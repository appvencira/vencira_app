#!/usr/bin/env bash
# Builds a candidate web image without modifying running Compose services.
# No app deploy, no migration, no api/db restart. Image persists for inspection.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "WEB_CANDIDATE_MODE=ISOLATED_BUILD_ONLY"
for bin in git docker; do
  command -v "$bin" >/dev/null || { echo "WEB_CANDIDATE_REQUIRED_TOOL_MISSING=$bin"; exit 2; }
done
HEAD_SHA="$(git rev-parse HEAD)"
SHORT="${HEAD_SHA:0:12}"
echo "WEB_CANDIDATE_SOURCE_SHA=$HEAD_SHA"
if ! git diff --quiet -- clients/flutter/lib clients/flutter/web clients/flutter/pubspec.yaml deploy/preview/Dockerfile.web deploy/local-web/nginx.conf; then
  echo "WEB_CANDIDATE_TRACKED_SOURCE_DIRTY=DENIED"
  exit 3
fi
if ! git diff --cached --quiet -- clients/flutter/lib clients/flutter/web clients/flutter/pubspec.yaml deploy/preview/Dockerfile.web deploy/local-web/nginx.conf; then
  echo "WEB_CANDIDATE_INDEX_SOURCE_DIRTY=DENIED"
  exit 3
fi
if test -n "$(git ls-files --others --exclude-standard -- clients/flutter/lib clients/flutter/web deploy/preview deploy/local-web)"; then
  echo "WEB_CANDIDATE_UNTRACKED_SOURCE=DENIED"
  exit 3
fi
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  state="$(docker inspect -f '{{.State.Status}}' "$name")"
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$name")"
  project="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")"
  if [[ "$state" != running || "$health" != healthy || "$project" != vencira_localcheck ]]; then
    echo "WEB_CANDIDATE_LIVE_SERVICE_CHECK=DENIED:$name"
    exit 4
  fi
done
OLD_WEB="$(docker inspect -f '{{.Image}}' vencira_localcheck-web_preview-1)"
OLD_API="$(docker inspect -f '{{.Image}}' vencira_localcheck-api-1)"
OLD_DB="$(docker inspect -f '{{.Image}}' vencira_localcheck-db-1)"
docker image inspect "$OLD_WEB" >/dev/null
echo "WEB_CANDIDATE_OLD_WEB_RECOVERABLE=YES"
# Fixed tag scoped to exact source commit. Never tag/overwrite the live image.
TAG="vencira-web-candidate:$SHORT"
echo "WEB_CANDIDATE_TAG=$TAG"
docker build --pull=false \
  --label "es.vencira.candidate.source=$HEAD_SHA" \
  -f deploy/preview/Dockerfile.web \
  -t "$TAG" . 
# Inspect static build artifacts without starting nginx or joining live network.
docker run --rm --network none --entrypoint /bin/sh "$TAG" -ec '
  test -s /usr/share/nginx/html/index.html
  test -s /usr/share/nginx/html/main.dart.js
  test -s /etc/nginx/conf.d/default.conf
'
echo "WEB_CANDIDATE_STATIC_ASSETS=OK"
ACTUAL_LABEL="$(docker image inspect -f '{{index .Config.Labels "es.vencira.candidate.source"}}' "$TAG")"
test "$ACTUAL_LABEL" = "$HEAD_SHA"
for entry in \
  "vencira_localcheck-web_preview-1:$OLD_WEB" \
  "vencira_localcheck-api-1:$OLD_API" \
  "vencira_localcheck-db-1:$OLD_DB"; do
  name="${entry%%:*}"
  expected="${entry#*:}"
  actual="$(docker inspect -f '{{.Image}}' "$name")"
  if [ "$actual" != "$expected" ]; then
    echo "WEB_CANDIDATE_LIVE_IMAGE_CHANGED=DENIED:$name"
    exit 5
  fi
done
echo "WEB_CANDIDATE_LIVE_IMAGES_UNCHANGED=OK"
echo "WEB_CANDIDATE_BUILD=PASS"
echo "WEB_CANDIDATE_DEPLOY_EXECUTED=NO"
echo "WEB_CANDIDATE_API_DB_UNCHANGED=YES"
echo "WEB_CANDIDATE_COMPATIBILITY_WITH_LIVE_API=NOT_VERIFIED"
echo "WEB_CANDIDATE_ROLLBACK_GATE=NOT_VERIFIED"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
