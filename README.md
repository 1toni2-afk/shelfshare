# ShelfShare

Platformă de schimb de cărți între oameni. Vezi specificația completă în `docs/` (dacă există) sau discuția din proiect.

## Structură

```
shelfshare/
├── backend/                  # NestJS API
│   ├── src/
│   ├── prisma/
│   │   └── schema.prisma
│   ├── Dockerfile            # imagine de producție
│   └── Dockerfile.dev        # imagine de dezvoltare (hot reload)
├── frontend/                 # Flutter (vine la milestone-ul respectiv)
├── docker-compose.yml        # dezvoltare locală
├── docker-compose.prod.yml   # producție, pe NUC
├── scripts/
│   └── deploy.sh             # deploy manual pe NUC
└── .github/workflows/ci.yml  # lint + build check automat
```

## Dezvoltare locală (Mac / PC)

1. Clonează repo-ul și intră în folder.
2. Copiază `.env.example` în `.env`:
   ```
   cp .env.example .env
   ```
3. Pornește totul:
   ```
   docker compose up -d --build
   ```
4. API-ul rulează pe `http://localhost:3000`, cu hot-reload — orice modificare din `backend/src` se reflectă automat.
5. Loguri live:
   ```
   docker compose logs -f backend
   ```

## Migrații Prisma

Când modifici `backend/prisma/schema.prisma`, generezi o migrație nouă:

```
docker compose exec backend pnpm exec prisma migrate dev --name numele_migratiei
```

## Deploy pe NUC (producție)

Prima dată:

1. Clonează repo-ul pe NUC.
2. Copiază `.env.example` în `.env` și completează parole reale (nu cele din exemplu).
3. Rulează:
   ```
   docker compose -f docker-compose.prod.yml up -d --build
   ```
4. Configurează Nginx Proxy Manager (UI la `http://IP-NUC:81`, credențiale default la prima logare — schimbă-le imediat) ca să facă proxy către `backend:3000`, cu domeniul tău (ex: `api.shelfshare.ro`) și HTTPS automat prin Let's Encrypt.

După prima dată, deploy-ul e automat (vezi „CI/CD" mai jos) — `./scripts/deploy.sh` rămâne util doar pentru un deploy manual/de urgență, direct pe NUC.

## Deploy web (shelfshare.ro)

Pe mașina care găzduiește `static-server.js`:

```
./scripts/deploy-web.ps1 -Pull -ApiBaseUrl https://api.shelfshare.ro
```

La fel, automatizat prin CI/CD după fiecare push pe `main` (vezi mai jos).

## CI/CD

La fiecare push pe `main` sau Pull Request, GitHub Actions rulează automat lint + teste + build pe backend și frontend (`backend-check` / `frontend-check`, pe runnere GitHub-hosted).

Doar la push direct pe `main` (nu la PR), și doar dacă ambele joburi de mai sus trec, rulează automat și deploy-ul:

- `deploy-backend` — pe un runner **self-hosted**, instalat pe NUC, rulează `./scripts/deploy.sh`.
- `deploy-web` — pe un runner **self-hosted**, instalat pe mașina cu `static-server.js`, rulează `./scripts/deploy-web.ps1`.

Ambele joburi rulează în clona persistentă existentă pe mașina respectivă (nu într-un checkout temporar al runner-ului) — calea vine din variabilele de repo `NUC_DEPLOY_PATH` / `WEB_DEPLOY_PATH` (**Settings → Secrets and variables → Actions → Variables**), ca să rămână scriptul de deploy singura sursă de adevăr pentru `git pull` + restart.

### Configurare runner self-hosted (o singură dată, per mașină)

1. **Settings → Actions → Runners → New self-hosted runner**, alegi OS-ul mașinii respective și copiezi comenzile generate acolo (au un token unic, expiră rapid — nu le refolosi de aici).
2. La pasul `config.sh` / `config.cmd`, adaugi eticheta corectă:
   - pe NUC: `--labels nuc`
   - pe mașina web: `--labels web`
3. Instalezi runner-ul ca serviciu, ca să pornească automat la reboot:
   - Linux (NUC): `sudo ./svc.sh install && sudo ./svc.sh start`
   - Windows: opțiunea de „Run as service" din `config.cmd`, sau `./svc.sh` echivalentul din pachetul descărcat.
4. Setezi variabila de repo corespunzătoare (`NUC_DEPLOY_PATH` / `WEB_DEPLOY_PATH`) cu calea absolută unde e clonat deja repo-ul pe acea mașină.

De atunci, orice merge pe `main` ajunge live automat, pe ambele mașini, fără pași manuali.
