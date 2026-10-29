import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("reminders", "0003_reminder_candidates"),
    ]

    operations = [
        migrations.CreateModel(
            name="RenewalAuditEvent",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("action", models.CharField(choices=[("created", "Creado"), ("updated", "Modificado")], max_length=12)),
                ("changed_fields", models.JSONField(default=list)),
                ("metadata", models.JSONField(default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("actor", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="vencira_renewal_events", to=settings.AUTH_USER_MODEL)),
                ("renewal", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="audit_events", to="reminders.renewal")),
                ("workspace", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="renewal_audit_events", to="reminders.workspace")),
            ],
            options={
                "ordering": ["created_at", "id"],
                "indexes": [
                    models.Index(fields=["workspace", "created_at"], name="audit_ws_time_idx"),
                    models.Index(fields=["renewal", "created_at"], name="audit_renew_time_idx"),
                ],
            },
        ),
    ]
