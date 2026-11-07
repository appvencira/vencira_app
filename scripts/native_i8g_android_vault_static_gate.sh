#!/usr/bin/env bash
# I8-G preflight only: Flutter vault contract + Android instrumentation syntax.
# Does NOT claim a physical Android Keystore test. No Django/DB/deploy.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v docker >/dev/null || exit 2
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
declare -A before
for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$s")" = vencira_localcheck || exit 3
  before[$s]="$(D inspect -f '{{.Id}}:{{.Image}}' "$s")"
done
cleanup() {
  local rc=$?
  trap - EXIT
  local unchanged=YES
  for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$s" 2>/dev/null || true)" != "${before[$s]}" ]]; then
      unchanged=NO
      rc=9
    fi
  done
  echo "NATIVE_I8G_DEV_CONTAINERS_UNCHANGED=$unchanged"
  echo "NATIVE_I8G_PHYSICAL_ANDROID_EXECUTED=NO"
  echo "NATIVE_I8G_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8G_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8G_LOCAL_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT

# Only Dart static analysis + existing fake-storage regression suites.
PUB_VOLUME="vencira-g7-public-dart-pub-v1"
D volume create "$PUB_VOLUME" >/dev/null
D run --rm \
  -v "$ROOT/clients/flutter:/work" -w /work \
  -v "$PUB_VOLUME:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  sh -ec '
    flutter pub get --offline || flutter pub get
    flutter analyze integration_test/native_i8g_android_secure_storage_test.dart lib/api/native_refresh_credential_vault.dart
    echo NATIVE_I8G_DART_ANALYZE=OK
    flutter test --no-pub test/native_refresh_credential_vault_test.dart test/native_http_auth_port_test.dart
    echo NATIVE_I8G_VAULT_CONTRACT_TESTS=PASS
  '
echo "NATIVE_I8G_STATIC_GATE=PASS"
