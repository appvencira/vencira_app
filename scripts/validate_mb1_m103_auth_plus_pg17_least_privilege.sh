#!/usr/bin/env bash
# M1-03: grouped NEW HBA/API identity audit + isolated PG17 least-privilege.
# Do not rerun prior Docker writer censuses or old PG17 recovery gates.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
finish() {
  rc=$?
  trap - EXIT
  echo "MB1_M103_AUTH_LP_PHASE=$PHASE"
  echo "MB1_M103_AUTH_LP_RESULT=$rc"
  echo "MB1_M103_OPERATIONAL_ROLE_MIGRATION=NOT_AUTHORIZED"
  echo "MB1_M103_WRITER_EXCLUSION=NOT_VERIFIED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
[ "$(printenv MB1_M103_AUTH_LP_GROUP || true)" = YES ] || {
  echo "MB1_M103_AUTH_LP_OPT_IN=REQUIRED"; exit 2;
}
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
git diff --quiet
git diff --cached --quiet
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
bash -n scripts/validate_mb1_m103_hba_identity_focused.sh
bash -n scripts/rehearse_mb1_m103_pg17_least_privilege_disposable.sh
echo "MB1_M103_AUTH_LP_SOURCE_PREFLIGHT=OK"

PHASE=HBA_DETAIL
bash scripts/validate_mb1_m103_hba_identity_focused.sh
echo "MB1_M103_AUTH_LP_HBA_AND_RUNTIME_IDENTITY=OK"

PHASE=PG17_LAB
MB1_M103_LP_DISPOSABLE=YES bash scripts/rehearse_mb1_m103_pg17_least_privilege_disposable.sh
echo "MB1_M103_AUTH_LP_DISPOSABLE_LP_POSTGRES=OK"
PHASE=DONE
echo "MB1_M103_AUTH_LP_GROUP_DONE=OK"
