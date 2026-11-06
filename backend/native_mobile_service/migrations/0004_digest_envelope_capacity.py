"""G5 candidate-only schema capacity; disposable DB test migration ONLY.

This widens digest columns but DOES NOT migrate or rehash old records, nor
authorize connecting the proposed keyring to token validation.
"""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("native_mobile_service", "0003_mobileauthauditevent"),
    ]

    operations = [
        migrations.AlterField(
            model_name="mobiledevicesession", name="access_digest",
            field=models.CharField(max_length=96),
        ),
        migrations.AlterField(
            model_name="mobiledevicesession", name="refresh_digest",
            field=models.CharField(max_length=96),
        ),
        migrations.AlterField(
            model_name="mobilespentrefresh", name="digest",
            field=models.CharField(max_length=96, unique=True),
        ),
        migrations.AlterField(
            model_name="mobileauthattemptbucket", name="subject_digest",
            field=models.CharField(max_length=96),
        ),
        migrations.AlterField(
            model_name="mobileauthauditevent", name="actor_digest",
            field=models.CharField(max_length=96, blank=True),
        ),
    ]
