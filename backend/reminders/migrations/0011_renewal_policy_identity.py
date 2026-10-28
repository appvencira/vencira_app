"""Campos de identificación propios de una póliza externa.

Migración exclusivamente aditiva y sin transformación de registros previos.
"""
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("reminders", "0010_workspace_insurer")]

    operations = [
        migrations.AddField(
            model_name="renewal", name="full_name",
            field=models.CharField(max_length=160, blank=True, default=""),
        ),
        migrations.AddField(
            model_name="renewal", name="nickname",
            field=models.CharField(max_length=80, blank=True, default=""),
        ),
        migrations.AddField(
            model_name="renewal", name="phone",
            field=models.CharField(max_length=32, blank=True, default=""),
        ),
        migrations.AddField(
            model_name="renewal", name="email",
            field=models.EmailField(blank=True, default=""),
        ),
        migrations.AddField(
            model_name="renewal", name="policy_number",
            field=models.CharField(max_length=100, blank=True, default=""),
        ),
    ]
