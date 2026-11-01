#!/usr/bin/env bash
# New-only object integrity contract gate. No PostgreSQL, Docker or DEV access.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$PWD/backend"
python3 -m unittest -v renewal_attachments.test_transition_object_contract
echo "MB1_PA_OBJECT_CONTRACT=OK"
echo "MB1_PA_OBJECT_REAL_STORE=NOT_RUN"
echo "MB1_PA_HISTORICAL_BOTH_SCHEMAS=NOT_RUN"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "C_FICHA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
