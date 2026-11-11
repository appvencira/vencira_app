#!/usr/bin/env bash
# Candidate Caddyfile static safety gate. No Caddy reload, DNS change or deploy.
set -Eeuo pipefail
set +x
mark(){ printf 'D10_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
for key in DEPLOY_EXECUTED CADDY_RELOAD_EXECUTED CADDY_CONFIG_CHANGED DNS_CHANGED LIVE_MIGRATIONS_EXECUTED; do mark "$key" NO; done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" && -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
path="$root/ops/caddy/vencira.es.Caddyfile.candidate"
[[ -f "$path" && ! -L "$path" ]] || { mark CANDIDATE_EXISTS FAIL; exit 3; }
python3 - "$path" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding="utf-8")
s="\n".join(line.split("#",1)[0] for line in s.splitlines())
assert re.search(r"(?m)^vencira\.es\s*\{",s), "no apex site"
assert not re.search(r"(?m)^dev\.vencira\.es\s*\{",s), "DEV site present"
assert re.search(r"reverse_proxy\s+127\.0\.0\.1:18741\b",s), "API upstream mismatch"
assert re.search(r"reverse_proxy\s+127\.0\.0\.1:18742\b",s), "Web upstream mismatch"
assert not re.search(r"1873[12]\b|localhost:1873[12]\b",s), "DEV port referenced"
assert "@api path /api/* /accounts/* /admin/*" in s
print("D10_APEX_HOST_EXPLICIT=PASS")
print("D10_SEPARATE_API_WEB_UPSTREAMS=PASS")
print("D10_DEV_PORTS_EXCLUDED=PASS")
PY
command -v caddy >/dev/null || { mark CADDY_BINARY_MISSING YES; exit 3; }
if caddy validate --config "$path" --adapter caddyfile >/dev/null 2>&1; then
  mark CADDYFILE_CANDIDATE_SYNTAX PASS
else
  mark CADDYFILE_CANDIDATE_SYNTAX FAIL; exit 4
fi
mark PRODUCTION_UPSTREAMS_DEPLOYED NO
mark DNS_CUTOVER_AUTHORIZED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark RESULT 0
