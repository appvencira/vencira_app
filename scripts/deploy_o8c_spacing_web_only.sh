#!/usr/bin/env bash
# O8c UI spacing: deploy Flutter WEB ONLY after green full preflight.
# Never migrate, restart API/DB, change O5, Caddy, OAuth or other stacks.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
# Historical deployment MFA fail-closed preflight (before any mutating action).
bash scripts/mfa_legacy_deploy_guard_readonly.sh web
PHASE=START
LOG="$(mktemp /tmp/vencira-o8c-spacing.XXXXXXXX.log)"
RUN="$(date -u +%Y%m%dT%H%M%SZ)_$$"
WEB_STARTED=0
WEB_OLD_TAG=""
RECEIPT=""
finish(){
  rc=$?
  trap - EXIT
  if [ "$rc" = 0 ]; then echo 'O8C_ESPACIADO_WEB_DESPLEGADO=OK'; else
    echo "FASE_FALLIDA=$PHASE"
    echo "WEB_PUDO_HABERSE_RECREADO=$WEB_STARTED"
    echo 'NO_REPETIR_SIN_REVISAR_EL_CONTENEDOR=1'
    tail -n 40 "$LOG" 2>/dev/null || true
  fi
  if [ -n "$WEB_OLD_TAG" ]; then echo "IMAGEN_WEB_ANTERIOR=$WEB_OLD_TAG"; fi
  if [ -n "$RECEIPT" ]; then echo "RECIBO_LOCAL=$RECEIPT"; fi
  echo "RESULTADO_GLOBAL=$rc"
  echo 'SIN_MIGRACIONES_REINICIOS_API_O_POSTGRES=1'
  echo 'SIN_CAMBIOS_O5_CADDY_OAUTH=1'
  echo "LOG_LOCAL=$LOG"
  echo 'CONSOLA_ABIERTA'
  exit "$rc"
}
trap finish EXIT
step(){
  PHASE="$1"; shift
  echo "=== $PHASE ==="
  "$@" >> "$LOG" 2>&1
  echo "$PHASE=OK"
}
PHASE=FUENTES
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra"
VALIDATED=0f9c17b03fde147d780fdcff5fc2d3e162488a0c
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients compose.yaml compose.preview.yaml deploy || {
  echo 'ERROR=FUENTES_POSTERIORES_A_LAS_PRUEBAS_CAMBIADAS'
  exit 3
}
echo "COMMIT=$(git rev-parse HEAD)"
echo 'FUENTES_UI_O8C_PINNED=OK'
sudo -v
COMPOSE=(sudo docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
PHASE=PRECHECK
for svc in api db web_preview; do
  c="vencira_localcheck-$svc-1"
  test "$(sudo docker inspect "$c" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(sudo docker inspect "$c" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
DB_ID="$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
API_ID="$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
WEB_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
sql(){
  sudo docker exec vencira_localcheck-db-1 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
MIG_COUNT="$(sql 'SELECT COUNT(*) FROM django_migrations;')"
test "$(sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0015_renewal_reminder_drafts
test "$(sql "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NOT NULL;")" = t
echo 'SCHEMA_0015_PRE=OK'
step O5_READ_ONLY sudo bash scripts/o5_verify_active_schedule.sh
grep -Fxq 'AUDITORIA_FINAL_O5=OK' "$LOG"
echo 'O5_SIN_CAMBIOS=OK'
PHASE=TAG_OLD_WEB
OLD_WEB_IMAGE="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Image}}')"
sudo docker image inspect "$OLD_WEB_IMAGE" >/dev/null
WEB_OLD_TAG="vencira-o8c-before-spacing-web:$RUN"
step TAG_WEB_ANTERIOR sudo docker tag "$OLD_WEB_IMAGE" "$WEB_OLD_TAG"
RECEIPT="$(mktemp /tmp/vencira-o8c-spacing.XXXXXXXX.receipt)"
chmod 600 "$RECEIPT"
printf 'SOURCE_SHA=%s\nOLD_WEB_IMAGE=%s\nOLD_WEB_TAG=%s\nDB_CONTAINER_ID=%s\nAPI_CONTAINER_ID=%s\n' "$VALIDATED" "$OLD_WEB_IMAGE" "$WEB_OLD_TAG" "$DB_ID" "$API_ID" > "$RECEIPT"
echo 'ROLLBACK_IMAGEN_WEB_CONSERVADA=OK'
step BUILD_SOLO_FLUTTER_WEB "${COMPOSE[@]}" build web_preview
test "$DB_ID" = "$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$API_ID" = "$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
test "$WEB_ID" = "$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
PHASE=WEB_RECREAR
WEB_STARTED=1
step DESPLEGAR_SOLO_WEB "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate web_preview
PHASE=WEB_HEALTH
status=starting
for i in $(seq 1 40); do
  status="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$status" = healthy ] || [ "$status" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_web_preview=$status"
test "$status" = healthy
PHASE=FINAL_CHECK
test "$DB_ID" = "$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$API_ID" = "$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
test "$(sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0015_renewal_reminder_drafts
test "$(sql 'SELECT COUNT(*) FROM django_migrations;')" = "$MIG_COUNT"
for svc in api db web_preview; do
  state="$(sudo docker inspect "vencira_localcheck-$svc-1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_$svc=$state"
  test "$state" = healthy
done
for path in / /api/health/ /api/ready/ /accounts/login/; do
  code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$path")"
  echo "HTTP_$path=$code"
  test "$code" = 200
done
code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' 'http://127.0.0.1:28732/api/v1/workspaces/11111111-1111-4111-8111-111111111111/renewals/b2222222-2222-4222-8222-222222222222/reminder-config/')"
echo "O8C_CONFIG_ANONIMA_HTTP=$code"
test "$code" = 401 || test "$code" = 403
echo 'API_POSTGRES_0015_INTACTOS=OK'
echo 'WEB_Y_RUTAS=OK'
printf 'WEB_RECREATED=OK\nAPI_DB_UNCHANGED=OK\nSCHEMA_0015_UNCHANGED=OK\n' >> "$RECEIPT"
echo "VERSION_WEB=$(git rev-parse HEAD)"
