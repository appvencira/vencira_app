#!/usr/bin/env bash
# M1-03: ONE new-only grouped gate, not repeating prior 11 HBA or PG SQL tests.
# Hosts: read-only HBA CIDR scope. Lab: fresh PG17 Django restricted ORM.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
finish() {
  rc=$?
  trap - EXIT
  echo "MB1_M103_SCOPE_ORM_PHASE=$PHASE"
  echo "MB1_M103_SCOPE_ORM_RESULT=$rc"
  echo "MB1_M103_ROLE_SEPARATION_IN_DEV=NOT_AUTHORIZED"
  echo "MB1_M103_FULL_WRITER_CENSUS=NOT_CLOSED"
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
bash -n scripts/rehearse_mb1_m103_real_django_limited_pg17.sh
python3 -m py_compile \
  scripts/audit_mb1_m103_host_trust_scope_readonly.py \
  scripts/test_mb1_m103_host_trust_scope_readonly.py \
  backend/reminders/offline_mb1_m103_limited_orm_lab.py
echo "MB1_M103_SCOPE_ORM_PREFLIGHT=OK"

PHASE=PURE_TESTS
python3 -m unittest -q scripts.test_mb1_m103_host_trust_scope_readonly
echo "MB1_M103_SCOPE_PURE_TESTS=OK"

PHASE=HBA_SCOPE
sudo env MB1_M103_HOST_TRUST_SCOPE=YES \
 python3 scripts/audit_mb1_m103_host_trust_scope_readonly.py
echo "MB1_M103_LIVE_HOST_TRUST_SCOPE_READONLY=OK"

PHASE=DJANGO_LAB
MB1_M103_DJANGO_PG17_LAB=YES \
 bash scripts/rehearse_mb1_m103_real_django_limited_pg17.sh
echo "MB1_M103_DJANGO_NONADMIN_ORM_REHEARSAL=OK"
PHASE=DONE
echo "MB1_M103_SCOPE_ORM_DONE=OK"
