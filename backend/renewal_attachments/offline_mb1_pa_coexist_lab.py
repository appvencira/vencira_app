"""M1-A coexistence: disposable PG17 only, no MFA migration chain.

The legacy table is created through the test model's schema editor,
NOT by applying reminders.0027. No real data or operational migrations.
"""
import hashlib
import os
from datetime import date

def main():
    required={"VENCIRA_ENV":"test","VENCIRA_DB_ENGINE":"postgresql",
              "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL":"1",
              "VENCIRA_M103_SPLIT_DELETE_LAB":"0","POSTGRES_DB":"mb1"}
    if any(os.getenv(k)!=v for k,v in required.items()):
        raise SystemExit("PA_COEXIST_ENV_GUARD=FAIL")
    if not os.getenv("POSTGRES_HOST","").startswith("mb1_pa_coexist_db_"):
        raise SystemExit("PA_COEXIST_HOST_GUARD=FAIL")
    os.environ["DJANGO_SETTINGS_MODULE"]="config.settings"
    import django
    django.setup()
    from django.db import connection
    from django.db.migrations.recorder import MigrationRecorder
    from django.contrib.auth import get_user_model
    from reminders.models import Renewal,Workspace,RenewalAttachment as Legacy
    from renewal_attachments.models import RenewalAttachment as Independent
    from renewal_attachments.transition_reconciliation import inspect_reconciliation
    from renewal_attachments.transition_object_audit import verify_encrypted_objects_readonly

    applied=MigrationRecorder(connection).applied_migrations()
    assert ("reminders","0018_draft_reasons") in applied
    assert ("renewal_attachments","0006_ed25519_signature_length") in applied
    assert not any(a=="reminders" and n[:4] in {f"{i:04d}" for i in range(19,28)}
                   for a,n in applied)
    assert Legacy._meta.db_table not in connection.introspection.table_names()
    with connection.schema_editor() as editor:
        editor.create_model(Legacy)
    assert Legacy._meta.db_table in connection.introspection.table_names()
    assert ("reminders","0027_renewal_attachment_metadata") not in MigrationRecorder(connection).applied_migrations()
    print("MB1_PA_COEXIST_LEGACY_SCHEMA_SYNTHETIC=OK")
    u=get_user_model().objects.create_user(username="pa_coexist_synthetic")
    ws=Workspace.objects.create(name="PA COEXIST SYNTHETIC")
    renewal=Renewal.objects.create(workspace=ws,customer_reference="PA_COEXIST",expires_on=date(2027,12,1))
    payload=b"synthetic-private-object-for-test"
    digest=hashlib.sha256(payload).hexdigest()
    legacy=Legacy.objects.create(renewal=renewal,uploaded_by=u,display_name="test.bin",
                                 content_type="application/octet-stream",byte_size=len(payload),
                                 sha256=digest,state="quarantined")
    original=inspect_reconciliation()
    assert (original.legacy_count,original.missing_in_independent)==(1,1)
    assert not original.release_authorized
    item=Independent.objects.create(id=legacy.id,renewal=renewal,uploaded_by=u,
                display_name=legacy.display_name,content_type=legacy.content_type,
                byte_size=legacy.byte_size,sha256=legacy.sha256,
                storage_key=legacy.storage_key,state=legacy.state)
    # auto_now_add generates distinct timestamps, align exactly by explicit SQL update.
    Independent.objects.filter(pk=item.pk).update(created_at=legacy.created_at)
    aligned=inspect_reconciliation()
    assert aligned.legacy_count==aligned.independent_count==1
    assert not(any((aligned.missing_in_independent,aligned.missing_in_legacy,
                    aligned.conflicting_records,aligned.reused_storage_keys)))
    assert not aligned.release_authorized
    print("MB1_PA_COEXIST_METADATA_RECONCILED=OK")
    class FakeQuarantine:
        def __init__(self,body): self.body=body
        def read_quarantine_for_scanner_only(self,key):
            assert key==legacy.storage_key
            return self.body
    clean=verify_encrypted_objects_readonly(store=FakeQuarantine(payload))
    assert clean.metadata_aligned and clean.objects_acceptable and clean.checked==1
    assert not clean.release_authorized
    bad=verify_encrypted_objects_readonly(store=FakeQuarantine(b"tampered"))
    assert not bad.objects_acceptable and bad.digest_mismatches==1
    print("MB1_PA_COEXIST_SYNTHETIC_OBJECT_HASH_FAILCLOSED=OK")
    Independent.objects.filter(pk=item.pk).update(sha256="f"*64)
    mismatch=inspect_reconciliation()
    assert mismatch.conflicting_records==1
    blocked=verify_encrypted_objects_readonly(store=FakeQuarantine(payload))
    assert not blocked.objects_acceptable and not blocked.metadata_aligned
    Independent.objects.filter(pk=item.pk).update(sha256=digest)
    print("MB1_PA_COEXIST_METADATA_DIVERGENCE_DENIED=OK")
    # End with original records intact; never delete for a passing result.
    assert Legacy.objects.count()==Independent.objects.count()==1
    print("MB1_PA_COEXIST_NO_AUTOMATIC_DELETION=OK")
    print("MB1_PA_COEXIST_FAKE_STORE=TEST_ONLY")
    print("MB1_PA_COEXIST_MFA_MIGRATIONS=NOT_APPLIED")

if __name__=="__main__":
    main()
