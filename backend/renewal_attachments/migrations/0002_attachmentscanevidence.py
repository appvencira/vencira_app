import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("renewal_attachments", "0001_initial")]
    operations = [
        migrations.CreateModel(
            name="AttachmentScanEvidence",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4,
                                        editable=False, serialize=False)),
                ("payload", models.JSONField()),
                ("signature", models.CharField(max_length=64)),
                ("recorded_at", models.DateTimeField(auto_now_add=True)),
                ("attachment", models.ForeignKey(
                    to="renewal_attachments.renewalattachment",
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="scan_evidence")),
            ],
            options={"ordering": ["-recorded_at", "-id"]},
        ),
    ]
