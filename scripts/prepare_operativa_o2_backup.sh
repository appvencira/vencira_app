#!/usr/bin/env bash
# O2 paso de seguridad: backup de localcheck y restauracion aislada.
# No crea/reinicia servicios api/db/web_preview y NO aplica migraciones.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-o2-backup.XXXXXXXX.log)"
PHASE="INICIO"
RESTORE_NAME=""
RESTORE_STARTED=0
BACKUP=""
BACKUP_OK=0

finish() {
  local rc=$?
  trap - EXIT
  if [ "$RESTORE_STARTED" -eq 1 ]; then
    sudo docker stop "$RESTORE_NAME" >>"$LOG" 2>&1 || {
      echo "ALERTA: no se pudo detener el PostgreSQL temporal $RESTORE_NAME"
      rc=1
    }
  fi
  if [ "$rc" -eq 0 ] && [ "$BACKUP_OK" -eq 1 ]; then
    echo "RESULTADO_GLOBAL=0"
    echo "BACKUP_RESTAURACION_VERIFICADOS=1"
    echo "BACKUP=$BACKUP"
    echo "BACKUP_SHA256=$(sha256sum "$BACKUP" | awk '{print $1}')"
  else
    echo "RESULTADO_GLOBAL=${rc:-1}"
    echo "FASE_FALLIDA=$PHASE"
    echo "=== ULTIMAS 60 LINEAS DE DIAGNOSTICO ==="
    tail -n 60 "$LOG" || true
    echo "BACKUP_VERIFICADO=0"
  fi
  echo "NO_SE_APLICARON_MIGRACIONES=1"
  echo "NO_SE_REINICIARON_SERVICIOS_LOCALCHECK=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

step() {
  PHASE="$1"
  shift
  echo "=== $PHASE ==="
  "$@" >>"$LOG" 2>&1
  echo "OK: $PHASE"
}

echo "=== IDENTIDAD Y FUENTES ==="
PHASE=GIT_BRANCH
test "$(git branch --show-current)" = integration/local-e2e-prep
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: hay modificaciones versionadas; no se realizara el respaldo"
  git status --short
  exit 3
fi
EXTRA="$(git ls-files --others --exclude-standard |
  grep -vx 'clients/flutter/pubspec.lock' || true)"
if [ -n "$EXTRA" ]; then
  echo "ERROR: nuevos archivos inesperados en el checkout"
  printf '%s\n' "$EXTRA"
  exit 3
fi
VALIDATED_SHA=f7a62e3debe1e7534572ed6ec5e0e81ce1913539
git cat-file -e "$VALIDATED_SHA^{commit}"
if ! git diff --quiet "$VALIDATED_SHA" HEAD -- \
    backend clients compose.yaml compose.preview.yaml deploy; then
  echo "ERROR: el codigo de produccion ha cambiado desde el preflight validado"
  exit 3
fi
echo "CODIGO_PREVALIDADO=$VALIDATED_SHA"
echo "COMMIT_ACTUAL=$(git rev-parse HEAD)"
echo "FUENTES_VERSIONADAS=OK"

PHASE=COMPOSE_IDENTITY
# sudo anticipado para no introducir un prompt oculto en el backup redirigido.
sudo -v
for service in api db web_preview; do
  label="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  test "$label" = vencira_localcheck || {
    echo "ERROR: identidad Docker incorrecta para $service"
    exit 4
  }
done
echo "COMPOSE_IDENTITY=OK"
step COMPOSE_CONFIG sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml config --quiet

DB=vencira_localcheck-db-1
live_sql() {
  sudo docker exec "$DB" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq -c "$1"' \
    sh "$1"
}
PHASE=DB_SCHEMA_PRE0013
echo "=== ESTADO MIGRACIONES PERSISTENTES ==="
migration="$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$migration" = 0012_renewal_notes || {
  echo "ERROR: migracion maxima inesperada: $migration (esperada 0012_renewal_notes)"
  exit 5
}
echo "ULTIMA_MIGRACION=0012_renewal_notes"

