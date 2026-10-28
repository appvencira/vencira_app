#!/usr/bin/env bash
# O8b: gate integral y despliegue DEV solo en caso de pruebas verdes.
# No es aplicable a producción ni a datos reales. No toca esquema PG17.
set -Eeuo pipefail
umask 077
PHASE=GIT
finish(){
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA_ORQUESTACION=$PHASE"
    echo "NO_REPETIR_DESPLIEGUE_A_CIEGAS=1"
  else
    echo "O8B_VALIDADO_Y_DESPLEGADO=OK"
  fi
  echo "RESULTADO_ORQUESTACION=$rc"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard |
  grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra"
echo "COMMIT=$(git rev-parse HEAD)"
bash -n scripts/validate_o7_o8_preflight.sh
bash -n scripts/deploy_o8b_no_migrations.sh

PHASE=PREFLIGHT_INTEGRAL
echo "=== O8B PREFLIGHT SIN DESPLIEGUE ==="
bash scripts/validate_o7_o8_preflight.sh
echo "O8B_PREFLIGHT_COMPLETO=OK"

PHASE=DEPLOY_O8B
echo "=== O8B DEPLOY CONTROLADO DEV ==="
bash scripts/deploy_o8b_no_migrations.sh
echo "O8B_DEPLOY_COMPLETO=OK"
