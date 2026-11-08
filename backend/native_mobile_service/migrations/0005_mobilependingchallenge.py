"""I8-B native challenge proposal migration. Disposable PG17 tests ONLY."""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("native_mobile_service", "0004_digest_envelope_capacity"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="MobilePendingChallenge",
            fields=[
                ("id", models.UUIDField(primary_key=True, editable=False, serialize=False)),
                ("secret_digest", models.CharField(max_length=64)),
                ("credential_version", models.CharField(max_length=64)),
                ("mfa_epoch", models.PositiveIntegerField()),
                ("auth_generation", models.PositiveBigIntegerField()),
                ("expires_at", models.DateTimeField()),
                ("consumed_at", models.DateTimeField(null=True, blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("user", models.ForeignKey(
                    to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.CASCADE,
                    related_name="+",
                )),
            ],
            options={
                "indexes": [
                    models.Index(fields=["user", "expires_at"], name="nms_chal_user_exp_idx"),
                ],
            },
        ),
    ]
