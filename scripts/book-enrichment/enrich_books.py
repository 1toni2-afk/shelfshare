#!/usr/bin/env python3
"""Book metadata enrichment scraper for ShelfShare.

Input: a list of ISBNs (optionally "isbn,title" per line) already present in
the catalog (imported from Google Books / Open Library), which is where the
cover/description/detail data tends to be missing or thin.

Output: one JSON object per ISBN with whatever the source pages exposed -
cover image URL, title/author/publisher, a Romanian description, and the
detail-table fields (ISBN, an apariție, nr. pagini, format, tip copertă,
colecție, limbă). This script does NOT touch the database or discover new
books - it is pure enrichment for ISBNs you already have.

Sources (robots.txt checked, both permissive on product pages):
  - carturesti.ro
  - elefant.ro

IMPORTANT - selectors are best-effort: this script extracts cover/title/
description primarily from Open Graph meta tags (og:image, og:title,
og:description), which are far more stable across a site's markup changes
than hand-picked CSS classes. The detail table (ISBN/an/pagini/format/etc.)
is parsed by matching row *labels* (tolerant of diacritics and spacing)
rather than by class name, for the same reason. Still, verify a handful of
results against the live pages before trusting a large batch - e-commerce
markup does change, and this was not (and could not be, from this sandbox,
which sits behind Cloudflare's bot challenge on both sites) validated
against the live DOM.

Usage:
    pip install -r requirements.txt
    python enrich_books.py --input isbns.txt --output enriched.json
    python enrich_books.py --input isbns.txt --output enriched.json --source elefant
    python enrich_books.py --isbn 9789734692765 --source carturesti

Input file format (one entry per line, blank lines and '#' comments ignored):
    9789734692765
    9786063312345,Numele trandafirului
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
from dataclasses import asdict, dataclass, field
from random import uniform
from typing import Iterable
from urllib.parse import quote_plus, urljoin

import requests
from bs4 import BeautifulSoup

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 ShelfShareEnrichmentBot/1.0"
)

REQUEST_TIMEOUT_SECONDS = 15

# Etichetele căutate în tabelul de detalii, cu variante (diacritice/fără,
# ortografii alternative). Comparația se face pe text normalizat (vezi
# `_normalize_label`), deci fiecare variantă de mai jos e deja "curată".
DETAIL_LABELS: dict[str, tuple[str, ...]] = {
    "isbn": ("isbn",),
    "publishedYear": ("an aparitie", "anul aparitiei", "an publicare"),
    "pageCount": ("nr pagini", "numar pagini", "numar de pagini"),
    "format": ("format",),
    "coverType": ("tip coperta", "coperta"),
    "collection": ("colectie", "seria"),
    "language": ("limba",),
}


def _normalize_label(text: str) -> str:
    """Diacritice + spații/punctuație variabile -> cheie comparabilă simplu."""
    decomposed = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", ascii_only.lower()).strip()


@dataclass
class EnrichedBook:
    isbn: str
    source: str
    productUrl: str | None = None
    title: str | None = None
    author: str | None = None
    publisher: str | None = None
    description: str | None = None
    coverUrl: str | None = None
    publishedYear: int | None = None
    pageCount: int | None = None
    format: str | None = None
    coverType: str | None = None
    collection: str | None = None
    language: str | None = None
    error: str | None = None


@dataclass
class SiteAdapter:
    """Cum se caută și se parsează o carte pe un anumit site.

    Fiecare adapter face DOAR două lucruri specifice site-ului: construiește
    URL-ul de căutare și alege primul rezultat plauzibil dintr-o pagină de
    căutare. Restul (extragerea din pagina de produs) e comun, pe OG tags +
    potrivire de etichete, tocmai ca să nu depindă de clasele CSS ale fiecărui
    site (mult mai fragile).
    """

    name: str
    base_url: str
    search_path: str  # cu `{query}` de interpolat
    result_link_selector: str  # selector CSS pentru linkurile din rezultate

    def search_url(self, query: str) -> str:
        return urljoin(self.base_url, self.search_path.format(query=quote_plus(query)))

    def pick_product_url(self, soup: BeautifulSoup) -> str | None:
        for link in soup.select(self.result_link_selector):
            href = link.get("href")
            if href:
                return urljoin(self.base_url, href)
        return None


SITE_ADAPTERS: dict[str, SiteAdapter] = {
    "carturesti": SiteAdapter(
        name="carturesti",
        base_url="https://carturesti.ro",
        search_path="/cauta?q={query}",
        result_link_selector="a.product-item, a[href*='/carte/'], .product-list a",
    ),
    "elefant": SiteAdapter(
        name="elefant",
        base_url="https://www.elefant.ro",
        search_path="/cautare/?q={query}",
        result_link_selector="a.product-title, a[href*='/carti/'], .product-list a",
    ),
}


class Scraper:
    def __init__(self, delay_range: tuple[float, float] = (1.0, 2.0)):
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": USER_AGENT,
                "Accept-Language": "ro-RO,ro;q=0.9,en;q=0.5",
            }
        )
        self.delay_range = delay_range

    def _throttled_get(self, url: str) -> requests.Response | None:
        time.sleep(uniform(*self.delay_range))
        try:
            response = self.session.get(url, timeout=REQUEST_TIMEOUT_SECONDS)
            response.raise_for_status()
            return response
        except requests.RequestException as exc:
            print(f"  [!] GET {url} a eșuat: {exc}", file=sys.stderr)
            return None

    def enrich_one(self, isbn: str, title_hint: str | None, adapter: SiteAdapter) -> EnrichedBook:
        query = isbn if not title_hint else f"{isbn} {title_hint}"
        result = EnrichedBook(isbn=isbn, source=adapter.name)

        search_response = self._throttled_get(adapter.search_url(query))
        if search_response is None:
            result.error = "search request failed"
            return result

        search_soup = BeautifulSoup(search_response.text, "html.parser")
        product_url = adapter.pick_product_url(search_soup)
        if not product_url:
            # Fallback: încearcă doar cu titlul, dacă ISBN-ul singur n-a găsit nimic.
            if title_hint:
                search_response = self._throttled_get(adapter.search_url(title_hint))
                if search_response is not None:
                    search_soup = BeautifulSoup(search_response.text, "html.parser")
                    product_url = adapter.pick_product_url(search_soup)
        if not product_url:
            result.error = "no search result found"
            return result

        result.productUrl = product_url
        product_response = self._throttled_get(product_url)
        if product_response is None:
            result.error = "product page request failed"
            return result

        self._parse_product_page(BeautifulSoup(product_response.text, "html.parser"), result)
        return result

    def _parse_product_page(self, soup: BeautifulSoup, result: EnrichedBook) -> None:
        result.coverUrl = self._meta(soup, "og:image")
        result.title = self._meta(soup, "og:title") or self._first_text(soup, "h1")
        result.description = self._meta(soup, "og:description") or self._first_text(
            soup, "[class*='descri']"
        )

        author = self._first_text(soup, "[class*='author'], [class*='autor']")
        if author:
            result.author = re.sub(r"(?i)^autor:?\s*", "", author).strip()

        publisher = self._first_text(soup, "[class*='publisher'], [class*='editura']")
        if publisher:
            result.publisher = re.sub(r"(?i)^editur[aă]:?\s*", "", publisher).strip()

        details = self._extract_detail_table(soup)
        for field_name, raw_value in details.items():
            if field_name == "publishedYear":
                match = re.search(r"\d{4}", raw_value)
                if match:
                    result.publishedYear = int(match.group())
            elif field_name == "pageCount":
                match = re.search(r"\d+", raw_value)
                if match:
                    result.pageCount = int(match.group())
            else:
                setattr(result, field_name, raw_value.strip())

    def _extract_detail_table(self, soup: BeautifulSoup) -> dict[str, str]:
        """Parcurge orice pereche etichetă/valoare plauzibilă (rânduri de tabel,
        liste de definiții, sau div-uri de tip "specificații") și potrivește
        eticheta normalizată cu DETAIL_LABELS - independent de markup-ul exact.
        """
        found: dict[str, str] = {}
        candidate_rows: list[tuple[str, str]] = []

        for row in soup.select("tr"):
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                candidate_rows.append((cells[0].get_text(" ", strip=True), cells[1].get_text(" ", strip=True)))

        for dt in soup.select("dt"):
            dd = dt.find_next_sibling("dd")
            if dd:
                candidate_rows.append((dt.get_text(" ", strip=True), dd.get_text(" ", strip=True)))

        for label_text, value_text in candidate_rows:
            normalized = _normalize_label(label_text)
            if not normalized or not value_text:
                continue
            for field_name, variants in DETAIL_LABELS.items():
                if field_name in found:
                    continue
                if any(normalized == v or normalized.startswith(v) for v in variants):
                    found[field_name] = value_text
                    break

        return found

    @staticmethod
    def _meta(soup: BeautifulSoup, property_name: str) -> str | None:
        tag = soup.find("meta", attrs={"property": property_name}) or soup.find(
            "meta", attrs={"name": property_name}
        )
        content = tag.get("content") if tag else None
        return content.strip() if content else None

    @staticmethod
    def _first_text(soup: BeautifulSoup, selector: str) -> str | None:
        tag = soup.select_one(selector)
        if not tag:
            return None
        text = tag.get_text(" ", strip=True)
        return text or None


def read_input(path: str) -> Iterable[tuple[str, str | None]]:
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split(",", 1)]
            isbn = parts[0]
            title_hint = parts[1] if len(parts) > 1 and parts[1] else None
            yield isbn, title_hint


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", help="Fișier cu ISBN-uri (unul pe linie, opțional 'isbn,titlu')")
    parser.add_argument("--isbn", help="Un singur ISBN, pentru teste rapide")
    parser.add_argument("--title", help="Titlu opțional, folosit ca query alături de --isbn")
    parser.add_argument("--output", default="enriched.json", help="Fișier JSON de ieșire")
    parser.add_argument(
        "--source",
        choices=["carturesti", "elefant", "both"],
        default="both",
        help="Ce site(uri) să interogheze (implicit: ambele, carturesti primul)",
    )
    parser.add_argument("--delay-min", type=float, default=1.0, help="Pauză minimă între request-uri (sec)")
    parser.add_argument("--delay-max", type=float, default=2.0, help="Pauză maximă între request-uri (sec)")
    args = parser.parse_args()

    if not args.input and not args.isbn:
        parser.error("dă --input sau --isbn")

    entries: list[tuple[str, str | None]] = (
        [(args.isbn, args.title)] if args.isbn else list(read_input(args.input))
    )
    if not entries:
        print("Nimic de procesat (fișier gol?).", file=sys.stderr)
        sys.exit(1)

    adapters = (
        [SITE_ADAPTERS[args.source]]
        if args.source != "both"
        else [SITE_ADAPTERS["carturesti"], SITE_ADAPTERS["elefant"]]
    )

    scraper = Scraper(delay_range=(args.delay_min, args.delay_max))
    results: list[dict] = []

    for index, (isbn, title_hint) in enumerate(entries, start=1):
        print(f"[{index}/{len(entries)}] {isbn} ({title_hint or '—'})")
        best: EnrichedBook | None = None
        for adapter in adapters:
            candidate = scraper.enrich_one(isbn, title_hint, adapter)
            if candidate.error is None:
                best = candidate
                break
            best = best or candidate
        results.append(asdict(best))

    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(results, handle, ensure_ascii=False, indent=2)

    ok = sum(1 for r in results if not r.get("error"))
    print(f"\n{ok}/{len(results)} îmbogățite cu succes -> {args.output}")


if __name__ == "__main__":
    main()
