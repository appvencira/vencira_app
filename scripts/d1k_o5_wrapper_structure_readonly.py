#!/usr/bin/env python3
"""D1-K: bounded, read-only structural review of protected O5 shell wrappers.

Never executes wrappers, source, shell, backup commands, systemctl start,
restic or rclone. Prints only fixed-vocabulary classifications, never raw
paths, commands, variables, arguments, file content, or secrets.
Keyword/structure heuristics are NOT proof of actual backup activity.
"""
from pathlib import Path
import os
import re
import shlex
import subprocess
import sys

UNITS = {"BACKUP": "vencira-o5-backup.service",
         "HEALTH": "vencira-o5-health.service"}
LIMIT = 262144
EXECUTION_WORDS = (
    "exec", "bash", "sh", "python", "python3", "systemctl", "runuser",
    "sudo", "su", "env", "restic", "rclone", "docker", "pg_dump",
    "pg_dumpall", "pg_restore", "true", "false", "exit", ":", "source", ".",
)
def mark(k, v):
    print("D1K_" + k + "=" + str(v), flush=True)

def bounded_read(path):
    if path.is_symlink() or not path.is_file():
        raise RuntimeError("file not regular or is symlink")
    if path.stat().st_size > LIMIT:
        raise RuntimeError("file too large")
    return path.read_text(encoding="utf-8", errors="replace")

def wrapper(unit):
    p = subprocess.run(["systemctl", "show", unit, "-p", "FragmentPath",
                        "--value"], capture_output=True, text=True,
                       timeout=12, check=False)
    if p.returncode: raise RuntimeError("systemd unit unavailable")
    path = p.stdout.strip()
    if not path.startswith("/"): raise RuntimeError("unit path not absolute")
    src = bounded_read(Path(path))
    section = None
    starts = []
    for line in src.splitlines():
        t = line.strip()
        if t.startswith("[") and t.endswith("]"): section=t.lower()
        elif section=="[service]" and t.startswith("ExecStart="):
            starts.append(t.split("=",1)[1])
    if len(starts)!=1: raise RuntimeError("unexpected ExecStart")
    tokens=shlex.split(starts[0])
    if len(tokens)!=1: raise RuntimeError("non-direct execution")
    cmd=tokens[0].lstrip("-+!:@")
    if not cmd.startswith("/"): raise RuntimeError("relative execution")
    return Path(cmd)

def analyze(label, src):
    lines=src.splitlines()
    commands=[]
    for line in lines:
        t=line.strip()
        if not t or t.startswith("#"): continue
        commands.append(t)
    mark(label+"_SOURCE_NONEMPTY_LINES", len(commands))
    mark(label+"_SOURCE_SIZE_CLASS",
         "SMALL" if len(src)<1024 else "MEDIUM" if len(src)<8192 else "LARGE")
    mark(label+"_SHEBANG_PRESENT", "YES" if src.startswith("#!") else "NO")
    has_shell_control = bool(re.search(r"(^|\\n)\\s*(?:if|for|while|case|function)\\b",src))
    mark(label+"_SHELL_CONTROL_FLOW", "YES" if has_shell_control else "NO")
    # Source constructs can be nested and dynamically evaluated; lexical only.
    suspicious_passthrough=bool(re.search(
        r"(^|\\n)\\s*(?:(?:exit\\s+0)|true|:)\\s*(?:[#;].*)?$",src))
    mark(label+"_EXIT_SUCCESS_STATEMENT_PRESENT",
         "YES" if suspicious_passthrough else "NO")
    # No actual command tokens are shown, even basename or line number.
    wrappers=bool(re.search(
        r"(^|\\n)\\s*(?:exec\\s+)?(?:/|(?:bash|sh|python3?|env|sudo|runuser|systemctl|source)\\b|\\.\\s+/)",
        src))
    mark(label+"_DELEGATION_INDICATOR",
         "YES" if wrappers else "NO")
    remote=bool(re.search(r"\\b(?:ssh|scp|rsync|curl|wget)\\b",src))
    mark(label+"_NETWORK_TRANSFER_KEYWORD",
         "YES" if remote else "NO")
    match_tool=bool(re.search(
        r"\\b(?:restic|rclone|pg_dump|pg_dumpall|pg_restore|docker)\\b",src))
    mark(label+"_BACKUP_TOOL_KEYWORD",
         "YES" if match_tool else "NO")
    # This is explicitly not a proof of effectiveness.
    mark(label+"_ACTUAL_BACKUP_ACTIVITY", "NOT_VERIFIED")

def main():
    mark("READ_ONLY", "YES")
    mark("WRAPPERS_EXECUTED", "NO")
    mark("HELPER_CONTENT_OUTPUT", "NO")
    mark("CREDENTIALS_ACCESSED", "NO")
    mark("RESTIC_EXECUTED", "NO")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    mark("MFA_RELEASE_AUTHORIZED", "NO")
    mark("NO_DEPLOY_NO_LIVE_MIGRATION", "1")
    if os.geteuid() != 0: raise RuntimeError("read-only root classification required")
    for label, unit in UNITS.items():
        src=bounded_read(wrapper(unit))
        analyze(label,src)
    mark("SNAPSHOT_VERIFIED", "NO")
    mark("RESTORE_VERIFIED", "NO")
    mark("RESULT", 0)
if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,ValueError,subprocess.TimeoutExpired) as exc:
        mark("ERROR_TYPE",type(exc).__name__)
        mark("RESULT",1)
        sys.exit(1)
