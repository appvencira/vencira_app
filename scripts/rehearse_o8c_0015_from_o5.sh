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
# El usuario verifico la COPIA cifrada O5 real del intento previo:
# snapshot inmutable 0b838739, etiquetado vencira-postgresql.
# NO duplicar backup ni bloquear /run/lock/vencira-o5-backup.lock:
# restic puede leer el snapshot fijado aun cuando corra el timer O5.
# No seleccionar "latest" (evita una carrera o restaurar otra copia).
SNAPSHOT_ID=0b838739
verify_exact_snapshot(){
  restic snapshots --json --tag vencira-postgresql | python3 -c '
import datetime, json, sys, time
prefix=sys.argv[1]
rows=json.load(sys.stdin)
matches=[s for s in rows if isinstance(s,dict)
         and str(s.get("id","")).startswith(prefix)
         and "vencira-postgresql" in s.get("tags",[])]
if len(matches)!=1:
    raise SystemExit("ERROR=SNAPSHOT_O5_NO_ENCONTRADO_O_AMBIGUO")
raw=matches[0].get("time","")
dt=datetime.datetime.fromisoformat(raw.replace("Z","+00:00"))
age=time.time()-dt.timestamp()
if not 0 <= age <= 86400:
    raise SystemExit("ERROR=SNAPSHOT_O5_SUPERA_24H")
print("SNAPSHOT_O5_VERIFICADO="+prefix)
print("SNAPSHOT_O5_ANTIGUEDAD_MENOS_24H=SI")
' "$SNAPSHOT_ID"
}
step SNAPSHOT_O5_EXACTO_Y_RECIENTE verify_exact_snapshot
echo "O5_BACKUP_PRE0015_REUTILIZADO=OK"

NET="vencira_o8c_internal_$$"
CLONE="vencira_o8c_clone_$$"
step RED_PRIVADA docker network create --internal "$NET"
step POSTGRES17_TEMPORAL docker run -d --rm --name "$CLONE" --network "$NET" \
 -e POSTGRES_USER=o8c_clone -e POSTGRES_DB=o8c_clone \
 -e POSTGRES_PASSWORD=o8c-ephemeral-2026-only postgres:17-alpine
ready=0
for i in $(seq 1 45); do
  if docker exec "$CLONE" pg_isready -U o8c_clone -d o8c_clone >>"$LOG" 2>&1; then ready=1; break; fi
  sleep 2
done
test "$ready" = 1
echo "PG17_TEMPORAL_AISLADO=OK"
PHASE=RESTIC_DUMP_PIPE
echo "=== RESTAURACION_O5_DRIVE_AL_CLON ==="
restic dump "$SNAPSHOT_ID" vencira-postgres.dump 2>>"$LOG" |
  docker exec -i "$CLONE" pg_restore --clean --if-exists \
   --no-owner --no-privileges --exit-on-error -U o8c_clone -d o8c_clone \
   >>"$LOG" 2>&1
echo "RESTAURACION_DRIVE_PG17_TEMPORAL=OK"
clone_sql(){
 docker exec "$CLONE" psql -X -v ON_ERROR_STOP=1 \
   -U o8c_clone -d o8c_clone -Atqc "$1"
}
PHASE=RESTORE_VERIFY
test "$(clone_sql "$MIG_SQL")" = 0014_renewal_outcomes
test "$(clone_sql "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NULL;")" = t
CLONE_BEFORE="$(clone_sql "$COUNTS_SQL")"
test "$CLONE_BEFORE" = "$COUNTS_BEFORE" || {
  echo "ERROR=CONTEOS_BACKUP_Y_ORIGINAL_DIFIEREN; revisar escrituras concurrentes"
  exit 5
}
echo "RESTAURACION_CONTEOS_VERIFICADOS=OK"
IMAGE="vencira-o8c-rehearsal:$(git rev-parse --short=12 HEAD)"
step BUILD_API_TEMPORAL docker build -t "$IMAGE" ./backend
DJANGO=(docker run --rm --network "$NET"
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql
  -e DJANGO_DEBUG=0
  -e DJANGO_SECRET_KEY=o8c-ephemeral-only-django-secret-key-2026-unique
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
  -e POSTGRES_HOST="$CLONE" -e POSTGRES_PORT=5432
  -e POSTGRES_DB=o8c_clone -e POSTGRES_USER=o8c_clone
  -e POSTGRES_PASSWORD=o8c-ephemeral-2026-only "$IMAGE")
step MIGRATE_PLAN_SOLO_CLON "${DJANGO[@]}" \
  python manage.py migrate reminders 0015_renewal_reminder_drafts --plan
grep -Fq "0015_renewal_reminder_drafts" "$LOG" || {
 echo "ERROR=PLAN_NO_INCLUYE_0015"; exit 6;
}
echo "PLAN_MIGRACION_0015=OK"
step MIGRATE_0015_SOLO_CLON "${DJANGO[@]}" \
  python manage.py migrate reminders 0015_renewal_reminder_drafts --noinput
PHASE=VERIFY_MIGRATION_CLONE
test "$(clone_sql "$MIG_SQL")" = 0015_renewal_reminder_drafts
test "$(clone_sql "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NOT NULL;")" = t
test "$(clone_sql "SELECT COUNT(*) FROM reminders_renewalreminderdraft;")" = 0
test "$(clone_sql "SELECT COUNT(*) FROM pg_constraint WHERE conrelid='public.reminders_renewalreminderdraft'::regclass AND conname IN ('renewal_reminder_draft_only','renewal_reminder_revision_positive');")" = 2
AFTER="$(clone_sql "$COUNTS_SQL")"
BASE="$(printf %s "$CLONE_BEFORE" | sed 's/:[^:]*$//')"
CURRENT="$(printf %s "$AFTER" | sed 's/:[^:]*$//')"
test "$BASE" = "$CURRENT"
test "$(clone_sql 'SELECT COUNT(*) FROM django_migrations;')" = "$((MIG_COUNT+1))"
echo "0015_APLICADA_SOLO_EN_CLON=OK"
echo "DRAFT_ONLY_CONSTRAINTS=OK"
echo "SIN_BACKFILL_Y_TABLAS_ANTERIORES_INTACTAS=OK"

PHASE=VERIFY_ORIGINAL_UNCHANGED
test "$DB_ID" = "$(docker inspect "$LIVE" --format '{{.Id}}')"
test "$API_ID" = "$(docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
test "$WEB_ID" = "$(docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
test "$(live_sql "$MIG_SQL")" = 0014_renewal_outcomes
test "$(live_sql "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NULL;")" = t
test "$(live_sql 'SELECT COUNT(*) FROM django_migrations;')" = "$MIG_COUNT"
for svc in api db web_preview; do
 c="vencira_localcheck-$svc-1"
 test "$(docker inspect "$c" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
echo "POSTGRES_0014_API_WEB_SIN_CAMBIOS=OK"
PHASE=RECEIPT
RECEIPT="$(mktemp /tmp/vencira-o8c-rehearsal.XXXXXXXX.receipt)"
chmod 600 "$RECEIPT"
printf 'VALIDATED_SHA=%s\nSNAPSHOT_O5=%s\nMIGRATION=reminders.0015_renewal_reminder_drafts\nRESTIC_RESTORE=OK\nCLONE_MIGRATION=OK\nLIVE_SCHEMA=0014_UNCHANGED\n' \
 "$VALIDATED" "$SNAPSHOT_ID" > "$RECEIPT"
echo "RECIBO_ENSAYO_O8C=OK"
