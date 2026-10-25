#!/usr/bin/env bash
# VENCIRA macrobloque A: validacion integral SIN despliegue.
# Usa el preflight aislado existente, no ejecuta migrate en DB persistente.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=IDENTIDAD
echo "=== MACROBLOQUE_A_IDENTIDAD ==="
test "$(git branch --show-current)" = "integration/local-e2e-prep"
test -z "$(git status --porcelain --untracked-files=normal)"
test "$(git rev-parse --show-toplevel)" = "/home/vencira/vencira-localcheck"
SHA="$(git rev-parse HEAD)"
echo "MACRO_A_SHA=$SHA"

PHASE=FUENTES
for path in \
  backend/reminders/migrations/0017_operational_reminders.py \
  backend/reminders/migrations/0018_draft_reasons.py \
  backend/reminders/operational_api.py \
  backend/reminders/reminder_activate.py \
  backend/reminders/operational_transitions.py \
  backend/reminders/control_repeat_schedule.py \
  backend/reminders/test_operational_agenda.py \
  backend/reminders/test_operational_transitions.py \
  backend/reminders/test_reminder_activate.py \
  clients/flutter/lib/ui/operational_panel.dart; do
  test -f "$path" || { echo "FALTA_FUENTE=$path"; exit 4; }
done
echo "MACRO_A_FUENTES=OK"

PHASE=GATE_INTEGRAL
# Este script ya valida identidad, salud localcheck, Compose,
# traducciones ES/CA, Django check + makemigrations --check --dry-run,
# todas las pruebas SQLite y PG17 EFIMERO, Flutter analyze/test/build,
# y salud localcheck final. Separa contenedores efimeros y los limpia.
bash scripts/validate_o7_o8_preflight.sh
echo "MACRO_A_PREFLIGHT_COMPLETO=OK"
echo "MACRO_A_NO_DESPLEGADO=1"
echo "MACRO_A_NO_MIGRACIONES_EN_DB_PERSISTENTE=1"
echo "MACRO_A_SHA_VALIDADO=$SHA"
