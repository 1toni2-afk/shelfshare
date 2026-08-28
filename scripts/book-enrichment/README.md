# Book metadata enrichment (carturesti.ro + libris.ro)

Scraper de îmbogățire, NU de descoperire: primește ISBN-uri deja existente în
catalogul ShelfShare (venite din Google Books / Open Library, unde adesea
lipsesc coperta, descrierea RO sau detaliile) și scoate pentru fiecare ce
găsește pe pagina de produs.

Două surse, două scripturi, același format de ieșire (deci `import_enriched.py`
le citește pe amândouă):

| Script | Sursă | Cum ajunge la date | Pentru ce |
|---|---|---|---|
| `enrich_libris.py` | libris.ro | index din sitemap + JSON-LD, verificat pe ISBN | cărți în română |
| `enrich_books.py` | carturesti.ro | căutare live pe ISBN + selectoare CSS | română, ce ratează libris |
| `enrich_google.py` | Google Books API | JSON, verificat pe `industryIdentifiers` | restul catalogului |

`nightly_run.py` le rulează pe toate trei, în lanț (vezi mai jos). Pe elefant.ro
nu există scraper: originea răspunde 403 la orice.

## Instalare

```bash
cd scripts/book-enrichment
pip install -r requirements.txt
playwright install chromium
```

## Utilizare

```bash
# fișier cu ISBN-uri, opțional "isbn,titlu" pe linie
python enrich_books.py --input isbns.txt --output enriched.json

# un singur ISBN, pentru testare rapidă
python enrich_books.py --isbn 9789735965006

# vezi ce se întâmplă vizual / salvează paginile navigate
python enrich_books.py --isbn 9789735965006 --headed --debug-html-dir debug_pages
```

`isbns.txt`:
```
9789735965006
9786063312345,Numele trandafirului
# comentariile și liniile goale sunt ignorate
```

## Ce extrage (selectoare verificate pe DOM-ul real, 2026-08)

| Câmp | De unde |
|---|---|
| `coverUrl` | `og:image` – coperta la rezoluție plină (JSON-LD dă doar thumb-ul `-240`) |
| `title` | `h1.titluProdus`, fallback `og:title` |
| `author` | `.autorProdus a[href*='/autor/']` (blocul conține și butonul „Alertă”, deci luăm doar linkurile) |
| `description` | `.descriereProdus` – text randat, cu diacritice; `og:description` e doar rezervă (conține HTML brut și entități `&icirc;`) |
| `publisher` | rândul „Editura” din `.productAttr`, fallback `brand.name` din JSON-LD |
| `publishedYear`, `pageCount`, `format`, `coverType`, `collection`, `language`, `sourceIsbn` | blocurile `.productAttr` (`.productAttrLabel` = eticheta), potrivite pe *eticheta normalizată* (fără diacritice), nu pe clasă |

Etichetele reale de pe carturesti sunt `Limba`, `Data publicarii`, `Editura`,
`Tip coperta`, `Nr. pagini`, `Colectie`, `ISBN`, `Dimensiuni` – de notat că
anul e sub „Data publicarii” (nu „An apariție”) și că nu există „Format”, ci
„Dimensiuni” (`l: 13cm | H: 20cm`). Nu toate cărțile au toate rândurile: o
ediție poate avea doar Limba/Data/Editura/ISBN, și atunci restul rămân `null`
– lipsa lor nu înseamnă selector greșit.

## Potrivirea pe ISBN (important)

Căutarea de pe carturesti e **fuzzy** (Solr). Căutând ISBN-ul
`9789734692765` site-ul întoarce senin `9789734692965` – *altă carte*. „Ia
primul rezultat” ar scrie deci metadate greșite peste o carte din catalog.

Scriptul citește răspunsul JSON pe care și-l cere singură pagina de rezultate
(`/product/json-search`), care conține `code`-ul (ISBN-ul) fiecărui rezultat,
și **acceptă doar potrivirea exactă**. Dacă nu există, rezultatul iese cu
`error: "no exact ISBN match (...)"` în loc de date plauzibile dar false.

