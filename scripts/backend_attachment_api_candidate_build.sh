#!/usr/bin/env bash
# Build an API candidate from the exact old DEV backend tree + independent
# attachment metadata route. This NEVER deploys or migrates the live DB.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BASE=/home/vencira/vencira-localcheck
API=vencira_localcheck-api-1
DB=vencira_localcheck-db-1
WEB=vencira_localcheck-web_preview-1
EXPECTED_API=sha256:6bb813f527410957b534da61ac8e4120813ba64c2b7f11b98122a231001a8ac5
DOCKER=(docker)
if [[ "$(id -u)" -ne 0 ]]; then sudo -v; DOCKER=(sudo docker); fi
for cmd in git python3 tar; do command -v "$cmd" >/dev/null || exit 2; done
test -d "$BASE/.git" || { echo "ATT_API_CANDIDATE_BASE_MISSING"; exit 2; }
test -z "$(git -C "$BASE" status --porcelain --untracked-files=no)" || {
  echo "ATT_API_CANDIDATE_BASE_DIRTY=DENIED"; exit 2; }
test -z "$(git status --porcelain --untracked-files=no -- backend/renewal_attachments backend/reminders/attachment_api.py backend/reminders/attachment_gate.py backend/reminders/attachment_model_router.py)" || {
  echo "ATT_API_CANDIDATE_SOURCE_DIRTY=DENIED"; exit 2; }
declare -A BEFORE
for name in "$API" "$DB" "$WEB"; do
  test "$("${DOCKER[@]}" inspect -f '{{.State.Health.Status}}' "$name")" = healthy || exit 3
  test "$("${DOCKER[@]}" inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" = vencira_localcheck || exit 3
  BEFORE[$name]="$("${DOCKER[@]}" inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
test "$("${DOCKER[@]}" inspect -f '{{.Image}}' "$API")" = "$EXPECTED_API" || {
  echo "ATT_API_CANDIDATE_LIVE_API_CHANGED=DENIED"; exit 3; }
# Prevent transplanting schema code onto an incompatible historical 0018.
BASE_0018="$(git -C "$BASE" show HEAD:backend/reminders/migrations/0018_draft_reasons.py | sha256sum | cut -d' ' -f1)"
SOURCE_0018="$(git show HEAD:backend/reminders/migrations/0018_draft_reasons.py | sha256sum | cut -d' ' -f1)"
test "$BASE_0018" = "$SOURCE_0018" || {
  echo "ATT_API_CANDIDATE_BASE_0018_MISMATCH=DENIED"; exit 4; }
SOURCE_SHA="$(git rev-parse HEAD)"
BASE_SHA="$(git -C "$BASE" rev-parse HEAD)"
TAG="vencira-attachment-api-candidate:${SOURCE_SHA:0:12}"
echo "ATT_API_CANDIDATE_BASE_SHA=$BASE_SHA"
echo "ATT_API_CANDIDATE_SOURCE_SHA=$SOURCE_SHA"
echo "ATT_API_CANDIDATE_BASE_0018=IDENTICAL"
WORK="$(mktemp -d /tmp/vencira-attachment-candidate.XXXXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"
git -C "$BASE" archive HEAD backend | tar -xf - -C "$WORK"
git archive HEAD backend/renewal_attachments backend/reminders/attachment_api.py backend/reminders/attachment_gate.py | tar -xf - -C "$WORK"
# The build must contain exactly the historical reminders migration chain
# through 0018, plus independent renewal_attachments migrations.
python3 - "$WORK/backend" <<'PY'
from pathlib import Path
import re
import sys
base = Path(sys.argv[1])
rem = base / "reminders/migrations"
entries = sorted(p.stem for p in rem.glob("[0-9][0-9][0-9][0-9]_*.py"))
assert entries and entries[-1] == "0018_draft_reasons", entries[-3:]
assert len(entries) == 18, entries
settings = base / "config/settings.py"
src = settings.read_text()
assert 'renewal_attachments' not in src, "Old base unexpectedly already uses independent app"
src += '\n# DEV attachment metadata candidate only; from verified 0018 backend.\n'
src += 'INSTALLED_APPS.append("renewal_attachments")\n'
settings.write_text(src)
router = base / "reminders/attachment_model_router.py"
router.write_text(
    '"""Candidate-only fixed resolver: independent metadata model."""\n'
    'from django.apps import apps\n'
    'def attachment_model():\n'
    '    return apps.get_model("renewal_attachments", "RenewalAttachment")\n'
)
urls = base / "reminders/urls.py"
u = urls.read_text()
assert 'renewal_attachments' not in u and 'renewal_attachment_detail' not in u
needle = 'urlpatterns = ['
assert u.count(needle) == 1
u = ('from .attachment_api import renewal_attachments, renewal_attachment_detail\n'
     + u.replace(needle, needle + '''
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/attachments/",
         renewal_attachments, name="api-renewal-attachments"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/attachments/<uuid:attachment_id>/",
         renewal_attachment_detail, name="api-renewal-attachment-detail"),
''', 1))
urls.write_text(u)
assert not any(p.name.startswith(("0019_", "0027_")) for p in rem.iterdir())
print("ATT_API_CANDIDATE_HISTORICAL_MIGRATIONS=0018_ONLY")
print("ATT_API_CANDIDATE_ATTACHMENT_APP=ISOLATED")
print("ATT_API_CANDIDATE_ATTACHMENT_ENDPOINTS=METADATA_ONLY")
PY
# Build with the historic Dockerfile and dependency graph. No live containers.
"${DOCKER[@]}" build --pull=false \
  --label "es.vencira.attachment.base=$BASE_SHA" \
  --label "es.vencira.attachment.source=$SOURCE_SHA" \
  -f "$WORK/backend/Dockerfile" -t "$TAG" "$WORK/backend" >/dev/null
echo "ATT_API_CANDIDATE_IMAGE_BUILD=OK"
# Dependency check with disposable SQLite, no network or secret mounts.
"${DOCKER[@]}" run --rm --network none \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
  -e DJANGO_SECRET_KEY=attachment-candidate-only-random-test-secret-2026 \
  "$TAG" python manage.py check >/dev/null || {
  echo "ATT_API_CANDIDATE_DJANGO_CHECK=FAIL"; exit 5; }
echo "ATT_API_CANDIDATE_DJANGO_CHECK=OK"
for name in "$API" "$DB" "$WEB"; do
  test "${BEFORE[$name]}" = "$("${DOCKER[@]}" inspect -f '{{.Id}}:{{.Image}}' "$name")" || {
    echo "ATT_API_CANDIDATE_LIVE_CHANGED=$name"; exit 6; }
done
echo "ATT_API_CANDIDATE_TAG=$TAG"
echo "ATT_API_CANDIDATE_LIVE_CONTAINERS_UNCHANGED=OK"
echo "ATT_API_CANDIDATE_BUILD=PASS"
echo "ATT_API_CANDIDATE_DEPLOY_EXECUTED=NO"
echo "ATT_API_CANDIDATE_LIVE_MIGRATION_EXECUTED=NO"
echo "ATT_API_CANDIDATE_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
