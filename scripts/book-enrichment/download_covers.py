#!/usr/bin/env python3
"""Descarca local coperti pentru ShelfShare_SCP_DB.json, ca accesul sa fie instant.

Salveaza fiecare coperta in ShelfShare_SCP_DB_covers/<isbn>.<ext> si scrie un
manifest (isbn -> cale relativa) langa ele.

Sursa de baza e `coverUrl` din scrape. Cand acesta lipseste sau e placeholderul
"fara imagine" al librariei, se cade pe Open Library dupa ISBN: cele ~300 de
titluri in engleza pe care Google Books le-a returnat fara coperta au aproape
toate coperta pe OL (verificat: 60 din 60 pe esantion), iar OL nu are cota si
serveste direct prin API, deci nu e nevoie de scraping pe site-uri de librarie.

Fisierele descarcate ajung in baza prin backend/prisma/import-scp-db.js, care
le converteste in webp si le urca in MinIO.
"""
import json
import mimetypes
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import requests

HERE = Path(__file__).resolve().parent
DB_PATH = HERE / "ShelfShare_SCP_DB.json"
COVERS_DIR = HERE / "ShelfShare_SCP_DB_covers"
MANIFEST_PATH = COVERS_DIR / "manifest.json"

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

# `default=false` e esential: fara el OL intoarce 200 cu un GIF transparent de
# 1x1 pentru orice ISBN necunoscut, deci am salva "coperti" goale fara sa stim.
OPEN_LIBRARY_COVER = "https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg?default=false"

# Sub atat nu e o coperta reala, ci un placeholder sau un raspuns trunchiat.
MIN_COVER_BYTES = 2000


def usable_cover_url(url: str | None) -> str | None:
    """URL bun = absolut si nu placeholderul "fara imagine" al librariei.

    Scrape-ul salveaza uneori `/assets/.../img/noimg.jpg` - o cale relativa
    catre imaginea "nu avem poza". Luata drept coperta, suprascria coperti
    bune cu una rupta (vezi usableCoverUrl din import-scp-db.js).
    """
    if not isinstance(url, str):
        return None
    trimmed = url.strip()
    if not trimmed.lower().startswith(("http://", "https://")):
        return None
    lowered = trimmed.lower()
    if any(mark in lowered for mark in ("noimg", "no-image", "placeholder")):
        return None
    return trimmed


def ext_from(url: str, content_type: str | None) -> str:
    path_ext = Path(urlparse(url).path).suffix
    if path_ext and len(path_ext) <= 5:
        return path_ext
    if content_type:
        guessed = mimetypes.guess_extension(content_type.split(";")[0].strip())
        if guessed:
            return guessed
    return ".jpg"


def main() -> None:
    data = json.loads(DB_PATH.read_text(encoding="utf-8"))
    books = data["books"]
    COVERS_DIR.mkdir(exist_ok=True)

    manifest = {}
    if MANIFEST_PATH.exists():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    # Toate cartile, nu doar cele cu `coverUrl`: cele fara au acum o sursa de
    # rezerva (Open Library dupa ISBN), deci nu mai are sens sa le sarim.
    todo = books
    print(f"[covers] {len(todo)} carti de verificat")

    ok, ok_fallback, failed, skipped = 0, 0, 0, 0
    for i, book in enumerate(todo, 1):
        isbn = book["isbn"]
        if isbn in manifest and (COVERS_DIR / manifest[isbn]).exists():
            skipped += 1
            continue

        scraped = usable_cover_url(book.get("coverUrl"))
        # Intai coperta de la librarie (e a editiei romanesti reale), apoi OL.
        candidates = [(scraped, False)] if scraped else []
        candidates.append((OPEN_LIBRARY_COVER.format(isbn=isbn), True))

        saved = False
        last_error = None
        for url, is_fallback in candidates:
            try:
                resp = requests.get(url, headers=HEADERS, timeout=20)
                resp.raise_for_status()
                if len(resp.content) < MIN_COVER_BYTES:
                    last_error = f"raspuns prea mic ({len(resp.content)}b)"
                    continue
                ext = ext_from(url, resp.headers.get("Content-Type"))
                filename = f"{isbn}{ext}"
                (COVERS_DIR / filename).write_bytes(resp.content)
                manifest[isbn] = filename
                ok += 1
                if is_fallback:
                    ok_fallback += 1
                saved = True
                break
            except Exception as exc:
                last_error = exc
            time.sleep(0.2)

        if not saved:
            print(f"[covers]   {isbn}: EROARE {last_error}", file=sys.stderr)
            failed += 1

        if i % 50 == 0:
            MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"[covers] {i}/{len(todo)} - ok:{ok} failed:{failed} skipped:{skipped}")

        time.sleep(0.2)

    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"[covers] gata - ok:{ok} (din care {ok_fallback} de pe Open Library) "
        f"failed:{failed} skipped:{skipped} total:{len(todo)}"
    )


if __name__ == "__main__":
    main()
