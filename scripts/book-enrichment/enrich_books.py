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

Sources:
  - carturesti.ro  - working (see "Cloudflare" below)
  - elefant.ro     - BLOCKED, see ELEFANT_BLOCKED_NOTE

Cloudflare
----------
Both sites sit behind Cloudflare, which 403s plain `requests` calls (even
with a browser-like User-Agent) - that's IP/fingerprint based, not something
a User-Agent string can talk around. This script drives a real headless
Chromium via Playwright instead.

Measured behaviour on carturesti.ro (2026-08, see README):
  * the FIRST navigation of a fresh browser session passes Cloudflare's
    passive check and serves real content;
  * every SUBSEQUENT navigation in that same session gets a managed
    challenge ("Doar un moment..." - the Romanian "Just a moment...") which a
    Playwright-driven Chromium never solves, headless or headed, no matter
    how long it waits (tested up to 2 min of cooldown).

So the scraper opens a fresh browser context per navigation and paces itself
with a long delay between them. Same IP, same User-Agent, same browser
fingerprint - no spoofing, no proxy rotation; just a clean session and a slow,
polite request rate. If that stops working, stop and reconsider rather than
reaching for evasion.

Result correctness
------------------
Carturesti's search is fuzzy (Solr): searching ISBN 9789734692765 happily
returns 9789734692965, a completely different book. Taking "the first search
result" therefore silently writes WRONG metadata onto a book. This script
reads the site's own /product/json-search response (which carries each hit's
`code`, i.e. its ISBN) and only accepts a hit whose ISBN equals the one asked
for. If nothing matches exactly the record comes back with an error instead
of a plausible-looking lie. `--allow-fuzzy-match` opts out, and flags every
such record with `"isbnVerified": false`.

Usage:
    pip install -r requirements.txt
    playwright install chromium
    python enrich_books.py --input isbns.txt --output enriched.json
    python enrich_books.py --isbn 9789735965006

Input file format (one entry per line, blank lines and '#' comments ignored):
    9789735965006
    9786063312345,Numele trandafirului
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
from dataclasses import asdict, dataclass
from random import uniform
from typing import Iterable
from urllib.parse import quote, urljoin

from bs4 import BeautifulSoup
from playwright.sync_api import Browser, BrowserContext, Page, sync_playwright

# stdout on a Windows console defaults to cp1252, which blows up on the
# diacritics in both our own messages and the scraped titles.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):  # pragma: no cover - non-reconfigurable stream
        pass

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

PAGE_TIMEOUT_MS = 45_000

# Cât așteptăm ca rezultatele randate de Angular să apară în DOM.
RENDER_TIMEOUT_MS = 20_000

# Titlurile paginilor de challenge Cloudflare. "Doar un moment..." e varianta
# românească a lui "Just a moment..." și e cea pe care o servește carturesti.ro
# - fără ea am parsa pagina de challenge ca și cum ar fi conținut real.
# Comparația se face pe text normalizat (fără diacritice), vezi `_is_challenge`.
CHALLENGE_TITLE_MARKERS = (
    "just a moment",
    "doar un moment",
    "verificam daca conexiunea",
    "checking your browser",
    "403 forbidden",
)

# Challenge-ul *nu* se rezolvă singur sub Playwright (măsurat: >120s fără
# efect), deci nu așteptăm mult degeaba - doar cât să prindem un redirect
# întârziat, apoi raportăm.
CHALLENGE_WAIT_SECONDS = 8

ELEFANT_BLOCKED_NOTE = (
    "elefant.ro serves a hard Cloudflare 403 for the whole origin (homepage "
    "included) to a real Chromium, headless or headed - an active block, not a "
    "solvable challenge. Left in place so the adapter is ready if that changes."
)

# Etichetele căutate în tabelul de detalii, cu variante (diacritice/fără,
# ortografii alternative). Comparația se face pe text normalizat (vezi
# `_normalize_label`), deci fiecare variantă de mai jos e deja "curată".
# Cele marcate `# carturesti` sunt confirmate pe DOM-ul real.
DETAIL_LABELS: dict[str, tuple[str, ...]] = {
    "sourceIsbn": ("isbn",),  # carturesti
    "publishedYear": ("data publicarii", "an aparitie", "anul aparitiei", "an publicare"),  # carturesti
    "pageCount": ("nr pagini", "numar pagini", "numar de pagini"),  # carturesti
    "format": ("format", "dimensiuni"),  # carturesti: "Dimensiuni"
    "coverType": ("tip coperta", "coperta"),  # carturesti
    "collection": ("colectie", "seria", "serie"),  # carturesti
    "language": ("limba",),  # carturesti
    "publisher": ("editura",),  # carturesti
}


