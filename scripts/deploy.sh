#!/bin/sh
# Rulează asta pe NUC, în folderul shelfshare/, după ce ai făcut push pe GitHub.
# Usage: ./scripts/deploy.sh
#
# ATENȚIE: asta reface DOAR backend-ul (containerele Docker). Frontend-ul web
# (shelfshare.ro) e servit de static-server de pe cealaltă mașină și se
# reconstruiește separat, cu scripts/deploy-web.ps1 (vezi acel fișier). Dacă
# schimbi ceva în frontend, un `deploy.sh` singur nu se vede în browser.

set -e

echo "==> Aduc ultima versiune din git..."
git pull origin main

echo "==> Rebuild + restart containere..."
docker compose -f docker-compose.prod.yml up -d --build

echo "==> Status containere:"
docker compose -f docker-compose.prod.yml ps

echo "==> Gata. Loguri live cu:"
echo "    docker compose -f docker-compose.prod.yml logs -f"
