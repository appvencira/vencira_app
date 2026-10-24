#!/usr/bin/env bash
# VENCIRA O5 — reautorizar remoto Drive existente, SIN sustituir Client ID/Secret.
# IMPORTANTE: la fase RCLONE_RECONNECT muestra en pantalla URL OAuth y
# posiblemente datos de autenticacion. NO copiar/capturar la transcripcion.
# Usar tunel SSH local 53682 hacia el navegador, ver docs O5.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck

PHASE=INICIO
CONFIG=/etc/vencira-backup/rclone.conf
CONFIG_DIR=/etc/vencira-backup
COPY_DIR=""
OAUTH_OK=0
CONFIG_CHANGED=0

finish() {
  local rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$CONFIG_CHANGED" -eq 1 ] && [ -n "$COPY_DIR" ]; then
    # Fallo del proceso: volver a version original guardada root:600
    if sudo install -o root -g root -m 0600 "$COPY_DIR/rclone.conf" "$CONFIG" >/dev/null 2>&1; then
      echo "CONFIG_ORIGINAL_RESTAURADA=1"
    else
      echo "ATENCION=ERROR_AL_RESTAURAR_CONFIG_REVISION_MANUAL_NECESARIA"
    fi
  fi
  if [ -n "$COPY_DIR" ]; then
    sudo rm -rf -- "$COPY_DIR" >/dev/null 2>&1 || rc=9
  fi
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "O5_GOOGLE_OAUTH_VERIFICADO=$OAUTH_OK"
  echo "SIN_ARCHIVOS_CREADOS_EN_DRIVE=1"
  echo "SIN_COPIAS_NI_MIGRACIONES=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

PHASE=FUENTES
test "$(git branch --show-current)" = integration/local-e2e-prep || exit 2
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)" || exit 2
echo "COMMIT=$(git rev-parse HEAD)"
test "$(restic version | awk '{print $2}')" = 0.19.1
command -v rclone >/dev/null
sudo -v

PHASE=SERVICIOS
for svc in api db web_preview; do
  container="vencira_localcheck-${svc}-1"
  project="$(sudo docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$container" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = vencira_localcheck && test "$health" = healthy
  echo "HEALTH_${svc}=healthy"
done

PHASE=CONFIG_SEGURA
sudo test -d "$CONFIG_DIR" && sudo test ! -L "$CONFIG_DIR"
test "$(sudo stat -c '%u:%a' "$CONFIG_DIR")" = "0:700"
sudo test -f "$CONFIG" && sudo test ! -L "$CONFIG"
test "$(sudo stat -c '%u:%a' "$CONFIG")" = "0:600"
sudo python3 - "$CONFIG" <<'PY'
import configparser
import sys
cfg = configparser.ConfigParser(interpolation=None)
if not cfg.read(sys.argv[1]) or not cfg.has_section("vencira_google"):
    raise SystemExit("ERROR: remoto existente no encontrado")
r = cfg["vencira_google"]
if r.get("type") != "drive" or r.get("scope") != "drive.file":
    raise SystemExit("ERROR: tipo o scope no autorizado")
if not r.get("client_id") or not r.get("client_secret"):
    raise SystemExit("ERROR: client ID/secret no presentes; no iniciar reconnect")
print("REMOTE_EXISTENTE_SCOPE_Y_CLIENTE=OK")
PY

PHASE=PRUEBA_INTERACTIVA
# SSH -t o la app SSH debe proporcionar TTY. No grabar la sesión.
test -t 0 && test -t 1 || {
  echo "ERROR: hace falta una sesión SSH interactiva con terminal"
  exit 3
}
echo "ANTES DE CONTINUAR: comprueba que el tunel SSH LOCAL 53682 esta activo"
echo "y que puedes abrir el enlace 127.0.0.1:53682 del servidor"
echo "en el navegador del DISPOSITIVO QUE MANTIENE EL TUNEL."
echo "No compartas la transcripcion OAuth ni token/secret en chat."
echo "Si no tienes tunel, pulsa Ctrl+C ahora y configuralo."
echo "=== AUTORIZACION DEL REMOTO EXISTENTE (INTERACTIVO) ==="

