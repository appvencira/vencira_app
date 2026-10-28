"""Candidate independent attachment schema. No MFA dependencies."""
import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [
        ("reminders", "0018_draft_reasons"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]
    operations = [
        migrations.CreateModel(
            name="RenewalAttachment",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4,
                                        editable=False, serialize=False)),
                ("display_name", models.CharField(max_length=120)),
                ("content_type", models.CharField(max_length=40)),
                ("byte_size", models.PositiveIntegerField()),
                ("sha256", models.CharField(max_length=64)),
                ("storage_key", models.UUIDField(default=uuid.uuid4,
                                                 unique=True, editable=False)),
                ("state", models.CharField(max_length=16, choices=[
                    ("quarantined", "En cuarentena"),
                    ("clean", "Revisado"), ("rejected", "Rechazado"),
                ], default="quarantined")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("renewal", models.ForeignKey(
                    to="reminders.renewal",
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="independent_attachments")),
                ("uploaded_by", models.ForeignKey(
                    to=settings.AUTH_USER_MODEL, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="vencira_independent_uploaded_attachments")),
            ],
            options={"ordering": ["-created_at", "-id"]},
        ),
        migrations.AddIndex(
            model_name="renewalattachment",
            index=models.Index(fields=["renewal", "-created_at"],
                               name="ratt_renewal_time_idx")),
        migrations.AddConstraint(
            model_name="renewalattachment",
            constraint=models.CheckConstraint(condition=models.Q(byte_size__gt=0),
                                              name="ratt_positive_bytes")),
    ]
