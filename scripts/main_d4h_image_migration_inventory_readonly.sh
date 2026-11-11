#!/usr/bin/env bash
# D4-H2: compare Django migration inventory in retained API image versus main.
# Read-only inspection, synthetic process, no O5, DB or host network.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D4H2_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
mark DEPLOY_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
mark DB_ACCESSED NO
mark O5_CREDENTIALS_ACCESSED NO
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_OPERATOR FAIL; exit 2; }
for t in git sudo docker python3; do command -v "$t" >/dev/null || { mark PREREQUISITE FAIL; exit 2; }; done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" && -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
sudo -n true >/dev/null 2>&1 || { mark SUDO_SESSION REQUIRED; exit 2; }
api_id="$(sudo -n docker inspect -f '{{.Image}}' vencira_localcheck-api-1 2>/dev/null)" || { mark API_ID FAIL; exit 3; }
[[ "$api_id" =~ ^sha256:[a-f0-9]{64}$ ]] || { mark API_ID_FORMAT FAIL; exit 3; }
[[ "$(sudo -n docker inspect -f '{{.State.Running}}' vencira_localcheck-api-1 2>/dev/null)" == true ]] || { mark API_RUNNING FAIL; exit 3; }
mark API_IMAGE_IDENTIFIED PASS
# Fixed Python procedure emits only numbered migration filenames; never
# application environment, passwords, filesystem paths or private data.
inspect='import os,re,sys
from pathlib import Path
p=Path(sys.argv[1])
nums=sorted({int(m.group(1)) for f in p.glob("*.py") if (m:=re.fullmatch(r"(\\d{4})_[A-Za-z0-9_]+\\.py",f.name))})
print("MIGRATION_NUMBERS="+",".join(str(n) for n in nums))
'
# The fixed paths below are repository and image build layout, not operator input.
image_inventory="$(sudo -n docker run --rm --pull never --network none --read-only \
 --security-opt no-new-privileges --pids-limit 32 --memory 128m \
 --entrypoint python "$api_id" -c "$inspect" /app/reminders/migrations 2>/dev/null)" || { mark IMAGE_INVENTORY FAIL; exit 4; }
main_inventory="$(python3 -c "$inspect" "$root/backend/reminders/migrations")" || { mark MAIN_INVENTORY FAIL; exit 4; }
python3 - "$image_inventory" "$main_inventory" <<'PY'
import sys
def parse(s):
    if not s.startswith("MIGRATION_NUMBERS="): raise SystemExit(1)
    fields=s.split("=",1)[1].strip()
    nums=[int(x) for x in fields.split(",")] if fields else []
    if nums!=sorted(set(nums)): raise SystemExit(1)
    return set(nums)
image,main=map(parse,sys.argv[1:])
for label,numbers in (("IMAGE",image),("MAIN",main)):
    print("D4H2_"+label+"_0018_PRESENT="+("YES" if 18 in numbers else "NO"))
    print("D4H2_"+label+"_0027_PRESENT="+("YES" if 27 in numbers else "NO"))
    print("D4H2_"+label+"_0019_0027_COMPLETE="+("YES" if set(range(19,28))<=numbers else "NO"))
    print("D4H2_"+label+"_MAX_MIGRATION_NUMBER="+str(max(numbers,default=0)))
print("D4H2_IMAGE_MAIN_NUMBERED_MIGRATION_PARITY="+("PASS" if image==main else "FAIL"))
print("D4H2_MIGRATION_PLAN_FAILURE_EXPLAINED_BY_MISSING_TARGET="+("YES" if 27 in main and 27 not in image else "NOT_ESTABLISHED"))
PY
mark O5_REAL_RESTORE_REEXECUTED NO
mark DEV_CONTAINERS_MODIFIED NO
mark RESULT 0
