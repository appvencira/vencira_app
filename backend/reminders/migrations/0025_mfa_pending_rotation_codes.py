from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("reminders", "0024_mfa_pending_rotation")]
    operations = [
        migrations.CreateModel(
            name="UserMfaPendingRotationCode",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("code_hash", models.CharField(max_length=256)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("state", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="pending_rotation_codes", to="reminders.usermfastate")),
            ],
        ),
    ]
