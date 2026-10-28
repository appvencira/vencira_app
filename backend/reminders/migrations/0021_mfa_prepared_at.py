"""D1.5e: expiry anchored to start of TOTP enrolment."""
from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [("reminders", "0020_mfa_attempt_limits")]
    operations = [
        migrations.AddField(
            model_name="usermfastate", name="prepared_at",
            field=models.DateTimeField(null=True, blank=True),
        ),
    ]
