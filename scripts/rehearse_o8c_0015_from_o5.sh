#!/usr/bin/env bash
# O8c rehearsal: ONLY an isolated PostgreSQL 17 clone of a fresh encrypted O5 backup.
# DO NOT migrate live DB, deploy, modify O5 config or discard snapshots.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=INITIAL
LOG="$(mktemp /tmp/vencira-o8c-rehearsal.XXXXXXXX.log)"
CLONE=""
NET=""
RECEIPT=""
finish(){
  rc=$?
  trap - EXIT
  if [ -n "$CLONE" ]; then docker rm -f "$CLONE" >>"$LOG" 2>&1 || rc=1; fi
  if [ -n "$NET" ]; then docker network rm "$NET" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$rc" -eq 0 ]; then echo "ENSAYO_O8C_0015_AISLADO=OK"; else
    echo "FASE_FALLIDA=$PHASE"
    tail -n 40 "$LOG" || true
  fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "NO_SE_MIGRO_NI_REINICIO_POSTGRES_ACTIVO=1"
  echo "SIN_DUMP_DESCIFRADO_EN_DISCO=1"
  echo "SIN_DESPLIEGUE_API_WEB=1"
  echo "SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1"
  if [ -n "$RECEIPT" ]; then echo "RECIBO_LOCAL=$RECEIPT"; fi
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
step(){
  PHASE="$1"; shift
  echo "=== $PHASE ==="
  "$@" >>"$LOG" 2>&1
  echo "$PHASE=OK"
}
test "$(id -u)" -eq 0 || { echo "ERROR=USAR_SUDO_BASH"; exit 2; }
for tool in git docker restic rclone flock; do command -v "$tool" >/dev/null; done
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra" || { echo "ERROR=ARCHIVOS_NO_VERSIONADOS"; exit 2; }
VALIDATED=80a5ac618f476a2d3b256499047dfdd1ada01c12
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients compose.yaml compose.preview.yaml deploy || {
  echo "ERROR=FUENTES_DISTINTAS_DE_PRECHECK_VERDE"; exit 3;
}
echo "FUENTES_PREFLIGHT_O8C=OK"
echo "COMMIT=$(git rev-parse HEAD)"
for svc in api db web_preview; do
  c="vencira_localcheck-$svc-1"
  test "$(docker inspect "$c" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(docker inspect "$c" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
LIVE=vencira_localcheck-db-1
DB_ID="$(docker inspect "$LIVE" --format '{{.Id}}')"
API_ID="$(docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
WEB_ID="$(docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
live_sql(){
  docker exec "$LIVE" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
MIG_SQL="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(live_sql "$MIG_SQL")" = 0014_renewal_outcomes
test "$(live_sql "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NULL;")" = t
MIG_COUNT="$(live_sql 'SELECT COUNT(*) FROM django_migrations;')"
COUNTS_SQL="SELECT (SELECT COUNT(*) FROM reminders_workspace)::text||':'||
  (SELECT COUNT(*) FROM reminders_renewal)::text||':'||
  (SELECT COUNT(*) FROM reminders_renewaloutcome)::text||':'||
  (SELECT COUNT(*) FROM reminders_renewalfollowup)::text||':'||
  (SELECT COUNT(*) FROM reminders_remindercandidate)::text||':'||
  (SELECT COUNT(*) FROM reminders_reminderpolicy)::text||':'||
  (SELECT COUNT(*) FROM django_migrations)::text;"
COUNTS_BEFORE="$(live_sql "$COUNTS_SQL")"
echo "POSTGRES_0014_ORIGINAL_PRE=OK"
step O5_STATUS bash scripts/o5_verify_active_schedule.sh
grep -Fxq "AUDITORIA_FINAL_O5=OK" "$LOG"
grep -Fxq "COPIA_TRAS_REAUTORIZACION=SI" "$LOG"
echo "O5_ESTADO_PREVIO=OK"
CFG=/etc/vencira-backup
test -d "$CFG" && test ! -L "$CFG" && test "$(stat -c %u:%a "$CFG")" = 0:700
test -f "$CFG/config.env" && test ! -L "$CFG/config.env" && test "$(stat -c %u:%a "$CFG/config.env")" = 0:600
. "$CFG/config.env"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = /etc/vencira-backup/restic-password
test "$RCLONE_CONFIG" = /etc/vencira-backup/rclone.conf
for file in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
 test -f "$file" && test ! -L "$file" && test "$(stat -c %u:%a "$file")" = 0:600
done
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
step COPIA_NUEVA_CIFRADA_DRIVE bash scripts/o5_backup_to_drive.sh
grep -Fxq "GOOGLE_DRIVE_BACKUP_CIFRADO=OK" "$LOG"
echo "O5_BACKUP_PRE0015=OK"
exec 8>/run/lock/vencira-o5-backup.lock
flock -n 8 || { echo "ERROR=O5_OCUPADO"; exit 4; }
