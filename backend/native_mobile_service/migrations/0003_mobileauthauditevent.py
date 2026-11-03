"""G5 candidate-only audit schema; not installed in production."""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("native_mobile_service", "0002_mobileauthattemptbucket"),
    ]

    operations = [
        migrations.CreateModel(
            name="MobileAuthAuditEvent",
            fields=[
                ("event_id", models.UUIDField(primary_key=True, serialize=False, editable=False)),
                ("event_type", models.CharField(max_length=24)),
                ("actor_digest", models.CharField(max_length=64, blank=True)),
                ("session_id", models.UUIDField(null=True, blank=True)),
                ("occurred_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={
                "indexes": [
                    models.Index(fields=["occurred_at"], name="nms_audit_age_idx"),
                    models.Index(fields=["event_type", "occurred_at"], name="nms_audit_type_age_idx"),
                ],
            },
        ),
    ]
