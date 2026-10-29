#!/usr/bin/env bash
# VENCIRA macroblock 1: synthetic recovery contract regression, not production DR.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
phase=PREFLIGHT
fail(){ echo "MB1_FAILED_PHASE=$phase"; echo "MB1_RELEASE_AUTHORIZED=NO"; echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"; exit 1; }
trap fail ERR
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
echo "MB1_COMMIT=$(git rev-parse HEAD)"
phase=BUILD
image="vencira-mb1-synthetic:$(git rev-parse --short=12 HEAD)"
# Docker build uses local repo, no live DB, no mounted secrets, no published ports.
sudo docker build -t "$image" ./backend >/dev/null
phase=RECOVERY_CONTRACTS
# This selection deliberately excludes the separate ClamAV and multi-container
# B17 network harnesses; a PASS is not a full application test.
sudo docker run --rm --network none \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
  -e DJANGO_SECRET_KEY=synthetic-mb1-test-only-2026-long \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  "$image" python manage.py test \
    renewal_attachments.test_backup_manifest_b09 \
    renewal_attachments.test_verified_restore_b09 \
    renewal_attachments.test_capture_fence_b06a \
    renewal_attachments.test_d3_double_failure \
    --noinput --verbosity 1
echo "MB1_SYNTHETIC_BACKUP_MANIFEST=TESTED"
echo "MB1_SYNTHETIC_DB_OBJECT_JOURNAL_RECOVERY=TESTED"
echo "MB1_CAPTURE_FENCE_AND_DOUBLE_FAILURE=TESTED"
echo "MB1_OPERATIONAL_WRITER_FREEZE=NOT_VERIFIED"
echo "MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED"
echo "MB1_FULL_RECOVERY_DRILL=NOT_RUN"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "MB1_RESULT=0"