`--allow-fuzzy-match` acceptă un rezultat fără potrivire exactă pe ISBN, dar
**numai dacă titlul lui confirmă cartea**. Rezultatul e marcat cu
`isbnVerified: false`, primește un `titleMatchScore`, iar `sourceIsbn` păstrează
ISBN-ul real al paginii, ca nepotrivirea să rămână vizibilă la revizuire.

Verificarea pe titlu nu e opțională, e ce face flag-ul utilizabil. „Primul
rezultat” nu e o dovadă de nimic: Solr, interogat cu un ISBN, potrivește șirul
de cifre pe coduri și EAN-uri arbitrare de produs. La primul batch de 100 de
cărți, ISBN-ul lui *Cum funcționează Google* a întors ca prim rezultat **un
tricou** (cod `6427416198628`), iar **31 din 42** de potriviri fuzzy erau cărți
complet diferite (*Sapiens* → „Munca”, *Alice în Țara Minunilor* → „Pinocchio”)
— date care ar fi corupt rânduri din `books` dacă ajungeau în DB.

Scorul măsoară cât din titlul rezultatului se regăsește în titlul cerut,
asimetric: titlurile noastre vin din Open Library cu subtitluri lungi, pe când
carturesti afișează doar titlul scurt. Un singur cuvânt comun nu e suficient
(„Munca” apare integral în „Munca forțată în Transnistria”). Peste asta există
o punte pe similaritate de caractere, cu prag strict (0.9), pentru typo-urile
din catalog: *Fata Din Forografie* → *Fata din fotografie* trece cu 0.95, dar
*Războinicii 1* → *Războinicii iernii* rămâne respins la 0.77. Pragul se reglează
din `--fuzzy-title-threshold` (implicit 0.6).

Fără titlu în input (`isbn,titlu`) modul fuzzy refuză din start: n-are cu ce
verifica. La fel, rezultatele fără titlu în răspunsul JSON sunt ignorate, iar
căutarea după titlu trimite doar cuvintele, fără diacritice și punctuație —
path-urile lungi cu `:` și `?` encodate primeau 403 (3 din 100 la primul batch).

## Cloudflare – comportament măsurat

Ambele site-uri sunt în spatele Cloudflare, care respinge (403) orice request
`requests`/`curl` pe baza reputației IP-ului/amprentei TLS, indiferent de
User-Agent. De aceea navigăm cu un Chromium real (Playwright).

Măsurat pe carturesti.ro:

- **prima** navigare a unei sesiuni de browser trece de verificarea pasivă și
  primește conținut real;
- **orice navigare următoare din aceeași sesiune** primește un managed
  challenge (`Doar un moment...`, varianta RO a lui „Just a moment...”), care
  **nu se rezolvă niciodată** sub Playwright – nici headless, nici `--headed`,
  nici după 2 minute de așteptare. Odată declanșat, prinde și paginile de
  produs, nu doar căutarea.

Prin urmare scriptul deschide **un context de browser nou pentru fiecare
navigare** și lasă 6–10s între ele (`--delay-min`/`--delay-max`). Același IP,
același User-Agent, aceeași amprentă – fără spoofing și fără proxy-uri; doar o
sesiune curată și un ritm lent. `--reuse-session` revine la un singur context
(util ca să reproduci challenge-ul), dar în practică eșuează de la a doua
carte.

Costul: ~2 navigări per carte (căutare + pagina de produs), deci ~15–25s per
carte. Pentru batch-uri mari, rulează-l peste noapte, nu paralelizat.

Dacă și varianta asta începe să fie blocată, **oprește-te și raportează** – nu
escalada spre spoofing de fingerprint sau rotație de IP.

## libris.ro – `enrich_libris.py`

A doua sursă, script separat, pentru că ruta către pagina de produs e alta.
Ieșirea are exact același format, deci `import_enriched.py` o citește nemodificat.

```bash
python enrich_libris.py --build-index                      # o dată (27 cereri, ~8 MB)
python enrich_libris.py --input isbns.txt --output enriched_libris.json
python enrich_libris.py --isbn 9789734610792 --title "Jurnalul fericirii"
```

