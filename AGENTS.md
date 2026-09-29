# ShelfShare - instrucțiuni pentru agenți (Codex, Claude etc.)

## Versiunea de referință: tag-ul `GOLD`

- Tag-ul git **`GOLD`** marchează ultima versiune verificată și pusă live
  (web + backend + AAB Android). Istoric: `gold-2026-09-29` = 2.0.1 (versionCode 30).
- Lucrează ÎNTOTDEAUNA pornind de la `main` actualizat (care conține `GOLD`), niciodată
  de la un commit, branch sau folder mai vechi. Nu face `git checkout`/`reset` pe
  commituri anterioare lui `GOLD` și nu copia fișiere din backup-uri peste cod.
- Dacă ceva pare „pierdut", compară cu `git diff GOLD` înainte de a restaura ceva.

## Care e aplicația reală

| Folder      | Ce este                                                        | Se modifică?              |
|-------------|----------------------------------------------------------------|---------------------------|
| `web/`      | **Aplicația live**: React + Vite. Servește shelfshare.ro și, prin Capacitor (`web/android`), aplicația de Android din Play. | **DA - aici se lucrează** |
| `backend/`  | API NestJS + Prisma (api.shelfshare.ro)                        | DA                        |
| `frontend/` | Aplicația **Flutter VECHE**. Păstrată doar ca rollback.        | **NU** - excepție: textele din `frontend/lib/l10n/*.arb` |

- Textele (traducerile) se editează DOAR în `frontend/lib/l10n/app_*.arb` (ro, en, de, hu).
  `web/src/lib/i18n/locales/` e generat la fiecare build și e ignorat de git.
- O schimbare de UI făcută în `frontend/` (Dart) NU ajunge nicăieri live - arată ca
  „aplicația a revenit la varianta veche".

## Verificări înainte de commit

- `cd web && npx tsc -b --noEmit`
- `cd backend && npx tsc --noEmit -p tsconfig.json && npx jest`
- Migrările Prisma scrise de mână folosesc numele de tabelă din `@@map` (ex. `"bookshelf_entries"`),
  nu numele modelului.

## Deploy (doar la cererea explicită a proprietarului)

- Backend: `docker compose -f docker-compose.prod.yml up -d --build backend`
- Web: `powershell -File scripts/deploy-beta.ps1` (construiește contra `https://api.shelfshare.ro`)
- Android: `cd web && npx cap sync android`, apoi `gradlew bundleRelease` în `web/android`.
