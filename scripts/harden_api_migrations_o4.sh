#!/usr/bin/env bash
# O4 hardening: backup del esquema O3 actual y restauracion aislada antes de proteger arranque API.
# No aplica migraciones: tras copia/restauracion valida, recrea API y proxy web sin modificar DB.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-o4-hardening.XXXXXXXX.log)"
PHASE="INICIO"
RESTORE_NAME=""
RESTORE_STARTED=0
BACKUP=""
BACKUP_OK=0
API_RECREATED=0
WEB_RECREATED=0
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)_$$"
RECEIPT=""

finish() {
  local rc=$?
  trap - EXIT
  if [ "$RESTORE_STARTED" -eq 1 ]; then
    sudo docker stop "$RESTORE_NAME" >>"$LOG" 2>&1 || {
      echo "ALERTA: no se pudo detener el PostgreSQL temporal $RESTORE_NAME"
      rc=1
    }
  fi
  if [ "$rc" -eq 0 ] && [ "$BACKUP_OK" -eq 1 ]; then
    echo "RESULTADO_GLOBAL=0"
    echo "BACKUP_RESTAURACION_VERIFICADOS=1"
    echo "O4_API_SIN_MIGRACION_AUTOMATICA=OK"
    echo "BACKUP=$BACKUP"
    echo "BACKUP_SHA256=$(sha256sum "$BACKUP" | awk '{print $1}')"
  else
    echo "RESULTADO_GLOBAL=${rc:-1}"
    echo "FASE_FALLIDA=$PHASE"
    echo "API_RECREADA=$API_RECREATED"
    echo "WEB_RECREADA=$WEB_RECREATED"
    echo "NO_RESTAURAR_BACKUP_AUTOMATICAMENTE=1"
    echo "=== ULTIMAS 60 LINEAS DE DIAGNOSTICO ==="
    tail -n 60 "$LOG" || true
    echo "BACKUP_VERIFICADO=$BACKUP_OK"
  fi
  echo "MIGRACIONES_APLICADAS_POR_O4=0"
  echo "POSTGRES_SIN_REINICIAR=1"
  if [ -n "$RECEIPT" ]; then echo "RECIBO_LOCAL=$RECEIPT"; fi
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

step() {
  PHASE="$1"
  shift
  echo "=== $PHASE ==="
  "$@" >>"$LOG" 2>&1
  echo "OK: $PHASE"
}

echo "=== IDENTIDAD Y FUENTES ==="
PHASE=GIT_BRANCH
test "$(git branch --show-current)" = integration/local-e2e-prep
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: hay modificaciones versionadas; no se realizara el respaldo"
  git status --short
  exit 3
fi
EXTRA="$(git ls-files --others --exclude-standard |
  grep -vx 'clients/flutter/pubspec.lock' || true)"
if [ -n "$EXTRA" ]; then
  echo "ERROR: nuevos archivos inesperados en el checkout"
  printf '%s\n' "$EXTRA"
  exit 3
fi
VALIDATED_SHA=4d5270be3ebb7ab32d4bab103208ed34002f0082
git cat-file -e "$VALIDATED_SHA^{commit}"
if ! git diff --quiet "$VALIDATED_SHA" HEAD -- \
    backend clients compose.preview.yaml deploy; then
  echo "ERROR: el codigo de produccion ha cambiado desde el preflight validado"
  exit 3
fi
POLICY_COMMIT=9fe0f15945b6361a14d1d8ca2f912bfc9baf4cb2
git merge-base --is-ancestor "$POLICY_COMMIT" HEAD
if ! git diff --quiet "$POLICY_COMMIT" HEAD -- compose.yaml; then
  echo "ERROR: compose modificado desde hardening aprobado"
  exit 3
fi
echo "CODIGO_PREVALIDADO=$VALIDATED_SHA"
echo "COMMIT_ACTUAL=$(git rev-parse HEAD)"
echo "FUENTES_VERSIONADAS=OK"

