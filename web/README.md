# web/ — frontendul nou (React + Vite + TypeScript)

Înlocuitorul pe termen lung al aplicației Flutter din `frontend/`. **Backendul
nu se atinge**: acelaşi NestJS, aceleaşi 262 de endpointuri, acelaşi Socket.io.

Cât timp cele două coexistă:

| | rulează pe | servit de |
|---|---|---|
| Flutter (live, userii actuali) | `shelfshare.ro` | `scripts/static-server.js` (port 5959) |
| React (ăsta) | `beta.shelfshare.ro` | `scripts/beta-server.js` (port 5960) |

Comutarea finală e o singură regulă de ingress în tunelul Cloudflare. Nu implică
nicio migrare de date şi nicio schimbare de API, deci userii nu simt nimic.

## De ce React + Vite şi nu Next.js

Aplicaţia de Android (live pe Play, `ro.shelfshare.shelfshare`) trece şi ea pe
acest stack, prin Capacitor. Capacitor împachetează un **build static de
client** — Next.js cu SSR nu poate rula aşa, ar fi forţat pe `output: 'export'`,
adică exact fără motivul pentru care l-ai alege. Pentru SEO rămân paginile
statice HTML servite deja de `static-server.js`.

## Comenzi

```bash
npm install          # o singură dată
npm run dev          # http://localhost:5173, lovește zona de test (:3999)
npm run build        # -> dist/
npm run typecheck
npm run i18n         # regenerează traducerile din .arb (rulează singur la dev/build)
```

`.env.development` alege backendul. Fără variabilă, `dev` merge pe zona de test
şi `build` pe producţie — la fel ca `ApiConfig` din Flutter, şi din acelaşi
motiv: un build de release fără variabilă ajungea cu `localhost:3000` compilat
în binar, adică fiecare cerere de pe telefon lovea telefonul însuşi.

## Traduceri — sursa e tot `.arb`

`scripts/arb-to-json.mjs` citeşte `frontend/lib/l10n/app_*.arb` şi generează
`src/lib/i18n/locales/*.json` la fiecare `dev` şi `build`. Fişierele generate
**nu se comit**.

Motivul: cât timp Flutter e live, orice text nou se adaugă tot în `.arb`, ca
aplicaţia din producţie să-l primească. Două seturi paralele ar diverge de la
primul string adăugat — şi sunt ~1530 de chei × 4 limbi, adică nimeni nu observă
divergenţa la timp. **Adaugă texte noi în `.arb`, nu în JSON.**

Generatorul semnalează şi limbile rămase în urmă: în acest moment `de` şi `hu`
au cu 135 de chei mai puţin decât `ro`/`en` (lipsă preexistentă în Flutter).

## Ce e portat până acum

- Infrastructura: client API cu refresh de token, temă (light/dark), i18n,
  rutare cu gardian de autentificare, primitive de interfaţă, mesaje efemere
- Auth complet: **Login** (cu captcha), **Înregistrare**, **Confirmare cont**,
  **Resetare parolă** (4 paşi), **Callback Google**
- Cărţi: **Home**, **Descoperă**, **Răsfoieşte** (filtre + scroll infinit),
  **Raftul meu** (grilă/listă), **Detaliu carte**, **Raftul de lectură**
