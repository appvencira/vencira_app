#!/usr/bin/env python3
"""D1-L: real Restic repository metadata verification, fail closed.

Operator must provide an authenticated Restic environment already available
on the host. This script never reads source wrappers, accepts secrets as args,
logs repository names/paths, or executes backup, forget, prune, unlock or restore.
Run ONLY after verifying the repo belongs to VENCIRA DEV. It does not certify
snapshot contents or successful restore.
"""
import datetime as dt
import json
import os
import shutil
import subprocess
import sys

def flag(k,v): print(f"D1L_{k}={v}", flush=True)

def invoke(*args):
    p=subprocess.run(["restic","--no-lock",*args],capture_output=True,
        text=True,check=False,timeout=600,env=os.environ.copy())
    # Never display stdout/stderr: can reveal repository paths or secrets.
    if p.returncode != 0:
        raise RuntimeError(f"restic_{args[0]}_failed")
    return p.stdout

def main():
    flag("READ_ONLY","YES")
    flag("RESTIC_BACKUP_EXECUTED","NO")
    flag("RESTIC_RESTORE_EXECUTED","NO")
    flag("SENSITIVE_OUTPUT","NO")
    flag("DEV_CONTAINERS_TOUCHED","NO")
    flag("LIVE_MIGRATIONS_EXECUTED","NO")
    flag("MFA_RELEASE_AUTHORIZED","NO")
    flag("NO_DEPLOY_NO_LIVE_MIGRATION","1")
    if os.environ.get("D1L_CONFIRM_REPOSITORY_IS_DEV") != "YES":
        raise RuntimeError("repository_scope_not_confirmed")
    if not os.environ.get("RESTIC_REPOSITORY"):
        raise RuntimeError("repository_not_supplied")
    if not (os.environ.get("RESTIC_PASSWORD_FILE") or
            os.environ.get("RESTIC_PASSWORD_COMMAND")):
        raise RuntimeError("restic_password_provider_not_supplied")
    if os.environ.get("RESTIC_PASSWORD"):
        raise RuntimeError("inline_password_not_allowed")
    if not shutil.which("restic"):
        raise RuntimeError("restic_not_installed")
    raw=invoke("snapshots","--json")
    records=json.loads(raw)
    if not isinstance(records,list):
        raise RuntimeError("snapshot_metadata_invalid")
    flag("SNAPSHOT_COUNT",len(records))
    if not records: raise RuntimeError("no_snapshots")
    dates=[]
    for item in records:
        if not isinstance(item,dict):
            raise RuntimeError("snapshot_record_invalid")
        stamp=item.get("time")
        if not isinstance(stamp,str):
            raise RuntimeError("snapshot_time_missing")
        # restic emits timezone-aware RFC3339 with fractional seconds.
        when=dt.datetime.fromisoformat(stamp.replace("Z","+00:00"))
        if when.tzinfo is None: raise RuntimeError("snapshot_time_naive")
        dates.append(when.astimezone(dt.timezone.utc))
    now=dt.datetime.now(dt.timezone.utc)
    recent=max(dates)
    age=max(0,int((now-recent).total_seconds()//3600))
    flag("NEWEST_SNAPSHOT_AGE_HOURS",age)
    if recent>now+dt.timedelta(minutes=10):
        raise RuntimeError("snapshot_time_in_future")
    flag("SNAPSHOT_FRESHNESS_48H","YES" if age<=48 else "NO")
    invoke("check")
    flag("RESTIC_METADATA_CHECK","PASS")
    flag("BACKUP_SCOPE","OPERATOR_CONFIRMED_NOT_INDEPENDENTLY_VERIFIED")
    flag("SNAPSHOT_PAYLOAD_FULL_READ","NOT_RUN")
    flag("RESTORE_VERIFIED","NO")
    flag("RESULT",0)
if __name__=="__main__":
    try:main()
    except (OSError, RuntimeError, ValueError, KeyError, json.JSONDecodeError,
            subprocess.TimeoutExpired) as exc:
        flag("ERROR_CLASS",type(exc).__name__)
        flag("RESULT",1)
        sys.exit(1)
