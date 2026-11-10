#!/usr/bin/env bash
# D1-P: read-only external TLS and public HTTP contract for EXISTING DEV.
# Does NOT test the un-deployed main candidate behind Caddy.
set -Eeuo pipefail
set +x
mark(){ printf 'D1P_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LOGIN_ATTEMPTED NO
mark MUTATING_HTTP_REQUESTS NO

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v curl >/dev/null || { mark CURL_AVAILABLE FAIL; exit 2; }
command -v git >/dev/null || { mark GIT_AVAILABLE FAIL; exit 2; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || { mark MAIN_HEAD_REQUIRED FAIL; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE_REQUIRED FAIL; exit 2; }

# Fixed trusted destination, strict system CA validation. Never -k or proxy
# overrides supplied by operator. No follow redirects to an unknown origin.
url='https://dev.vencira.es'
if [[ -n "${HTTPS_PROXY:-}${HTTP_PROXY:-}${ALL_PROXY:-}${https_proxy:-}${http_proxy:-}${all_proxy:-}" ]]; then
  mark PROXY_ENV_PRESENT YES
  exit 3
fi
request(){
  local path="$1" status
  status="$(curl --noproxy '*' --silent --show-error --output /dev/null \
    --max-time 15 --connect-timeout 6 --proto '=https' \
    --request GET --write-out '%{http_code}' "$url$path")" || return 1
  printf '%s' "$status"
}
health="$(request /api/health/)" || { mark TLS_OR_HEALTH FAIL; exit 4; }
[[ "$health" == 200 ]] || { mark HEALTH_HTTP FAIL; exit 4; }
mark TLS_TRUSTED_CA_AND_HEALTH PASS
ready="$(request /api/ready/)" || { mark READY_HTTP FAIL; exit 4; }
[[ "$ready" == 200 ]] || { mark READY_HTTP FAIL; exit 4; }
mark READY_HTTP PASS

login="$(request /accounts/login/)" || { mark LOGIN_GET FAIL; exit 4; }
[[ "$login" == 200 ]] || { mark LOGIN_GET FAIL; exit 4; }
mark LOGIN_GET PASS
csrf="$(request /api/v1/csrf/)" || { mark CSRF_GET FAIL; exit 4; }
[[ "$csrf" == 200 ]] || { mark CSRF_GET FAIL; exit 4; }
mark CSRF_GET PASS

# GET checks alone do NOT prove that no other public native URL exists.
for path in /api/native/sessions/ /api/v1/native/issue/ /api/v1/native/refresh/ /api/v1/native/recovery/; do
  status="$(request "$path")" || { mark NATIVE_ROUTE_NEGATIVE FAIL; exit 5; }
  [[ "$status" == 404 ]] || { mark NATIVE_ROUTE_NEGATIVE FAIL; exit 5; }
done
mark SAMPLED_NATIVE_ROUTES_404 PASS

# No cookies/passwords/tokens are sent; only status is recorded.
mark EXTERNAL_HTTPS_EXISTING_DEV PASS
mark CANDIDATE_DEPLOYED NO
mark CANDIDATE_HTTPS_TESTED NO
mark COMPOSE_CONFIG_CONTENT_INSPECTED NO
mark RESULT 0
