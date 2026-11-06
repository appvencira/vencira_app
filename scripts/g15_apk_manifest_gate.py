#!/usr/bin/env python3
"""Fail-closed static gate for a prebuilt G15 Android lab APK."""
import argparse
import re
import subprocess
from pathlib import Path

PACKAGE = "es.vencira.vencira.g15lab"
REQUIRED = (
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
)
RECEIVERS = (
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
)


def verify(badging: str, permissions: str, tree: str) -> None:
    if not re.search(r"^package: name='es\.vencira\.vencira\.g15lab'", badging,
                     re.MULTILINE):
        raise ValueError("G15_WRONG_PACKAGE")
    for permission in REQUIRED:
        if not re.search(
            r"^uses-permission: name='" + re.escape(permission) + r"'",
            permissions, re.MULTILINE,
        ):
            raise ValueError("G15_MISSING_DECLARED_PERMISSION")
    for receiver in RECEIVERS:
        if receiver not in tree:
            raise ValueError("G15_MISSING_NOTIFICATION_RECEIVER")
    if any(permission in permissions for permission in (
        "android.permission.SCHEDULE_EXACT_ALARM",
        "android.permission.USE_EXACT_ALARM",
    )):
        raise ValueError("G15_FORBIDDEN_EXACT_ALARM_PERMISSION")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True)
    parser.add_argument("--aapt", required=True)
    args = parser.parse_args()
    apk, aapt = Path(args.apk), Path(args.aapt)
    if not apk.is_file() or apk.stat().st_size == 0 or not aapt.is_file():
        print("G15_MANIFEST_GATE=NO_INPUT")
        return 2
    try:
        def dump(command, *args):
            return subprocess.run(
                [str(aapt), "dump", command, str(apk), *args],
                capture_output=True, text=True, check=True,
                timeout=30,
            ).stdout
        verify(dump("badging"), dump("permissions"),
               dump("xmltree", "AndroidManifest.xml"))
    except (OSError, ValueError, subprocess.SubprocessError):
        print("G15_MANIFEST_GATE=FAIL")
        return 1
    print(f"G15_APK_PACKAGE={PACKAGE}")
    print("G15_POST_NOTIFICATIONS_DECLARED=OK")
    print("G15_BOOT_RECEIVER_DECLARED=OK")
    print("G15_SCHEDULE_RECEIVER_DECLARED=OK")
    print("G15_EXACT_ALARM_PERMISSIONS=ABSENT")
    print("G15_MANIFEST_GATE=PASS")
    print("G15_OS_PERMISSIONS_ON_PHONE=NOT_VERIFIED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
