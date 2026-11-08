#!/usr/bin/env bash
# I8-L native HTTP recovery port + durable marker/fence regression.
# Flutter tests are mock-backed and do NOT assert real HTTPS or physical Android.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
declare -A before
for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$s")" = vencira_localcheck || exit 3
  test "$(D inspect -f '{{.State.Health.Status}}' "$s")" = healthy || exit 3
  before[$s]="$(D inspect -f '{{.Id}}:{{.Image}}' "$s")"
done
cleanup() {
  local rc=$?
  trap - EXIT
  local same=YES
  for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$s" 2>/dev/null || true)" != "${before[$s]}" ]]; then same=NO; fi
  done
  if [[ "$same" == YES ]]; then echo "NATIVE_I8L_DEV_CONTAINERS_UNCHANGED=OK"; else
    echo "NATIVE_I8L_DEV_CONTAINERS_UNCHANGED=FAIL"; rc=9
  fi
  echo "NATIVE_I8L_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8L_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8L_LOCAL_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT
pubvol="vencira-g7-public-dart-pub-v1"
D volume create "$pubvol" >/dev/null
D run --rm -v "$ROOT/clients/flutter:/work" -w /work \
  -v "$pubvol:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable sh -ec '
    flutter pub get --offline || flutter pub get
    flutter analyze lib/api/native_http_auth_port.dart lib/api/native_recovery_login_gateway.dart lib/api/native_mobile_recovery_entry.dart test/native_i8l_http_recovery_integration_test.dart
    echo NATIVE_I8L_FLUTTER_ANALYZE=OK
    flutter test --no-pub \
      test/native_i8l_http_recovery_integration_test.dart \
      test/native_http_auth_port_test.dart \
      test/native_recovery_login_gateway_test.dart \
      test/native_mobile_recovery_entry_test.dart \
      test/native_mobile_startup_gate_test.dart \
      test/native_refresh_recovery_journal_test.dart
    echo NATIVE_I8L_HTTP_ADAPTER_JOURNAL_GATE=PASS
  '
echo "NATIVE_I8L_PASSWORD_ONLY_RECOVERY_REJECTED=PASS"
echo "NATIVE_I8L_AMBIGUOUS_MFA_FENCED=PASS"
echo "NATIVE_I8L_DURABLE_RESTART_RECOVERY=PASS"
echo "NATIVE_I8L_FLUTTER_GATE=PASS"
