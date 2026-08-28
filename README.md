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

După prima dată, pentru fiecare update:

```
./scripts/deploy.sh
```

## Jurnalul global (activity log)

Fiecare interacțiune user-user și user-admin se scrie în fișiere text, nu în
baza de date: un fișier pe zi, în foldere an/lună.

```
logs/activity/2026/08/2026-08-28.log   # schimburi, oferte, licitații, follow,
                                       # blocări, rapoarte, acțiuni de admin
logs/chat/2026/08/2026-08-28.log       # mesajele (fișier separat: sunt de zeci
                                       # de ori mai multe și ar îneca restul)
```

O linie arată așa:

```
[14:03:22] Ana Pop (ab12cd34) → Ion Vasile (ef56ab78) OFFER_ACCEPTED {"carte":"Ion","suma":35}
```

În producție folderul e montat pe host (`./logs`, vezi `docker-compose.prod.yml`),
deci supraviețuiește rebuild-urilor. Variabile de mediu:

| Variabilă | Implicit | Ce face |
| --- | --- | --- |
| `ACTIVITY_LOG_DIR` | `<cwd>/logs` | rădăcina jurnalului |
| `ACTIVITY_LOG_TZ` | `Europe/Bucharest` | fusul care decide „ce zi e" |
| `ACTIVITY_LOG_CHAT_CONTENT` | `false` | `true` scrie și textul mesajelor (implicit doar lungimea) |
| `ACTIVITY_LOG_DISABLED` | `false` | `true` oprește complet scrierea |

## CI

La fiecare push pe `main` sau Pull Request, GitHub Actions rulează automat lint + build check pe backend. Deploy-ul rămâne manual (vezi mai sus) — se automatizează mai târziu, când are sens.
