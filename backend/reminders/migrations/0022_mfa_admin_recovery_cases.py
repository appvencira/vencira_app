"""D1.5-S1B: tablas administrativas inertes, no autorizan reset ni despliegue."""
import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0021_mfa_prepared_at"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]
    operations = [
        migrations.CreateModel(
            name="MfaAdministrativeRecoveryCase",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("status", models.CharField(max_length=12, default="pending", choices=[
                    ("pending", "Pendiente"), ("rejected", "Rechazado"),
                    ("expired", "Caducado"), ("cancelled", "Cancelado"), ("closed", "Cerrado"),
                ])),
                ("channel_verified_at", models.DateTimeField(null=True, blank=True)),
                ("quarantine_until", models.DateTimeField()),
                ("expires_at", models.DateTimeField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("requester", models.ForeignKey(to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.PROTECT, related_name="vencira_requested_mfa_recoveries")),
                ("subject", models.ForeignKey(to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.PROTECT, related_name="vencira_mfa_recovery_cases")),
            ],
            options={"indexes": [models.Index(fields=["subject", "status"], name="mfa_rec_subject_status")]},
        ),
        migrations.CreateModel(
            name="MfaAdministrativeRecoveryApproval",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("expires_at", models.DateTimeField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("case", models.ForeignKey(to="reminders.mfaadministrativerecoverycase", on_delete=django.db.models.deletion.PROTECT, related_name="approvals")),
                ("reviewer", models.ForeignKey(to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.PROTECT, related_name="vencira_mfa_recovery_approvals")),
            ],
            options={"constraints": [models.UniqueConstraint(fields=("case", "reviewer"), name="uniq_mfa_case_reviewer")]},
        ),
        migrations.CreateModel(
            name="MfaAdministrativeRecoveryEvent",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("action", models.CharField(max_length=32)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("actor", models.ForeignKey(to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.PROTECT, related_name="vencira_mfa_recovery_events")),
                ("case", models.ForeignKey(to="reminders.mfaadministrativerecoverycase", on_delete=django.db.models.deletion.PROTECT, related_name="events")),
            ],
        ),
    ]
