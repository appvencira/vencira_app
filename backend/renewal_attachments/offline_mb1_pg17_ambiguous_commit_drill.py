"""Disposable MB1 M1-02 Django/PG17/Fernet/IntakeJournal ambiguous ACK drill.

No REST API, DEV SQL, operational storage, automatic deletion, or repair.
Invoked only inside the isolated PG17 laboratory via its dedicated runner.
"""
import hashlib
import os
from pathlib import Path
import sys
import uuid

if __name__ == "__main__":
    if (os.environ.get("VENCIRA_ENV") != "test" or
            os.environ.get("VENCIRA_ATTACHMENT_SPLIT_REHEARSAL") != "1" or
            os.environ.get("MB1_DISPOSABLE_ONLY") != "1" or
            os.environ.get("POSTGRES_DB") != "mb1" or
            not os.environ.get("POSTGRES_HOST", "").startswith("mb1_ack_db_") or
            len(sys.argv) != 2 or sys.argv[1] not in ("write", "verify")):
        raise SystemExit("MB1_M102_PG17_DISPOSABLE_GUARD=FAIL")

    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
    import django
    django.setup()

    from cryptography.fernet import Fernet
    from django.db import transaction
    from reminders.attachment_private_store import PrivateQuarantineStore
    from reminders.attachment_quarantine_intake import stage_private_attachment
    from reminders.models import Renewal, Workspace
    from renewal_attachments.models import RenewalAttachment
    from renewal_attachments.offline_intake_journal import IntakeJournal
    from renewal_attachments.offline_pending_intent_reconcile_b18l import (
        classify_pending_intent,
    )

    root_obj = Path("/lab/objects")
    root_journal = Path("/lab/journal")
    assert (root_obj.is_dir() and root_journal.is_dir() and
            root_obj.stat().st_mode & 0o077 == 0 and
            root_journal.stat().st_mode & 0o077 == 0)
    key_path = root_obj / ".mb1-synthetic-key"
    if sys.argv[1] == "write":
        key_path.write_bytes(Fernet.generate_key())
        key_path.chmod(0o600)
    key = key_path.read_bytes()
    store = PrivateQuarantineStore(root_obj, key)
    journal = IntakeJournal(str(root_journal))

    cases = (
        ("commit", b"%PDF-1.7\nMB1_PG17_COMMITTED_BUT_ACK_LOST\n%%EOF"),
        ("rollback", b"%PDF-1.7\nMB1_PG17_ROLLED_BACK\n%%EOF"),
    )

    if sys.argv[1] == "write":
        workspace = Workspace.objects.create(name="MB1_ACK_SYNTHETIC")
        renewal = Renewal.objects.create(
            workspace=workspace, customer_reference="MB1_ACK",
            full_name="Synthetic", expires_on="2027-12-01",
        )
        def persist(staged, *, mode):
            # Atomic really COMMITs before the simulated lost acknowledgement.
            if mode == "commit":
                with transaction.atomic():
                    RenewalAttachment.objects.create(
                        renewal=renewal, display_name=staged.display_name,
                        content_type=staged.content_type, byte_size=staged.byte_size,
                        sha256=staged.sha256, state="quarantined",
                        storage_key=staged.storage_key,
                    )
                raise TimeoutError("synthetic post-commit acknowledgement lost")
            # The exception is raised INSIDE atomic, so PG17 rolls back.
            with transaction.atomic():
                RenewalAttachment.objects.create(
                    renewal=renewal, display_name=staged.display_name,
                    content_type=staged.content_type, byte_size=staged.byte_size,
                    sha256=staged.sha256, state="quarantined",
                    storage_key=staged.storage_key,
                )
                raise RuntimeError("synthetic pre-commit SQL failure")

        for mode, payload in cases:
            expected_error = TimeoutError if mode == "commit" else RuntimeError
            try:
                stage_private_attachment(
                    store=store, journal=journal, filename="synthetic.pdf",
                    content_type="application/pdf", content=payload,
                    create_metadata=lambda staged, mode=mode: persist(
                        staged, mode=mode
                    ),
                )
            except expected_error:
                pass
            else:
                raise AssertionError("MB1_EXPECTED_SQL_ACK_ERROR_NOT_SEEN")
        print("MB1_M102_REAL_PG17_METADATA_PATHS_TRIGGERED=OK")
    else:
        # New Django process / new DB connection: the result must have
        # survived beyond the writer's process and transaction.
        intents = {}
        for item in root_journal.iterdir():
            if item.suffix != ".json" or len(item.stem) != 32:
                continue
            key_id = uuid.UUID(hex=item.stem)
            entry = journal.read_intent(key_id)
            assert key_id not in intents.values()
            intents[entry["sha256"]] = key_id
        assert len(intents) == 2, "MB1_INCOMPLETE_DURABLE_INTENTS"
        for mode, payload in cases:
            digest = hashlib.sha256(payload).hexdigest()
            key_id = intents[digest]
            assert store.read_quarantine_for_scanner_only(key_id) == payload
            rows = RenewalAttachment.objects.filter(storage_key=key_id)
            if mode == "commit":
                assert rows.count() == 1
                record = rows.get()
                assert record.sha256 == digest
                assert record.state == "quarantined"
                decision = classify_pending_intent(
                    journal_present=True, object_present=True,
                    metadata_present=True, object_digest_matches=True,
                )
                assert decision.classification == "PENDING_INTENT_WITH_COMPLETE_PAIR"
                print("MB1_M102_REAL_PG17_COMMIT_PERSISTS_AFTER_LOST_ACK=OK")
            else:
                assert not rows.exists()
                decision = classify_pending_intent(
                    journal_present=True, object_present=True,
                    metadata_present=False, object_digest_matches=True,
                )
                assert decision.classification == "ORPHAN_ENCRYPTED_OBJECT"
                print("MB1_M102_REAL_PG17_ROLLBACK_ABSENT=OK")
            assert decision.requires_manual_review
            assert not decision.release_authorized
            assert not decision.delete_authorized
            assert (root_obj / key_id.hex).is_file()
        print("MB1_M102_REAL_FERNET_JOURNAL_PRESERVED=OK")
        print("MB1_M102_REAL_READONLY_RECONCILIATION=OK")
        print("MB1_M102_REAL_PG17_NO_AUTODELETE=OK")
