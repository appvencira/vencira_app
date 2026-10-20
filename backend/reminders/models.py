"""Base de datos inicial: organizaciones y vencimientos sin API pública."""
import uuid
from django.conf import settings
from django.core.validators import MaxValueValidator
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
    notice_deadline_on = models.DateField(null=True, blank=True)
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

class ReminderPolicy(models.Model):
    """Regla voluntaria por organización. Deshabilitada por defecto."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(Workspace, on_delete=models.CASCADE, related_name="reminder_policies")
    class Basis(models.TextChoices):
        EXPIRY = "expiry", "Vencimiento"
        NOTICE_DEADLINE = "notice_deadline", "Límite de preaviso"

    basis = models.CharField(max_length=16, choices=Basis.choices, default=Basis.EXPIRY)
    days_before = models.PositiveSmallIntegerField(validators=[MaxValueValidator(365)])
    enabled = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["workspace", "basis", "days_before"], name="uniq_policy_workspace_basis_day"),
            models.CheckConstraint(condition=models.Q(days_before__lte=365), name="policy_days_lte_365"),
        ]


class ReminderCandidate(models.Model):
    """Previsión de aviso SIN canal ni envío; estado conciliado y deduplicado."""
    class State(models.TextChoices):
        PLANNED = "planned", "Previsto"
        CANCELLED = "cancelled", "Cancelado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    renewal = models.ForeignKey(Renewal, on_delete=models.CASCADE, related_name="reminder_candidates")
    policy = models.ForeignKey(ReminderPolicy, on_delete=models.CASCADE, related_name="candidates")
    scheduled_for = models.DateField()
    state = models.CharField(max_length=16, choices=State.choices, default=State.PLANNED)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["renewal", "policy", "scheduled_for"],
                name="uniq_reminder_candidate",
            ),
        ]
        indexes = [models.Index(fields=["scheduled_for", "state"], name="candidate_due_idx")]

class RenewalAuditEvent(models.Model):
    """Rastro interno de cambios realizados por API; sin referencia de cliente en texto."""
    class Action(models.TextChoices):
        CREATED = "created", "Creado"
        UPDATED = "updated", "Modificado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(
        Workspace, on_delete=models.PROTECT, related_name="renewal_audit_events"
    )
    renewal = models.ForeignKey(
        Renewal, on_delete=models.PROTECT, related_name="audit_events"
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name="vencira_renewal_events",
    )
    action = models.CharField(max_length=12, choices=Action.choices)
    changed_fields = models.JSONField(default=list)
    metadata = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["workspace", "created_at"], name="audit_ws_time_idx"),
            models.Index(fields=["renewal", "created_at"], name="audit_renew_time_idx"),
        ]
        ordering = ["created_at", "id"]
