"""G5 test-only antiabuse ledger; NEVER migrate the persistent database."""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("native_mobile_service", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="MobileAuthAttemptBucket",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("scope", models.CharField(max_length=12)),
                ("subject_digest", models.CharField(max_length=64)),
                ("window_started_at", models.DateTimeField()),
                ("attempt_count", models.PositiveIntegerField(default=0)),
                ("blocked_until", models.DateTimeField(blank=True, null=True)),
            ],
            options={
                "indexes": [
                    models.Index(fields=["blocked_until"], name="nms_abuse_block_idx"),
                ],
                "constraints": [
                    models.UniqueConstraint(fields=("scope", "subject_digest"), name="nms_abuse_scope_subject_uq"),
                ],
            },
        ),
    ]
