# Schiță: adăugarea cărților în bulk pentru anticariate

Stare: **propunere**, nimic implementat. Documentul descrie cum s-ar integra un
anticariat (sau orice magazin cu stoc mare de carte veche) în ShelfShare, ce
trebuie adăugat în schemă și în ce ordine merită construit.

## 1. Ce problemă rezolvă

Un anticariat are între câteva sute și câteva zeci de mii de exemplare. Fluxul
actual de adăugare presupune un om care completează un formular pe carte
(`/library/add`) sau scanează coduri de bare, maximum 50 odată
(`POST /books/bulk`, vezi `BulkAddBooksDto`). Pentru un magazin asta nu e
utilizabil: stocul lui există deja într-un sistem propriu (gestiune, site,
export Excel) și se schimbă zilnic - vinde, cumpără loturi, retrage titluri.

Integrarea trebuie deci să acopere trei lucruri, nu doar primul:

1. **Import inițial** al întregului stoc.
2. **Sincronizare** - ce s-a vândut dispare din marketplace fără intervenție
   manuală.
3. **Identitate** - cumpărătorul vede clar că e un magazin, nu un vecin cu un
   raft.

## 2. Model de date

Adăugiri la `schema.prisma` (nimic din ce există nu-și schimbă semantica):

```prisma
model Partner {
  id          String   @id @default(uuid())
  name        String
  slug        String   @unique
  /// Contul prin care apar anunțurile - un User obișnuit, marcat ca magazin.
  /// Reutilizăm tot ce există deja (profil, chat, oferte), nu construim un
  /// al doilea tip de proprietar în paralel cu UserBook.userId.
  userId      String   @unique
  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  /// Doar hash-ul cheii + un prefix vizibil („ss_pk_a1b2…"), ca la tokenul de
  /// worker din scripts/book-requests - cheia în clar se arată o singură dată,
  /// la generare.
  apiKeyHash  String
  apiKeyLast4 String
  active      Boolean  @default(true)
  maxListings Int      @default(5000)
  createdAt   DateTime @default(now())
  imports     PartnerImport[]
}

model PartnerImport {
  id         String   @id @default(uuid())
  partnerId  String
  partner    Partner  @relation(fields: [partnerId], references: [id], onDelete: Cascade)
  mode       String   // "delta" | "full"
  status     String   // "QUEUED" | "RUNNING" | "DONE" | "FAILED"
  received   Int      @default(0)
  created    Int      @default(0)
  updated    Int      @default(0)
  unlisted   Int      @default(0)
  failed     Int      @default(0)
  /// Primele N erori, cu SKU-ul care le-a produs - destul cât magazinul să-și
  /// repare exportul, fără să ținem un log complet în baza de date.
  errors     Json?
  startedAt  DateTime @default(now())
  finishedAt DateTime?
}
```

Pe `UserBook`:

```prisma
  /// SKU-ul din sistemul magazinului. Cheia de idempotență a importului:
  /// același SKU trimis a doua oară actualizează rândul, nu creează altul.
  externalRef String?
  partnerId   String?
  @@unique([partnerId, externalRef])
```

`externalRef` nullable înseamnă că anunțurile normale rămân neatinse, iar
unicitatea nu le vede.

## 3. Formatul de intrare

Un singur vocabular, două ambalaje - JSON pentru cine are dezvoltator, CSV cu
aceleași coloane pentru cine exportă din Excel.

| câmp | obligatoriu | note |
|---|---|---|
| `sku` | da | unic la nivel de partener |
| `isbn` | nu | fără el, potrivirea se face pe titlu+autor |
| `title` | da | |
| `author` | nu | |
| `publisher`, `publishedYear`, `edition`, `language` | nu | |
| `price` | da dacă `status=active` | RON, număr, fără simbol |
| `quantity` | nu (implicit 1) | `0` = ieșit din stoc |
| `condition`, `description` | nu | text liber, plafonat |
| `photos[]` | nu | URL-uri publice, maximum 5 |
| `city` | nu | implicit orașul contului de partener |
| `status` | nu | `active` \| `sold` \| `hidden`, implicit `active` |

Mărimea unei cereri: **500 de rânduri**. Mai mult se paginează - nu fiindcă
n-am putea, ci ca un import de 20.000 de titluri să poată fi reluat de unde a
căzut, nu de la zero.

## 4. Endpointuri

