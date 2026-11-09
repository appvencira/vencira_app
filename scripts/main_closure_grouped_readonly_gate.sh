#!/usr/bin/env bash
# One-command read-only source/DEV metadata preflight. NEVER performs
# backup, migrations, deploy, SQL queries or changes to running services.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
echo 'CLOSE_COMBINED_READ_ONLY=YES'
python3 scripts/main_closure_source_inventory_readonly.py
echo 'CLOSE_FUNCTIONAL_SOURCE_AUDIT=PASS'
python3 scripts/d1b_dev_compose_o5_metadata_readonly.py
echo 'CLOSE_D1B_COMPOSE_O5_METADATA=PASS'
python3 scripts/d1c_o5_scope_units_readonly.py
echo 'CLOSE_D1C_O5_SCOPE_DIAGNOSTIC=PASS'
python3 scripts/d1e_o5_actual_units_health_readonly.py
echo 'CLOSE_D1E_O5_ACTUAL_HEALTH_DIAGNOSTIC=PASS'
echo 'CLOSE_BACKUP_RESTORE=NOT_RUN'
echo 'CLOSE_DEV_MIGRATIONS=NOT_RUN'
echo 'CLOSE_DEPLOY_EXECUTED=NO'
echo 'CLOSE_LIVE_MIGRATIONS_EXECUTED=NO'
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
echo 'CLOSE_COMBINED_PREFLIGHT=PASS'
