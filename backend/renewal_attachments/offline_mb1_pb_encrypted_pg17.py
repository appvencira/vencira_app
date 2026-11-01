"""Disposable PostgreSQL 17 + actual Fernet-on-disk object integrity gate.

No live database, secrets, migration 0027 or object store. Run only with
the isolated runner and synthetic credentials. Never authorizes release.
"""
import hashlib
import os
import tempfile
from datetime import date
from pathlib import Path

def main():
    expected = {"VENCIRA_ENV":"test", "VENCIRA_DB_ENGINE":"postgresql",
                "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL":"1",
                "VENCIRA_M103_SPLIT_DELETE_LAB":"0", "POSTGRES_DB":"mb1"}
    if any(os.environ.get(k) != v for k,v in expected.items()):
        raise SystemExit("MB1_PB_ENCRYPTED_ENV_GUARD=FAIL")
    if not os.environ.get("POSTGRES_HOST","").startswith("mb1_pb_crypto_db_"):
        raise SystemExit("MB1_PB_ENCRYPTED_HOST_GUARD=FAIL")
    os.environ["DJANGO_SETTINGS_MODULE"]="config.settings"
    import django
    django.setup()
    from cryptography.fernet import Fernet
    from django.contrib.auth import get_user_model
    from django.db import connection
    from django.db.migrations.recorder import MigrationRecorder
    from reminders.models import Renewal,Workspace,RenewalAttachment as Legacy
    from reminders.attachment_private_store import PrivateQuarantineStore
    from renewal_attachments.models import RenewalAttachment as Independent
    from renewal_attachments.transition_reconciliation import inspect_reconciliation
    from renewal_attachments.transition_object_audit import verify_encrypted_objects_readonly

    migrations = MigrationRecorder(connection).applied_migrations()
    assert ("reminders","0018_draft_reasons") in migrations
    assert ("renewal_attachments","0006_ed25519_signature_length") in migrations
    assert not any(a=="reminders" and n[:4] in {f"{i:04d}" for i in range(19,28)}
                   for a,n in migrations)
    assert Legacy._meta.db_table not in connection.introspection.table_names()
    with connection.schema_editor() as editor:
        editor.create_model(Legacy)
    print("MB1_PB_LEGACY_SCHEMA_SYNTHETIC_ONLY=OK")
    user=get_user_model().objects.create_user(username="pb_synthetic")
    ws=Workspace.objects.create(name="PB encrypted lab")
    renewal=Renewal.objects.create(workspace=ws,customer_reference="PB_SYNTHETIC",expires_on=date(2027,12,1))
    payload=b"Vencira disposable Fernet encrypted integrity test payload"
    digest=hashlib.sha256(payload).hexdigest()
    with tempfile.TemporaryDirectory(prefix="vencira-pb-crypto-") as td:
        root=Path(td)/"quarantine"
        root.mkdir(mode=0o700)
        store=PrivateQuarantineStore(root,Fernet.generate_key())
        legacy=Legacy.objects.create(renewal=renewal,uploaded_by=user,
            display_name="synthetic.bin",content_type="application/octet-stream",
            byte_size=len(payload),sha256=digest,state="quarantined")
        item=Independent.objects.create(id=legacy.id,renewal=renewal,uploaded_by=user,
            display_name=legacy.display_name,content_type=legacy.content_type,
            byte_size=legacy.byte_size,sha256=digest,
            storage_key=legacy.storage_key,state=legacy.state)
        Independent.objects.filter(pk=item.pk).update(created_at=legacy.created_at)
        store.put_quarantine(item.storage_key,payload)
        encrypted=(root/item.storage_key.hex).read_bytes()
        assert encrypted != payload and payload not in encrypted
        report=inspect_reconciliation()
        assert (report.legacy_count,report.independent_count)==(1,1)
        assert not any((report.conflicting_records,report.missing_in_independent,
                        report.missing_in_legacy,report.reused_storage_keys))
        good=verify_encrypted_objects_readonly(store=store)
        assert good.objects_acceptable and good.checked==1 and not good.release_authorized
        print("MB1_PB_REAL_FERNET_DISK_PG17_ALIGNMENT=OK")
        # A missing ciphertext must NOT be interpreted as a clean metadata record.
        object_path=root/item.storage_key.hex
        object_path.rename(root/"hidden-for-lab")
        missing=verify_encrypted_objects_readonly(store=store)
        assert not missing.objects_acceptable and missing.unreadable==1
        (root/"hidden-for-lab").rename(object_path)
        print("MB1_PB_MISSING_OBJECT_FAILCLOSED=OK")
        token=object_path.read_bytes()
        object_path.write_bytes(token[:-1]+bytes([token[-1]^1]))
        damaged=verify_encrypted_objects_readonly(store=store)
        assert not damaged.objects_acceptable and damaged.unreadable==1
        object_path.write_bytes(token)
        print("MB1_PB_TAMPERED_CIPHERTEXT_FAILCLOSED=OK")
        Independent.objects.filter(pk=item.pk).update(sha256="f"*64)
        divergent=verify_encrypted_objects_readonly(store=store)
        assert not divergent.metadata_aligned and not divergent.objects_acceptable
        Independent.objects.filter(pk=item.pk).update(sha256=digest)
        print("MB1_PB_SQL_METADATA_DIVERGENCE_FAILCLOSED=OK")
        assert Legacy.objects.filter(pk=legacy.pk).exists()
        assert Independent.objects.filter(pk=item.pk).exists()
        assert object_path.exists()
        print("MB1_PB_NO_AUTOMATIC_DELETION=OK")
    print("MB1_PB_TEMPORARY_OBJECTS_CLEANED=OK")
    print("MB1_PB_REAL_STORE=DISPOSABLE_FERNET")
    print("MB1_PB_MFA_MIGRATIONS=NOT_APPLIED")

if __name__=="__main__":
    main()