PHASE=COMPOSE_IDENTITY
# sudo anticipado para no introducir un prompt oculto en el backup redirigido.
sudo -v
for service in api db web_preview; do
  label="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  test "$label" = vencira_localcheck || {
    echo "ERROR: identidad Docker incorrecta para $service"
    exit 4
  }
  previous_health="$(sudo docker inspect "vencira_localcheck-${service}-1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$previous_health" = healthy || {
    echo "ERROR: servicio $service sin salud inicial (valor=$previous_health)"
    exit 4
  }
done
echo "COMPOSE_IDENTITY=OK"
echo "HEALTH_PREVIO_API_DB_WEB=healthy"
# Script de una sola ejecución. No reciclarlo si la API ya está endurecida.
PHASE=RUNTIME_PREVIO
old_runtime_cmd="$(sudo docker inspect vencira_localcheck-api-1 --format '{{json .Config.Cmd}}')"
if [[ "$old_runtime_cmd" == *'migrate --check --noinput'* ]]; then
  echo "ERROR: el arranque API ya está protegido. No repetir O4; comprobar salud."
  exit 4
fi
if [[ "$old_runtime_cmd" != *'migrate --noinput'* ]]; then
  echo "ERROR: comando de arranque API previo distinto del previsto; detener."
  exit 4
fi
echo "API_COMANDO_ANTIGUO=AUTOMIGRATE_CONFIRMADO"
step COMPOSE_CONFIG sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml config --quiet

COMPOSE=(sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml)
check_policy() {
  "${COMPOSE[@]}" config --format json | python3 -c '
import json, sys
cmd=json.load(sys.stdin)["services"]["api"]["command"]
if isinstance(cmd,list): cmd=" ".join(cmd)
assert "migrate --check --noinput" in cmd, "No fail-closed migration check"
assert "migrate --noinput" not in cmd, "Unexpected automatic migration"
assert "exec gunicorn" in cmd, "Gunicorn is not primary process"
'
}
step COMPOSE_GUARD_CHECK_ONLY check_policy
echo "COMPOSE_MIGRATE_POLICY=CHECK_ONLY"


DB=vencira_localcheck-db-1
live_sql() {
  sudo docker exec "$DB" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq -c "$1"' \
    sh "$1"
}
PHASE=DB_SCHEMA_O3
echo "=== ESTADO MIGRACIONES PERSISTENTES ==="
migration="$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$migration" = 0014_renewal_outcomes || {
  echo "ERROR: migracion maxima inesperada: $migration (esperada 0014_renewal_outcomes)"
  exit 5
}
echo "ULTIMA_MIGRACION=0014_renewal_outcomes"
# Estamos en O3 ya migrada: jamás intentar aplicar 0014 de nuevo.
PHASE=SCHEMA_0014_APPLIED
o3_table="$(live_sql "SELECT to_regclass('public.reminders_renewaloutcome') IS NOT NULL;")"
o3_index="$(live_sql "SELECT to_regclass('public.outcome_renewal_time_idx') IS NOT NULL;")"
o3_columns="$(live_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='reminders_renewal' AND column_name IN ('archived_at','archive_outcome');")"
test "$o3_table" = t && test "$o3_index" = t && test "$o3_columns" = 2 || {
  echo "ERROR: esquema O3 incompleto. No se realizará despliegue."
  exit 5
}
DB_CONTAINER_ID="$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
MIGRATION_STAMP="$(live_sql "SELECT COUNT(*)::text || ':' || COALESCE(MAX(applied)::text,'') FROM django_migrations WHERE app='reminders' AND name='0014_renewal_outcomes';")"
echo "ESQUEMA_O3_ACTUAL=OK"


BACKUP_DIR=/home/vencira/vencira-db-backups
PHASE=BACKUP_DIRECTORY
test ! -L "$BACKUP_DIR" || {
  echo "ERROR: el directorio de backups es un enlace simbolico"
  exit 6
}
mkdir -p -m 700 "$BACKUP_DIR"
test -O "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
BACKUP="$(mktemp "$BACKUP_DIR/post0014_o4_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXXXX.dump")"
chmod 600 "$BACKUP"
echo "=== COPIA PG_DUMP (formato custom) ==="
PHASE=PG_DUMP
sudo docker exec "$DB" sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -Fc -h 127.0.0.1 \
   -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  >"$BACKUP" 2>>"$LOG"
