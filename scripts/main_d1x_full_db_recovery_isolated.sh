#!/usr/bin/env bash
# D1-X: synthetic whole-DB snapshot/restore in an isolated PostgreSQL 17 tmpfs.
# Does NOT touch DEV, O5 repositories, live images, or persistent volumes.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D1X_DB_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark LIVE_RESTORE_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark DEPLOY_EXECUTED NO
if [[ "$(id -u)" == 0 ]]; then
  D(){ docker "$@"; }
else
  command -v sudo >/dev/null || exit 2
  sudo -v
  D(){ sudo docker "$@"; }
fi
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck ]] || {
    mark DEV_IDENTITY FAIL; exit 3;
  }
done
mark DEV_IDENTITY PASS
declare -A dev_ids
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  dev_ids["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
nonce="$(openssl rand -hex 8)"
network="vencira-d1x-$nonce-net"
db="vencira-d1x-$nonce-pg"
created_net=NO
created_db=NO
cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$created_db" == YES ]]; then D rm -f "$db" >/dev/null 2>&1 || rc=9; fi
  if [[ "$created_net" == YES ]]; then D network rm "$network" >/dev/null 2>&1 || rc=9; fi
  local unchanged=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" == "${dev_ids[$name]}" ]] || unchanged=NO
  done
  [[ "$unchanged" == YES ]] || rc=9
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$unchanged" == YES ]] && echo OK || echo FAIL)"
  mark EPHEMERAL_CLEANUP "$([[ "$rc" == 9 ]] && echo FAIL || echo DONE)"
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
D network create --internal "$network" >/dev/null
created_net=YES
[[ "$(D network inspect -f '{{.Internal}}' "$network")" == true ]] || exit 4
mark INTERNAL_NETWORK PASS
pw="$(openssl rand -hex 24)"
D run -d --name "$db" --network "$network" --security-opt no-new-privileges \
  --pids-limit 256 --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  -e POSTGRES_DB=d1x -e POSTGRES_USER=d1x -e POSTGRES_PASSWORD="$pw" \
  postgres:17-alpine >/dev/null
created_db=YES
[[ "$(D inspect -f '{{.HostConfig.PortBindings}}' "$db")" == 'map[]' ]] || exit 4
[[ -z "$(D inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' "$db")" ]] || exit 4
mark NO_PORTS_NO_PERSISTENT_MOUNTS PASS
ready=NO
for _ in $(seq 1 60); do
  if D exec "$db" pg_isready -U d1x -d d1x >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark PG17_READY FAIL; exit 4; }
mark PG17_TMPFS PASS
D exec "$db" psql -U d1x -d d1x -v ON_ERROR_STOP=1 -q \
  -c "CREATE TABLE d1x_recovery_fixture(id integer primary key, state text not null); INSERT INTO d1x_recovery_fixture VALUES (1, 'before');" >/dev/null || exit 5
D exec "$db" pg_dump -U d1x -d d1x -Fc -f /tmp/d1x-full-database.dump >/dev/null || exit 5
mark FULL_SYNTHETIC_DB_SNAPSHOT PASS
D exec "$db" psql -U d1x -d d1x -v ON_ERROR_STOP=1 -q \
  -c "UPDATE d1x_recovery_fixture SET state='after'; DROP TABLE d1x_recovery_fixture;" >/dev/null || exit 5
D exec "$db" pg_restore -U d1x -d d1x --clean --if-exists --exit-on-error \
  /tmp/d1x-full-database.dump >/dev/null || { mark FULL_SYNTHETIC_DB_RESTORE FAIL; exit 6; }
state="$(D exec "$db" psql -U d1x -d d1x -At -v ON_ERROR_STOP=1 \
  -c "SELECT state FROM d1x_recovery_fixture WHERE id=1;")"
[[ "$state" == before ]] || { mark DATA_RECONCILIATION FAIL; exit 6; }
mark FULL_SYNTHETIC_DB_RESTORE PASS
mark DATA_RECONCILIATION PASS
mark DEV_VOLUME_RESTORED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark RESULT_GATE PASS
