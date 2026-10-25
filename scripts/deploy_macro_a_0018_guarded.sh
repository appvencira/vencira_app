#!/usr/bin/env bash
# Macro A: guarded migration and API/web deployment to DEV. NOT a rollback script.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=IDENTITY
LOG="$(mktemp /tmp/vencira-macro-a-deploy.XXXXXXXX.log)"
RECEIPT="$(mktemp /tmp/vencira-macro-a-deploy.XXXXXXXX.receipt)"
chmod 600 "$RECEIPT"
RUN="$(date -u +%Y%m%dT%H%M%SZ)_$$"
MIGRATION_STARTED=0
API_RECREATED=0
WEB_RECREATED=0
finish() {
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "MIGRACION_PUDO_HABERSE_APLICADO=$MIGRATION_STARTED"
    echo "API_RECREADA=$API_RECREATED"
    echo "WEB_RECREADA=$WEB_RECREATED"
    echo "NO_REPETIR_SIN_DIAGNOSTICO=1"
    echo "NO_RESTAURAR_DB_AUTOMATICAMENTE=1"
    tail -n 20 "$LOG" 2>/dev/null || true
  else
    echo "MACRO_A_DEV_DESPLIEGUE=OK"
  fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "LOG_LOCAL=$LOG"
  echo "RECIBO_LOCAL=$RECEIPT"
  echo "SIN_REINICIO_POSTGRES=1"
  echo "SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1"
  exit "$rc"
}
trap finish EXIT
step() { PHASE="$1"; shift; echo "=== $PHASE ==="; "$@" >>"$LOG" 2>&1; echo "$PHASE=OK"; }
test "$(id -u)" -eq 0
if [ "${MACRO_A_DEPLOY_CONFIRM:-}" != "DEPLOY_0017_0018_DEV" ]; then
  echo "ERROR=CONFIRMACION_EXPLICITA_REQUERIDA"
  exit 3
fi
if [ "${MACRO_A_O5_VERIFIED_SNAPSHOT:-}" != "4341e05e" ]; then
  echo "ERROR=ENSAYO_O5_NO_ACREDITADO"
  exit 3
