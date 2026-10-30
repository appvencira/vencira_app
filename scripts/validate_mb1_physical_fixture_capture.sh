#!/usr/bin/env bash
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
image="vencira-mb1-physical:$(git rev-parse --short=12 HEAD)"
echo "MB1_PHYSICAL_COMMIT=$(git rev-parse HEAD)"
sudo docker build -t "$image" ./backend >/dev/null
sudo docker run --rm --network none \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_SECRET_KEY=synthetic-mb1-physical-only-long-secret \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 "$image" python manage.py test renewal_attachments.test_synthetic_file_capture_mb1 --noinput --verbosity 1
echo "MB1_PHYSICAL_FIXTURE_CAPTURE=OK"
echo "MB1_REAL_PG17_CAPTURE=NOT_RUN"
echo "MB1_NONCOOPERATIVE_WRITER_EXCLUSION=NOT_VERIFIED"
echo "MB1_INDEPENDENT_RESTORE=NOT_RUN"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "MB1_PHYSICAL_RESULT=0"