BACKUP_DIR=/home/vencira/vencira-db-backups
PHASE=BACKUP_DIRECTORY
test ! -L "$BACKUP_DIR" || {
  echo "ERROR: el directorio de backups es un enlace simbolico"
  exit 6
}
mkdir -p -m 700 "$BACKUP_DIR"
test -O "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
BACKUP="$(mktemp "$BACKUP_DIR/pre0013_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXXXX.dump")"
chmod 600 "$BACKUP"
echo "=== COPIA PG_DUMP (formato custom) ==="
PHASE=PG_DUMP
sudo docker exec "$DB" sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -Fc -h 127.0.0.1 \
   -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  >"$BACKUP" 2>>"$LOG"
test -s "$BACKUP"
test "$(stat -c %a "$BACKUP")" = 600
echo "PG_DUMP=OK"
step PG_RESTORE_INDEX sh -c 'sudo docker exec -i vencira_localcheck-db-1 pg_restore -l < "$1" >/dev/null' \
  sh "$BACKUP"

PHASE=CHECKSUM
sha256sum "$BACKUP" > "$BACKUP.sha256"
chmod 600 "$BACKUP.sha256"
sha256sum --status -c "$BACKUP.sha256"
echo "SHA256=OK"

# Ensayo completo aislado en postgres:17, red deshabilitada, sin volumen persistente.
RESTORE_NAME="vencira_o2_restore_$$"
PHASE=RESTORE_CONTAINER
echo "=== RESTAURACION EFIMERA SIN RED NI VOLUMEN ==="
sudo docker run -d --rm --name "$RESTORE_NAME" --network none \
  -e POSTGRES_USER=o2_restore -e POSTGRES_DB=o2_restore \
  -e POSTGRES_PASSWORD=o2-restore-temporary-only \
  postgres:17-alpine >>"$LOG" 2>&1
RESTORE_STARTED=1
ready=0
for attempt in $(seq 1 40); do
  if sudo docker exec "$RESTORE_NAME" pg_isready -U o2_restore -d o2_restore \
     >>"$LOG" 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
test "$ready" = 1
PHASE=PG_RESTORE_COMPLETO
sudo docker exec -i "$RESTORE_NAME" pg_restore \
  --clean --if-exists --no-owner --no-privileges --exit-on-error \
  -U o2_restore -d o2_restore < "$BACKUP" >>"$LOG" 2>&1
echo "RESTAURACION_INTEGRAL=OK"

PHASE=RESTORE_SCHEMA
restored="$(sudo docker exec "$RESTORE_NAME" psql -X -v ON_ERROR_STOP=1 \
  -U o2_restore -d o2_restore -Atqc \
  "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$restored" = 0012_renewal_notes
# Contrastar conteos generales sin sacar valores personales a la terminal.
counts="SELECT (SELECT COUNT(*) FROM reminders_workspace)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_renewal)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_renewalauditevent)::text || ':' ||
               (SELECT COUNT(*) FROM django_migrations)::text;"
live_counts="$(live_sql "$counts")"
restored_counts="$(sudo docker exec "$RESTORE_NAME" psql \
  -X -v ON_ERROR_STOP=1 -U o2_restore -d o2_restore -Atqc "$counts")"
test "$live_counts" = "$restored_counts" || {
  echo "ERROR: los conteos difieren entre BD viva y copia restaurada"
  exit 8
}
echo "CONTENIDO_RESTAURADO=VERIFICADO"
echo "MIGRACION_0013_AUN_NO_APLICADA=1"

# Recibo no secreto vinculado al commit probado y al archivo restaurado.
PHASE=RECEIPT
printf 'VALIDATED_SHA=%s\nARCHIVE_SHA256=%s\nRESTORE_TEST=OK\n' \
 "$VALIDATED_SHA" "$(sha256sum "$BACKUP" | awk '{print $1}')" \
 > "$BACKUP.verified"
chmod 600 "$BACKUP.verified"
BACKUP_OK=1
