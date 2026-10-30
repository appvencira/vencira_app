#!/usr/bin/env bash
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
img="vencira-mb1-classifier:$(git rev-parse --short=12 HEAD)"
sudo docker build -q -t "$img" ./backend >/dev/null
sudo docker run --rm --network none \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_SECRET_KEY=synthetic-mb1-classifier-only-long-secret-20261030 \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 "$img" python manage.py test renewal_attachments.test_recovery_classifier_mb1 --noinput --verbosity 1
echo "MB1_READONLY_CLASSIFIER_TESTS=OK"
echo "MB1_CLASSIFIER_AUTOMATIC_REPAIR=DISABLED"
echo "MB1_CLASSIFIER_LIVE_INVENTORY=NOT_CONNECTED"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
