#!/usr/bin/env bash
# O5 — ensayo de recuperación en PG17 temporal: NO RESTAURA la base viva.
# Lee snapshot cifrado de Drive, lo vuelca por pipe hacia contenedor efímero
# sin escribir dump descifrado en almacenamiento persistente del host.
set -euo pipefail
umask 077
PHASE=INICIO
RESTORE_NAME=""
RESTORE_STARTED=0
LOG="$(mktemp /tmp/vencira-o5-restore.XXXXXXXX.log)"

finish() {
  local rc=$?
  trap - EXIT
  if [ "$RESTORE_STARTED" -eq 1 ]; then
    docker rm -f "$RESTORE_NAME" >>"$LOG" 2>&1 || rc=1
  fi
  if [ "$rc" -eq 0 ]; then
    echo "RESULTADO_GLOBAL=0"
    echo "O5_RESTAURACION_REMOTA_VERIFICADA=1"
  else
    echo "RESULTADO_GLOBAL=$rc"
    echo "FASE_FALLIDA=$PHASE"
    echo "=== ULTIMAS 30 LINEAS DIAGNOSTICO ==="
    tail -n 30 "$LOG" 2>/dev/null || true
  fi
  echo "POSTGRES_LOCALCHECK_NO_MODIFICADO=1"
  echo "SIN_DUMP_DESCIFRADO_EN_DISCO=1"
  echo "LOG_LOCAL=$LOG"
  exit "$rc"
}
trap finish EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: solo root; mantiene claves bajo /etc/vencira-backup"
  exit 2
fi
exec 8>/run/lock/vencira-o5-backup.lock
flock -n 8 || { echo "ERROR: otro proceso O5 está trabajando"; exit 2; }

PHASE=CONFIG
CONFIG_DIR=/etc/vencira-backup
test -d "$CONFIG_DIR" && test ! -L "$CONFIG_DIR" && test "$(stat -c %u:%a "$CONFIG_DIR")" = 0:700
test -f "$CONFIG_DIR/config.env" && test "$(stat -c %u:%a "$CONFIG_DIR/config.env")" = 0:600
# shellcheck disable=SC1091
. "$CONFIG_DIR/config.env"
: "${RESTIC_REPOSITORY:?}"
: "${RESTIC_PASSWORD_FILE:?}"
: "${RCLONE_CONFIG:?}"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = /etc/vencira-backup/restic-password
test "$RCLONE_CONFIG" = /etc/vencira-backup/rclone.conf
for file in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  test -f "$file" && test ! -L "$file" && test "$(stat -c %u:%a "$file")" = 0:600
done
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
for cmd in docker restic rclone flock; do command -v "$cmd" >/dev/null; done

PHASE=STACK_PRECONDITION
DB=vencira_localcheck-db-1
BEFORE_DB_ID="$(docker inspect "$DB" --format '{{.Id}}')"
test "$(docker inspect "$DB" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
test "$(docker inspect "$DB" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
restic snapshots --quiet >/dev/null
echo "DRIVE_SNAPSHOT_ACCESIBLE=1"

PHASE=RESTORE_CONTAINER
RESTORE_NAME="vencira_o5_pg_restore_$$"
docker run -d --rm --name "$RESTORE_NAME" --network none \
  -e POSTGRES_USER=o5_restore -e POSTGRES_DB=o5_restore \
  -e POSTGRES_PASSWORD=temporary-o5-only \
  postgres:17-alpine >>"$LOG" 2>&1
RESTORE_STARTED=1
ready=0
for attempt in $(seq 1 40); do
  if docker exec "$RESTORE_NAME" pg_isready -U o5_restore -d o5_restore >>"$LOG" 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
test "$ready" = 1
echo "PG17_EFIMERO_SIN_RED=OK"

PHASE=RESTIC_DUMP_TO_PG_RESTORE
echo "=== DESCIFRAR SOLO EN TRANSITO HACIA POSTGRES TEMPORAL ==="
restic dump latest vencira-postgres.dump 2>>"$LOG" |
  docker exec -i "$RESTORE_NAME" pg_restore \
    --clean --if-exists --no-owner --no-privileges --exit-on-error \
    -U o5_restore -d o5_restore >>"$LOG" 2>&1
echo "RESTAURACION_PG17_DESDE_DRIVE=OK"

PHASE=VERIFICACION_RESTORADA
schema="$(docker exec "$RESTORE_NAME" psql -X -v ON_ERROR_STOP=1 \
  -U o5_restore -d o5_restore -Atqc \
  "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$schema" = 0014_renewal_outcomes
n_migrations="$(docker exec "$RESTORE_NAME" psql -X -v ON_ERROR_STOP=1 \
  -U o5_restore -d o5_restore -Atqc "SELECT COUNT(*) FROM django_migrations;")"
test "$n_migrations" -gt 0
test "$BEFORE_DB_ID" = "$(docker inspect "$DB" --format '{{.Id}}')"
echo "ESQUEMA_O3_RESTAURADO=0014_renewal_outcomes"
echo "POSTGRES_ORIGINAL_INTACTO=1"
