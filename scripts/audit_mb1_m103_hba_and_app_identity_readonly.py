#!/usr/bin/env python3
"""M1-03: targeted read-only PostgreSQL HBA + API SQL identity classification.

Run on source VPS ONLY with explicit opt-in; never print identities, HBA
addresses, credentials, docker container names, raw SQL or env variables.
Neither a connection probe nor an authentication change is performed.
"""
import json
import os
import subprocess
import sys

PROJECTS = ("vencira_localcheck", "vencira_preview")
SQL = """
WITH r AS (
  SELECT type, auth_method, address, netmask,
    (type LIKE 'host%' AND (
      address IN ('all', '0.0.0.0/0', '::/0', '0.0.0.0', '::') OR
      (address = '0.0.0.0' AND netmask = '0.0.0.0') OR
      (address = '::' AND netmask = '::')
    )) AS broad
  FROM pg_hba_file_rules
)
SELECT json_build_object(
  'local_trust',count(*) FILTER (WHERE type = 'local' AND auth_method = 'trust'),
  'host_trust',count(*) FILTER (WHERE type LIKE 'host%' AND auth_method = 'trust'),
  'broad_host',count(*) FILTER (WHERE broad),
  'broad_host_trust',count(*) FILTER (WHERE broad AND auth_method = 'trust'),
  'broad_host_scram',count(*) FILTER (WHERE broad AND auth_method = 'scram-sha-256'),
  'broad_host_md5',count(*) FILTER (WHERE broad AND auth_method = 'md5'),
  'broad_host_password',count(*) FILTER (WHERE broad AND auth_method = 'password'),
  'broad_host_other',count(*) FILTER (WHERE broad AND auth_method NOT IN
      ('trust','scram-sha-256','md5','password')),
  'invalid_rules',count(*) FILTER (WHERE auth_method IS NULL)
)::text
FROM r;
"""
IDENTITY_SQL = "SELECT rolsuper FROM pg_roles WHERE rolname=current_user;"


def call(*args):
    proc = subprocess.run(args, capture_output=True, text=True, check=False, timeout=30)
    if proc.returncode:
        raise RuntimeError("READ_ONLY_SUBPROCESS_FAILED")
    return proc.stdout


def config_env(item, key):
    raw = (item.get("Config") or {}).get("Env") or []
    vals = [v[len(key)+1:] for v in raw if isinstance(v, str) and v.startswith(key+"=")]
    if len(vals) != 1:
        return None
    return vals[0]


def parse_counts(raw):
    expected = {
        "local_trust","host_trust","broad_host","broad_host_trust",
        "broad_host_scram","broad_host_md5","broad_host_password",
        "broad_host_other","invalid_rules",
    }
    value = json.loads(raw)
    if type(value) is not dict or set(value) != expected:
        raise ValueError("HBA_UNEXPECTED_FIELDS")
    if any(type(x) is not int or x < 0 or x > 500 for x in value.values()):
        raise ValueError("HBA_INVALID_COUNT")
    if value["broad_host"] != sum(value[k] for k in (
        "broad_host_trust","broad_host_scram","broad_host_md5",
        "broad_host_password","broad_host_other",
    )):
        raise ValueError("HBA_BROAD_CLASSIFICATION_INCOMPLETE")
    if value["broad_host_trust"] > value["host_trust"]:
        raise ValueError("HBA_BROAD_TRUST_EXCEEDS_HOST")
    return value


def classify_identity(app_user, db_user, role_is_super):
    if app_user is None or db_user is None or role_is_super not in ("t", "f"):
        return "UNKNOWN"
    if not app_user or not db_user:
        return "UNKNOWN"
    if app_user != db_user:
        return "NOT_MATCHED"
    return "YES" if role_is_super == "t" else "NO"


def main():
    if os.geteuid() != 0 or os.environ.get("MB1_M103_HBA_DETAIL_READONLY") != "YES":
        raise RuntimeError("ROOT_READONLY_OPT_IN_REQUIRED")
    containers = call("docker","ps","-q").split()
    if not containers:
        raise RuntimeError("NO_DOCKER_CONTAINERS")
    inspected = json.loads(call("docker","inspect",*containers))
    selected = {}
    for item in inspected:
        labels = (item.get("Config") or {}).get("Labels") or {}
        project = labels.get("com.docker.compose.project")
        service = labels.get("com.docker.compose.service")
        if project in PROJECTS and service in ("api","db"):
            key = (project,service)
            if key in selected:
                raise RuntimeError("DUPLICATE_VENCIRA_SERVICE")
            selected[key] = item
    if len(selected) != 4:
        raise RuntimeError("VENCIRA_PROJECT_SERVICE_MISSING")
    for project in PROJECTS:
        db = selected[project,"db"]
        api = selected[project,"api"]
        sql = call("docker","exec",db["Id"],"sh","-ec",
          'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -A -t -v ON_ERROR_STOP=1 '
          '-U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"',
          "sh",SQL).strip()
        counts = parse_counts(sql)
        superuser = call("docker","exec",db["Id"],"sh","-ec",
          'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -A -t -v ON_ERROR_STOP=1 '
          '-U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"',
          "sh",IDENTITY_SQL).strip()
        matching = classify_identity(
            config_env(api,"POSTGRES_USER"),config_env(db,"POSTGRES_USER"),superuser
        )
        print(f"MB1_M103_DETAIL_PROJECT={project}")
        for key, val in sorted(counts.items()):
            print(f"MB1_M103_DETAIL_{project.upper()}_{key.upper()}={val}")
        print(f"MB1_M103_DETAIL_{project.upper()}_API_USES_DB_SUPERUSER={matching}")
        if counts["invalid_rules"]:
            raise RuntimeError("HBA_INVALID_RULES")
        if counts["broad_host_trust"] or counts["host_trust"]:
            print(f"MB1_M103_DETAIL_{project.upper()}_NETWORK_TRUST_RISK=REVIEW_REQUIRED")
        if matching == "YES":
            print(f"MB1_M103_DETAIL_{project.upper()}_API_SUPERUSER_RISK=REVIEW_REQUIRED")
    print("MB1_M103_HBA_IDENTITY_DETAIL=OK")
    print("MB1_M103_PUBLIC_INTERNET_EXPOSURE=NOT_DEMONSTRATED")
    print("MB1_M103_WRITER_EXCLUSION=NOT_VERIFIED")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("MB1_M103_HBA_IDENTITY_ERROR_CLASS="+type(exc).__name__)
        print("MB1_M103_HBA_IDENTITY_DETAIL=FAILED")
        print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
        print("MB1_RELEASE_AUTHORIZED=NO")
        print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
        sys.exit(1)
