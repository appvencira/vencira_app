"""Evolución no destructiva. Nunca inferir Cliente/Candidato desde referencias legacy."""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0007_renewal_assignment")]

    operations = [
        migrations.AddField(
            model_name="renewal",
            name="entry",
            field=models.CharField(
                max_length=16,
                choices=[("clients", "Clientes"), ("prospects", "Candidatos")],
                null=True,
                blank=True,
            ),
        ),
        migrations.AddField(
            model_name="renewal",
            name="modality",
            field=models.CharField(max_length=80, blank=True, default=""),
        ),
    ]
