#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$PWD/backend"
echo "MB1_TRANSITION_CONTRACT_SCOPE=PURE_OFFLINE_NO_DB"
python3 -m unittest -v renewal_attachments.test_transition_contract_batch
echo "MB1_TRANSITION_CONTRACT_UNIT=OK"
echo "MB1_TRANSITION_PG17_HTTP=NOT_RUN"
echo "MB1_TRANSITION_LEGACY_INTEGRATION=NOT_RUN"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
