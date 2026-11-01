"""MB1 G2/G3 independent role and writer-boundary evidence review.

Never contacts a database, host, Docker daemon or deployed application.
Positive attestations are only review candidates, never operational authorization.
"""
import argparse
import json
from pathlib import Path

ROLES=("app_not_superuser","app_no_createdb","app_no_createrole",
       "app_no_bypassrls","app_no_ddl_on_runtime_schema",
       "backup_and_admin_separate_from_app",
       "application_connect_restricted")
BOUNDARY=("api_ingress_quiesced","scheduled_writers_quiesced",
          "sql_sessions_drained","admin_sql_writers_excluded",
          "external_sql_writers_excluded","object_fs_writers_excluded",
          "journal_fs_writers_excluded","host_docker_writers_excluded",
          "all_resources_same_capture_epoch")
ALL=ROLES+BOUNDARY

def evaluate(candidate):
    if not isinstance(candidate,dict) or set(candidate)!=set(ALL):
        raise ValueError("INVALID_EVIDENCE_KEYS")
    unresolved=[]
    for key in ALL:
        val=candidate[key]
        if not isinstance(val,dict) or set(val)!={"verified","artifact"}:
            raise ValueError("INVALID_EVIDENCE_RECORD")
        if type(val["verified"]) is not bool or not isinstance(val["artifact"],str):
            raise ValueError("INVALID_EVIDENCE_TYPE")
        if len(val["artifact"])>256 or (val["verified"] and not val["artifact"].strip()):
            raise ValueError("INVALID_ARTIFACT")
        if not val["verified"]:
            unresolved.append(key)
    return {"unresolved":unresolved,"independent_review_required":True,
            "operational_authorized":False}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("candidate",type=Path)
    args=parser.parse_args()
    result=evaluate(json.loads(args.candidate.read_text(encoding="utf-8")))
    print("MB1_G23_REQUIREMENTS="+str(len(ALL)))
    print("MB1_G23_UNRESOLVED="+str(len(result["unresolved"])))
    print("MB1_G23_INDEPENDENT_REVIEW_REQUIRED=YES")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 0 if result["unresolved"] else 3

if __name__=="__main__":
    raise SystemExit(main())
