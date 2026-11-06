from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("renewal_attachments", "0005_recoverycase"),
    ]

    operations = [
        migrations.AlterField(
            model_name="attachmentscanevidence",
            name="signature",
            field=models.CharField(max_length=128),
        ),
    ]
