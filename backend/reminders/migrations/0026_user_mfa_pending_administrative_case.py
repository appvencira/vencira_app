from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0025_mfa_pending_rotation_codes"),
    ]

    operations = [
        migrations.AddField(
            model_name="usermfastate",
            name="pending_administrative_case_id",
            field=models.UUIDField(blank=True, null=True),
        ),
    ]
