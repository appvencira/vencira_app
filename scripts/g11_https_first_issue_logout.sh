#!/usr/bin/env bash
# G11 only. Verified TLS via G7's existing internal Docker/SQLite tmpfs
# fixture, with completely new test scenarios and no operational routing.
set -euo pipefail
cd "$(dirname "$0")/.."

end() {
  local status=$?
  trap - EXIT
  echo "G11_HTTPS_GATE_RESULT=$status"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$status"
}
trap end EXIT

python3 scripts/n1_static_security_gate.py
bash -n scripts/g11_https_first_issue_logout.sh

PUB_VOLUME="vencira-g7-public-dart-pub-v1"
sudo docker volume create "$PUB_VOLUME" >/dev/null

# Analyzer gets public dependency cache; neither production auth nor secrets.
sudo docker run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$PUB_VOLUME:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c '
    set -e
    flutter pub get --offline || flutter pub get
    flutter analyze tool/g11_https_scenarios.dart tool/g7_d2_https_probe.dart
  '

echo "G11_HTTPS_FLUTTER_ANALYZE=OK"

# This runs ONLY group g11, not D2/E/F/G/H. The unchanged Docker
# isolation primitives enforce private-only bridge, disposable SQLite,
# CA verification and no published ports.
bash scripts/g7_d2_https_flutter_django.sh --group g11

echo "G11_HTTPS_FIRST_ISSUANCE_LOGOUT=OK"
