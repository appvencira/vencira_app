#!/usr/bin/env python3
"""M1-03: read-only effective PG17 privilege and Docker-network writer census.

NEVER print DB role names, container IDs, host paths, credentials, IPs or SQL rows.
A successful audit is INVENTORY_ONLY, never writer isolation or a release gate.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

PROJECTS = ("vencira_localcheck", "vencira_preview")
DB_SERVICE = "db"
SOURCE = Path("/home/vencira/vencira-localcheck")
SQL = """
SELECT json_build_object(
  'login_roles', (SELECT count(*) FROM pg_roles WHERE rolcanlogin),
  'superuser_login', (SELECT count(*) FROM pg_roles WHERE rolcanlogin AND rolsuper),
  'ddl_login', (SELECT count(*) FROM pg_roles WHERE rolcanlogin AND
                          (rolsuper OR rolcreatedb OR rolcreaterole)),
  'replication_login', (SELECT count(*) FROM pg_roles WHERE rolcanlogin AND rolreplication),
  'public_schema_create_login', (
    SELECT count(*) FROM pg_roles r
    WHERE r.rolcanlogin AND has_schema_privilege(r.oid, 'public', 'CREATE')
  ),
  'business_table_dml_login', (
    SELECT count(DISTINCT r.oid) FROM pg_roles r
    CROSS JOIN pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE r.rolcanlogin AND n.nspname='public'
      AND c.relkind IN ('r','p') AND
      has_table_privilege(r.oid, c.oid, 'INSERT,UPDATE,DELETE,TRUNCATE')
  ),
  'client_sessions_other', (
    SELECT count(*) FROM pg_stat_activity
    WHERE datname=current_database() AND pid<>pg_backend_pid()
      AND backend_type='client backend'
  ),
  'other_active_transactions', (
    SELECT count(*) FROM pg_stat_activity
    WHERE datname=current_database() AND pid<>pg_backend_pid()
      AND xact_start IS NOT NULL
  ),
  'hba_host_rules', (
    SELECT count(*) FROM pg_hba_file_rules WHERE type LIKE 'host%'
  ),
  'hba_trust_rules', (
    SELECT count(*) FROM pg_hba_file_rules WHERE auth_method='trust'
  ),
  'hba_unrestricted_address_rules', (
    SELECT count(*) FROM pg_hba_file_rules WHERE type LIKE 'host%' AND
      (address IN ('0.0.0.0/0','::/0','all','0.0.0.0','::') OR
       (address='0.0.0.0' AND netmask='0.0.0.0') OR
       (address='::' AND netmask='::'))
  ),
  'hba_invalid_rules', (
    SELECT count(*) FROM pg_hba_file_rules WHERE error IS NOT NULL
  )
)::text;
"""


def call(*argv, timeout=25):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       timeout=timeout, check=False, text=True)
    if p.returncode:
        raise RuntimeError("READONLY_SUBPROCESS_FAILED")
    return p.stdout


def db_labels(item):
    labels = item.get("Config", {}).get("Labels") or {}
    return labels.get("com.docker.compose.project"), labels.get("com.docker.compose.service")


def validate_sql_counts(value):
    expected = {
        "login_roles", "superuser_login", "ddl_login", "replication_login",
        "public_schema_create_login", "business_table_dml_login",
        "client_sessions_other", "other_active_transactions",
        "hba_host_rules", "hba_trust_rules", "hba_unrestricted_address_rules",
        "hba_invalid_rules",
    }
    if not isinstance(value, dict) or set(value) != expected:
        raise ValueError("UNEXPECTED_SQL_CENSUS_SHAPE")
    if any(type(n) is not int or n < 0 or n > 100000 for n in value.values()):
        raise ValueError("UNEXPECTED_SQL_CENSUS_COUNT")
    return value


def categorize_network_members(db_container, network_payloads, project):
    networks = (db_container.get("NetworkSettings") or {}).get("Networks") or {}
    if not networks:
        raise ValueError("DB_NETWORK_NOT_FOUND")
    projects, foreign, unlabeled, privileged, members = set(), 0, 0, 0, set()
    for net in networks:
        if net not in network_payloads:
            raise ValueError("DB_NETWORK_AUDIT_INCOMPLETE")
        item = network_payloads[net]
        if not item.get("Containers"):
            raise ValueError("NETWORK_MEMBERSHIP_MISSING")
        for container in item["Containers"].values():
            cid = container.get("Name")
            if not isinstance(cid, str) or not cid:
                raise ValueError("INVALID_NETWORK_MEMBER")
            members.add(cid)
    return {"network_count": len(networks), "member_count": len(members)}


def main():
    if os.environ.get("MB1_M103_READONLY_GAP") != "YES" or os.geteuid() != 0:
        raise RuntimeError("READONLY_ROOT_OPT_IN_REQUIRED")
    if not SOURCE.is_dir():
        raise RuntimeError("SOURCE_TREE_NOT_FOUND")
    branch = call("git", "-c", f"safe.directory={SOURCE}", "-C", str(SOURCE),
                  "branch", "--show-current").strip()
    if branch != "feature/c-ficha-independent-attachments":
        raise RuntimeError("UNEXPECTED_BRANCH")
    raw_ids = call("docker", "ps", "-q", "--filter",
                   "label=com.docker.compose.service=db").split()
    if not raw_ids:
        raise RuntimeError("NO_DATABASE_SERVICES")
    found = json.loads(call("docker", "inspect", *raw_ids))
    selected = {}
    for item in found:
        project, service = db_labels(item)
        if project in PROJECTS and service == DB_SERVICE:
            if project in selected:
                raise RuntimeError("DUPLICATE_PROJECT_DB")
            selected[project] = item
    if set(selected) != set(PROJECTS):
        raise RuntimeError("INCOMPLETE_VENCIRA_DATABASE_CENSUS")

    all_ids = call("docker", "ps", "-q").split()
    if not all_ids:
        raise RuntimeError("NO_RUNNING_CONTAINERS")
    all_containers = json.loads(call("docker", "inspect", *all_ids))
    members_by_name = {}
    for container in all_containers:
        name = container.get("Name", "").removeprefix("/")
        if not name:
            continue
        members_by_name[name] = container

    for project in PROJECTS:
        item = selected[project]
        networks = list(((item.get("NetworkSettings") or {}).get("Networks") or {}).keys())
        if not networks:
            raise RuntimeError("DATABASE_HAS_NO_NETWORK")
        network_data = {}
        for net in networks:
            result = json.loads(call("docker", "network", "inspect", net))
            if len(result) != 1:
                raise RuntimeError("NETWORK_NOT_UNIQUE")
            network_data[net] = result[0]
        summary = categorize_network_members(item, network_data, project)
        foreign = 0
        same_project = 0
        unknown = 0
        privileged = 0
        member_names = set()
        for net in networks:
            for data in (network_data[net].get("Containers") or {}).values():
                name = data.get("Name", "")
                if not name or name not in members_by_name:
                    raise RuntimeError("NETWORK_MEMBER_INSPECTION_INCOMPLETE")
                if name in member_names:
                    continue
                member_names.add(name)
                member = members_by_name[name]
                owner, _ = db_labels(member)
                if owner == project:
                    same_project += 1
                elif not owner:
                    unknown += 1
                else:
                    foreign += 1
                if (member.get("HostConfig") or {}).get("Privileged") is True:
                    privileged += 1
        if summary["member_count"] != len(member_names):
            raise RuntimeError("NETWORK_COUNT_MISMATCH")
        sql = call(
            "docker", "exec", item["Id"], "sh", "-ec",
            'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -A -t -v ON_ERROR_STOP=1 '
            '-U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"', "sh", SQL
        ).strip()
        stats = validate_sql_counts(json.loads(sql))
        print(f"MB1_M103_PROJECT={project}:NETWORKS={summary['network_count']}"
              f":MEMBERS={summary['member_count']}:SAME_PROJECT={same_project}"
              f":FOREIGN_PROJECT={foreign}:UNLABELED={unknown}:PRIVILEGED={privileged}")
        for name in sorted(stats):
            print(f"MB1_M103_{project.upper()}_{name.upper()}={stats[name]}")
        if stats["hba_invalid_rules"]:
            raise RuntimeError("PG_HBA_RULES_INVALID")
    print("MB1_M103_EFFECTIVE_ACCESS_INVENTORY=OK")
    print("MB1_M103_WRITER_ROUTES=INVENTORY_NOT_FULLY_REVIEWED")
    print("MB1_M103_EXTERNAL_SQL_ACCESS=NOT_EXCLUDED")
    print("MB1_M103_PRIVILEGED_HOST_WRITERS=NOT_EXCLUDED")
    print("MB1_M103_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("MB1_M103_AUDIT_ERROR_CLASS=" + type(exc).__name__)
        print("MB1_M103_EFFECTIVE_ACCESS_INVENTORY=FAILED")
        print("MB1_M103_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED")
        print("MB1_RELEASE_AUTHORIZED=NO")
        print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
        sys.exit(1)