**Fără căutare, intenționat.** `robots.txt` de la libris interzice toate rutele
de căutare pentru orice user-agent (`/search?*`, `/s.jsp`, `/ax.jsp`,
`/*?fts_fts=`, `/*?iv.q=`, `/*?psq=`). Folosim în schimb ruta pe care site-ul
o publică singur pentru crawlere – sitemap-urile – și mergem direct pe paginile
de produs, care nu sunt interzise.

**Cum se potrivește cartea.** URL-urile sunt `/carte/<slug>/<id>`, unde slug-ul
e titlu+autor și nu conține ISBN. Deci:

1. `--build-index` descarcă cele 27 de `sitemap-carte.xml` (53.004 cărți la
   2026-08-27) și scrie `slug -> url` în `libris_index.json`;
2. titlul cerut e scorat față de slug-uri (index inversat pe cuvinte, ca să nu
   scanăm 53k intrări per carte) și se iau primii `--max-candidates` (implicit 3);
3. paginile alea se deschid și se acceptă **doar** dacă `isbn`/`gtin13` din
   JSON-LD e exact ISBN-ul cerut.

Pasul 3 e ce face pasul 2 sigur. Spre deosebire de carturesti, unde căutarea
întoarce produse arbitrare și euristica pe titlu e singura apărare, aici fiecare
rezultat acceptat e confirmat de ISBN-ul de pe pagină. Nu există nivel fuzzy și
nici `--allow-fuzzy-match`: tot ce iese are `isbnVerified: true`.
`titleMatchScore` rămâne doar informativ (cât de bine a potrivit slug-ul).

**Datele vin din JSON-LD**, nu din selectoare CSS: nodul `["Product","Book"]` dă
`isbn`, `gtin13`, `name`, `author`, `publisher`, `description`, `image`,
`datePublished`, `numberOfPages`, `inLanguage`, `bookFormat`, `bookEdition`,
`category`. Mai stabil decât DOM-ul.

