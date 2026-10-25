#!/usr/bin/env bash
# O8b: actualizar API + Flutter Web de vencira_localcheck DESPUES de preflight verde.
# Sin migraciones; conserva imágenes anteriores; exige O5 saludable.
# Este script es llamado exclusivamente por validate_and_deploy_o8b.sh.
# Tiene gates propios: fuentes SHA fijo, O5 remoto, contenedores, esquema 0014,
# imágenes anteriores disponibles y rutas anónimas bajo autenticación.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=INICIO
LOG="$(mktemp /tmp/vencira-o8b-deploy.XXXXXXXX.log)"
RUN="$(date -u +%Y%m%dT%H%M%SZ)_$$"
OLD_API_TAG=""
OLD_WEB_TAG=""
API_CHANGED=0
WEB_CHANGED=0
DB_ID=""
RECEIPT=""
finish(){
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "API_RECREADA=$API_CHANGED"
    echo "WEB_RECREADA=$WEB_CHANGED"
    echo "NO_RESTAURAR_DB_AUTOMATICAMENTE=1"
    echo "REVISAR_RECIBO_ANTES_DE_REINTENTAR=1"
    echo "=== DIAGNOSTICO_LIMITADO ==="
    tail -n 55 "$LOG" 2>/dev/null || true
  else
    echo "DESPLIEGUE_O8B_LOCALCHECK=OK"
  fi
  if [ -n "$OLD_API_TAG" ]; then echo "IMAGEN_API_ANTERIOR=$OLD_API_TAG"; fi
  if [ -n "$OLD_WEB_TAG" ]; then echo "IMAGEN_WEB_ANTERIOR=$OLD_WEB_TAG"; fi
  if [ -n "$RECEIPT" ]; then echo "RECIBO_LOCAL=$RECEIPT"; fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "SIN_MIGRACIONES_NI_REINICIOS_POSTGRES=1"
  echo "SIN_CAMBIOS_CADDY_RESTIC_TIMERS=1"
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
PHASE=GIT_PRECHECK
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra" || { echo "ERROR=UNTRACKED_AJENOS"; exit 2; }
VALIDATED=1986ecfbf35f53c6f8f455cc0799d740ed99aeb7
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients compose.yaml compose.preview.yaml deploy || {
  echo "ERROR=FUENTES_CAMBIARON_DESDE_GATE_VALIDADO"
  exit 2
}
echo "FUENTES_IGUALES_GATE_VALIDADO=OK"
echo "COMMIT=$(git rev-parse HEAD)"
sudo -v
COMPOSE=(sudo docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
PHASE=COMPOSE_IDENTITY
for svc in api db web_preview; do
  name="vencira_localcheck-$svc-1"
  test "$(sudo docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(sudo docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
DB_ID="$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
cmd="$(sudo docker inspect vencira_localcheck-api-1 --format '{{json .Config.Cmd}}')"
case "$cmd" in *"migrate --check --noinput"*) ;; *) echo "ERROR=API_NO_CHECK_ONLY"; exit 3;; esac
echo "COMPOSE_IDENTIDAD_Y_MIGRATE_CHECK_ONLY=OK"
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
PHASE=O5_BACKUP
step O5_BACKUP_READ_ONLY sudo bash scripts/o5_verify_active_schedule.sh
grep -Fxq 'TIMERS_ACTIVOS_Y_HABILITADOS=OK' "$LOG"
grep -Fxq 'COPIA_TRAS_REAUTORIZACION=SI' "$LOG"
grep -Fxq 'ULTIMO_SNAPSHOT_MENOS_36H=SI' "$LOG"
grep -Fxq 'AUDITORIA_FINAL_O5=OK' "$LOG"
echo "BACKUP_O5_RECIENTE_Y_CIFRADO=OK"
PHASE=DATABASE_BASELINE
sql_read(){
  sudo docker exec vencira_localcheck-db-1 sh -c     'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
migration="$(sql_read "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$migration" = 0014_renewal_outcomes || { echo "ERROR=ESQUEMA_NO_0014"; exit 4; }
count_before="$(sql_read "SELECT COUNT(*) FROM django_migrations;")"
echo "POSTGRES_0014_INTACTO_PRE=OK"
PHASE=GUARDAR_IMAGENES
OLD_API_ID="$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Image}}')"
OLD_WEB_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Image}}')"
sudo docker image inspect "$OLD_API_ID" >/dev/null || {
  echo "ERROR=IMAGEN_API_PREVIA_NO_DISPONIBLE"
  exit 5
}
sudo docker image inspect "$OLD_WEB_ID" >/dev/null || {
  echo "ERROR=IMAGEN_WEB_PREVIA_NO_DISPONIBLE"
  exit 5
}
OLD_API_TAG="vencira-o8b-pre-api:$RUN"
OLD_WEB_TAG="vencira-o8b-pre-web:$RUN"
step TAG_API_PREVIA sudo docker tag "$OLD_API_ID" "$OLD_API_TAG"
step TAG_WEB_PREVIA sudo docker tag "$OLD_WEB_ID" "$OLD_WEB_TAG"
RECEIPT="$(mktemp "/tmp/vencira-o8b-$RUN.XXXXXXXX.receipt")"
chmod 0600 "$RECEIPT"
{
  echo "TEST_SOURCE_SHA=$VALIDATED"
  echo "DEPLOY_HEAD=$(git rev-parse HEAD)"
  echo "OLD_API_IMAGE=$OLD_API_ID"
  echo "OLD_WEB_IMAGE=$OLD_WEB_ID"
  echo "OLD_API_TAG=$OLD_API_TAG"
  echo "OLD_WEB_TAG=$OLD_WEB_TAG"
  echo "DB_CONTAINER_ID=$DB_ID"
  echo "POSTGRES_MIGRATION_0014=EXPECTED"
} >> "$RECEIPT"
echo "IMAGENES_ANTERIORES_RECUPERABLES=OK"
step BUILD_API_WEB "${COMPOSE[@]}" build api web_preview
step MIGRATIONS_CHECK_ONLY_NEW_IMAGE "${COMPOSE[@]}" run --rm --no-deps   api python manage.py migrate --check --noinput
echo "ESQUEMA_SIN_MIGRACIONES_PENDIENTES=OK"
PHASE=DEPLOY_API
echo "=== DEPLOY_API ==="
API_CHANGED=1
"${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate api >>"$LOG" 2>&1
PHASE=API_HEALTH
healthy=starting
for i in $(seq 1 35); do
  healthy="$(sudo docker inspect vencira_localcheck-api-1     --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$healthy" = healthy ] || [ "$healthy" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_api=$healthy"
test "$healthy" = healthy
echo "DEPLOY_API=OK"
PHASE=DEPLOY_WEB
echo "=== DEPLOY_WEB ==="
WEB_CHANGED=1
"${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate web_preview >>"$LOG" 2>&1
PHASE=WEB_HEALTH
healthy=starting
for i in $(seq 1 35); do
  healthy="$(sudo docker inspect vencira_localcheck-web_preview-1     --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$healthy" = healthy ] || [ "$healthy" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_web_preview=$healthy"
test "$healthy" = healthy
echo "DEPLOY_WEB=OK"
PHASE=DB_POSTCHECK
test "$DB_ID" = "$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
count_after="$(sql_read "SELECT COUNT(*) FROM django_migrations;")"
test "$count_before" = "$count_after"
test "$(sql_read "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0014_renewal_outcomes
echo "POSTGRES_0014_SIN_CAMBIOS=OK"
PHASE=HTTP
for endpoint in / /api/health/ /api/ready/ /accounts/login/; do
  code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$endpoint")"
  echo "PROXY_ENDPOINT=$endpoint STATUS=$code"
  test "$code" = 200
done
endpoint="/api/v1/workspaces/11111111-1111-4111-8111-111111111111/results/?period=month&year=2027&month=3"
anon="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$endpoint")"
echo "RESULTS_SIN_SESION_HTTP=$anon"
test "$anon" = 401 || test "$anon" = 403
endpoint="/api/v1/workspaces/11111111-1111-4111-8111-111111111111/renewals/b2222222-2222-4222-8222-222222222222/reminder-preview/?days=60,45,35"
anon="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$endpoint")"
echo "O8B_PREVIEW_SIN_SESION_HTTP=$anon"
test "$anon" = 401 || test "$anon" = 403
endpoint="/api/v1/workspaces/11111111-1111-4111-8111-111111111111/renewals/b2222222-2222-4222-8222-222222222222/outcomes/"
anon="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$endpoint")"
echo "OUTCOMES_SIN_SESION_HTTP=$anon"
test "$anon" = 401 || test "$anon" = 403
for svc in api db web_preview; do
  h="$(sudo docker inspect "vencira_localcheck-$svc-1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_$svc=$h"
  test "$h" = healthy
done
echo "API_Y_WEB_SANO=OK"
ext="$(curl -L -sS --max-time 12 -o /dev/null -w '%{http_code}' https://dev.vencira.es/ 2>/dev/null || true)"
echo "DEV_VENCIRA_HTTPS_HTTP=${ext:-no_disponible}"
PHASE=RECEIPT
{
 echo "HEALTH_API=healthy"
 echo "HEALTH_WEB=healthy"
 echo "RESULTS_AUTH=OK"
 echo "SCHEMA_0014=UNCHANGED"
 echo "DEPLOY_RESULT=OK"
} >> "$RECEIPT"
echo "O7_RESULTADOS_WEB_CONSERVADOS=OK"
echo "O8B_PREVIEW_UI_Y_API=OK"
echo "VERSION_WEB=$(git rev-parse HEAD)"
