#!/usr/bin/env bash
# Read-only main integration gate: tree differences, migration paths and main-only history.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
MAIN=origin/main
FEAT=origin/feature/m3-android-local-notifications
git rev-parse --verify "$MAIN^{commit}" >/dev/null
git rev-parse --verify "$FEAT^{commit}" >/dev/null
echo "MAIN_INTEGRATION_BASE=$(git merge-base "$MAIN" "$FEAT")"
echo "MAIN_INTEGRATION_MAIN=$(git rev-parse "$MAIN")"
echo "MAIN_INTEGRATION_FEATURE=$(git rev-parse "$FEAT")"
echo "=== COMMITS EXCLUSIVOS DE MAIN (hasta 30) ==="
git log --format='%h %s' --max-count=30 "$FEAT..$MAIN"
echo "=== ARCHIVOS TOCADOS POR COMMITS EXCLUSIVOS DE MAIN ==="
git log --format= --name-only "$FEAT..$MAIN" | LC_ALL=C sort -u | sed '/^$/d' | head -100
echo "=== MIGRACIONES DIFERENTES ENTRE ARBOLES ==="
git diff --name-status "$MAIN" "$FEAT" -- backend/reminders/migrations backend/renewal_attachments/migrations backend/native_mobile_service/migrations backend/native_sessions_lab/migrations
echo "=== MIGRACIONES CAMBIADAS DESDE ANCESTRO ==="
BASE=$(git merge-base "$MAIN" "$FEAT")
git diff --name-status "$BASE" "$FEAT" -- backend/reminders/migrations backend/renewal_attachments/migrations backend/native_mobile_service/migrations backend/native_sessions_lab/migrations | head -100
echo "=== CONFIGURACION Y DESPLIEGUE — DIFERENCIAS DE ARBOLES ==="
git diff --name-status "$MAIN" "$FEAT" -- backend/config backend/Dockerfile backend/requirements.txt compose.yaml compose.web.yaml compose.preview.yaml .github/workflows | head -100
echo "MAIN_INTEGRATION_GATE=READ_ONLY_COMPLETE"
echo "MAIN_INTEGRATION_MERGE_AUTHORIZED=NO"
echo "MAIN_INTEGRATION_DEPLOY_AUTHORIZED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
