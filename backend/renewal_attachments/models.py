"""Independent attachment schema candidate; NOT installed in Django yet.

Do not enable alongside reminders.0027 without a reviewed transition: both
models represent attachments and the historical model is still in reminders.
"""
import uuid
from django.conf import settings
from django.db import models


class RenewalAttachment(models.Model):
    class State(models.TextChoices):
        QUARANTINED = "quarantined", "En cuarentena"
        CLEAN = "clean", "Revisado"
        REJECTED = "rejected", "Rechazado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    renewal = models.ForeignKey("reminders.Renewal", on_delete=models.PROTECT,
                                related_name="independent_attachments")
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True,
                                    on_delete=models.SET_NULL,
                                    related_name="vencira_independent_uploaded_attachments")
    display_name = models.CharField(max_length=120)
    content_type = models.CharField(max_length=40)
    byte_size = models.PositiveIntegerField()
    sha256 = models.CharField(max_length=64)
    storage_key = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    state = models.CharField(max_length=16, choices=State.choices,
                             default=State.QUARANTINED)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["renewal", "-created_at"],
                                name="ratt_renewal_time_idx")]
        constraints = [models.CheckConstraint(condition=models.Q(byte_size__gt=0),
                                              name="ratt_positive_bytes")]
        ordering = ["-created_at", "-id"]


class AttachmentScanEvidence(models.Model):
    """Audit-only evidence. A CLEAN verdict never grants file access."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    attachment = models.ForeignKey(
        RenewalAttachment, on_delete=models.PROTECT, related_name="scan_evidence")
    payload = models.JSONField()
    signature = models.CharField(max_length=64)
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-recorded_at", "-id"]
        constraints = [models.UniqueConstraint(
            fields=["attachment"], name="unique_attachment_scan_evidence")]


class AttachmentDiscardJob(models.Model):
    """Durable test-only deletion outbox; never grants download access."""
    class Status(models.TextChoices):
        PENDING = "pending", "Pendiente"
        COMPLETED = "completed", "Completado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    attachment = models.OneToOneField(
        RenewalAttachment, on_delete=models.PROTECT,
        related_name="discard_job")
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.PENDING)
    attempts = models.PositiveIntegerField(default=0)
    last_error = models.CharField(max_length=80, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
