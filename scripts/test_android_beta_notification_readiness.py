"""Pure, no-device checks for B2-C source readiness reporter."""
import unittest
from android_beta_notification_readiness import permission_readiness


class AndroidNotificationReadinessTests(unittest.TestCase):
    def test_missing_app_manifest_features_are_reported_not_invented(self):
        facts = permission_readiness(
            '<manifest><uses-permission android:name="android.permission.INTERNET"/></manifest>',
            'void main() {}',
            'areNotificationsEnabled()',
            'enableFromExplicitAction() _nativeRolloutApproved',
        )
        self.assertEqual(facts["APP_MANIFEST_POST_NOTIFICATIONS"], "NO")
        self.assertEqual(facts["APP_MANIFEST_BOOT_PERMISSION"], "NO")
        self.assertEqual(facts["APP_MANIFEST_BOOT_RECEIVERS"], "NO")
        self.assertEqual(facts["OS_PERMISSION_PREFLIGHT_IN_ALARM_PORT"], "YES")
        self.assertEqual(facts["NATIVE_NOTICE_ROLLOUT_WIRED_TO_MAIN"], "NO")

    def test_explicit_config_and_wiring_is_visible_but_not_approved(self):
        manifest = (
            '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>'
            '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>'
            '<receiver android:name="ScheduledNotificationBootReceiver"/>'
        )
        facts = permission_readiness(
            manifest, 'DeviceNoticeSessionCoordinator(', 'areNotificationsEnabled()',
            'enableFromExplicitAction() _nativeRolloutApproved',
        )
        self.assertEqual(facts["APP_MANIFEST_POST_NOTIFICATIONS"], "YES")
        self.assertEqual(facts["APP_MANIFEST_BOOT_PERMISSION"], "YES")
        self.assertEqual(facts["APP_MANIFEST_BOOT_RECEIVERS"], "YES")
        self.assertEqual(facts["NATIVE_NOTICE_ROLLOUT_WIRED_TO_MAIN"], "YES")
        self.assertEqual(facts["EXPLICIT_OPT_IN_GATE_IN_COORDINATOR"], "YES")


if __name__ == "__main__":
    unittest.main()
