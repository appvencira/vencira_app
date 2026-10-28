from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("renewal_attachments", "0002_attachmentscanevidence")]
    operations = [
        migrations.AddConstraint(
            model_name="attachmentscanevidence",
            constraint=models.UniqueConstraint(
                fields=["attachment"], name="unique_attachment_scan_evidence"),
        ),
    ]
