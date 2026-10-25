#!/usr/bin/env bash
# Macrofase B: gate aislado de backend y Flutter; NO desplegar/migrar DEV.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=IDENTITY
finish() {
 rc=$?
 trap - EXIT
 if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
 echo "MACRO_B_GATE_RESULTADO=$rc"
 echo "NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1"
 exit "$rc"
}
trap finish EXIT
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
for path in   backend/reminders/operational_inbox.py   backend/reminders/test_operational_inbox.py   clients/flutter/lib/ui/operational_inbox_screen.dart   clients/flutter/test/operational_inbox_test.dart; do
  test -f "$path" || { echo "FALTA_FUENTE=$path"; exit 4; }
done
echo "MACRO_B_COMMIT=$(git rev-parse HEAD)"
echo "MACRO_B_FUENTES=OK"
PHASE=FULL_ISOLATED_GATE
# Reutiliza contenedores PG17 efímeros, SQLite in-memory y Flutter SDK Docker.
# El gate existente ejecuta todas las pruebas reminders, flutter test/build, l10n
# y salud DEV sin alterar ninguna base persistente.
bash scripts/validate_o7_o8_preflight.sh
PHASE=COMPLETE
echo "MACRO_B_GATE_INTEGRAL=OK"