test -s "$BACKUP"
test "$(stat -c %a "$BACKUP")" = 600
echo "PG_DUMP=OK"
step PG_RESTORE_INDEX sh -c 'sudo docker exec -i vencira_localcheck-db-1 pg_restore -l < "$1" >/dev/null' \
  sh "$BACKUP"

PHASE=CHECKSUM
sha256sum "$BACKUP" > "$BACKUP.sha256"
chmod 600 "$BACKUP.sha256"
sha256sum --status -c "$BACKUP.sha256"
echo "SHA256=OK"

# Ensayo completo aislado en postgres:17, red deshabilitada, sin volumen persistente.
RESTORE_NAME="vencira_o4_restore_$$"
PHASE=RESTORE_CONTAINER
echo "=== RESTAURACION EFIMERA SIN RED NI VOLUMEN ==="
sudo docker run -d --rm --name "$RESTORE_NAME" --network none \
  -e POSTGRES_USER=o4_restore -e POSTGRES_DB=o4_restore \
  -e POSTGRES_PASSWORD=o4-restore-temporary-only \
  postgres:17-alpine >>"$LOG" 2>&1
RESTORE_STARTED=1
ready=0
for attempt in $(seq 1 40); do
  if sudo docker exec "$RESTORE_NAME" pg_isready -U o4_restore -d o4_restore \
     >>"$LOG" 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
test "$ready" = 1
PHASE=PG_RESTORE_COMPLETO
sudo docker exec -i "$RESTORE_NAME" pg_restore \
  --clean --if-exists --no-owner --no-privileges --exit-on-error \
  -U o4_restore -d o4_restore < "$BACKUP" >>"$LOG" 2>&1
echo "RESTAURACION_INTEGRAL=OK"

PHASE=RESTORE_SCHEMA
restored="$(sudo docker exec "$RESTORE_NAME" psql -X -v ON_ERROR_STOP=1 \
  -U o4_restore -d o4_restore -Atqc \
  "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$restored" = 0014_renewal_outcomes
# Contrastar conteos generales sin sacar valores personales a la terminal.
counts="SELECT (SELECT COUNT(*) FROM reminders_workspace)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_renewal)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_renewaloutcome)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_renewalfollowup)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_remindercandidate)::text || ':' ||
               (SELECT COUNT(*) FROM reminders_renewalauditevent)::text || ':' ||
               (SELECT COUNT(*) FROM django_migrations)::text;"
live_counts="$(live_sql "$counts")"
restored_counts="$(sudo docker exec "$RESTORE_NAME" psql \
  -X -v ON_ERROR_STOP=1 -U o4_restore -d o4_restore -Atqc "$counts")"
test "$live_counts" = "$restored_counts" || {
  echo "ERROR: los conteos difieren entre BD viva y copia restaurada"
  exit 8
}
echo "CONTENIDO_RESTAURADO=VERIFICADO"
echo "MIGRACION_0014_YA_APLICADA=1"

# Recibo no secreto vinculado al commit probado y al archivo restaurado.
PHASE=RECEIPT
printf 'VALIDATED_SHA=%s\nARCHIVE_SHA256=%s\nRESTORE_TEST=OK\n' \
 "$VALIDATED_SHA" "$(sha256sum "$BACKUP" | awk '{print $1}')" \
 > "$BACKUP.verified"
chmod 600 "$BACKUP.verified"
BACKUP_OK=1

# Postbackup, sin cambios persistentes de esquema: probar código O3 aprobado.
PHASE=RESTORE_LIMPIEZA
sudo docker stop "$RESTORE_NAME" >>"$LOG" 2>&1
RESTORE_STARTED=0
echo "RESTAURACION_POSTGRES_TEMPORAL=VERIFICADA"
step SINTAXIS_SCRIPT bash -n scripts/harden_api_migrations_o4.sh
IMAGE="vencira-o4-test:$RUN_ID"
step BUILD_API_AISLADA sudo docker build -t "$IMAGE" ./backend
step DJANGO_CHECK_Y_MIGRACIONES_EN_SECO sudo docker run --rm \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=o4-ephemeral-validation-key-never-production-2026-django \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  "$IMAGE" sh -ec 'python manage.py check && python manage.py makemigrations --check --dry-run'
step REGRESION_DJANGO_SQLITE sudo docker run --rm \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=o4-ephemeral-validation-key-never-production-2026-django \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  "$IMAGE" python manage.py test reminders --verbosity 1 --noinput
echo "REGRESION_API_O3=OK"

