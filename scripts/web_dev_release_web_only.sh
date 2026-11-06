#!/usr/bin/env bash
# Controlled DEV frontend-only replacement; does not build/restart Django or PostgreSQL.
# Usage: bash scripts/web_dev_release_web_only.sh preflight|deploy|rollback
# Do not execute deploy until post-canary demo UAT / explicit approval.
set -Eeuo pipefail
umask 077
MODE="${1:-preflight}"
[[ "$MODE" = preflight || "$MODE" = deploy || "$MODE" = rollback ]] || { echo "WEB_RELEASE_BAD_MODE"; exit 2; }
PROJECT=vencira_localcheck
SERVICE=vencira_localcheck-web_preview-1
API=vencira_localcheck-api-1
DB=vencira_localcheck-db-1
BASE=/home/vencira/vencira-localcheck
TAG=vencira-web-candidate:308c69da24aa
EXPECTED_SOURCE=308c69da24aa7c75502d132e28645d9b1150c1ef
EXPECTED_OLD_WEB=sha256:9de96e4a9a3ae18b13dbcfbb6c2a25857d7511df3840c4851c6400223136eaf1
RECEIPT=/home/vencira/.vencira-web-only-last-release.receipt
DOCKER=(docker)
if [[ "$(id -u)" -ne 0 ]]; then
  sudo -v
  DOCKER=(sudo docker)
fi
test -d "$BASE/.git" || { echo "WEB_RELEASE_BASE_CHECKOUT=ABSENT"; exit 3; }
cd "$BASE"
# .env is read by Compose, never print it or config output.
COMPOSE=("${DOCKER[@]}" compose -p "$PROJECT" -f "$BASE/compose.yaml" -f "$BASE/compose.preview.yaml")
exec 9>/home/vencira/.vencira-web-only-release.lock
flock -n 9 || { echo "WEB_RELEASE_ALREADY_RUNNING=YES"; exit 3; }
tmp="$(mktemp /tmp/vencira-web-only-override.XXXXXXXX.yaml)"
chmod 0600 "$tmp"
trap 'rm -f "$tmp"' EXIT

