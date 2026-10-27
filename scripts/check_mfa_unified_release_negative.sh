#!/usr/bin/env bash
# No docker, network, database, deployment or operational secrets.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
sha="$(git rev-parse HEAD)"
for stage in schema-off mfa-enable rollback; do
  set +e
  output="$(bash scripts/mfa_release_entrypoint.sh "$stage" "$sha" 2>&1)"
  rc=$?
  set -e
  test "$rc" -eq 4
  grep -Fxq "MFA_RELEASE_STAGE=$stage" <<< "$output"
  grep -Fxq "REASON=OPERATIONAL_AUTHORIZATION_REQUIRED" <<< "$output"
  grep -Fxq "MFA_RELEASE_AUTHORIZED=NO" <<< "$output"
done
echo "MFA_UNIFIED_THREE_STAGES_FAIL_CLOSED=OK"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
