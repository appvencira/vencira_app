#!/usr/bin/env python3
"""Create synthetic users/tenants ONLY in an isolated I4 CI database."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
if not (
    os.environ.get("VENCIRA_ENV") == "test"
    and os.environ.get("VENCIRA_DB_ENGINE") == "postgresql"
    and os.environ.get("I4_DISPOSABLE_DATABASE") == "YES"
    and os.environ.get("POSTGRES_DB") == "vencira_i4_ci"
    and os.environ.get("POSTGRES_HOST") in {"127.0.0.1", "localhost"}
    and os.environ.get("VENCIRA_NATIVE_SESSION_LAB", "0") == "0"
    and os.environ.get("VENCIRA_NATIVE_SERVICE_CANDIDATE", "0") == "0"
    and os.environ.get("VENCIRA_ATTACHMENT_SPLIT_REHEARSAL", "0") == "0"
):
    raise SystemExit("I4_SEED_DENIED: disposable local Postgres CI only")

import django
django.setup()
from django.contrib.auth import get_user_model
from reminders.models import Workspace, WorkspaceMember, Renewal

password = os.environ["I4_OWNER_PASSWORD"]
if len(password) < 20:
    raise SystemExit("I4_SEED_DENIED: synthetic password too short")
owner = get_user_model().objects.create_user(username="i4-owner", password=password)
other = get_user_model().objects.create_user(username="i4-foreign", password=password)
workspace = Workspace.objects.create(name="I4 Synthetic Workspace")
foreign = Workspace.objects.create(name="I4 Foreign Synthetic Workspace")
WorkspaceMember.objects.create(workspace=workspace, user=owner, role=WorkspaceMember.Role.OWNER)
WorkspaceMember.objects.create(workspace=foreign, user=other, role=WorkspaceMember.Role.OWNER)
Renewal.objects.create(workspace=workspace, assigned_to=owner,
                       customer_reference="I4-SYNTHETIC-ONLY",
                       full_name="Synthetic Person",
                       expires_on="2027-04-10")
import json
Path("/tmp/vencira-i4-fixture.json").write_text(json.dumps({
    "workspace": str(workspace.pk),
    "foreign": str(foreign.pk),
    "renewal": str(workspace.renewals.get().pk),
}), encoding="utf-8")
print(f"I4_WORKSPACE_ID={workspace.pk}")
print(f"I4_FOREIGN_WORKSPACE_ID={foreign.pk}")
print(f"I4_RENEWAL_ID={workspace.renewals.get().pk}")
print("I4_SEED_DISPOSABLE=OK")
