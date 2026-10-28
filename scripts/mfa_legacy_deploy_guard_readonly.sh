#!/usr/bin/env bash
# Fail-closed protection for historical deployment scripts. Never modifies the DB.
set -Eeuo pipefail
MODE="${1:-}"
case "$MODE" in web|api|schema) ;; *) echo "MFA_LEGACY_GUARD=BLOCKED"; exit 4;; esac
block(){ echo "MFA_LEGACY_GUARD=BLOCKED"; echo "REASON=$1"; exit 4; }
# Any historical schema-changing or API deployment requires a new separately
# authorized release route; none of the historical scripts is MFA-aware.
case "$MODE" in
 api|schema) block LEGACY_API_OR_SCHEMA_DEPLOY_DISABLED ;;
esac
# Web-only rollback is permitted only against the pre-MFA live schema.
LIVE=vencira_localcheck-db-1
id="$(sudo docker inspect "$LIVE" --format '{{.Id}}' 2>/dev/null)" || block LIVE_DB_UNKNOWN
test -n "$id" || block LIVE_DB_UNKNOWN
project="$(sudo docker inspect "$LIVE" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)" || block LIVE_DB_UNKNOWN
test "$project" = vencira_localcheck || block WRONG_DB
status="$(sudo docker inspect "$LIVE" --format '{{.State.Health.Status}}' 2>/dev/null)" || block LIVE_DB_UNKNOWN
test "$status" = healthy || block DB_NOT_HEALTHY
migration="$(sudo docker exec "$LIVE" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;" 2>/dev/null)" || block MIGRATION_UNKNOWN
test "$migration" = 0018_draft_reasons || block MFA_SCHEMA_PRESENT_OR_UNKNOWN
echo "MFA_LEGACY_WEB_PREFLIGHT=OK"
echo "MFA_RELEASE_AUTHORIZED=NO"
