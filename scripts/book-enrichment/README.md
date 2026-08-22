# Book metadata enrichment (carturesti.ro / elefant.ro)

Scraper de îmbogățire, NU de descoperire: primește ISBN-uri deja existente în
catalogul ShelfShare (venite din Google Books / Open Library, unde adesea
lipsesc coperta, descrierea RO sau detaliile) și scoate pentru fiecare ce
găsește pe paginile de produs de la carturesti.ro și elefant.ro.

Ambele robots.txt permit scraping pe pagini de produs individuale (verificat
manual înainte de a scrie scriptul); ambele blochează filtre/sortare/discount/
login, pe care scriptul nu le atinge.

## Instalare

```bash
cd scripts/book-enrichment
pip install -r requirements.txt
playwright install chromium
```

Rulează cu un Chromium headless real (Playwright), nu cu request-uri HTTP
brute: ambele site-uri sunt în spatele Cloudflare, care respinge (403) orice
request `requests`/`curl` pe baza reputației IP-ului/amprentei TLS, indiferent
de User-Agent - un browser real trece de verificarea pasivă la fel ca o
vizită normală. Adaugă `--headed` la orice comandă ca să vezi fereastra
browserului (util la depanarea selectoarelor).

## Utilizare

```bash
# fișier cu ISBN-uri, opțional "isbn,titlu" pe linie (titlul ajută căutarea)
python enrich_books.py --input isbns.txt --output enriched.json

# un singur ISBN, pentru testare rapidă
python enrich_books.py --isbn 9789734692765 --title "Numele trandafirului"

# doar un singur site
python enrich_books.py --input isbns.txt --source elefant --output enriched.json
```

`isbns.txt`:
```
9789734692765
9786063312345,Numele trandafirului
# comentariile și liniile goale sunt ignorate
```

## Ce extrage

- `coverUrl`, `title`, `description` - din meta tag-urile Open Graph
  (`og:image`, `og:title`, `og:description`), aceleași pe (aproape) orice
  pagină de produs, indiferent de markup - mult mai stabile decât clase CSS.
- `author`, `publisher` - din elemente cu clase ce conțin `author`/`autor`
  respectiv `publisher`/`editura`.
- `isbn`, `publishedYear`, `pageCount`, `format`, `coverType`, `collection`,
  `language` - din tabelul de detalii al paginii, prin potrivire pe *eticheta*
  rândului (normalizată: fără diacritice, case-insensitive), nu pe clasă CSS.

## Limitări cunoscute

- **Cloudflare**: navigarea cu Playwright trece de verificarea pasivă
  (challenge-ul „Just a moment...” se rezolvă singur în câteva secunde, fără
  interacțiune) - scriptul așteaptă automat până la `CHALLENGE_WAIT_SECONDS`.
  Dacă totuși apare `"search request failed"` sau `"product page request failed"`
  în rezultat, rulează din nou cu `--headed` ca să vezi ce se întâmplă vizual
  (poate fi un challenge interactiv, IP blocat definitiv, sau selector greșit).
- **Selectoarele nu au fost validate pe DOM-ul real**: parsing-ul e cel mai bun
  efort bazat pe structuri tipice de e-commerce (OG tags + etichete de tabel).
  Rulează scriptul o dată pe un eșantion mic (10-20 ISBN-uri) și verifică manual
  rezultatul din `enriched.json` înainte de a-l folosi pentru un batch mare;
  ajustează `result_link_selector` din `SITE_ADAPTERS` dacă pagina de căutare
  nu se potrivește.
- Rate limiting: 1-2 secunde între orice două request-uri HTTP (nu doar per
  ISBN - căutare + pagină de produs sunt ambele limitate), configurabil din
  `--delay-min`/`--delay-max`.
- Scriptul NU scrie în baza de date - produce doar `enriched.json`. Maparea
  peste tabelul `books` (Prisma) e un pas separat, intenționat, ca să poți
  revizui datele înainte de a le scrie.
- nemira.ro nu e inclus (are challenge JS Cloudflare, ar necesita Playwright).
