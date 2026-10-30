#!/usr/bin/env bash
# MB1 interruption-contract tests; Docker image + SQLite disposable tests only.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
img="vencira-mb1-failure:$(git rev-parse --short=12 HEAD)"
echo "MB1_FAILURE_COMMIT=$(git rev-parse HEAD)"
docker build -q -t "$img" ./backend >/dev/null
docker run --rm --network none \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_SECRET_KEY=synthetic-mb1-failure-contract-secret \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 "$img" python manage.py test reminders.test_mb1_intake_failure_contract --noinput --verbosity 1
echo "MB1_INTENT_OBJECT_METADATA_FAILURE_CONTRACT=OK"
echo "MB1_ORPHAN_INTENT_RECONCILIATION=REQUIRED"
echo "MB1_FAILED_CLEANUP_RECONCILIATION=REQUIRED"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
