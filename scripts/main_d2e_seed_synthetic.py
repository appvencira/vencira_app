"""D2-E: fixture confined to isolated PostgreSQL tmpfs, never DEV."""
import os
from django.contrib.auth import get_user_model
from reminders.models import Workspace, WorkspaceMember

username = os.environ["D2E_SYNTHETIC_USER"]
password = os.environ["D2E_SYNTHETIC_PASSWORD"]
if not username.startswith("d2e-synthetic-") or len(password) < 24:
    raise RuntimeError("Synthetic fixture identity invalid")
User = get_user_model()
if User.objects.filter(username=username).exists():
    raise RuntimeError("Fixture already exists")
user = User.objects.create_user(username=username, password=password)
workspace = Workspace.objects.create(name="D2E Synthetic Workspace")
WorkspaceMember.objects.create(
    workspace=workspace, user=user, role=WorkspaceMember.Role.OWNER
)
if WorkspaceMember.objects.filter(user=user, workspace=workspace,
                                  role=WorkspaceMember.Role.OWNER).count() != 1:
    raise RuntimeError("Fixture membership missing")

from datetime import date
from reminders.models import Renewal
renewal = Renewal.objects.create(
    workspace=workspace, assigned_to=user,
    customer_reference="D2E-EDIT", full_name="Persona ficticia D2E",
    entry=Renewal.Entry.CLIENTS, expires_on=date(2027, 5, 31),
    status=Renewal.Status.PENDING, notes="Before D2E",
)
assert renewal.workspace_id == workspace.pk
