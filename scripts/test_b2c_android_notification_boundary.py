#!/usr/bin/env python3
"""Source-level regression tests. Not a physical Android permissions test."""
import unittest

from b2c_android_notification_boundary import audit, inspect

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<uses-permission android:name="android.permission.INTERNET"/>
<application android:allowBackup="false"/></manifest>'''
MAIN = 'DeviceNoticeStartupGate( AndroidWebAccessScreen() cancelPreviousAlarms: _revokeNativeAlarms'
ADAPTER = 'areNotificationsEnabled() explicitUserOptIn encryptedInventoryVerified'
COORDINATOR = 'bool nativeRolloutApproved = false !_nativeRolloutApproved'


class B2CAndroidNotificationBoundaryTests(unittest.TestCase):
    def test_current_sources_keep_scheduling_disabled(self):
        self.assertTrue(all(audit().values()))

    def test_exact_alarm_privilege_is_not_silently_accepted(self):
        changed = MANIFEST.replace(
            '<application',
            '<uses-permission android:name="android.permission.USE_EXACT_ALARM"/><application',
        )
        self.assertFalse(inspect(changed, MAIN, ADAPTER, COORDINATOR)[
            "no_privileged_exact_alarm_permissions"
        ])

    def test_reboot_receiver_registration_requires_review(self):
        changed = MANIFEST.replace(
            '<application android:allowBackup="false"/>',
            '<application android:allowBackup="false">'
            '<receiver android:name="com.dexterous.flutterlocalnotifications.'
            'ScheduledNotificationBootReceiver"/></application>',
        )
        self.assertFalse(inspect(changed, MAIN, ADAPTER, COORDINATOR)[
            "scheduling_receivers_not_operationally_registered"
        ])

    def test_deleting_app_startup_revocation_is_detected(self):
        self.assertFalse(inspect(MANIFEST, MAIN.replace(
            "cancelPreviousAlarms: _revokeNativeAlarms", "",
        ), ADAPTER, COORDINATOR)["android_startup_revoke_before_web_access"])

    def test_enabling_native_rollout_by_default_is_detected(self):
        self.assertFalse(inspect(MANIFEST, MAIN, ADAPTER,
            COORDINATOR.replace("bool nativeRolloutApproved = false",
                                "bool nativeRolloutApproved = true"))[
            "native_rollout_default_disabled"
        ])

    def test_missing_os_permission_check_is_detected(self):
        self.assertFalse(inspect(MANIFEST, MAIN,
            ADAPTER.replace("areNotificationsEnabled()", ""), COORDINATOR)[
            "os_permission_check_before_scheduling"
        ])


if __name__ == "__main__":
    unittest.main()
