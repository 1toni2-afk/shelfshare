#!/usr/bin/env python3
"""Cautarea de noapte pentru cartile cerute de useri prin „nu gasesc cartea".

Ce rezolva
----------
Cand cautarea din aplicatie nu gaseste o carte (nici in catalogul propriu,
nici la Google Books / Open Library), userul poate trimite un formular cu
titlul si autorul. Rândul ajunge in `book_requests`, cu status PENDING.

Backend-ul reia singur, in fiecare noapte la 02:30, sursele pe care le poate
atinge din container (catalog + Google Books + Open Library - vezi
BookRequestsService.resolvePendingRequests). Scriptul asta e a doua jumatate:
librariile ROMANESTI, care se scrapuiesc cu Playwright si deci nu au ce cauta
in backend. Rulat dupa cron-ul backend-ului, ia ce a ramas nerezolvat.

Ordinea surselor (de la cea mai ieftina la cea mai scumpa)
---------------------------------------------------------
  1. targulcartii-local  dataset-ul deja scrapuit (scripts/targulcartii/data/
                         opere.jsonl, ~11.800 opere). ZERO cereri de retea.
  2. targulcartii        slug-ul cerut e cautat in opere_urls.txt (toate cele
                         ~47.000 de URL-uri din sitemap) si se deschide DOAR
                         pagina aia + prima oferta, pentru ISBN si specificatii.
  3. libris              index de slug-uri (libris_index.json, construit de
                         enrich_libris.py --build-index) -> pagini de produs,
                         acceptate pe titlu (nu avem ISBN de confirmat).
  4. carturesti          cautare live pe site, acceptata tot pe titlu.

O cerere se opreste la prima sursa care o gaseste. Ce nu gaseste nimeni se
raporteaza inapoi ca incercare esuata: backend-ul creste contorul si, dupa 3
nopti, scoate cererea din coada.

De ce nu scrie direct in DB
---------------------------
Crearea cartii, deduplicarea pe ISBN, marcarea cererilor gemene ale altor
useri si notificarile sunt deja scrise o data, in BookRequestsService. Un al
doilea drum spre `books` (psql direct, ca la import_enriched.py) ar insemna
inca o implementare a acelorasi reguli, care ar ramane in urma. Deci scriptul
vorbeste doar prin doua rute HTTP, protejate cu `BOOK_REQUEST_WORKER_TOKEN`:

    GET  /book-requests/worker/queue?limit=N
    POST /book-requests/worker/resolve

Rulare
------
    set BOOK_REQUEST_WORKER_TOKEN=...
    python nightly_book_requests.py --limit 30
    python nightly_book_requests.py --dry-run --sources targulcartii-local
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import re
import sys
import threading
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable, Iterable

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
ENRICHMENT_DIR = REPO / "scripts" / "book-enrichment"
TARGUL_DIR = REPO / "scripts" / "targulcartii"

OPERE_JSONL = TARGUL_DIR / "data" / "opere.jsonl"
OPERE_URLS = TARGUL_DIR / "data" / "opere_urls.txt"
LIBRIS_INDEX = ENRICHMENT_DIR / "libris_index.json"

DEFAULT_API = os.environ.get("SHELFSHARE_API_URL", "http://localhost:3000")

# Pragul de la care acceptam o potrivire pe titlu. Mai strict decat cel
# implicit din enrich_books.py (0.72): acolo titlul doar CONFIRMA o cautare
# dupa ISBN, aici e singura dovada ca e cartea ceruta. Un fals pozitiv nu
# strica un rand oarecare din catalog, ci trimite userului o notificare
# „am gasit cartea ta" pentru alta carte.
TITLE_THRESHOLD = 0.86

SOURCE_NAMES = ("targulcartii-local", "targulcartii", "libris", "carturesti")

# Cat asteptam un site inainte sa-l consideram pierdut pentru cererea curenta.
# Generos: Carturesti porneste un Chromium la prima cerere, iar sursele au
# delay-uri proprii de cateva secunde intre pagini.
REMOTE_TIMEOUT = 300.0


# --------------------------------------------------------------------------
# Import-uri din scripturile existente (nu sunt pachete, deci pe sys.path)
# --------------------------------------------------------------------------

sys.path.insert(0, str(ENRICHMENT_DIR))
sys.path.insert(0, str(TARGUL_DIR))


def _load_title_similarity() -> Callable[[str | None, str | None], float]:
    """`_title_similarity` din enrich_books.py - aceeasi masura ca la enrichment.

    Import lenes si cu plasa: enrich_books importa Playwright la incarcare, iar
    sursa 1 (dataset local) trebuie sa mearga si pe o masina fara el.
    """
    try:
        from enrich_books import _title_similarity  # type: ignore[import-not-found]

        return _title_similarity
    except Exception:  # noqa: BLE001 - lipsa Playwright/bs4 nu opreste sursa locala
        return _fallback_similarity


def _fallback_similarity(wanted: str | None, candidate: str | None) -> float:
    """Jaccard pe cuvinte - doar cand enrich_books.py nu se poate importa."""
    a, b = set(_tokens(wanted)), set(_tokens(candidate))
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def _tokens(text: str | None) -> list[str]:
    if not text:
        return []
    plain = unicodedata.normalize("NFD", text)
    plain = "".join(ch for ch in plain if not unicodedata.combining(ch))
    return [t for t in re.split(r"[^a-z0-9]+", plain.lower()) if t]


title_similarity = _load_title_similarity()


def author_matches(wanted: str | None, candidate: str | None) -> bool:
    """Autorul e un FILTRU, nu un scor: daca userul l-a dat si candidatul are
    unul, macar un cuvant (nume sau prenume) trebuie sa fie comun. Fara asta,
    „Idiotul" ar fi la fel de bine Dostoievski sau oricine altcineva."""
    if not wanted:
        return True
    if not candidate:
        # Sursa nu declara autorul - nu putem infirma, deci nu blocam.
        return True
    return bool(set(_tokens(wanted)) & set(_tokens(candidate)))


