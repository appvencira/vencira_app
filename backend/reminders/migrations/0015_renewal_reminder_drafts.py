"""O8c: add per-renewal DRAFT-only reminder preferences. No backfill or jobs."""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0014_renewal_outcomes"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="RenewalReminderDraft",
            fields=[
                ("renewal", models.OneToOneField(
                    to="reminders.renewal", primary_key=True, serialize=False,
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="reminder_draft")),
                ("days_before", models.JSONField(default=list)),
                ("state", models.CharField(
                    max_length=12, default="draft",
                    choices=[("draft", "Borrador")])),
                ("revision", models.PositiveIntegerField(default=1)),
                ("created_by", models.ForeignKey(
                    to=settings.AUTH_USER_MODEL, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="vencira_created_reminder_drafts")),
                ("updated_by", models.ForeignKey(
                    to=settings.AUTH_USER_MODEL, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="vencira_updated_reminder_drafts")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"constraints": [
                models.CheckConstraint(
                    condition=models.Q(state="draft"),
                    name="renewal_reminder_draft_only",
                ),
                models.CheckConstraint(
                    condition=models.Q(revision__gte=1),
                    name="renewal_reminder_revision_positive",
                ),
            ]},
        ),
    ]
