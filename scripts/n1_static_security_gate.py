#!/usr/bin/env python3
"""Fail-closed, read-only N1 release boundary guard.

Static evidence complements tests; it does not authorize token issuance.
Runs with stdlib, without Django settings, Docker, database or network.
"""
from pathlib import Path
import ast

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
        "g5_keyring_not_connected":
            "CandidateKeyring" in g5_keyring
            and "DJANGO_SECRET_KEY" not in g5_keyring.replace("Django SECRET_KEY", "")
            and "g5_keyring_policy" not in config
            and "g5_keyring_policy" not in routes,
        "g5_versioned_digest_capacity":
            "max_length=96" in candidate_schema
            and "0004_digest_envelope_capacity" not in config
            and "native_mobile_service" not in routes,
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