Două particularități măsurate, ambele tratate în `_strip_author_suffix`:
`name` conține și autorul („Jurnalul fericirii - Nicolae Steinhardt"), iar
autorul apare uneori în ordine inversă față de titlu (`name` „... - Yasunari
Kawabata", `author` „Kawabata Yasunari"). Contează pentru că `import_enriched.py`
suprascrie `title` fix pentru intrările verificate.

**Cloudflare: nu blochează.** Trei pagini de produs consecutive în *același*
context de browser au întors toate 200 – deci aici ținem un singur context și
doar distanțăm cererile (3–6s implicit), fără dansul cu context nou per navigare
de la carturesti. Costă ~1 navigare per carte, față de ~2.

Control rapid că lanțul merge (cărți confirmate pe libris la 2026-08-27):

```bash
printf '9789734610792,Jurnalul fericirii
9786067795899,Dansatoarea din Izu
9789734603930,Dans dans dans
' > libris_control.txt
python enrich_libris.py --input libris_control.txt --output /tmp/ctrl.json   # asteptat: 3/3
```

## elefant.ro – blocat

Adapterul există în `SITE_ADAPTERS` din `enrich_books.py`, dar **elefant.ro
răspunde 403 pe toată originea** (inclusiv pe homepage) către un Chromium real,
headless sau headed. Nu e un challenge care se rezolvă, ci un blocaj activ.
Selectoarele lui (`result_link_selector`) sunt încă **neverificate** – n-am putut
încărca nicio pagină ca să inspectăm DOM-ul – și formatul URL-ului de produs
rămâne neconfirmat. `--source` e implicit `carturesti`; `elefant`/`both` rămân
disponibile dacă blocajul dispare.

Reverificat 2026-08-27 cu Playwright, context nou, aceleași condiții ca
scraperul: `https://www.elefant.ro/` → **HTTP 403** („403 Forbidden", 2.800
octeți), la fel și pagina de căutare; în trafic se vede
`/cdn-cgi/challenge-platform/...`. Blocajul e neschimbat, deci nu există scraper
de elefant – nu pentru că lipsește codul, ci pentru că nu se poate încărca nicio
pagină. Conform notei de mai sus, **nu** escaladăm spre spoofing de amprentă sau
rotație de IP.

## Google Books – `enrich_google.py`

A treia sursă și singura care nu e scraper: API JSON public, fără Cloudflare,
fără browser, fără selectoare de întreținut.

```bash
python enrich_google.py --input isbns.txt --output enriched_google.json
```

Există pentru că golul real din catalog nu e unde păreau să fie scraperele:
din 3.680.942 de cărți, **27** n-au copertă, dar **2.725.584** n-au descriere –
și 2.724.945 dintre alea sunt în engleză. Librăriile românești n-au ce oferi
acolo.

Un volum se acceptă doar dacă ISBN-ul cerut apare în `industryIdentifiers`,
la fel ca verificarea pe `gtin13` de la libris – `q=isbn:` e o interogare, nu o
potrivire exactă.

**Cota.** Fără `GOOGLE_BOOKS_API_KEY` cota anonimă e mică (măsurat 2026-08-27:
429 după câteva sute de cereri) și pare zilnică. Scriptul salvează incremental
(la fiecare 25) și reia din fișierul de ieșire, iar după 3 cărți la rând oprite
de cotă abandonează rularea cu exit 2 în loc să macine restul listei producând
doar erori. Cheia e aceeași variabilă pe care o folosește și backendul în
`book-lookup.service.ts`.

## Ce carte se îmbogățește prima – `nightly_run.py`

Interogarea nu mai e `ORDER BY RANDOM()`. Catalogul are 3,68M de cărți, dar
userii au atins 613 – deci ordinea contează mult mai mult decât viteza
scraperului. Prioritatea:

| tier | ce e | mărime la 2026-08-27 |
|---|---|---|
| 0 `atinse` | apare în raft, swipe, recenzie, wishlist, colecție, progres, user_books sau vot | 189 fără descriere |
| 1 `populare` | are `popularityScore` | 23 fără descriere |
| 2 `restul` | tot catalogul | ~2,7M |

`RANDOM()` a rămas doar ca departajare în interiorul unui tier. Tabelele care
fac o carte „atinsă" sunt în `TOUCHED_TABLES`.

**Lanțul de surse.** Fiecare carte trece la sursa următoare doar dacă cea de
dinainte n-a adus-o cu descriere:

- română (`ROMANIAN_LANGS`): libris → carturesti → Google Books;
- orice altceva: direct Google Books – librăriile românești nu au stoc străin
  (măsurat: 0/12 pe candidați reali din DB).

Etapele rulează pe subseturi, nu carte cu carte, ca să pornim un singur proces
(și un singur browser) per sursă. Dacă `libris_index.json` lipsește, etapa
libris se sare cu un avertisment, nu cade noaptea.

Sesiunea ține implicit `RUN_HOURS` (7h, fereastra 01:00–08:00 a sarcinii
programate). O rulare manuală poate cere altă durată:

```bash
python nightly_run.py --hours 14
```

## Limitări cunoscute

- Scriptul NU scrie în baza de date - produce doar `enriched.json`. Maparea
  peste tabelul `books` (Prisma) e un pas separat, intenționat, ca să poți
  revizui datele înainte de a le scrie. Verifică în special înregistrările cu
  `isbnVerified: false`.
- Cărțile străine din catalog (ISBN `978-0…`, importate din Open Library) în
  general nu există pe carturesti; se vor întoarce cu `no exact ISBN match`.
- Rate limiting: 6–10 secunde între orice două navigări, configurabil din
  `--delay-min`/`--delay-max`.
- Randamentul depinde masiv de *ce* cărți alegi, nu de scraper. Catalogul e
  ~99,97% dump Open Library în engleză, iar `popularityScore` e non-NULL pe doar
  17 rânduri din 2,7M, deci nu poate ordona un batch. Pe un batch ales din
  subsetul românesc (ISBN-13 `978973`/`978606`/`978630`, ~329 de cărți) am
  obținut 27/100 potriviri exacte; pe un batch ordonat după `popularityScore`,
  0/20.
- nemira.ro nu e inclus.
