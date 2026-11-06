#!/usr/bin/env bash
# Ephemeral, local-only HTTP canary for already-built Flutter Web image.
# Does not change the running web/API/DB services, restart Compose, or migrate.
set -Eeuo pipefail
umask 077

TAG="${1:-vencira-web-candidate:308c69da24aa}"
PORT="${WEB_DEV_CANARY_PORT:-18744}"
CANARY="vencira-web-canary-$$"
DOCKER=(docker)
if [[ "$(id -u)" -ne 0 ]]; then
  sudo -v
  DOCKER=(sudo docker)
fi
cleanup() {
  "${DOCKER[@]}" rm -f "$CANARY" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "WEB_DEV_CANARY_TAG=$TAG"
echo "WEB_DEV_CANARY_PORT=$PORT"
case "$TAG" in vencira-web-candidate:*) ;; *) echo "WEB_DEV_CANARY_IMAGE_NOT_CANDIDATE=DENIED"; exit 2;; esac
"${DOCKER[@]}" image inspect "$TAG" >/dev/null
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  health="$("${DOCKER[@]}" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' "$name")"
  project="$("${DOCKER[@]}" inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")"
  test "$health" = healthy && test "$project" = vencira_localcheck || {
    echo "WEB_DEV_CANARY_LIVE_PRECHECK=FAILED:$name"; exit 3; }
done
BEFORE_WEB="$("${DOCKER[@]}" inspect -f '{{.Image}}' vencira_localcheck-web_preview-1)"
BEFORE_API="$("${DOCKER[@]}" inspect -f '{{.Image}}' vencira_localcheck-api-1)"
BEFORE_DB="$("${DOCKER[@]}" inspect -f '{{.Image}}' vencira_localcheck-db-1)"

# Reuse the network already linked to the live web/API pair. No network
# creation or modifications to those containers.
WEB_NET="$("${DOCKER[@]}" inspect vencira_localcheck-web_preview-1 --format '{{range $name, $v := .NetworkSettings.Networks}}{{println $name}}{{end}}' | head -n 1)"
test -n "$WEB_NET" || { echo "WEB_DEV_CANARY_NETWORK=NOT_FOUND"; exit 4; }
"${DOCKER[@]}" network inspect "$WEB_NET" >/dev/null
echo "WEB_DEV_CANARY_NETWORK=EXISTING_COMPOSE_NETWORK"

# The name and port are local-only. The ephemeral container proxies the same
# existing API without exposing another public service.
"${DOCKER[@]}" run -d --rm --name "$CANARY" --network "$WEB_NET" \
    --publish "127.0.0.1:$PORT:8080" "$TAG" >/dev/null

BASE="http://127.0.0.1:$PORT"
request_code() {
  curl --noproxy '*' -sS --max-time 12 -o /dev/null -w '%{http_code}' "$1"
}
for _ in $(seq 1 20); do
  status="$(request_code "$BASE/" || true)"
  if [[ "$status" = 200 ]]; then break; fi
  sleep 1
done
test "$status" = 200 || { echo "WEB_DEV_CANARY_HOME=$status"; exit 5; }
echo "WEB_DEV_CANARY_HOME=200"
js="$(request_code "$BASE/main.dart.js" || true)"
test "$js" = 200 || { echo "WEB_DEV_CANARY_JS=$js"; exit 6; }
echo "WEB_DEV_CANARY_JS=200"
health="$(request_code "$BASE/api/health/" || true)"
test "$health" = 200 || { echo "WEB_DEV_CANARY_API_HEALTH=$health"; exit 7; }
echo "WEB_DEV_CANARY_API_HEALTH=200"
login="$(request_code "$BASE/accounts/login/" || true)"
test "$login" = 200 || { echo "WEB_DEV_CANARY_LOGIN=$login"; exit 8; }
echo "WEB_DEV_CANARY_LOGIN=200"
private="$(request_code "$BASE/api/v1/workspaces/" || true)"
case "$private" in 401|403) echo "WEB_DEV_CANARY_PRIVATE_DENIED=$private";; *)
  echo "WEB_DEV_CANARY_PRIVATE_UNEXPECTED=$private"; exit 9;;
esac
for entry in \
  "vencira_localcheck-web_preview-1:$BEFORE_WEB" \
  "vencira_localcheck-api-1:$BEFORE_API" \
  "vencira_localcheck-db-1:$BEFORE_DB"; do
  name="${entry%%:*}"
  before="${entry#*:}"
  after="$("${DOCKER[@]}" inspect -f '{{.Image}}' "$name")"
  test "$after" = "$before" || {
    echo "WEB_DEV_CANARY_LIVE_IMAGE_CHANGED=$name"; exit 10; }
done
echo "WEB_DEV_CANARY_LIVE_IMAGES_UNCHANGED=OK"
echo "WEB_DEV_CANARY_HTTP_SMOKE=PASS"
echo "WEB_DEV_FUNCTIONAL_UAT=NOT_VERIFIED"
echo "WEB_DEV_DEPLOY_EXECUTED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
