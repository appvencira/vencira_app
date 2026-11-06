"""G5 digest capacity and legacy-format coexistence on disposable Django DB.

Schema capacity is NOT a migration or automatic conversion of old digests.
"""
from datetime import timedelta
import uuid

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone

from .g5_keyring_policy import CandidateKey, CandidateKeyring
from .models import (
    MobileAccountFence, MobileAuthAttemptBucket,
    MobileAuthAuditEvent, MobileDeviceSession, MobileSpentRefresh,
)


class G5DigestCapacityTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="g5-capacity-synthetic",
            password="G5SyntheticPassword-2026!",
        )

    def test_all_digest_columns_fit_maximum_versioned_envelope(self):
        ring = CandidateKeyring(
            active=CandidateKey("k" + "a" * 19, b"k" * 32),
        )
        digest = ring.digest(purpose="mobile-access", value=b"synthetic")
        self.assertEqual(len(digest), 88)
        fields = (
            (MobileDeviceSession, "access_digest"),
            (MobileDeviceSession, "refresh_digest"),
            (MobileSpentRefresh, "digest"),
            (MobileAuthAttemptBucket, "subject_digest"),
            (MobileAuthAuditEvent, "actor_digest"),
        )
        for model, name in fields:
            with self.subTest(model=model.__name__, name=name):
                self.assertGreaterEqual(model._meta.get_field(name).max_length, len(digest))

    def test_long_versioned_digest_and_legacy_digest_can_coexist_without_rehash(self):
        ring = CandidateKeyring(
            active=CandidateKey("version2026", b"k" * 32),
        )
        versioned = ring.digest(purpose="mobile-refresh", value=b"fake-secret")
        legacy = "b" * 64
        now = timezone.now()
        row = MobileDeviceSession.objects.create(
            user=self.user,
            access_digest=legacy,
            refresh_digest=versioned,
            credential_version="v" * 64,
            access_expires_at=now + timedelta(minutes=5),
            refresh_expires_at=now + timedelta(days=30),
        )
        MobileSpentRefresh.objects.create(session=row, digest=versioned)
        MobileAuthAttemptBucket.objects.create(
            scope="account", subject_digest=versioned,
            window_started_at=now,
        )
        MobileAuthAuditEvent.objects.create(
            event_id=uuid.uuid4(), event_type="auth_denied",
            actor_digest=versioned,
        )
        row.refresh_from_db()
        self.assertEqual(row.access_digest, legacy)
        self.assertEqual(row.refresh_digest, versioned)
        self.assertTrue(MobileSpentRefresh.objects.filter(digest=versioned).exists())
        self.assertEqual(MobileAuthAttemptBucket.objects.get().subject_digest, versioned)
        self.assertEqual(MobileAuthAuditEvent.objects.get().actor_digest, versioned)

    def test_previous_key_does_not_sign_new_digest(self):
        ring = CandidateKeyring(
            active=CandidateKey("current", b"c" * 32),
            previous=(CandidateKey(
                "old", b"o" * 32,
                verify_until=timezone.now() + timedelta(days=1),
            ),),
        )
        self.assertTrue(ring.digest(purpose="mobile-refresh", value=b"x").startswith("k1:current:"))
        self.assertFalse(ring.verify(
            purpose="mobile-refresh", value=b"x", stored="a" * 64,
        ))
