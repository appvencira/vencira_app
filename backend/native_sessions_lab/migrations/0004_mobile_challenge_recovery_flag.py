"""Recovery-only challenge bit; ISOLATED TEST DATABASES ONLY."""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("native_sessions_lab", "0003_mobile_account_fence"),
    ]

    operations = [
        migrations.AddField(
            model_name="mobileloginchallengelab",
            name="replace_devices",
            field=models.BooleanField(default=False),
        ),
    ]
