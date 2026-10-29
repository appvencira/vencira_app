from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0001_initial")]

    operations = [
        migrations.CreateModel(
            name="LoginAttemptBucket",
            fields=[
                ("key", models.CharField(max_length=64, primary_key=True, serialize=False)),
                ("failures", models.PositiveSmallIntegerField(default=0)),
                ("started_at", models.DateTimeField()),
                ("blocked_until", models.DateTimeField(blank=True, null=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
        ),
    ]
