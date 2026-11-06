"""B09C: verificación integral antes de recuperar bytes.

Exclusivamente offline y experimental. No consulta BD,
no escribe archivos, no abre endpoints ni habilita release.
"""
from .offline_backup_manifest_b09 import verify_manifest
from .offline_db_envelope_b08 import open_database_dump
from .offline_restore_reconcile import reconcile_restored_content


def verify_backup_set_and_restore(
    *,
    manifest,
    database_envelope,
    attachment_bundle,
    manifest_key,
    database_key,
    backup_key,
    attachment_key,
    snapshot_id,
    database_key_id,
    attachment_bundle_key_id,
    attachment_content_key_id,
    manifest_key_id,
    expected_database_sha256,
    expected_metadata,
    expected_ciphertext_digests,
):
    """Autenticidad del conjunto -> dump -> contenido.

    Todos los identificadores y huellas esperados deben
    proceder de un catálogo de recuperación custodiado,
    independiente de los paquetes respaldados.

    No contiene un mecanismo de captura atómica.
    """
    manifest_result = verify_manifest(
        manifest=manifest,
        database_envelope=database_envelope,
        attachment_bundle=attachment_bundle,
        expected_snapshot_id=snapshot_id,
        expected_database_key_id=database_key_id,
        expected_attachment_key_id=attachment_bundle_key_id,
        expected_manifest_key_id=manifest_key_id,
        authentication_key=manifest_key,
    )

    # Nunca descifrar el volcado ni el contenido antes
    # de comprobar la identidad del conjunto completo.
    database_bytes = open_database_dump(
        envelope=database_envelope,
        key=database_key,
        expected_key_id=database_key_id,
        expected_snapshot_id=snapshot_id,
        expected_sha256=expected_database_sha256,
    )

    content_result = reconcile_restored_content(
        bundle=attachment_bundle,
        backup_key=backup_key,
        attachment_key=attachment_key,
        backup_key_id=attachment_bundle_key_id,
        attachment_key_id=attachment_content_key_id,
        snapshot_id=snapshot_id,
        expected_metadata=expected_metadata,
        expected_ciphertext_digests=expected_ciphertext_digests,
    )

    if not (
        manifest_result["verified"]
        and content_result["verified"]
        and content_result["content_reconciled"]
        and content_result["journal_reconciled"]
    ):
        raise RuntimeError("B09_RESTORE_NOT_VERIFIED")

    return {
        "verified": True,
        "database_bytes": database_bytes,
        "objects": content_result["objects"],
        "release_authorized": False,
    }
