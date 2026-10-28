#!/usr/bin/env bash
# Only invokes the read-only guard; never any historical deployment entrypoint.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
tmp="$(mktemp -d /tmp/vencira-mfa-legacy-negative.XXXXXXXX)"
trap 'rm -rf -- "$tmp"' EXIT
for mode in api schema; do
  set +e
  output="$(bash scripts/mfa_legacy_deploy_guard_readonly.sh "$mode" 2>&1)"
  rc=$?
  set -e
  test "$rc" -eq 4
  grep -Fq 'REASON=LEGACY_API_OR_SCHEMA_DEPLOY_DISABLED' <<< "$output"
done
echo "MFA_LEGACY_API_SCHEMA_NEGATIVE=OK"
# Fake sudo makes sure web preflight cannot contact the real Docker socket.
cat > "$tmp/sudo" <<'EOF'
#!/usr/bin/env sh
exit 90
EOF
chmod 700 "$tmp/sudo"
set +e
output="$(PATH="$tmp:$PATH" bash scripts/mfa_legacy_deploy_guard_readonly.sh web 2>&1)"
rc=$?
set -e
test "$rc" -eq 4
grep -Fq 'REASON=LIVE_DB_UNKNOWN' <<< "$output"
echo "MFA_LEGACY_WEB_FAIL_CLOSED_NO_DOCKER=OK"
echo "MFA_NEGATIVE_TEST_RESULT=0"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
