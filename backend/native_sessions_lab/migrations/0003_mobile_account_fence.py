"""Isolated account revocation generation. LAB ONLY, NEVER PRODUCTION."""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("native_sessions_lab", "0002_mobileloginchallengelab"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="mobiledevicesessionlab",
            name="auth_generation",
            field=models.PositiveBigIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="mobileloginchallengelab",
            name="auth_generation",
            field=models.PositiveBigIntegerField(default=0),
        ),
        migrations.CreateModel(
            name="MobileAccountFenceLab",
            fields=[
                ("user", models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE,
                    primary_key=True, related_name="+", serialize=False,
                    to=settings.AUTH_USER_MODEL,
                )),
                ("generation", models.PositiveBigIntegerField(default=0)),
            ],
        ),
    ]
