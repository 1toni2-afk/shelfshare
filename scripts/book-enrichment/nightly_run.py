#!/usr/bin/env python3
"""Nightly driver for the enrichment scrapers.

Triggered once per night (01:00) by a Windows Task Scheduler job. Pulls
batches of not-yet-attempted ISBNs from the DB in priority order (books a
user has actually touched first - see TOUCHED_TABLES and candidate_sql),
then runs them through the source chain: libris -> carturesti -> Google
Books for Romanian titles, Google Books alone for everything else, each
book moving on only if the previous source did not return a description.
Keeps going until either the ~08:00 cutoff, a configured max number of
nights, or an empty catalog query stops it - whichever comes first. State
(nights run so far, total ISBNs attempted, done flag) persists in
nightly_state.json so each night's invocation knows where it left off.

Does NOT touch the DB except to SELECT candidate ISBNs - never writes.
"""

from __future__ import annotations

import argparse
import datetime
import json
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATE_PATH = HERE / "nightly_state.json"
LEDGER_PATH = HERE / "attempted_isbns.txt"
MASTER_OUTPUT = HERE / "enriched_all.json"
RUNS_DIR = HERE / "nightly_runs"
TASK_NAME = "ShelfShareEnrichmentScraper"

RUN_HOURS = 7.0  # 01:00 -> ~08:00; o rulare manuala poate cere alta durata cu --hours
BATCH_SIZE = 50
MAX_NIGHTS = 14
PYTHON = sys.executable

POSTGRES_CONTAINER = "shelfshare-postgres-1"
POSTGRES_USER = "shelfshare"
POSTGRES_DB = "shelfshare"

# Limbile pentru care merita incercate librariile romanesti; restul merg direct
# pe Google Books (vezi enrich_google.py).
ROMANIAN_LANGS = ("rum", "Română", "ron", "ro")

# Tabelele prin care o carte devine "atinsa de cineva". Cat timp catalogul are
# 3,68M de carti dar userii au atins 613, ordinea in care le luam conteaza mult
# mai mult decat viteza scraperului: ORDER BY RANDOM() peste tot catalogul
# imbogateste carti pe care nu le vede nimeni.
TOUCHED_TABLES = (
    "bookshelf_entries", "book_swipes", "collection_items", "reading_progress",
    "reviews", "user_books", "wishlist_items", "book_of_month_votes",
)
TOUCHED_SQL = " UNION ".join(f'SELECT "bookId" FROM {t}' for t in TOUCHED_TABLES)

# Etichetele de prioritate, in ordinea in care sunt servite.
TIER_LABELS = {0: "atinse", 1: "populare", 2: "restul"}

SOURCE_SCRIPTS = {
    "libris": ("enrich_libris.py", ()),
    "carturesti": ("enrich_books.py", ("--allow-fuzzy-match",)),
    "google": ("enrich_google.py", ()),
}

# Ordinea surselor, dupa limba cartii. Libris intai pentru ca verifica exact pe
# ISBN si costa o singura navigare; carturesti dupa, fiindca e de doua ori mai
# scump si accepta doar potriviri fuzzy; Google la urma, ca ultima incercare
# ieftina. Pentru carti care nu-s in romana librariile romanesti n-au ce oferi
# (masurat: 0/12 pe candidati reali), deci mergem direct pe Google.
CHAIN_ROMANIAN = ("libris", "carturesti", "google")
CHAIN_OTHER = ("google",)

LIBRIS_INDEX = HERE / "libris_index.json"


def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    return {"nights_run": 0, "total_attempted": 0, "done": False, "done_reason": None}


def save_state(state: dict) -> None:
    STATE_PATH.write_text(json.dumps(state, indent=2), encoding="utf-8")


def load_ledger() -> set[str]:
    if not LEDGER_PATH.exists():
        return set()
    return {line.strip() for line in LEDGER_PATH.read_text(encoding="utf-8").splitlines() if line.strip()}


def append_ledger(isbns: list[str]) -> None:
    with LEDGER_PATH.open("a", encoding="utf-8") as fh:
        for isbn in isbns:
            fh.write(isbn + "\n")


def unregister_task(reason: str) -> None:
    print(f"[nightly] catalog epuizat / plafon atins ({reason}) - dezactivez task-ul programat")
    subprocess.run(
        ["schtasks", "/delete", "/tn", TASK_NAME, "/f"],
        capture_output=True,
        text=True,
    )


