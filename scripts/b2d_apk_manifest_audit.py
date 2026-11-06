#!/usr/bin/env python3
"""B2-D: inspect a pre-existing, isolated G13 debug APK; never build/install.

Usage: python3 scripts/b2d_apk_manifest_audit.py --apk path/to/G13.apk --aapt /path/to/aapt
Missing permissions or boot receivers are reported; NOT treated as successful
physical permission/reboot tests. Rejects normal production package names.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

LAB_PACKAGE = "es.vencira.vencira.g13lab"


def evaluate_manifest(badging: str, permissions: str, tree: str):
    match = re.search(r"^package: name='([^']+)'", badging, re.MULTILINE)
    package = match.group(1) if match else None
    if package != LAB_PACKAGE:
        raise ValueError("B2_D_UNEXPECTED_OR_UNVERIFIED_APK_PACKAGE")
    declared = set(re.findall(
        r"(?:uses-permission: name=|name=)'(android\.permission\.[A-Z_]+)'",
        permissions,
    ))
    permission_labels = {
        "POST_NOTIFICATIONS": "android.permission.POST_NOTIFICATIONS",
        "RECEIVE_BOOT_COMPLETED": "android.permission.RECEIVE_BOOT_COMPLETED",
        "SCHEDULE_EXACT_ALARM": "android.permission.SCHEDULE_EXACT_ALARM",
        "USE_EXACT_ALARM": "android.permission.USE_EXACT_ALARM",
    }
    facts = {"PACKAGE": package}
    for label, name in permission_labels.items():
        facts[f"PERMISSION_{label}"] = "DECLARED" if name in declared else "NOT_DECLARED"
    facts["BOOT_RECEIVER"] = (
        "DECLARED" if "ScheduledNotificationBootReceiver" in tree
        else "NOT_DECLARED"
    )
    facts["SCHEDULED_RECEIVER"] = (
        "DECLARED" if "ScheduledNotificationReceiver" in tree
        else "NOT_DECLARED"
    )
    return facts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True)
    parser.add_argument("--aapt", required=True)
    args = parser.parse_args()
    apk = Path(args.apk)
    aapt = Path(args.aapt)
    if not apk.is_file() or apk.stat().st_size == 0:
        print("B2_D_APK=NOT_FOUND_OR_EMPTY")
        return 2
    if not aapt.is_file():
        print("B2_D_AAPT=NOT_FOUND")
        return 2
    try:
        def dump(*command):
            result = subprocess.run([str(aapt), "dump", *command, str(apk)],
                                    capture_output=True, text=True, timeout=30,
                                    check=True)
            return result.stdout

        facts = evaluate_manifest(
            dump("badging"),
            dump("permissions"),
            dump("xmltree", "AndroidManifest.xml"),
        )
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        # No stderr of aapt: paths/identifiers from build environment may leak.
        print(f"B2_D_AUDIT=DENIED_{type(exc).__name__.upper()}")
        return 1
    for name, value in facts.items():
        print(f"B2_D_{name}={value}")
    print("B2_D_OS_PERMISSION_GRANTED=NOT_VERIFIED")
    print("B2_D_REBOOT_RESCHEDULE_ON_PHONE=NOT_VERIFIED")
    print("B2_D_LAB_DEBUG_ONLY=1")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    print("B2_D_MANIFEST_AUDIT=PASS_READONLY")
    return 0


if __name__ == "__main__":
    sys.exit(main())
