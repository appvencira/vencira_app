"""Aditiva: motivos por aviso guardados en el borrador; sin envíos."""
from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [("reminders", "0017_operational_reminders")]
    operations = [
        migrations.AddField(
            model_name="renewalreminderdraft",
            name="reasons_by_day",
            field=models.JSONField(default=dict),
        ),
    ]
