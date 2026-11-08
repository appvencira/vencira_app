#!/usr/bin/env bash
# Pure Python native lc1 challenge wire contract; no DB, Docker, network or migrations.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
PYTHONPATH=backend python3 -m unittest -v native_mobile_service.test_candidate_challenge_wire
echo "NATIVE_I8_CHALLENGE_WIRE_UNIT=PASS"
echo "NATIVE_I8_ISSUER_PUBLIC=NO"
echo "NATIVE_I8_DURABLE_CHALLENGE_STORAGE=NOT_TESTED_BY_THIS_GATE"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
