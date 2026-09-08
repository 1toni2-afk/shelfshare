# Cereri de carte („nu găsesc cartea")

Când căutarea din aplicație nu găsește o carte — nici în catalogul propriu,
nici la Google Books / Open Library — sub câmpul de titlu apare butonul
„Nu găsești cartea? Cere-o". Formularul scrie un rând în `book_requests`, cu
status `PENDING`.

De acolo cartea e căutată **în fiecare noapte, cu prioritate**, în două etape.

## Etapa 1 — backend, 02:30 (automat)

`BookRequestsService.resolvePendingRequests` (backend/src/book-requests/)
rulează pe cron, în container, și ia sursele pe care le poate atinge de acolo:

1. catalogul propriu (aceeași căutare fără diacritice ca autocomplete-ul);
2. Google Books;
3. Open Library.

Ordinea cozii: întâi titlurile cerute de **cei mai mulți useri distincți**,
apoi cele cu cele mai puține încercări, apoi cele mai vechi.

## Etapa 2 — scriptul ăsta, ~03:30 (Task Scheduler)

`nightly_book_requests.py` ia ce a rămas nerezolvat și caută în **librăriile
românești**, care se scrapuiesc cu Playwright și deci n-au ce căuta în backend:

| # | Sursă | Cereri de rețea | Ce cere pe disc |
|---|-------|-----------------|-----------------|
| 1 | `targulcartii-local` | zero | `scripts/targulcartii/data/opere.jsonl` (~11.800 opere) |
| 2 | `targulcartii` | 2 pagini / carte | `scripts/targulcartii/data/opere_urls.txt` (~47.000 URL-uri) + `requests` |
| 3 | `libris` | până la 3 pagini / carte | `scripts/book-enrichment/libris_index.json` |
| 4 | `carturesti` | 2 pagini / carte | — |

O cerere se oprește la prima sursă care o găsește. Sursele fără fișierele lor
locale sunt anunțate la pornire și sărite — restul rulării continuă.

### Ce înseamnă „găsită"

Titlul normalizat al rezultatului trebuie să treacă pragul de similaritate
(0.86, mai strict decât cel din enrichment), iar dacă userul a dat autorul,
măcar un cuvânt din nume trebuie să fie comun. Un fals pozitiv nu strică un
rând oarecare din catalog: trimite unui om notificarea „am găsit cartea ta"
pentru altă carte.

Ce trece de filtru intră în catalog cu `curatedAt` setat — la fel ca cele
~1900 de titluri scrapuite manual — deci căutarea îl va prefera în fața
rezultatelor externe.

### Rulare

```
set BOOK_REQUEST_WORKER_TOKEN=...          # aceeași valoare ca în .env
python nightly_book_requests.py --limit 30

python nightly_book_requests.py --dry-run --sources targulcartii-local
python nightly_book_requests.py --sources libris,carturesti --delay 4
```

`run_nightly.cmd` e învelișul pentru Task Scheduler: își ia singur tokenul din
`.env`-ul de producție (o singură copie a secretului), folosește calea completă
către `python.exe` — un task programat n-are neapărat același PATH ca o consolă
— și loghează în `nightly.log`.

Taskul e înregistrat ca **`ShelfShareBookRequests`**, zilnic la 03:30, sub
contul userului (rulează doar când e logat, la fel ca taskul de enrichment):

```powershell
Get-ScheduledTaskInfo -TaskName ShelfShareBookRequests   # ultima rulare + rezultat
Start-ScheduledTask   -TaskName ShelfShareBookRequests   # rulare la cerere
```

### De ce nu scrie direct în DB

Crearea cărții, deduplicarea pe ISBN, marcarea cererilor gemene ale altor useri
și notificările sunt scrise o singură dată, în `BookRequestsService`. Scriptul
vorbește doar prin două rute HTTP, protejate cu `BOOK_REQUEST_WORKER_TOKEN`:

```
GET  /book-requests/worker/queue?limit=N
POST /book-requests/worker/resolve
```

Fără tokenul din mediu rutele răspund 401 — închise, nu deschise.

## Când se oprește o cerere

După 3 nopți fără rezultat trece în `NOT_FOUND` și iese din coadă (rămâne
vizibilă userului, în „Cărți cerute", și în `GET /book-requests/admin`). Când
o carte e găsită, **toate** cererile în așteptare pentru același titlu
normalizat devin `FULFILLED` și toți solicitanții primesc notificare.
