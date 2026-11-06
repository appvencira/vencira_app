#!/usr/bin/env python3
"""B2-C read-only source inventory of Android notification release boundaries.

This is NOT a merged-manifest test, OS permission check or installation test.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = "{http://schemas.android.com/apk/res/android}"


def inspect(manifest_text: str, flutter_main: str, adapter: str, coordinator: str) -> dict[str, bool]:
    root = ET.fromstring(manifest_text)
    permissions = {
        item.attrib.get(ANDROID + "name")
        for item in root.findall("uses-permission")
    }
    application = root.find("application")
    receivers = (
        [item.attrib.get(ANDROID + "name", "") for item in application.findall("receiver")]
        if application is not None else []
    )
    return {
        "manifest_backup_disabled":
            application is not None and application.attrib.get(ANDROID + "allowBackup") == "false",
        "no_privileged_exact_alarm_permissions":
            "android.permission.SCHEDULE_EXACT_ALARM" not in permissions
            and "android.permission.USE_EXACT_ALARM" not in permissions,
        "scheduling_receivers_not_operationally_registered":
            not any("ScheduledNotification" in name for name in receivers),
        "android_startup_revoke_before_web_access":
            "DeviceNoticeStartupGate(" in flutter_main
            and "AndroidWebAccessScreen()" in flutter_main
            and "cancelPreviousAlarms: _revokeNativeAlarms" in flutter_main,
        "alarm_scheduling_not_initialized_from_main":
            "AndroidLocalAlarmPort.prepare(" not in flutter_main
            and "DeviceNoticeSessionCoordinator(" not in flutter_main,
        "os_permission_check_before_scheduling":
            "areNotificationsEnabled()" in adapter
            and "explicitUserOptIn" in adapter
            and "encryptedInventoryVerified" in adapter,
        "native_rollout_default_disabled":
            "bool nativeRolloutApproved = false" in coordinator
            and "!_nativeRolloutApproved" in coordinator,
    }


def audit(root: Path = ROOT) -> dict[str, bool]:
    def read(relative: str) -> str:
        return (root / relative).read_text(encoding="utf-8")
    return inspect(
        read("clients/flutter/android/app/src/main/AndroidManifest.xml"),
        read("clients/flutter/lib/main.dart"),
        read("clients/flutter/lib/notifications/android_local_alarm_port.dart"),
        read("clients/flutter/lib/notifications/device_notice_session_coordinator.dart"),
    )


def main() -> int:
    checks = audit()
    for name, ok in checks.items():
        print(f"B2C_ANDROID_{name.upper()}={'OK' if ok else 'FAIL'}")
    print(f"B2C_ANDROID_BOUNDARY={'PASS' if all(checks.values()) else 'FAIL'}")
    print("B2C_ANDROID_MERGED_MANIFEST=NOT_CHECKED")
    print("B2C_ANDROID_OS_PERMISSION=NOT_CHECKED")
    print("B2C_ANDROID_REBOOT_RESCHEDULE=NOT_IMPLEMENTED")
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
