"""M1-03 actual Django ORM CRUD under a non-superuser PostgreSQL login.

Only runs in isolated lab with disposable db name prefix and test flag.
Writes synthetic Workspace/Renewal/Modalities/Insurer rows then removes them.
"""
import os


def main():
    if any((
        os.environ.get("VENCIRA_ENV") != "test",
        os.environ.get("MB1_M103_DJANGO_LAB") != "YES",
        os.environ.get("VENCIRA_DB_ENGINE") != "postgresql",
        os.environ.get("POSTGRES_DB") != "mb1",
        not os.environ.get("POSTGRES_HOST","").startswith("mb1_m103_django_db_"),
        os.environ.get("POSTGRES_USER") != "mb1_app_limited",
    )):
        raise SystemExit("MB1_M103_DJANGO_LAB_GUARD=FAIL")
    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
    import django
    django.setup()
    from datetime import date
    from django.db import connection, transaction, DatabaseError
    from reminders.models import Workspace, WorkspaceInsurer, WorkspaceModality, Renewal

    with connection.cursor() as cursor:
        cursor.execute("SELECT current_user, rolsuper, rolcreatedb, rolcreaterole, rolreplication "
                       "FROM pg_roles WHERE rolname=current_user")
        row=cursor.fetchone()
        assert row is not None
        assert row[0]=="mb1_app_limited" and not any(row[1:]), "ADMIN_CAPABILITY_ON_APP_LOGIN"
        cursor.execute("SELECT has_schema_privilege(current_user, 'public', 'CREATE')")
        assert cursor.fetchone()[0] is False, "APP_CAN_CREATE_SCHEMA_OBJECTS"
    print("MB1_M103_DJANGO_REAL_LIMITED_LOGIN=OK")

    with transaction.atomic():
        ws=Workspace.objects.create(name="MB1_SYNTHETIC_RESTRICTED_ORM")
        modality=WorkspaceModality.objects.create(
            workspace=ws,code="mb1-orm",label="MB1",active=True,
        )
        insurer=WorkspaceInsurer.objects.create(
            workspace=ws,name="Synthetic",normalized_name="synthetic",active=True,
        )
        item=Renewal.objects.create(
            workspace=ws,customer_reference="MB1_ORM_SYNTHETIC",
            expires_on=date(2027,12,31),insurer=insurer,
        )
        item.notes="mb1-only-fixture"
        item.save(update_fields=["notes","updated_at"])
        item.refresh_from_db()
        assert item.notes == "mb1-only-fixture"
        assert Renewal.objects.filter(workspace=ws,customer_reference="MB1_ORM_SYNTHETIC").count()==1
        item.delete()
        modality.delete()
        insurer.delete()
        ws.delete()
    assert not Workspace.objects.filter(name="MB1_SYNTHETIC_RESTRICTED_ORM").exists()
    print("MB1_M103_DJANGO_ORM_CREATE_READ_UPDATE_DELETE=OK")

    # Authorization negative checks use distinct transactions so any SQL
    # privilege error cannot contaminate the preceding legitimate CRUD.
    for label, sql in (
        ("DDL","CREATE TABLE public.mb1_forbidden_table(id integer)"),
        ("TRUNCATE","TRUNCATE reminders_workspace"),
        ("ROLE_ESCALATION","SET ROLE mb1"),
    ):
        try:
            with connection.cursor() as cursor:
                cursor.execute(sql)
        except DatabaseError as exc:
            cause=exc.__cause__
            state=(getattr(cause,"sqlstate",None) or getattr(cause,"pgcode",None))
            if state!="42501":
                raise AssertionError(f"MB1_UNEXPECTED_SQLSTATE_{label}") from None
        else:
            raise AssertionError(f"MB1_UNEXPECTED_SQL_PRIVILEGE_{label}")
        print(f"MB1_M103_DJANGO_DENIED_{label}=OK")

    # Required auth/session permission paths are granted but the complete API
    # HTTP workflow and deployment role switch have not been exercised.
    with connection.cursor() as cursor:
        cursor.execute("SELECT has_table_privilege(current_user, 'django_session', 'SELECT')")
        assert cursor.fetchone()[0] is True
    print("MB1_M103_DJANGO_AUTH_SESSION_TABLE_READ=OK")
    print("MB1_M103_DJANGO_ROLE_SEPARATION_LAB=OK")


if __name__ == "__main__":
    main()
