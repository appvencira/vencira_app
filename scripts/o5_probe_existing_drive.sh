#!/usr/bin/env bash
# O5: inspeccion segura de Rclone existente sin mostrar secretos ni reconfigurar.
# lsd consulta metadatos; puede renovar token OAuth dentro de rclone.conf.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=INICIO
PROBE=0
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "RCLONE_EXISTENTE_VALIDADO=$PROBE"
  echo "CONFIG_NO_SOBRESCRITA=1"
  echo "SIN_ARCHIVOS_CREADOS_EN_DRIVE=1"
  echo "SIN_BACKUP_NI_MIGRACIONES=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

echo "=== FUENTES Y SERVICIOS ==="
PHASE=GIT
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)"
echo "COMMIT=$(git rev-parse HEAD)"
test "$(restic version | awk '{print $2}')" = 0.19.1
command -v rclone >/dev/null
sudo -v
PHASE=SERVICIOS
for service in api db web_preview; do
  cname="vencira_localcheck-${service}-1"
  project="$(sudo docker inspect "$cname" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$cname" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = vencira_localcheck && test "$health" = healthy || {
    echo "ERROR: identidad o salud incorrecta en $service"; exit 3;
  }
  echo "HEALTH_${service}=healthy"
done
PHASE=PERMISOS
CONF_DIR=/etc/vencira-backup
CONF="$CONF_DIR/rclone.conf"
sudo test -d "$CONF_DIR" && sudo test ! -L "$CONF_DIR" &&
  test "$(sudo stat -c '%u:%a' "$CONF_DIR")" = "0:700" || {
  echo "ERROR: /etc/vencira-backup debe ser directorio root:700"; exit 4;
}
sudo test -f "$CONF" && sudo test ! -L "$CONF" &&
  test "$(sudo stat -c '%u:%a' "$CONF")" = "0:600" || {
  echo "ERROR: rclone.conf debe ser archivo root:600"; exit 4;
}
echo "CONFIG_PRIVADA_ROOT_0700_0600=OK"

# Comprobar estructura y presencia de credenciales sin imprimir sus valores.
PHASE=METADATOS
sudo python3 - "$CONF" <<'PY'
import configparser
import json
import sys

cfg = configparser.ConfigParser(interpolation=None)
if not cfg.read(sys.argv[1]) or not cfg.has_section("vencira_google"):
    raise SystemExit("ERROR: remoto vencira_google inexistente")
r = cfg["vencira_google"]
if r.get("type", "") != "drive":
    raise SystemExit("ERROR: remoto no es tipo drive")
print("RCLONE_TIPO_DRIVE=OK")
if r.get("scope", "") != "drive.file":
    print("RCLONE_SCOPE_DRIVE_FILE=NO")
    raise SystemExit(5)
print("RCLONE_SCOPE_DRIVE_FILE=OK")
if not r.get("client_id") or not r.get("client_secret"):
    print("RCLONE_CLIENTE_OAUTH_PROPIO=INCOMPLETO")
    raise SystemExit(5)
print("RCLONE_CLIENTE_OAUTH_PROPIO=OK")
try:
    token = json.loads(r.get("token", ""))
except (ValueError, TypeError):
    print("RCLONE_TOKEN_OAUTH=NO_VALIDO")
    raise SystemExit(5)
if not isinstance(token, dict) or not token.get("refresh_token") or not token.get("access_token"):
    print("RCLONE_TOKEN_OAUTH=INCOMPLETO")
    raise SystemExit(5)
print("RCLONE_TOKEN_OAUTH=PRESENTE")
PY
echo "CONFIG_OAUTH_LOCAL=OK"

PHASE=ACCESO_DRIVE
echo "=== PROBAR ACCESO A DRIVE SIN MOSTRAR CARPETAS ==="
if timeout 90s sudo env RCLONE_CONFIG="$CONF" \
  rclone --contimeout 15s --timeout 40s lsd vencira_google: \
  >/dev/null 2>&1; then
  echo "RCLONE_GOOGLE_DRIVE_ACCESO=OK"
else
  echo "RCLONE_GOOGLE_DRIVE_ACCESO=ERROR"
  echo "Revisar autorizacion OAuth o API; no sobrescribir el remoto."
  exit 6
fi
PHASE=VERIFICACION_FINAL
test "$(sudo stat -c '%u:%a' "$CONF")" = "0:600"
echo "RCLONE_CONF_ROOT_PERMISOS=OK"
echo "O5_OAUTH_CONFIGURADO=1"
PROBE=1
