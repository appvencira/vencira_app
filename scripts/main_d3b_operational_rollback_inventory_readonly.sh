#!/usr/bin/env bash
# D3-B: READ-ONLY immutable operational image inventory and previous version custody.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D3B_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark ROLLBACK_EXECUTED NO
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
for tool in docker git; do
  command -v "$tool" >/dev/null || { mark MISSING_TOOL "$tool"; exit 2; }
done
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  mark MAIN_SYNC FAIL; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE FAIL; exit 2; }
mark MAIN_SYNC PASS
if [[ "$(id -u)" == 0 ]]; then
  D(){ docker "$@"; }
else
  sudo -v
  D(){ sudo docker "$@"; }
fi
services=(vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1)
for name in "${services[@]}"; do
  project="$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null || true)"
  status="$(D inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)"
  [[ "$project" == vencira_localcheck && "$status" == true ]] || {
    mark OPERATIONAL_IDENTITY FAIL; exit 3;
  }
done
mark OPERATIONAL_IDENTITY PASS
api_current="$(D inspect -f '{{.Image}}' "${services[0]}")"
db_current="$(D inspect -f '{{.Image}}' "${services[1]}")"
web_current="$(D inspect -f '{{.Image}}' "${services[2]}")"
for current in "$api_current" "$db_current" "$web_current"; do
  [[ "$current" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    mark IMMUTABLE_IDENTITY FAIL; exit 3;
  }
  D image inspect "$current" >/dev/null 2>&1 || {
    mark IMAGE_LOCAL_CUSTODY FAIL; exit 3;
  }
done
mark CURRENT_IMAGES_IMMUTABLE_AND_LOCAL PASS
mount="$(D inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Type}}:{{.Name}}{{end}}{{end}}' "${services[1]}")"
[[ "$mount" =~ ^volume:[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]] || {
  mark POSTGRES_NAMED_VOLUME FAIL; exit 3;
}
mark POSTGRES_NAMED_VOLUME PASS
# The PREVIOUS images must be explicitly supplied as immutable IDs, distinct
# from current running images, and already retained in local Docker storage.
# Never accept mutable tags or infer a previous release from 'latest'.
prev_api="${D3B_PREVIOUS_API_IMAGE:-}"
prev_web="${D3B_PREVIOUS_WEB_IMAGE:-}"
if [[ -z "$prev_api" || -z "$prev_web" ]]; then
  mark PREVIOUS_IMAGE_MANIFEST MISSING
  mark PREVIOUS_IMAGE_CUSTODY_VERIFIED NO
  mark OPERATIONAL_ROLLBACK_VERIFIED NO
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT 4
  exit 4
fi
for previous in "$prev_api" "$prev_web"; do
  [[ "$previous" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    mark PREVIOUS_IMAGE_IMMUTABLE_IDS FAIL; exit 4;
  }
  D image inspect "$previous" >/dev/null 2>&1 || {
    mark PREVIOUS_IMAGE_LOCAL_CUSTODY FAIL; exit 4;
  }
done
[[ "$prev_api" != "$api_current" && "$prev_web" != "$web_current" ]] || {
  mark PREVIOUS_DISTINCT_FROM_RUNNING FAIL; exit 4;
}
mark PREVIOUS_IMAGES_IMMUTABLE PASS
mark PREVIOUS_IMAGES_LOCALLY_AVAILABLE PASS
mark PREVIOUS_IMAGE_CUSTODY_VERIFIED YES
# Availability is necessary, not sufficient, for rollback readiness.
mark PRIOR_IMAGE_RUNTIME_WITH_O5_RESTORED_DB_VERIFIED NO
mark PREVIOUS_IMAGE_SWITCHOVER_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark RESULT 0
