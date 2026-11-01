# VENCIRA — PB Fernet PG17 (01/11/2026)

Desarrollo en rama aislada. Código: `backend/renewal_attachments/offline_mb1_pb_encrypted_pg17.py`; runner: `scripts/rehearse_mb1_pb_crypto_pg17_disposable.sh`.

Prueba prevista: PostgreSQL 17 efímero y objeto realmente cifrado en directorio temporal, con datos y clave sintéticos; ausencia, corrupción y divergencia de metadatos deben rechazarse sin borrado automático. No se aplica la migración histórica 0027 ni la cadena MFA. No repetir tests anteriores aprobados.

**NO EJECUTADO por el operador.** Los resultados aún no son PASS. No acredita almacenamiento real operativo, freeze universal, custodia externa ni autorización de despliegue.

`MB1_RELEASE_AUTHORIZED=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Hitos 1/15 (6,7%).
