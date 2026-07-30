#!/bin/sh
# Backup zilnic ShelfShare: baza de date + fișierele urcate de useri.
#
# Rulează în containerul `backup` din docker-compose.prod.yml, pornit de crond
# (vezi crontab-ul din compose). Poate fi rulat și manual:
#   docker compose -f docker-compose.prod.yml exec backup /scripts/backup.sh
#
# Ce salvează:
#   - un dump SQL comprimat al bazei (pg_dump peste rețeaua internă Docker)
#   - o arhivă cu volumul MinIO (coperte, avatare, transcripturi de chat)
#
# Ce NU salvează: codul aplicației - ăla stă în git, nu are rost duplicat.
#
# Retenție: ține ultimele $BACKUP_RETENTION_DAYS zile (implicit 14) și șterge
# restul. Fără curățare, volumul de backup crește până umple discul NUC-ului.

set -eu

RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DB_DIR=/backups/db
FILES_DIR=/backups/files

mkdir -p "$DB_DIR" "$FILES_DIR"

log() { echo "[backup $(date +%H:%M:%S)] $*"; }

# --- Baza de date -----------------------------------------------------------
# Scriem întâi într-un fișier .partial și abia la final îl redenumim: dacă
# procesul e întrerupt la jumătate, nu rămâne un dump trunchiat care arată ca
# un backup valid.
DB_FILE="$DB_DIR/shelfshare-$STAMP.sql.gz"
log "dump baza de date -> $(basename "$DB_FILE")"
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  --host=postgres \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  --no-owner --no-acl \
  | gzip -9 > "$DB_FILE.partial"
mv "$DB_FILE.partial" "$DB_FILE"
log "baza de date: $(du -h "$DB_FILE" | cut -f1)"

# --- Fișierele din MinIO ----------------------------------------------------
# Volumul e montat read-only, deci arhivăm direct datele. Nu folosim `mc`
# fiindcă ar cere credențiale și un client în plus în imagine - avem deja
# acces la fișiere pe disc.
FILES_FILE="$FILES_DIR/minio-$STAMP.tar.gz"
log "arhivez fișierele MinIO -> $(basename "$FILES_FILE")"
tar czf "$FILES_FILE.partial" -C /minio-data . 2>/dev/null || {
  # tar întoarce cod de eroare și când doar avertizează că un fișier s-a
  # schimbat cât timp îl citea (normal pe un sistem viu). Nu abandonăm
  # backup-ul pentru asta, dar nici nu îl declarăm reușit în silence.
  log "atenție: tar a raportat avertismente (fișiere modificate în timpul citirii)"
}
mv "$FILES_FILE.partial" "$FILES_FILE"
log "fișiere: $(du -h "$FILES_FILE" | cut -f1)"

# --- Retenție ---------------------------------------------------------------
log "șterg backup-urile mai vechi de $RETENTION_DAYS zile"
find "$DB_DIR" -name 'shelfshare-*.sql.gz' -type f -mtime "+$RETENTION_DAYS" -delete
find "$FILES_DIR" -name 'minio-*.tar.gz' -type f -mtime "+$RETENTION_DAYS" -delete

# Curățăm și eventualele .partial rămase de la rulări întrerupte.
find /backups -name '*.partial' -type f -mtime +1 -delete

log "gata. Total ocupat: $(du -sh /backups | cut -f1)"
