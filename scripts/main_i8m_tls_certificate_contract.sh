#!/usr/bin/env bash
# I8-M: offline X.509 fixture contract only. NO TLS server, API, Docker or DB.
set -Eeuo pipefail
umask 077
for cmd in openssl mktemp grep; do command -v "$cmd" >/dev/null || exit 2; done
tmp="$(mktemp -d /tmp/vencira-i8m-cert.XXXXXXXX)"
chmod 700 "$tmp"
cleanup() {
  local status=$?
  trap - EXIT
  rm -f -- "$tmp/verified.pem" "$tmp/verified.key" \
    "$tmp/untrusted.pem" "$tmp/untrusted.key"
  rmdir "$tmp" || true
  echo "MAIN_I8M_TLS_CERT_CONTRACT_RESULT=$status"
  echo "MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED"
  echo "MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$status"
}
trap cleanup EXIT

openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 1 \
  -keyout "$tmp/verified.key" -out "$tmp/verified.pem" \
  -subj '/CN=native-i8k.test' \
  -addext 'subjectAltName=DNS:native-i8k.test' \
  >/dev/null 2>&1
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 1 \
  -keyout "$tmp/untrusted.key" -out "$tmp/untrusted.pem" \
  -subj '/CN=untrusted-i8m.invalid' \
  -addext 'subjectAltName=DNS:untrusted-i8m.invalid' \
  >/dev/null 2>&1
chmod 600 "$tmp/"*.key
test "$(stat -c '%a' "$tmp/verified.key")" = 600
echo "MAIN_I8M_EPHEMERAL_PRIVATE_KEY_MODE=PASS"

openssl x509 -in "$tmp/verified.pem" -noout -ext subjectAltName \
  | grep -Fq 'DNS:native-i8k.test'
echo "MAIN_I8M_CERTIFICATE_SAN=PASS"

openssl verify -CAfile "$tmp/verified.pem" \
  -verify_hostname native-i8k.test "$tmp/verified.pem" >/dev/null
echo "MAIN_I8M_CERTIFICATE_TRUSTED_HOST=PASS"

if openssl verify -CAfile "$tmp/verified.pem" \
  -verify_hostname wrong-i8k-host.invalid "$tmp/verified.pem" \
  >/dev/null 2>&1; then
  echo "MAIN_I8M_CERTIFICATE_WRONG_HOST=UNEXPECTED_ACCEPT" >&2
  exit 4
fi
echo "MAIN_I8M_CERTIFICATE_WRONG_HOST=DENIED"

if openssl verify -CAfile "$tmp/untrusted.pem" \
  -verify_hostname native-i8k.test "$tmp/verified.pem" \
  >/dev/null 2>&1; then
  echo "MAIN_I8M_CERTIFICATE_WRONG_CA=UNEXPECTED_ACCEPT" >&2
  exit 5
fi
echo "MAIN_I8M_CERTIFICATE_WRONG_CA=DENIED"
echo "MAIN_I8M_TLS_CERT_CONTRACT=PASS"
