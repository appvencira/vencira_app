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

class WorkspaceModality(models.Model):
    """Opciones de Modalidad por cuenta, con códigos inmutables al renombrar."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="modality_options"
    )
    code = models.CharField(max_length=64)
    label = models.CharField(max_length=80)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["workspace", "code"], name="uniq_workspace_modality_code"
            ),
        ]
        ordering = ["code"]


class WorkspaceInsurer(models.Model):
    """Aseguradora añadida a una cuenta; no es un registro regulatorio verificado."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="insurer_options",
    )
    name = models.CharField(max_length=140)
    # Normalización para evitar nombres duplicados cambiando mayúsculas.
    normalized_name = models.CharField(max_length=140)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["workspace", "normalized_name"],
                name="uniq_workspace_insurer_name",
            ),
        ]
        ordering = ["name", "id"]


class Renewal(models.Model):
    class Entry(models.TextChoices):
        CLIENTS = "clients", "Clientes"
        PROSPECTS = "prospects", "Candidatos"

    class Status(models.TextChoices):
        PENDING = "pending", "Pendiente"
        CONTACTED = "contacted", "Contactado"
        CLOSED = "closed", "Cerrado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(Workspace, on_delete=models.CASCADE, related_name="renewals")
    # Las filas históricas sin asignar quedan visibles solo para el propietario.
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="vencira_assigned_renewals",
        null=True,
        blank=True,
    )
    customer_reference = models.CharField(max_length=160)
    # Datos propios de cada póliza externa; sin entidad global de cliente.
    full_name = models.CharField(max_length=160, blank=True, default="")
    nickname = models.CharField(max_length=80, blank=True, default="")
    phone = models.CharField(max_length=32, blank=True, default="")
    email = models.EmailField(blank=True, default="")
    policy_number = models.CharField(max_length=100, blank=True, default="")
    notes = models.TextField(blank=True, default="")
    # Nullable para conservar anotaciones previas; Flutter exigirá Entrada
    # para nuevas anotaciones. No clasificamos automáticamente las antiguas.
    entry = models.CharField(
        max_length=16, choices=Entry.choices, null=True, blank=True,
    )
    modality = models.CharField(max_length=80, blank=True, default="")
    insurer = models.ForeignKey(
        WorkspaceInsurer, on_delete=models.PROTECT,
        related_name="renewals", null=True, blank=True,
    )
    expires_on = models.DateField()
    notice_deadline_on = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    # Resultado archivado, distinto del estado operativo legacy 'closed'.
    archived_at = models.DateTimeField(null=True, blank=True)
    archive_outcome = models.CharField(
        max_length=16, choices=[("won", "Conseguido"),
                                ("discarded", "Descartado")],
        blank=True, default="",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["workspace", "expires_on"], name="renewal_ws_exp_idx"),
            models.Index(
                fields=["workspace", "assigned_to", "expires_on"],
                name="renewal_ws_ass_exp",
            ),
        ]
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(notice_deadline_on__isnull=True)
                    | models.Q(notice_deadline_on__lte=models.F("expires_on"))
                ),
                name="renewal_notice_lte_expiry",
            ),
        ]
        ordering = ["expires_on", "id"]

    def __str__(self):
        return f"{self.customer_reference} — {self.expires_on}"

class RenewalFollowUp(models.Model):
    """Seguimiento manual civil por anotación; nunca es notificación enviada."""

    class State(models.TextChoices):
        PLANNED = "planned", "Previsto"
        COMPLETED = "completed", "Atendido"
        CANCELLED = "cancelled", "Cancelado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    renewal = models.ForeignKey(
        Renewal, on_delete=models.CASCADE, related_name="manual_follow_ups",
    )
    scheduled_for = models.DateField()
    state = models.CharField(
        max_length=16, choices=State.choices, default=State.PLANNED,
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL,
        related_name="vencira_manual_followups_created",
    )
    closed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name="vencira_manual_followups_closed",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["renewal"], condition=models.Q(state="planned"),
                name="uniq_planned_followup",
            ),
        ]
        indexes = [
            models.Index(fields=["scheduled_for", "state"],
                name="manual_follow_due_idx"),
        ]


class RenewalOutcome(models.Model):
    """Decisión de seguimiento registrada con usuario y fecha; no es un CRM."""

    class Kind(models.TextChoices):
        WON = "won", "Conseguido"
        DECLINED = "declined", "No aceptó"
        UNDECIDED = "undecided", "Aún sin decidir"
        DISCARDED = "discarded", "Descartar"
        RESTORED = "restored", "Recuperado del archivo"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    renewal = models.ForeignKey(
        Renewal, on_delete=models.PROTECT, related_name="resolution_events",
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name="vencira_outcomes",
    )
    kind = models.CharField(max_length=16, choices=Kind.choices)
    previous_expiry = models.DateField(null=True, blank=True)
    new_expiry = models.DateField(null=True, blank=True)
    follow_up_for = models.DateField(null=True, blank=True)
    previous_entry = models.CharField(max_length=16, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["renewal", "-created_at"],
                         name="outcome_renewal_time_idx"),
        ]
        ordering = ["-created_at", "-id"]


class LoginAttemptBucket(models.Model):
    """Contador compartido entre workers; clave HMAC, sin almacenar nombre."""
    key = models.CharField(max_length=64, primary_key=True)
    failures = models.PositiveSmallIntegerField(default=0)
    started_at = models.DateTimeField()
    blocked_until = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

class RenewalReminderDraft(models.Model):
    """O8c: configuración de avisos por anotación, solo BORRADOR.

    No crea ReminderCandidate ni activa ninguna política de organización.
    La versión hace imposible sobrescribir un borrador sin verificar cambios.
    """
    renewal = models.OneToOneField(
        Renewal, on_delete=models.CASCADE, primary_key=True,
        related_name="reminder_draft",
    )
    days_before = models.JSONField(default=list)
    state = models.CharField(
        max_length=12, default="draft", choices=[("draft", "Borrador")],
    )
    revision = models.PositiveIntegerField(default=1)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL,
        related_name="vencira_created_reminder_drafts",
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL,
        related_name="vencira_updated_reminder_drafts",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(state="draft"),
                name="renewal_reminder_draft_only",
            ),
            models.CheckConstraint(
                condition=models.Q(revision__gte=1),
                name="renewal_reminder_revision_positive",
            ),
        ]


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
            models.CheckConstraint(
                condition=models.Q(basis__in=["expiry", "notice_deadline"]),
                name="policy_basis_valid",
            ),
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
