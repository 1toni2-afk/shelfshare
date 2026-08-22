# Book metadata enrichment (carturesti.ro)

Scraper de îmbogățire, NU de descoperire: primește ISBN-uri deja existente în
catalogul ShelfShare (venite din Google Books / Open Library, unde adesea
lipsesc coperta, descrierea RO sau detaliile) și scoate pentru fiecare ce
găsește pe pagina de produs de la carturesti.ro.

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

`--allow-fuzzy-match` acceptă totuși primul rezultat, dar îl marchează cu
`isbnVerified: false` și păstrează în `sourceIsbn` ISBN-ul real al paginii, ca
nepotrivirea să fie vizibilă la revizuire.

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

## elefant.ro – blocat

Adapterul există în `SITE_ADAPTERS`, dar **elefant.ro răspunde 403 pe toată
originea** (inclusiv pe homepage) către un Chromium real, headless sau headed.
Nu e un challenge care se rezolvă, ci un blocaj activ. Selectoarele lui
(`result_link_selector`) sunt încă **neverificate** – n-am putut încărca nicio
pagină ca să inspectăm DOM-ul – și formatul URL-ului de produs rămâne
neconfirmat. `--source` e implicit `carturesti`; `elefant`/`both` rămân
disponibile dacă blocajul dispare.

## Limitări cunoscute

- Scriptul NU scrie în baza de date - produce doar `enriched.json`. Maparea
  peste tabelul `books` (Prisma) e un pas separat, intenționat, ca să poți
  revizui datele înainte de a le scrie. Verifică în special înregistrările cu
  `isbnVerified: false`.
- Cărțile străine din catalog (ISBN `978-0…`, importate din Open Library) în
  general nu există pe carturesti; se vor întoarce cu `no exact ISBN match`.
- Rate limiting: 6–10 secunde între orice două navigări, configurabil din
  `--delay-min`/`--delay-max`.
- nemira.ro nu e inclus.
