"""M1-03 split-schema deletion and read-only attachment API view laboratory.

Only run on a newly created PG17 Docker database with explicit test-only
legacy model omission. No MFA migrations, no DEV, no real credentials.
Direct DRF APIRequestFactory exercises attachment *views*, not full HTTP
middleware/session behaviour. Never claim release readiness from this lab.
"""
import os


def main():
    expected = {
        "VENCIRA_ENV": "test",
        "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL": "1",
        "VENCIRA_M103_SPLIT_DELETE_LAB": "1",
        "VENCIRA_DB_ENGINE": "postgresql",
        "POSTGRES_DB": "mb1",
        "POSTGRES_USER": "mb1_app_limited",
    }
    if any(os.environ.get(k) != v for k, v in expected.items()):
        raise SystemExit("MB1_M103_SPLIT_LAB_GUARD=FAIL")
    if not os.environ.get("POSTGRES_HOST", "").startswith("mb1_m103_split_db_"):
        raise SystemExit("MB1_M103_SPLIT_DB_GUARD=FAIL")
    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
    import django
    django.setup()

    from datetime import date
    from django.apps import apps
    from django.contrib.auth import get_user_model
    from django.db import connection
    from django.db.migrations.recorder import MigrationRecorder
    from django.db.models.deletion import ProtectedError
    from rest_framework.test import APIRequestFactory, force_authenticate

    from reminders.models import Renewal, Workspace, WorkspaceMember
    from reminders.attachment_api import (
        renewal_attachments, renewal_attachment_detail,
    )
    from reminders.attachment_model_router import attachment_model
    from renewal_attachments.models import RenewalAttachment as Independent

    assert attachment_model() is Independent
    assert not apps.get_app_config("reminders").models.get("renewalattachment")
    assert "RenewalAttachment" not in vars(__import__("reminders.models", fromlist=["RenewalAttachment"]))
    tables = set(connection.introspection.table_names())
    assert "reminders_renewalattachment" not in tables
    assert "renewal_attachments_renewalattachment" in tables
    applied = MigrationRecorder(connection).applied_migrations()
    assert ("reminders", "0018_draft_reasons") in applied
    assert ("renewal_attachments", "0006_ed25519_signature_length") in applied
    assert not any(
        app == "reminders" and name[:4] in {f"{n:04d}" for n in range(19, 28)}
        for app, name in applied
    )
    assert "reminders_usermfastate" not in tables
    print("MB1_M103_SPLIT_RUNTIME_ONLY_NO_HISTORICAL_MODEL=OK")
    print("MB1_M103_SPLIT_NO_MFA_MIGRATIONS=OK")

    with connection.cursor() as cur:
        cur.execute(
            "SELECT current_user, rolsuper, rolcreatedb, rolcreaterole, rolreplication "
            "FROM pg_roles WHERE rolname=current_user"
        )
        role = cur.fetchone()
        assert role and role[0] == "mb1_app_limited" and not any(role[1:])
        cur.execute("SELECT has_schema_privilege(current_user, 'public', 'CREATE')")
        assert cur.fetchone()[0] is False
    print("MB1_M103_SPLIT_DJANGO_LIMITED_ROLE=OK")

    owner = get_user_model().objects.create_user(username="mb1_split_owner")
    stranger = get_user_model().objects.create_user(username="mb1_split_other")
    ws = Workspace.objects.create(name="MB1_SPLIT_DJANGO_SYNTHETIC")
    foreign_ws = Workspace.objects.create(name="MB1_SPLIT_FOREIGN_SYNTHETIC")
    WorkspaceMember.objects.create(workspace=ws, user=owner, role="owner")
    WorkspaceMember.objects.create(workspace=foreign_ws, user=stranger, role="owner")

    empty = Renewal.objects.create(
        workspace=ws, customer_reference="MB1_SYNTHETIC_EMPTY",
        expires_on=date(2027, 12, 1)
    )
    empty_id = empty.pk
    empty.delete()
    assert not Renewal.objects.filter(pk=empty_id).exists()
    print("MB1_M103_SPLIT_RENEWAL_DELETE_EMPTY=OK")

    renewal = Renewal.objects.create(
        workspace=ws, customer_reference="MB1_SYNTHETIC_PROTECTED",
        expires_on=date(2027, 12, 2)
    )
    item = Independent.objects.create(
        renewal=renewal, display_name="synthetic.pdf",
        content_type="application/pdf", byte_size=18,
        sha256="a" * 64, state="clean",
    )
    try:
        renewal.delete()
    except ProtectedError:
        pass
    else:
        raise AssertionError("MB1_SPLIT_ATTACHMENT_PROTECTION_BYPASSED")
    assert Renewal.objects.filter(pk=renewal.pk).exists()
    assert Independent.objects.filter(pk=item.pk).exists()
    print("MB1_M103_SPLIT_ATTACHED_RENEWAL_PROTECTED=OK")

    # DRF view-level checks. Do not claim middleware/session E2E.
    factory = APIRequestFactory()
    listing = f"/api/v1/workspaces/{ws.pk}/renewals/{renewal.pk}/attachments/"
    detail = listing + str(item.pk) + "/"

    def invoke(view, method, url, user, **kwargs):
        req = getattr(factory, method)(url, data={}, format="json")
        force_authenticate(req, user=user)
        return view(req, workspace_id=ws.pk, renewal_id=renewal.pk, **kwargs)

    result = invoke(renewal_attachments, "get", listing, owner)
    assert result.status_code == 200
    assert result.data["capabilities"] == {
        "upload": False, "download": False, "delete": False,
        "reason": "SECURITY_REVIEW_PENDING",
    }
    assert len(result.data["results"]) == 1
    row = result.data["results"][0]
    assert row["id"] == str(item.pk)
    assert row["download_enabled"] is False
    assert row["delete_enabled"] is False
    assert "storage_key" not in row and "sha256" not in row
    assert result["Cache-Control"] == "no-store"
    assert invoke(renewal_attachments, "post", listing, owner).status_code == 403
    assert invoke(
        renewal_attachment_detail, "get", detail, owner, attachment_id=item.pk
    ).status_code == 403
    assert invoke(
        renewal_attachment_detail, "delete", detail, owner, attachment_id=item.pk
    ).status_code == 403
    assert invoke(renewal_attachments, "get", listing, stranger).status_code == 404
    assert Independent.objects.filter(pk=item.pk).exists()
    print("MB1_M103_SPLIT_ATTACHMENT_API_VIEW_FAILCLOSED=OK")
    print("MB1_M103_SPLIT_ATTACHMENT_HTTP_MIDDLEWARE=NOT_VERIFIED")

    item.delete()
    renewal.delete()
    assert not Renewal.objects.filter(pk=renewal.pk).exists()
    print("MB1_M103_SPLIT_RENEWAL_DELETE_AFTER_ATTACHMENT_REMOVAL=OK")
    print("MB1_M103_SPLIT_DATA_MIGRATION=NOT_IMPLEMENTED")
    print("MB1_M103_SPLIT_OPERATIONAL_RELEASE=NO")
    print("MB1_M103_SPLIT_DJANGO_DELETE_LAB=OK")


if __name__ == "__main__":
    main()
