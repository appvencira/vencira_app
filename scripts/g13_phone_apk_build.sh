#!/usr/bin/env bash
# Called only inside G13 Flutter+Android SDK container. Never builds release.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || exit 2
command -v python3 >/dev/null || exit 2
test "${VENCIRA_G13_LAB_BUILD:-}" = 1

python3 - <<'PY'
import base64, os, ssl
encoded = os.environ.get("G13_LAB_PUBLIC_CA_BASE64", "")
assert 128 < len(encoded) < 25000, "G13_PUBLIC_CA_REQUIRED"
pem = base64.b64decode(encoded, validate=True).decode("ascii")
assert pem.count("-----BEGIN CERTIFICATE-----") == 1
assert pem.count("-----END CERTIFICATE-----") == 1
assert "PRIVATE KEY" not in pem
assert len(ssl.PEM_cert_to_DER_cert(pem)) > 128
print("G13_PUBLIC_ONLY_CA_VALIDATED=OK")
PY

python3 scripts/n1_static_security_gate.py
bash -n scripts/g13_phone_apk_build.sh

cd clients/flutter
flutter pub get
flutter analyze lib/g13_lab_main.dart lib/g13_lab/physical_https_checks.dart
echo "G13_ANDROID_FLUTTER_ANALYZE=OK"

flutter build apk --debug \
  --target=lib/g13_lab_main.dart \
  --dart-define=VENCIRA_G13_LAB_BUILD=true \
  --dart-define=G13_LAB_PUBLIC_CA_BASE64="$G13_LAB_PUBLIC_CA_BASE64" \
  --no-pub

apk="build/app/outputs/flutter-apk/app-debug.apk"
test -s "$apk"

aapt_bin="$(command -v aapt || true)"
if [[ -z "$aapt_bin" ]]; then
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "$sdk" && -d "$sdk/build-tools" ]]; then
    aapt_bin="$(find "$sdk/build-tools" -type f -name aapt | sort -V | tail -n 1)"
  fi
fi
test -n "$aapt_bin" && test -x "$aapt_bin" || {
  echo "G13_ANDROID_AAPT_REQUIRED" >&2
  exit 1
}
package="$("$aapt_bin" dump badging "$apk" |
    sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n 1)"
if [[ "$package" != "es.vencira.vencira.g13lab" ]]; then
  echo "G13_ANDROID_UNEXPECTED_PACKAGE" >&2
  exit 1
fi

mkdir -p build/g13-phone
cp -- "$apk" build/g13-phone/VENCIRA-G13-LAB-debug.apk
(cd build/g13-phone && sha256sum VENCIRA-G13-LAB-debug.apk \
  > VENCIRA-G13-LAB-debug.apk.sha256)

echo "G13_ANDROID_APK_PACKAGE=es.vencira.vencira.g13lab"
echo "G13_ANDROID_APK_BUILD=OK"
echo "G13_ANDROID_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
