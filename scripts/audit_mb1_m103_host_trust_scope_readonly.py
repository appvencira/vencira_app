#!/usr/bin/env python3
"""M1-03 targeted read-only scope census for PostgreSQL host/trust HBA entries.

Addresses and masks are handled ONLY in memory, never printed or persisted.
This census does not prove network reachability or which earlier HBA rule wins.
"""
import ipaddress
import json
import os
import subprocess
import sys

PROJECTS = ("vencira_localcheck", "vencira_preview")
SQL = """
SELECT coalesce(json_agg(json_build_object('address',address,'mask',netmask)),
'[]'::json)::text FROM pg_hba_file_rules
WHERE type LIKE 'host%' AND auth_method='trust' AND error IS NULL;
"""


def scope(address, mask):
    if not isinstance(address, str) or not address:
        return "UNRESOLVED"
    if mask is not None and not isinstance(mask, str):
        return "UNRESOLVED"
    try:
        cidr = address if mask in (None, "") else f"{address}/{mask}"
        network = ipaddress.ip_network(cidr, strict=False)
    except ValueError:
        return "UNRESOLVED"
    return ("LOOPBACK_IPV4" if network.version == 4 else "LOOPBACK_IPV6") if network.is_loopback else "NONLOOPBACK"


def classify(rows):
    if type(rows) is not list or len(rows) > 1000:
        raise ValueError("HBA_SCOPE_INVALID_LIST")
    results = {k: 0 for k in ("LOOPBACK_IPV4","LOOPBACK_IPV6","NONLOOPBACK","UNRESOLVED")}
    for item in rows:
        if type(item) is not dict or set(item) != {"address","mask"}:
            raise ValueError("HBA_SCOPE_INVALID_ROW")
        results[scope(item["address"], item["mask"])] += 1
    return results


def run(*args):
    p = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, check=False, timeout=30)
    if p.returncode:
        raise RuntimeError("READONLY_SUBPROCESS_FAILED")
    return p.stdout


def main():
    if os.geteuid() != 0 or os.environ.get("MB1_M103_HOST_TRUST_SCOPE") != "YES":
        raise ValueError("ROOT_AND_OPT_IN_REQUIRED")
    ids = run("docker","ps","-q","--filter","label=com.docker.compose.service=db").split()
    if not ids:
        raise RuntimeError("NO_DB_CONTAINERS")
    containers=json.loads(run("docker","inspect",*ids))
    selected={}
    for item in containers:
        labels=(item.get("Config") or {}).get("Labels") or {}
        project=labels.get("com.docker.compose.project")
        service=labels.get("com.docker.compose.service")
        if project in PROJECTS and service == "db":
            if project in selected:
                raise RuntimeError("DUPLICATE_DB")
            selected[project]=item["Id"]
    if set(selected)!=set(PROJECTS):
        raise RuntimeError("DB_CENSUS_INCOMPLETE")
    for project in PROJECTS:
        raw=run("docker","exec",selected[project],"sh","-ec",
           'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -A -t -v ON_ERROR_STOP=1 '
           '-U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"', "sh", SQL).strip()
        counts=classify(json.loads(raw))
        for name,n in sorted(counts.items()):
            print(f"MB1_M103_TRUST_SCOPE_{project.upper()}_{name}={n}")
        print(f"MB1_M103_TRUST_SCOPE_{project.upper()}_HOST_TRUST_TOTAL={sum(counts.values())}")
        print(f"MB1_M103_TRUST_SCOPE_{project.upper()}_RISK=" +
              ("NONLOOPBACK_OR_UNRESOLVED" if counts["NONLOOPBACK"] or counts["UNRESOLVED"] else "LOOPBACK_ONLY_OBSERVED"))
    print("MB1_M103_TRUST_SCOPE_READONLY=OK")
    print("MB1_M103_NETWORK_REACHABILITY=NOT_VERIFIED")
    print("MB1_M103_API_SUPERUSER_CHANGE=NOT_AUTHORIZED")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("MB1_M103_TRUST_SCOPE_ERROR_CLASS="+type(exc).__name__)
        print("MB1_M103_TRUST_SCOPE_READONLY=FAILED")
        print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
        print("MB1_RELEASE_AUTHORIZED=NO")
        print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
        sys.exit(1)
