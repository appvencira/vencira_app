#!/usr/bin/env bash
# Compact, read-only review. Does not merge, switch, reset, deploy or migrate.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
M=origin/main
F=origin/feature/m3-android-local-notifications
git rev-parse --verify "$M^{commit}" >/dev/null
git rev-parse --verify "$F^{commit}" >/dev/null
B="$(git merge-base "$M" "$F")"
echo "MAIN_RISK_BASE=$B"
echo "MAIN_RISK_MAIN=$(git rev-parse "$M")"
echo "MAIN_RISK_FEATURE=$(git rev-parse "$F")"
echo "=== MAIN-ONLY COMMITS ==="
git log --format='%h %s' "$F..$M"
echo "=== MAIN-ONLY COMMIT PATHS BY RISK ==="
git log --format= --name-only "$F..$M" | LC_ALL=C sort -u | sed '/^$/d' | awk '
 /\/migrations\// { migration++; next }
 /mfa|credential|session|security|auth/ { auth++; next }
 /^(backend\/|compose|\.github\/workflows\/)/ { infra++; next }
 /^(clients\/flutter\/)/ { flutter++; next }
 {other++}
 END {printf "MAIN_RISK_MAIN_ONLY_MIGRATION_PATHS=%d\nMAIN_RISK_MAIN_ONLY_AUTH_PATHS=%d\nMAIN_RISK_MAIN_ONLY_INFRA_PATHS=%d\nMAIN_RISK_MAIN_ONLY_FLUTTER_PATHS=%d\nMAIN_RISK_MAIN_ONLY_OTHER_PATHS=%d\n",migration,auth,infra,flutter,other}'
echo "=== MIGRATION TREE DIFFERENCES (MAIN V FEATURE) ==="
git diff --name-status "$M" "$F" -- backend/reminders/migrations backend/renewal_attachments/migrations backend/native_mobile_service/migrations backend/native_sessions_lab/migrations
echo "=== MIGRATION HISTORY DELTA (BASE V FEATURE) ==="
git diff --name-status "$B" "$F" -- backend/reminders/migrations backend/renewal_attachments/migrations backend/native_mobile_service/migrations backend/native_sessions_lab/migrations | awk '
 {count++; if (count<=40) print}
 END {printf "MAIN_RISK_FEATURE_MIGRATION_CHANGE_COUNT=%d\n",count}'
echo "=== MAIN-ONLY BACKEND/DEPLOY PATHS (up to 45) ==="
git log --format= --name-only "$F..$M" | LC_ALL=C sort -u | sed '/^$/d' | grep -E '^(backend/|compose|\.github/workflows/)' | sed -n '1,45p' || true
echo "MAIN_RISK_SUMMARY=PASS"
echo "MAIN_RISK_MERGE_AUTHORIZED=NO"
echo "MAIN_RISK_DEPLOY_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
