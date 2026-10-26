"""D1.5d: estado por cuenta para limitar intentos MFA (aditivo)."""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0019_user_mfa_state")]
    operations = [
        migrations.AddField(
            model_name="usermfastate", name="failed_attempts",
            field=models.PositiveSmallIntegerField(default=0)),
        migrations.AddField(
            model_name="usermfastate", name="attempts_started_at",
            field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(
            model_name="usermfastate", name="locked_until",
            field=models.DateTimeField(null=True, blank=True)),
    ]
