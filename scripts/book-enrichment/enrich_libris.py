#!/usr/bin/env python3
"""Book metadata enrichment from libris.ro - sitemap index + JSON-LD.

Same job as enrich_books.py (ISBNs already in the ShelfShare catalog go in,
metadata comes out, in the same JSON shape import_enriched.py already reads),
but a different route to the product page, because libris is a different site:

  - carturesti.ro: live search per book (/product/json-search), then the
    product page, then CSS selectors over a hand-mapped DOM.
  - libris.ro:     NO search. robots.txt disallows every search route for all
    user agents (/search?*, /s.jsp, /*?fts_fts=, /*?iv.q=, /*?psq=), so we use
    the route the site publishes for crawlers instead - its sitemaps - and go
    straight to product pages, which are not disallowed.

How the match works
-------------------
Product URLs are /carte/<slug>/<id>, where the slug is title+author and there
is no ISBN in it. So the sitemap gives us CANDIDATES, not answers:

  1. --build-index downloads the 27 sitemap-carte.xml pages (~54k books) once
     and stores slug -> url in libris_index.json.
  2. For each wanted book we score its title against the slugs and take the
     best few.
  3. We open those product pages and accept one ONLY if the JSON-LD
     isbn/gtin13 equals the ISBN we asked for.

Step 3 is what makes step 2 safe to be loose. Unlike carturesti - where the
search returns arbitrary products and a title heuristic is the only guard (see
README: an ISBN query once returned a T-shirt) - here every accepted result is
confirmed by the ISBN printed on the page itself. Nothing ships with
isbnVerified=false, so there is no fuzzy tier and no --allow-fuzzy-match.

Cloudflare
----------
libris.ro does not challenge a real Chromium the way carturesti does: three
consecutive product loads in ONE browser context all returned 200. So we keep
a single context and only pace requests, instead of carturesti's
one-fresh-context-per-navigation dance.

Usage:
    python enrich_libris.py --build-index
    python enrich_libris.py --input isbns.txt --output enriched_libris.json
    python enrich_libris.py --isbn 9789734610792 --title "Jurnalul fericirii"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from collections import Counter
from dataclasses import asdict
from pathlib import Path
from random import uniform

from bs4 import BeautifulSoup
from playwright.sync_api import Browser, BrowserContext, Page, sync_playwright

from enrich_books import (
    EnrichedBook,
    PAGE_TIMEOUT_MS,
    USER_AGENT,
    _normalize_isbn,
    _normalize_label,
    _title_similarity,
    _title_tokens,
    read_input,
)

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

HERE = Path(__file__).resolve().parent
DEFAULT_INDEX = HERE / "libris_index.json"

BASE_URL = "https://www.libris.ro"
SITEMAP_INDEX = f"{BASE_URL}/sitemap-new-url-index.xml?nofilename=on"
# Doar sitemap-urile de carte; indexul mai contine categorii, autori, edituri.
BOOK_SITEMAP_MARKER = "sitemap-carte.xml"
PRODUCT_URL_RE = re.compile(r"^https://www\.libris\.ro/carte/([^/]+)/(\d+)$")

SOURCE_NAME = "libris"


# --------------------------------------------------------------------------
# Indexul din sitemap
# --------------------------------------------------------------------------

def build_index(context: BrowserContext, index_path: Path, delay: tuple[float, float]) -> int:
    """Descarca sitemap-urile de carte si scrie slug -> url in index_path."""
    resp = context.request.get(SITEMAP_INDEX, timeout=PAGE_TIMEOUT_MS)
    if resp.status != 200:
        raise RuntimeError(f"sitemap index: HTTP {resp.status}")
    sitemaps = [
        loc.replace("&amp;", "&")
        for loc in re.findall(r"<loc>(.*?)</loc>", resp.text())
        if BOOK_SITEMAP_MARKER in loc
    ]
    print(f"[index] {len(sitemaps)} sitemap-uri de carte")

    entries: dict[str, str] = {}
    for i, sitemap_url in enumerate(sitemaps, start=1):
        if i > 1:
            time.sleep(uniform(*delay))
        r = context.request.get(sitemap_url, timeout=PAGE_TIMEOUT_MS)
        if r.status != 200:
            print(f"[index] {i}/{len(sitemaps)} HTTP {r.status} - sar peste", file=sys.stderr)
            continue
        found = 0
        for loc in re.findall(r"<loc>(.*?)</loc>", r.text()):
            match = PRODUCT_URL_RE.match(loc.replace("&amp;", "&"))
            if match:
                # Slugul e "titlu-autor"; il tinem deja normalizat, ca sa nu
                # renormalizam 54k intrari la fiecare rulare.
                entries[loc] = _normalize_label(match.group(1).replace("-", " "))
                found += 1
        print(f"[index] {i}/{len(sitemaps)}: +{found} (total {len(entries)})")

    payload = {"source": SOURCE_NAME, "entries": [{"u": u, "t": t} for u, t in entries.items()]}
    index_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    print(f"[index] {len(entries)} carti -> {index_path}")
    return len(entries)


class SlugIndex:
    """Index inversat pe cuvintele din slug, ca sa nu scanam 54k intrari/carte."""

    def __init__(self, entries: list[dict]):
        self.urls = [e["u"] for e in entries]
        self.texts = [e["t"] for e in entries]
        self.by_token: dict[str, list[int]] = {}
        for idx, text in enumerate(self.texts):
            for token in set(_title_tokens(text)):
                self.by_token.setdefault(token, []).append(idx)

    @classmethod
    def load(cls, path: Path) -> "SlugIndex":
        if not path.exists():
            raise SystemExit(
                f"Lipseste {path.name}. Ruleaza intai:  python enrich_libris.py --build-index"
            )
        return cls(json.loads(path.read_text(encoding="utf-8"))["entries"])

    def candidates(self, title: str | None, limit: int) -> list[tuple[float, str]]:
        tokens = _title_tokens(title)
        if not tokens:
            return []

        # Prefiltru ieftin: doar intrarile care impart cuvinte cu interogarea.
        # Cerem 2 cuvinte comune cand titlul are de unde sa le dea - un singur
        # cuvant comun scoate mii de candidati fara sa insemne nimic.
        hits: Counter[int] = Counter()
        for token in set(tokens):
            for idx in self.by_token.get(token, ()):
                hits[idx] += 1
        need = 2 if len(set(tokens)) >= 2 else 1
        pool = [idx for idx, n in hits.items() if n >= need]
        if not pool and need > 1:
            pool = list(hits)

        scored = [(_title_similarity(title, self.texts[idx]), self.urls[idx]) for idx in pool]
        scored.sort(key=lambda pair: pair[0], reverse=True)
        return scored[:limit]


# --------------------------------------------------------------------------
# Pagina de produs
# --------------------------------------------------------------------------

def _book_node(soup: BeautifulSoup) -> dict | None:
    """Nodul JSON-LD ["Product","Book"] - toate campurile vin de acolo."""
    for script in soup.find_all("script", attrs={"type": "application/ld+json"}):
        try:
            data = json.loads(script.string or "{}")
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(data, dict):
            continue
        for node in data.get("@graph", []):
            types = node.get("@type")
            types = types if isinstance(types, list) else [types]
            if "Book" in types:
                return node
    return None


def _year(value: object) -> int | None:
    match = re.search(r"\d{4}", str(value or ""))
    return int(match.group()) if match else None


def _int(value: object) -> int | None:
    match = re.search(r"\d+", str(value or ""))
    return int(match.group()) if match else None


def _names(value: object) -> str | None:
    """author/publisher vin ca dict, lista de dict-uri sau simplu string."""
    items = value if isinstance(value, list) else [value]
    names = []
    for item in items:
        name = item.get("name") if isinstance(item, dict) else item
        if name:
            names.append(str(name).strip())
    return ", ".join(names) or None


def _strip_author_suffix(name: str | None, author: str | None) -> str | None:
    """"Jurnalul fericirii - Nicolae Steinhardt" -> "Jurnalul fericirii".

    libris pune autorul in `name`. Conteaza pentru ca rezultatele de aici au
    mereu isbnVerified=true, iar import_enriched.py suprascrie titlul din DB
    exact pentru intrarile verificate - fara curatarea asta am scrie autorul
    in coloana `title` a fiecarei carti importate de aici.
    """
    if not name or not author:
        return name
    # Taiem pe separatorul brut, nu pe lungimea sufixului normalizat: normalizarea
    # scoate punctuatia, deci " - Jorge Luis Borges, Margarita Guerrero" si
    # "jorge luis borges margarita guerrero" n-au aceeasi lungime, iar taierea
    # dupa a doua ar manca un caracter din prima ("...Borge").
    head, separator, tail = name.rpartition(" - ")
    if not separator:
        return name
    # Set de cuvinte, nu sir exact: libris scrie acelasi autor in ordini diferite
    # in cele doua campuri ("... - Yasunari Kawabata" cu author "Kawabata
    # Yasunari"), iar comparatia pe sir ar rata exact cazurile astea.
    def words(text: str) -> frozenset[str]:
        return frozenset(_normalize_label(text).split())

    known = {words(author)}
    known.update(words(part) for part in author.split(","))
    tail_words = words(tail)
    if tail_words and tail_words in known:
        return head.strip() or name
    return name


def parse_product(html: str, url: str, wanted_isbn: str) -> EnrichedBook | None:
    """-> EnrichedBook daca ISBN-ul paginii e chiar cel cerut, altfel None."""
    node = _book_node(BeautifulSoup(html, "html.parser"))
    if not node:
        return None

    page_isbn = _normalize_isbn(str(node.get("isbn") or node.get("gtin13") or ""))
    if not page_isbn or page_isbn != _normalize_isbn(wanted_isbn):
        return None

    book_format = str(node.get("bookFormat") or "")
    image = node.get("image")
    author = _names(node.get("author"))
    return EnrichedBook(
        isbn=_normalize_isbn(wanted_isbn),
        source=SOURCE_NAME,
        productUrl=url,
        title=_strip_author_suffix(node.get("name") or None, author),
        author=author,
        publisher=_names(node.get("publisher")),
        description=node.get("description") or None,
        coverUrl=image if isinstance(image, str) else None,
        publishedYear=_year(node.get("datePublished")),
        pageCount=_int(node.get("numberOfPages")),
        coverType=node.get("bookEdition") or book_format.rsplit("/", 1)[-1] or None,
        collection=node.get("category") or None,
        language=node.get("inLanguage") or None,
        sourceIsbn=page_isbn,
        # Nu exista alt mod de a ajunge aici: potrivirea e pe ISBN exact.
        isbnVerified=True,
    )


class LibrisScraper:
    def __init__(self, delay_range: tuple[float, float], headless: bool = True,
                 debug_html_dir: str | None = None):
        self._pw = sync_playwright().start()
        self.browser: Browser = self._pw.chromium.launch(headless=headless)
        # Un singur context: libris nu da challenge la navigari repetate.
        self.context: BrowserContext = self.browser.new_context(
            user_agent=USER_AGENT, locale="ro-RO", viewport={"width": 1280, "height": 900}
        )
        self.page: Page = self.context.new_page()
        self.delay_range = delay_range
        self.debug_html_dir = debug_html_dir
        self._debug_counter = 0
        self._navigated = False

    def __enter__(self) -> "LibrisScraper":
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.close()

    def close(self) -> None:
        self.context.close()
        self.browser.close()
        self._pw.stop()

    def fetch(self, url: str) -> str | None:
        if self._navigated:
            time.sleep(uniform(*self.delay_range))
        self._navigated = True
        try:
            resp = self.page.goto(url, timeout=PAGE_TIMEOUT_MS, wait_until="domcontentloaded")
        except Exception as exc:  # noqa: BLE001 - orice esec de navigare e non-fatal
            print(f"  [!] Navigare la {url} a esuat: {exc}", file=sys.stderr)
            return None
        if resp is not None and resp.status >= 400:
            print(f"  [!] {url} -> HTTP {resp.status}", file=sys.stderr)
            return None
        html = self.page.content()
        if self.debug_html_dir:
            self._debug_counter += 1
            path = os.path.join(self.debug_html_dir, f"{self._debug_counter:03d}.html")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(f"<!-- {url} -->\n{html}")
        return html

    def enrich_one(self, isbn: str, title: str, index: SlugIndex,
                   max_candidates: int) -> EnrichedBook:
        candidates = index.candidates(title, max_candidates)
        if not candidates:
            return EnrichedBook(isbn=_normalize_isbn(isbn), source=SOURCE_NAME,
                                error="no candidate in libris sitemap index")
        for score, url in candidates:
            html = self.fetch(url)
            if not html:
                continue
            book = parse_product(html, url, isbn)
            if book is not None:
                book.titleMatchScore = round(score, 3)
                return book
        tried = ", ".join(f"{score:.2f}" for score, _ in candidates)
        return EnrichedBook(
            isbn=_normalize_isbn(isbn), source=SOURCE_NAME,
            error=f"no exact ISBN match in top-{len(candidates)} candidates (scoruri: {tried})",
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--build-index", action="store_true",
                        help="(Re)descarca sitemap-urile si scrie libris_index.json, apoi iese")
    parser.add_argument("--index", default=str(DEFAULT_INDEX), help="Fisierul de index")
    parser.add_argument("--input", help="Fisier cu ISBN-uri ('isbn' sau 'isbn,titlu' pe linie)")
    parser.add_argument("--isbn", help="Un singur ISBN, pentru teste rapide")
    parser.add_argument("--title", help="Titlul cartii - obligatoriu, e cheia de cautare in index")
    parser.add_argument("--output", default="enriched_libris.json", help="Fisier JSON de iesire")
    parser.add_argument("--max-candidates", type=int, default=3,
                        help="Cate pagini de produs incercam per carte inainte sa renuntam")
    parser.add_argument("--delay-min", type=float, default=3.0,
                        help="Pauza minima intre navigari (sec)")
    parser.add_argument("--delay-max", type=float, default=6.0,
                        help="Pauza maxima intre navigari (sec)")
    parser.add_argument("--headed", action="store_true", help="Deschide fereastra browserului")
    parser.add_argument("--debug-html-dir", help="Salveaza fiecare pagina navigata ca .html")
    args = parser.parse_args()

    index_path = Path(args.index)
    delay = (args.delay_min, args.delay_max)

    if args.build_index:
        with LibrisScraper(delay, headless=not args.headed) as scraper:
            # O navigare normala intai: cererile de sitemap merg pe sesiunea ei.
            scraper.fetch(BASE_URL + "/")
            build_index(scraper.context, index_path, delay)
        return

    if not args.input and not args.isbn:
        parser.error("da --input, --isbn sau --build-index")

    entries = [(args.isbn, args.title)] if args.isbn else list(read_input(args.input))
    if not entries:
        print("Nimic de procesat (fisier gol?).", file=sys.stderr)
        sys.exit(1)

    index = SlugIndex.load(index_path)
    print(f"[index] {len(index.urls)} carti in {index_path.name}")

    if args.debug_html_dir:
        os.makedirs(args.debug_html_dir, exist_ok=True)

    results: list[dict] = []
    with LibrisScraper(delay, headless=not args.headed,
                       debug_html_dir=args.debug_html_dir) as scraper:
        for i, (isbn, title) in enumerate(entries, start=1):
            print(f"[{i}/{len(entries)}] {isbn} ({title or '-'})")
            if not title:
                # Fara titlu n-avem cu ce cauta in index: URL-ul nu contine ISBN.
                book = EnrichedBook(isbn=_normalize_isbn(isbn), source=SOURCE_NAME,
                                    error="fara titlu in input - indexul se cauta pe titlu")
            else:
                book = scraper.enrich_one(isbn, title, index, args.max_candidates)
            if book.error:
                print(f"    -> {book.error}")
            else:
                print(f"    -> {book.title} ({book.publisher or '?'}) {book.productUrl}")
            results.append(asdict(book))

    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(results, handle, ensure_ascii=False, indent=2)

    ok = sum(1 for r in results if not r.get("error"))
    print(f"\n{ok}/{len(results)} imbogatite cu succes -> {args.output}")


if __name__ == "__main__":
    main()
