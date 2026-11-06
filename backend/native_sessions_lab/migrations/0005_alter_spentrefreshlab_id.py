"""Align disposable N1 lab schema with current SpentRefreshLab UUID primary key.

TEST ONLY. Do not apply to any persistent or operational database.
"""
import uuid

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("native_sessions_lab", "0004_mobile_challenge_recovery_flag"),
    ]

    operations = [
        migrations.AlterField(
            model_name="spentrefreshlab",
            name="id",
            field=models.UUIDField(
                default=uuid.uuid4, editable=False,
                primary_key=True, serialize=False,
            ),
        ),
    ]
