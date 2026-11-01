"""Fail-closed G1-G3 evidence adjudicator; not operational freeze."""
import json
from pathlib import Path

REQUIRED = (
    "api_writers_reviewed", "scheduler_indirections_reviewed",
    "admin_writers_reviewed", "external_sql_clients_reviewed",
    "object_fs_writers_reviewed", "journal_writers_reviewed",
    "app_sql_non_superuser_verified", "api_role_no_ddl_verified",
    "backup_admin_credentials_segregated", "all_sql_sessions_drained",
    "noncooperative_sql_writers_excluded", "noncooperative_fs_writers_excluded",
    "host_and_docker_privilege_boundary_verified",
    "cross_resource_snapshot_verified",
)

def adjudicate(evidence):
    if not isinstance(evidence, dict) or set(evidence) != set(REQUIRED):
        raise ValueError("G123_EVIDENCE_SHAPE")
    for key, record in evidence.items():
        if not isinstance(record, dict) or set(record) != {"verified", "artifact"}:
            raise ValueError("G123_EVIDENCE_RECORD")
        if type(record["verified"]) is not bool:
            raise ValueError("G123_EVIDENCE_BOOLEAN")
        if not isinstance(record["artifact"], str) or len(record["artifact"]) > 256:
            raise ValueError("G123_ARTIFACT_INVALID")
        if record["verified"] and not record["artifact"].strip():
            raise ValueError("G123_POSITIVE_WITHOUT_EVIDENCE")
    gaps = [k for k in REQUIRED if not evidence[k]["verified"]]
    return {"reviewed": len(REQUIRED), "blocked": gaps,
            "operational_freeze_verified": False,
            "closure_ready": len(gaps) == 0}

def main():
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument("evidence",type=Path)
    args=parser.parse_args()
    result=adjudicate(json.loads(args.evidence.read_text(encoding="utf-8")))
    print("MB1_G123_FIELDS_REVIEWED="+str(result["reviewed"]))
    print("MB1_G123_UNVERIFIED_COUNT="+str(len(result["blocked"])))
    print("MB1_G123_DECISION="+("REVIEW_REQUIRED" if result["closure_ready"] else "BLOCKED"))
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    if result["closure_ready"]:
        print("MB1_G123_SELF_ASSERTED_EVIDENCE=INDEPENDENT_REVIEW_REQUIRED")
    return 0 if not result["closure_ready"] else 3

if __name__=="__main__":
    raise SystemExit(main())
