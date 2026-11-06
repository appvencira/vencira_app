"""G4 native-service schema proposal. ONLY test opt-in, never live migration."""
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
            name="MobileAccountFence",
            fields=[
                ("user", models.OneToOneField(
                    primary_key=True, serialize=False, related_name="+",
                    on_delete=django.db.models.deletion.CASCADE,
                    to=settings.AUTH_USER_MODEL,
                )),
                ("generation", models.PositiveBigIntegerField(default=0)),
            ],
        ),
        migrations.CreateModel(
            name="MobileDeviceSession",
            fields=[
                ("id", models.UUIDField(
                    primary_key=True, serialize=False, default=uuid.uuid4,
                    editable=False,
                )),
                ("access_digest", models.CharField(max_length=64)),
                ("refresh_digest", models.CharField(max_length=64)),
                ("credential_version", models.CharField(max_length=64)),
                ("auth_generation", models.PositiveBigIntegerField(default=0)),
                ("verified_mfa", models.BooleanField(default=False)),
                ("mfa_epoch", models.PositiveIntegerField(blank=True, null=True)),
                ("access_expires_at", models.DateTimeField()),
                ("refresh_expires_at", models.DateTimeField()),
                ("rotation_generation", models.PositiveBigIntegerField(default=0)),
                ("revoked_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="+", to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                "indexes": [
                    models.Index(fields=["user", "revoked_at"], name="nms_user_revoke_idx"),
                    models.Index(fields=["refresh_expires_at"], name="nms_refresh_exp_idx"),
                ],
            },
        ),
        migrations.CreateModel(
            name="MobileSpentRefresh",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("digest", models.CharField(max_length=64, unique=True)),
                ("spent_at", models.DateTimeField(auto_now_add=True)),
                ("session", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="spent_refreshes",
                    to="native_mobile_service.mobiledevicesession",
                )),
            ],
        ),
    ]
