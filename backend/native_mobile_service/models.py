"""Persistent mobile identity schema CANDIDATE, never registered outside tests.

Unlike native_sessions_lab, these names and constraints are a release proposal.
They are not part of reminders migrations or the deployed database.
"""
import uuid

from django.conf import settings
from django.db import models


class MobileAccountFence(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="+", primary_key=True,
    )
    generation = models.PositiveBigIntegerField(default=0)


class MobileDeviceSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="+",
    )
    access_digest = models.CharField(max_length=64)
    refresh_digest = models.CharField(max_length=64)
    credential_version = models.CharField(max_length=64)
    auth_generation = models.PositiveBigIntegerField(default=0)
    verified_mfa = models.BooleanField(default=False)
    mfa_epoch = models.PositiveIntegerField(null=True, blank=True)
    access_expires_at = models.DateTimeField()
    refresh_expires_at = models.DateTimeField()
    rotation_generation = models.PositiveBigIntegerField(default=0)
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "revoked_at"], name="nms_user_revoke_idx"),
            models.Index(fields=["refresh_expires_at"], name="nms_refresh_exp_idx"),
        ]


class MobileSpentRefresh(models.Model):
    session = models.ForeignKey(
        MobileDeviceSession, on_delete=models.CASCADE,
        related_name="spent_refreshes",
    )
    digest = models.CharField(max_length=64, unique=True)
    spent_at = models.DateTimeField(auto_now_add=True)


class MobileAuthAttemptBucket(models.Model):
    """G5 test-only shared throttle ledger; HMAC subject, never a raw IP/login."""

    scope = models.CharField(max_length=12)
    subject_digest = models.CharField(max_length=64)
    window_started_at = models.DateTimeField()
    attempt_count = models.PositiveIntegerField(default=0)
    blocked_until = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["scope", "subject_digest"], name="nms_abuse_scope_subject_uq",
            ),
        ]
        indexes = [
            models.Index(fields=["blocked_until"], name="nms_abuse_block_idx"),
        ]


class MobileAuthAuditEvent(models.Model):
    """G5 lab-only immutable-shaped security event without raw credentials."""

    event_id = models.UUIDField(primary_key=True, editable=False)
    event_type = models.CharField(max_length=24)
    actor_digest = models.CharField(max_length=64, blank=True)
    session_id = models.UUIDField(null=True, blank=True)
    occurred_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["occurred_at"], name="nms_audit_age_idx"),
            models.Index(fields=["event_type", "occurred_at"], name="nms_audit_type_age_idx"),
        ]