def candidate_sql(exclude: set[str], limit: int) -> str:
    """Cartile care au nevoie de imbogatire, in ordinea in care merita facute.

    tier 0 = atinse de un user (raft, swipe, recenzie, wishlist, ...)
    tier 1 = au popularityScore
    tier 2 = restul catalogului

    RANDOM() a ramas doar ca departajare in interiorul unui tier, ca doua nopti
    la rand sa nu ia aceleasi carti cand tier-ul e mai mare decat un batch.
    Coloana `title` e ultima pentru ca poate contine virgule (vezi run_query).
    """
    exclude_list = ",".join("'" + isbn.replace("'", "''") + "'" for isbn in exclude) or "''"
    return f"""
    WITH touched AS ({TOUCHED_SQL})
    SELECT b.isbn,
           COALESCE(b.language, ''),
           CASE WHEN t."bookId" IS NOT NULL THEN 0
                WHEN b."popularityScore" IS NOT NULL THEN 1
                ELSE 2 END AS tier,
           b.title
    FROM books b LEFT JOIN touched t ON t."bookId" = b.id
    WHERE b.isbn IS NOT NULL
    AND b.isbn NOT IN ({exclude_list})
    AND (b.description IS NULL OR b."coverUrl" IS NULL)
    ORDER BY tier, b."popularityScore" DESC NULLS LAST, RANDOM()
    LIMIT {limit}
    """


@dataclass(frozen=True)
class Candidate:
    isbn: str
    language: str
    tier: int
    title: str


