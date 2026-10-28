"""Catálogo por cuenta: overrides de defaults y opciones personalizadas."""
import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("reminders", "0008_renewal_entry_modality")]

    operations = [
        migrations.CreateModel(
            name="WorkspaceModality",
            fields=[
                ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
                ("code", models.CharField(max_length=64)),
                ("label", models.CharField(max_length=80)),
                ("active", models.BooleanField(default=True)),
                ("workspace", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="modality_options", to="reminders.workspace",
                )),
            ],
            options={"ordering": ["code"]},
        ),
        migrations.AddConstraint(
            model_name="workspacemodality",
            constraint=models.UniqueConstraint(
                fields=["workspace", "code"], name="uniq_workspace_modality_code"
            ),
        ),
    ]