PHASE=BACKUP_PRIVADO
COPY_DIR="$(sudo mktemp -d /etc/vencira-backup/.o5-reconnect.XXXXXXXX)"
sudo chmod 0700 "$COPY_DIR"
sudo install -o root -g root -m 0600 "$CONFIG" "$COPY_DIR/rclone.conf"
echo "COPIA_CONFIG_PRIVADA_TEMPORAL=OK"

PHASE=RCLONE_RECONNECT
CONFIG_CHANGED=1
# Inicia sólo un OAuth nuevo sobre remoto existente. No imprime la config.
# En Y con tunel SSH se abrira la URL privada localhost:53682.
sudo env RCLONE_CONFIG="$CONFIG" rclone config reconnect vencira_google:

PHASE=VERIFICACION_SIN_SECRETOS
sudo python3 - "$CONFIG" <<'PY'
import configparser
import json
import os
import stat
import sys
p = sys.argv[1]
st = os.stat(p)
if st.st_uid != 0 or stat.S_IMODE(st.st_mode) != 0o600:
    raise SystemExit("ERROR: permisos root:600 incorrectos")
cfg = configparser.ConfigParser(interpolation=None)
if not cfg.read(p) or not cfg.has_section("vencira_google"):
    raise SystemExit("ERROR: remoto desaparecido")
r = cfg["vencira_google"]
if r.get("type") != "drive" or r.get("scope") != "drive.file":
    raise SystemExit("ERROR: scope cambiado, no continuar")
if not r.get("client_id") or not r.get("client_secret"):
    raise SystemExit("ERROR: cliente OAuth propio ausente")
try:
    token = json.loads(r.get("token", ""))
except (ValueError, TypeError):
    raise SystemExit("ERROR: token sigue malformado")
if not isinstance(token, dict) or not token.get("refresh_token") or not token.get("access_token"):
    raise SystemExit("ERROR: token OAuth incompleto")
print("RCLONE_TOKEN_OAUTH_VALIDO=OK")
print("RCLONE_SCOPE_DRIVE_FILE=OK")
print("RCLONE_CONF_ROOT_PERMISOS=OK")
PY

PHASE=ACCESO_DRIVE
if timeout 90s sudo env RCLONE_CONFIG="$CONFIG" rclone --contimeout 15s \
  --timeout 40s lsd vencira_google: >/dev/null 2>&1; then
  echo "RCLONE_GOOGLE_DRIVE_ACCESO=OK"
else
  echo "ERROR: no se puede acceder a Drive con el nuevo token"
  exit 4
fi

PHASE=SNAPSHOT_EXISTENTE
# No se permite habilitar un timer si el OAuth nuevo no abre el
# repositorio Restic previamente existente.
sudo bash scripts/o5_verify_existing_drive.sh
echo "O5_REPO_ORIGINAL_TRAS_RECONNECT=OK"

PHASE=CONSTANCIA_OAUTH
# Marcador privado SOLO despues de reconectar Rclone y leer Restic real.
# Este marcador indica renovacion valida tras la declaracion In production
# del titular; no es prueba independiente del estado en Google Cloud.
sudo install -d -o root -g root -m 0700 /var/lib/vencira-o5
sudo bash -euc '
  umask 077
  f="$(mktemp /var/lib/vencira-o5/.oauth.XXXXXXXX)"
  date -u +%s > "$f"
  chmod 0600 "$f"
  mv -f -- "$f" /var/lib/vencira-o5/oauth-postproduction.epoch
'
echo "O5_POSTPRODUCTION_RECONNECT_REGISTRADO=OK"

PHASE=OK
echo "O5_OAUTH_CONFIGURADO=1"
OAUTH_OK=1
