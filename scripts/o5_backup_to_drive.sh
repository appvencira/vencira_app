#!/usr/bin/env bash
# O5 — copia PostgreSQL vía restic(rclone:Google Drive). SOLO tras OAuth,
# clave fuera de GitHub, y prueba de recuperacion exitosa.
# Ejecutar como root desde servicio controlado, no en entorno publico.
set -euo pipefail
umask 077
PHASE=INICIO
LOCK=/run/lock/vencira-o5-backup.lock

finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "NO_SE_MIGRO_NI_REINICIO_POSTGRES=1"
  echo "SIN_DUMP_EN_DISCO_LOCAL=1"
  exit "$rc"
}
trap finish EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: solo root. Sin sudo persistente ni contraseñas en cron."
  exit 2
fi
exec 8>"$LOCK"
if ! flock -n 8; then
  echo "ERROR: copia ya en ejecución"
  exit 2
fi
cd /home/vencira/vencira-localcheck

PHASE=CONFIG
CONFIG_DIR=/etc/vencira-backup
test -d "$CONFIG_DIR" && test ! -L "$CONFIG_DIR"
test "$(stat -c %u:%a "$CONFIG_DIR")" = 0:700
CONFIG_FILE="$CONFIG_DIR/config.env"
test -f "$CONFIG_FILE" && test ! -L "$CONFIG_FILE"
test "$(stat -c %u:%a "$CONFIG_FILE")" = 0:600
# shellcheck disable=SC1091
. "$CONFIG_FILE"
: "${RESTIC_REPOSITORY:?}"
: "${RESTIC_PASSWORD_FILE:?}"
: "${RCLONE_CONFIG:?}"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = /etc/vencira-backup/restic-password
test "$RCLONE_CONFIG" = /etc/vencira-backup/rclone.conf
for f in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  test -f "$f" && test ! -L "$f"
  test "$(stat -c %u:%a "$f")" = 0:600
done
test -s "$RESTIC_PASSWORD_FILE" && test -s "$RCLONE_CONFIG"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
for cmd in docker restic rclone flock; do command -v "$cmd" >/dev/null; done

PHASE=CONTENEDOR
DB=vencira_localcheck-db-1
label="$(docker inspect "$DB" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
health="$(docker inspect "$DB" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
test "$label" = vencira_localcheck && test "$health" = healthy
echo "DB_LOCALCHECK_HEALTHY=1"

PHASE=RESTIC_ACCESS
restic snapshots --quiet >/dev/null
echo "RESTIC_DRIVE_ACCESIBLE=1"

# --stdin-from-command comprueba el exit code de pg_dump; nunca
# almacenar una copia sin cifrar en el directorio de respaldos local.
PHASE=PG_DUMP_ENCRYPT_UPLOAD
echo "=== COPIA CIFRADA DE POSTGRESQL A DRIVE ==="
restic backup --tag vencira-postgresql --stdin-filename vencira-postgres.dump \
  --stdin-from-command -- docker exec "$DB" sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -Fc -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

PHASE=REPOSITORY_CHECK
restic check >/dev/null
echo "RESTIC_INTEGRIDAD_METADATA=OK"
echo "GOOGLE_DRIVE_BACKUP_CIFRADO=OK"