fi
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
VALIDATED=b8654ddaaf7f4e57322e564d566af0072ce8e9ee
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients compose.yaml compose.preview.yaml deploy
echo "FUENTES_IDENTICAS_GATE_VALIDADO=OK"
echo "COMMIT=$(git rev-parse HEAD)"
COMPOSE=(docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" config --format json | python3 -c 'import json,sys;x=json.load(sys.stdin)["services"]["api"]["command"];x=" ".join(x) if isinstance(x,list) else x;assert "migrate --check --noinput" in x and "migrate --noinput" not in x' >>"$LOG" 2>&1
echo "MIGRATE_CHECK_ONLY=OK"
DB=vencira_localcheck-db-1
API=vencira_localcheck-api-1
WEB=vencira_localcheck-web_preview-1
for name in "$DB" "$API" "$WEB"; do
 test "$(docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
 test "$(docker inspect "$name" --format '{{.State.Health.Status}}')" = healthy
done
DB_ID="$(docker inspect "$DB" --format '{{.Id}}')"
OLD_API="$(docker inspect "$API" --format '{{.Image}}')"
OLD_WEB="$(docker inspect "$WEB" --format '{{.Image}}')"
sql() { docker exec "$DB" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"; }
LAST="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(sql "$LAST")" = 0016_renewal_control_responses
COUNT="$(sql 'SELECT COUNT(*) FROM django_migrations;')"
echo "DEV_0016_PRE=OK"
PHASE=O5_PRECHECK
# Read-only schedule and snapshot checks. A successful restoration rehearsal
# from the CURRENT schema is independently required before running this script.
step O5_AUDIT bash scripts/o5_verify_active_schedule.sh
grep -Fxq 'AUDITORIA_FINAL_O5=OK' "$LOG"
grep -Fxq 'ULTIMO_SNAPSHOT_MENOS_36H=SI' "$LOG"
echo "O5_READ_ONLY=OK"
PHASE=PRESERVE_IMAGES
OLD_API_TAG="vencira-macro-a-pre-api:$RUN"
OLD_WEB_TAG="vencira-macro-a-pre-web:$RUN"
step TAG_OLD_API docker tag "$OLD_API" "$OLD_API_TAG"
step TAG_OLD_WEB docker tag "$OLD_WEB" "$OLD_WEB_TAG"
printf 'VALIDATED_SHA=%s\nOLD_API=%s\nOLD_WEB=%s\nDB_ID=%s\n' "$VALIDATED" "$OLD_API_TAG" "$OLD_WEB_TAG" "$DB_ID" > "$RECEIPT"
echo "IMAGENES_PREVIAS_RECUPERABLES=OK"
step BUILD_API "${COMPOSE[@]}" build api
step BUILD_WEB "${COMPOSE[@]}" build web_preview
step MIGRATION_PLAN "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate reminders 0018_draft_reasons --plan
grep -Fq '0017_operational_reminders' "$LOG"
grep -Fq '0018_draft_reasons' "$LOG"
test "$(sql "$LAST")" = 0016_renewal_control_responses
test "$(docker inspect "$DB" --format '{{.Id}}')" = "$DB_ID"
echo "PLAN_0017_0018=OK"
# Create fresh backup only after images and plan are ready.
step FRESH_BACKUP_O5 bash scripts/o5_backup_to_drive.sh
grep -Fxq 'GOOGLE_DRIVE_BACKUP_CIFRADO=OK' "$LOG"
grep -Fxq 'RESTIC_INTEGRIDAD_METADATA=OK' "$LOG"
echo "O5_FRESH_BEFORE_SCHEMA=OK"
PHASE=APPLY_MIGRATIONS
MIGRATION_STARTED=1
step APPLY_0017_0018 "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate reminders 0018_draft_reasons --noinput
PHASE=SCHEMA_VERIFY
test "$(sql "$LAST")" = 0018_draft_reasons
test "$(sql 'SELECT COUNT(*) FROM django_migrations;')" = "$((COUNT+2))"
test "$(sql "SELECT to_regclass('public.reminders_operationalreminder') IS NOT NULL;")" = t
test "$(sql "SELECT to_regclass('public.reminders_operationalreminderevent') IS NOT NULL;")" = t
echo "DEV_0018_VERIFICADO=OK"
step POST_MIGRATE_CHECK "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate --check --noinput
PHASE=DEPLOY_API
API_RECREATED=1
step DEPLOY_API "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate api
for i in $(seq 1 40); do
 health="$(docker inspect "$API" --format '{{.State.Health.Status}}')"
 if [ "$health" = healthy ] || [ "$health" = unhealthy ]; then break; fi
 sleep 5
done
test "$health" = healthy
echo "HEALTH_API=healthy"
PHASE=DEPLOY_WEB
WEB_RECREATED=1
step DEPLOY_WEB "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate web_preview
for i in $(seq 1 40); do
 health="$(docker inspect "$WEB" --format '{{.State.Health.Status}}')"
 if [ "$health" = healthy ] || [ "$health" = unhealthy ]; then break; fi
 sleep 5
done
test "$health" = healthy
echo "HEALTH_WEB=healthy"
PHASE=FINAL
test "$(docker inspect "$DB" --format '{{.Id}}')" = "$DB_ID"
test "$(docker inspect "$DB" --format '{{.State.Health.Status}}')" = healthy
test "$(sql "$LAST")" = 0018_draft_reasons
for path in / /api/health/ /api/ready/; do
 test "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732$path")" = 200
done
uuid1=11111111-1111-4111-8111-111111111111
uuid2=b2222222-2222-4222-8222-222222222222
auth="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732/api/v1/workspaces/$uuid1/renewals/$uuid2/operational-reminders/")"
test "$auth" = 401 || test "$auth" = 403
echo "ANON_DENIED_HTTP=$auth"
echo "DEV_0018_FINAL=OK"
printf 'MIGRATION_0018=OK\nAPI=OK\nWEB=OK\n' >> "$RECEIPT"
