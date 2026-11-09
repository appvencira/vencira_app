#!/usr/bin/env python3
"""D1-F: inspect O5 systemd service topology WITHOUT running backup commands.

Reads only the installed service unit text and systemd metadata. Never
loads EnvironmentFile contents, secrets, unit credentials, backup repositories,
database, logs or snapshot payloads. Reports no absolute paths or arguments.
"""
from pathlib import Path
import re
import subprocess
import sys

UNITS = ("vencira-o5-backup.service", "vencira-o5-health.service")
SAFE_BASENAME = re.compile(r"^[a-zA-Z0-9_.@-]{1,96}$")
KNOWN_ENV_NAMES = {
    "RESTIC_REPOSITORY", "RESTIC_PASSWORD_FILE", "RESTIC_PASSWORD_COMMAND",
    "RCLONE_CONFIG", "RCLONE_CONFIG_PASS", "VENCIRA_BACKUP_ENV",
}

def show(name, value):
    print("D1F_" + name + "=" + str(value), flush=True)

def prop(unit, key):
    p = subprocess.run(
        ["systemctl", "show", unit, "--property=" + key, "--value"],
        capture_output=True, text=True, timeout=12, check=False)
    if p.returncode:
        raise RuntimeError("systemctl show failed")
    return p.stdout.strip()

def safe_name(value):
    name = Path(value).name
    return name if SAFE_BASENAME.fullmatch(name) else "REDACTED"

def check_service(unit):
    label = unit.replace("vencira-", "").replace(".", "_").replace("-", "_").upper()
    fragment = prop(unit, "FragmentPath")
    load = prop(unit, "LoadState")
    show(label + "_LOADED", "YES" if load == "loaded" else "NO")
    if load != "loaded":
        raise RuntimeError("service not loaded")
    if not fragment.startswith("/") or not Path(fragment).is_file():
        show(label + "_FRAGMENT_READABLE", "NO")
        raise RuntimeError("installed service fragment unavailable")
    # Never emit content of unit files: a unit may embed sensitive arguments.
    raw = Path(fragment).read_text(encoding="utf-8", errors="replace")
    show(label + "_FRAGMENT_READABLE", "YES")
    show(label + "_FRAGMENT_BASENAME", safe_name(fragment))
    active_section = ""
    exec_count = 0
    envfile_count = 0
    direct_environment = False
    helper_names = set()
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            active_section = line.lower()
        if not line or line.startswith(("#", ";")) or active_section != "[service]":
            continue
        key, sep, value = line.partition("=")
        if not sep:
            continue
        key = key.strip()
        if key in ("ExecStart", "ExecStartPre", "ExecStartPost") and value.strip():
            exec_count += 1
            # For recognizable command scripts only, report their basename,
            # never shell command arguments, absolute paths or credentials.
            for tok in re.findall(r"(?:^|\\s)(/[a-zA-Z0-9_./-]+\\.(?:sh|py))(?=\\s|$)", value):
                if tok.startswith("/home/") or tok.startswith("/opt/") or tok.startswith("/usr/local/"):
                    helper_names.add(safe_name(tok))
        elif key == "EnvironmentFile":
            envfile_count += 1
        elif key == "Environment":
            direct_environment = True
    show(label + "_EXEC_DIRECTIVES_COUNT", exec_count)
    show(label + "_ENVFILE_DIRECTIVES_COUNT", envfile_count)
    show(label + "_DIRECT_ENVIRONMENT_PRESENT",
         "YES" if direct_environment else "NO")
    for name in sorted(helper_names):
        show(label + "_HELPER_BASENAME", name)
    show(label + "_HELPER_DISCOVERED",
         "YES" if helper_names else "NO")
    # No inference of backup success from unit execution.
    show(label + "_SNAPSHOT_VERIFIED", "NO")

def main():
    show("READ_ONLY", "YES")
    show("UNIT_CONTENT_PRINTED", "NO")
    show("ENVFILE_CONTENT_READ", "NO")
    show("RESTIC_EXECUTED", "NO")
    show("RESTORE_EXECUTED", "NO")
    show("MFA_RELEASE_AUTHORIZED", "NO")
    show("NO_DEPLOY_NO_LIVE_MIGRATION", 1)
    for unit in UNITS:
        check_service(unit)
    show("O5_BACKUP_REPOSITORY_IDENTIFIED", "NO")
    show("O5_SNAPSHOT_FRESHNESS_VERIFIED", "NO")
    show("O5_RESTORE_VERIFIED", "NO")
    show("RESULT", 0)

if __name__ == "__main__":
    try:
        main()
    except (OSError, UnicodeError, RuntimeError, subprocess.TimeoutExpired) as exc:
        show("ERROR_TYPE", type(exc).__name__)
        show("RESULT", 1)
        sys.exit(1)
