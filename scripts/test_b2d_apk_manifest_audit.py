"""B2-D pure aapt-output parser tests; no SDK/APK/device required."""
import unittest

from b2d_apk_manifest_audit import evaluate_manifest


class ManifestAuditTests(unittest.TestCase):
    def test_matching_isolated_package_with_merged_plugin_permissions(self):
        facts = evaluate_manifest(
            "package: name='es.vencira.vencira.g13lab' versionCode='1'",
            "uses-permission: name='android.permission.INTERNET'\n"
            "uses-permission: name='android.permission.POST_NOTIFICATIONS'\n",
            "E: manifest\n E: receiver android:name='ScheduledNotificationReceiver'",
        )
        self.assertEqual(facts["PERMISSION_POST_NOTIFICATIONS"], "DECLARED")
        self.assertEqual(facts["PERMISSION_RECEIVE_BOOT_COMPLETED"], "NOT_DECLARED")
        self.assertEqual(facts["SCHEDULED_RECEIVER"], "DECLARED")
        self.assertEqual(facts["BOOT_RECEIVER"], "NOT_DECLARED")

    def test_does_not_infer_permission_from_manifest_receiver_text(self):
        facts = evaluate_manifest(
            "package: name='es.vencira.vencira.g13lab'",
            "uses-permission: name='android.permission.INTERNET'",
            "E: receiver android:name='android.permission.POST_NOTIFICATIONS'",
        )
        self.assertEqual(facts["PERMISSION_POST_NOTIFICATIONS"], "NOT_DECLARED")

    def test_prevents_inspection_of_normal_application_as_lab(self):
        for package in ("es.vencira.vencira", "es.vencira.vencira.g8lab", ""):
            with self.subTest(package=package):
                with self.assertRaises(ValueError):
                    evaluate_manifest(f"package: name='{package}'", "", "")

    def test_can_report_exact_alarm_permission_without_claiming_os_grant(self):
        facts = evaluate_manifest(
            "package: name='es.vencira.vencira.g13lab'",
            "uses-permission: name='android.permission.SCHEDULE_EXACT_ALARM'",
            "",
        )
        self.assertEqual(facts["PERMISSION_SCHEDULE_EXACT_ALARM"], "DECLARED")
        self.assertNotIn("OS_PERMISSION_GRANTED", facts)


if __name__ == "__main__":
    unittest.main()
