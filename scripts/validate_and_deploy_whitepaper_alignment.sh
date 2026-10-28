#!/usr/bin/env bash
# One gate, one release of whitepaper alignment fixes. No schema migration.
# Only DEV stack vencira_localcheck; never touches O5 timers or other stacks.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
PHASE=INITIAL
LOG="$(mktemp /tmp/vencira-wp-align.XXXXXXXX.log)"
DEPLOY_ATTEMPTED=0
finish(){
  code=$?
  trap - EXIT
  if [ "$code" -ne 0 ]; then
    echo "FASE_FALLIDA_ORQUESTACION=$PHASE"
    echo "DESPLIEGUE_INTENTADO=$DEPLOY_ATTEMPTED"
    echo "NO_REPETIR_DESPLIEGUE_A_CIEGAS=1"
    echo "REVISA_LOG_LOCAL=$LOG"
    tail -n 45 "$LOG" 2>/dev/null || true
  else
    echo "WP_ALIGNMENT_PHASE_COMPLETE=OK"
  fi
  echo "RESULTADO_ORQUESTACION=$code"
  echo "SIN_MIGRACIONES_NI_REINICIOS_POSTGRES=1"
  echo "SIN_CAMBIOS_CADDY_RESTIC_TIMERS=1"
  echo "LOG_ORQUESTACION=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$code"
}
trap finish EXIT

PHASE=STATIC_GATE
echo "=== WP_STATIC_GATE ==="
bash scripts/check_whitepaper_alignment_static.sh | tee -a "$LOG"
echo "WP_STATIC_GATE=OK"

PHASE=PREFLIGHT_INTEGRAL
echo "=== WP_PREFLIGHT_INTEGRAL ==="
bash scripts/validate_o7_o8_preflight.sh | tee -a "$LOG"
grep -Fxq "LOCALCHECK_HEALTH_POST=OK" "$LOG"
grep -Fxq "DJANGO_SQLITE_SUITE_COMPLETA=OK" "$LOG"
grep -Fxq "DJANGO_POSTGRES17_SUITE_COMPLETA=OK" "$LOG"
grep -Fxq "FLUTTER_ANALYZE_TEST_BUILD=OK" "$LOG"
grep -Fxq "O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK" "$LOG"
grep -Fxq "RESULTADO_GLOBAL=0" "$LOG"
echo "WP_PREFLIGHT_INTEGRAL=OK"

PHASE=DESPLIEGUE_API_WEB
echo "=== WP_DESPLIEGUE_API_WEB ==="
DEPLOY_ATTEMPTED=1
bash scripts/deploy_whitepaper_alignment_no_migrations.sh | tee -a "$LOG"
grep -Fxq "WP_ALIGNMENT_DESPLIEGUE_SIN_MIGRACION=OK" "$LOG"
echo "WP_RELEASE_API_WEB=OK"
