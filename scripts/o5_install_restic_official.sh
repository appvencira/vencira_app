#!/usr/bin/env bash
# O5: instalar Restic 0.19.1 oficial verificado, sin cambiar package apt.
# No OAuth, no DB, no migraciones, sin reiniciar Docker.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-o5-restic-compat.XXXXXXXX.log)"
PHASE=INICIO
STAGE=""
UPDATED=0
TEST_OK=0

finish() {
  local rc=$?
  trap - EXIT
  if [ -n "$STAGE" ]; then rm -rf -- "$STAGE" || rc=1; fi
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "=== ULTIMAS 35 LINEAS DIAGNOSTICO ==="
    tail -n 35 "$LOG" 2>/dev/null || true
  fi
  echo "RESTIC_OFICIAL_INSTALADO=$UPDATED"
  echo "RESTIC_PRUEBA_CIFRADA_LOCAL=$TEST_OK"
  echo "GOOGLE_DRIVE_NO_CONECTADO=1"
  echo "SIN_MIGRACIONES_NI_REINICIOS=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

echo "=== CHECKOUT Y ENTORNO ==="
PHASE=IDENTIDAD
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)"
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04
test "$(uname -m)" = x86_64
echo "COMMIT=$(git rev-parse HEAD)"
echo "SISTEMA=Ubuntu_24.04_x86_64"
sudo -v
for service in api db web_preview; do
  cname="vencira_localcheck-${service}-1"
  project="$(sudo docker inspect "$cname" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$cname" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = vencira_localcheck && test "$health" = healthy || {
    echo "ERROR: stack o salud de $service no corresponde a localcheck"
    exit 2
  }
done
API_ID="$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
DB_ID="$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
WEB_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
echo "CONTENEDORES_PREVIOS=healthy"

PHASE=PREREQUISITOS
missing=0
for tool in curl sha256sum python3 openssl restic rclone grep awk sed; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "REQUISITO_${tool}=OK"
  else
    echo "REQUISITO_${tool}=FALTA"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "ERROR: faltan herramientas detalladas arriba; no se ha descargado ni instalado nada"
  exit 3
fi
if ! python3 -c "import bz2, shutil" >/dev/null 2>&1; then
  echo "ERROR: modulos estándar Python bz2/shutil no disponibles; no se ha instalado nada"
  exit 3
fi
echo "DESCOMPRESION_PYTHON_BZ2=DISPONIBLE"
echo "RESTIC_ANTERIOR=$(restic version)"
echo "RCLONE_VERSION=$(rclone version | sed -n '1p')"

# SHA256 fijado del release oficial Linux amd64 v0.19.1, publicado 05/07/2026.
VERSION=0.19.1
ARCHIVE=restic_0.19.1_linux_amd64.bz2
SHA256_ESPERADO=f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c
URL="https://github.com/restic/restic/releases/download/v${VERSION}/${ARCHIVE}"
STAGE="$(mktemp -d /tmp/vencira-o5-restic.XXXXXXXX)"
chmod 700 "$STAGE"

PHASE=DESCARGA
echo "=== DESCARGA OFICIAL RESTIC 0.19.1 ==="
curl -fsSL --retry 3 --connect-timeout 15 --max-time 180 \
  -o "$STAGE/$ARCHIVE" "$URL" >>"$LOG" 2>&1
test -s "$STAGE/$ARCHIVE"
echo "DESCARGA=OK"

PHASE=SHA256
echo "$SHA256_ESPERADO  $STAGE/$ARCHIVE" | sha256sum --status -c - || {
  echo "ERROR: huella SHA256 incorrecta. No se instala la descarga."
  exit 4
}
echo "SHA256_PINNED_RELEASE=OK"

PHASE=VERIFICAR_BINARIO
# Descomprimir con Python estándar (bz2) sin depender del paquete bzip2.
# SHA256 se verifica ANTES de abrir el archivo.
python3 - "$STAGE/$ARCHIVE" "$STAGE/restic" <<'PY'
import bz2
import shutil
import sys
with bz2.open(sys.argv[1], "rb") as source, open(sys.argv[2], "xb") as target:
    shutil.copyfileobj(source, target, length=1024 * 1024)
PY
echo "DESCOMPRESION_PYTHON_BZ2=OK"
chmod 700 "$STAGE/restic"
test -s "$STAGE/restic"
test "$("$STAGE/restic" version | awk '{print $2}')" = "$VERSION"
"$STAGE/restic" backup --help | grep -F -- '--stdin-from-command' >>"$LOG"
"$STAGE/restic" dump --help >>"$LOG" 2>&1
rclone serve restic --help >>"$LOG" 2>&1
echo "RESTIC_STDIN_FROM_COMMAND=OK"
echo "RCLONE_BACKEND_RESTIC=OK"

PHASE=PRUEBA_CIFRADA_AISLADA
echo "=== PRUEBA LOCAL DE BACKUP Y RESTORE CIFRADOS ==="
export RESTIC_PASSWORD="$(openssl rand -hex 32)"
export RESTIC_REPOSITORY="$STAGE/repository_test"
"$STAGE/restic" init >>"$LOG" 2>&1
"$STAGE/restic" backup --quiet --stdin-filename prueba.txt \
  --stdin-from-command -- sh -c 'printf "vencira-o5-restic-ok\n"' >>"$LOG" 2>&1
test "$("$STAGE/restic" dump latest prueba.txt)" = vencira-o5-restic-ok
"$STAGE/restic" check >>"$LOG" 2>&1
unset RESTIC_PASSWORD RESTIC_REPOSITORY
TEST_OK=1
echo "PRUEBA_CIFRADA_Y_RESTAURACION_LOCAL=OK"

PHASE=INSTALACION
echo "=== INSTALAR BINARIO VERIFICADO SIN ALTERAR APT ==="
sudo install -o root -g root -m 0755 "$STAGE/restic" /usr/local/bin/restic.vencira-new >>"$LOG" 2>&1
sudo mv -f /usr/local/bin/restic.vencira-new /usr/local/bin/restic >>"$LOG" 2>&1
hash -r
test "$(command -v restic)" = /usr/local/bin/restic
test "$(restic version | awk '{print $2}')" = "$VERSION"
UPDATED=1
echo "RESTIC_ACTUAL=$(restic version)"
echo "RESTIC_APT_ANTERIOR_EN_USR_BIN=CONSERVADO"

PHASE=VERIFICACION_FINAL
test "$API_ID" = "$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
test "$DB_ID" = "$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$WEB_ID" = "$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
for service in api db web_preview; do
  health="$(sudo docker inspect "vencira_localcheck-${service}-1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_${service}=$health"
  test "$health" = healthy
done
echo "CONTENEDORES_INTACTOS=1"
echo "O5_HERRAMIENTAS_COMPATIBLES=OK"
