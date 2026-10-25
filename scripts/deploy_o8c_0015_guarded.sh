#!/usr/bin/env bash
# O8c — DEV-only one-time 0015 migration and API/Web deployment.
# Requires O5 restore proof. NEVER auto-rollback persistent database.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=INITIAL
LOG="$(mktemp /tmp/vencira-o8c-deploy.XXXXXXXX.log)"
RUN="$(date -u +%Y%m%dT%H%M%SZ)_$$"
RECEIPT=""
OLD_API_TAG=""
OLD_WEB_TAG=""
MIGRATION_STARTED=0
MIGRATION_CONFIRMED=0
API_RECREATED=0
WEB_RECREATED=0
finish(){
  rc=$?
  trap - EXIT
  if [ "$rc" -eq 0 ]; then
    echo "O8C_DESPLIEGUE_0015_LOCALCHECK=OK"
  else
    echo "FASE_FALLIDA=$PHASE"
    echo "MIGRACION_PUDO_HABERSE_APLICADO=$MIGRATION_STARTED"
    echo "MIGRACION_0015_VERIFICADA=$MIGRATION_CONFIRMED"
    echo "API_RECREADA=$API_RECREATED"
    echo "WEB_RECREADA=$WEB_RECREATED"
    echo "NO_REPETIR_SIN_VERIFICAR_ESQUEMA=1"
    echo "NO_RESTAURAR_DB_AUTOMATICAMENTE=1"
    echo "=== ULTIMAS_45_LINEAS_LOG_LOCAL ==="
    tail -n 45 "$LOG" 2>/dev/null || true
  fi
  if [ -n "$OLD_API_TAG" ]; then echo "IMAGEN_API_ANTERIOR=$OLD_API_TAG"; fi
  if [ -n "$OLD_WEB_TAG" ]; then echo "IMAGEN_WEB_ANTERIOR=$OLD_WEB_TAG"; fi
  if [ -n "$RECEIPT" ]; then echo "RECIBO_DESPLIEGUE=$RECEIPT"; fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "SIN_REINICIO_POSTGRES=1"
  echo "SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
step(){
  PHASE="$1"; shift
  echo "=== $PHASE ==="
  if "$@" >>"$LOG" 2>&1; then echo "$PHASE=OK"; else return $?; fi
}
test "$(id -u)" -eq 0 || { echo "ERROR=USAR_SUDO_BASH"; exit 2; }
for cmd in docker git curl restic rclone python3; do command -v "$cmd" >/dev/null; done
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra" || { echo "ERROR=ARCHIVOS_NO_VERSIONADOS"; exit 2; }
VALIDATED=80a5ac618f476a2d3b256499047dfdd1ada01c12
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients compose.yaml compose.preview.yaml deploy || {
  echo "ERROR=FUENTES_DIFERENTES_DEL_PREFLIGHT"; exit 2;
}
echo "FUENTES_PREFLIGHT_O8C=OK"
echo "COMMIT=$(git rev-parse HEAD)"

# Immutable proof of actual O5-restored clone migration.
PROOF=/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt
test -f "$PROOF" && test ! -L "$PROOF"
test "$(stat -c '%u:%a' "$PROOF")" = 0:600
grep -Fxq "VALIDATED_SHA=$VALIDATED" "$PROOF"
grep -Fxq 'SNAPSHOT_O5=0b838739' "$PROOF"
grep -Fxq 'MIGRATION=reminders.0015_renewal_reminder_drafts' "$PROOF"
grep -Fxq 'RESTIC_RESTORE=OK' "$PROOF"
grep -Fxq 'CLONE_MIGRATION=OK' "$PROOF"
grep -Fxq 'LIVE_SCHEMA=0014_UNCHANGED' "$PROOF"
age=$(( $(date +%s) - $(stat -c %Y "$PROOF") ))
test "$age" -ge 0 && test "$age" -le 86400
echo "RECIBO_RESTAURACION_O8C_VALIDO=OK"

COMPOSE=(docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" config --format json | python3 -c '
import json,sys
cmd=json.load(sys.stdin)["services"]["api"]["command"]
if isinstance(cmd,list): cmd=" ".join(cmd)
assert "migrate --check --noinput" in cmd
assert "migrate --noinput" not in cmd
' >>"$LOG" 2>&1
echo "API_MIGRATE_CHECK_ONLY=OK"
for svc in api db web_preview; do
  name="vencira_localcheck-$svc-1"
  test "$(docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
DB_ID="$(docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
echo "CONTENEDORES_PRE_HEALTHY=OK"

sql_read(){
  docker exec vencira_localcheck-db-1 sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
LAST_SQL="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(sql_read "$LAST_SQL")" = 0014_renewal_outcomes
test "$(sql_read "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NULL;")" = t
MIG_COUNT="$(sql_read 'SELECT COUNT(*) FROM django_migrations;')"
echo "POSTGRES_0014_PRE_MIGRACION=OK"
step O5_READ_ONLY bash scripts/o5_verify_active_schedule.sh
grep -Fxq 'TIMERS_ACTIVOS_Y_HABILITADOS=OK' "$LOG"
grep -Fxq 'COPIA_TRAS_REAUTORIZACION=SI' "$LOG"
grep -Fxq 'ULTIMO_SNAPSHOT_MENOS_36H=SI' "$LOG"
grep -Fxq 'AUDITORIA_FINAL_O5=OK' "$LOG"
echo "O5_CIFRADO_ACTIVO=OK"

PHASE=TAG_IMAGENES_PREVIAS
OLD_API_ID="$(docker inspect vencira_localcheck-api-1 --format '{{.Image}}')"
OLD_WEB_ID="$(docker inspect vencira_localcheck-web_preview-1 --format '{{.Image}}')"
docker image inspect "$OLD_API_ID" >/dev/null
docker image inspect "$OLD_WEB_ID" >/dev/null
OLD_API_TAG="vencira-o8c-before-api:$RUN"
OLD_WEB_TAG="vencira-o8c-before-web:$RUN"
step TAG_API_ANTERIOR docker tag "$OLD_API_ID" "$OLD_API_TAG"
step TAG_WEB_ANTERIOR docker tag "$OLD_WEB_ID" "$OLD_WEB_TAG"
RECEIPT="$(mktemp /tmp/vencira-o8c-deploy.XXXXXXXX.receipt)"
chmod 600 "$RECEIPT"
printf 'SOURCE_SHA=%s\nPREVIOUS_API=%s\nPREVIOUS_WEB=%s\nDB_ID=%s\nRESTORE_PROOF=%s\n' \
 "$VALIDATED" "$OLD_API_TAG" "$OLD_WEB_TAG" "$DB_ID" "$PROOF" > "$RECEIPT"
echo "IMAGENES_O8B_CONSERVADAS=OK"

# Builds never affect active containers. Only migrate after BOTH succeed.
step BUILD_API_WEB "${COMPOSE[@]}" build api web_preview
step PLAN_MIGRACION_0015 "${COMPOSE[@]}" run --rm --no-deps \
 api python manage.py migrate reminders 0015_renewal_reminder_drafts --plan
grep -Fq '0015_renewal_reminder_drafts' "$LOG"
test "$DB_ID" = "$(docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$OLD_API_ID" = "$(docker inspect vencira_localcheck-api-1 --format '{{.Image}}')"
test "$OLD_WEB_ID" = "$(docker inspect vencira_localcheck-web_preview-1 --format '{{.Image}}')"
echo "BUILD_Y_PLAN_0015_SIN_REINICIOS=OK"
