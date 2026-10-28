"""Notas libres por anotación, sin reestructurar clientes ni tocar valores previos."""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0011_renewal_policy_identity")]

    operations = [
        migrations.AddField(
            model_name="renewal",
            name="notes",
            field=models.TextField(blank=True, default=""),
        ),
    ]
