#!/usr/bin/env python3
"""Nightly driver for enrich_books.py.

Triggered once per night (01:00) by a Windows Task Scheduler job. Pulls
batches of not-yet-attempted ISBNs from the DB, runs enrich_books.py on each
batch, and keeps going until either the ~08:00 cutoff, a configured max
number of nights, or an empty catalog query stops it - whichever comes
first. State (nights run so far, total ISBNs attempted, done flag) persists
in nightly_state.json so each night's invocation knows where it left off.

Does NOT touch the DB except to SELECT candidate ISBNs - never writes.
"""

from __future__ import annotations

import datetime
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATE_PATH = HERE / "nightly_state.json"
LEDGER_PATH = HERE / "attempted_isbns.txt"
MASTER_OUTPUT = HERE / "enriched_all.json"
RUNS_DIR = HERE / "nightly_runs"
TASK_NAME = "ShelfShareEnrichmentScraper"

RUN_HOURS = 7.0  # 01:00 -> ~08:00
BATCH_SIZE = 50
MAX_NIGHTS = 14
PYTHON = sys.executable

POSTGRES_CONTAINER = "shelfshare-postgres-1"
POSTGRES_USER = "shelfshare"
POSTGRES_DB = "shelfshare"


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


def fetch_batch(exclude: set[str], limit: int) -> list[tuple[str, str]]:
    exclude_list = ",".join("'" + isbn.replace("'", "''") + "'" for isbn in exclude) or "''"
    sql = f"""
    SELECT isbn, title FROM books
    WHERE isbn IS NOT NULL
    AND isbn NOT IN ({exclude_list})
    AND (description IS NULL OR "coverUrl" IS NULL)
    ORDER BY RANDOM()
    LIMIT {limit}
    """
    result = subprocess.run(
        ["docker", "exec", POSTGRES_CONTAINER, "psql", "-U", POSTGRES_USER, "-d", POSTGRES_DB,
         "-t", "-A", "-F,", "-c", sql],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"DB query failed: {result.stderr}")
    rows = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        isbn, _, title = line.partition(",")
        rows.append((isbn, title))
    return rows


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
    stop_at = start + datetime.timedelta(hours=RUN_HOURS)
    night_no = state["nights_run"] + 1
    print(f"[nightly] noaptea {night_no}/{MAX_NIGHTS} - start {start.isoformat(timespec='seconds')}, stop cel tarziu la {stop_at.isoformat(timespec='seconds')}")

    ledger = load_ledger()
    batch_idx = 0
    exhausted = False

    while datetime.datetime.now() < stop_at:
        try:
            rows = fetch_batch(ledger, BATCH_SIZE)
        except RuntimeError as exc:
            print(f"[nightly] eroare la interogarea DB, sar peste noaptea asta: {exc}")
            return

        if not rows:
            print("[nightly] nicio carte netestata ramasa in catalog - gata")
            exhausted = True
            break

        batch_idx += 1
        batch_isbns = [isbn for isbn, _ in rows]
        input_path = RUNS_DIR / f"night{night_no}_batch{batch_idx}_isbns.txt"
        output_path = RUNS_DIR / f"night{night_no}_batch{batch_idx}_enriched.json"
        log_path = RUNS_DIR / f"night{night_no}_batch{batch_idx}.log"
        input_path.write_text(
            "\n".join(f"{isbn},{title}" if title else isbn for isbn, title in rows),
            encoding="utf-8",
        )

        print(f"[nightly] batch {batch_idx}: {len(rows)} carti -> {output_path.name}")
        with log_path.open("w", encoding="utf-8") as log_fh:
            proc = subprocess.run(
                [PYTHON, str(HERE / "enrich_books.py"),
                 "--input", str(input_path),
                 "--output", str(output_path),
                 "--allow-fuzzy-match"],
                cwd=str(HERE),
                stdout=log_fh,
                stderr=subprocess.STDOUT,
            )
        if proc.returncode != 0:
            print(f"[nightly] enrich_books.py a iesit cu cod {proc.returncode}, vezi {log_path.name}")

        append_ledger(batch_isbns)
        ledger.update(batch_isbns)
        state["total_attempted"] += len(batch_isbns)
        added = merge_into_master(output_path)
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
