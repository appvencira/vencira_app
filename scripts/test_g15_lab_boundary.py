#!/usr/bin/env python3
"""G15 source and pure manifest guards; no Dart/Gradle/phone required."""
import unittest
from pathlib import Path

from g15_apk_manifest_gate import verify

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class G15LabBoundaryTests(unittest.TestCase):
    def test_only_debug_lab_variant_and_separate_app_id(self):
        gradle = read("clients/flutter/android/app/build.gradle.kts")
        self.assertIn('VENCIRA_G15_LAB_BUILD', gradle)
        self.assertIn('applicationIdSuffix = ".g15lab"', gradle)
        self.assertIn('src/g15lab/AndroidManifest.xml', gradle)
        self.assertIn('Physical Android labs must never build release/profile', gradle)
        self.assertNotIn('g15_lab', read("clients/flutter/lib/main.dart"))
        self.assertNotIn('VENCIRA_G15_LAB_BUILD', read("clients/flutter/lib/main.dart"))

    def test_lab_has_no_network_or_customer_dependencies(self):
        main = read("clients/flutter/lib/g15_lab_main.dart")
        port = read("clients/flutter/lib/g15_lab/physical_notice_checks.dart")
        self.assertIn("g15LabEnabled", main)
        self.assertIn("kReleaseMode", main)
        self.assertIn("Platform.isAndroid", main)
        self.assertIn("requestNotificationsPermission()", port)
        self.assertIn("areNotificationsEnabled()", port)
        self.assertIn("AndroidScheduleMode.inexactAllowWhileIdle", port)
        self.assertIn("cancelSyntheticNotice()", port)
        self.assertIn("pendingNotificationRequests()", port)
        self.assertIn("G15_PERMISSION_REQUIRED", port)
        for forbidden in ("VenciraApi", "HttpClient(", "Dio(", "login(", "dev.vencira.es"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, main + port)

    def test_manifest_overlay_is_g15_only_and_requires_reboot_receivers(self):
        manifest = read("clients/flutter/android/app/src/g15lab/AndroidManifest.xml")
        self.assertIn("android.permission.RECEIVE_BOOT_COMPLETED", manifest)
        self.assertIn("android.permission.POST_NOTIFICATIONS", manifest)
        self.assertIn("ScheduledNotificationReceiver", manifest)
        self.assertIn("ScheduledNotificationBootReceiver", manifest)
        self.assertNotIn("SCHEDULE_EXACT_ALARM", manifest)
        self.assertNotIn("USE_EXACT_ALARM", manifest)
        self.assertIn('android.permission.INTERNET" tools:node="remove"', manifest)
        self.assertNotIn("ScheduledNotificationBootReceiver",
                         read("clients/flutter/android/app/src/main/AndroidManifest.xml"))

    def test_compiled_gate_accepts_only_laboratory_package(self):
        badging = "package: name='es.vencira.vencira.g15lab' versionCode='1'"
        perms = "".join(
            f"uses-permission: name='{p}'\n" for p in (
                "android.permission.POST_NOTIFICATIONS",
                "android.permission.RECEIVE_BOOT_COMPLETED",
            )
        )
        tree = ("com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver\n"
                "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver")
        verify(badging, perms, tree)
        with self.assertRaises(ValueError):
            verify("package: name='es.vencira.vencira'", perms, tree)
        with self.assertRaises(ValueError):
            verify(badging, perms.replace("RECEIVE_BOOT_COMPLETED", "INTERNET"), tree)
        with self.assertRaises(ValueError):
            verify(badging, perms, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver")
        with self.assertRaises(ValueError):
            verify(badging, perms + "android.permission.SCHEDULE_EXACT_ALARM", tree)
        with self.assertRaises(ValueError):
            verify(badging, perms + "uses-permission: name=\'android.permission.INTERNET\'", tree)


if __name__ == "__main__":
    unittest.main()
