"""Manual follow-up dates: additive, with unique active schedule per annotation."""
import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0012_renewal_notes"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="RenewalFollowUp",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("scheduled_for", models.DateField()),
                ("state", models.CharField(choices=[
                    ("planned", "Previsto"), ("completed", "Atendido"),
                    ("cancelled", "Cancelado"),
                ], default="planned", max_length=16)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("renewal", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="manual_follow_ups", to="reminders.renewal")),
                ("created_by", models.ForeignKey(
                    null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name="vencira_manual_followups_created",
                    to=settings.AUTH_USER_MODEL)),
                ("closed_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="vencira_manual_followups_closed",
                    to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "indexes": [
                    models.Index(fields=["scheduled_for", "state"],
                                 name="manual_follow_due_idx"),
                ],
                "constraints": [
                    models.UniqueConstraint(fields=["renewal"],
                        condition=models.Q(state="planned"),
                        name="uniq_planned_followup"),
                ],
            },
        ),
    ]
