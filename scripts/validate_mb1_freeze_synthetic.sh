#!/usr/bin/env bash
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
image="vencira-mb1-freeze:$(git rev-parse --short=12 HEAD)"
echo "MB1_FREEZE_COMMIT=$(git rev-parse HEAD)"
sudo docker build -t "$image" ./backend >/dev/null
sudo docker run --rm --network none \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_SECRET_KEY=synthetic-mb1-freeze-long-secret-only \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 "$image" python manage.py test renewal_attachments.test_freeze_mb1 --noinput --verbosity 1
echo "MB1_FREEZE_INPROCESS_TESTS=OK"
echo "MB1_FREEZE_CROSS_PROCESS=NOT_IMPLEMENTED"
echo "MB1_FREEZE_FILESYSTEM=NOT_ENFORCED"
echo "MB1_FULL_RESTORE=NOT_RUN"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "MB1_FREEZE_RESULT=0"
