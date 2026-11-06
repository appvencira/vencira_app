"""O9b-2 additive schema only: control response intents, never notifications."""
import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0015_renewal_reminder_drafts"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="RenewalControlResponse",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("answer", models.CharField(max_length=3, choices=[("yes", "Sí"), ("no", "No")])),
                ("yes_option", models.CharField(max_length=32, blank=True, default="")),
                ("repeat_on", models.DateField(null=True, blank=True)),
                ("cutoff_on", models.DateField()),
                ("answered_at", models.DateTimeField(auto_now_add=True)),
                ("revision", models.PositiveIntegerField(default=1)),
                ("idempotency_key", models.UUIDField()),
                ("renewal", models.ForeignKey(to="reminders.renewal", on_delete=django.db.models.deletion.PROTECT, related_name="control_responses")),
                ("actor", models.ForeignKey(to=settings.AUTH_USER_MODEL, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="vencira_control_responses")),
            ],
            options={
                "ordering": ["answered_at", "id"],
                "constraints": [
                    models.UniqueConstraint(fields=["renewal", "idempotency_key"], name="uniq_control_response_retry"),
                    models.UniqueConstraint(fields=["renewal", "revision"], name="uniq_control_response_revision"),
                    models.CheckConstraint(condition=models.Q(revision__gte=1), name="control_response_revision_positive"),
                    models.CheckConstraint(condition=(
                        models.Q(answer="yes", yes_option__in=["notified_by_client", "insurer_not_renewing", "notified_by_mediator"], repeat_on__isnull=True)
                        | models.Q(answer="no", yes_option="", repeat_on__isnull=False, repeat_on__lte=models.F("cutoff_on"))
                    ), name="control_response_choice_shape"),
                ],
            },
        ),
    ]
