#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$PWD"
python3 -m unittest -v scripts.test_mb1_g1_runtime_review_ledger
echo "MB1_G1_LEDGER_UNIT=OK"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 scripts/mb1_g1_runtime_review_ledger.py --source backend --out "$TMP/runtime-ledger.csv"
test -s "$TMP/runtime-ledger.csv"
echo "MB1_G1_LEDGER_CSV_CREATED=OK"
echo "MB1_G1_LEDGER_CSV_LOCATION=TEMPORARY_REMOVED_ON_EXIT"
echo "MB1_G1_RUNTIME_EVIDENCE=REVIEW_REQUIRED"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
