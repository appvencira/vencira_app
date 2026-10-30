#!/usr/bin/env bash
# M1-03: read-only database role/session capabilities, no role names or credentials printed.
set -Eeuo pipefail
if [ "${MB1_READONLY_SQL_AUDIT:-}" != YES ]; then echo "MB1_SQL_AUDIT_OPT_IN=REQUIRED"; exit 2; fi
python3 - <<'PY'
import json,subprocess,sys
def cmd(*args):
    return subprocess.run(args,capture_output=True,text=True,timeout=20)
try:
    ps=cmd("docker","ps","-q","--filter","label=com.docker.compose.service=db")
    if ps.returncode: raise RuntimeError("docker ps failed")
    ids=ps.stdout.splitlines()
    if not ids: raise RuntimeError("no database containers")
    details=cmd("docker","inspect",*ids)
    if details.returncode: raise RuntimeError("inspect failed")
    inspected=json.loads(details.stdout)
    checked=0
    for item in inspected:
        labels=(item.get("Config") or {}).get("Labels") or {}
        project=labels.get("com.docker.compose.project","")
        if project not in ("vencira_localcheck","vencira_preview"): continue
        # SQL is constant and read-only; connection credentials stay inside DB container.
        query=("SELECT (SELECT count(*) FROM pg_roles WHERE rolcanlogin),"
               "(SELECT count(*) FROM pg_roles WHERE rolsuper OR rolcreatedb OR rolcreaterole),"
               "(SELECT count(*) FROM pg_stat_activity WHERE datname=current_database())")
        run=cmd("docker","exec",item["Id"],"sh","-ec",
                'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -A -t -v ON_ERROR_STOP=1 '
                '-U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"', "sh",query)
        if run.returncode: raise RuntimeError("SQL read-only query failed")
        fields=run.stdout.strip().split("|")
        if len(fields)!=3 or any(not x.isdigit() for x in fields):
            raise RuntimeError("unexpected SQL result")
        print(f"MB1_SQL_PROJECT={project}:LOGIN_ROLES={fields[0]}:ELEVATED_ROLES={fields[1]}:DB_SESSIONS={fields[2]}")
        checked+=1
    if checked!=2: raise RuntimeError("expected two distinct VENCIRA DBs")
    print("MB1_SQL_READONLY_ROLE_CENSUS=OK")
    print("MB1_SQL_ROLE_GRANTS_AND_NETWORK_AUTH=NOT_FULLY_VERIFIED")
    print("MB1_SQL_ACTIVE_WRITER_EXCLUSION=NOT_VERIFIED")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
except Exception as exc:
    print("MB1_SQL_READONLY_ROLE_CENSUS=FAILED")
    print("MB1_SQL_AUDIT_ERROR_CLASS="+type(exc).__name__)
    sys.exit(1)
PY
