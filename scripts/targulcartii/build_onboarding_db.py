#!/usr/bin/env python3
"""Construieste Onboarding_Books_DB din lista de titluri de onboarding.

De ce e separat de scrape_targulcartii.py: acela ia tot catalogul, orbeste, in
ordinea sitemap-ului. Aici avem o lista scurta si precisa (onboarding_books.txt),
deci pasii sunt altii - intai gasim URL-ul fiecarui titlu, abia apoi cerem
paginile, si cerem DOAR pe alea.

Diferenta de cost e toata povestea: 197 de titluri inseamna ~400 de cereri, adica
~7h chiar si la delay-ul de 60s cerut de robots.txt, fata de peste o luna pentru
catalogul intreg. Nu e nevoie sa fortam ritmul pentru lista asta.

Etape
-----
    python build_onboarding_db.py match     # zero cereri - doar sitemap-ul local
    python build_onboarding_db.py scrape    # cere doar paginile nepotrivite inca
    python build_onboarding_db.py export    # scrie Onboarding_Books_DB.json
    python build_onboarding_db.py covers    # descarca copertile in _covers/

`match` nu atinge reteaua deloc: sitemap-ul e deja pe disc (data/sitemap_opere.xml)
si contine autorul si titlul in URL, deci potrivirea se face local. `scrape`
refoloseste ce e deja in data/opere.jsonl din rularea pe tot catalogul, deci
titlurile prinse acolo nu se mai cer a doua oara.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from scrape_targulcartii import (
    COVERS_DIR,
    DATA_DIR,
    OPERE_PATH,
    URLS_PATH,
    Blocked,
    Fetcher,
    eta,
    is_usable,
    load_records,
    parse_offer,
    parse_opera,
)

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

HERE = Path(__file__).resolve().parent
BOOKS_LIST = HERE / "onboarding_books.txt"
MATCHES_PATH = DATA_DIR / "onboarding_matches.json"
DB_PATH = HERE / "Onboarding_Books_DB.json"
DB_COVERS_DIR = HERE / "Onboarding_Books_DB_covers"

# Praguri de acceptare. Autorul e semnalul decisiv, nu titlul: masurat pe lista
# asta, potrivirile gresite ("Educated" -> Pratchett, "Jurnalul Annei Frank" ->
# frank-skinner, "Puterea obisnuintei" -> lj-smith/puterea) aveau toate scor de
# titlu decent si autor gresit, iar cele bune ("Catre far" -> woolf/spre-far,
# "O mie de sori..." -> hosseini/splendida-cetate...) aveau autorul corect si
# titlu doar partial. Deci autorul e poarta, titlul e doar confirmarea.
ACCEPT_WITH_AUTHOR = 0.50
# Fara autor potrivit cerem practic titlu identic - altfel intra zgomot.
ACCEPT_TITLE_ONLY = 0.85

# Cuvinte prea comune ca sa dovedeasca ceva despre un titlu.
STOPWORDS = {
    "the", "and", "for", "din", "cu", "de", "la", "un", "una", "sau", "si",
    "in", "pe", "al", "ale", "lui", "care", "dintre", "o", "si", "a", "ai",
}


def normalize(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", ascii_only.lower()).strip()


def tokens(text: str, *, keep_short: bool = False) -> list[str]:
    words = normalize(text).split()
    if keep_short:
        return [w for w in words if w not in STOPWORDS]
    return [w for w in words if len(w) > 2 and w not in STOPWORDS]


def read_list() -> list[dict]:
    """onboarding_books.txt -> [{title, author, note}], in ordinea din fisier."""
    books = []
    for line in BOOKS_LIST.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if not parts[0]:
            continue
        books.append({
            "title": parts[0],
            "author": parts[1] if len(parts) > 1 else "",
            "note": parts[2] if len(parts) > 2 and parts[2] else None,
        })
    return books


class Catalog:
    """URL-urile din sitemap, indexate pe cuvintele din slug-ul de titlu.

    Un URL e /<autor-slug>/<titlu-slug>, deci avem si autorul si titlul fara sa
    deschidem nicio pagina - de asta `match` nu face nicio cerere.
    """

    def __init__(self, urls: list[str]):
        self.urls = urls
        self.titles: list[str] = []
        self.authors: list[str] = []
        self.by_token: dict[str, list[int]] = {}
        for i, url in enumerate(urls):
            author_slug, title_slug = url.rsplit("/", 2)[-2:]
            self.authors.append(normalize(author_slug.replace("-", " ")))
            self.titles.append(normalize(title_slug.replace("-", " ")))
            for token in set(tokens(self.titles[i], keep_short=True)):
                self.by_token.setdefault(token, []).append(i)

    @classmethod
    def load(cls) -> "Catalog":
        if not URLS_PATH.exists():
            raise SystemExit(
                f"Lipseste {URLS_PATH.name}. Ruleaza intai:  "
                f"python scrape_targulcartii.py sitemap"
            )
        urls = [u for u in URLS_PATH.read_text(encoding="utf-8").splitlines() if u.strip()]
        return cls(urls)

    def best(self, title: str, author: str, limit: int = 3) -> list[dict]:
        want_title = set(tokens(title, keep_short=True))
        want_author = set(tokens(author, keep_short=True))
        if not want_title:
            return []

        hits: Counter[int] = Counter()
        for token in want_title:
            for idx in self.by_token.get(token, ()):
                hits[idx] += 1
        if not hits:
            return []

        scored = []
        for idx, common in hits.items():
            cand_title = set(tokens(self.titles[idx], keep_short=True))
            if not cand_title:
                continue
            # Media dintre cat acopera titlul cerut si cat acopera cel gasit:
            # asimetric intr-o singura directie ar accepta "Ion" in "Ion Creanga
            # - opere alese" la fel de bine ca romanul lui Rebreanu.
            coverage_want = common / len(want_title)
            coverage_got = common / len(cand_title)
            score = (coverage_want + coverage_got) / 2
            author_ok = bool(want_author
                             and want_author & set(tokens(self.authors[idx], keep_short=True)))
            scored.append({
                "score": round(score, 3),
                "authorMatch": author_ok,
                "url": self.urls[idx],
            })

        # Cu autorul potrivit intai: la scor egal, ala e candidatul serios.
        scored.sort(key=lambda c: (c["authorMatch"], c["score"]), reverse=True)
        return scored[:limit]


def is_acceptable(candidate: dict) -> bool:
    if candidate["authorMatch"]:
        return candidate["score"] >= ACCEPT_WITH_AUTHOR
    return candidate["score"] >= ACCEPT_TITLE_ONLY


def cmd_match(args: argparse.Namespace) -> None:
    books = read_list()
    catalog = Catalog.load()
    print(f"[match] {len(books)} titluri x {len(catalog.urls)} opere din sitemap (zero cereri)")

    matched = unmatched = 0
    results = []
    for book in books:
        candidates = catalog.best(book["title"], book["author"])
        best = candidates[0] if candidates else None
        accepted = bool(best and is_acceptable(best))
        matched += accepted
        unmatched += not accepted
        results.append({
            **book,
            "url": best["url"] if accepted else None,
            "score": best["score"] if best else 0.0,
            "authorMatch": best["authorMatch"] if best else False,
            "candidates": candidates,
        })

    # Doua titluri diferite care cad pe acelasi URL inseamna ca cel putin unul e
    # gresit - de obicei o pagina generica de serie ("/jk-rowling/harry-potter")
    # care inghite volumele pentru care site-ul n-are pagina separata. Le trimitem
    # pe toate la verificare manuala, ca sa nu intre acelasi produs de doua ori.
    used: Counter[str] = Counter(r["url"] for r in results if r["url"])
    for result in results:
        if result["url"] and used[result["url"]] > 1:
            result["url"] = None
            result["collision"] = True
            matched -= 1
            unmatched += 1

    MATCHES_PATH.write_text(
        json.dumps({"books": results}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[match] potrivite {matched}, de verificat {unmatched} -> {MATCHES_PATH.name}")
    if unmatched:
        print("[match] fara potrivire sigura (primele 15):")
        for r in results:
            if not r["url"] and unmatched > 0:
                top = r["candidates"][0]["url"].rsplit("/", 1)[-1] if r["candidates"] else "-"
                print(f"         {r['title'][:45]:45s} (best {r['score']:.2f}: {top})")


def cmd_scrape(args: argparse.Namespace) -> None:
    if not MATCHES_PATH.exists():
        raise SystemExit("Ruleaza intai:  python build_onboarding_db.py match")
    wanted = [b for b in json.loads(MATCHES_PATH.read_text(encoding="utf-8"))["books"] if b["url"]]

    # Rularea pe tot catalogul a prins deja o parte din titluri; alea nu se mai cer.
    have = {url: rec for url, rec in load_records().items() if is_usable(rec)}
    todo = [b for b in wanted if b["url"] not in have]
    print(f"[scrape] {len(wanted)} titluri potrivite, {len(wanted) - len(todo)} deja in "
          f"opere.jsonl, {len(todo)} de cerut")
    if not todo:
        print("[scrape] nimic de cerut - treci direct la `export`")
        return

    fetcher = Fetcher.create(args.delay)
    eta(len(todo) * 2, fetcher.delay, f"cereri ({len(todo)} titluri)")

    saved = 0
    with OPERE_PATH.open("a", encoding="utf-8") as out:
        for i, book in enumerate(todo, start=1):
            try:
                resp = fetcher.get(book["url"])
                if resp is None:
                    continue
                record = parse_opera(resp.text, book["url"])
                if not is_usable(record):
                    print(f"  [!] pagina fara continut: {book['url']}", file=sys.stderr)
                    continue
                for offer in record["offers"][:1]:
                    if offer.get("url"):
                        detail = fetcher.get(offer["url"])
                        if detail is not None:
                            offer["details"] = parse_offer(detail.text, offer["url"])
            except Blocked as exc:
                raise SystemExit(
                    f"\n[STOP] {exc}\n       {saved} titluri salvate. Reia mai tarziu."
                )

            out.write(json.dumps(record, ensure_ascii=False) + "\n")
            out.flush()
            saved += 1
            print(f"[scrape] {i}/{len(todo)} {record.get('title')}")

    print(f"[scrape] gata - {saved} titluri adaugate")


def cmd_export(args: argparse.Namespace) -> None:
    if not MATCHES_PATH.exists():
        raise SystemExit("Ruleaza intai:  python build_onboarding_db.py match")
    wanted = json.loads(MATCHES_PATH.read_text(encoding="utf-8"))["books"]
    records = load_records()

    manifest: dict[str, str] = {}
    manifest_path = DB_COVERS_DIR / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    books = []
    for entry in wanted:
        record = records.get(entry["url"]) if entry["url"] else None
        # O inregistrare goala (scrisa cat eram blocati) nu inseamna "gasita" -
        # n-are nici titlu, nici oferte, deci nu are ce contribui aici.
        if record is not None and not is_usable(record):
            record = None
        offer = (record or {}).get("offers", [{}])[0] if (record or {}).get("offers") else {}
        details = offer.get("details") or {}
        cover = details.get("coverUrlLarge") or offer.get("coverUrl")
        books.append({
            "requestedTitle": entry["title"],
            "requestedAuthor": entry["author"],
            "note": entry["note"],
            "matchScore": entry["score"],
            "found": bool(record),
            "isbn": details.get("isbn"),
            "title": (record or {}).get("title"),
            "author": (record or {}).get("author"),
            "publisher": details.get("publisher") or offer.get("publisher"),
            "publishedYear": details.get("publishedYear") or offer.get("year"),
            "pageCount": details.get("pageCount"),
            "language": details.get("language"),
            "coverType": details.get("coverType") or offer.get("coverType"),
            "price": offer.get("price"),
            "offerCount": (record or {}).get("offerCount", 0),
            "coverUrl": cover,
            "coverFile": (f"Onboarding_Books_DB_covers/{manifest[cover]}"
                          if cover in manifest else None),
            "operaUrl": entry["url"],
            "source": "targulcartii",
        })

    found = sum(1 for b in books if b["found"])
    payload = {
        "name": "Onboarding_Books_DB",
        "source": "targulcartii.ro",
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "requested": len(books),
        "found": found,
        "books": books,
    }
    DB_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    with_isbn = sum(1 for b in books if b["isbn"])
    with_cover = sum(1 for b in books if b["coverUrl"])
    print(f"[export] {len(books)} cerute, {found} gasite, {with_isbn} cu ISBN, "
          f"{with_cover} cu coperta -> {DB_PATH.name}")


def cmd_covers(args: argparse.Namespace) -> None:
    if not DB_PATH.exists():
        raise SystemExit("Ruleaza intai:  python build_onboarding_db.py export")
    payload = json.loads(DB_PATH.read_text(encoding="utf-8"))

    DB_COVERS_DIR.mkdir(parents=True, exist_ok=True)
    manifest_path = DB_COVERS_DIR / "manifest.json"
    manifest: dict[str, str] = {}
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    todo = []
    for book in payload["books"]:
        url = book.get("coverUrl")
        if url and (url not in manifest or not (DB_COVERS_DIR / manifest[url]).exists()):
            todo.append(url)

    # Copertile din rularea pe tot catalogul sunt deja pe disc; le copiem in loc
    # sa le cerem din nou.
    catalog_manifest_path = COVERS_DIR / "manifest.json"
    catalog_manifest = (json.loads(catalog_manifest_path.read_text(encoding="utf-8"))
                        if catalog_manifest_path.exists() else {})
    copied = 0
    still_needed = []
    for url in todo:
        name = catalog_manifest.get(url)
        source = COVERS_DIR / name if name else None
        if source and source.exists():
            (DB_COVERS_DIR / name).write_bytes(source.read_bytes())
            manifest[url] = name
            copied += 1
        else:
            still_needed.append(url)

    print(f"[covers] {copied} copiate local, {len(still_needed)} de descarcat")
    if still_needed and args.skip_download:
        print("[covers] --skip-download: nu cer nimic de pe site")
        still_needed = []
    if still_needed:
        fetcher = Fetcher.create(args.delay)
        eta(len(still_needed), fetcher.delay, "coperti")
        for i, url in enumerate(still_needed, start=1):
            resp = fetcher.get(url, binary=True)
            if resp is None:
                continue
            name = re.sub(r"[^A-Za-z0-9._-]", "_", url.rsplit("/", 1)[-1])
            (DB_COVERS_DIR / name).write_bytes(resp.content)
            manifest[url] = name
            print(f"[covers] {i}/{len(still_needed)} {name}")

    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[covers] gata - {len(manifest)} coperti in {DB_COVERS_DIR.name}")
    print("[covers] ruleaza din nou `export` ca sa lege coverFile in DB")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--delay", type=float, default=None,
                        help="Secunde intre cereri (implicit: Crawl-delay din robots.txt)")
    sub = parser.add_subparsers(dest="command", required=True)

    for name, func, helptext in (
        ("match", cmd_match, "Potriveste lista cu sitemap-ul local (zero cereri)"),
        ("scrape", cmd_scrape, "Cere paginile titlurilor potrivite"),
        ("export", cmd_export, "Scrie Onboarding_Books_DB.json"),
        ("covers", cmd_covers, "Copiaza/descarca copertile"),
    ):
        p = sub.add_parser(name, help=helptext)
        if name == "covers":
            p.add_argument("--skip-download", action="store_true",
                           help="Doar copiaza copertile deja descarcate, nu cere nimic")
        p.set_defaults(func=func)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
