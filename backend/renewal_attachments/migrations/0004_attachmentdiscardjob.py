import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("renewal_attachments", "0003_unique_scan_evidence")]
    operations = [
        migrations.CreateModel(
            name="AttachmentDiscardJob",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4,
                                        editable=False, serialize=False)),
                ("status", models.CharField(
                    max_length=12, default="pending",
                    choices=[("pending", "Pendiente"),
                             ("completed", "Completado")])),
                ("attempts", models.PositiveIntegerField(default=0)),
                ("last_error", models.CharField(
                    max_length=80, blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("completed_at", models.DateTimeField(
                    null=True, blank=True)),
                ("attachment", models.OneToOneField(
                    to="renewal_attachments.renewalattachment",
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="discard_job")),
            ],
        ),
    ]
