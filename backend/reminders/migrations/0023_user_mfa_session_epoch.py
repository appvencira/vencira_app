from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0022_mfa_admin_recovery_cases")]
    operations = [
        migrations.AddField(
            model_name="usermfastate",
            name="session_epoch",
            field=models.PositiveIntegerField(default=0),
        ),
    ]
