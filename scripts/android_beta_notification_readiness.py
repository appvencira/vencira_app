#!/usr/bin/env python3
"""Read-only source audit for VENCIRA Android notification beta readiness.

The report is NOT Android OS permission evidence. No requests, scheduling,
network operations, key access or builds are performed.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "clients/flutter/android/app/src/main/AndroidManifest.xml"
MAIN = "clients/flutter/lib/main.dart"
ALARM = "clients/flutter/lib/notifications/android_local_alarm_port.dart"
COORDINATOR = "clients/flutter/lib/notifications/device_notice_session_coordinator.dart"


def permission_readiness(manifest: str, main: str, alarm: str, coordinator: str):
    # App-owned manifest only; Gradle's merged manifest may supply permissions.
    # This is deliberately not presented as a package-level/OS-level check.
    declares_boot = bool(re.search(
        r'<uses-permission\s+android:name="android\.permission\.RECEIVE_BOOT_COMPLETED"',
        manifest,
    ))
    declares_post = bool(re.search(
        r'<uses-permission\s+android:name="android\.permission\.POST_NOTIFICATIONS"',
        manifest,
    ))
    return {
        "APP_MANIFEST_POST_NOTIFICATIONS": "YES" if declares_post else "NO",
        "APP_MANIFEST_BOOT_PERMISSION": "YES" if declares_boot else "NO",
        "APP_MANIFEST_BOOT_RECEIVERS": (
            "YES" if "ScheduledNotificationBootReceiver" in manifest else "NO"
        ),
        "OS_PERMISSION_PREFLIGHT_IN_ALARM_PORT": (
            "YES" if "areNotificationsEnabled()" in alarm else "NO"
        ),
        "EXPLICIT_OPT_IN_GATE_IN_COORDINATOR": (
            "YES" if "enableFromExplicitAction()" in coordinator and
            "_nativeRolloutApproved" in coordinator else "NO"
        ),
        "NATIVE_NOTICE_ROLLOUT_WIRED_TO_MAIN": (
            "YES" if "DeviceNoticeSessionCoordinator(" in main or
            "AndroidLocalAlarmPort.prepare(" in main else "NO"
        ),
        "RUNTIME_OS_PERMISSION_REQUEST_IN_MAIN": (
            "YES" if "requestNotificationsPermission(" in main else "NO"
        ),
    }


def main():
    sources = [
        (ROOT / name).read_text(encoding="utf-8")
        for name in (MANIFEST, MAIN, ALARM, COORDINATOR)
    ]
    facts = permission_readiness(*sources)
    for name, value in facts.items():
        print(f"B2_C_{name}={value}")
    # Source audit is successful when it reports truthfully. Missing beta
    # capabilities are reported as NO rather than silently being accepted.
    print("B2_C_OS_PERMISSION_ON_DEVICE=NOT_VERIFIED")
    print("B2_C_MERGED_ANDROID_MANIFEST=NOT_VERIFIED")
    print("B2_C_REBOOT_RESCHEDULE_ON_DEVICE=NOT_VERIFIED")
    print("B2_C_ANDROID_READINESS_AUDIT=PASS_READONLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
