#!/usr/bin/env bash
# MB1 M1-02 grouped failure-domain checks, once. Synthetic Docker only.
# Existing real-PG17 external SIGKILL PASS is kept as historical evidence,
# not re-run. No service changes, no attached DEV volume, no network.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
IMAGE=""
finish() {
  rc=$?
  trap - EXIT
  if [ -n "$IMAGE" ]; then
    sudo docker image rm "$IMAGE" >/dev/null 2>&1 || true
  fi
  echo "MB1_M102_GROUP_PHASE=$PHASE"
  echo "MB1_M102_GROUP_RESULT=$rc"
  echo "MB1_M102_ACTUAL_POWERLOSS=NOT_VERIFIED"
  echo "MB1_M102_AMBIGUOUS_COMMIT_RECOVERY=NOT_VERIFIED"
  echo "MB1_M102_OPERATIONAL_RECONCILIATION=NOT_IMPLEMENTED"
  echo "MB1_M106_EXTERNAL_CUSTODY=NOT_VERIFIED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
if [ "$(printenv MB1_M102_GROUPED_LAB || true)" != YES ]; then
  echo "MB1_M102_EXPLICIT_OPT_IN=REQUIRED"
  exit 2
fi
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
# Never use untracked or modified code under sudo.
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
for testfile in \
  backend/reminders/test_mb1_intake_failure_contract.py \
  backend/renewal_attachments/test_pending_intent_reconcile_b18l.py \
  backend/renewal_attachments/test_mb1_partial_io_failclosed.py; do
  test -f "$testfile"
done
python3 -m py_compile backend/renewal_attachments/test_mb1_partial_io_failclosed.py
echo "MB1_M102_GROUP_SOURCE_PREFLIGHT=OK"

PHASE=BUILD
IMAGE="vencira-mb1-m102:$(git rev-parse --short=12 HEAD)"
# Build local source only. Do not bind/mount any DEV storage.
sudo docker build -q -t "$IMAGE" ./backend >/dev/null
echo "MB1_M102_GROUP_IMAGE_BUILD=OK"

PHASE=TEST_ALL
sudo docker run --rm --network none \
  -e VENCIRA_ENV=test \
  -e VENCIRA_DB_ENGINE=sqlite \
  -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
  -e DJANGO_SECRET_KEY=synthetic-mb1-m102-only-key-not-operational \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  "$IMAGE" python manage.py test \
    reminders.test_mb1_intake_failure_contract \
    renewal_attachments.test_pending_intent_reconcile_b18l \
    renewal_attachments.test_mb1_partial_io_failclosed \
    --noinput --verbosity 1
echo "MB1_M102_GROUP_INTAKE_CONTRACTS=OK"
echo "MB1_M102_GROUP_READONLY_RECONCILIATION=OK"
echo "MB1_M102_GROUP_PARTIAL_IO_FAIL_CLOSED=OK"
echo "MB1_M102_GROUP_NO_AUTOMATIC_DELETE_OR_PUBLISH=OK"
PHASE=DONE
echo "MB1_M102_GROUP_DONE=OK"
