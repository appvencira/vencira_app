#!/usr/bin/env bash
# O5 — diagnostico local y no destructivo del puerto OAuth de Rclone.
# NO termina procesos, NO ejecuta reconnect ni toca credenciales/DB/Drive.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=INICIO
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "SIN_PROCESOS_DETENIDOS=1"
  echo "SIN_MODIFICACION_OAUTH_DRIVE_DB=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

PHASE=GIT
test "$(git branch --show-current)" = integration/local-e2e-prep || {
  echo "ERROR: rama inesperada"; exit 2;
}
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)" || {
  echo "ERROR: checkout versionado con modificaciones"; exit 2;
}
echo "COMMIT=$(git rev-parse HEAD)"
command -v ss >/dev/null || { echo "ERROR: ss ausente"; exit 2; }
command -v python3 >/dev/null || { echo "ERROR: python3 ausente"; exit 2; }
sudo -v

PHASE=SERVICIOS
for service in api db web_preview; do
  container="vencira_localcheck-${service}-1"
  project="$(sudo docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$container" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = vencira_localcheck && test "$health" = healthy || {
    echo "ERROR: salud/identidad de $service incorrecta"; exit 3;
  }
  echo "HEALTH_${service}=healthy"
done

PHASE=PUERTO
echo "=== DIAGNOSTICO PUERTO OAUTH 53682 EN UBUNTU ==="
# No imprimir argumentos de procesos, ni credenciales o informacion de red.
sudo python3 - <<'PY'
import errno
import os
import re
import socket
import subprocess
import sys

PORT = 53682
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    try:
        sock.bind(("127.0.0.1", PORT))
    except OSError as exc:
        if exc.errno != errno.EADDRINUSE:
            print("PUERTO_53682=ERROR_BIND_NO_ES_OCUPACION")
            print("ERROR_NUMERO=", exc.errno, sep="")
            sys.exit(4)
        print("PUERTO_53682=OCUPADO")
    else:
        print("PUERTO_53682=LIBRE")
        print("PUERTO_REINTENTAR_OAUTH=POSIBLE_SI_TUNEL_LOCAL_CORRECTO")
        sys.exit(0)

res = subprocess.run(
    ["ss", "-H", "-lntp", "sport = :53682"],
    capture_output=True, text=True, check=False, timeout=8,
)
if res.returncode != 0:
    print("IDENTIFICACION_PROCESO=ERROR_SS")
    sys.exit(4)
found = 0
for line in res.stdout.splitlines():
    if not line.strip():
        continue
    found += 1
    addr = "127.0.0.1" if "127.0.0.1:53682" in line else (
        "[::1]" if "[::1]:53682" in line else "OTRA_INTERFAZ"
    )
    print("PUERTO_DIRECCION=" + addr)
    owners = re.findall(r'\("([^"]+)",pid=(\d+),fd=\d+\)', line)
    if not owners:
        print("PUERTO_DUENO=NO_IDENTIFICADO")
        continue
    for name, pid in owners[:5]:
        safe_name = re.sub(r"[^A-Za-z0-9_.-]", "?", name)[:40]
        print("PUERTO_PROCESO=" + safe_name)
        print("PUERTO_PID=" + pid)
        try:
            st = os.stat("/proc/" + pid)
            print("PUERTO_UID=" + str(st.st_uid))
        except OSError:
            print("PUERTO_UID=DESCONOCIDO")
if found == 0:
    print("PUERTO_SS_NO_IDENTIFICA_LISTENER=1")
    print("NOTA=Podria ser otro socket o una carrera; no terminar procesos")
else:
    print("REQUIERE_CORREGIR_PUERTO_ANTES_DE_RECONNECT=1")
PY