idof() { "${DOCKER[@]}" inspect --format '{{.Image}}' "$1"; }
healthof() { "${DOCKER[@]}" inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$1"; }
projectof() { "${DOCKER[@]}" inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$1"; }
for name in "$SERVICE" "$API" "$DB"; do
  test "$(projectof "$name")" = "$PROJECT" || { echo "WEB_RELEASE_PROJECT_MISMATCH=$name"; exit 4; }
  test "$(healthof "$name")" = healthy || { echo "WEB_RELEASE_HEALTH_NOT_READY=$name"; exit 4; }
done
api_before="$(idof "$API")"
db_before="$(idof "$DB")"
web_before="$(idof "$SERVICE")"

image_for_tag="$("${DOCKER[@]}" image inspect -f '{{.Id}}' "$TAG")"
source_for_tag="$("${DOCKER[@]}" image inspect -f '{{index .Config.Labels "es.vencira.candidate.source"}}' "$TAG")"
test "$source_for_tag" = "$EXPECTED_SOURCE" || { echo "WEB_RELEASE_CANDIDATE_SHA_MISMATCH"; exit 5; }
"${DOCKER[@]}" image inspect "$web_before" >/dev/null
test "$image_for_tag" != "$web_before" || { echo "WEB_RELEASE_ALREADY_ACTIVE=YES"; exit 5; }

if [[ "$MODE" = rollback ]]; then
  test -f "$RECEIPT" && test ! -L "$RECEIPT" || { echo "WEB_ROLLBACK_NO_RECEIPT"; exit 6; }
  # Receipt contains only a previous image ID and no secrets. Parse fixed keys.
  old="$(sed -n 's/^OLD_WEB_IMAGE=//p' "$RECEIPT" | head -n 1)"
  candidate="$(sed -n 's/^NEW_WEB_IMAGE=//p' "$RECEIPT" | head -n 1)"
  [[ "$old" =~ ^sha256:[a-f0-9]{64}$ && "$candidate" =~ ^sha256:[a-f0-9]{64}$ ]] || exit 6
  test "$web_before" = "$candidate" || { echo "WEB_ROLLBACK_ACTIVE_IMAGE_MISMATCH"; exit 6; }
  "${DOCKER[@]}" image inspect "$old" >/dev/null
  old_tag="$(sed -n 's/^OLD_WEB_TAG=//p' "$RECEIPT" | head -n 1)"
  [[ "$old_tag" =~ ^vencira-web-rollback:[a-f0-9]{12}$ ]] || exit 6
  test "$("\${DOCKER[@]}" image inspect -f '{{.Id}}' "$old_tag")" = "$old" || exit 6
  target="$old_tag"
else
  test "$web_before" = "$EXPECTED_OLD_WEB" || {
    echo "WEB_RELEASE_BASELINE_IMAGE_CHANGED"; exit 5; }
  target="$TAG"
fi
printf 'services:\n  web_preview:\n    image: "%s"\n' "$target" > "$tmp"
"${COMPOSE[@]}" -f "$tmp" config --quiet >/dev/null
echo "WEB_RELEASE_MODE=$MODE"
echo "WEB_RELEASE_API_IMAGE=$api_before"
echo "WEB_RELEASE_DB_IMAGE=$db_before"
echo "WEB_RELEASE_WEB_FROM=$web_before"
echo "WEB_RELEASE_WEB_TO=$target"
echo "WEB_RELEASE_ONLY_SERVICE=web_preview"
if [[ "$MODE" = preflight ]]; then
  echo "WEB_RELEASE_PREFLIGHT=PASS"
  echo "WEB_RELEASE_EXECUTED=NO"
  exit 0
fi
if [[ "$MODE" = deploy ]]; then
  [[ "${VENCIRA_WEB_DEV_DEPLOY_APPROVED:-}" = YES ]] || {
    echo "WEB_RELEASE_EXPLICIT_APPROVAL=REQUIRED"; exit 7; }
elif [[ "$MODE" = rollback ]]; then
  [[ "${VENCIRA_WEB_DEV_ROLLBACK_APPROVED:-}" = YES ]] || {
    echo "WEB_ROLLBACK_EXPLICIT_APPROVAL=REQUIRED"; exit 7; }
fi

restore() {
  local target_image="$1"
  printf 'services:\n  web_preview:\n    image: "%s"\n' "$target_image" > "$tmp"
  "${COMPOSE[@]}" -f "$tmp" up -d --no-deps --no-build --force-recreate web_preview >/dev/null
}
http_check() {
  local base=http://127.0.0.1:18732 code
  for _ in $(seq 1 30); do
    code="$(curl --noproxy '*' --silent --show-error --max-time 6 -o /dev/null -w '%{http_code}' "$base/" 2>/dev/null || true)"
    [[ "$code" = 200 ]] && break
    sleep 2
  done
  [[ "$code" = 200 ]] || return 1
  for path in /main.dart.js /api/health/ /accounts/login/; do
    code="$(curl --noproxy '*' --silent --show-error --max-time 8 -o /dev/null -w '%{http_code}' "$base$path" 2>/dev/null || true)"
    [[ "$code" = 200 ]] || return 1
  done
  code="$(curl --noproxy '*' --silent --show-error --max-time 8 -o /dev/null -w '%{http_code}' "$base/api/v1/workspaces/" 2>/dev/null || true)"
  [[ "$code" = 401 || "$code" = 403 ]]
}
echo "WEB_RELEASE_MUTATION_START=web_preview_ONLY"
if [[ "$MODE" = deploy ]]; then
  # Convert the immutable old image ID into a stable, inspected local reference.
  rollback_tag="vencira-web-rollback:${web_before:7:12}"
  "${DOCKER[@]}" image tag "$web_before" "$rollback_tag"
  test "$("${DOCKER[@]}" image inspect -f '{{.Id}}' "$rollback_tag")" = "$web_before" || exit 8
fi
if ! restore "$target"; then
  echo "WEB_RELEASE_COMPOSE=FAIL"
  if [[ "$MODE" = deploy ]]; then restore "$web_before" || true; fi
  exit 8
fi
if ! http_check || [[ "$(idof "$API")" != "$api_before" || "$(idof "$DB")" != "$db_before" ]]; then
  echo "WEB_RELEASE_POSTCHECK=FAIL"
  if [[ "$MODE" = deploy ]]; then
    echo "WEB_RELEASE_AUTO_ROLLBACK=START"
    restore "$rollback_tag" && http_check && echo "WEB_RELEASE_AUTO_ROLLBACK=PASS" || echo "WEB_RELEASE_AUTO_ROLLBACK=NEEDS_MANUAL_ACTION"
  fi
  exit 9
fi
test "$(idof "$SERVICE")" = "$("${DOCKER[@]}" image inspect -f '{{.Id}}' "$target")" || {
  echo "WEB_RELEASE_NEW_IMAGE_NOT_ACTIVE"; exit 10; }
if [[ "$MODE" = deploy ]]; then
  {
    printf 'OLD_WEB_IMAGE=%s\n' "$web_before"
    printf 'NEW_WEB_IMAGE=%s\n' "$image_for_tag"
    printf 'SOURCE_SHA=%s\n' "$EXPECTED_SOURCE"
  } > "$RECEIPT"
  chmod 0600 "$RECEIPT"
fi
echo "WEB_RELEASE_POSTCHECK=PASS"
echo "WEB_RELEASE_API_DB_IMAGES_UNCHANGED=YES"
echo "WEB_RELEASE_MODE_RESULT=PASS:$MODE"
echo "WEB_RELEASE_UAT=REQUIRES_MANUAL_BROWSER_VALIDATION"
echo "NO_LIVE_DB_MIGRATION=1"
