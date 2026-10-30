#!/usr/bin/env bash
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
image="vencira-b18l-synthetic:$(git rev-parse --short=12 HEAD)"
echo "B18L_COMMIT=$(git rev-parse HEAD)"
sudo docker build -t "$image" ./backend >/dev/null
sudo docker run --rm --network none \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
  -e DJANGO_SECRET_KEY=synthetic-b18l-only-not-production-secret \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  "$image" python manage.py test renewal_attachments.test_pending_intent_reconcile_b18l --noinput --verbosity 1
echo "B18L_PENDING_INTENT_CONTRACTS=OK"
echo "B18L_LIVE_RECONCILIATION=NOT_IMPLEMENTED"
echo "B18L_GLOBAL_CAPTURE=BLOCKED"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "B18L_RESULT=0"
