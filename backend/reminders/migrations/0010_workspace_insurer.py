"""Registro privado de aseguradoras; no altera datos de anotaciones existentes."""
import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("reminders", "0009_workspace_modality")]

    operations = [
        migrations.CreateModel(
            name="WorkspaceInsurer",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("name", models.CharField(max_length=140)),
                ("normalized_name", models.CharField(max_length=140)),
                ("active", models.BooleanField(default=True)),
                ("workspace", models.ForeignKey(
                    to="reminders.workspace",
                    related_name="insurer_options",
                    on_delete=django.db.models.deletion.CASCADE,
                )),
            ],
            options={"ordering": ["name", "id"]},
        ),
        migrations.AddConstraint(
            model_name="workspaceinsurer",
            constraint=models.UniqueConstraint(
                fields=["workspace", "normalized_name"],
                name="uniq_workspace_insurer_name",
            ),
        ),
        migrations.AddField(
            model_name="renewal",
            name="insurer",
            field=models.ForeignKey(
                to="reminders.workspaceinsurer",
                on_delete=django.db.models.deletion.PROTECT,
                related_name="renewals",
                null=True, blank=True,
            ),
        ),
    ]
