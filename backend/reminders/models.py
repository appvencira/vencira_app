"""Base de datos inicial: organizaciones y vencimientos sin API pública."""
import uuid
from django.conf import settings
from django.db import models

class Workspace(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=140)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class WorkspaceMember(models.Model):
    class Role(models.TextChoices):
        OWNER = "owner", "Propietario"
        MEMBER = "member", "Miembro"

    workspace = models.ForeignKey(Workspace, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="vencira_memberships")
    role = models.CharField(max_length=16, choices=Role.choices, default=Role.MEMBER)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["workspace", "user"], name="uniq_workspace_user")]

class Renewal(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pendiente"
        CONTACTED = "contacted", "Contactado"
        CLOSED = "closed", "Cerrado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(Workspace, on_delete=models.CASCADE, related_name="renewals")
    customer_reference = models.CharField(max_length=160)
    expires_on = models.DateField()
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [models.Index(fields=["workspace", "expires_on"], name="renewal_ws_exp_idx")]
        ordering = ["expires_on", "id"]

    def __str__(self):
        return f"{self.customer_reference} — {self.expires_on}"

class LoginAttemptBucket(models.Model):
    """Contador compartido entre workers; clave HMAC, sin almacenar nombre."""
    key = models.CharField(max_length=64, primary_key=True)
    failures = models.PositiveSmallIntegerField(default=0)
    started_at = models.DateTimeField()
    blocked_until = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
