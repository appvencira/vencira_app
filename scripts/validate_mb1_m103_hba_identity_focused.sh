#!/usr/bin/env bash
# M1-03 focused second-pass HBA/auth identity audit: no previous census reruns.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
finish() {
  rc=$?
  trap - EXIT
  echo "MB1_M103_DETAIL_PHASE=$PHASE"
  echo "MB1_M103_DETAIL_RESULT=$rc"
  echo "MB1_M103_WRITER_EXCLUSION=NOT_VERIFIED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
git diff --quiet
git diff --cached --quiet
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
python3 -m py_compile scripts/audit_mb1_m103_hba_and_app_identity_readonly.py \
  scripts/test_mb1_m103_hba_and_app_identity_readonly.py
echo "MB1_M103_DETAIL_SOURCE=OK"
PHASE=PURE_TESTS
python3 -m unittest -q scripts.test_mb1_m103_hba_and_app_identity_readonly
echo "MB1_M103_DETAIL_TESTS=OK"
PHASE=HBA_AND_API_IDENTITY
sudo env MB1_M103_HBA_DETAIL_READONLY=YES \
  python3 scripts/audit_mb1_m103_hba_and_app_identity_readonly.py
echo "MB1_M103_DETAIL_HBA_API_IDENTITY=OK"
PHASE=DONE
echo "MB1_M103_DETAIL_DONE=OK"