# Build nuevo, seguido de --check SOLO LECTURA sobre la base actual.
step BUILD_API_COMPOSE "${COMPOSE[@]}" build api
step MIGRATE_CHECK_READ_ONLY "${COMPOSE[@]}" run --rm --no-deps \
  api python manage.py migrate --check --noinput
updated_stamp="$(live_sql "SELECT COUNT(*)::text || ':' || COALESCE(MAX(applied)::text,'') FROM django_migrations WHERE app='reminders' AND name='0014_renewal_outcomes';")"
test "$updated_stamp" = "$MIGRATION_STAMP" || {
  echo "ERROR: 0014 cambiada durante verificación"
  exit 7
}
echo "CHECK_MIGRACION_SOLO_LECTURA=OK"

PHASE=CONSERVAR_IMAGENES_O3
WEB_CONTAINER_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
OLD_API_ID="$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Image}}')"
OLD_WEB_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Image}}')"
OLD_API_TAG="vencira-prev-o4-api:$RUN_ID"
OLD_WEB_TAG="vencira-prev-o4-web:$RUN_ID"
# Tras docker compose build, la etiqueta anterior puede haber sido
# retirada del image store aunque el contenedor O3 continue activo.
# NO confundir una imagen reconstruida con la imagen binaria exacta previa.
OLD_API_AVAILABLE=0
if sudo docker image inspect "$OLD_API_ID" >>"$LOG" 2>&1; then
  sudo docker tag "$OLD_API_ID" "$OLD_API_TAG" >>"$LOG" 2>&1
  OLD_API_AVAILABLE=1
else
  RECOVERY_API_TAG="vencira-o4-recovery-api-rebuilt:$RUN_ID"
  sudo docker tag vencira_localcheck-api:latest "$RECOVERY_API_TAG" >>"$LOG" 2>&1
  echo "RECUPERACION_API=REBUILD_CODIGO_O3_VALIDADO_NO_IMAGEN_BINARIA_ORIGINAL"
  echo "ETIQUETA_RECUPERACION_API=$RECOVERY_API_TAG"
fi
OLD_WEB_AVAILABLE=0
if sudo docker image inspect "$OLD_WEB_ID" >>"$LOG" 2>&1; then
  sudo docker tag "$OLD_WEB_ID" "$OLD_WEB_TAG" >>"$LOG" 2>&1
  OLD_WEB_AVAILABLE=1
fi
echo "IMAGEN_ANTERIOR_API_DISPONIBLE=$OLD_API_AVAILABLE"
echo "IMAGEN_ANTERIOR_WEB_DISPONIBLE=$OLD_WEB_AVAILABLE"
RECEIPT="$BACKUP_DIR/deploy_o4_$RUN_ID.receipt"
printf 'COMMIT=%s\nBACKUP_SHA256=%s\nSCHEMA=0014_renewal_outcomes\nPREVIOUS_API_IMAGE=%s\nPREVIOUS_WEB_IMAGE=%s\nPREVIOUS_API_TAG=%s\nPREVIOUS_WEB_TAG=%s\n' \
  "$(git rev-parse HEAD)" "$(sha256sum "$BACKUP" | awk '{print $1}')" \
  "$OLD_API_ID" "$OLD_WEB_ID" "$OLD_API_TAG" "$OLD_WEB_TAG" >"$RECEIPT"
chmod 600 "$RECEIPT"
echo "IMAGENES_O3_RECUPERACION_PREPARADA=1"
if [ "$OLD_API_AVAILABLE" -eq 0 ]; then
  echo "AVISO_IMAGEN_ANTIGUA_API=no_disponible_en_Docker"
  echo "RECOVERY_API_NO_EQUIVALE_BINARIAMENTE_A_ORIGINAL=1"
fi