def _normalize_label(text: str) -> str:
    """Diacritice + spații/punctuație variabile -> cheie comparabilă simplu."""
    decomposed = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", ascii_only.lower()).strip()


def _normalize_isbn(value: str | None) -> str:
    """ISBN-uri comparabile: doar cifre și X final (fără cratime/spații)."""
    return re.sub(r"[^0-9xX]", "", value or "").upper()


def _is_challenge(title: str | None) -> bool:
    normalized = _normalize_label(title or "")
    return any(marker in normalized for marker in CHALLENGE_TITLE_MARKERS)


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
    sourceIsbn: str | None = None
    isbnVerified: bool = False
    error: str | None = None


@dataclass
class SiteAdapter:
    """Cum se caută și se parsează o carte pe un anumit site.

    Adapterul știe doar ce e specific site-ului: URL-ul de căutare, endpoint-ul
    JSON pe care îl apelează singură pagina de rezultate, și selectorul de
    rezervă pentru linkurile de produs. Restul (extragerea din pagina de
    produs) e comun.
    """

    name: str
    base_url: str
    search_path: str  # cu `{query}` de interpolat
    result_link_selector: str  # selector CSS pentru linkurile din rezultate
    search_api_marker: str | None = None  # substring din URL-ul XHR de căutare
    blocked_note: str | None = None

    def search_url(self, query: str) -> str:
        # `quote` (nu `quote_plus`): search_path poate fi un segment de path
        # (ex. /product/search/{query}), unde spațiile trebuie %20, nu '+'.
        return urljoin(self.base_url, self.search_path.format(query=quote(query, safe="")))

    def pick_product_url(self, soup: BeautifulSoup) -> str | None:
        for link in soup.select(self.result_link_selector):
            href = link.get("href")
            if href:
                return urljoin(self.base_url, href)
        return None

    def products_from_api(self, payload: dict) -> list[dict]:
        """Normalizează răspunsul JSON al căutării la {isbn, url, title}."""
        products: list[dict] = []
        for item in payload.get("products") or []:
            gtm = item.get("gtmData") or {}
            products.append(
                {
                    "isbn": _normalize_isbn(item.get("code") or gtm.get("item_ISBN_code")),
                    "url": urljoin(self.base_url, item.get("url") or ""),
                    "title": item.get("name"),
                }
            )
        return products


SITE_ADAPTERS: dict[str, SiteAdapter] = {
    # Verificat pe DOM-ul real: pagina de rezultate e un SPA AngularJS care
    # cere /product/json-search și randează tile-urile în
    # .product-grid-container > a.select-item-event[href^="/carte/"].
    "carturesti": SiteAdapter(
        name="carturesti",
        base_url="https://carturesti.ro",
        search_path="/product/search/{query}",
        result_link_selector=".product-grid-container a[href*='/carte/'], a.select-item-event[href*='/carte/']",
        search_api_marker="/product/json-search",
    ),
    "elefant": SiteAdapter(
        name="elefant",
        base_url="https://www.elefant.ro",
        search_path="/search?SearchTerm={query}",
        # Neverificat: originea răspunde 403 pe tot site-ul, deci n-am putut
        # inspecta DOM-ul real al paginii de rezultate.
        result_link_selector="a.product-title, a[href*='/carti/'], .product-list a",
        blocked_note=ELEFANT_BLOCKED_NOTE,
    ),
}


