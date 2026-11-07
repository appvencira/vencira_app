#!/usr/bin/env bash
# Validate existing independent attachment app in a disposable environment.
# Runs Django migration autodetector with no live DB, no writes to checkout.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DOCKER=(docker)
if [[ "$(id -u)" -ne 0 ]]; then
  sudo -v
  DOCKER=(sudo docker)
fi
API=vencira_localcheck-api-1
IMAGE="$("${DOCKER[@]}" inspect -f '{{.Image}}' "$API")"
PROJECT="$("${DOCKER[@]}" inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$API")"
HEALTH="$("${DOCKER[@]}" inspect -f '{{.State.Health.Status}}' "$API")"
test "$PROJECT" = vencira_localcheck && test "$HEALTH" = healthy || {
  echo "ATTACHMENT_DRYRUN_LIVE_IMAGE=DENIED"; exit 2;
}
test -d backend/renewal_attachments/migrations || exit 2
echo "ATTACHMENT_DRYRUN_MODE=DISPOSABLE_CONTAINER"
# DEV API image is older than the candidate source and lacks cryptography.
# Build a separate, disposable candidate-dependency image; never alter live API.
SHA="$(git rev-parse HEAD)"
DRY_IMAGE="vencira-backend-attachment-dryrun:${SHA:0:12}"
echo "ATTACHMENT_DRYRUN_DEPENDENCIES=CANDIDATE_SOURCE"
"${DOCKER[@]}" build --pull=false -f backend/Dockerfile -t "$DRY_IMAGE" backend >/dev/null
echo "ATTACHMENT_DRYRUN_IMAGE_BUILD=OK"
echo "ATTACHMENT_DRYRUN_LIVE_API_IMAGE_UNCHANGED=YES"
# A throwaway clone of the source tree under /tmp lets Django inspect files
# with a writable tree if needed. No data mounts, no network.
SCRATCH="$(mktemp -d /tmp/vencira-attach-dryrun.XXXXXXXX)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT
cp -a backend/. "$SCRATCH/"
chmod -R u+rwX "$SCRATCH"
# Force Django to see only the independent app's test rehearsal configuration.
# Use disposable test secret; DO NOT pass any production secrets into container.
set +e
"${DOCKER[@]}" run --rm --network none \
  --user "$(id -u):$(id -g)" \
  -e DJANGO_SECRET_KEY=attachment-isolated-rehearsal-only-secret-2026 \
  -e VENCIRA_ENV=test \
  -e VENCIRA_DB_ENGINE=sqlite \
  -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
  -e VENCIRA_M103_SPLIT_DELETE_LAB=1 \
  -v "$SCRATCH:/app:rw" -w /app "$DRY_IMAGE" \
  python manage.py makemigrations renewal_attachments --check --dry-run --noinput \
  >"$SCRATCH/report.txt" 2>&1
RC=$?
set -e
if [[ "$RC" -eq 0 ]]; then
  echo "ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=YES"
elif grep -Eq '^(Migrations for|    [+-] )' "$SCRATCH/report.txt"; then
  echo "ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=NO"
else
  echo "ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=NOT_VERIFIED"
fi
# No customer content or keys; show only the Django detection report.
grep -E '^(Migrations for|  renewal_attachments/|    \+|    -|No changes detected|SystemCheckError|ERRORS:|CommandError:)' "$SCRATCH/report.txt" | head -n 70 || true
if [[ "$RC" -ne 0 ]]; then
  echo "ATTACHMENT_DRYRUN_EXIT_CODE=$RC"
  tail -n 12 "$SCRATCH/report.txt"
fi
test "$("${DOCKER[@]}" inspect -f '{{.Image}}' "$API")" = "$IMAGE" || {
  echo "ATTACHMENT_DRYRUN_LIVE_IMAGE_CHANGED=FAIL"; exit 3;
}
echo "ATTACHMENT_DRYRUN_LIVE_IMAGE_CHANGED=NO"
echo "ATTACHMENT_DRYRUN_API_DEPLOY_EXECUTED=NO"
echo "ATTACHMENT_DRYRUN_LIVE_MIGRATIONS_EXECUTED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
# Model drift is a diagnostic finding, but startup errors must fail.
if [[ "$RC" -ne 0 ]] && ! grep -Eq '^(Migrations for|    [+-] )' "$SCRATCH/report.txt"; then
  exit "$RC"
fi
exit 0
