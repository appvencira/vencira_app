#!/usr/bin/env bash
# Macrofase B History: guarded API + Flutter Web DEV deploy, NO schema migration.
# REQUIRE: successful isolated gate for VALIDATED commit.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck

PHASE=PRECONDITIONS
LOG="$(mktemp /tmp/vencira-macro-b-history-deploy.XXXXXXXX.log)"
RECEIPT="$(mktemp /tmp/vencira-macro-b-history-deploy.XXXXXXXX.receipt)"
API_RECREATED=0
WEB_RECREATED=0
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)_$$"
OLD_API_TAG=""
OLD_WEB_TAG=""
finish() {
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "API_PUDO_HABERSE_RECREADO=$API_RECREATED"
    echo "WEB_PUDO_HABERSE_RECREADO=$WEB_RECREATED"
    echo "NO_REPETIR_SIN_DIAGNOSTICO=1"
    echo "NO_RESTAURAR_DB_AUTOMATICAMENTE=1"
    # Do not echo log contents: Compose may contain deployment configuration.
  else
    echo "MACRO_B_HISTORY_DEV_DESPLIEGUE=OK"
  fi
  [ -z "$OLD_API_TAG" ] || echo "IMAGEN_API_ANTERIOR=$OLD_API_TAG"
  [ -z "$OLD_WEB_TAG" ] || echo "IMAGEN_WEB_ANTERIOR=$OLD_WEB_TAG"
  echo "RESULTADO_GLOBAL=$rc"
  echo "LOG_LOCAL=$LOG"
  echo "RECIBO_LOCAL=$RECEIPT"
  echo "SIN_MIGRACIONES=1"
  echo "SIN_REINICIO_POSTGRES=1"
  echo "SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
step() { PHASE="$1"; shift; echo "=== $PHASE ==="; "$@" >>"$LOG" 2>&1; echo "$PHASE=OK"; }

test "$(id -u)" -eq 0 || { echo "ERROR=REQUIERE_ROOT"; exit 3; }
test "${MACRO_B_HISTORY_CONFIRM:-}" = "DEPLOY_HISTORY_API_WEB_NO_MIGRATIONS" || {
  echo "ERROR=CONFIRMACION_EXPLICITA_REQUERIDA"; exit 3;
}
test "$(git rev-parse --show-toplevel)" = /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
VALIDATED=0e6f621d834e882d437acbbf8ca15c89075224c7
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients/flutter compose.yaml compose.preview.yaml deploy
echo "FUENTES_IDENTICAS_GATE_VALIDADO=OK"
echo "COMMIT=$(git rev-parse HEAD)"

COMPOSE=(docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" config --format json | python3 -c '
import json,sys
cfg=json.load(sys.stdin)
services=cfg["services"]
assert set(("db","api","web_preview")).issubset(services)
command=services["api"]["command"]
command=" ".join(command) if isinstance(command,list) else command
assert "migrate --check --noinput" in command
assert "migrate --noinput" not in command
' >>"$LOG" 2>&1
echo "MIGRATE_CHECK_ONLY=OK"

DB=vencira_localcheck-db-1
API=vencira_localcheck-api-1
WEB=vencira_localcheck-web_preview-1
PHASE=IDENTITY
for name in "$DB" "$API" "$WEB"; do
  test "$(docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(docker inspect "$name" --format '{{.State.Health.Status}}')" = healthy
done
DB_ID="$(docker inspect "$DB" --format '{{.Id}}')"
API_ID="$(docker inspect "$API" --format '{{.Id}}')"
WEB_ID="$(docker inspect "$WEB" --format '{{.Id}}')"
OLD_API="$(docker inspect "$API" --format '{{.Image}}')"
OLD_WEB="$(docker inspect "$WEB" --format '{{.Image}}')"
sql_read() {
  docker exec "$DB" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
LAST="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(sql_read "$LAST")" = 0018_draft_reasons
COUNT="$(sql_read 'SELECT COUNT(*) FROM django_migrations;')"
echo "DEV_0018_PRE=OK"
step O5_AUDIT bash scripts/o5_verify_active_schedule.sh
grep -Fxq 'AUDITORIA_FINAL_O5=OK' "$LOG"
grep -Fxq 'ULTIMO_SNAPSHOT_MENOS_36H=SI' "$LOG"
echo "O5_READ_ONLY=OK"

# Preserve both exact predecessor image IDs before replacing any live service.
PHASE=PRESERVE_IMAGES
OLD_API_TAG="vencira-macro-b-history-pre-api:$RUN_ID"
OLD_WEB_TAG="vencira-macro-b-history-pre-web:$RUN_ID"
step TAG_PREVIOUS_API docker tag "$OLD_API" "$OLD_API_TAG"
step TAG_PREVIOUS_WEB docker tag "$OLD_WEB" "$OLD_WEB_TAG"
printf 'VALIDATED_SHA=%s\nOLD_API=%s\nOLD_WEB=%s\nORIGINAL_API_ID=%s\nORIGINAL_WEB_ID=%s\nDB_ID=%s\nSCHEMA=%s\nMIGRATION_COUNT=%s\n'   "$VALIDATED" "$OLD_API_TAG" "$OLD_WEB_TAG" "$API_ID" "$WEB_ID" "$DB_ID"   0018_draft_reasons "$COUNT" >"$RECEIPT"
echo "IMAGENES_ANTERIORES_RECUPERABLES=OK"

step BUILD_API "${COMPOSE[@]}" build api
step BUILD_WEB "${COMPOSE[@]}" build web_preview
PHASE=PREDEPLOY_READONLY_CHECKS
test "$(docker inspect "$DB" --format '{{.Id}}')" = "$DB_ID"
test "$(docker inspect "$API" --format '{{.Id}}')" = "$API_ID"
test "$(docker inspect "$WEB" --format '{{.Id}}')" = "$WEB_ID"
test "$(sql_read "$LAST")" = 0018_draft_reasons
test "$(sql_read 'SELECT COUNT(*) FROM django_migrations;')" = "$COUNT"
step API_MIGRATION_CHECK "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate --check --noinput
step API_SYSTEM_CHECK "${COMPOSE[@]}" run --rm --no-deps api python manage.py check
echo "SIN_MIGRACIONES_PENDIENTES=OK"

PHASE=DEPLOY_API
API_RECREATED=1
step DEPLOY_API "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate api
PHASE=API_HEALTH
health=starting
for i in $(seq 1 40); do
  health="$(docker inspect "$API" --format '{{.State.Health.Status}}')"
  if [ "$health" = healthy ] || [ "$health" = unhealthy ]; then break; fi
  sleep 5
done
test "$health" = healthy
echo "HEALTH_API=healthy"

# New endpoint MUST exist after deploying API and deny anonymous access.
PHASE=API_AUTH
uuid=11111111-1111-4111-8111-111111111111
auth="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15   "http://127.0.0.1:28731/api/v1/workspaces/$uuid/operational-inbox/?day=2026-10-25")"
test "$auth" = 401 || test "$auth" = 403
echo "BANDEJA_ANON_DENIED_HTTP=$auth"
history_url="http://127.0.0.1:28731/api/v1/workspaces/$uuid/renewals/$uuid/operational-reminders/$uuid/history/"
history_auth="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$history_url")"
test "$history_auth" = 401 || test "$history_auth" = 403
echo "HISTORIAL_ANON_DENIED_HTTP=$history_auth"

PHASE=DEPLOY_WEB
WEB_RECREATED=1
step DEPLOY_WEB "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate web_preview
PHASE=WEB_HEALTH
health=starting
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
test "$(sql_read "$LAST")" = 0018_draft_reasons
test "$(sql_read 'SELECT COUNT(*) FROM django_migrations;')" = "$COUNT"
for path in / /api/health/ /api/ready/; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732$path")"
  test "$code" = 200
done
auth="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15   "http://127.0.0.1:28732/api/v1/workspaces/$uuid/operational-inbox/?day=2026-10-25")"
test "$auth" = 401 || test "$auth" = 403
echo "BANDEJA_PROXY_ANON_DENIED_HTTP=$auth"
history_auth="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
  "http://127.0.0.1:28732/api/v1/workspaces/$uuid/renewals/$uuid/operational-reminders/$uuid/history/")"
test "$history_auth" = 401 || test "$history_auth" = 403
echo "HISTORIAL_PROXY_ANON_DENIED_HTTP=$history_auth"
echo "POSTGRES_0018_INTACTO=OK"
echo "DEV_0018_FINAL=OK"
printf 'API=healthy\nWEB=healthy\nDB_ID_UNCHANGED=YES\nSCHEMA_0018_UNCHANGED=YES\n' >>"$RECEIPT"
