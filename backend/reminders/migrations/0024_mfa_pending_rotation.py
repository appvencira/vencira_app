from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0023_user_mfa_session_epoch")]
    operations = [
        migrations.AddField(
            model_name="usermfastate", name="pending_rotation_secret",
            field=models.TextField(blank=True, default=""),
        ),
        migrations.AddField(
            model_name="usermfastate", name="pending_rotation_expires_at",
            field=models.DateTimeField(null=True, blank=True),
        ),
    ]
