"""Asignación de vencimientos a personas del equipo, retrocompatible.

Los registros existentes permanecen sin asignar; solo owner puede acceder a ellos
hasta que se asignen explícitamente, evitando revelar trabajo ajeno.
"""
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0006_notice_constraints"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="renewal",
            name="assigned_to",
            field=models.ForeignKey(
                to=settings.AUTH_USER_MODEL,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="vencira_assigned_renewals",
                null=True,
                blank=True,
            ),
        ),
        migrations.AddIndex(
            model_name="renewal",
            index=models.Index(
                fields=["workspace", "assigned_to", "expires_on"],
                name="renewal_ws_ass_exp",
            ),
        ),
    ]
