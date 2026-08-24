#!/bin/sh
# Backup zilnic ShelfShare: baza de date + fișierele urcate de useri.
#
# Rulează în containerul `backup` din docker-compose.prod.yml, pornit de crond
# (vezi crontab-ul din compose). Poate fi rulat și manual:
#   docker compose -f docker-compose.prod.yml exec backup /scripts/backup.sh
#
# Capcană la testare: busybox crond decide dacă recitește crontab-urile după
# mtime-ul DIRECTORULUI /etc/crontabs, nu al fișierului. Dacă rescrii
# /etc/crontabs/root în loc, cu crond deja pornit, modificarea e ignorată și
# pare că cron nu funcționează. La un test manual, dă și `touch /etc/crontabs`
# după ce scrii. În funcționare normală nu e o problemă: compose scrie
# crontab-ul înainte de a porni crond.
#
# Ce salvează:
#   - un dump SQL comprimat al bazei (pg_dump peste rețeaua internă Docker)
#   - o arhivă cu volumul MinIO (coperte, avatare, transcripturi de chat)
#
# Ce NU salvează: codul aplicației - ăla stă în git, nu are rost duplicat.
#
# CRIPTARE: ambele arhive conțin date personale - dump-ul are toată tabela
# User (emailuri, nume, orașe, hash-uri de parolă), iar arhiva MinIO conține
# transcripturile conversațiilor raportate și pozele userilor. Înainte erau
# scrise în clar, inclusiv pe discul extern (E:\Backup ShelfShare): un HDD
# pierdut sau un acces la NUC însemna toată baza de useri, fără să fie nevoie
# să spargă cineva aplicația. Acum trec prin `gpg --symmetric` (AES256) cu
# parola din $BACKUP_ENCRYPTION_PASSPHRASE.
#
# Restaurare:
#   gpg --decrypt shelfshare-AAAALLZZ-HHMMSS.sql.gz.gpg | gunzip | psql ...
#
# Retenție: ține ultimele $BACKUP_RETENTION_DAYS zile (implicit 14) și șterge
# restul. Fără curățare, volumul de backup crește până umple discul NUC-ului.

set -eu
# `pipefail` nu e POSIX, dar busybox ash (Alpine) îl are. Fără el, o eroare de
# pg_dump sau gpg la mijlocul pipeline-ului era înghițită: `mv` reușea oricum,
# deci rămânea un fișier cu aspect de backup valid, gol sau trunchiat.
(set -o pipefail) 2>/dev/null && set -o pipefail

# Fișierele de backup nu au motiv să fie citibile de alți utilizatori ai
# gazdei - fie ele și criptate.
umask 077

RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
EXTERNAL_KEEP="${BACKUP_EXTERNAL_KEEP:-10}"
PASSPHRASE="${BACKUP_ENCRYPTION_PASSPHRASE:-}"
ALLOW_UNENCRYPTED="${BACKUP_ALLOW_UNENCRYPTED:-false}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DB_DIR=/backups/db
FILES_DIR=/backups/files

# Discul extern (E:\Backup ShelfShare), montat din compose. Dacă lipsește -
# HDD deconectat, partajarea de drive oprită în Docker Desktop - continuăm
# doar cu copia locală, dar o spunem în log în loc să tăcem.
EXTERNAL_DIR=/backups-external

mkdir -p "$DB_DIR" "$FILES_DIR"

log() { echo "[backup $(date +%H:%M:%S)] $*"; }

# --- Criptare ---------------------------------------------------------------
# Oprim ÎNAINTE de a scrie ceva pe disc dacă lipsește parola: un backup
# necriptat creat "doar de data asta" rămâne pe disc luni de zile, iar
# avertismentul din log trece neobservat. Portița e explicită și trebuie
# cerută intenționat.
if [ -z "$PASSPHRASE" ] && [ "$ALLOW_UNENCRYPTED" != "true" ]; then
  log "EROARE: BACKUP_ENCRYPTION_PASSPHRASE nu e setată."
  log "  Dump-ul conține emailurile, numele și hash-urile de parolă ale tuturor"
  log "  userilor, iar o copie ajunge pe discul extern. Generează o parolă"
  log "  (openssl rand -base64 32), pune-o în .env și PĂSTREAZĂ-O SEPARAT -"
  log "  fără ea backup-urile devin nerecuperabile."
  log "  Pentru un backup necriptat deliberat: BACKUP_ALLOW_UNENCRYPTED=true"
  exit 1
fi

if [ -n "$PASSPHRASE" ]; then
  ENCRYPT=true
  SUFFIX=.gpg
else
  ENCRYPT=false
  SUFFIX=
  log "ATENȚIE: backup NECRIPTAT (BACKUP_ALLOW_UNENCRYPTED=true)"
fi

# Parola ajunge la gpg pe descriptorul 3, nu ca argument: argumentele sunt
# vizibile în `ps` oricărui proces din container.
encrypt_stream() {
  if [ "$ENCRYPT" != "true" ]; then
    cat
    return
  fi
  # --compress-algo none: intrarea e deja gzip/tar.gz, o a doua comprimare doar
  # consumă CPU fără să scadă dimensiunea.
  gpg --batch --yes --quiet --pinentry-mode loopback \
    --cipher-algo AES256 --compress-algo none \
    --passphrase-fd 3 --symmetric 3<<GPG_PASSPHRASE
$PASSPHRASE
GPG_PASSPHRASE
}

decrypt_stream() {
  if [ "$ENCRYPT" != "true" ]; then
    cat
    return
  fi
  gpg --batch --yes --quiet --pinentry-mode loopback \
    --passphrase-fd 3 --decrypt 3<<GPG_PASSPHRASE
$PASSPHRASE
GPG_PASSPHRASE
}