# --------------------------------------------------------------------------
# API
# --------------------------------------------------------------------------


class Api:
    def __init__(self, base_url: str, token: str, dry_run: bool = False):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.dry_run = dry_run

    def _call(self, method: str, path: str, payload: dict | None = None) -> object:
        request = urllib.request.Request(
            f"{self.base_url}{path}",
            method=method,
            data=json.dumps(payload).encode("utf-8") if payload is not None else None,
            headers={
                "x-worker-token": self.token,
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:300]
            raise SystemExit(f"{method} {path} -> HTTP {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise SystemExit(f"{method} {path} a esuat: {exc.reason}") from exc
        return json.loads(body) if body else None

    def queue(self, limit: int) -> list[dict]:
        rows = self._call("GET", f"/book-requests/worker/queue?limit={limit}")
        return rows if isinstance(rows, list) else []

    def resolve(self, request_id: str, source: str, book: dict | None) -> object:
        payload = {"requestId": request_id, "source": source}
        if book:
            # Cartile de la librariile romanesti intra in catalogul curat, la
            # fel ca cele ~1900 scrapuite manual: sunt editii reale, cu ISBN si
            # editura, nu rezultate aproximative de la un API generalist.
            payload["book"] = book
            payload["curated"] = True
        if self.dry_run:
            print(f"    [dry-run] POST resolve {json.dumps(payload, ensure_ascii=False)[:200]}")
            return None
        return self._call("POST", "/book-requests/worker/resolve", payload)


# --------------------------------------------------------------------------
# Sursa 1: dataset-ul targulcartii deja scrapuit (fara retea)
# --------------------------------------------------------------------------


class TargulLocal:
    # Citeste doar din opere.jsonl: zero cereri de retea, deci merita intotdeauna
    # incercata prima si singura, inainte sa deranjam vreun site.
    local = True
    name = "targulcartii-local"

    def __init__(self) -> None:
        self.records: list[dict] = []
        self.by_token: dict[str, list[int]] = {}

    def available(self) -> bool:
        return OPERE_JSONL.exists()

    def load(self) -> None:
        if self.records:
            return
        with OPERE_JSONL.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                # Randurile goale scrise in timpul blocajului de anul trecut
                # (200 cu corp gol - vezi docstring-ul scraperului) n-au titlu.
                if not record.get("title"):
                    continue
                index = len(self.records)
                self.records.append(record)
                for token in set(_tokens(record["title"])):
                    self.by_token.setdefault(token, []).append(index)
        print(f"[targulcartii-local] {len(self.records)} opere in dataset")

    def find(self, title: str, author: str | None) -> dict | None:
        self.load()
        tokens = set(_tokens(title))
        if not tokens:
            return None
        hits: dict[int, int] = {}
        for token in tokens:
            for index in self.by_token.get(token, ()):
                hits[index] = hits.get(index, 0) + 1
        need = 2 if len(tokens) >= 2 else 1
        pool = [i for i, n in hits.items() if n >= need] or list(hits)

        best: tuple[float, dict] | None = None
        for index in pool:
            record = self.records[index]
            if not author_matches(author, record.get("author")):
                continue
            score = title_similarity(title, record.get("title"))
            if score >= TITLE_THRESHOLD and (best is None or score > best[0]):
                best = (score, record)
        return book_from_targul_record(best[1]) if best else None


def book_from_targul_record(record: dict) -> dict:
    """Oferta cea mai completa a operei -> forma ceruta de /worker/resolve.

    „Cea mai completa", nu „prima": ISBN-ul, numarul de pagini si limba apar
    doar pe pagina unei oferte anume, iar scraperul a luat detaliile doar
    pentru unele (vezi --details first).
    """
    offers = record.get("offers") or []
    best = max(
        offers,
        key=lambda offer: (
            1 if (offer.get("details") or {}).get("isbn") else 0,
            1 if (offer.get("details") or {}).get("pageCount") else 0,
        ),
        default={},
    )
    details = best.get("details") or {}
    book = {
        "title": record["title"],
        "author": record.get("author"),
        "isbn": details.get("isbn"),
        "coverUrl": details.get("coverUrlLarge") or best.get("coverUrl"),
        "publisher": details.get("publisher") or best.get("publisher"),
        "publishedYear": details.get("publishedYear") or best.get("year"),
        "pageCount": details.get("pageCount"),
        "language": details.get("language"),
    }
    return {key: value for key, value in book.items() if value not in (None, "")}


# --------------------------------------------------------------------------
# Sursa 2: targulcartii live, o singura opera
# --------------------------------------------------------------------------


class TargulLive:
    name = "targulcartii"

    def __init__(self, delay: float):
        self.delay = delay
        self.urls: list[tuple[str, str]] = []
        self.fetcher = None
        self.blocked = False

    def available(self) -> bool:
        if not OPERE_URLS.exists():
            return False
        try:
            # scrape_targulcartii.py merge pe `requests`; fara el sursa asta
            # pur si simplu nu exista, dar restul rularii continua.
            import requests  # noqa: F401  # type: ignore[import-not-found]
        except ImportError:
            return False
        return True

    def _load_urls(self) -> None:
        if self.urls:
            return
        for line in OPERE_URLS.read_text(encoding="utf-8").splitlines():
            url = line.strip()
            if not url:
                continue
            # .../<autor-slug>/<titlu-slug> - doar ultimul segment e titlul.
            slug = url.rsplit("/", 1)[-1]
            self.urls.append((url, slug.replace("-", " ")))
        print(f"[targulcartii] {len(self.urls)} URL-uri in sitemap")

    def find(self, title: str, author: str | None) -> dict | None:
        if self.blocked:
            return None
        self._load_urls()

        best: tuple[float, str] | None = None
        for url, slug_text in self.urls:
            score = title_similarity(title, slug_text)
            if score >= TITLE_THRESHOLD and (best is None or score > best[0]):
                best = (score, url)
        if best is None:
            return None

        from scrape_targulcartii import Blocked, Fetcher, parse_offer, parse_opera

        if self.fetcher is None:
            # `create`, nu constructorul direct: citeste robots.txt si respecta
            # ce e interzis acolo. `--delay`-ul nostru il trecem explicit.
            self.fetcher = Fetcher.create(self.delay)

        try:
            response = self.fetcher.get(best[1])
            if response is None:
                return None
            opera = parse_opera(response.text, best[1])
            if not author_matches(author, opera.get("author")):
                return None
            offers = opera.get("offers") or []
            details = {}
            if offers:
                # O singura navigare in plus: doar pagina ofertei are ISBN.
                offer_url = offers[0].get("url")
                if offer_url:
                    detail_response = self.fetcher.get(offer_url)
                    if detail_response is not None:
                        details = parse_offer(detail_response.text, offer_url)
        except Blocked as exc:
            # Site-ul raspunde 200 cu corp gol cand te opreste - vezi memoria
            # „HTTP 200 nu inseamna succes". Din clipa asta nu-l mai atingem
            # in rularea curenta.
            print(f"  [!] targulcartii ne-a blocat ({exc}) - sar peste sursa", file=sys.stderr)
            self.blocked = True
            return None
        except Exception as exc:  # noqa: BLE001 - o pagina rupta nu opreste coada
            print(f"  [!] targulcartii: {exc}", file=sys.stderr)
            return None

        merged = dict(opera)
        if offers:
            first = dict(offers[0])
            first["details"] = details
            merged["offers"] = [first]
        return book_from_targul_record(merged)


# --------------------------------------------------------------------------
# Sursa 3: libris
# --------------------------------------------------------------------------


class Libris:
    name = "libris"

    def __init__(self, delay: float, max_candidates: int = 3):
        self.delay = delay
        self.max_candidates = max_candidates
        self.index = None
        self.scraper = None

    def available(self) -> bool:
        return LIBRIS_INDEX.exists()

    def find(self, title: str, author: str | None) -> dict | None:
        from bs4 import BeautifulSoup
        from enrich_libris import (  # type: ignore[import-not-found]
            LibrisScraper,
            SlugIndex,
            _book_node,
            _names,
            _int,
            _year,
        )

        if self.index is None:
            self.index = SlugIndex.load(LIBRIS_INDEX)
        if self.scraper is None:
            self.scraper = LibrisScraper(delay_range=(self.delay, self.delay + 1.0))

        for score, url in self.index.candidates(title, self.max_candidates):
            if score < 0.5:
                # Sub atat nici nu merita deschisa pagina: scorul e pe slug,
                # care e mai sarac decat titlul real de pe pagina.
                continue
            html = self.scraper.fetch(url)
            if not html:
                continue
            node = _book_node(BeautifulSoup(html, "html.parser"))
            if not node:
                continue
            page_title = node.get("name") or ""
            page_author = _names(node.get("author"))
            # Verificarea se face pe titlul REAL al paginii, nu pe slug: aici
            # nu avem ISBN-ul cerut cu care enrich_libris.py confirma de obicei.
            if title_similarity(title, page_title) < TITLE_THRESHOLD:
                continue
            if not author_matches(author, page_author):
                continue
            image = node.get("image")
            book = {
                "title": page_title,
                "author": page_author,
                "isbn": str(node.get("isbn") or node.get("gtin13") or "") or None,
                "description": node.get("description") or None,
                "coverUrl": image if isinstance(image, str) else None,
                "publisher": _names(node.get("publisher")),
                "publishedYear": _year(node.get("datePublished")),
                "pageCount": _int(node.get("numberOfPages")),
                "language": node.get("inLanguage") or None,
            }
            return {k: v for k, v in book.items() if v not in (None, "")}
        return None

    def close(self) -> None:
        if self.scraper is not None:
            self.scraper.close()
            self.scraper = None


# --------------------------------------------------------------------------
# Sursa 4: carturesti
# --------------------------------------------------------------------------


class Carturesti:
    name = "carturesti"

    def __init__(self, delay: float):
        self.delay = delay
        self.scraper = None

    def available(self) -> bool:
        return True

    def find(self, title: str, author: str | None) -> dict | None:
        from bs4 import BeautifulSoup
        from enrich_books import (  # type: ignore[import-not-found]
            SITE_ADAPTERS,
            EnrichedBook,
            Scraper,
            _search_query,
        )

        adapter = SITE_ADAPTERS["carturesti"]
        if self.scraper is None:
            self.scraper = Scraper(delay_range=(self.delay, self.delay + 4.0))

        # Compunem din primitivele scraperului in loc sa chemam `enrich_one`:
        # aia porneste de la un ISBN cunoscut, iar aici tocmai ISBN-ul lipseste.
        _, payload, error = self.scraper._navigate(
            adapter.search_url(_search_query(title)),
            wait_selector=adapter.result_link_selector,
            api_marker=adapter.search_api_marker,
        )
        if error or not payload:
            return None
        candidates = adapter.products_from_api(payload)
        best = self.scraper._best_title_match(candidates, title, TITLE_THRESHOLD)
        if best is None:
            return None

        candidate, _score = best
        html, _, nav_error = self.scraper._navigate(candidate["url"])
        if nav_error:
            return None
        result = EnrichedBook(isbn=candidate.get("isbn") or "", source="carturesti")
        self.scraper._parse_product_page(BeautifulSoup(html, "html.parser"), result)
        if not author_matches(author, result.author):
            return None

        book = {
            "title": result.title or candidate.get("title"),
            "author": result.author,
            "isbn": result.sourceIsbn or candidate.get("isbn") or None,
            "description": result.description,
            "coverUrl": result.coverUrl,
            "publisher": result.publisher,
            "publishedYear": result.publishedYear,
            "pageCount": result.pageCount,
            "language": result.language,
        }
        return {k: v for k, v in book.items() if v not in (None, "")}

    def close(self) -> None:
        if self.scraper is not None:
            self.scraper.close()
            self.scraper = None


# --------------------------------------------------------------------------
# Rularea
# --------------------------------------------------------------------------


def build_sources(names: Iterable[str], delay: float) -> list[object]:
    built: list[object] = []
    for name in names:
        if name == "targulcartii-local":
            built.append(TargulLocal())
        elif name == "targulcartii":
            built.append(TargulLive(delay=max(delay, 2.0)))
        elif name == "libris":
            built.append(Libris(delay=delay))
        elif name == "carturesti":
            built.append(Carturesti(delay=max(delay, 6.0)))
        else:
            raise SystemExit(f"Sursa necunoscuta: {name}")
    return built


class SourceWorker:
    """Ruleaza o singura sursa pe firul ei de executie.

    De ce un fir dedicat per sursa si nu un ThreadPoolExecutor: Carturesti tine
    un Chromium prin API-ul *sincron* al Playwright, care trebuie creat si
    folosit din acelasi fir. Un pool ar plimba sursa intre fire si ar crapa.

    Bonus care conteaza mai mult decat viteza: un singur fir per sursa inseamna
    ca nu cerem niciodata doua pagini simultan de la acelasi site. Paralelismul
    e *intre* site-uri, unde limitele sunt independente, niciodata *in interiorul*
    unuia - exact ce ne-a blocat la targulcartii cand am fortat ritmul.

    Si repara un bug: Libris si Carturesti pornesc fiecare `sync_playwright()`,
    iar API-ul sincron nu suporta doua instante in acelasi fir - a doua crapa cu
    "Playwright Sync API inside the asyncio loop". Cum ordinea era libris inainte
    de carturesti si sursele se inchideau abia la final, **carturesti pica la
    fiecare rulare**. Un fir per sursa inseamna cate o instanta per fir, ceea ce
    Playwright accepta. De aceea trec prin worker si sursele rulate pe rand.
    """

    def __init__(self, source: object):
        self.source = source
        self.name: str = source.name  # type: ignore[attr-defined]
        self._jobs: queue.Queue = queue.Queue()
        self._thread = threading.Thread(
            target=self._run, name=f"src-{self.name}", daemon=True
        )
        self._thread.start()

    def _run(self) -> None:
        while True:
            job = self._jobs.get()
            if job is None:
                # Inchiderea trebuie facuta tot aici: browserul apartine firului asta.
                close = getattr(self.source, "close", None)
                if close:
                    try:
                        close()
                    except Exception as exc:  # noqa: BLE001
                        print(f"    [!] {self.name} la inchidere: {exc}", file=sys.stderr)
                return
            title, author, box = job
            try:
                box["book"] = self.source.find(title, author)  # type: ignore[attr-defined]
            except Exception as exc:  # noqa: BLE001 - o sursa cazuta nu opreste restul
                box["error"] = exc
            finally:
                box["done"].set()

    def submit(self, title: str, author: str | None) -> dict:
        box: dict = {"book": None, "error": None, "done": threading.Event()}
        self._jobs.put((title, author, box))
        return box

    def shutdown(self) -> None:
        self._jobs.put(None)
        self._thread.join(timeout=120)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default=DEFAULT_API, help="URL-ul backend-ului")
    parser.add_argument("--limit", type=int, default=30, help="Cate cereri luam")
    parser.add_argument(
        "--sources",
        default="all",
        help=f"Lista separata prin virgula din: {', '.join(SOURCE_NAMES)} (implicit: all)",
    )
    parser.add_argument("--delay", type=float, default=2.0, help="Secunde intre cereri HTTP")
    parser.add_argument(
        "--sequential",
        action="store_true",
        help="Interogheaza site-urile pe rand, ca inainte, in loc de paralel",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Cauta, dar nu trimite nimic inapoi in backend",
    )
    args = parser.parse_args()

    token = os.environ.get("BOOK_REQUEST_WORKER_TOKEN", "")
    if not token:
        raise SystemExit(
            "Lipseste BOOK_REQUEST_WORKER_TOKEN (aceeasi valoare ca in .env-ul backend-ului)"
        )

    names = SOURCE_NAMES if args.sources == "all" else tuple(
        n.strip() for n in args.sources.split(",") if n.strip()
    )
    api = Api(args.api, token, dry_run=args.dry_run)
    requests_ = api.queue(args.limit)
    if not requests_:
        print("Nicio cerere in asteptare.")
        return

    sources = build_sources(names, args.delay)
    usable = [s for s in sources if s.available()]  # type: ignore[attr-defined]
    skipped = [s.name for s in sources if s not in usable]  # type: ignore[attr-defined]
    if skipped:
        print(f"Surse indisponibile (lipsesc datele locale): {', '.join(skipped)}")
    if not usable:
        raise SystemExit("Nicio sursa disponibila.")

    local_sources = [s for s in usable if getattr(s, "local", False)]
    remote_sources = [s for s in usable if not getattr(s, "local", False)]
    # Un singur site n-are cu ce sa se suprapuna.
    parallel = not args.sequential and len(remote_sources) > 1
    # Workerii se creeaza in ambele moduri: firul dedicat nu e doar pentru
    # viteza, e si singurul mod in care doua surse pe Playwright coexista.
    workers = [SourceWorker(s) for s in remote_sources]

    mod = "in paralel" if parallel else "pe rand"
    print(f"{len(requests_)} cereri, surse: {', '.join(s.name for s in usable)} ({mod})")  # type: ignore[attr-defined]
    found = 0
    try:
        for position, request in enumerate(requests_, start=1):
            label = request["title"]
            if request.get("author"):
                label += f" / {request['author']}"
            print(f"[{position}/{len(requests_)}] {label} (ceruta de {request.get('demand', 1)})")

            book = None
            hit_source = None

            # Intai sursele locale: costa zero cereri, deci nu are rost sa
            # deranjam niciun site daca raspunsul e deja pe disc.
            for source in local_sources:
                try:
                    book = source.find(request["title"], request.get("author"))  # type: ignore[attr-defined]
                except Exception as exc:  # noqa: BLE001
                    print(f"    [!] {source.name}: {exc}", file=sys.stderr)  # type: ignore[attr-defined]
                    continue
                if book:
                    hit_source = source.name  # type: ignore[attr-defined]
                    break

            if not book and workers:
                if parallel:
                    # Toate site-urile pornesc odata; asteptam sa termine toate
                    # si abia apoi alegem, ca sa pastram ordinea de prioritate.
                    boxes = [
                        (w, w.submit(request["title"], request.get("author")))
                        for w in workers
                    ]
                    for worker, box in boxes:
                        if not box["done"].wait(timeout=REMOTE_TIMEOUT):
                            print(
                                f"    [!] {worker.name}: timeout dupa {REMOTE_TIMEOUT}s",
                                file=sys.stderr,
                            )
                    for worker, box in boxes:
                        if box["error"] is not None:
                            print(f"    [!] {worker.name}: {box['error']}", file=sys.stderr)
                            continue
                        if box["book"] and not book:
                            book = box["book"]
                            hit_source = worker.name
                else:
                    # Pe rand, cu oprire la primul hit - dar tot prin workeri,
                    # ca fiecare Playwright sa stea pe firul lui.
                    for worker in workers:
                        box = worker.submit(request["title"], request.get("author"))
                        if not box["done"].wait(timeout=REMOTE_TIMEOUT):
                            print(
                                f"    [!] {worker.name}: timeout dupa {REMOTE_TIMEOUT}s",
                                file=sys.stderr,
                            )
                            continue
                        if box["error"] is not None:
                            print(f"    [!] {worker.name}: {box['error']}", file=sys.stderr)
                            continue
                        if box["book"]:
                            book = box["book"]
                            hit_source = worker.name
                            break

            if book and hit_source:
                print(f"    -> gasita pe {hit_source}: {book.get('title')} ({book.get('isbn', 'fara ISBN')})")
                api.resolve(request["id"], hit_source, book)
                found += 1
            else:
                print("    -> negasita nicaieri")
                # Tot raportam: backend-ul numara incercarea si, dupa 3
                # nopti, scoate cererea din coada.
                api.resolve(request["id"], ",".join(s.name for s in usable), None)  # type: ignore[attr-defined]
    finally:
        # Sursele date pe mana workerilor se inchid pe firul lor; restul aici.
        for worker in workers:
            worker.shutdown()
        for source in usable:
            if any(w.source is source for w in workers):
                continue
            close = getattr(source, "close", None)
            if close:
                close()

    print(f"Gata: {found}/{len(requests_)} cereri rezolvate.")


if __name__ == "__main__":
    main()
