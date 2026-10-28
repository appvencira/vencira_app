#!/usr/bin/env bash
# C-FICHA migration split: dry-run graph proof ONLY, never migrate anything.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
IMAGE="vencira-c-ficha-split:$(git rev-parse --short=12 HEAD)"
sudo docker build -q -t "$IMAGE" ./backend >/dev/null
sudo docker run --rm --network none \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
  -e DJANGO_SECRET_KEY=synthetic-split-only-not-a-real-secret-2026 \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  "$IMAGE" python manage.py shell -c '
from django.conf import settings
from django.test.utils import override_settings
from django.db.migrations.loader import MigrationLoader
with override_settings(INSTALLED_APPS=[*settings.INSTALLED_APPS, "renewal_attachments"]):
    loader=MigrationLoader(None)
    path=set(loader.graph.forwards_plan(("renewal_attachments","0001_initial")))
    assert ("reminders","0018_draft_reasons") in path, path
    assert all(not (app=="reminders" and name[:4] in {
        "0019","0020","0021","0022","0023","0024","0025","0026","0027"
    }) for app,name in path), path
    print("ATTACHMENTS_INDEPENDENT_GRAPH=OK")
    print("MFA_MIGRATIONS_EXCLUDED_FROM_TARGET_PLAN=OK")
    print("NO_MIGRATION_EXECUTED=1")
'
echo "RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
