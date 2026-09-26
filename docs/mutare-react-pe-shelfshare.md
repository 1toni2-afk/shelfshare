# Mutarea shelfshare.ro de pe Flutter pe React

Azi: `shelfshare.ro` → `static-server.js` (Flutter, port 5959), `beta.shelfshare.ro`
→ `beta-server.js` (React, port 5960) care vorbește cu backendul de TEST
(`api-beta` → 3999). Mutarea înseamnă: React pe domeniul principal, vorbind cu
backendul de PRODUCȚIE. Aplicația Android (Flutter, din Play) nu e atinsă — ea
vorbește doar cu API-ul.

Ordinea contează. Fiecare pas se poate verifica înainte de următorul, iar până
la pasul 5 nimic nu se schimbă pentru vizitatorii shelfshare.ro.

## 0. Înainte de orice

- **Commit la tot.** `docker compose ... --build` construiește backendul din
  working tree, deci ce e necomis ajunge în producție fără să rămână în istoric.
  La fel `deploy-beta.ps1` pentru `web/`.
- **Backup verificat** al bazei de producție (vezi memoria „Backup verificat prin
  restaurare").

## 1. Backendul de producție

Producția rulează o imagine din 2026-09-22. Îi lipsesc endpointurile pe care
React le folosește deja pe beta (`/profile/:id/compatibility`, `currentlyReading`,
`availableBooks`, like-urile și comentariile din feed) și două migrări:

| Migrare | Ce face | Sigură înaintea codului? |
| --- | --- | --- |
| `20260925180000_feed_likes_comments` | tabele noi + `ALTER TYPE "ReportTargetType" ADD VALUE` + coloană nullabilă în `reports` | da, strict aditivă |
| `20260926120000_refresh_sessions` | tabelă nouă `refresh_sessions` | da, strict aditivă |

Containerul rulează `prisma migrate deploy` la pornire, deci ajunge:

```
docker compose -f docker-compose.prod.yml up -d --build backend
```

Ce se schimbă pentru userii existenți (inclusiv aplicația Flutter din Play):

- **Sesiunile de login.** Token-urile de refresh poartă acum un `sid` legat de un
  rând din `refresh_sessions`. Token-urile vechi (fără `sid`) sunt acceptate încă
  maximum 30 de zile și mutate automat pe o sesiune la primul refresh — nimeni
  nu e delogat de deploy.
- **Ban-ul chiar blochează.** Un cont banat nu se mai poate autentifica, iar
  sesiunile, token-urile de acces și socket-ul de chat îi sunt închise pe loc.
- **Resetul de parolă** închide toate sesiunile contului.

Verificare: `curl -s -o NUL -w "%{http_code}" http://localhost:3000/profile/00000000-0000-0000-0000-000000000000/compatibility`
trebuie să dea **401** (ruta există, cere login), nu 404.

## 2. Build-ul React contra producției

```
.\scripts\deploy-beta.ps1 -ApiBaseUrl https://api.shelfshare.ro
```

Din acest moment **beta.shelfshare.ro vorbește cu producția**. E momentul de
testat pe beta cu un cont real: login cu email, chat, un schimb, notificări.
(Login-ul cu Google redirecționează la `FRONTEND_URL` = shelfshare.ro, care e
încă Flutter până la pasul 5 — se testează după.)

`web/dist/build-info.json` trebuie să arate `"apiBaseUrl": "https://api.shelfshare.ro"`.
`beta-seo.js` îl citește singur, deci HTML-ul pre-randat vine din același backend.

## 3. Adresa canonică

În `scripts/start-beta-server.bat` se decomentează:

```
set BETA_SITE_URL=https://shelfshare.ro
set REDIRECT_HOSTS=beta.shelfshare.ro,www.shelfshare.ro
```

- `BETA_SITE_URL` → canonical, `og:url`, `sitemap.xml` și `robots.txt` indică
  shelfshare.ro. Fără el, Google ar indexa beta în locul domeniului.
- `REDIRECT_HOSTS` → beta și www primesc 301 spre shelfshare.ro (fără conținut
  duplicat).

Repornire (fișierul `.bat` se citește la pornire; **nu** doar procesul node —
cmd recitește un `.bat` modificat de la offsetul vechi și poate executa linii
rupte):

```
Stop-ScheduledTask -TaskName "ShelfShare Beta Server"
Get-CimInstance Win32_Process | ? { $_.CommandLine -match 'beta-server\.js|start-beta-server\.bat' } | % { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep 3; Start-ScheduledTask -TaskName "ShelfShare Beta Server"
```

## 4. Tunelul

Din PowerShell **ca administrator**:

```
.\scripts\switch-web-to-react.ps1
```

Scriptul refuză comutarea dacă: build-ul React nu țintește producția, canonical-ul
nu e shelfshare.ro, sau backendul de producție e încă cel vechi. Pleacă de la
configul LIVE al serviciului și schimbă doar portul pentru `shelfshare.ro` și
`www.shelfshare.ro` (5959 → 5960); restul gazdelor (api, storage, beta, api-beta,
runapp) rămân neatinse. La final verifică să fie un singur proces cloudflared.

**Rollback** (Flutter înapoi, `static-server.js` rămâne pornit tocmai pentru asta):

```
.\scripts\switch-web-to-react.ps1 -Rollback
```

## 5. Verificări după comutare

- `https://shelfshare.ro/build-info.json` → 200 (e React); `https://beta.shelfshare.ro/x` → 301 spre shelfshare.ro.
- `https://shelfshare.ro/app-ads.txt` → linia AdMob. **Dacă lipsește, AdMob
  taie reclamele din aplicația Android** (beta-server îl servește acum).
- `https://shelfshare.ro/flutter_service_worker.js` → scriptul care se
  dezînregistrează. Browserele cu worker-ul Flutter vechi trec singure pe React.
- `/privacy`, `/terms`, `/safety-center`, `/help-center` (și `/en/...`) → paginile statice.
- `/get-the-app` → 302 spre Play Store (adresa apare pe materiale tipărite).
- O carte și un profil: titlul corect în tab și în „view source" (canonical pe shelfshare.ro).
- Login cu Google pe shelfshare.ro (acum ajunge la `/auth/google/callback` din React).
- GA4 → Realtime: după „Accept" în banner apar page view-uri.
- Search Console: retrimite `https://shelfshare.ro/sitemap.xml`.

## Ce trebuie știut dinainte

- **Toți userii web se vor autentifica o dată din nou.** Flutter ținea token-urile
  în `flutter_secure_storage` (criptate), React în `localStorage`; nu le migrăm.
- **Consimțământul GA se păstrează**: aceeași cheie (`ss-analytics-consent`), aceeași origine.
- **Conturile create pe beta nu există în producție** — beta a scris în baza de
  test. La 2026-09-26 era un singur cont real acolo (adresă yahoo.com).
- **Statisticile din aplicația de Android pe Capacitor** nu sunt portate
  (Flutter folosește Firebase Analytics); pe web GA merge.
- Flutter web (`frontend/build/web` + `static-server.js`) rămâne ca rollback;
  se poate opri după câteva zile fără probleme.

## Probleme găsite la auditul din 2026-09-26 (rezolvate în cod)

| Problemă | Unde | Stare |
| --- | --- | --- |
| XSS stocat: nume de user / titlu de carte cu `</script>` în JSON-LD | `beta-seo.js`, `static-server.js` | reparat; beta live, producția cere repornirea `static-server.js` |
| Un singur request (`/%00`, `/%ZZ`) oprea serverul web | `beta-server.js`, `static-server.js` | reparat; idem |
| Resetul de parolă folosea codul fix de test → preluarea oricărui cont de pe api-beta | `auth.service.ts` | reparat și live pe api-beta |
| Token-urile de refresh vechi rămâneau valide după logout/reset (bcrypt vede doar 72 de octeți) | `auth.service.ts` | sesiuni pe dispozitiv; live pe api-beta, producția la pasul 1 |
| Ban-ul nu bloca login-ul | `auth.service.ts`, `admin.service.ts` | reparat; idem |
| Coduri de 6 cifre fără plafon de încercări pe cont | `auth.service.ts` | 5 încercări pe cod |
| Parola conturilor demo publicată la `/demo/README.md` | `web/public/demo` | mutată în `docs/capturi-see-demo.md`, blocat `.md` |
| HTML-ul pre-randat de pe beta lista cărți din producție, aplicația din test | `start-beta-server.bat` | API-ul vine acum din `build-info.json` |
| Hărțile de surse publice | `vite.config.ts`, `beta-server.js` | `hidden` + blocate |
| Fără antete anti-clickjacking / Referrer-Policy / HSTS | `beta-server.js` | adăugate |
| Backendul de test fără `TRUST_PROXY` → o singură limită de rate pentru toți userii beta | `.env.test` | setat |
| Anunțuri ascunse de moderare vizibile în `listedBooks` (profil public Flutter) | `profile.service.ts` | reparat |
| Copia din repo a configului de tunel nu avea `runapp.shelfshare.ro` | `cloudflared-config.beta.yml` | sincronizată |