# Un backup pe care nu-l poți reciti nu e backup. Verificăm întreg lanțul
# (decriptare + integritatea gzip-ului), nu doar că fișierul e nenul.
verify_archive() {
  file="$1"
  if ! decrypt_stream < "$file" | gzip -t 2>/dev/null; then
    log "EROARE: $(basename "$file") nu trece verificarea - îl șterg"
    rm -f "$file"
    return 1
  fi
}

# --- Baza de date -----------------------------------------------------------
# Scriem întâi într-un fișier .partial și abia la final îl redenumim: dacă
# procesul e întrerupt la jumătate, nu rămâne un dump trunchiat care arată ca
# un backup valid.
DB_FILE="$DB_DIR/shelfshare-$STAMP.sql.gz$SUFFIX"
log "dump baza de date -> $(basename "$DB_FILE")"
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  --host=postgres \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  --no-owner --no-acl \
  | gzip -9 | encrypt_stream > "$DB_FILE.partial"
mv "$DB_FILE.partial" "$DB_FILE"
verify_archive "$DB_FILE"
log "baza de date: $(du -h "$DB_FILE" | cut -f1)"

# --- Fișierele din MinIO ----------------------------------------------------
# Volumul e montat read-only, deci arhivăm direct datele. Nu folosim `mc`
# fiindcă ar cere credențiale și un client în plus în imagine - avem deja
# acces la fișiere pe disc.
FILES_FILE="$FILES_DIR/minio-$STAMP.tar.gz$SUFFIX"
log "arhivez fișierele MinIO -> $(basename "$FILES_FILE")"
# Criptată și asta, nu doar baza: arhiva conține transcripturile
# conversațiilor raportate (`chat-reports/`) și pozele urcate de useri.
tar czf - -C /minio-data . 2>/dev/null | encrypt_stream > "$FILES_FILE.partial" || {
  # tar întoarce cod de eroare și când doar avertizează că un fișier s-a
  # schimbat cât timp îl citea (normal pe un sistem viu). Nu abandonăm
  # backup-ul pentru asta, dar nici nu îl declarăm reușit în silence.
  log "atenție: tar a raportat avertismente (fișiere modificate în timpul citirii)"
}
mv "$FILES_FILE.partial" "$FILES_FILE"
verify_archive "$FILES_FILE"
log "fișiere: $(du -h "$FILES_FILE" | cut -f1)"

# --- Copie pe discul extern -------------------------------------------------
# Volumul local stă pe același disc ca baza de date, deci nu acoperă o
# defecțiune de disc. Copia de aici e pe alt HDD fizic.
if [ -d "$EXTERNAL_DIR" ]; then
  log "copiez pe discul extern"
  mkdir -p "$EXTERNAL_DIR/db" "$EXTERNAL_DIR/files"

  # Aceeași tehnică .partial: pe un disc extern (sau montat prin Docker
  # Desktop) o copiere întreruptă ar lăsa altfel un fișier pe jumătate care
  # arată ca un backup bun.
  cp "$DB_FILE" "$EXTERNAL_DIR/db/$(basename "$DB_FILE").partial"
  mv "$EXTERNAL_DIR/db/$(basename "$DB_FILE").partial" "$EXTERNAL_DIR/db/$(basename "$DB_FILE")"

  cp "$FILES_FILE" "$EXTERNAL_DIR/files/$(basename "$FILES_FILE").partial"
  mv "$EXTERNAL_DIR/files/$(basename "$FILES_FILE").partial" "$EXTERNAL_DIR/files/$(basename "$FILES_FILE")"

  # Retenție pe număr de generații, nu pe zile: pe extern ținem ultimele
  # $EXTERNAL_KEEP, indiferent cât de rar a rulat backup-ul. Dacă mașina a fost
  # închisă o săptămână, o regulă pe zile ar fi șters copii pe care încă le vrem.
  #
  # Sortarea e pe NUME, nu pe dată de fișier: numele conține STAMP-ul
  # (AAAALLZZ-HHMMSS), deci ordinea alfabetică e ordine cronologică, iar
  # copierea pe alt volum poate schimba mtime-ul.
  prune_external() {
    dir="$1"
    pattern="$2"
    total=$(find "$dir" -maxdepth 1 -name "$pattern" -type f | wc -l)
    excess=$((total - EXTERNAL_KEEP))
    if [ "$excess" -gt 0 ]; then
      log "  șterg $excess generații vechi din $(basename "$dir")"
      find "$dir" -maxdepth 1 -name "$pattern" -type f | sort | head -n "$excess" |
        while IFS= read -r old; do rm -f "$old"; done
    fi
  }
  prune_external "$EXTERNAL_DIR/db" 'shelfshare-*.sql.gz*'
  prune_external "$EXTERNAL_DIR/files" 'minio-*.tar.gz*'

  log "  extern: $(find "$EXTERNAL_DIR/db" -name '*.sql.gz*' | wc -l) generații, $(du -sh "$EXTERNAL_DIR" | cut -f1)"
else
  log "ATENȚIE: discul extern nu e montat ($EXTERNAL_DIR lipsește) - doar copie locală"
fi

# --- Retenție locală --------------------------------------------------------
log "șterg backup-urile locale mai vechi de $RETENTION_DAYS zile"
find "$DB_DIR" -name 'shelfshare-*.sql.gz*' -type f -mtime "+$RETENTION_DAYS" -delete
find "$FILES_DIR" -name 'minio-*.tar.gz*' -type f -mtime "+$RETENTION_DAYS" -delete

# Curățăm și eventualele .partial rămase de la rulări întrerupte.
find /backups -name '*.partial' -type f -mtime +1 -delete

log "gata. Local: $(du -sh /backups | cut -f1)"
