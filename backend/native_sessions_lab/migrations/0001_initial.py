# Generated schema for test-only N1 mobile session laboratory. NEVER live.
import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="MobileDeviceSessionLab",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("access_digest", models.CharField(max_length=64)),
                ("refresh_digest", models.CharField(max_length=64)),
                ("credential_version", models.CharField(max_length=64)),
                ("verified_mfa", models.BooleanField(default=False)),
                ("mfa_epoch", models.PositiveIntegerField(blank=True, null=True)),
                ("access_expires_at", models.DateTimeField()),
                ("refresh_expires_at", models.DateTimeField()),
                ("generation", models.PositiveIntegerField(default=0)),
                ("revoked_at", models.DateTimeField(blank=True, null=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="SpentRefreshLab",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("digest", models.CharField(max_length=64, unique=True)),
                ("session", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="spent_refreshes", to="native_sessions_lab.mobiledevicesessionlab")),
            ],
        ),
    ]
