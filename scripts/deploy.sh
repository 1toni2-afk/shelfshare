#!/bin/sh
# Rulează asta pe NUC, în folderul shelfshare/, după ce ai făcut push pe GitHub.
# Usage: ./scripts/deploy.sh

set -e

echo "==> Aduc ultima versiune din git..."
git pull origin main

echo "==> Rebuild + restart containere..."
docker compose -f docker-compose.prod.yml up -d --build

echo "==> Status containere:"
docker compose -f docker-compose.prod.yml ps

echo "==> Gata. Loguri live cu:"
echo "    docker compose -f docker-compose.prod.yml logs -f"
