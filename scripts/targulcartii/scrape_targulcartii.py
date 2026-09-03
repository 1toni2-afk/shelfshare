#!/usr/bin/env python3
"""Scraper pentru targulcartii.ro - catalogul de opere + ofertele si copertile lor.

Ce e diferit fata de scraperele din scripts/book-enrichment
-----------------------------------------------------------
Alea pornesc de la o lista de ISBN-uri din catalogul nostru si cauta metadate
pentru fiecare. Asta merge invers: ia TOT ce publica site-ul in sitemap si
scrie un dataset local, in scripts/targulcartii/data/.

Modelul de date al site-ului are doua niveluri, si scriptul le pastreaza:

  opera   https://www.targulcartii.ro/<autor-slug>/<titlu-slug>
          o lucrare (titlu + autor). Pagina listeaza toate exemplarele scoase
          la vanzare, fiecare cu editura, anul, tipul copertii, pretul si
          coperta lui.
  oferta  aceeasi pagina + ?an=&editura=&coperta=&pid=<id>
          un exemplar anume. DOAR aici apar ISBN-ul, numarul de pagini, limba,
          dimensiunile, greutatea si starile disponibile (Buna / Foarte buna...).

Deci ISBN-ul costa o navigare in plus per carte - de asta e pe --details, nu
implicit peste tot (vezi mai jos).

Nu exista JSON-LD si nici microdate utile pe pagini (verificat: zero blocuri
application/ld+json), deci tot ce urmeaza e parsare de DOM: #opera_products
pentru oferte, #product_specs pentru specificatii. Nu exista nici camp de
descriere pe site - e anticariat, are doar specificatii.

robots.txt
----------
Scriptul citeste https://www.targulcartii.ro/robots.txt la fiecare pornire si:
  - sare peste orice URL interzis pentru User-agent: * (/cauta/, /informatii,
    /*?*order=, /*?*sort=, /*?*limit=, filtrele etc.);
  - foloseste Crawl-delay-ul declarat acolo ca delay implicit intre cereri.
Delay-ul declarat pentru `*` e 60s, adica un catalog intreg (~49.000 de opere)
ar dura peste o luna. --delay il poate scadea, dar e o decizie constienta:
scriptul scrie ETA-ul si un avertisment inainte sa porneasca.

Etape (rulabile separat, toate se pot relua din locul in care au ramas)
----------------------------------------------------------------------
    python scrape_targulcartii.py sitemap
    python scrape_targulcartii.py --delay 2 scrape --details first
    python scrape_targulcartii.py --delay 1 covers
    python scrape_targulcartii.py export

Reluarea nu tine de un flag: `scrape` citeste opere.jsonl si sare peste
URL-urile deja scrise, `covers` citeste manifestul copertilor. Poti opri cu
Ctrl+C oricand.

Exemple:
    # o singura carte, ca sa vezi ce iese
    python scrape_targulcartii.py --delay 1 scrape --limit 1 --details all
    # tot catalogul, fara paginile de oferta (rapid, dar fara ISBN-uri)
    python scrape_targulcartii.py --delay 2 scrape --details none
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
import urllib.robotparser
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from random import uniform
from urllib.parse import parse_qs, urljoin, urlparse

import requests
from bs4 import BeautifulSoup

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

HERE = Path(__file__).resolve().parent
DATA_DIR = HERE / "data"
SITEMAP_CACHE = DATA_DIR / "sitemap_opere.xml"
URLS_PATH = DATA_DIR / "opere_urls.txt"
OPERE_PATH = DATA_DIR / "opere.jsonl"
COVERS_DIR = DATA_DIR / "covers"
COVERS_MANIFEST = COVERS_DIR / "manifest.json"
ERRORS_PATH = DATA_DIR / "errors.log"
EXPORT_PATH = DATA_DIR / "targulcartii_books.json"

BASE_URL = "https://www.targulcartii.ro"
ROBOTS_URL = f"{BASE_URL}/robots.txt"
SITEMAP_INDEX = f"{BASE_URL}/sitemap.xml"
# Din indexul de sitemap-uri ne intereseaza doar operele; restul sunt categorii,
# edituri, autori si pagini statice.
OPERE_SITEMAP_MARKER = "sitemap_opere"

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)
# Cu ce grup din robots.txt ne potrivim. Trimitem un UA de browser (site-ul
# serveste HTML complet doar asa), dar respectam regulile grupului `*` - cel mai
# restrictiv grup generic din fisier.
ROBOTS_AGENT = "*"
TIMEOUT = 30
RETRIES = 3
# Cate opere scriem inainte sa dam flush pe disc. Mic, ca o oprire cu Ctrl+C sa
# nu piarda munca de o ora.
FLUSH_EVERY = 20


# --------------------------------------------------------------------------
# Utilitare de text
# --------------------------------------------------------------------------

def _clean(text: str | None) -> str | None:
    """Textul din HTML-ul asta vine cu tab-uri si newline-uri din template."""
    if text is None:
        return None
    collapsed = re.sub(r"\s+", " ", text).strip()
    return collapsed or None


def _slug_key(text: str) -> str:
    """Eticheta de specificatie -> cheie stabila: fara diacritice, doar a-z0-9."""
    decomposed = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", ascii_only.lower()).strip("_")


def _price(text: str | None) -> float | None:
    """"14,99LEI" / "4.99 lei" -> 14.99 / 4.99."""
    if not text:
        return None
    match = re.search(r"(\d+(?:[.,]\d+)?)", text.replace(" ", ""))
    return float(match.group(1).replace(",", ".")) if match else None


def _int(text: str | None) -> int | None:
    match = re.search(r"\d+", text or "")
    return int(match.group()) if match else None


def _year(text: str | None) -> int | None:
    match = re.search(r"(1[5-9]\d{2}|20\d{2})", text or "")
    return int(match.group()) if match else None


def _normalize_isbn(value: str | None) -> str | None:
    """"973-95046-1-2" -> "973950461X"-style, fara separatori; None daca nu e ISBN.

    Site-ul pune in acelasi camp si ISBN-uri, si coduri interne de anticariat
    (eticheta e chiar "ISBN/ Cod:"), iar cartile de dinainte de 2007 au ISBN-10.
    Pastram doar ce are 10 sau 13 caractere dupa curatare - restul ramane
    oricum in specsRaw, netocat.
    """
    digits = re.sub(r"[^0-9xX]", "", value or "").upper()
    return digits if len(digits) in (10, 13) else None


# --------------------------------------------------------------------------
# Client HTTP care respecta robots.txt
# --------------------------------------------------------------------------

@dataclass
class Fetcher:
    delay: float
    session: requests.Session = field(default_factory=requests.Session)
    robots: urllib.robotparser.RobotFileParser | None = None
    _last_request: float = 0.0
    blocked: int = 0

    def __post_init__(self) -> None:
        self.session.headers.update({
            "User-Agent": USER_AGENT,
            "Accept-Language": "ro-RO,ro;q=0.9",
        })

    @classmethod
    def create(cls, delay: float | None) -> "Fetcher":
        robots: urllib.robotparser.RobotFileParser | None
        robots = urllib.robotparser.RobotFileParser()
        robots.set_url(ROBOTS_URL)
        declared: float | None = None
        try:
            robots.read()
            raw = robots.crawl_delay(ROBOTS_AGENT)
            declared = float(raw) if raw is not None else None
        except Exception as exc:  # noqa: BLE001 - fara robots mergem prudent
            print(f"[robots] nu am putut citi robots.txt ({exc}); folosesc 60s", file=sys.stderr)
            robots = None

        effective = delay if delay is not None else (declared if declared is not None else 60.0)
        if declared is not None:
            print(f"[robots] Crawl-delay declarat pentru '{ROBOTS_AGENT}': {declared:g}s")
        if declared is not None and effective < declared:
            print(
                f"[robots] ATENTIE: rulezi cu --delay {effective:g}s, sub cele {declared:g}s "
                f"cerute de site. E alegerea ta; tine ritmul rezonabil.",
                file=sys.stderr,
            )
        return cls(delay=effective, robots=robots)

    def allowed(self, url: str) -> bool:
        if self.robots is None:
            return True
        return self.robots.can_fetch(ROBOTS_AGENT, url)

    def _wait(self) -> None:
        if not self._last_request:
            return
        elapsed = time.monotonic() - self._last_request
        if elapsed < self.delay:
            time.sleep(self.delay - elapsed)
        else:
            # Jitter mic, ca sa nu batem la usa la interval perfect fix.
            time.sleep(uniform(0, min(0.3, self.delay)))

    def get(self, url: str, *, binary: bool = False) -> requests.Response | None:
        if not self.allowed(url):
            self.blocked += 1
            print(f"  [robots] interzis, sar peste: {url}", file=sys.stderr)
            return None

        for attempt in range(1, RETRIES + 1):
            self._wait()
            self._last_request = time.monotonic()

            try:
                resp = self.session.get(url, timeout=TIMEOUT, stream=binary)
            except requests.RequestException as exc:
                if attempt == RETRIES:
                    log_error(f"{url} -> {exc}")
                    return None
                time.sleep(self.delay * attempt)
                continue

            if resp.status_code == 404:
                return None
            # 429/503 = ne-au spus sa incetinim. Nu insistam in acelasi ritm.
            if resp.status_code in (429, 503):
                wait = float(resp.headers.get("Retry-After") or self.delay * 4 * attempt)
                print(f"  [!] HTTP {resp.status_code}, astept {wait:g}s", file=sys.stderr)
                time.sleep(wait)
                continue
            if resp.status_code >= 400:
                log_error(f"{url} -> HTTP {resp.status_code}")
                return None
            return resp

        log_error(f"{url} -> renuntat dupa {RETRIES} incercari")
        return None


def log_error(message: str) -> None:
    line = f"{datetime.now(timezone.utc).isoformat(timespec='seconds')} {message}"
    print(f"  [!] {message}", file=sys.stderr)
    with ERRORS_PATH.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def eta(count: int, delay: float, label: str) -> None:
    print(f"[plan] {count} {label} x ~{delay:g}s = ~{count * delay / 3600:.1f}h")


# --------------------------------------------------------------------------
# Etapa 1: sitemap -> lista de URL-uri de opera
# --------------------------------------------------------------------------

def cmd_sitemap(args: argparse.Namespace) -> None:
    if SITEMAP_CACHE.exists() and not args.refresh:
        print(f"[sitemap] folosesc cache-ul {SITEMAP_CACHE.name} (--refresh ca sa il reiau)")
        xml = SITEMAP_CACHE.read_text(encoding="utf-8")
    else:
        fetcher = Fetcher.create(args.delay)
        index = fetcher.get(SITEMAP_INDEX)
        if index is None:
            raise SystemExit("nu am putut citi sitemap.xml")
        sitemaps = [
            loc for loc in re.findall(r"<loc>(.*?)</loc>", index.text)
            if OPERE_SITEMAP_MARKER in loc
        ]
        if not sitemaps:
            raise SystemExit(f"sitemap.xml nu contine niciun '{OPERE_SITEMAP_MARKER}'")
        print(f"[sitemap] {len(sitemaps)} sitemap(uri) de opere")
        parts = []
        for url in sitemaps:
            resp = fetcher.get(url)
            if resp is None:
                continue
            parts.append(resp.text)
            print(f"[sitemap] {url}: {len(re.findall(r'<loc>', resp.text))} URL-uri")
        xml = "\n".join(parts)
        SITEMAP_CACHE.write_text(xml, encoding="utf-8")

    urls: list[str] = []
    seen: set[str] = set()
    for loc in re.findall(r"<loc>(.*?)</loc>", xml):
        loc = loc.replace("&amp;", "&").strip()
        # Doar /<autor>/<titlu>, exact doua segmente - restul sunt categorii.
        path = urlparse(loc).path.strip("/")
        if loc.startswith(BASE_URL) and path.count("/") == 1 and loc not in seen:
            seen.add(loc)
            urls.append(loc)

    URLS_PATH.write_text("\n".join(urls) + "\n", encoding="utf-8")
    print(f"[sitemap] {len(urls)} opere -> {URLS_PATH}")


# --------------------------------------------------------------------------
# Etapa 2: paginile de opera (+ optional paginile de oferta)
# --------------------------------------------------------------------------

def parse_opera(html: str, url: str) -> dict:
    soup = BeautifulSoup(html, "html.parser")
    path_parts = urlparse(url).path.strip("/").split("/")

    heading = soup.select_one("h1")
    title = _clean(heading.get_text()) if heading else None
    author_link = soup.select_one(".opera_caracteristici .opera_fields a")
    author = _clean(author_link.get_text()) if author_link else None
    # h1-ul paginii de opera e "Titlu - Autor"; autorul canonic vine din linkul
    # de sub lista, deci il taiem din titlu cand se potriveste.
    if title and author and title.lower().endswith(f"- {author.lower()}"):
        title = title[: -(len(author) + 2)].strip(" -")

    offers = []
    for row in soup.select("#opera_products .product-list-row"):
        link = row.select_one("a[href*='pid=']")
        href = urljoin(url, link["href"]) if link and link.has_attr("href") else None
        # Editura, anul si tipul copertii sunt chiar in query-ul linkului, deci
        # le luam de acolo in loc sa despartim textul "Tinerama 1991" din .name.
        params = parse_qs(urlparse(href).query) if href else {}

        image = row.select_one(".image img")
        cover = None
        if image:
            raw_src = image.get("data-image-src") or image.get("src")
            # Placeholder-ul lazy-load e un GIF inline de 1x1; nu e coperta.
            if raw_src and not raw_src.startswith("data:"):
                cover = urljoin(url, raw_src)

        old = row.select_one(".price .price-old")
        new = row.select_one(".best_price_anticariat .price_value") or row.select_one(".price-new")
        discount = row.select_one(".discount_cell_inner")
        rating_img = row.select_one(".rating img")

        offers.append({
            "pid": (params.get("pid") or [None])[0],
            "url": href,
            "publisher": (params.get("editura") or [None])[0],
            "year": _year((params.get("an") or [None])[0]),
            "coverType": (params.get("coperta") or [None])[0],
            "priceOld": _price(old.get_text() if old else None),
            "price": _price(new.get_text() if new else None),
            "discount": _clean(discount.get_text()) if discount else None,
            # alt-ul e de forma "Pe baza a 15 comentarii."
            "reviewCount": _int(rating_img.get("alt")) if rating_img else None,
            "coverUrl": cover,
        })

    return {
        "url": url,
        "authorSlug": path_parts[0] if len(path_parts) > 1 else None,
        "slug": path_parts[-1],
        "title": title,
        "author": author,
        "authorUrl": (urljoin(url, author_link["href"])
                      if author_link and author_link.has_attr("href") else None),
        "offerCount": len(offers),
        "offers": offers,
        "fetchedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


# Etichetele din #product_specs, normalizate cu _slug_key -> campurile noastre.
SPEC_FIELDS = {
    "editura": "publisher",
    "colectia": "collection",
    "data_aparitie": "publishedDate",
    "limba": "language",
    "coperta": "coverType",
    "numar_volume": "volumes",
    "numar_pagini": "pageCount",
    "dimensiuni": "dimensions",
    "greutate": "weight",
    "isbn_cod": "isbn",
    "isbn": "isbn",
    "traducator": "translator",
}


def parse_offer(html: str, url: str) -> dict:
    soup = BeautifulSoup(html, "html.parser")

    raw: dict[str, str] = {}
    for row in soup.select("#product_specs .editura-list-row"):
        label_el = row.select_one(".descr_label")
        if not label_el:
            continue
        label = _clean(label_el.get_text())
        cells = row.find_all("div", recursive=False)
        value = _clean(cells[-1].get_text()) if len(cells) >= 2 else None
        # Pe randurile cu o singura celula eticheta si valoarea stau impreuna;
        # atunci scoatem eticheta din text si pastram restul.
        if value and label and value.startswith(label):
            value = _clean(value[len(label):])
        if label and value:
            raw[_slug_key(label)] = value

    specs: dict[str, object] = {}
    for key, value in raw.items():
        target = SPEC_FIELDS.get(key)
        if target in ("pageCount", "volumes"):
            specs[target] = _int(value)
        elif target == "publishedDate":
            specs[target] = value
            specs["publishedYear"] = _year(value)
        elif target == "isbn":
            specs["isbn"] = _normalize_isbn(value)
            specs["isbnRaw"] = value
        elif target:
            specs[target] = value

    conditions = []
    for cond in soup.select(".conditie_row"):
        product_input = cond.select_one("input.product_id")
        label = cond.select_one(".conditie_col")
        note = cond.select_one(".conditie_col_info")
        price = cond.select_one(".conditie_col_pret .price-new")
        conditions.append({
            "productId": (product_input["value"]
                          if product_input and product_input.has_attr("value") else None),
            # .conditie_col contine "Buna 4,99 lei"; taiem pretul din eticheta.
            "label": (_clean(re.sub(r"\d+[.,]\d+\s*lei.*$", "", label.get_text(), flags=re.I))
                      if label else None),
            "note": _clean(note.get_text()) if note else None,
            "price": _price(price.get_text() if price else None),
        })

    # Coperta mare (480x760) exista doar aici, in input-urile ascunse; URL-ul ei
    # NU se poate deduce din thumb-ul de 228x280 al listei - difera slug-ul, nu
    # doar sufixul de dimensiune (verificat: varianta dedusa da 404).
    popup = soup.select_one("input.popup")
    # #status_stoc contine doua span-uri ("In stoc" + "In stoc (ultimele 3
    # bucati)"); al doilea le spune pe amandoua, deci il preferam cand exista.
    stock = soup.select_one("#status_stoc #stoc_val_txt") or soup.select_one("#status_stoc")

    return {
        "detailUrl": url,
        "coverUrlLarge": popup["value"] if popup and popup.has_attr("value") else None,
        "stock": _clean(stock.get_text()) if stock else None,
        "conditions": conditions,
        "specsRaw": raw,
        **specs,
    }


def cmd_scrape(args: argparse.Namespace) -> None:
    if not URLS_PATH.exists():
        raise SystemExit(
            f"Lipseste {URLS_PATH.name}. Ruleaza intai:  python {Path(__file__).name} sitemap"
        )

    urls = [u for u in URLS_PATH.read_text(encoding="utf-8").splitlines() if u.strip()]

    done: set[str] = set()
    if OPERE_PATH.exists():
        with OPERE_PATH.open(encoding="utf-8") as handle:
            for line in handle:
                try:
                    done.add(json.loads(line)["url"])
                except (json.JSONDecodeError, KeyError):
                    continue
        print(f"[scrape] {len(done)} opere deja salvate, le sar")

    todo = [u for u in urls if u not in done]
    if args.limit:
        todo = todo[: args.limit]
    if not todo:
        print("[scrape] nimic de facut")
        return

    fetcher = Fetcher.create(args.delay)
    per_opera = 2 if args.details == "first" else 1
    eta(len(todo) * per_opera, fetcher.delay,
        f"cereri ({len(todo)} opere, --details {args.details})")

    saved = 0
    with OPERE_PATH.open("a", encoding="utf-8") as out:
        for i, url in enumerate(todo, start=1):
            resp = fetcher.get(url)
            if resp is None:
                continue
            record = parse_opera(resp.text, url)

            wanted = record["offers"]
            if args.details == "first":
                wanted = wanted[:1]
            elif args.details == "none":
                wanted = []
            for offer in wanted:
                if not offer.get("url"):
                    continue
                detail_resp = fetcher.get(offer["url"])
                if detail_resp is not None:
                    offer["details"] = parse_offer(detail_resp.text, offer["url"])

            out.write(json.dumps(record, ensure_ascii=False) + "\n")
            saved += 1
            if saved % FLUSH_EVERY == 0:
                out.flush()
            print(f"[scrape] {i}/{len(todo)} {record.get('title') or record['slug']} "
                  f"({record['offerCount']} oferte)")

    print(f"[scrape] gata - {saved} opere adaugate in {OPERE_PATH.name} "
          f"(sarite de robots: {fetcher.blocked})")


# --------------------------------------------------------------------------
# Etapa 3: copertile
# --------------------------------------------------------------------------

def _cover_name(url: str) -> str:
    """Numele fisierului din URL; sunt deja unice, contin id-ul produsului."""
    name = Path(urlparse(url).path).name or "cover.jpg"
    return re.sub(r"[^A-Za-z0-9._-]", "_", name)


def cmd_covers(args: argparse.Namespace) -> None:
    if not OPERE_PATH.exists():
        raise SystemExit(f"Lipseste {OPERE_PATH.name}. Ruleaza intai etapa `scrape`.")

    COVERS_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, str] = {}
    if COVERS_MANIFEST.exists():
        manifest = json.loads(COVERS_MANIFEST.read_text(encoding="utf-8"))

    # Aceeasi coperta apare si in lista de oferte, si pe pagina ofertei; luam
    # varianta mare cand exista si descarcam fiecare URL o singura data.
    wanted: list[str] = []
    seen: set[str] = set()
    with OPERE_PATH.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            for offer in record.get("offers", []):
                details = offer.get("details") or {}
                url = details.get("coverUrlLarge") or offer.get("coverUrl")
                if url and url not in seen:
                    seen.add(url)
                    if url not in manifest or not (COVERS_DIR / manifest[url]).exists():
                        wanted.append(url)

    print(f"[covers] {len(seen)} coperti distincte, {len(wanted)} de descarcat")
    if args.limit:
        wanted = wanted[: args.limit]
    if not wanted:
        return

    fetcher = Fetcher.create(args.delay)
    eta(len(wanted), fetcher.delay, "coperti")

    ok = failed = 0
    for i, url in enumerate(wanted, start=1):
        resp = fetcher.get(url, binary=True)
        if resp is None:
            failed += 1
            continue
        name = _cover_name(url)
        (COVERS_DIR / name).write_bytes(resp.content)
        manifest[url] = name
        ok += 1
        if i % 50 == 0:
            COVERS_MANIFEST.write_text(
                json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"[covers] {i}/{len(wanted)} - ok:{ok} failed:{failed}")

    COVERS_MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[covers] gata - ok:{ok} failed:{failed} -> {COVERS_DIR}")


# --------------------------------------------------------------------------
# Etapa 4: export plat, o intrare per exemplar
# --------------------------------------------------------------------------

def cmd_export(args: argparse.Namespace) -> None:
    if not OPERE_PATH.exists():
        raise SystemExit(f"Lipseste {OPERE_PATH.name}. Ruleaza intai etapa `scrape`.")

    manifest: dict[str, str] = {}
    if COVERS_MANIFEST.exists():
        manifest = json.loads(COVERS_MANIFEST.read_text(encoding="utf-8"))

    books = []
    with OPERE_PATH.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            for offer in record.get("offers", []):
                details = offer.get("details") or {}
                cover = details.get("coverUrlLarge") or offer.get("coverUrl")
                isbn = details.get("isbn")
                if args.only_isbn and not isbn:
                    continue
                books.append({
                    "isbn": isbn,
                    "title": record.get("title"),
                    "author": record.get("author"),
                    "publisher": details.get("publisher") or offer.get("publisher"),
                    "publishedYear": details.get("publishedYear") or offer.get("year"),
                    "pageCount": details.get("pageCount"),
                    "language": details.get("language"),
                    "coverType": details.get("coverType") or offer.get("coverType"),
                    "collection": details.get("collection"),
                    "price": offer.get("price"),
                    "coverUrl": cover,
                    "coverFile": f"covers/{manifest[cover]}" if cover in manifest else None,
                    "productUrl": offer.get("url"),
                    "operaUrl": record.get("url"),
                    "source": "targulcartii",
                })

    payload = {
        "source": "targulcartii.ro",
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "count": len(books),
        "books": books,
    }
    EXPORT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    with_isbn = sum(1 for b in books if b["isbn"])
    print(f"[export] {len(books)} intrari ({with_isbn} cu ISBN) -> {EXPORT_PATH}")


# --------------------------------------------------------------------------

def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--delay", type=float, default=None,
        help="Secunde intre cereri. Implicit: Crawl-delay-ul din robots.txt (60s).",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_sitemap = sub.add_parser("sitemap", help="Descarca sitemap-ul si scrie lista de opere")
    p_sitemap.add_argument("--refresh", action="store_true", help="Ignora cache-ul local")
    p_sitemap.set_defaults(func=cmd_sitemap)

    p_scrape = sub.add_parser("scrape", help="Paginile de opera (+ optional cele de oferta)")
    p_scrape.add_argument(
        "--details", choices=("none", "first", "all"), default="first",
        help="Cate pagini de oferta deschidem per opera. Doar ele au ISBN-ul si "
             "numarul de pagini. 'first' = una singura (implicit).",
    )
    p_scrape.add_argument("--limit", type=int, help="Opreste-te dupa N opere (pentru teste)")
    p_scrape.set_defaults(func=cmd_scrape)

    p_covers = sub.add_parser("covers", help="Descarca copertile in data/covers/")
    p_covers.add_argument("--limit", type=int, help="Opreste-te dupa N coperti")
    p_covers.set_defaults(func=cmd_covers)

    p_export = sub.add_parser("export", help="Export plat, o intrare per exemplar")
    p_export.add_argument("--only-isbn", action="store_true", help="Doar intrarile cu ISBN valid")
    p_export.set_defaults(func=cmd_export)

    args = parser.parse_args()
    try:
        args.func(args)
    except KeyboardInterrupt:
        print("\n[stop] intrerupt; reia cu aceeasi comanda, continua de unde a ramas")


if __name__ == "__main__":
    main()
