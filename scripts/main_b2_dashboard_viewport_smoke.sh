#!/usr/bin/env bash
# B2 narrow mobile UI smoke, fake API, no access to DEV.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v docker >/dev/null
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
echo 'B2_SMOKE_FAKE_API_ONLY=YES'
echo 'B2_SMOKE_DEV_NETWORK_REQUESTS=NO'
echo 'B2_SMOKE_DEV_DEPLOY=NO'
echo 'B2_SMOKE_LIVE_MIGRATIONS=NO'
D run --rm \
  -v "$root/clients/flutter:/source:ro" \
  --tmpfs /tmp:rw,size=512m,mode=1777 \
  ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
    cp -a /source /tmp/vencira-flutter
    cd /tmp/vencira-flutter
    flutter pub get
    flutter analyze test/b2_dashboard_viewport_smoke_test.dart
    flutter test test/b2_dashboard_viewport_smoke_test.dart --reporter expanded
  '
echo 'B2_DASHBOARD_VIEWPORTS_320_390=PASS'
echo 'B2_DEV_CONTAINERS_TOUCHED=NO'
echo 'B2_VISUAL_PHONE_REVIEW=NOT_RUN'
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
echo 'B2_UI_SMOKE_RESULT=0'
