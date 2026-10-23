#!/usr/bin/env bash
# VENCIRA O2: despliegue controlado SOLO del stack vencira_localcheck.
# Requiere preflight verde y backup pre0013 restaurado en PG temporal.
# Nunca restaura BD de forma automatica. Uso: bash scripts/deploy_operativa_o2.sh
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-o2-deploy.XXXXXXXX.log)"
PHASE=INICIO
MIGRATION_TRIGGERED=0
BACKUP_VERIFIED=0
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)_$$"
RECEIPT=""

finish() {
  local rc=$?
  trap - EXIT
  if [ "$rc" -eq 0 ]; then
    echo "RESULTADO_GLOBAL=0"
    echo "DESPLIEGUE_OPERATIVA_O2_LOCALCHECK=OK"
  else
    echo "RESULTADO_GLOBAL=$rc"
    echo "FASE_FALLIDA=$PHASE"
    echo "MIGRACION_PUDO_HABERSE_APLICADO=$MIGRATION_TRIGGERED"
    echo "NO_RESTAURAR_BACKUP_AUTOMATICAMENTE=1"
    echo "=== ULTIMAS 70 LINEAS DE DIAGNOSTICO ==="
    tail -n 70 "$LOG" 2>/dev/null || true
  fi
  echo "BACKUP_PRE0013_VALIDADO=$BACKUP_VERIFIED"
  if [ -n "$RECEIPT" ]; then echo "RECIBO_LOCAL=$RECEIPT"; fi
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

step() {
  PHASE="$1"; shift
  echo "=== $PHASE ==="
  if "$@" >>"$LOG" 2>&1; then
    echo "OK: $PHASE"
  else
    return $?
  fi
}

echo "=== IDENTIDAD DEL CODIGO Y REPOSITORIO ==="
PHASE=FUENTES
EXPECTED_BRANCH=integration/local-e2e-prep
VALIDATED_SHA=f7a62e3debe1e7534572ed6ec5e0e81ce1913539
test "$(git branch --show-current)" = "$EXPECTED_BRANCH"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: hay cambios versionados locales, cancelado"
  exit 2
fi
EXTRA="$(git ls-files --others --exclude-standard |
  grep -vx 'clients/flutter/pubspec.lock' || true)"
if [ -n "$EXTRA" ]; then
  echo "ERROR: archivos no versionados ajenos al bloqueo permitido"
  printf '%s\n' "$EXTRA"
  exit 2
fi
git cat-file -e "$VALIDATED_SHA^{commit}"
if ! git diff --quiet "$VALIDATED_SHA" HEAD -- \
    backend clients compose.yaml compose.preview.yaml deploy; then
  echo "ERROR: fuentes de API/Flutter/Compose diferentes del preflight validado"
  exit 2
fi
echo "PREFLIGHT_VALIDADO=$VALIDATED_SHA"
echo "COMMIT_DESPLIEGUE=$(git rev-parse HEAD)"
echo "FUENTES=OK"

PHASE=IDENTIDAD_DOCKER
sudo -v
for service in api db web_preview; do
  container="vencira_localcheck-${service}-1"
  label="$(sudo docker inspect "$container" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  if [ "$label" != vencira_localcheck ]; then
    echo "ERROR: contenedor fuera de vencira_localcheck: $service"
    exit 3
  fi
  health="$(sudo docker inspect "$container" \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$health" != healthy ]; then
    echo "ERROR: servicio $service no saludable antes del despliegue ($health)"
    exit 3
  fi
