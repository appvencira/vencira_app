"""D1.5c: esquema aditivo MFA, desactivado por defecto; sin activación de login."""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0018_draft_reasons"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]
    operations = [
        migrations.CreateModel(
            name="UserMfaState",
            fields=[
                ("user", models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE, primary_key=True,
                    related_name="vencira_mfa", serialize=False, to=settings.AUTH_USER_MODEL)),
                ("encrypted_totp_secret", models.TextField()),
                ("enabled", models.BooleanField(default=False)),
                ("last_accepted_counter", models.BigIntegerField(default=-1)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.CreateModel(
            name="UserMfaRecoveryCode",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("code_hash", models.CharField(max_length=256)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("state", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="recovery_codes", to="reminders.usermfastate")),
            ],
        ),
    ]
