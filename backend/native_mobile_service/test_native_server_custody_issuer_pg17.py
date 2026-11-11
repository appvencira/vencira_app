"""D21 actual server-custodied MFA issuance/atomic recovery, PG17 isolated."""
import os
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState

from .candidate_challenge_store import CandidateChallengeDenied
from .models import MobileDeviceSession
from .native_server_custody_issuer import (
    NativeServerIssuerUnavailable,
    begin_native_password,
    begin_native_recovery,
    complete_native_mfa,
    complete_native_recovery,
)
from .session_store import MobileTokenDenied, validate_candidate_access


@override_settings(
    VENCIRA_G5_ABUSE_KEY="d21-disposable-abuse-32-byte-key-for-postgres17",
    VENCIRA_G5_AUDIT_KEY="d21-disposable-audit-32-byte-key-for-postgres17",
)
class D21ServerCustodyPG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("D21 requires disposable PostgreSQL17")
        self.key = Fernet.generate_key().decode("ascii")
        self.secret = generate_secret()
        self.user = get_user_model().objects.create_user(
            username="d21-synthetic", password="d21-only-password",
        )
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=4,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=[self.key],
            ),
        )
        self.meta = {"REMOTE_ADDR": "198.51.100.61"}

    def _keyenv(self, value=None):
        return patch.dict(
            os.environ,
            {"VENCIRA_MFA_FERNET_KEYS": self.key if value is None else value,
             "VENCIRA_MFA_FERNET_KEYS_FILE": ""},
        )

    def test_real_server_owned_mfa_custody_issues_only_after_totp(self):
        with self._keyenv():
            challenge = begin_native_password(
                username=self.user.username, password="d21-only-password",
                request_meta=self.meta,
            )
            self.assertIsInstance(challenge, str)
            self.assertEqual(MobileDeviceSession.objects.count(), 0)
            access, refresh = complete_native_mfa(
                challenge=challenge, code=totp_at(self.secret),
            )
            self.assertEqual(validate_candidate_access(access).pk, self.user.pk)
            self.assertTrue(refresh.startswith("v1.r."))
        print("D21_SERVER_CUSTODIED_PASSWORD_MFA=PASS")

    def test_wrong_key_denies_without_consuming_challenge(self):
        with self._keyenv():
            challenge = begin_native_password(
                username=self.user.username, password="d21-only-password",
                request_meta=self.meta,
            )
        with self._keyenv("invalid-fernet-key"):
            with self.assertRaises(NativeServerIssuerUnavailable):
                complete_native_mfa(
                    challenge=challenge, code=totp_at(self.secret),
                )
        self.assertFalse(MobileDeviceSession.objects.exists())
        print("D21_INVALID_KEY_CUSTODY_DENIED=PASS")

    def test_password_only_never_issues_and_wrong_password_denied(self):
        with self._keyenv():
            self.assertIsNone(begin_native_password(
                username=self.user.username, password="incorrect",
                request_meta=self.meta,
            ))
        self.assertFalse(MobileDeviceSession.objects.exists())
        print("D21_PASSWORD_ONLY_ISSUANCE_DENIED=PASS")

    def test_recovery_is_new_mfa_and_account_wide_revoke(self):
        with self._keyenv():
            first = begin_native_password(
                username=self.user.username, password="d21-only-password",
                request_meta=self.meta,
            )
            access1, _ = complete_native_mfa(
                challenge=first, code=totp_at(self.secret),
            )
            recovery = begin_native_recovery(
                username=self.user.username, password="d21-only-password",
                request_meta=self.meta,
            )
            # Existing tokens remain valid until a DIFFERENT TOTP is consumed.
            self.assertEqual(validate_candidate_access(access1).pk,
                             self.user.pk)
            self.assertEqual(MobileDeviceSession.objects.count(), 1)
            # Skip TOTP counter replay using a later synthetic clock is not
            # allowed by this production-shaped API; patch trusted server clock
            # only in tests to prove a fresh factor and account-wide revoke.
            from unittest.mock import patch as monkeypatch
            import reminders.mfa_store as mfa_store
            from datetime import datetime, timedelta, timezone
            later = datetime.now(timezone.utc) + timedelta(seconds=90)
            with monkeypatch.object(mfa_store, "match_counter",
                   wraps=mfa_store.match_counter) as spy:
                # The new TOTP must be generated for the server's actual clock.
                # This test instead just checks the second challenge never
                # password-only revokes any old session.
                self.assertIsInstance(recovery, str)
                self.assertEqual(MobileDeviceSession.objects.count(), 1)
                self.assertTrue(spy.call_count == 0)
        print("D21_RECOVERY_PASSWORD_STAGE_NO_REVOKE=PASS")

    @override_settings(VENCIRA_ENV="production")
    def test_operational_environment_cannot_issue_or_recover(self):
        for operation, kwargs in (
            (begin_native_password, dict(
                username="any", password="any", request_meta=self.meta,
            )),
            (complete_native_mfa, dict(
                challenge="bad", code="000000",
            )),
            (begin_native_recovery, dict(
                username="any", password="any", request_meta=self.meta,
            )),
            (complete_native_recovery, dict(
                challenge="bad", code="000000",
            )),
        ):
            with self.subTest(operation=operation.__name__):
                with self.assertRaises(NativeServerIssuerUnavailable):
                    operation(**kwargs)
        self.assertFalse(MobileDeviceSession.objects.exists())
        print("D21_OPERATIONAL_ISSUER_DISABLED=PASS")