- Chat realtime: **Conversaţii**, **Conversaţie** (socket.io, prezenţă,
  „scrie…", confirmări de citire, poze), **Notificări**
- Profil: **Profilul meu**, **Editare**, **Profil public**, **Setări**,
  **Vânzători favoriţi**, **Activitate recentă**
- Liste: **Lista de dorinţe**, **Colecţii** (+ detaliu), **Căutări salvate**,
  **Coşul de gunoi**, **Cărţi cerute**
- Tranzacţii: **Schimburi** (+ oferte de preţ), **Pregătire schimb/vânzare**
- Social: **Clasament**, **Statistici globale**, **Grupuri** (+ detaliu),
  **Potriviri de schimb**, **Book Match**, **Feedback**

**Toate cele 63 de rute sunt legate.** Mai sunt trei sub-ecrane de admin care
randează `NotPortedYet` (cereri de carte, conturi de magazin, scor anunţuri) —
pe beta trebuie să se vadă diferenţa între „încă n-am ajuns aici" şi „e stricat".

Nu sunt portate încă, dinadins: scanarea codului de bare cu camera (ar cere o
bibliotecă separată; căutarea după ISBN tastat dă acelaşi rezultat) şi
compresia pozelor la upload.

## Decizii care nu se văd din cod

- **Coperţile Google Books NU trec prin `/books/cover-proxy`.** Proxy-ul exista
  fiindcă CanvasKit desenează imaginile din bytes obţinuţi cu `fetch`, deci
  supuşi CORS. Un `<img>` obişnuit nu e supus CORS pentru afişare — o cerere mai
  puţin către API pentru fiecare copertă de pe ecran.
- **`tokenStorage` are interfaţă asincronă** deşi implementarea de acum
  (localStorage) e sincronă. Pe Android/iOS va fi un plugin de secure storage,
  care e inerent asincron; expusă sincron acum, ar trebui rescris fiecare apelant.
- **Reîmprospătarea token-ului e „single-flight".** Refresh token-ul e rotit de
  backend la fiecare folosire, deci două cereri paralele care iau 401 ar
  prezenta al doilea token deja consumat — adică exact deconectarea pe care
  încercăm să o evităm.
- **Starea `restoring` e distinctă de `unauthenticated`.** Colapsate, fiecare
  reîncărcare de pagină ar arunca un user logat pe `/login` înainte ca
  `/profile/me` să răspundă, iar un link direct către o rută protejată s-ar
  pierde definitiv.
- **Filtrele de răsfoire stau în query string**, nu în state local. În Flutter
  erau argumente de rută; pe web, o căutare filtrată trebuie să fie un link care
  poate fi salvat la favorite, trimis mai departe sau redeschis cu butonul de
  back. Se scriu cu `replace`, altfel fiecare bifă ar adăuga o intrare în istoric.
- **Socketul e „connect în fundal", nu aşteptat.** Listele se încarcă pe HTTP;
  socketul doar le ţine proaspete. Aşteptat cu `await`, un handshake care nu se
  stabilea ţinea lista în „se încarcă" 15 secunde şi apoi o arunca în eroare,
  deşi API-ul răspundea perfect - şi, fiindcă toate aşteptau ACEEAŞI promisiune,
  un singur handshake căzut le strica pe toate deodată.
- **Transportul socketului e `['polling', 'websocket']`, polling PRIMUL.** Dacă
  websocket eşuează (un proxy sau tunel care blochează upgrade-ul), engine.io
  nu mai încearcă polling - `tryAllTransports` e false implicit - şi socketul
  rămâne mort fără nicio eroare. Sub Capacitor rulează tot engine.io de
  browser, deci lista e aceeaşi pe web şi pe mobil.
- **Se aşteaptă evenimentul `ready`, nu `connect`.** `connect` se declanşează
  la finalul handshake-ului, înainte ca serverul să termine join-ul în camera
  userului: un eveniment emis fix atunci s-ar pierde în tăcere.
- **Preferinţele de notificare se comută pe CATEGORII, dar se salvează pe TIP.**
  PUT-ul e parţial (`{preferences: [{type, enabled}]}`, nu harta plată), ca două
  tab-uri deschise să nu se suprascrie reciproc.
- **Doar `/assets/` primeşte cache immutable** (Vite pune hash de conţinut în
  nume). Regula nu se poate copia la `static-server.js`: acolo `/assets/` sunt
  asset-urile Flutter, fără hash — marcate immutable, au produs un bug de
  iconiţe invizibile.
