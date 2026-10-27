#!/usr/bin/env bash
# O8c — DEV-only one-time 0015 migration and API/Web deployment.
# Rollout intencional, de uso único. Requiere ensayo restaurado de O5,
# copia cifrada fresca, imagenes anteriores y migracion 0015 explicita.
# Requires O5 restore proof. NEVER auto-rollback persistent database.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
# Historical deployment MFA fail-closed preflight (before any mutating action).
bash scripts/mfa_legacy_deploy_guard_readonly.sh schema
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
PHASE=IDENTIDAD
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
PHASE=PRUEBA_RESTAURACION
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

PHASE=COMPOSE
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
ACTUAL_CMD="$(docker inspect vencira_localcheck-api-1 --format '{{json .Config.Cmd}}')"
case "$ACTUAL_CMD" in *"migrate --check --noinput"*) ;; *) echo 'ERROR=API_ACTUAL_NO_FAIL_CLOSED'; exit 3;; esac
DB_ID="$(docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
echo "CONTENEDORES_PRE_HEALTHY=OK"

sql_read(){
  docker exec vencira_localcheck-db-1 sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
LAST_SQL="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(sql_read "$LAST_SQL")" = 0014_renewal_outcomes
test "$(sql_read "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NULL;")" = t
PHASE=BASE_DATOS_PRE0015
MIG_COUNT="$(sql_read 'SELECT COUNT(*) FROM django_migrations;')"
PRE_POLICIES="$(sql_read 'SELECT COUNT(*) FROM reminders_reminderpolicy;')"
PRE_CANDIDATES="$(sql_read 'SELECT COUNT(*) FROM reminders_remindercandidate;')"
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

# Fresh encrypted O5 backup before live migration.
step BACKUP_O5_FRESCO_CIFRADO bash scripts/o5_backup_to_drive.sh
grep -Fxq 'GOOGLE_DRIVE_BACKUP_CIFRADO=OK' "$LOG"
grep -Fxq 'RESTIC_INTEGRIDAD_METADATA=OK' "$LOG"
echo "BACKUP_O5_PRE0015_FRESCO=OK"
printf 'FRESH_O5_BACKUP=OK\n' >> "$RECEIPT"

PHASE=MIGRACION_0015_PERSISTENTE
MIGRATION_STARTED=1
step APLICAR_0015_EXPLICITAMENTE "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate reminders 0015_renewal_reminder_drafts --noinput
PHASE=VERIFICAR_0015
test "$(sql_read "$LAST_SQL")" = 0015_renewal_reminder_drafts
test "$(sql_read 'SELECT COUNT(*) FROM django_migrations;')" = "$((MIG_COUNT+1))"
test "$(sql_read "SELECT to_regclass('public.reminders_renewalreminderdraft') IS NOT NULL;")" = t
test "$(sql_read 'SELECT COUNT(*) FROM reminders_renewalreminderdraft;')" = 0
constraint_count="$(sql_read "SELECT COUNT(*) FROM pg_constraint WHERE conrelid='public.reminders_renewalreminderdraft'::regclass AND conname IN ('renewal_reminder_draft_only','renewal_reminder_revision_positive');")"
test "$constraint_count" = 2
echo "MIGRACION_0015_VERIFICADA=OK"
echo "TABLA_BORRADORES_VACIA_Y_RESTRINGIDA=OK"
step CHECK_MIGRACIONES_POST0015 "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate --check --noinput
test "$DB_ID" = "$(docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
MIGRATION_CONFIRMED=1
printf 'LIVE_SCHEMA_0015_VERIFIED=OK\n' >> "$RECEIPT"
# Schema is now 0015. No automatic rollback of applied migration.
PHASE=DESPLEGAR_API
API_RECREATED=1
step DESPLEGAR_API "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate api
PHASE=ESPERAR_API
api_health=starting
for attempt in $(seq 1 40); do
  api_health="$(docker inspect vencira_localcheck-api-1 --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$api_health" = healthy ] || [ "$api_health" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_api=$api_health"
test "$api_health" = healthy
echo "API_O8C_DESPLEGADA=OK"

PHASE=DESPLEGAR_WEB
WEB_RECREATED=1
step DESPLEGAR_WEB "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate web_preview
PHASE=ESPERAR_WEB
web_health=starting
for attempt in $(seq 1 40); do
  web_health="$(docker inspect vencira_localcheck-web_preview-1 --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$web_health" = healthy ] || [ "$web_health" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_web_preview=$web_health"
test "$web_health" = healthy
echo "FLUTTER_WEB_O8C_DESPLEGADA=OK"

PHASE=DB_POSTCHECK
test "$DB_ID" = "$(docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$(sql_read "$LAST_SQL")" = 0015_renewal_reminder_drafts
test "$(sql_read 'SELECT COUNT(*) FROM django_migrations;')" = "$((MIG_COUNT+1))"
test "$(sql_read 'SELECT COUNT(*) FROM reminders_renewalreminderdraft;')" = 0
test "$(sql_read 'SELECT COUNT(*) FROM reminders_reminderpolicy;')" = "$PRE_POLICIES"
test "$(sql_read 'SELECT COUNT(*) FROM reminders_remindercandidate;')" = "$PRE_CANDIDATES"
echo "POSTGRES_0015_SIN_REINICIO=OK"
PHASE=HTTP_COMPROBACIONES
for endpoint in / /api/health/ /api/ready/ /accounts/login/; do
  code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$endpoint")"
  echo "PROXY_ENDPOINT=$endpoint STATUS=$code"
  test "$code" = 200
done
echo "HTTP_PUBLICO_LOCAL=OK"
WS=11111111-1111-4111-8111-111111111111
RN=b2222222-2222-4222-8222-222222222222
for spec in \
 'RESULTADOS:/api/v1/workspaces/'"$WS"'/results/?period=month&year=2027&month=3' \
 'SIMULADOR:/api/v1/workspaces/'"$WS"'/renewals/'"$RN"'/reminder-preview/?days=60,45,35' \
 'BORRADOR:/api/v1/workspaces/'"$WS"'/renewals/'"$RN"'/reminder-config/' \
 'DESENLACES:/api/v1/workspaces/'"$WS"'/renewals/'"$RN"'/outcomes/'; do
  label="${spec%%:*}"
  endpoint="${spec#*:}"
  code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:28732$endpoint")"
  echo "RUTA_${label}_ANONIMA_HTTP=$code"
  test "$code" = 401 || test "$code" = 403
done
echo "ENDPOINTS_PRIVADOS_PROTEGIDOS=OK"
for svc in api db web_preview; do
  health="$(docker inspect "vencira_localcheck-$svc-1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_$svc=$health"
  test "$health" = healthy
done
echo "API_DB_WEB_HEALTHY=OK"
ext="$(curl -L -sS --max-time 12 -o /dev/null -w '%{http_code}' https://dev.vencira.es/ 2>/dev/null || true)"
echo "DEV_VENCIRA_HTTPS_HTTP=${ext:-no_disponible}"
PHASE=RECIBO_FINAL
printf 'API_DEPLOY=OK\nWEB_DEPLOY=OK\nSCHEMA_0015=VERIFIED\nAUTH_CHECKS=OK\nDRAFT_ONLY=YES\n' >> "$RECEIPT"
echo "O8C_GUARDADO_SOLO_BORRADOR=OK"
echo "VERSION_WEB=$(git rev-parse HEAD)"
