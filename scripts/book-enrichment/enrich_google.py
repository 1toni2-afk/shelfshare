#!/usr/bin/env python3
"""Book metadata enrichment from the Google Books API.

A treia sursa, si singura care nu e un scraper: Google Books e un API JSON
public, deci nu avem nici Cloudflare, nici browser, nici selectoare de intretinut.
Ce iese are exact acelasi format ca la enrich_books.py / enrich_libris.py, deci
import_enriched.py il citeste nemodificat.

De ce exista
------------
Celelalte doua surse sunt librarii romanesti si acopera doar stoc romanesc
curent. Golul real din catalog e altul: 2.725.584 de carti fara descriere, din
care 2.724.945 in engleza (coperti lipsesc doar la 27). Pentru partea aia
carturesti si libris n-au ce oferi - Google Books are.

Verificarea pe ISBN
-------------------
`q=isbn:...` e o interogare, nu o cautare exacta: Google poate intoarce alta
editie sau, la ISBN-uri neobisnuite, altceva. Acceptam un volum doar daca ISBN-ul
cerut chiar apare in `industryIdentifiers`, la fel cum enrich_libris.py verifica
`gtin13` din JSON-LD. Fara asta am scrie descrieri de la alte carti.

Cheia API (GOOGLE_BOOKS_API_KEY) e optionala - aceeasi variabila pe care o
foloseste si backendul in book-lookup.service.ts. Fara ea cota anonima e mai
mica, dar pentru cateva sute de carti ajunge.

Usage:
    python enrich_google.py --input isbns.txt --output enriched_google.json
    python enrich_google.py --isbn 9780140449136
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict
from random import uniform

from enrich_books import EnrichedBook, _normalize_isbn, read_input

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

API_URL = "https://www.googleapis.com/books/v1/volumes"
SOURCE_NAME = "google"
# Aceeasi limita ca la importul din Open Library (import-openlibrary-cdump.js),
# ca descrierile din catalog sa ramana comparabile ca lungime.
DESCRIPTION_MAX = 2000
RETRY_STATUSES = {429, 500, 502, 503, 504}
MAX_RETRIES = 3
# Asteptari intre reincercari, in secunde. Mai lungi pentru 429 decat pentru
# 5xx: un 429 inseamna cota, nu o eroare trecatoare, deci reincercarea rapida
# doar consuma din ea.
RETRY_WAITS = {429: (10, 30), "default": (2, 4)}
# Dupa atatea carti la rand oprite de cota, abandonam rularea in loc sa macinam
# restul listei producand doar erori.
RATE_LIMIT_STRIKES = 3
RATE_LIMIT_MARKER = "HTTP 429"
# Salvare incrementala: procesul poate fi oprit (sau poate crapa) dupa ore de
# rulare, iar un singur json.dump la final ar pierde tot.
SAVE_EVERY = 25


def _api_url(isbn: str) -> str:
    url = f"{API_URL}?q=isbn:{urllib.parse.quote(isbn)}"
    key = os.environ.get("GOOGLE_BOOKS_API_KEY")
    return f"{url}&key={urllib.parse.quote(key)}" if key else url


def fetch_volumes(isbn: str, timeout: float) -> tuple[list[dict] | None, str | None]:
    """-> (items, eroare). Reincearca pe 429/5xx, cu asteptare crescatoare."""
    url = _api_url(isbn)
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            request = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
            return payload.get("items") or [], None
        except urllib.error.HTTPError as exc:
            if exc.code in RETRY_STATUSES and attempt < MAX_RETRIES:
                waits = RETRY_WAITS.get(exc.code, RETRY_WAITS["default"])
                wait = waits[min(attempt - 1, len(waits) - 1)]
                print(f"    [!] HTTP {exc.code}, reincerc peste {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            return None, f"google books HTTP {exc.code}"
        except (urllib.error.URLError, TimeoutError) as exc:
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)
                continue
            return None, f"google books unreachable: {exc}"
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            return None, f"google books raspuns invalid: {exc}"
    return None, "google books: retries epuizate"


def _isbns_of(volume_info: dict) -> set[str]:
    return {
        _normalize_isbn(ident.get("identifier"))
        for ident in volume_info.get("industryIdentifiers") or []
        if ident.get("identifier")
    }


def _year(value: object) -> int | None:
    text = str(value or "")
    return int(text[:4]) if text[:4].isdigit() else None


def _cover(volume_info: dict) -> str | None:
    links = volume_info.get("imageLinks") or {}
    # De la mare la mic; thumbnail-ul e ultima varianta, dar tot e o copertă.
    for size in ("extraLarge", "large", "medium", "small", "thumbnail", "smallThumbnail"):
        url = links.get(size)
        if url:
            return url.replace("http://", "https://")
    return None


def _description(volume_info: dict) -> str | None:
    text = (volume_info.get("description") or "").strip()
    if not text:
        return None
    if len(text) > DESCRIPTION_MAX:
        return text[: DESCRIPTION_MAX - 1].rstrip() + "…"
    return text


def pick_volume(items: list[dict], wanted_isbn: str) -> dict | None:
    """Primul volum care chiar are ISBN-ul cerut in industryIdentifiers."""
    wanted = _normalize_isbn(wanted_isbn)
    for item in items:
        info = item.get("volumeInfo") or {}
        if wanted in _isbns_of(info):
            return info
    return None


def enrich_one(isbn: str, timeout: float) -> EnrichedBook:
    normalized = _normalize_isbn(isbn)
    if not normalized:
        return EnrichedBook(isbn=isbn or "", source=SOURCE_NAME, error="ISBN gol")

    items, error = fetch_volumes(normalized, timeout)
    if error:
        return EnrichedBook(isbn=normalized, source=SOURCE_NAME, error=error)
    if not items:
        return EnrichedBook(isbn=normalized, source=SOURCE_NAME, error="niciun volum returnat")

    info = pick_volume(items, normalized)
    if info is None:
        return EnrichedBook(
            isbn=normalized, source=SOURCE_NAME,
            error=f"niciun volum cu ISBN-ul cerut (au venit {len(items)})",
        )

    authors = info.get("authors") or []
    return EnrichedBook(
        isbn=normalized,
        source=SOURCE_NAME,
        productUrl=info.get("infoLink") or info.get("canonicalVolumeLink"),
        title=info.get("title") or None,
        author=", ".join(authors) or None,
        publisher=info.get("publisher") or None,
        description=_description(info),
        coverUrl=_cover(info),
        publishedYear=_year(info.get("publishedDate")),
        pageCount=info.get("pageCount") if isinstance(info.get("pageCount"), int) else None,
        language=info.get("language") or None,
        collection=", ".join(info.get("categories") or []) or None,
        sourceIsbn=normalized,
        # Volumul a fost acceptat exact pentru ca poarta ISBN-ul cerut.
        isbnVerified=True,
    )


def load_existing(path: str) -> list[dict]:
    """Rezultatele dintr-o rulare anterioara, ca sa reluam de unde s-a ramas."""
    if not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError) as exc:
        print(f"[!] {path} nu se poate citi ({exc}), o iau de la zero", file=sys.stderr)
        return []


def _is_retryable(entry: dict) -> bool:
    """O intrare oprita de cota nu conteaza ca facuta - o reincercam."""
    error = entry.get("error") or ""
    return RATE_LIMIT_MARKER in error or "unreachable" in error


def save_results(path: str, results: list[dict]) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(results, handle, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--input", help="Fisier cu ISBN-uri ('isbn' sau 'isbn,titlu' pe linie)")
    parser.add_argument("--isbn", help="Un singur ISBN, pentru teste rapide")
    parser.add_argument("--output", default="enriched_google.json", help="Fisier JSON de iesire")
    parser.add_argument("--delay-min", type=float, default=0.6,
                        help="Pauza minima intre cereri (sec) - e API, nu scraping")
    parser.add_argument("--delay-max", type=float, default=1.2, help="Pauza maxima intre cereri (sec)")
    parser.add_argument("--timeout", type=float, default=10.0, help="Timeout per cerere (sec)")
    parser.add_argument("--only-missing-description", action="store_true",
                        help="Pastreaza in iesire doar intrarile care chiar au adus o descriere")
    args = parser.parse_args()

    if not args.input and not args.isbn:
        parser.error("da --input sau --isbn")

    entries = [(args.isbn, None)] if args.isbn else list(read_input(args.input))
    if not entries:
        print("Nimic de procesat (fisier gol?).", file=sys.stderr)
        sys.exit(1)

    if not os.environ.get("GOOGLE_BOOKS_API_KEY"):
        print("[i] GOOGLE_BOOKS_API_KEY nesetata - merg pe cota anonima", file=sys.stderr)

    results = load_existing(args.output)
    done = {r["isbn"] for r in results if not _is_retryable(r)}
    if done:
        print(f"[i] reiau: {len(done)} ISBN-uri deja in {args.output}", flush=True)

    strikes = 0
    aborted = None
    for i, (isbn, title) in enumerate(entries, start=1):
        if _normalize_isbn(isbn) in done:
            continue
        if i > 1:
            time.sleep(uniform(args.delay_min, args.delay_max))
        print(f"[{i}/{len(entries)}] {isbn} ({title or '-'})", flush=True)
        book = enrich_one(isbn, args.timeout)

        if book.error and RATE_LIMIT_MARKER in book.error:
            # Cota Google e epuizata: fara cheie API e ~1.000 cereri/zi. Nu are
            # rost sa mai macinam sute de carti producand doar erori - oprim si
            # pastram ce s-a strans, ca urmatoarea rulare sa continue de aici.
            strikes += 1
            print(f"    -> {book.error} ({strikes}/{RATE_LIMIT_STRIKES})", flush=True)
            if strikes >= RATE_LIMIT_STRIKES:
                aborted = "cota Google Books epuizata"
                break
            continue
        strikes = 0

        if book.error:
            print(f"    -> {book.error}", flush=True)
        else:
            has_description = "descriere" if book.description else "fara descriere"
            print(f"    -> {book.title} ({book.publisher or '?'}) [{has_description}]", flush=True)
        if args.only_missing_description and not book.description:
            continue
        results.append(asdict(book))
        if len(results) % SAVE_EVERY == 0:
            save_results(args.output, results)

    save_results(args.output, results)

    ok = sum(1 for r in results if not r.get("error"))
    with_description = sum(1 for r in results if r.get("description"))
    print(f"\n{ok}/{len(entries)} gasite, {with_description} cu descriere -> {args.output}")
    if aborted:
        print(f"[!] OPRIT: {aborted}. Seteaza GOOGLE_BOOKS_API_KEY sau reia maine "
              f"- rularea urmatoare continua de unde a ramas.", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
