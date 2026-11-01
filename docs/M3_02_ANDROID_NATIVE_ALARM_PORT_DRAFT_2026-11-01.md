# VENCIRA — M3-02: Android native notification adapter (01/11/2026)

## Scope and isolation

Draft PR #17: https://github.com/appvencira/vencira_app/pull/17, based on the protected feature worktree; neither default nor DEV is changed. The Android platform scaffold was versioned separately in the parent feature branch and remains subject to release review.

- Dependencies selected for Flutter stable: `flutter_local_notifications 22.3.3`, `flutter_secure_storage 11.1.0`, `timezone 0.11.2` and `flutter_timezone 5.1.1`. Minimum Dart SDK raised to 3.10 for plugin compatibility.
- `device_notice_inventory.dart`: strict, private encrypted store and serializable record contract. Persist only user/workspace/occurrence/generation and civil time. Block corrupted JSON, duplicates, cross-session access, oversized payloads, invalid dates and unnoticed migration. Android platform storage defaults to Keystore-backed authenticated encryption; no fallback to `shared_preferences`.
- `android_local_alarm_port.dart`: real platform port `FlutterLocalNotificationsPlugin`, not referenced in `main.dart`. It cannot prepare without user opt-in, verified encrypted inventory, notification permission, Android platform and verified IANA timezone `Europe/Madrid`. The OS receives only generic, lock-screen-hidden text (no customer, policy, email or phone). Schedules INEXACT alarms near 09:00, never guarantees exact-time delivery, network availability or notification seen.
- Notification numeric IDs are deterministic, checked for collisions against the verified inventory. The ID is reserved *before* the platform call so an uncertain schedule ACK can be compensated by `device_notice_sync.dart`.
- `test/device_notice_inventory_test.dart` and `test/android_local_alarm_port_test.dart` cover codec, tenancy, corruption, duplicates and IDs. No automatic OS calls are executed in widget/unit tests.

## Verified constraints

The adapter is present but **never wired to runtime startup, login or screen actions**. No permissions are requested automatically. Backend `device-notice-preview` capabilities remain `native_alarm_scheduling=false`, `offline_storage=false`, `delivery=false`. Release status **NO**.

The first Android adapter CI run `41310530123` detected `flutter_local_notifications` requiring Java core-library desugaring in the Android project. The *versioned parent feature branch* now includes `isCoreLibraryDesugaringEnabled=true`, multidex and `desugar_jdk_libs:2.1.4` at commit `5a05197`; a refreshed Android debug build is required to verify the correction. Never represent the original failed run as PASS.

## Remaining blockers before device activation

1. Add versioned Android `POST_NOTIFICATIONS` permission, `RECEIVE_BOOT_COMPLETED` and plugin receiver declarations **after the native scaffold branch is reconciled**; no exact-alarm privilege without explicit product approval. Reinstate scheduled notifications after reboot and verify Android 13–16 permission and Doze handling. The existing inexact schedule may occur later than 09:00.
2. Persist and verify the encrypted inventory across the *entire* scheduling transaction, including mixed cancel/schedule failure and process death; revoke OS alarms and encrypted inventory on logout/session change, workspace membership changes or device loss. Fail closed if server snapshot is partial/expired.
3. Add user-facing opt-in, explain inexact delivery and privacy, manual enable/disable UI, and account-aware reconciliation. Do not run on app startup.
4. Android emulator + physical device tests offline, reboot, DST (Europe/Madrid, islands under review), lock screen, aggressive battery optimizations, denied permissions, and session revocation.
5. Independent security acceptance and release authorization gates. No change to MFA / C-FICHA release.

The formal master checklist remains **2/15 (13.3%)**, M3-02 open. No server DB migration, deployment, or real notice sent by this work.
