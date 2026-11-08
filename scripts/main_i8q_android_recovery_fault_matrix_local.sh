#!/usr/bin/env bash
# I8-Q: consolidated fail-closed Flutter regression suite (pure test,
# no real HTTP, no mobile operations, no database writes or deployment).
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v docker >/dev/null || exit 2
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" == vencira_localcheck ]] || exit 3
  [[ "$(D inspect -f '{{.State.Health.Status}}' "$name")" == healthy ]] || exit 3
done
declare -A original
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  original["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
cleanup() {
  local rc=$?
  trap - EXIT
  local intact=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${original[$name]}" ]]; then intact=NO; fi
  done
  echo "I8Q_DEV_CONTAINERS_UNCHANGED=$([[ "$intact" == YES ]] && echo OK || echo FAIL)"
  if [[ "$intact" != YES ]]; then rc=9; fi
  echo 'I8Q_DEPLOY_EXECUTED=NO'
  echo 'I8Q_LIVE_MIGRATIONS_EXECUTED=NO'
  echo 'MFA_RELEASE_AUTHORIZED=NO'
  echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
  echo "I8Q_LOCAL_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT
D run --rm \
  -v "$root/clients/flutter:/source:ro" \
  ghcr.io/cirruslabs/flutter:3.44.0 \
  sh -euc '
    cp -a /source /tmp/vencira-i8q-flutter
    cd /tmp/vencira-i8q-flutter
    flutter pub get
    flutter analyze test/native_i8q_recovery_fault_matrix_test.dart
    flutter test --reporter expanded \
      test/native_i8q_recovery_fault_matrix_test.dart \
      test/native_i8l_http_recovery_integration_test.dart \
      test/native_http_auth_port_test.dart \
      test/native_api_endpoint_test.dart
  '
echo 'I8Q_FLUTTER_FAULT_MATRIX_GATE=PASS'
