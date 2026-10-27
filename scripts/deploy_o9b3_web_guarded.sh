#!/usr/bin/env bash
# O9b-3: web-only DEV deploy, no schema migrations, no API/DB restarts.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
# Shared MFA guard: fail closed before modifying services or schema.
bash scripts/mfa_legacy_deploy_guard_readonly.sh web
PHASE=START
LOG="$(mktemp /tmp/vencira-o9b3-web.XXXXXXXX.log)"
OLD_TAG=""
RECREATED=0
finish() {
 local rc=$?
 trap - EXIT
 if [ "$rc" -ne 0 ]; then
  echo "FASE_FALLIDA=$PHASE"
  echo "WEB_PUDO_HABERSE_RECREADO=$RECREATED"
  echo "NO_REPETIR_SIN_DIAGNOSTICO=1"
  echo "LOG_LOCAL=$LOG"
 else
  echo "O9B3_WEB_DEV_DESPLIEGUE=OK"
 fi
 [ -z "$OLD_TAG" ] || echo "IMAGEN_WEB_ANTERIOR=$OLD_TAG"
 echo "RESULTADO_GLOBAL=$rc"
 echo "SIN_MIGRACIONES=1"
 echo "SIN_REINICIO_API_DB=1"
 echo "SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1"
 echo "CONSOLA_ABIERTA"
 exit "$rc"
}
trap finish EXIT
step() { PHASE="$1"; shift; echo "=== $PHASE ==="; "$@" >>"$LOG" 2>&1; echo "$PHASE=OK"; }
PHASE=PRECONDITIONS
test "$(id -u)" -eq 0
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
git cat-file -e '96bde67999eb0cfaca71d1204d73e216d9b7fe4a^{commit}'
git cat-file -e 'd7b3bfed5749c8cfe23deed1c6d65f907236d072^{commit}'
git diff --quiet 96bde67999eb0cfaca71d1204d73e216d9b7fe4a HEAD -- clients/flutter
git diff --quiet d7b3bfed5749c8cfe23deed1c6d65f907236d072 HEAD -- backend compose.yaml compose.preview.yaml deploy
echo "FUENTES_WEB_PREFLIGHT_IDENTICAS=OK"
echo "COMMIT=$(git rev-parse HEAD)"
COMPOSE=(docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" config --format json | python3 -c 'import json,sys; x=json.load(sys.stdin)["services"]["api"]["command"]; x=" ".join(x) if isinstance(x,list) else x; assert "migrate --check --noinput" in x; assert "migrate --noinput" not in x' >> "$LOG" 2>&1
echo "MIGRATE_CHECK_ONLY=OK"
API=vencira_localcheck-api-1
DB=vencira_localcheck-db-1
WEB=vencira_localcheck-web_preview-1
for name in "$API" "$DB" "$WEB"; do
 test "$(docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
 test "$(docker inspect "$name" --format '{{.State.Health.Status}}')" = healthy
done
API_ID="$(docker inspect "$API" --format '{{.Id}}')"
DB_ID="$(docker inspect "$DB" --format '{{.Id}}')"
WEB_IMAGE="$(docker inspect "$WEB" --format '{{.Image}}')"
sql_read() { docker exec "$DB" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"; }
LAST="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(sql_read "$LAST")" = 0016_renewal_control_responses
COUNT="$(sql_read 'SELECT COUNT(*) FROM django_migrations;')"
echo "POSTGRES_0016_PRE=OK"
curl -fsS --max-time 15 -o /dev/null http://127.0.0.1:28732/
echo "WEB_PRE_HEALTH=OK"
OLD_TAG="vencira-o9b3-pre-web:$(date -u +%Y%m%dT%H%M%SZ)_$$"
step TAG_PREVIOUS_WEB docker tag "$WEB_IMAGE" "$OLD_TAG"
step BUILD_WEB "${COMPOSE[@]}" build web_preview
test "$(docker inspect "$API" --format '{{.Id}}')" = "$API_ID"
test "$(docker inspect "$DB" --format '{{.Id}}')" = "$DB_ID"
test "$(sql_read "$LAST")" = 0016_renewal_control_responses
echo "API_DB_IDENTIDAD_PRE_DEPLOY=OK"
PHASE=WEB_DEPLOY
RECREATED=1
step WEB_DEPLOY "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate web_preview
PHASE=WEB_HEALTH
health=starting
for n in $(seq 1 36); do
 health="$(docker inspect "$WEB" --format '{{.State.Health.Status}}')"
 if [ "$health" = healthy ] || [ "$health" = unhealthy ]; then break; fi
 sleep 5
done
test "$health" = healthy
echo "HEALTH_web_preview=healthy"
PHASE=FINAL
test "$(docker inspect "$API" --format '{{.Id}}')" = "$API_ID"
test "$(docker inspect "$DB" --format '{{.Id}}')" = "$DB_ID"
test "$(docker inspect "$API" --format '{{.State.Health.Status}}')" = healthy
test "$(docker inspect "$DB" --format '{{.State.Health.Status}}')" = healthy
test "$(sql_read "$LAST")" = 0016_renewal_control_responses
test "$(sql_read 'SELECT COUNT(*) FROM django_migrations;')" = "$COUNT"
for url in / /api/health/ /api/ready/; do
 test "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732$url")" = 200
done
UUID1=11111111-1111-4111-8111-111111111111
UUID2=b2222222-2222-4222-8222-222222222222
AUTH="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732/api/v1/workspaces/$UUID1/renewals/$UUID2/control-responses/")"
test "$AUTH" = 401 || test "$AUTH" = 403
echo "CONTROL_RESPONSES_ANON_HTTP=$AUTH"
echo "POSTGRES_0016_INTACTO=OK"
echo "API_DB_IDENTIDAD_POST_DEPLOY=OK"
