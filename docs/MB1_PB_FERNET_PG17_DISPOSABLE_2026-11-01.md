# VENCIRA — PB Fernet PG17 (01/11/2026)

Desarrollo en rama aislada. Código: `backend/renewal_attachments/offline_mb1_pb_encrypted_pg17.py`; runner: `scripts/rehearse_mb1_pb_crypto_pg17_disposable.sh`.

Prueba prevista: PostgreSQL 17 efímero y objeto realmente cifrado en directorio temporal, con datos y clave sintéticos; ausencia, corrupción y divergencia de metadatos deben rechazarse sin borrado automático. No se aplica la migración histórica 0027 ni la cadena MFA. No repetir tests anteriores aprobados.

**PASS del operador (01/11/2026):** `MB1_PB_LEGACY_SCHEMA_SYNTHETIC_ONLY=OK`, `MB1_PB_REAL_FERNET_DISK_PG17_ALIGNMENT=OK`, `MB1_PB_MISSING_OBJECT_FAILCLOSED=OK`, `MB1_PB_TAMPERED_CIPHERTEXT_FAILCLOSED=OK`, `MB1_PB_SQL_METADATA_DIVERGENCE_FAILCLOSED=OK`, `MB1_PB_NO_AUTOMATIC_DELETION=OK`, `MB1_PB_TEMPORARY_OBJECTS_CLEANED=OK`, `MB1_PB_REAL_STORE=DISPOSABLE_FERNET`, `MB1_PB_MFA_MIGRATIONS=NOT_APPLIED`, `MB1_PB_CRYPTO_GROUP=OK`, `MB1_PB_CRYPTO_PHASE=DONE`, `MB1_PB_CRYPTO_RESULT=0`. `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, release `NO`. El PASS es de un almacenamiento cifrado real **efímero y sintético**, no del operativo. No acredita almacenamiento real operativo, freeze universal, custodia externa ni autorización de despliegue.

`MB1_RELEASE_AUTHORIZED=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Hitos 1/15 (6,7%).
