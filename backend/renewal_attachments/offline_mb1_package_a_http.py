"""HTTP/middleware test-only rehearsal on disposable PG17 split schema.

Never import this in a deployed application. Synthetic MFA tables are created
only in the disposable DB so real middleware can execute without MFA migrations.
"""
import os

def main():
    requirements = {"VENCIRA_ENV":"test", "VENCIRA_DB_ENGINE":"postgresql",
                    "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL":"1",
                    "VENCIRA_M103_SPLIT_DELETE_LAB":"1", "POSTGRES_DB":"mb1"}
    if any(os.environ.get(k) != v for k, v in requirements.items()):
        raise SystemExit("MB1_PACKAGE_A_HTTP_ENV_GUARD=FAIL")
    if not os.environ.get("POSTGRES_HOST", "").startswith("mb1_pa_db_"):
        raise SystemExit("MB1_PACKAGE_A_HTTP_DB_GUARD=FAIL")
    os.environ["DJANGO_SETTINGS_MODULE"]="config.settings"
    import django
    django.setup()
    from django.apps import apps
    from django.contrib.auth import get_user_model
    from django.db import connection
    from django.test import Client
    from django.urls import reverse
    from reminders.models import Renewal, Workspace, WorkspaceMember, UserMfaState, MfaAdministrativeRecoveryCase
    from renewal_attachments.models import RenewalAttachment
    from datetime import date

    # Explicit test-only synthetic support for real middleware. No MFA
    # migration state is inserted, no enrollment endpoints are activated.
    if os.environ.get('MB1_PA_SCHEMA_BOOTSTRAP') == '1':
        if os.environ.get('POSTGRES_USER') != 'mb1':
            raise SystemExit('MB1_PA_BOOTSTRAP_ADMIN_REQUIRED')
        existing=set(connection.introspection.table_names())
        with connection.schema_editor() as editor:
            for model in (UserMfaState, MfaAdministrativeRecoveryCase):
                if model._meta.db_table not in existing:
                    editor.create_model(model)
        print('MB1_PA_MFA_TABLES_SYNTHETIC_ONLY=OK')
        return
    if os.environ.get('POSTGRES_USER') != 'mb1_pa_limited':
        raise SystemExit('MB1_PA_NONADMIN_REQUIRED')
    with connection.cursor() as cur:
        cur.execute('SELECT rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname=current_user')
        assert cur.fetchone() == (False,False,False)
        cur.execute("SELECT has_schema_privilege(current_user,'public','CREATE')")
        assert cur.fetchone()[0] is False
    print('MB1_PA_HTTP_NONADMIN_ROLE=OK')
    from django.db.migrations.recorder import MigrationRecorder
    applied=MigrationRecorder(connection).applied_migrations()
    assert ("reminders","0018_draft_reasons") in applied
    assert not any(a=="reminders" and n.startswith(tuple(f"{i:04d}" for i in range(19,28))) for a,n in applied)
    assert "reminders_renewalattachment" not in connection.introspection.table_names()
    assert apps.get_app_config("reminders").models.get("renewalattachment") is None
    u=get_user_model().objects.create_user(username="pa_http_owner",password="synthetic-test-only-password-123")
    other=get_user_model().objects.create_user(username="pa_http_stranger",password="synthetic-test-only-password-456")
    w=Workspace.objects.create(name="PA HTTP TEST")
    foreign=Workspace.objects.create(name="PA OTHER")
    WorkspaceMember.objects.create(workspace=w,user=u,role="owner")
    WorkspaceMember.objects.create(workspace=foreign,user=other,role="owner")
    renewal=Renewal.objects.create(workspace=w,customer_reference="PA_SYNTHETIC",expires_on=date(2027,12,1))
    item=RenewalAttachment.objects.create(renewal=renewal,display_name="synthetic.pdf",content_type="application/pdf",byte_size=18,sha256="a"*64,state="clean")
    listing=reverse("api-renewal-attachments",kwargs=dict(workspace_id=w.pk,renewal_id=renewal.pk))
    detail=reverse("api-renewal-attachment-detail",kwargs=dict(workspace_id=w.pk,renewal_id=renewal.pk,attachment_id=item.pk))
    client=Client(enforce_csrf_checks=True,HTTP_HOST="testserver")
    assert client.get(listing).status_code in (401,403)
    client.force_login(u)
    r=client.get(listing)
    assert r.status_code==200,(r.status_code,r.content[:100])
    data=r.json()
    assert data["capabilities"]["upload"] is False and data["capabilities"]["download"] is False and data["capabilities"]["delete"] is False
    assert len(data["results"])==1
    assert "sha256" not in data["results"][0] and "storage_key" not in data["results"][0]
    assert r.headers["Cache-Control"]=="no-store"
    assert client.post(listing,data="{}",content_type="application/json").status_code==403
    assert client.get(detail).status_code==403
    assert client.delete(detail).status_code==403
    assert RenewalAttachment.objects.filter(pk=item.pk).exists()
    client.force_login(other)
    assert client.get(listing).status_code==404
    print("MB1_PA_REAL_HTTP_MIDDLEWARE_METADATA_ONLY=OK")
    print("MB1_PA_REAL_HTTP_CROSS_TENANT_DENIED=OK")
    print("MB1_PA_MFA_MIGRATIONS=NOT_APPLIED")

if __name__=="__main__":
    main()
