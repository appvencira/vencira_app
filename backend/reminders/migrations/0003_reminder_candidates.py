import uuid
import django.core.validators
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0002_loginattemptbucket")]

    operations = [
        migrations.CreateModel(
            name="ReminderPolicy",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("days_before", models.PositiveSmallIntegerField(validators=[django.core.validators.MaxValueValidator(365)])),
                ("enabled", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("workspace", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reminder_policies", to="reminders.workspace")),
            ],
        ),
        migrations.CreateModel(
            name="ReminderCandidate",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("scheduled_for", models.DateField()),
                ("state", models.CharField(choices=[("planned", "Previsto"), ("cancelled", "Cancelado")], default="planned", max_length=16)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("policy", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="candidates", to="reminders.reminderpolicy")),
                ("renewal", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reminder_candidates", to="reminders.renewal")),
            ],
        ),
        migrations.AddConstraint(
            model_name="reminderpolicy",
            constraint=models.UniqueConstraint(fields=("workspace", "days_before"), name="uniq_reminder_policy_ws_day"),
        ),
        migrations.AddConstraint(
            model_name="reminderpolicy",
            constraint=models.CheckConstraint(condition=models.Q(("days_before__lte", 365)), name="policy_days_lte_365"),
        ),
        migrations.AddConstraint(
            model_name="remindercandidate",
            constraint=models.UniqueConstraint(fields=("renewal", "policy", "scheduled_for"), name="uniq_reminder_candidate"),
        ),
        migrations.AddIndex(
            model_name="remindercandidate",
            index=models.Index(fields=["scheduled_for", "state"], name="candidate_due_idx"),
        ),
    ]