done
echo "COMPOSE_IDENTITY=OK"
COMPOSE=(sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet

# Backup pre0013 con restauracion integral ya demostrada. Los tres ficheros
# deben concordar. No seguir si la huella ha variado o falta el recibo.
PHASE=VERIFICAR_BACKUP
BACKUP_DIR=/home/vencira/vencira-db-backups
BACKUP="$BACKUP_DIR/pre0013_20261023T084917Z_EQESO7FF.dump"
BACKUP_SHA256=6f3df512b225a361182248a25a718715106fb4d566af5f11f1e479cace7b8f1c
test ! -L "$BACKUP_DIR" && test -d "$BACKUP_DIR"
test -O "$BACKUP_DIR" && test "$(stat -c %a "$BACKUP_DIR")" = 700
for file in "$BACKUP" "$BACKUP.sha256" "$BACKUP.verified"; do
  test -f "$file" && test ! -L "$file" || {
    echo "ERROR: falta respaldo verificado o fichero no seguro"
    exit 4
  }
  test -O "$file" && test "$(stat -c %a "$file")" = 600 || {
    echo "ERROR: propietario/permisos no validos en respaldo"
    exit 4
  }
done
test -s "$BACKUP"
# No aceptar una copia antigua para desplegar otro dia. Crear y ensayar
# otra copia antes de continuar si ha transcurrido mas de 24 horas.
backup_age=$(( $(date +%s) - $(stat -c %Y "$BACKUP") ))
if [ "$backup_age" -lt 0 ] || [ "$backup_age" -gt 86400 ]; then
  echo "ERROR: backup de mas de 24h o fecha inconsistente; repetir respaldo y restauracion antes de migrar"
  exit 4
fi
echo "ANTIGUEDAD_BACKUP_HORAS=$(( backup_age / 3600 ))"
step BACKUP_CHECKSUM sha256sum --status -c "$BACKUP.sha256"
actual_sha="$(sha256sum "$BACKUP" | awk '{print $1}')"
test "$actual_sha" = "$BACKUP_SHA256" || {
  echo "ERROR: huella no coincide con la copia restaurada"
  exit 4
}
grep -Fxq "VALIDATED_SHA=$VALIDATED_SHA" "$BACKUP.verified"
grep -Fxq "ARCHIVE_SHA256=$BACKUP_SHA256" "$BACKUP.verified"
grep -Fxq 'RESTORE_TEST=OK' "$BACKUP.verified"
BACKUP_VERIFIED=1
echo "BACKUP_RESTAURACION_VERIFICADOS=1"
echo "COPIA_PRE0013_INTACTA=1"

# Confirmar la realidad de Postgres ANTES de construir o recrear servicios.
DB=vencira_localcheck-db-1
sql_read() {
  sudo docker exec "$DB" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq -c "$1"' \
    sh "$1"
}
PHASE=PREMIGRACION
migration="$(sql_read "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
if [ "$migration" != 0012_renewal_notes ]; then
  echo "ERROR: esquema distinto del esperado (0012); cancelado"
  exit 5
fi
table_exists="$(sql_read "SELECT to_regclass('public.reminders_renewalfollowup') IS NOT NULL;")"
test "$table_exists" = f || {
  echo "ERROR: tabla 0013 ya existe; detener y revisar manualmente"
  exit 5
}
echo "ESQUEMA_PREVIO_0012=OK"
echo "MIGRACION_0013_PENDIENTE=1"

# Guardar antiguas imagenes ANTES del build. Etiquetas unicas: no sobrescribir
# referencias recuperables a la version O1. Esta operacion NO reinicia Docker.
PHASE=GUARDAR_IMAGENES_PREVIAS
OLD_API_ID="$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Image}}')"
OLD_WEB_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Image}}')"
OLD_API_TAG="vencira-prev-o2-api:$RUN_ID"
OLD_WEB_TAG="vencira-prev-o2-web:$RUN_ID"
sudo docker tag "$OLD_API_ID" "$OLD_API_TAG" >>"$LOG" 2>&1
sudo docker tag "$OLD_WEB_ID" "$OLD_WEB_TAG" >>"$LOG" 2>&1
RECEIPT="$BACKUP_DIR/deploy_o2_$RUN_ID.receipt"
{
  printf 'PREFLIGHT_SHA=%s\n' "$VALIDATED_SHA"
  printf 'BACKUP_SHA256=%s\n' "$BACKUP_SHA256"
  printf 'PREVIOUS_API_IMAGE=%s\nPREVIOUS_WEB_IMAGE=%s\n' "$OLD_API_ID" "$OLD_WEB_ID"
  printf 'PREVIOUS_API_TAG=%s\nPREVIOUS_WEB_TAG=%s\n' "$OLD_API_TAG" "$OLD_WEB_TAG"
  printf 'MIGRATION_TARGET=reminders.0013_renewal_manual_followups\n'
} > "$RECEIPT"
chmod 600 "$RECEIPT"
echo "IMAGENES_O1_CONSERVADAS=1"
echo "ETIQUETA_API_ANTERIOR=$OLD_API_TAG"
echo "ETIQUETA_WEB_ANTERIOR=$OLD_WEB_TAG"

# Construir AMBAS imagenes primero: fallo de build = cero migraciones/reinicios.
step CONSTRUIR_API_Y_WEB "${COMPOSE[@]}" build api web_preview

# --plan NO escribe en DB: el command explicito sustituye el migrate del
# entrypoint de Compose; --no-deps evita cambios de DB o stack vecino.
step PLAN_MIGRACION_0013 "${COMPOSE[@]}" run --rm --no-deps \
  api python manage.py migrate --plan
if ! grep -Fq 'reminders.0013_renewal_manual_followups' "$LOG"; then
  echo "ERROR: el plan no incluye la migracion esperada"
  exit 6
