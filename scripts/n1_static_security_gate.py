#!/usr/bin/env python3
"""Fail-closed, read-only N1 release boundary guard.

Static evidence complements tests; it does not authorize token issuance.
Runs with stdlib, without Django settings, Docker, database or network.
"""
from pathlib import Path
import ast
from g14_trusted_issuer_boundary import audit_tree as audit_g14_issuer_calls

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def verify():
    settings = read("backend/config/settings.py")
    config = read("backend/config/urls.py")
    routes = read("backend/reminders/urls.py")
    guard = read("backend/reminders/test_native_mobile_auth_boundary.py")
    lab_models = read("backend/native_sessions_lab/models.py")
    lab_migration = read("backend/native_sessions_lab/migrations/0001_initial.py")
    lab_epoch_migration = read(
        "backend/native_sessions_lab/migrations/0003_mobile_account_fence.py"
    )
    session_rules = read("backend/native_sessions_lab/session_rules.py")
    login_rules = read("backend/native_sessions_lab/login_rules.py")
    lab_urls = read("backend/native_sessions_lab/test_urls.py")
    flutter_http = read("clients/flutter/lib/api/native_http_auth_port.dart")
    flutter_main = read("clients/flutter/lib/main.dart")
    flutter_lab_shell = read("clients/flutter/lib/ui/native_lab_login_shell.dart")
    flutter_lab_http_test = read("clients/flutter/test/native_http_login_integration_test.dart")
    django_socket_lab_test = read("backend/native_sessions_lab/test_loopback_http_contract.py")
    django_https_lab_test = read("backend/native_sessions_lab/test_verified_https_loopback.py")
    django_d2_fixture = read("backend/native_sessions_lab/g7_d2_https_fixture.py")
    dart_d2_probe = read("clients/flutter/tool/g7_d2_https_probe.dart")
    dart_d2_binding = read("clients/flutter/test/g7_d2_https_live_test.dart")
    g7_d2_runner = read("scripts/g7_d2_https_flutter_django.sh")
    g8_device_test = read("clients/flutter/integration_test/g8_protected_store_device_test.dart")
    g8_emulator_runner = read("scripts/g8_android_store_lab.sh")
    g8_phone_main = read("clients/flutter/lib/g8_lab_main.dart")
    g8_phone_store = read("clients/flutter/lib/g8_lab/physical_store_checks.dart")
    g8_phone_runner = read("scripts/g8_phone_apk_build.sh")
    g12_phone_main = read("clients/flutter/lib/g12_lab_main.dart")
    g12_phone_flow = read("clients/flutter/lib/g12_lab/physical_auth_checks.dart")
    g12_phone_runner = read("scripts/g12_phone_apk_build.sh")
    g12_phone_ci = read(".github/workflows/g12-phone-auth-apk.yml")
    g13_phone_main = read("clients/flutter/lib/g13_lab_main.dart")
    g13_phone_flow = read("clients/flutter/lib/g13_lab/physical_https_checks.dart")
    g13_phone_runner = read("scripts/g13_phone_apk_build.sh")
    g13_host_lab = read("scripts/g13_android_usb_https_lab.sh")
    g13_loopback_relay = read("scripts/g13_usb_loopback_relay.py")
    g13_ci = read(".github/workflows/g13-android-https-source.yml")
    g9_boot = read("clients/flutter/lib/api/native_mobile_startup_gate.dart")
    g9_entry = read("clients/flutter/lib/api/native_mobile_recovery_entry.dart")
    g9_boot_test = read("clients/flutter/test/native_mobile_startup_gate_test.dart")
    g9_entry_test = read("clients/flutter/test/native_mobile_recovery_entry_test.dart")
    g9_boot_runner = read("scripts/g9_native_startup_gate.sh")
    g10_entry = read("clients/flutter/lib/api/native_first_issuance_entry.dart")
    g10_journal = read("clients/flutter/lib/api/native_refresh_recovery_journal.dart")
    g10_coordinator = read("clients/flutter/lib/api/native_session_coordinator.dart")
    g10_test = read("clients/flutter/test/native_first_issuance_entry_test.dart")
    g10_runner = read("scripts/g10_issuance_logout_gate.sh")
    g11_scenarios = read("clients/flutter/tool/g11_https_scenarios.dart")
    g11_runner = read("scripts/g11_https_first_issue_logout.sh")
    g11_lab_runner = read("scripts/g7_d2_https_flutter_django.sh")
    g11_probe = read("clients/flutter/tool/g7_d2_https_probe.dart")
    g8_phone_ci = read(".github/workflows/g8-phone-apk.yml")
    g8_gradle = read("clients/flutter/android/app/build.gradle.kts")
    flutter_pubspec = read("clients/flutter/pubspec.yaml")
    android_manifest = read("clients/flutter/android/app/src/main/AndroidManifest.xml")
    recovery_gateway = read("clients/flutter/lib/api/native_recovery_login_gateway.dart")
    recovery_migration = read(
        "backend/native_sessions_lab/migrations/0004_mobile_challenge_recovery_flag.py"
    )
    candidate_schema = read("backend/native_mobile_service/models.py")
    candidate_migration = read(
        "backend/native_mobile_service/migrations/0001_initial.py"
    )
    candidate_auth = read("backend/native_mobile_service/authentication.py")
    candidate_store = read("backend/native_mobile_service/session_store.py")
    candidate_urls = read("backend/native_mobile_service/test_urls.py")
    candidate_test = read("backend/native_mobile_service/test_contract.py")
    candidate_races = read("backend/native_mobile_service/test_pg17_races.py")
    g5_throttle = read("backend/native_mobile_service/g5_throttle.py")
    g5_schema = read("backend/native_mobile_service/migrations/0002_mobileauthattemptbucket.py")
    g5_audit = read("backend/native_mobile_service/g5_audit.py")
    g5_keyring = read("backend/native_mobile_service/g5_keyring_policy.py")
    g14_admission = read("backend/native_mobile_service/g14_admission.py")
    g14_test = read("backend/native_mobile_service/test_g14_admission.py")
    g14_issuance = read("backend/native_mobile_service/g14_issuance_contract.py")
    g14_issuance_test = read("backend/native_mobile_service/test_g14_issuance_contract.py")
    g14_atomicity_test = read("backend/native_mobile_service/test_g14_issuance_atomicity.py")
    g14_verifier = read("backend/native_mobile_service/g14_locked_verifier.py")
    g14_verifier_test = read("backend/native_mobile_service/test_g14_locked_verifier.py")
    g14_evidence_test = read("backend/native_mobile_service/test_g14_untrusted_evidence.py")
    g14_d3 = read("backend/native_mobile_service/g14_d3_candidate_boundary.py")
    g14_d3_test = read("backend/native_mobile_service/test_g14_d3_candidate_boundary.py")
    g14_d3_races = read("backend/native_mobile_service/test_g14_d3_pg17_races.py")
    g14_d5_races = read("backend/native_mobile_service/test_g14_d5_mfa_writer_pg17_races.py")
    g14_d8_races = read("backend/native_mobile_service/test_g14_d8_admin_rotation_pg17.py")
    g14_d9_guards = read("backend/native_mobile_service/test_g14_d9_recovery_guards_pg17.py")
    g14_d9c_races = read("backend/native_mobile_service/test_g14_d9c_admin_finalization_pg17.py")
    g14_e1_verifier = read("backend/native_mobile_service/g14_e1_locked_mfa_verifier.py")
    g14_e1_tests = read("backend/native_mobile_service/test_g14_e1_locked_mfa_verifier.py")
    g14_e1b_tests = read("backend/native_mobile_service/test_g14_e1_concurrency_pg17.py")
    g14_e1c_tests = read("backend/native_mobile_service/test_g14_e1c_transaction_rollback_pg17.py")
    g14_e1d_tests = read("backend/native_mobile_service/test_g14_e1d_key_custody_pg17.py")
    mfa_enrollment_lock = read("backend/reminders/mfa_enrollment.py")
    g14_inventory = read("scripts/g14_mfa_writer_inventory.py")
    g14_inventory_tests = read("scripts/test_g14_mfa_writer_inventory.py")
    g14_lock_report = read("scripts/g14_mfa_lock_order_report.py")
    g14_lock_report_tests = read("scripts/test_g14_mfa_lock_order_report.py")
    g14_issuer_guard = read("scripts/g14_trusted_issuer_boundary.py")
    g14_issuer_guard_tests = read("scripts/test_g14_trusted_issuer_boundary.py")

    failures = []
    checks = {
        "default_auth_session_only":
            '"rest_framework.authentication.SessionAuthentication"' in settings
            and "DEFAULT_AUTHENTICATION_CLASSES" in settings,
        "lab_env_test_guard":
            'if VENCIRA_ENV != "test":' in settings
            and 'raise ImproperlyConfigured("Native device session lab only allowed in test")' in settings,
        "lab_explicit_opt_in":
            'VENCIRA_NATIVE_SESSION_LAB = os.getenv("VENCIRA_NATIVE_SESSION_LAB", "0") == "1"' in settings,
        "lab_installed_only_under_guard":
            settings.count('INSTALLED_APPS.append("native_sessions_lab")') == 1,
        "lab_migrations_isolated":
            "native_sessions_lab" not in config
            and "native_sessions_lab" not in routes,
        "no_bearer_routes":
            "native_mobile_token_primitives" not in config
            and "native_mobile_token_primitives" not in routes
            and 'path("mobile/' not in routes
            and 'path("mobile/' not in config,
        "web_auth_guard_present":
            "test_bearer_header_cannot_authenticate_web_session_api" in guard
            and "test_device_session_lab_is_absent_from_normal_django" in guard,
        "ephemeral_schema_has_no_user_secret":
            "password" not in lab_models.lower()
            and "password" not in lab_migration.lower()
            and "refresh_digest" in lab_models
            and "SpentRefreshLab" in lab_migration,
        "account_revoke_fences_pending_mfa":
            "MobileAccountFenceLab" in lab_models
            and "auth_generation" in lab_epoch_migration
            and "generation=F(\"generation\") + 1" in session_rules
            and "MobileLoginChallengeLab.objects.filter(" in session_rules
            and "consumed_at=now" in session_rules
            and "record.auth_generation != account_generation_lab" in login_rules,
        "test_http_is_unreachable_from_operational_routes":
            "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes
            and "test_http_contract" not in config
            and "test_http_contract" not in routes
            and 'path("api/v1/mobile/auth/password/"' in lab_urls
            and 'path("api/v1/mobile/workspaces/<uuid:workspace_id>/renewals/"' in lab_urls,
        "g6_recovery_after_full_mfa":
            "replace_devices" in recovery_migration
            and "record.replace_devices is not expected_recovery" in login_rules
            and "revoke_all_devices_for_user_lab(user_id=user.pk)" in login_rules
            and 'path("api/v1/mobile/auth/recover/password/"' in lab_urls
            and 'path("api/v1/mobile/auth/recover/mfa/"' in lab_urls
            and "native_sessions_lab.test_urls" not in config,
        "flutter_http_single_canonical_recovery_contract":
            flutter_http.count("class NativeHttpAuthFailure implements Exception") == 1
            and flutter_http.count("Future<NativeIssuedTokens> recoverMfa({") == 1
            and flutter_http.count("Future<NativeIssuedTokens> mfa({") == 1
            and flutter_http.count("Future<NativeIssuedTokens> rotateRefresh(") == 1
            and flutter_http.count("Future<void> revoke({") == 1
            and "'/api/v1/mobile/auth/recover/mfa/'" in flutter_http,
        "g6_recovery_gateway_isolated":
            "class NativeRecoveryLoginGateway implements NativeLoginGateway" in recovery_gateway
            and "journal.confirmFullReauthentication(" in recovery_gateway
            and "journal.requiresReauthentication()" in recovery_gateway
            and "NativeRecoveryAuthPort" in flutter_http
            and "NativeRecoveryLoginGateway" not in read("clients/flutter/lib/main.dart"),
        "g4_candidate_opt_in_test_only":
            'VENCIRA_NATIVE_SERVICE_CANDIDATE = (' in settings
            and 'if VENCIRA_NATIVE_SERVICE_CANDIDATE:' in settings
            and 'if VENCIRA_ENV != "test":' in settings
            and 'INSTALLED_APPS.append("native_mobile_service")' in settings
            and "VENCIRA_NATIVE_BEARER_ENABLED = False" in settings
            and "native_mobile_service" not in config
            and "native_mobile_service" not in routes
            and "native_mobile_service" not in read("backend/config/urls.py"),
        "g4_drf_bearer_no_global_fallback":
            '"rest_framework.authentication.SessionAuthentication"' in settings
            and "CandidateMobileBearerAuthentication" in candidate_auth
            and "settings.VENCIRA_NATIVE_BEARER_ENABLED" in candidate_auth
            and "settings.VENCIRA_ENV == \"test\"" in candidate_auth
            and 'request.META.get("HTTP_COOKIE")' in candidate_auth
            and "request.is_secure()" in candidate_auth
            and "authentication_classes = [CandidateMobileBearerAuthentication]" in read(
                "backend/native_mobile_service/test_views.py"
            ),
        "g4_candidate_no_plaintext_refresh":
            "class MobileDeviceSession" in candidate_schema
            and "refresh_digest" in candidate_schema
            and "MobileSpentRefresh" in candidate_schema
            and "refresh_digest" in candidate_migration
            and 'models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")' in candidate_migration
            and 'native_token_digest(refresh, kind="r")' in candidate_store
            and "MobileSpentRefresh.objects.create(" in candidate_store
            and 'rows.select_for_update(of=("self",))' in candidate_store,
        "g4_candidate_lab_suites_present":
            "class MobileCandidateContractTests" in candidate_test
            and "class CandidateRacePG17Tests" in candidate_races
            and 'path("api/v1/mobile/me/"' in candidate_urls
            and "native_mobile_service.test_urls" not in config
            and "native_mobile_service.test_urls" not in routes,
        "g5_throttle_is_test_only":
            'settings.VENCIRA_ENV == "test"' in g5_throttle
            and "settings.VENCIRA_NATIVE_SERVICE_CANDIDATE" in g5_throttle
            and "select_for_update()" in g5_throttle
            and "transaction.atomic()" in g5_throttle
            and "VENCIRA_G5_ABUSE_KEY" in g5_throttle
            and "DJANGO_SECRET_KEY" not in g5_throttle.replace(
                "no fallback to DJANGO_SECRET_KEY", ""
            )
            and "MobileAuthAttemptBucket" in g5_schema
            and "native_mobile_service" not in config
            and "native_mobile_service" not in routes,
        "g5_audit_test_only":
            'settings.VENCIRA_ENV == "test"' in g5_audit
            and "VENCIRA_G5_AUDIT_KEY" in g5_audit
            and "MobileAuthAuditEvent" in g5_audit
            and "native_mobile_service" not in config,
        "g14_admission_test_only":
            "transaction.atomic()" in g14_admission
            and "consume_candidate_auth_attempt(" in g14_admission
            and "record_candidate_auth_event(" in g14_admission
            and "require_audit_key()" in g14_admission
            and "auth_denied" in g14_admission
            and "issue_verified_candidate_session" not in g14_admission
            and "authenticate(" not in g14_admission
            and "test_missing_audit_key_denies_before_consuming_budget" in g14_test
            and "test_reused_denial_uuid_with_conflicting_actor_rolls_back" in g14_test
            and "g14_admission" not in config
            and "g14_admission" not in routes
            and "g14_admission" not in candidate_urls,
        "g14_issuer_policy_untrusted_evidence_only":
            "class IssuanceSecurityEvidence" in g14_issuance
            and "missing_issuance_requirements" in g14_issuance
            and "mfa_not_verified" in g14_issuance
            and "mfa_epoch" in g14_issuance
            and "recovery_quarantine" in g14_issuance
            and "generation" in g14_issuance
            and "audit" in g14_issuance
            and "issue_verified_candidate_session" not in g14_issuance
            and "get_user_model" not in g14_issuance
            and "check_password(" not in g14_issuance
            and "test_enabled_mfa_requires_completed_factor_and_current_epoch" in g14_issuance_test
            and "test_invalid_or_missing_evidence_fails_closed" in g14_issuance_test
            and "g14_issuance_contract" not in config
            and "g14_issuance_contract" not in routes
            and "g14_issuance_contract" not in candidate_urls,
        "g14_atomicity_only_in_disposable_tests":
            "test_audit_unavailable_rolls_back_session" in g14_atomicity_test
            and "test_conflicting_audit_event_rolls_back_new_session" in g14_atomicity_test
            and "test_transaction_abort_rolls_back_session_and_audit" in g14_atomicity_test
            and "test_revocation_generation_denies_stale_issuance" in g14_atomicity_test
            and "transaction.atomic()" in g14_atomicity_test
            and "issue_verified_candidate_session(" in g14_atomicity_test
            and "record_candidate_auth_event(" in g14_atomicity_test
            and "g14_issuance_atomicity" not in config
            and "g14_issuance_atomicity" not in routes
            and "g14_issuance_atomicity" not in candidate_urls,
        "g14_locked_verifier_test_only_no_issuer":
            'settings.VENCIRA_ENV == "test"' in candidate_store
            and "select_for_update()" in g14_verifier
            and "check_password(password)" in g14_verifier
            and "require_mobile_identity_gate(" in g14_verifier
            and "UserMfaState.objects.filter(" in g14_verifier
            and "CandidateVerificationDenied" in g14_verifier
            and "issue_verified_candidate_session(" not in g14_verifier
            and "make_native_token(" not in g14_verifier
            and "authenticate(" not in g14_verifier
            and "test_enabled_mfa_never_passes_password_only" in g14_verifier_test
            and "test_password_rotation_invalidates_old_password" in g14_verifier_test
            and "g14_locked_verifier" not in config
            and "g14_locked_verifier" not in routes
            and "g14_locked_verifier" not in candidate_urls,
        "g14_d2_untrusted_evidence_negative_contract":
            "test_verified_metadata_becomes_stale_after_revocation" in g14_evidence_test
            and "test_verified_metadata_does_not_survive_password_rotation" in g14_evidence_test
            and "test_mfa_enabled_after_password_check_denies_non_mfa_issuer" in g14_evidence_test
            and "test_no_native_issuer_routes_in_operational_urls" in g14_evidence_test
            and "g14_untrusted_evidence" not in config
            and "g14_untrusted_evidence" not in routes
            and "g14_untrusted_evidence" not in candidate_urls,
        "g14_d3_only_non_mfa_transaction":
            "transaction.atomic()" in g14_d3
            and "verify_candidate_password_only(" in g14_d3
            and "issue_verified_candidate_session(" in g14_d3
            and "record_candidate_auth_event(" in g14_d3
            and "admit_candidate_password_attempt(" in g14_d3
            and "verified_mfa=False" in g14_d3
            and "verified_mfa=True" not in g14_d3
            and "test_enabled_mfa_denies_password_only" in g14_d3_test
            and "test_conflicting_success_audit_rolls_back_new_session" in g14_d3_test
            and "test_replayed_success_audit_uuid_cannot_issue_second_session" in g14_d3_test
            and "if not created:" in g14_d3
            and "g14_d3_candidate_boundary" not in config
            and "g14_d3_candidate_boundary" not in routes
            and "g14_d3_candidate_boundary" not in candidate_urls,
        "g14_d3_pg17_race_isolated":
            "TransactionTestCase" in g14_d3_races
            and 'connection.vendor != "postgresql"' in g14_d3_races
            and "test_revoke_waits_for_locked_issuance_and_no_session_survives" in g14_d3_races
            and "test_password_rotation_after_issuance_invalidates_access" in g14_d3_races
            and "select_for_update()" in g14_d3_races
            and "g14_d3_pg17_races" not in config
            and "g14_d3_pg17_races" not in routes,
        "g14_mfa_finalize_user_lock_before_state":
            "def finalize_mfa(" in mfa_enrollment_lock
            and "get_user_model().objects.select_for_update().filter(" in mfa_enrollment_lock
            and "test_mfa_finalization_after_locked_issuance_invalidates_access" in g14_d3_races
            and 'reminders.mfa_secrets.verify_recovery_code' in g14_d3_races,
        "g14_d5_pg17_mfa_writer_tests_present":
            "test_parallel_same_totp_has_exactly_one_acceptance" in g14_d5_races
            and "test_parallel_same_recovery_code_has_exactly_one_acceptance" in g14_d5_races
            and "test_epoch_revocation_invalidates_mfa_candidate_access" in g14_d5_races
            and "TransactionTestCase" in g14_d5_races
            and "g14_d5_mfa_writer_pg17_races" not in config,
        "g14_mfa_inventory_readonly":
            "def find_candidates(" in g14_inventory
            and "ast.parse(" in g14_inventory
            and "ROOT.rglob(" in g14_inventory
            and "G14_MFA_WRITER_INVENTORY=REPORT_ONLY_NOT_A_SECURITY_GATE" in g14_inventory
            and "test_mfa_model_update_is_detected" in g14_inventory_tests
            and "test_inventory_does_not_execute_source" in g14_inventory_tests,
        "g14_d8_pg17_admin_rotation_isolated":
            "TransactionTestCase" in g14_d8_races
            and 'connection.vendor != "postgresql"' in g14_d8_races
            and "test_final_rotation_vs_epoch_revocation_invalidates_old_access" in g14_d8_races
            and "test_open_admin_recovery_vs_candidate_issuance_never_leaves_valid_access" in g14_d8_races
            and "MobileTokenDenied" in g14_d8_races
            and "g14_d8_admin_rotation_pg17" not in config
            and "g14_d8_admin_rotation_pg17" not in routes,
        "g14_d9_lock_report_readonly":
            "def lock_calls(" in g14_lock_report
            and "ast.parse(" in g14_lock_report
            and "READ_ONLY_REVIEW_REQUIRED" in g14_lock_report
            and "test_two_locks_are_sorted_by_source_line" in g14_lock_report_tests
            and "test_nonexecuted_syntax" in g14_lock_report_tests,
        "g14_d9_recovery_verifier_failclosed_tests":
            "TransactionTestCase" in g14_d9_guards
            and "test_missing_verifier_fails_closed" in g14_d9_guards
            and "test_negative_verifier_fails_closed" in g14_d9_guards
            and "test_truthy_non_boolean_verifier_fails_closed" in g14_d9_guards
            and "test_verifier_exception_fails_closed" in g14_d9_guards
            and "assert_unchanged" in g14_d9_guards
            and "g14_d9_recovery_guards_pg17" not in config
            and "g14_d9_recovery_guards_pg17" not in routes,
        "g14_d9c_admin_factor_finalization_pg17":
            "TransactionTestCase" in g14_d9c_races
            and "test_cancel_vs_finalization_cannot_both_succeed" in g14_d9c_races
            and "test_missing_execution_evidence_preserves_factor" in g14_d9c_races
            and "cancel_recovery_case(" in g14_d9c_races
            and "finalize_administrative_factor(" in g14_d9c_races
            and "g14_d9c_admin_finalization_pg17" not in config
            and "g14_d9c_admin_finalization_pg17" not in routes,
        "g14_d9d_terminal_case_races_pg17":
            "test_expiry_vs_finalization_cannot_both_succeed" in g14_d9c_races
            and "test_rejection_vs_finalization_cannot_both_succeed" in g14_d9c_races
            and "expire_recovery_case(" in g14_d9c_races
            and "record_review(" in g14_d9c_races
            and "self.assertNotEqual(finalized, expired)" in g14_d9c_races
            and "self.assertNotEqual(finalized, rejected)" in g14_d9c_races,
        "g14_trusted_issuer_direct_call_boundary":
            audit_g14_issuer_calls(ROOT / "backend")[1] == []
            and "G14_TRUSTED_ISSUER_IMPLEMENTED=NO" in g14_issuer_guard
            and "test_unreviewed_caller_denied" in g14_issuer_guard_tests
            and "test_aliased_import_detected" in g14_issuer_guard_tests,
        "g14_e1_locked_mfa_proof_without_issuer":
            "verify_candidate_password_and_totp(" in g14_e1_verifier
            and "transaction.atomic()" in g14_e1_verifier
            and "select_for_update()" in g14_e1_verifier
            and "consume_totp(" in g14_e1_verifier
            and "issue_verified_candidate_session(" not in g14_e1_verifier
            and "MobileDeviceSession" not in g14_e1_verifier
            and "test_verified_factor_consumes_once_without_session" in g14_e1_tests
            and "test_pending_administrative_recovery_blocks_factor" in g14_e1_tests
            and "g14_e1_locked_mfa_verifier" not in config
            and "g14_e1_locked_mfa_verifier" not in routes,
        "g14_e1b_pg17_concurrency_and_lockout":
            "TransactionTestCase" in g14_e1b_tests
            and "test_same_totp_concurrent_accepts_once_no_sessions" in g14_e1b_tests
            and "test_bad_totp_persists_attempt_budget" in g14_e1b_tests
            and "test_five_bad_totp_attempts_lock_and_deny_good_code" in g14_e1b_tests
            and "test_wrong_password_does_not_increment_totp_budget" in g14_e1b_tests
            and "MobileDeviceSession.objects.exists()" in g14_e1b_tests
            and "g14_e1_concurrency_pg17" not in config
            and "g14_e1_concurrency_pg17" not in routes,
        "g14_e1c_pg17_outer_savepoint_rollback":
            "TransactionTestCase" in g14_e1c_tests
            and "test_successful_proof_rolls_back_when_outer_transaction_fails" in g14_e1c_tests
            and "test_invalid_code_budget_rolls_back_with_outer_transaction" in g14_e1c_tests
            and "test_inner_savepoint_rollback_does_not_consume_factor" in g14_e1c_tests
            and "transaction.atomic()" in g14_e1c_tests
            and "MobileDeviceSession.objects.exists()" in g14_e1c_tests
            and "g14_e1c_transaction_rollback_pg17" not in config
            and "g14_e1c_transaction_rollback_pg17" not in routes,
        "g14_e1d_pg17_key_custody_failclosed":
            "TransactionTestCase" in g14_e1d_tests
            and "test_missing_keyring_denied_without_consumption" in g14_e1d_tests
            and "test_unknown_key_cannot_decrypt_or_consume_factor" in g14_e1d_tests
            and "test_inactive_account_denied_without_factor_consumption" in g14_e1d_tests
            and "test_pending_recovery_denied_even_with_valid_factor" in g14_e1d_tests
            and "MobileDeviceSession.objects.exists()" in g14_e1d_tests
            and "g14_e1d_key_custody_pg17" not in config
            and "g14_e1d_key_custody_pg17" not in routes,
        "g14_e1d_uniform_custody_denial":
            "except (MobileTokenDenied, ValueError):" in g14_e1_verifier
            and "raise CandidateMfaDenied() from None" in g14_e1_verifier
            and "test_malformed_key_denied_without_details_or_consumption" in g14_e1d_tests
            and "self.assertIsNone(denied.exception.__cause__)" in g14_e1d_tests,
        "g5_keyring_not_connected":
            "CandidateKeyring" in g5_keyring
            and "DJANGO_SECRET_KEY" not in g5_keyring.replace("Django SECRET_KEY", "")
            and "g5_keyring_policy" not in config
            and "g5_keyring_policy" not in routes,
        "g5_versioned_digest_capacity":
            "max_length=96" in candidate_schema
            and "0004_digest_envelope_capacity" not in config
            and "native_mobile_service" not in routes,
        "g7_native_ui_lab_entrypoint_only":
            "nativeLoginLab != null" in flutter_main
            and "!kReleaseMode" in flutter_main
            and "NativeLabLoginShell" in flutter_main
            and "NativeHttpAuthPort(" not in flutter_main
            and "NativeSessionCoordinator(" not in flutter_main
            and "AndroidWebAccessScreen()" in flutter_main
            and "widget.coordinator.fence.ticket" in flutter_lab_shell
            and "widget.coordinator.logout()" in flutter_lab_shell
            and "VenciraDashboardScreen" not in flutter_lab_shell,
        "g7_http_stack_mock_only":
            "MockClient((request) async" in flutter_lab_http_test
            and "test('G7-B HTTP" in flutter_lab_http_test
            and "testWidgets('G7-B" not in flutter_lab_http_test
            and "http.Client()" not in flutter_lab_http_test
            and "IOClient(" not in flutter_lab_http_test
            and "NativeHttpAuthPort(endpoint: endpoint, client: client)" in flutter_lab_http_test
            and "NativeApiTransport(" in flutter_lab_http_test
            and "NativeLabLoginShell(coordinator: coordinator)" in read("clients/flutter/test/native_lab_login_shell_test.dart")
            and "native_sessions_lab.test_urls" not in read("backend/config/urls.py")
            and "NativeHttpAuthPort(" not in flutter_main,
        "g7_socket_lab_loopback_only":
            'host = "127.0.0.1"' in django_socket_lab_test
            and "LiveServerTestCase" in django_socket_lab_test
            and "http.client.HTTPConnection(" in django_socket_lab_test
            and 'ROOT_URLCONF="native_sessions_lab.test_urls"' in django_socket_lab_test
            and "http://" not in read("clients/flutter/lib/api/native_api_endpoint.dart")
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "g7_https_lab_ephemeral_tls_and_hostname":
            '("127.0.0.1", 0)' in django_https_lab_test
            and 'ROOT_URLCONF="native_sessions_lab.test_urls"' in django_https_lab_test
            and "tempfile.TemporaryDirectory(" in django_https_lab_test
            and 'x509.DNSName("dev.vencira.es")' in django_https_lab_test
            and "context.check_hostname = True" in django_https_lab_test
            and "context.verify_mode = ssl.CERT_REQUIRED" in django_https_lab_test
            and "ssl.SSLCertVerificationError" in django_https_lab_test
            and "check_hostname = False" not in django_https_lab_test
            and "CERT_NONE" not in django_https_lab_test
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "g7_d2_django_flutter_tls_isolation":
            'VENCIRA_NATIVE_SESSION_LAB") != "1"' in django_d2_fixture
            and 'VENCIRA_DB_ENGINE") != "sqlite"' in django_d2_fixture
            and 'G7_D2_ISOLATED_NETWORK_ACK") != "1"' in django_d2_fixture
            and 'settings.ROOT_URLCONF = "native_sessions_lab.test_urls"' in django_d2_fixture
            and '"/tmp/g7d2-disposable.sqlite3"' in django_d2_fixture
            and '("0.0.0.0", 8443)' in django_d2_fixture
            and '--internal "$NETWORK"' in g7_d2_runner
            and '--network "$NETWORK"' in g7_d2_runner
            and '--read-only' in g7_d2_runner
            and '--network-alias dev.vencira.es' in g7_d2_runner
            and 'G7_D2_PEER_IPV4="$G7_D2_PEER_IPV4"' in g7_d2_runner
            and 'exec "$SERVER" cat /tmp/g7d2-public-ca.pem' in g7_d2_runner
            and 'test -s /tmp/g7d2-public-ca.pem' in g7_d2_runner
            and 'chmod 0644 "$TMP/public-ca.pem"' in g7_d2_runner
            and 'ssl.PEM_cert_to_DER_cert(raw)' in g7_d2_runner
            and 'PRIVATE KEY" not in raw' in g7_d2_runner
            and g7_d2_runner.count('flutter test --no-pub test/g7_d2_https_live_test.dart') == 1
            and g7_d2_runner.count('echo "G7_D2_FLUTTER_DJANGO_HTTPS=OK"') == 1
            and '"G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0"' in g7_d2_runner
            and '"All tests passed!"' in g7_d2_runner
            and '"${DOCKER[@]}" cp ' not in g7_d2_runner
            and '"$IMAGE" python -u -m native_sessions_lab.g7_d2_https_fixture' in g7_d2_runner
            and 'flutter test --no-pub test/g7_d2_https_live_test.dart' in g7_d2_runner
            and 'SecurityContext(withTrustedRoots: false)' in dart_d2_probe
            and 'Socket.startConnect(_privateLabPeer(), _tlsPort).then((task)' in dart_d2_probe
            and 'final secure = await SecureSocket.secure(' in dart_d2_probe
            and 'raw, host: uri.host, context: trust' in dart_d2_probe
            and 'ConnectionTask.fromSocket<Socket>(verified,' in dart_d2_probe
            and 'G7_D2_FACTORY_VERIFIED_TLS=OK' in dart_d2_probe
            and 'return Socket.startConnect(_privateLabPeer(), _tlsPort);' not in dart_d2_probe
            and 'SecureSocket.secure(' in dart_d2_probe
            and 'host: _serverAlias, context: trust' in dart_d2_probe
            and 'class _SafeHttpTraceClient extends http.BaseClient' in dart_d2_probe
            and 'final httpClient = _SafeHttpTraceClient(IOClient(_httpsClient(trust)));' in dart_d2_probe
            and 'G7_D2_HTTP_${kind}_STATUS=' in dart_d2_probe
            and 'G7_D2_TLS_PREFLIGHT=OK' in dart_d2_probe
            and 'WEB_COOKIE_RESPONSE_ONLY_DELETES_SESSION' in dart_d2_probe
            and "cookieName == 'vencira_sessionid'" in dart_d2_probe
            and 'max-age=0' in dart_d2_probe
            and 'badCertificateCallback' not in dart_d2_probe
            and 'bool get overrideHttpClient => false' in dart_d2_binding
            and 'G7_D2_ISOLATED_NETWORK_ACK' in dart_d2_binding
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes,
        "g7_e_https_mfa_rotation_only_in_lab":
            "Fernet.generate_key()" in django_d2_fixture
            and "UserMfaState.objects.create(" in django_d2_fixture
            and "encrypt_totp_secret(" in django_d2_fixture
            and 'username="g7-e-mfa-synthetic"' in django_d2_fixture
            and "crypto: ^3.0.6" in read("clients/flutter/pubspec.yaml")
            and "Hmac(" in dart_d2_probe
            and "sha1, utf8.encode(" in dart_d2_probe
            and "RFC6238_TOTP_VECTOR" in dart_d2_probe
            and "_syntheticTotp(DateTime.fromMillisecondsSinceEpoch(" in dart_d2_probe
            and "287082" in dart_d2_probe
            and "await coordinator.verifyTotp(consumedCode)" in dart_d2_probe
            and "'MFA_PENDING_BEARER_DENIED'" in dart_d2_probe
            and "'MFA_REUSED_TOTP_DENIED'" in dart_d2_probe
            and "await port.rotateRefresh(oldTokens.refresh)" in dart_d2_probe
            and "'REFRESH_REPLAY_REVOKES_NEW_ACCESS'" in dart_d2_probe
            and "..followRedirects = false" in dart_d2_probe
            and "G7_E_MFA_HTTPS_RESULT=0" in dart_d2_probe
            and "G7_E_REFRESH_REPLAY_RESULT=0" in dart_d2_probe
            and '"G7_E_MFA_HTTPS_RESULT=0"' in g7_d2_runner
            and '"G7_E_REFRESH_REPLAY_RESULT=0"' in g7_d2_runner
            and "G7_E_HTTPS_MFA_REFRESH=OK" in g7_d2_runner
            and "VENCIRA_MFA_FERNET_KEYS=" not in g7_d2_runner
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "g7_f_disposable_https_uncertain_refresh":
            "NativeRecoveryLoginGateway(" in dart_d2_probe
            and "NativeRefreshRecoveryJournal(" in dart_d2_probe
            and "await journal.arm()" in dart_d2_probe
            and "await gateway.requiresRecovery()" in dart_d2_probe
            and "await gateway.verifyPassword(" in dart_d2_probe
            and "RECOVERY_COLD_START_DENIES_ACCESS" in dart_d2_probe
            and "RECOVERY_REAUTH_COMMIT_AND_CLEAR_MARKER" in dart_d2_probe
            and "RECOVERY_ACCOUNT_WIDE_REVOKE" in dart_d2_probe
            and "G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0" in dart_d2_probe
            and '"G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0"' in g7_d2_runner
            and "G7_F_HTTPS_RECOVERY=OK" in g7_d2_runner
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "g7_fast_batch_isolation_and_full_suite_gates":
            "G7_LAB_GROUP" in dart_d2_probe
            and "G7_LAB_GROUP_COMPLETE=$group" in dart_d2_probe
            and "group == 'all' || group == 'd2'" in dart_d2_probe
            and "group == 'all' || group == 'e'" in dart_d2_probe
            and "group == 'all' || group == 'f'" in dart_d2_probe
            and "group == 'all' || group == 'g'" in dart_d2_probe
            and "group == 'all' || group == 'h'" in dart_d2_probe
            and 'GROUP="h"' in g7_d2_runner
            and "d2|e|f|g|h|g11)" in g7_d2_runner
            and "g11) required+=" in g7_d2_runner
            and 'G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0' in g7_d2_runner
            and 'G7_E_MFA_HTTPS_RESULT=0' in g7_d2_runner
            and 'G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0' in g7_d2_runner
            and 'G7_G_MFA_RECOVERY_HTTPS_RESULT=0' in g7_d2_runner
            and 'G7_H_RECOVERY_STORAGE_FAULTS_RESULT=0' in g7_d2_runner
            and 'GROUP="all"' in g7_d2_runner
            and "--fast)" in g7_d2_runner
            and "--group)" in g7_d2_runner
            and 'PUB_VOLUME="vencira-g7-public-dart-pub-v1"' in g7_d2_runner
            and '"${DOCKER[@]}" volume create "$PUB_VOLUME"' in g7_d2_runner
            and '-e G7_LAB_GROUP="$GROUP"' in g7_d2_runner
            and 'required=("G7_LAB_GROUP_COMPLETE=$GROUP" "All tests passed!")' in g7_d2_runner
            and 'grep -Fq -- "$marker" "$TMP/flutter-result.log"' in g7_d2_runner
            and 'echo "G7_BATCH_RESULT=0"' in g7_d2_runner
            and 'echo "G7_BATCH_GATE_RESULT=$status"' in g7_d2_runner
            and 'if [[ "$GROUP" == all ]]; then' in g7_d2_runner
            and 'echo "G7_D2_GATE_RESULT=$status"' in g7_d2_runner
            and '--internal "$NETWORK"' in g7_d2_runner
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g7_d2_runner,
        "g7_g_real_https_mfa_recovery_fail_closed":
            'username="g7-g-mfa-recovery"' in django_d2_fixture
            and 'session_epoch=1' in django_d2_fixture
            and 'keys=[mfa_key]' in django_d2_fixture
            and 'Future<void> _verifyMfaRecoveryHttps(' in dart_d2_probe
            and 'G7_G_MFA_RECOVERY_HTTPS_RESULT=0' in dart_d2_probe
            and 'MFA_RECOVERY_CHECKPOINT_BEFORE_ROTATION' in dart_d2_probe
            and 'MFA_RECOVERY_LOST_REFRESH_RESPONSE' in dart_d2_probe
            and 'MFA_RECOVERY_COLD_START_FENCED' in dart_d2_probe
            and 'MFA_RECOVERY_PASSWORD_CANNOT_REVOKE' in dart_d2_probe
            and 'MFA_RECOVERY_REPLAY_NO_ACCOUNT_REVOKE' in dart_d2_probe
            and 'MFA_RECOVERY_VERIFIED_COMMIT' in dart_d2_probe
            and 'MFA_RECOVERY_ACCOUNT_WIDE_REVOKE' in dart_d2_probe
            and 'MFA_RECOVERY_FINAL_LOGOUT_REVOKES' in dart_d2_probe
            and 'await gateway.verifyTotp(_syntheticTotp())' in dart_d2_probe
            and 'await _verifyMfaRecoveryHttps(endpoint, httpClient)' in dart_d2_probe
            and 'G7_G_MFA_RECOVERY_HTTPS_RESULT=0' in g7_d2_runner
            and 'G7_G_HTTPS_MFA_RECOVERY=OK' in g7_d2_runner
            and 'G7_LAB_GROUP_COMPLETE=$GROUP' in g7_d2_runner
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes,
        "g7_h_https_secure_vault_faults_fail_closed":
            "class _FaultInjectStore extends _DisposableSecretStore" in dart_d2_probe
            and "ignoreRefreshWrite" in dart_d2_probe
            and "ignoreRecoveryDelete" in dart_d2_probe
            and "await journal.arm()" in dart_d2_probe
            and "RECOVERY_STORAGE_CHECKPOINT_READY" in dart_d2_probe
            and "RECOVERY_STORAGE_REFRESH_WRITE_FAILURE_FENCED" in dart_d2_probe
            and "RECOVERY_STORAGE_MARKER_DELETE_FAILURE_FENCED" in dart_d2_probe
            and "RECOVERY_STORAGE_RETRY_VERIFIED" in dart_d2_probe
            and "RECOVERY_STORAGE_FINAL_CLEANUP" in dart_d2_probe
            and "G7_H_RECOVERY_STORAGE_FAULTS_RESULT=0" in dart_d2_probe
            and "await _verifyRecoveryStorageFaultsHttps(endpoint, httpClient)" in dart_d2_probe
            and "G7_H_RECOVERY_STORAGE_FAULTS_RESULT=0" in g7_d2_runner
            and "G7_H_HTTPS_STORAGE_FAULTS=OK" in g7_d2_runner
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "g8_android_plugin_device_test_isolated":
            'integration_test:' in flutter_pubspec
            and 'sdk: flutter' in flutter_pubspec
            and 'IntegrationTestWidgetsFlutterBinding.ensureInitialized()' in g8_device_test
            and 'if (!Platform.isAndroid)' in g8_device_test
            and "storageNamespace: _labNamespace" in g8_device_test
            and "'vencira_g8_emulator_credential_lab_v1'" in g8_device_test
            and 'FlutterNativeSecretStore(' in g8_device_test
            and 'NativeRefreshCredentialVault(' in g8_device_test
            and 'NativeRefreshRecoveryJournal(' in g8_device_test
            and 'await reopenedJournal.confirmFullReauthentication(' in g8_device_test
            and 'await store.delete(_devRefreshKey)' in g8_device_test
            and 'await store.delete(_devJournalKey)' in g8_device_test
            and 'G8_ANDROID_PROTECTED_STORE_RESULT=0' in g8_device_test
            and 'package:http/' not in g8_device_test
            and 'NativeHttpAuthPort' not in g8_device_test
            and 'Socket.connect' not in g8_device_test
            and 'ro.kernel.qemu' in g8_emulator_runner
            and 'DENIED_NON_EMULATOR' in g8_emulator_runner
            and 'DENIED_VENCIRA_ALREADY_INSTALLED' in g8_emulator_runner
            and 'shell pm path es.vencira.vencira' in g8_emulator_runner
            and 'integration_test/g8_protected_store_device_test.dart' in g8_emulator_runner
            and 'G8_ANDROID_EMULATOR_STORE=OK' in g8_emulator_runner
            and 'G8_EMULATOR_GATE_RESULT=$status' in g8_emulator_runner
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g8_emulator_runner
            and 'android:allowBackup="false"' in android_manifest
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes
            and 'NativeRefreshRecoveryJournal' not in flutter_main,
        "g8_physical_phone_debug_apk_isolated":
            'VENCIRA_G8_LAB_BUILD' in g8_gradle
            and 'applicationIdSuffix = ".g8lab"' in g8_gradle
            and 'contains("Release"' in g8_gradle
            and 'contains("Profile"' in g8_gradle
            and 'VENCIRA G8 Pruebas' in g8_gradle
            and 'android:label="${venciraAppLabel}"' in android_manifest
            and "bool.fromEnvironment('VENCIRA_G8_LAB_BUILD')" in g8_phone_main
            and 'kReleaseMode' in g8_phone_main
            and 'G8_DEBUG_ANDROID_LAB_ONLY' in g8_phone_main
            and 'G8PhoneStorageCheck.prepare' in g8_phone_main
            and 'G8PhoneStorageCheck.verifyAfterRestart' in g8_phone_main
            and "G8PhoneStorageCheck.cleanup" in g8_phone_main
            and 'vencira_g8_phone_only_v1' in g8_phone_store
            and 'FlutterNativeSecretStore(' in g8_phone_store
            and 'NativeRefreshRecoveryJournal(' in g8_phone_store
            and 'NativeRefreshCredentialVault(' in g8_phone_store
            and 'previousPid == pid' in g8_phone_store
            and 'G8_PHONE_FORCE_STOP_REQUIRED' in g8_phone_store
            and 'G8_PHONE_PHYSICAL_STORAGE_RESULT=0' in g8_phone_store
            and 'await store.delete(_refreshKey)' in g8_phone_store
            and 'await store.delete(_markerKey)' in g8_phone_store
            and 'http://' not in g8_phone_main
            and 'package:http/' not in g8_phone_store
            and 'NativeHttpAuthPort' not in g8_phone_store
            and 'scripts/g8_phone_apk_build.sh' not in flutter_main
            and "VENCIRA_G8_LAB_BUILD=1 flutter build apk --debug" in g8_phone_runner
            and '--target=lib/g8_lab_main.dart' in g8_phone_runner
            and '--dart-define=VENCIRA_G8_LAB_BUILD=true' in g8_phone_runner
            and 'es.vencira.vencira.g8lab' in g8_phone_runner
            and 'G8_PHONE_APK_ID_VERIFY=OK' in g8_phone_runner
            and 'G8_PHONE_RELEASE_AUTHORIZED=NO' in g8_phone_runner
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g8_phone_runner
            and 'bash scripts/g8_phone_apk_build.sh' in g8_phone_ci
            and 'actions/upload-artifact@v4' in g8_phone_ci
            and 'VENCIRA-G8-PHONE-DEBUG-ONLY' in g8_phone_ci
            and 'G8_PHONE_PHYSICAL_STORAGE_RESULT=NOT_RUN' in g8_phone_ci
            and 'G8_PHONE_RELEASE_AUTHORIZED=NO' in g8_phone_ci
            and 'NativeRefreshRecoveryJournal' not in flutter_main
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes,
        "g12_physical_android_offline_auth_isolated":
            'VENCIRA_G12_LAB_BUILD' in g8_gradle
            and 'listOf(g8LabBuild, g12LabBuild, g13LabBuild).count { it } > 1' in g8_gradle
            and '(g8LabBuild || g12LabBuild || g13LabBuild)' in g8_gradle
            and 'applicationIdSuffix = ".g12lab"' in g8_gradle
            and 'VENCIRA G12 Pruebas' in g8_gradle
            and 'applicationIdSuffix = ".g8lab"' in g8_gradle
            and "bool.fromEnvironment('VENCIRA_G12_LAB_BUILD')" in g12_phone_main
            and 'G12_DEBUG_ANDROID_LAB_ONLY' in g12_phone_main
            and 'kReleaseMode' in g12_phone_main
            and 'Platform.isAndroid' in g12_phone_main
            and 'G12PhoneAuthCheck.prepare' in g12_phone_main
            and 'G12PhoneAuthCheck.verifyAfterRestart' in g12_phone_main
            and 'G12PhoneAuthCheck.cleanup' in g12_phone_main
            and "vencira_g12_phone_only_v1" in g12_phone_flow
            and 'storageNamespace: _namespace' in g12_phone_flow
            and 'resetOnError: false' in g12_phone_flow
            and 'migrateOnAlgorithmChange: false' in g12_phone_flow
            and 'FlutterNativeSecretStore(' in g12_phone_flow
            and 'NativeFirstIssuanceEntry(' in g12_phone_flow
            and 'NativeMobileRecoveryEntry(' in g12_phone_flow
            and 'NativeMobileStartupGate(' in g12_phone_flow
            and 'NativeSessionCoordinator(' in g12_phone_flow
            and 'NativeRefreshRecoveryJournal(' in g12_phone_flow
            and 'NativeRefreshCredentialVault(' in g12_phone_flow
            and 'firstIssuanceJournal: journal' in g12_phone_flow
            and 'before != pid' in g12_phone_flow
            and 'G12_REAL_PROCESS_RESTART_REQUIRED' in g12_phone_flow
            and 'G12_ANDROID_PHYSICAL_AUTH_RESULT=0' in g12_phone_flow
            and 'G12_ANDROID_LOST_ISSUE_MARKER=OK' in g12_phone_flow
            and 'G12_ANDROID_MFA_RECOVERY_COMMITTED=OK' in g12_phone_flow
            and 'G12_ANDROID_FAILED_LOGOUT_RETRY=OK' in g12_phone_flow
            and 'G12_DEV_PROD_KEY_COLLISION' in g12_phone_flow
            and 'G12_CORRUPT_MARKER_ACCEPTED' in g12_phone_flow
            and 'await store.delete(_refreshKey)' in g12_phone_flow
            and 'await store.delete(_markerKey)' in g12_phone_flow
            and 'package:http/' not in g12_phone_flow
            and 'NativeHttpAuthPort' not in g12_phone_flow
            and 'package:http/' not in g12_phone_main
            and 'NativeHttpAuthPort' not in g12_phone_main
            and 'NativeFirstIssuanceEntry' not in flutter_main
            and 'G12PhoneAuthCheck' not in flutter_main
            and 'VENCIRA_G12_LAB_BUILD=1 flutter build apk --debug' in g12_phone_runner
            and '--target=lib/g12_lab_main.dart' in g12_phone_runner
            and '--dart-define=VENCIRA_G12_LAB_BUILD=true' in g12_phone_runner
            and 'es.vencira.vencira.g12lab' in g12_phone_runner
            and 'G12_PHONE_APK_ID_VERIFY=OK' in g12_phone_runner
            and 'G12_PHONE_RELEASE_AUTHORIZED=NO' in g12_phone_runner
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g12_phone_runner
            and 'bash scripts/g12_phone_apk_build.sh' in g12_phone_ci
            and 'actions/upload-artifact@v4' in g12_phone_ci
            and 'VENCIRA-G12-PHONE-DEBUG-ONLY' in g12_phone_ci
            and 'G12_PHONE_PHYSICAL_AUTH_RESULT=NOT_RUN' in g12_phone_ci
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g12_phone_ci
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes,
        "g13_android_real_tls_usb_only":
            'VENCIRA_G13_LAB_BUILD' in g8_gradle
            and 'applicationIdSuffix = ".g13lab"' in g8_gradle
            and 'VENCIRA G13 TLS' in g8_gradle
            and 'applicationIdSuffix = ".g12lab"' in g8_gradle
            and 'applicationIdSuffix = ".g8lab"' in g8_gradle
            and 'listOf(g8LabBuild, g12LabBuild, g13LabBuild).count { it } > 1' in g8_gradle
            and '(g8LabBuild || g12LabBuild || g13LabBuild)' in g8_gradle
            and "bool.fromEnvironment('VENCIRA_G13_LAB_BUILD')" in g13_phone_main
            and "String.fromEnvironment('G13_LAB_PUBLIC_CA_BASE64')" in g13_phone_main
            and 'G13_DEBUG_ANDROID_TEMPORARY_CA_ONLY' in g13_phone_main
            and 'kReleaseMode' in g13_phone_main
            and 'Platform.isAndroid' in g13_phone_main
            and 'G13PhoneHttpsCheck.prepare' in g13_phone_main
            and 'G13PhoneHttpsCheck.verifyAfterRestart' in g13_phone_main
            and 'G13PhoneHttpsCheck.cleanup' in g13_phone_main
            and 'vencira_g13_phone_tls_v1' in g13_phone_flow
            and 'FlutterNativeSecretStore(' in g13_phone_flow
            and 'resetOnError: false' in g13_phone_flow
            and 'migrateOnAlgorithmChange: false' in g13_phone_flow
            and 'NativeFirstIssuanceEntry(' in g13_phone_flow
            and 'NativeMobileRecoveryEntry(' in g13_phone_flow
            and 'NativeHttpAuthPort(' in g13_phone_flow
            and 'NativeMobileStartupGate(' in g13_phone_flow
            and 'NativeSessionCoordinator(' in g13_phone_flow
            and 'NativeRefreshRecoveryJournal(' in g13_phone_flow
            and 'NativeRefreshCredentialVault(' in g13_phone_flow
            and 'firstIssuanceJournal: journal' in g13_phone_flow
            and "G13_ANDROID_REAL_HTTPS_RESULT=0" in g13_phone_flow
            and "G13_POST_COMMIT_ISSUANCE_RESPONSE_LOST" in g13_phone_flow
            and 'G13_REQUEST_WITHOUT_DURABLE_CHECKPOINT' in g13_phone_flow
            and 'G13_NONLAB_DESTINATION_BLOCKED' in g13_phone_flow
            and 'InternetAddress.loopbackIPv4' in g13_phone_flow
            and '_labPort = 18743' in g13_phone_flow
            and 'HttpClient(context: trust)' in g13_phone_flow
            and 'SecureSocket.secure(' in g13_phone_flow
            and 'host: uri.host' in g13_phone_flow
            and 'context: trust' in g13_phone_flow
            and 'ConnectionTask.fromSocket<Socket>(verified' in g13_phone_flow
            and 'raw.destroy()' in g13_phone_flow
            and 'task.cancel()' in g13_phone_flow
            and 'SecurityContext(withTrustedRoots: false)' in g13_phone_flow
            and 'SecurityContext(withTrustedRoots: false)' in g13_phone_flow
            and 'G13_ANDROID_UNTRUSTED_CA_DENIED=OK' in g13_phone_flow
            and 'G13_ANDROID_REAL_FIRST_ISSUE=OK' in g13_phone_flow
            and 'G13_ANDROID_DJANGO_LOGOUT_REVOKED=OK' in g13_phone_flow
            and 'G13_ANDROID_MFA_TLS_COMMITTED=OK' in g13_phone_flow
            and 'G13_ANDROID_NEW_PROCESS=OK' in g13_phone_flow
            and 'G13_ANDROID_SERVER_RECOVERY_COMMITTED=OK' in g13_phone_flow
            and "await journal.confirmLogoutCompleted(vault: vault)" in g13_phone_flow
            and "await store.delete(_markerKey)" in g13_phone_flow
            and "await store.delete(_refreshKey)" in g13_phone_flow
            and "before != pid" not in g13_phone_flow
            and "previous != pid" in g13_phone_flow
            and 'Socket.startConnect(InternetAddress.loopbackIPv4, _labPort)' in g13_phone_flow
            and 'SecurityContext(withTrustedRoots: false)' in g13_phone_flow
            and 'badCertificateCallback' not in g13_phone_flow
            and 'es.vencira.vencira.g13lab' in g13_phone_runner
            and '--target=lib/g13_lab_main.dart' in g13_phone_runner
            and '--dart-define=VENCIRA_G13_LAB_BUILD=true' in g13_phone_runner
            and '--dart-define=G13_LAB_PUBLIC_CA_BASE64=' in g13_phone_runner
            and 'G13_ANDROID_APK_BUILD=OK' in g13_phone_runner
            and 'G13_ANDROID_RELEASE_AUTHORIZED=NO' in g13_phone_runner
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g13_phone_runner
            and 'G13_DISPOSABLE_ACK' in g13_loopback_relay
            and '("127.0.0.1", LAB_PORT)' in g13_loopback_relay
            and 'SERVER_PORT = 8443' in g13_loopback_relay
            and 'G13_HOST_LOOPBACK_RELAY_READY=OK' in g13_loopback_relay
            and 'G13_ADB_REVERSE_ALREADY_IN_USE' in g13_host_lab
            and 'adb reverse tcp:18743 tcp:18743' in g13_host_lab
            and 'adb reverse --remove tcp:18743' in g13_host_lab
            and 'network create --internal "$NET"' in g13_host_lab
            and '--read-only' in g13_host_lab
            and '--tmpfs /tmp:' in g13_host_lab
            and '--cap-drop ALL' in g13_host_lab
            and '--security-opt no-new-privileges' in g13_host_lab
            and 'G7_D2_ISOLATED_NETWORK_ACK=1' in g13_host_lab
            and 'VENCIRA_NATIVE_SESSION_LAB=1' in g13_host_lab
            and 'VENCIRA_ENV=test' in g13_host_lab
            and 'G13_HOST_VERIFIED_TLS_AND_UNAUTH_401=OK' in g13_host_lab
            and 'G13_USB_LOOPBACK_ONLY=OK' in g13_host_lab
            and 'G13_LAB_PUBLIC_CA_BASE64=' in g13_host_lab
            and 'NO_DEPLOY_NO_LIVE_MIGRATION=1' in g13_host_lab
            and 'bash scripts/g13_android_usb_https_lab.sh' not in flutter_main
            and 'G13PhoneHttpsCheck' not in flutter_main
            and 'g13_lab_main.dart' not in flutter_main
            and 'badCertificateCallback' not in g13_phone_main
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes
            and 'flutter analyze' in g13_ci
            and 'G13_REAL_PHONE_RESULT=NOT_RUN' in g13_ci,
        "g13_termux_ssh_local_forward_isolated":
            'MODE="usb"' in g13_host_lab
            and '--ssh-tunnel)' in g13_host_lab
            and 'MODE="ssh_tunnel"' in g13_host_lab
            and 'G13_MODE=TERMUX_SSH_LOCAL_FORWARD' in g13_host_lab
            and 'G13_NO_ADB_REQUIRED=1' in g13_host_lab
            and 'G13_TERMUX_SSH_APK_READY=OK' in g13_host_lab
            and 'G13_TERMUX_SSH_APK_REMOTE_PATH=' in g13_host_lab
            and 'G13_SSH_FORWARD_TARGET=127.0.0.1:18743' in g13_host_lab
            and 'if [[ "$MODE" == usb ]]; then' in g13_host_lab
            and 'adb reverse tcp:18743 tcp:18743' in g13_host_lab
            and 'adb install -r "$APK"' in g13_host_lab
            and 'if [[ "$REVERSE_SET" = 1 ]]; then' in g13_host_lab
            and 'adb reverse --remove tcp:18743' in g13_host_lab
            and 'G13_LAB_SESSION_ACTIVE=1' in g13_host_lab
            and 'G13_NO_PRODUCTION_NETWORK_OR_DB=1' in g13_host_lab
            and 'network create --internal "$NET"' in g13_host_lab
            and '--read-only' in g13_host_lab
            and '--tmpfs /tmp:' in g13_host_lab
            and '--cap-drop ALL' in g13_host_lab
            and 'G13_HOST_RELAY_BOUND_LOOPBACK=OK' in g13_host_lab
            and 'adb reverse' not in g13_loopback_relay
            and '("127.0.0.1", LAB_PORT)' in g13_loopback_relay
            and 'Socket.startConnect(InternetAddress.loopbackIPv4, _labPort)' in g13_phone_flow
            and 'HttpClient(context: trust)' in g13_phone_flow
            and 'SecureSocket.secure(' in g13_phone_flow
            and 'host: uri.host' in g13_phone_flow
            and 'context: trust' in g13_phone_flow
            and 'ConnectionTask.fromSocket<Socket>(verified' in g13_phone_flow
            and 'raw.destroy()' in g13_phone_flow
            and 'badCertificateCallback' not in g13_phone_flow
            and 'badCertificateCallback' not in g13_phone_flow
            and 'native_sessions_lab.test_urls' not in config
            and 'native_sessions_lab.test_urls' not in routes,
        "g9_native_startup_recovers_orphan_fail_closed":
            "enum NativeStartupDisposition" in g9_boot
            and "locked, cleanLogin, fullReauthentication" in g9_boot
            and "fence.revoke();" in g9_boot
            and "journal.fence.revoke();" in g9_boot
            and "final markerExists = await journal.requiresReauthentication();" in g9_boot
            and "final refresh = await vault.read();" in g9_boot
            and "if (markerExists || refresh != null)" in g9_boot
            and "if (!markerExists)" in g9_boot
            and "await journal.arm();" in g9_boot
            and "if (!await journal.requiresReauthentication())" in g9_boot
            and "NativeStartupDisposition.fullReauthentication" in g9_boot
            and "NativeStartupDisposition.cleanLogin" in g9_boot
            and "Future<NativeStartupDisposition>? _inFlight;" in g9_boot
            and "if (_inFlight != null) return _inFlight!;" in g9_boot
            and "Future<void>" not in g9_boot
            and "NativeHttpAuthPort" not in g9_boot
            and "package:http/" not in g9_boot
            and "NativeMobileStartupGate" not in flutter_main
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes
            and "orphan refresh is fenced and gets durable marker" in g9_boot_test
            and "silently ignored orphan marker write fails closed" in g9_boot_test
            and "concurrent inspections share one locked transition" in g9_boot_test
            and "wrong journal fence fails without any protected read" in g9_boot_test
            and "native_mobile_startup_gate_test.dart" in g9_boot_runner
            and "native_refresh_recovery_journal_test.dart" in g9_boot_runner
            and "native_recovery_login_gateway_test.dart" in g9_boot_runner
            and "native_session_coordinator_test.dart" in g9_boot_runner
            and "G9_STARTUP_GATE_BATCH=OK" in g9_boot_runner
            and "NO_DEPLOY_NO_LIVE_MIGRATION=1" in g9_boot_runner,
        "g9_recovery_entry_never_downgrades_to_regular_login":
            "class NativeMobileRecoveryEntry implements NativeLoginGateway" in g9_entry
            and "NativeStartupDisposition.fullReauthentication" in g9_entry
            and "await startup.inspect()" in g9_entry
            and "await recovery.requiresRecovery()" in g9_entry
            and "identical(startup.fence, recovery.fence)" in g9_entry
            and "identical(startup.journal, recovery.journal)" in g9_entry
            and "identical(startup.vault, recovery.vault)" in g9_entry
            and "Native recovery entry not authorized" in g9_entry
            and "return recovery.verifyPassword" in g9_entry
            and "return recovery.verifyTotp" in g9_entry
            and "import 'native_session_coordinator.dart'" not in g9_entry
            and "NativeHttpAuthPort" not in g9_entry
            and "package:http/" not in g9_entry
            and "NativeMobileRecoveryEntry" not in flutter_main
            and "no boot: all credential submissions denied" in g9_entry_test
            and "clean startup cannot bypass unreviewed first-issuance checkpoint" in g9_entry_test
            and "orphan refresh routes exclusively through full recovery" in g9_entry_test
            and "existing marker requires recovery MFA" in g9_entry_test
            and "pending secure read never enables speculative login" in g9_entry_test
            and "native_mobile_recovery_entry_test.dart" in g9_boot_runner
            and "native_mobile_recovery_entry.dart" in g9_boot_runner
            and "NO_DEPLOY_NO_LIVE_MIGRATION=1" in g9_boot_runner,
        "g10_first_issuance_logout_checkpoint":
            "Future<void> confirmFirstIssuance(" in g10_journal
            and "First issuance checkpoint missing" in g10_journal
            and "First issuance requires an empty protected vault" in g10_journal
            and "First issuance storage commit not verified" in g10_journal
            and "First issuance marker deletion not verified" in g10_journal
            and "Future<void> confirmLogoutCompleted(" in g10_journal
            and "Logout credential still protected" in g10_journal
            and "Logout checkpoint deletion not verified" in g10_journal
            and "firstIssuanceJournal" in g10_coordinator
            and "G10 checkpoint required before password" in g10_coordinator
            and "G10 checkpoint required before MFA" in g10_coordinator
            and "issuance.confirmFirstIssuance(" in g10_coordinator
            and "await issuance.arm();" in g10_coordinator
            and "await issuance.confirmLogoutCompleted(vault: vault);" in g10_coordinator
            and "_revokedStoredRefresh" in g10_coordinator
            and "class NativeFirstIssuanceEntry implements NativeLoginGateway" in g10_entry
            and "await startup.inspect()" in g10_entry
            and "await journal.arm();" in g10_entry
            and "if (!await journal.requiresReauthentication())" in g10_entry
            and "First issuance cancelled before network" in g10_entry
            and "return coordinator.verifyPassword(" in g10_entry
            and "return coordinator.verifyTotp(" in g10_entry
            and "return coordinator.logout();" in g10_entry
            and "native_first_issuance_entry_test.dart" in g10_runner
            and "native_mobile_startup_gate_test.dart" in g10_runner
            and "native_mobile_recovery_entry_test.dart" in g10_runner
            and "native_refresh_recovery_journal_test.dart" in g10_runner
            and "G10_ISSUANCE_LOGOUT_BATCH=OK" in g10_runner
            and "NO_DEPLOY_NO_LIVE_MIGRATION=1" in g10_runner
            and "silent checkpoint write fails before any password request" in g10_test
            and "failed remote logout remains durable" in g10_test
            and "failed protected deletion retries without replaying successful revoke" in g10_test
            and "cancelled issuance while marker write waits sends no HTTP" in g10_test
            and "NativeFirstIssuanceEntry" not in flutter_main
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "g11_real_https_first_issue_logout_isolated":
            "Future<void> verifyG11Https(" in g11_scenarios
            and "NativeFirstIssuanceEntry(" in g11_scenarios
            and "NativeMobileRecoveryEntry(" in g11_scenarios
            and "NativeSessionCoordinator(" in g11_scenarios
            and "NativeHttpAuthPort(" in g11_scenarios
            and "NativeMobileStartupGate(" in g11_scenarios
            and "G11_DURABLE_MARKER_REQUIRED_BEFORE_HTTP" in g11_scenarios
            and "G11_FIRST_ISSUANCE_HTTPS_COMMITTED=OK" not in g11_scenarios
            and "'FIRST_ISSUANCE_HTTPS_COMMITTED'" in g11_scenarios
            and "'STORAGE_FAILURE_NO_PASSWORD_HTTP'" in g11_scenarios
            and "'LOST_ISSUANCE_RESPONSE_FENCED'" in g11_scenarios
            and "'FULL_RECOVERY_VERIFIED_HTTPS'" in g11_scenarios
            and "'REMOTE_REVOKE_FAILURE_DURABLE'" in g11_scenarios
            and "'REVOKE_RETRY_SERVER_DENIES_OLD_ACCESS'" in g11_scenarios
            and "'POST_COMMIT_REVOKE_RESPONSE_LOSS_FENCED'" in g11_scenarios
            and "'AMBIGUOUS_REVOKE_RETRY_CANNOT_REOPEN'" in g11_scenarios
            and "lostServerAccess" in g11_scenarios
            and "loseNextRevokeResponse" in g11_scenarios
            and "G11_POST_COMMIT_REVOKE_RESPONSE_LOSS_FENCED=OK" in g11_lab_runner
            and "G11_AMBIGUOUS_REVOKE_RETRY_CANNOT_REOPEN=OK" in g11_lab_runner
            and "'MFA_SERVER_REVOKED_AFTER_LOGOUT'" in g11_scenarios
            and "G11_HTTPS_FIRST_ISSUANCE_LOGOUT_RESULT=0" in g11_scenarios
            and "loseNextPasswordResponse" in g11_scenarios
            and "refuseNextRevoke" in g11_scenarios
            and "void close() {}" in g11_scenarios
            and "import 'g11_https_scenarios.dart' as g11;" in g11_probe
            and "if (group == 'g11')" in g11_probe
            and "await g11.verifyG11Https(" in g11_probe
            and "--group g11" in g11_runner
            and "G11_HTTPS_GATE_RESULT=$status" in g11_runner
            and "G11_HTTPS_FLUTTER_ANALYZE=OK" in g11_runner
            and "NO_DEPLOY_NO_LIVE_MIGRATION=1" in g11_runner
            and "--network \"$NETWORK\"" in g11_lab_runner
            and "--read-only" in g11_lab_runner
            and "--tmpfs /tmp" in g11_lab_runner
            and "G11_HTTPS_FIRST_ISSUANCE_LOGOUT_RESULT=0" in g11_lab_runner
            and "NativeFirstIssuanceEntry" not in flutter_main
            and "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes,
        "lab_issuer_requires_epoch":
            "expected_generation," in session_rules
            and "expected_generation=None" not in session_rules,
    }

    for name, ok in checks.items():
        print(f"N1_STATIC_{name}={'OK' if ok else 'FAIL'}")
        if not ok:
            failures.append(name)

    # Require syntactically valid sources, independent of installed packages.
    for file in (
        "backend/config/settings.py",
        "backend/native_sessions_lab/models.py",
        "backend/native_sessions_lab/migrations/0001_initial.py",
        "backend/native_sessions_lab/session_rules.py",
        "backend/native_sessions_lab/tests.py",
        "backend/native_sessions_lab/test_pg17_race.py",
        "backend/native_sessions_lab/login_rules.py",
        "backend/native_sessions_lab/test_login_rules.py",
        "backend/native_sessions_lab/test_pg17_login_race.py",
        "backend/native_sessions_lab/migrations/0002_mobileloginchallengelab.py",
        "backend/native_sessions_lab/migrations/0003_mobile_account_fence.py",
        "backend/native_sessions_lab/migrations/0004_mobile_challenge_recovery_flag.py",
        "backend/native_sessions_lab/test_urls.py",
        "backend/native_sessions_lab/test_http_contract.py",
        "backend/native_sessions_lab/test_http_contract_cases.py",
        "backend/native_sessions_lab/test_loopback_http_contract.py",
        "backend/native_sessions_lab/test_verified_https_loopback.py",
        "backend/native_sessions_lab/g7_d2_https_fixture.py",
        "backend/native_mobile_service/models.py",
        "backend/native_mobile_service/migrations/0001_initial.py",
        "backend/native_mobile_service/authentication.py",
        "backend/native_mobile_service/session_store.py",
        "backend/native_mobile_service/test_views.py",
        "backend/native_mobile_service/test_urls.py",
        "backend/native_mobile_service/test_contract.py",
        "backend/native_mobile_service/test_pg17_races.py",
        "backend/native_mobile_service/migrations/0002_mobileauthattemptbucket.py",
        "backend/native_mobile_service/g5_network_identity.py",
        "backend/native_mobile_service/g5_throttle.py",
        "backend/native_mobile_service/test_g5_network_identity.py",
        "backend/native_mobile_service/test_g5_throttle.py",
        "backend/native_mobile_service/test_g5_pg17_races.py",
        "backend/native_mobile_service/migrations/0003_mobileauthauditevent.py",
        "backend/native_mobile_service/g5_audit.py",
        "backend/native_mobile_service/test_g5_audit.py",
        "backend/native_mobile_service/test_g5_audit_pg17_races.py",
        "backend/native_mobile_service/g5_keyring_policy.py",
        "backend/native_mobile_service/test_g5_keyring_policy.py",
        "backend/native_mobile_service/migrations/0004_digest_envelope_capacity.py",
        "backend/native_mobile_service/test_g5_digest_capacity.py",
        "backend/native_mobile_service/g14_admission.py",
        "backend/native_mobile_service/test_g14_admission.py",
        "backend/native_mobile_service/g14_issuance_contract.py",
        "backend/native_mobile_service/test_g14_issuance_contract.py",
        "backend/native_mobile_service/test_g14_issuance_atomicity.py",
        "backend/native_mobile_service/g14_locked_verifier.py",
        "backend/native_mobile_service/test_g14_locked_verifier.py",
        "backend/native_mobile_service/test_g14_untrusted_evidence.py",
        "backend/native_mobile_service/g14_d3_candidate_boundary.py",
        "backend/native_mobile_service/test_g14_d3_candidate_boundary.py",
        "backend/native_mobile_service/test_g14_d3_pg17_races.py",
        "backend/native_mobile_service/test_g14_d5_mfa_writer_pg17_races.py",
        "backend/native_mobile_service/test_g14_d8_admin_rotation_pg17.py",
        "backend/native_mobile_service/test_g14_d9_recovery_guards_pg17.py",
        "backend/native_mobile_service/test_g14_d9c_admin_finalization_pg17.py",
        "backend/native_mobile_service/g14_e1_locked_mfa_verifier.py",
        "backend/native_mobile_service/test_g14_e1_locked_mfa_verifier.py",
        "backend/native_mobile_service/test_g14_e1_concurrency_pg17.py",
        "backend/native_mobile_service/test_g14_e1c_transaction_rollback_pg17.py",
        "backend/native_mobile_service/test_g14_e1d_key_custody_pg17.py",
        "scripts/g14_mfa_writer_inventory.py",
        "scripts/test_g14_mfa_writer_inventory.py",
        "scripts/g14_mfa_lock_order_report.py",
        "scripts/test_g14_mfa_lock_order_report.py",
        "scripts/g14_trusted_issuer_boundary.py",
        "scripts/test_g14_trusted_issuer_boundary.py",
        "backend/reminders/native_mobile_identity_gate.py",
        "backend/reminders/native_mobile_token_primitives.py",
    ):
        try:
            ast.parse(read(file), filename=file)
        except (SyntaxError, UnicodeError) as exc:
            failures.append(f"{file}: {type(exc).__name__}")

    print(f"N1_STATIC_GATE_RESULT={'FAIL' if failures else 'OK'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(verify())
