"""Django schema exercised ONLY by VENCIRA_ENV=test ephemeral databases."""
import uuid

from django.conf import settings
from django.db import models


class MobileDeviceSessionLab(models.Model):
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
    generation = models.PositiveIntegerField(default=0)
    revoked_at = models.DateTimeField(null=True, blank=True)


class SpentRefreshLab(models.Model):
    session = models.ForeignKey(
        MobileDeviceSessionLab, on_delete=models.CASCADE,
        related_name="spent_refreshes",
    )
    digest = models.CharField(max_length=64, unique=True)


class MobileLoginChallengeLab(models.Model):
    """Single-use second-factor challenge; TEST APP ONLY, never deployed."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="+",
    )
    secret_digest = models.CharField(max_length=64)
    credential_version = models.CharField(max_length=64)
    mfa_epoch = models.PositiveIntegerField()
    auth_generation = models.PositiveBigIntegerField(default=0)
    expires_at = models.DateTimeField()
    consumed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class MobileAccountFenceLab(models.Model):
    """Account revocation epoch; lab-only persistent serialization fence."""
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        primary_key=True, related_name="+",
    )
    generation = models.PositiveBigIntegerField(default=0)
