# Migración inicial bajo control de versiones.
import uuid
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models

class Migration(migrations.Migration):
    initial = True
    dependencies = [migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [
        migrations.CreateModel(name="Workspace", fields=[
            ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
            ("name", models.CharField(max_length=140)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
        ]),
        migrations.CreateModel(name="WorkspaceMember", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("role", models.CharField(choices=[("owner", "Propietario"), ("member", "Miembro")], default="member", max_length=16)),
            ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="vencira_memberships", to=settings.AUTH_USER_MODEL)),
            ("workspace", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="memberships", to="reminders.workspace")),
        ]),
        migrations.CreateModel(name="Renewal", fields=[
            ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
            ("customer_reference", models.CharField(max_length=160)),
            ("expires_on", models.DateField()),
            ("status", models.CharField(choices=[("pending", "Pendiente"), ("contacted", "Contactado"), ("closed", "Cerrado")], default="pending", max_length=16)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("updated_at", models.DateTimeField(auto_now=True)),
            ("workspace", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="renewals", to="reminders.workspace")),
        ], options={
            "ordering": ["expires_on", "id"],
            "indexes": [models.Index(fields=["workspace", "expires_on"], name="renewal_ws_exp_idx")],
        }),
        migrations.AddConstraint(model_name="workspacemember",
            constraint=models.UniqueConstraint(fields=("workspace", "user"), name="uniq_workspace_user")),
    ]