class Scraper:
    """Navighează cu un Chromium real (Playwright), nu cu request-uri HTTP
    brute - Cloudflare respinge (403) request-urile `requests`/`curl` pe baza
    reputației IP-ului și a amprentei TLS/HTTP2, indiferent de User-Agent.

    Deschide un context de browser nou pentru fiecare navigare: pe
    carturesti.ro doar prima cerere a unei sesiuni trece de verificarea
    pasivă, iar challenge-ul primit la a doua nu se rezolvă niciodată sub
    Playwright. Vezi docstring-ul modulului.
    """

    def __init__(
        self,
        delay_range: tuple[float, float] = (6.0, 10.0),
        headless: bool = True,
        debug_html_dir: str | None = None,
        reuse_session: bool = False,
    ):
        self._playwright = sync_playwright().start()
        self.browser: Browser = self._playwright.chromium.launch(headless=headless)
        self.delay_range = delay_range
        self.debug_html_dir = debug_html_dir
        self.reuse_session = reuse_session
        self._shared_context: BrowserContext | None = None
        self._debug_counter = 0
        self._first_navigation = True

    def _new_context(self) -> BrowserContext:
        return self.browser.new_context(
            user_agent=USER_AGENT,
            locale="ro-RO",
            viewport={"width": 1280, "height": 900},
        )

    def close(self) -> None:
        if self._shared_context is not None:
            self._shared_context.close()
        self.browser.close()
        self._playwright.stop()

    def __enter__(self) -> "Scraper":
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.close()

    def _save_debug(self, html: str, url: str) -> None:
        if not self.debug_html_dir:
            return
        self._debug_counter += 1
        path = os.path.join(self.debug_html_dir, f"{self._debug_counter:03d}.html")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(f"<!-- {url} -->\n{html}")
        print(f"  [debug] pagină salvată în {path}", file=sys.stderr)

    def _navigate(
        self,
        url: str,
        wait_selector: str | None = None,
        api_marker: str | None = None,
    ) -> tuple[str | None, dict | None, str | None]:
        """-> (html, payload JSON al căutării, mesaj de eroare)."""
        # Prima navigare nu așteaptă degeaba; restul sunt distanțate.
        if self._first_navigation:
            self._first_navigation = False
        else:
            time.sleep(uniform(*self.delay_range))

        if self.reuse_session:
            if self._shared_context is None:
                self._shared_context = self._new_context()
            context = self._shared_context
        else:
            context = self._new_context()

        page: Page = context.new_page()
        captured: dict[str, str] = {}

        if api_marker:

            def on_response(response) -> None:  # noqa: ANN001 - tip Playwright intern
                if api_marker in response.url and response.status == 200 and "body" not in captured:
                    try:
                        captured["body"] = response.text()
                    except Exception:  # noqa: BLE001 - corpul poate fi deja eliberat
                        pass

            page.on("response", on_response)

        try:
            page.goto(url, timeout=PAGE_TIMEOUT_MS, wait_until="domcontentloaded")
        except Exception as exc:  # noqa: BLE001 - orice eșec de navigare e non-fatal aici
            print(f"  [!] Navigare la {url} a eșuat: {exc}", file=sys.stderr)
            self._release(context, page)
            return None, None, "navigation failed"

        if _is_challenge(page.title()):
            # Nu se rezolvă singur sub Playwright, dar mai lăsăm o fereastră
            # scurtă în caz că e doar un redirect întârziat.
            deadline = time.time() + CHALLENGE_WAIT_SECONDS
            while time.time() < deadline and _is_challenge(page.title()):
                page.wait_for_timeout(1000)
            if _is_challenge(page.title()):
                print(f"  [!] Cloudflare a blocat {url} ({page.title()!r})", file=sys.stderr)
                self._save_debug(page.content(), url)
                self._release(context, page)
                return None, None, "blocked by Cloudflare"

        # Pagina de rezultate e randată de Angular după domcontentloaded, deci
        # așteptăm fie XHR-ul de căutare, fie tile-urile din DOM.
        if api_marker:
            deadline = time.time() + RENDER_TIMEOUT_MS / 1000
            while time.time() < deadline and "body" not in captured:
                page.wait_for_timeout(250)
        if wait_selector:
            try:
                page.wait_for_selector(wait_selector, timeout=RENDER_TIMEOUT_MS)
            except Exception:  # noqa: BLE001 - lipsa selectorului e un rezultat valid (0 hits)
                pass

        html = page.content()
        self._save_debug(html, url)
        self._release(context, page)

        payload = None
        if captured.get("body"):
            try:
                payload = json.loads(captured["body"])
            except json.JSONDecodeError:
                payload = None
        return html, payload, None

    def _release(self, context: BrowserContext, page: Page) -> None:
        try:
            page.close()
        except Exception:  # noqa: BLE001
            pass
        if not self.reuse_session:
            try:
                context.close()
            except Exception:  # noqa: BLE001
                pass

    def enrich_one(
        self,
        isbn: str,
        title_hint: str | None,
        adapter: SiteAdapter,
        allow_fuzzy: bool = False,
    ) -> EnrichedBook:
        result = EnrichedBook(isbn=isbn, source=adapter.name)
        wanted = _normalize_isbn(isbn)

        # Căutăm după ISBN: e singurul termen care poate fi verificat exact.
        # `title_hint` rămâne doar ca plasă de siguranță (--allow-fuzzy-match).
        html, payload, nav_error = self._navigate(
            adapter.search_url(isbn),
            wait_selector=adapter.result_link_selector,
            api_marker=adapter.search_api_marker,
        )
        if nav_error:
            result.error = nav_error
            return result

        candidates: list[dict] = adapter.products_from_api(payload) if payload else []
        exact = next((c for c in candidates if c["isbn"] and c["isbn"] == wanted), None)

        if exact:
            result.productUrl = exact["url"]
            result.isbnVerified = True
        elif allow_fuzzy:
            fallback_url = candidates[0]["url"] if candidates else None
            if not fallback_url and html:
                fallback_url = adapter.pick_product_url(BeautifulSoup(html, "html.parser"))
            if not fallback_url and title_hint:
                html2, payload2, _ = self._navigate(
                    adapter.search_url(title_hint),
                    wait_selector=adapter.result_link_selector,
                    api_marker=adapter.search_api_marker,
                )
                more = adapter.products_from_api(payload2) if payload2 else []
                if more:
                    fallback_url = more[0]["url"]
                elif html2:
                    fallback_url = adapter.pick_product_url(BeautifulSoup(html2, "html.parser"))
            if not fallback_url:
                result.error = "no search result found"
                return result
            result.productUrl = fallback_url
            result.isbnVerified = False
        else:
            # Căutarea e fuzzy: fără potrivire exactă pe ISBN am scrie datele
            # altei cărți. Mai bine un rezultat gol decât unul greșit.
            result.error = (
                f"no exact ISBN match ({len(candidates)} fuzzy result(s); "
                "use --allow-fuzzy-match to accept them)"
            )
            return result

        product_html, _, nav_error = self._navigate(result.productUrl)
        if nav_error:
            result.error = nav_error
            return result

        self._parse_product_page(BeautifulSoup(product_html, "html.parser"), result)

        if result.sourceIsbn and _normalize_isbn(result.sourceIsbn) == wanted:
            result.isbnVerified = True
        return result

    def _parse_product_page(self, soup: BeautifulSoup, result: EnrichedBook) -> None:
        ld = self._product_ld_json(soup)

        # og:image e coperta la rezoluție plină; JSON-LD dă doar thumb-ul -240.
        result.coverUrl = self._meta(soup, "og:image") or (ld.get("image") if ld else None)
        result.title = (
            self._first_text(soup, "h1.titluProdus")
            or self._meta(soup, "og:title")
            or (ld.get("name") if ld else None)
            or self._first_text(soup, "h1")
        )

        # .descriereProdus e textul randat (diacritice corecte, fără taguri);
        # og:description conține HTML brut și entități (&icirc;), deci e doar
        # rezerva. Pot exista mai multe noduri, primul plin e cel bun.
        for node in soup.select(".descriereProdus, [class*='descriere'], [class*='descri']"):
            text = node.get_text(" ", strip=True)
            if text:
                result.description = text
                break
        if not result.description:
            raw = self._meta(soup, "og:description") or (ld.get("description") if ld else None)
            if raw:
                result.description = BeautifulSoup(raw, "html.parser").get_text(" ", strip=True)

        # Autorul e în .autorProdus (care mai conține și butonul "Alertă când
        # apare o carte nouă"), deci luăm doar linkurile /autor/.
        authors = [
            a.get_text(" ", strip=True)
            for a in soup.select(".autorProdus a[href*='/autor/']")
            if a.get_text(strip=True)
        ]
        if authors:
            result.author = ", ".join(dict.fromkeys(authors))

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

        if ld:
            brand = ld.get("brand") if isinstance(ld.get("brand"), dict) else None
            result.publisher = result.publisher or (brand.get("name") if brand else None)
            result.sourceIsbn = result.sourceIsbn or ld.get("GTIN13") or ld.get("sku")

    def _extract_detail_table(self, soup: BeautifulSoup) -> dict[str, str]:
        """Parcurge orice pereche etichetă/valoare plauzibilă și potrivește
        eticheta normalizată cu DETAIL_LABELS - independent de markup-ul exact.
        """
        found: dict[str, str] = {}
        candidate_rows: list[tuple[str, str]] = []

        # carturesti.ro: <div class="productAttr">
        #                  <span class="productAttrLabel">Nr. pagini: </span><div>64</div>
        #                </div>
        # Valoarea nu e mereu într-un tag propriu ("Dimensiuni" o are ca text
        # liber), deci o luăm ca "textul blocului minus eticheta".
        for attr in soup.select(".productAttr"):
            label_node = attr.select_one(".productAttrLabel")
            if not label_node:
                continue
            label_text = label_node.get_text(" ", strip=True)
            whole = attr.get_text(" ", strip=True)
            value_text = whole[len(label_text) :] if whole.startswith(label_text) else whole
            candidate_rows.append((label_text, value_text.strip().lstrip(":").strip()))

        for row in soup.select("tr"):
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                candidate_rows.append(
                    (cells[0].get_text(" ", strip=True), cells[1].get_text(" ", strip=True))
                )

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
    def _product_ld_json(soup: BeautifulSoup) -> dict | None:
        for script in soup.find_all("script", attrs={"type": "application/ld+json"}):
            raw = script.string or script.get_text()
            if not raw or '"Product"' not in raw:
                continue
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if isinstance(data, dict) and data.get("@type") == "Product":
                return data
        return None

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
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--input", help="Fișier cu ISBN-uri (unul pe linie, opțional 'isbn,titlu')")
    parser.add_argument("--isbn", help="Un singur ISBN, pentru teste rapide")
    parser.add_argument("--title", help="Titlu opțional, folosit ca query de rezervă (--allow-fuzzy-match)")
    parser.add_argument("--output", default="enriched.json", help="Fișier JSON de ieșire")
    parser.add_argument(
        "--source",
        choices=["carturesti", "elefant", "both"],
        default="carturesti",
        help="Ce site(uri) să interogheze (implicit: carturesti; elefant.ro e blocat, vezi README)",
    )
    parser.add_argument("--delay-min", type=float, default=6.0, help="Pauză minimă între navigări (sec)")
    parser.add_argument("--delay-max", type=float, default=10.0, help="Pauză maximă între navigări (sec)")
    parser.add_argument(
        "--allow-fuzzy-match",
        action="store_true",
        help="Acceptă primul rezultat chiar dacă ISBN-ul nu se potrivește exact "
        "(marcat cu isbnVerified=false) - căutarea e fuzzy, deci poate fi altă carte",
    )
    parser.add_argument(
        "--reuse-session",
        action="store_true",
        help="Refolosește un singur context de browser (implicit: unul nou per navigare). "
        "Pe carturesti.ro asta primește challenge Cloudflare de la a doua cerere.",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Deschide fereastra browserului (implicit: headless) - util la depanarea selectoarelor",
    )
    parser.add_argument(
        "--debug-html-dir",
        help="Salvează fiecare pagină navigată ca .html în acest folder (util ca să corectăm selectoarele)",
    )
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
    for adapter in adapters:
        if adapter.blocked_note:
            print(f"[!] {adapter.name}: {adapter.blocked_note}", file=sys.stderr)

    if args.debug_html_dir:
        os.makedirs(args.debug_html_dir, exist_ok=True)

    results: list[dict] = []
    with Scraper(
        delay_range=(args.delay_min, args.delay_max),
        headless=not args.headed,
        debug_html_dir=args.debug_html_dir,
        reuse_session=args.reuse_session,
    ) as scraper:
        for index, (isbn, title_hint) in enumerate(entries, start=1):
            print(f"[{index}/{len(entries)}] {isbn} ({title_hint or '—'})")
            best: EnrichedBook | None = None
            for adapter in adapters:
                candidate = scraper.enrich_one(
                    isbn, title_hint, adapter, allow_fuzzy=args.allow_fuzzy_match
                )
                if candidate.error is None:
                    best = candidate
                    break
                best = best or candidate
            assert best is not None
            if best.error:
                print(f"    -> {best.error}")
            else:
                print(f"    -> {best.title} ({best.publisher or '?'}) {best.productUrl}")
            results.append(asdict(best))

    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(results, handle, ensure_ascii=False, indent=2)

    ok = sum(1 for r in results if not r.get("error"))
    print(f"\n{ok}/{len(results)} îmbogățite cu succes -> {args.output}")


if __name__ == "__main__":
    main()