Modul nou `partners`, montat sub `/partners`, cu un guard propriu care citește
`X-ShelfShare-Key`, caută partenerul după prefix și compară hash-ul. Nu trece
prin `JwtAuthGuard`: e autentificare de server, nu de user.

```
POST   /partners/imports        { mode: "delta" | "full", items: [...] }  -> { importId }
POST   /partners/imports/csv    multipart, aceleași coloane               -> { importId }
GET    /partners/imports/:id    -> stare + contoare + primele erori
GET    /partners/listings?cursor=  -> ce vede ShelfShare că are magazinul acum
DELETE /partners/listings/:sku  -> retragere punctuală (echivalent quantity: 0)
```

`mode: "full"` înseamnă „ăsta e tot stocul meu": tot ce lipsește din lot se
delistează la final. `mode: "delta"` atinge doar SKU-urile trimise. Implicit
`delta`, fiindcă greșeala în cazul lui costă mai puțin.

## 5. Procesare

Cererea nu procesează sincron: scrie `PartnerImport` cu `QUEUED`, salvează
lotul și întoarce `importId`. Un worker (același tipar cu
`scripts/book-requests/run_nightly.cmd`) îl consumă în tranșe de ~100.

Pentru fiecare rând:

1. **Rezolvarea cărții din catalog** - exact lanțul existent din
   `resolveOrCreateBookForShelf`: ISBN → catalog curat (`curatedAt`) →
   titlu+autor fără diacritice (indexul GIN) → abia apoi providerii externi.
   Ordinea contează: cheia Google Books își epuizează cota zilnică, deci un
   import de 5.000 de titluri nu are voie să depindă de ea.
2. **Titlurile nerezolvate** nu blochează importul: se creează cartea din
   datele trimise de magazin și se pune la coadă pentru îmbogățire în jobul de
   noapte.
3. **Upsert pe `(partnerId, sku)`** - creează sau actualizează `UserBook`, cu
   `isForSale: true`, `availableForSwap: false`.
4. **`quantity: 0` / `status: sold`** → `isForSale: false`, fără ștergere:
   istoricul și conversațiile legate de anunț rămân valide.
5. **Pozele** nu se servesc de pe domeniul magazinului - se descarcă o dată în
   storage-ul propriu, altfel marketplace-ul se sparge când magazinul își
   reface site-ul.

## 6. Cum arată în aplicație

- Contul de partener are un badge „Anticariat" pe profil și pe fiecare card.
- Anunțurile lui sunt **doar de vânzare**: nu intră în schimb și nu intră în
  Book Match (pool-ul curat rămâne pentru useri reali).
- Un filtru nou în browse: „include magazine" / „doar persoane fizice".
  Implicit incluse - dar filtrul trebuie să existe din prima zi, altfel un
  singur anticariat cu 8.000 de titluri acoperă tot ce vede un user.
- Ordonarea trebuie să limiteze câte rezultate consecutive vin de la același
  vânzător, altfel prima pagină e a lui.

## 7. Limite și abuz

- Plafon de anunțuri pe partener (`maxListings`), verificat înainte de import.
- Rate limit pe cheie: 60 de cereri/minut, refolosind
  `SlidingWindowLimiterService`.
- Sanity-check pe preț (0 < preț < 100.000 RON) - un export cu virgula
  zecimală greșită n-are voie să scoată o carte la 500.000.
- Primul import al unui partener nou intră în moderare: nimic public până când
  un admin apasă „aprobă".
- Cheia se poate roti din panoul de admin; fiecare import rămâne în audit.

## 8. Panoul de admin

Un tab „Parteneri": listă cu nume, cont legat, ultimul import (când, câte
create/actualizate/eșuate), buton de rotire a cheii, buton de suspendare care
delistează tot stocul dintr-o mișcare.

## 9. Ordinea de construit

1. **Fără API.** Import CSV făcut de un admin în numele magazinului, pe un cont
   normal. Zero schemă nouă în afară de `externalRef`. Validează formatul și
   arată dacă produsul interesează pe cineva.
2. **Partener + cheie + JSON/CSV asincron**, `delta` și `full`, badge și filtru
   în browse. Ăsta e MVP-ul real.
3. **Self-serve**: pagină de partener unde magazinul își vede importurile, își
   rotește cheia și primește webhook la fiecare comandă.

## 10. Rămase în afara schiței

Plățile și comisionul (nedecise încă la nivel de produs), facturarea, retururile
și orice ține de KYC. Până la ele, tranzacția cu un anticariat funcționează la
fel ca între doi useri: se vorbește în chat și se plătește la livrare.