def run_query(sql: str, columns: int = 2) -> list[list[str]]:
    """Rularea unui SELECT prin psql -> randuri deja despartite pe coloane.

    maxsplit=columns-1: ultima coloana inghite virgulele ramase, de aceea
    `title` e mereu selectata ultima.
    """
    result = subprocess.run(
        ["docker", "exec", POSTGRES_CONTAINER, "psql", "-U", POSTGRES_USER, "-d", POSTGRES_DB,
         "-t", "-A", "-F,", "-c", sql],
        capture_output=True,
        text=True,
        # psql scoate UTF-8; fara asta text=True decodeaza cu codepage-ul Windows
        # (cp1252) si crapa pe primul titlu cu diacritice - byte 0x81 n-are mapare.
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        raise RuntimeError(f"DB query failed: {result.stderr}")
    rows = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(line.split(",", columns - 1))
    return rows


def fetch_batch(exclude: set[str], limit: int) -> list[Candidate]:
    candidates = []
    for row in run_query(candidate_sql(exclude, limit), columns=4):
        if len(row) != 4:
            print(f"[nightly] rand neasteptat, il sar: {row!r}", file=sys.stderr)
            continue
        isbn, language, tier, title = row
        candidates.append(Candidate(isbn, language, int(tier), title))
    return candidates


def chain_for(language: str) -> tuple[str, ...]:
    return CHAIN_ROMANIAN if language in ROMANIAN_LANGS else CHAIN_OTHER


def run_stage(source: str, candidates: list[Candidate], night_no: int,
              batch_idx: int) -> tuple[Path | None, set[str]]:
    """Ruleaza o sursa pe un subset. -> (fisierul de iesire, ISBN-urile rezolvate).

    "Rezolvat" = a venit inapoi cu descriere. Descrierea e golul real (2,7M de
    carti fara, fata de 27 fara coperta), deci ea decide daca mai are rost sa
    trecem cartea la sursa urmatoare.
    """
    script_name, extra_args = SOURCE_SCRIPTS[source]
    stem = f"night{night_no}_batch{batch_idx}_{source}"
    input_path = RUNS_DIR / f"{stem}_isbns.txt"
    output_path = RUNS_DIR / f"{stem}.json"
    log_path = RUNS_DIR / f"{stem}.log"
    input_path.write_text(
        "\n".join(f"{c.isbn},{c.title}" if c.title else c.isbn for c in candidates),
        encoding="utf-8",
    )

    with log_path.open("w", encoding="utf-8") as log_fh:
        proc = subprocess.run(
            [PYTHON, str(HERE / script_name),
             "--input", str(input_path), "--output", str(output_path), *extra_args],
            cwd=str(HERE), stdout=log_fh, stderr=subprocess.STDOUT,
        )
    if proc.returncode != 0:
        print(f"[nightly]   {script_name} a iesit cu cod {proc.returncode}, vezi {log_path.name}")

    if not output_path.exists():
        return None, set()
    try:
        entries = json.loads(output_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"[nightly]   {output_path.name} nu se poate citi: {exc}")
        return None, set()
    solved = {e["isbn"] for e in entries if not e.get("error") and e.get("description")}
    return output_path, solved


def merge_into_master(batch_output: Path) -> int:
    if not batch_output.exists():
        return 0
    batch = json.loads(batch_output.read_text(encoding="utf-8"))
    master = json.loads(MASTER_OUTPUT.read_text(encoding="utf-8")) if MASTER_OUTPUT.exists() else []
    by_isbn = {entry["isbn"]: entry for entry in master}
    added = 0
    for entry in batch:
        if entry.get("title"):
            by_isbn[entry["isbn"]] = entry
            added += 1
    MASTER_OUTPUT.write_text(
        json.dumps(list(by_isbn.values()), ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return added


def main() -> None:
    parser = argparse.ArgumentParser(description="Driverul de noapte al scraperelor de imbogatire.")
    parser.add_argument("--hours", type=float, default=RUN_HOURS,
                        help=f"cat tine sesiunea asta, in ore (implicit {RUN_HOURS})")
    args = parser.parse_args()

    state = load_state()
    if state["done"]:
        print(f"[nightly] deja marcat done ({state['done_reason']}) - nu mai fac nimic")
        unregister_task(state["done_reason"])
        return

    if state["nights_run"] >= MAX_NIGHTS:
        state["done"] = True
        state["done_reason"] = "max_nights_reached"
        save_state(state)
        unregister_task("max_nights_reached")
        return

    RUNS_DIR.mkdir(exist_ok=True)
    start = datetime.datetime.now()
    stop_at = start + datetime.timedelta(hours=args.hours)
    night_no = state["nights_run"] + 1
    print(f"[nightly] noaptea {night_no}/{MAX_NIGHTS} - start {start.isoformat(timespec='seconds')}, stop cel tarziu la {stop_at.isoformat(timespec='seconds')}")

    ledger = load_ledger()
    batch_idx = 0
    exhausted = False

    while datetime.datetime.now() < stop_at:
        try:
            candidates = fetch_batch(ledger, BATCH_SIZE)
        except RuntimeError as exc:
            print(f"[nightly] eroare la interogarea DB, sar peste noaptea asta: {exc}")
            return

        if not candidates:
            print("[nightly] nicio carte netestata ramasa in catalog - gata")
            exhausted = True
            break

        batch_idx += 1
        batch_isbns = [c.isbn for c in candidates]

        spread = Counter(c.tier for c in candidates)
        tiers = " ".join(f"{TIER_LABELS[t]}:{n}" for t, n in sorted(spread.items()))
        print(f"[nightly] batch {batch_idx} [{tiers}]: {len(candidates)} carti")

        # Lantul de surse: fiecare carte trece la sursa urmatoare doar daca cea
        # de dinainte n-a adus-o cu descriere. Rulam pe etape, nu carte cu carte,
        # ca sa pornim un singur proces (si un singur browser) per sursa.
        pending = list(candidates)
        added = 0
        for source in ("libris", "carturesti", "google"):
            subset = [c for c in pending if source in chain_for(c.language)]
            if not subset:
                continue
            if source == "libris" and not LIBRIS_INDEX.exists():
                print(f"[nightly]   libris: lipseste {LIBRIS_INDEX.name}, sar peste "
                      f"(ruleaza: python enrich_libris.py --build-index)")
                continue
            print(f"[nightly]   {source}: {len(subset)} carti")
            output_path, solved = run_stage(source, subset, night_no, batch_idx)
            if output_path is not None:
                added += merge_into_master(output_path)
            print(f"[nightly]   {source}: {len(solved)}/{len(subset)} cu descriere")
            pending = [c for c in pending if c.isbn not in solved]

        append_ledger(batch_isbns)
        ledger.update(batch_isbns)
        state["total_attempted"] += len(batch_isbns)
        print(f"[nightly] {added}/{len(batch_isbns)} imbogatite in acest batch, total incercat pana acum: {state['total_attempted']}")
        save_state(state)

    state["nights_run"] = night_no
    if exhausted:
        state["done"] = True
        state["done_reason"] = "catalog_exhausted"
    save_state(state)

    print(f"[nightly] noaptea {night_no} incheiata - total incercat: {state['total_attempted']}")

    if state["done"]:
        unregister_task(state["done_reason"])
    elif night_no >= MAX_NIGHTS:
        state["done"] = True
        state["done_reason"] = "max_nights_reached"
        save_state(state)
        unregister_task("max_nights_reached")


if __name__ == "__main__":
    main()
