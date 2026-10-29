#!/usr/bin/env bash
# B18E synthetic validation only; no PostgreSQL, networks, keys or live services.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
echo "B18E_COMMIT=$(git rev-parse HEAD)"
image="vencira-b18e-synthetic:$(git rev-parse --short=12 HEAD)"
sudo docker build -t "$image" ./backend >/dev/null
sudo docker run --rm --network none \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
  -e DJANGO_SECRET_KEY=synthetic-b18e-test-only-2026-long \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  "$image" python manage.py test renewal_attachments.test_capture_set_b18e \
  --noinput --verbosity 2
echo "B18E_SYNTHETIC_CONTRACTS=OK"
echo "B18E_CAPTURE_LOCK=NOT_IMPLEMENTED"
echo "B18E_OPERATIONAL_RELEASE=NO"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "B18E_RESULT=0"