fi
echo "PLAN_MIGRACION_INCLUYE_0013=1"

# El up de la API ejecuta migrate --noinput AUTOMATICAMENTE. El backup
# ya ha sido restaurado y verificado; no automatizar rollback con pg_restore.
PHASE=DESPLEGAR_API_Y_MIGRAR
MIGRATION_TRIGGERED=1
echo "=== DESPLEGAR_API_Y_MIGRAR_0013 ==="
if "${COMPOSE[@]}" up -d --no-deps --force-recreate api >>"$LOG" 2>&1; then
  echo "OK: DESPLEGAR_API_Y_MIGRAR_0013"
else
  exit 7
fi

PHASE=ESPERAR_API
echo "=== HEALTH_API ==="
api_health=starting
for attempt in $(seq 1 36); do
  api_health="$(sudo docker inspect vencira_localcheck-api-1 \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$api_health" = healthy ] || [ "$api_health" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_api=$api_health"
test "$api_health" = healthy || exit 8

PHASE=VERIFICAR_MIGRACION
applied="$(sql_read "SELECT COUNT(*) FROM django_migrations WHERE app='reminders' AND name='0013_renewal_manual_followups';")"
test "$applied" = 1 || {
  echo "ERROR: migracion 0013 no consta aplicada; detener"
  exit 8
}
table_exists="$(sql_read "SELECT to_regclass('public.reminders_renewalfollowup') IS NOT NULL;")"
unique_exists="$(sql_read "SELECT to_regclass('public.uniq_planned_followup') IS NOT NULL;")"
test "$table_exists" = t && test "$unique_exists" = t || {
  echo "ERROR: tabla/indice O2 no verificados"
  exit 8
}
echo "MIGRACION_0013_APLICADA=1"
echo "TABLA_E_INDICE_O2=OK"

# La web actual resuelve el nombre DNS del API al arrancar; despues de
# recrear api, recrear web evita referencias antiguas.
step DESPLEGAR_WEB "${COMPOSE[@]}" up -d --no-deps --force-recreate web_preview

PHASE=ESPERAR_WEB
echo "=== HEALTH_WEB ==="
web_health=starting
for attempt in $(seq 1 36); do
  web_health="$(sudo docker inspect vencira_localcheck-web_preview-1 \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$web_health" = healthy ] || [ "$web_health" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_web_preview=$web_health"
test "$web_health" = healthy || exit 9

PHASE=COMPROBAR_PROXY
echo "=== HTTP_INTERNO ==="
for endpoint in / /api/health/ /api/ready/ /accounts/login/; do
  code="$(curl -fsS --max-time 15 -o /dev/null -w '%{http_code}' \
    "http://127.0.0.1:28732$endpoint")"
  echo "RUTA=$endpoint HTTP=$code"
  test "$code" = 200 || exit 10
done
for service in api db web_preview; do
  h="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_${service}=$h"
  test "$h" = healthy || exit 10
done

# Endpoint O2, sin credenciales: 401/403 (no 404) verifica que la ruta existe
# y se sigue exigiendo autenticacion. No crear ni consultar datos privados.
PHASE=VERIFICAR_RUTA_O2_ANONIMA
endpoint="/api/v1/workspaces/11111111-1111-4111-8111-111111111111/renewals/b2222222-2222-4222-8222-222222222222/follow-up/"
code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' \
  "http://127.0.0.1:28732$endpoint")"
echo "FOLLOW_UP_SIN_SESION_HTTP=$code"
test "$code" = 401 || test "$code" = 403 || exit 11
echo "FOLLOW_UP_REQUIERE_AUTENTICACION=1"

# El tunel publico puede devolver 401 por su proteccion adicional:
# es informativo y no condiciona salud interna.
PHASE=HTTPS_PUBLICO
echo "=== HTTPS_PUBLICO (sin credenciales, informativo) ==="
external="$(curl -L -sS --max-time 12 -o /dev/null -w '%{http_code}' \
  https://dev.vencira.es/ 2>/dev/null || true)"
echo "DEV_VENCIRA_HTTPS_HTTP=${external:-sin_respuesta}"

PHASE=REGISTRAR_DESPLIEGUE
printf 'DEPLOY_SHA=%s\nMIGRATION_0013=APPLIED\nAPI_HEALTH=healthy\nWEB_HEALTH=healthy\nRESULTADO_GLOBAL=0\n' \
  "$(git rev-parse HEAD)" >> "$RECEIPT"
echo "COMMIT_VALIDADO=$(git rev-parse HEAD)"
echo "SOLO_STACK_VENCIRA_LOCALCHECK=1"
echo "SIN_RESTAURACION_AUTOMATICA=1"
