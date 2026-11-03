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
            and "d2|e|f|g|h)" in g7_d2_runner
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