PHASE=RECREAR_API_CHECK_ONLY
echo "=== RECREAR_API_SIN_MIGRAR ==="
"${COMPOSE[@]}" up -d --no-deps --force-recreate api >>"$LOG" 2>&1
API_RECREATED=1
PHASE=ESPERAR_API
api_health=starting
for attempt in $(seq 1 40); do
  api_health="$(sudo docker inspect vencira_localcheck-api-1 \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$api_health" = healthy ] || [ "$api_health" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_api=$api_health"
test "$api_health" = healthy || exit 8

# Comando EFECTIVO del nuevo contenedor debe estar protegido.
PHASE=POLITICA_REAL_API
sudo docker inspect vencira_localcheck-api-1 --format '{{json .Config.Cmd}}' |
  python3 -c '
import json,sys
cmd=json.load(sys.stdin)
text=" ".join(cmd) if isinstance(cmd,list) else str(cmd)
assert "migrate --check --noinput" in text
assert "migrate --noinput" not in text
assert "exec gunicorn" in text
'
echo "API_RUNTIME_MIGRATE_POLICY=CHECK_ONLY"

# Nginx resuelve api:8000 al arrancar. Reiniciar el MISMO
# contenedor Web conserva el bundle O3 y NO precisa la imagen borrada.
PHASE=REINICIAR_PROXY_EXISTENTE
echo "=== REINICIAR_WEB_EXISTENTE_SIN_RECREAR ==="
sudo docker restart vencira_localcheck-web_preview-1 >>"$LOG" 2>&1
WEB_RECREATED=1
PHASE=ESPERAR_WEB
web_health=starting
for attempt in $(seq 1 40); do
  web_health="$(sudo docker inspect vencira_localcheck-web_preview-1 \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$web_health" = healthy ] || [ "$web_health" = unhealthy ]; then break; fi
  sleep 5
done
echo "HEALTH_web_preview=$web_health"
test "$web_health" = healthy || exit 9
test "$WEB_CONTAINER_ID" = "$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
echo "WEB_CONTENEDOR_ORIGINAL_CONSERVADO=1"

PHASE=POSTDEPLOY_DB_INTACTA
test "$DB_CONTAINER_ID" = "$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$MIGRATION_STAMP" = "$(live_sql "SELECT COUNT(*)::text || ':' || COALESCE(MAX(applied)::text,'') FROM django_migrations WHERE app='reminders' AND name='0014_renewal_outcomes';")"
test "$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0014_renewal_outcomes
sha256sum --status -c "$BACKUP.sha256"
echo "POSTGRES_Y_MIGRACION_0014_INALTERADOS=1"

PHASE=SALUD_HTTP
for endpoint in / /api/health/ /api/ready/ /accounts/login/; do
  code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' \
    "http://127.0.0.1:28732$endpoint")"
  echo "HTTP_${endpoint}=$code"
  test "$code" = 200 || exit 10
done
for service in api db web_preview; do
  health="$(sudo docker inspect "vencira_localcheck-$service-1" \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_$service=$health"
  test "$health" = healthy || exit 10
done
for ep in outcomes follow-up; do
  endpoint="http://127.0.0.1:28732/api/v1/workspaces/11111111-1111-4111-8111-111111111111/renewals/b2222222-2222-4222-8222-222222222222/$ep/"
  code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' "$endpoint")"
  echo "HTTP_${ep}_ANONIMO=$code"
  { test "$code" = 401 || test "$code" = 403; } || exit 11
done
sudo docker exec vencira_localcheck-web_preview-1 sh -c \
  'test -s /usr/share/nginx/html/main.dart.js && grep -Fq "Elegir desenlace" /usr/share/nginx/html/main.dart.js'
echo "FLUTTER_O3_CONSERVADO=1"

PHASE=REGISTRAR_RECIBO
printf 'RESULTADO_GLOBAL=0\nAPI_POLICY=CHECK_ONLY\nMIGRATIONS_APPLIED_BY_O4=0\nAPI_HEALTH=healthy\nWEB_HEALTH=healthy\nDB_CONTAINER_UNCHANGED=1\n' >>"$RECEIPT"
echo "SOLO_STACK_VENCIRA_LOCALCHECK=1"
echo "SIN_RESTAURACION_AUTOMATICA=1"
