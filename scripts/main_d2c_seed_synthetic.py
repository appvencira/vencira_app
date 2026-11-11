"""D2-C: fixture confined to isolated PostgreSQL tmpfs, never DEV."""
import os
from django.contrib.auth import get_user_model
from reminders.models import Workspace, WorkspaceMember

username = os.environ["D2C_SYNTHETIC_USER"]
password = os.environ["D2C_SYNTHETIC_PASSWORD"]
if not username.startswith("d2c-synthetic-") or len(password) < 24:
    raise RuntimeError("Synthetic fixture identity invalid")
User = get_user_model()
if User.objects.filter(username=username).exists():
    raise RuntimeError("Fixture already exists")
user = User.objects.create_user(username=username, password=password)
workspace = Workspace.objects.create(name="D2B Synthetic Workspace")
WorkspaceMember.objects.create(
    workspace=workspace, user=user, role=WorkspaceMember.Role.OWNER
)
if WorkspaceMember.objects.filter(user=user, workspace=workspace,
                                  role=WorkspaceMember.Role.OWNER).count() != 1:
    raise RuntimeError("Fixture membership missing")
