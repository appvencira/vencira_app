#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$PWD"
python3 -m unittest -v scripts.test_mb1_g123_evidence_gate
echo "MB1_G123_UNIT_CONTRACT=OK"
python3 - <<'PY'
from scripts.mb1_g123_evidence_gate import REQUIRED, adjudicate
evidence={k: {"verified":False,"artifact":""} for k in REQUIRED}
result=adjudicate(evidence)
assert len(result["blocked"])==len(REQUIRED)
assert not result["operational_freeze_verified"]
print("MB1_G123_DEFAULT_FAILCLOSED=OK")
print("MB1_G123_UNVERIFIED_COUNT="+str(len(result["blocked"])))
PY
echo "MB1_G123_OPERATIONAL_EVIDENCE=NOT_VERIFIED"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
