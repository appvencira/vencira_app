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
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)_$"
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
    echo "BACKUP_VERIFICADO=0"
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
done
echo "COMPOSE_IDENTITY=OK"
step COMPOSE_CONFIG sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml config --quiet

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
