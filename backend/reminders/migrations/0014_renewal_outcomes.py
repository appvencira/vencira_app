"""O3 outcomes and archive markers; additive with no rewriting old 'closed' data."""
import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0013_renewal_manual_followups"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="renewal", name="archived_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="renewal", name="archive_outcome",
            field=models.CharField(blank=True, default="", max_length=16,
                choices=[("won", "Conseguido"), ("discarded", "Descartado")]),
        ),
        migrations.CreateModel(
            name="RenewalOutcome",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("kind", models.CharField(max_length=16, choices=[
                    ("won", "Conseguido"), ("declined", "No aceptó"),
                    ("undecided", "Aún sin decidir"),
                    ("discarded", "Descartar"),
                    ("restored", "Recuperado del archivo")])),
                ("previous_expiry", models.DateField(blank=True, null=True)),
                ("new_expiry", models.DateField(blank=True, null=True)),
                ("follow_up_for", models.DateField(blank=True, null=True)),
                ("previous_entry", models.CharField(
                    blank=True, default="", max_length=16)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("renewal", models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="resolution_events", to="reminders.renewal")),
                ("actor", models.ForeignKey(
                    null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name="vencira_outcomes", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at", "-id"],
                "indexes": [
                    models.Index(fields=["renewal", "-created_at"],
                        name="outcome_renewal_time_idx"),
                ],
            },
        ),
    ]
