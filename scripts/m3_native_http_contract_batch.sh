#!/usr/bin/env bash
# VENCIRA M3: test-only native HTTP + Flutter adapter contract (never deploy).
# Uses isolated PG17 tmpfs Docker network and mock HTTP; no production routes.
set -uo pipefail

cd "$(dirname "$0")/.."
OUT="$HOME/vencira-m3-results/m3-http-contract-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
DOCKER=(sudo docker)
declare -A RESULT

step() {
  local name="$1"
  shift
  echo "=== $name ==="
  "$@" > "$OUT/$name.log" 2>&1
  RESULT["$name"]=$?
  tail -n 14 "$OUT/$name.log"
  echo "M3_HTTP_${name}=${RESULT[$name]}"
}

step STATIC python3 scripts/n1_static_security_gate.py
step BUILD "${DOCKER[@]}" build -t vencira-m3-backend-test ./backend

if [ "${RESULT[BUILD]}" -eq 0 ]; then
  step PG17_LAB bash scripts/n1_identity_pg17_ephemeral.sh --lab
  step G4_PG17 bash scripts/n1_identity_pg17_ephemeral.sh --candidate
else
  RESULT[G4_PG17]=99
  echo "M3_HTTP_G4_PG17=99"
  RESULT[PG17_LAB]=99
  echo "M3_HTTP_PG17_LAB=99"
fi

step FLUTTER "${DOCKER[@]}" run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  ghcr.io/cirruslabs/flutter:stable sh -c \
  'flutter pub get && flutter analyze && flutter test test/native_recovery_login_gateway_test.dart test/native_refresh_recovery_journal_test.dart test/native_workspace_read_port_test.dart test/native_http_auth_port_test.dart test/native_session_coordinator_test.dart test/native_login_screen_test.dart test/native_refresh_credential_vault_test.dart test/native_api_transport_test.dart'

echo "=== M3 HTTP CONTRACT FINAL SUMMARY ==="
failed=0
for name in STATIC BUILD PG17_LAB G4_PG17 FLUTTER; do
  code="${RESULT[$name]:-99}"
  echo "M3_HTTP_$name=$code"
  if [ "$code" -ne 0 ]; then failed=1; fi
done
echo "M3_HTTP_LOGS=$OUT"
echo "M3_HTTP_RESULT=$failed"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
exit "$failed"
