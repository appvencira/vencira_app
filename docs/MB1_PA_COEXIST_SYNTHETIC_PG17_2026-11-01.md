# VENCIRA — Paquete A: coexistencia histórica sintética + objetos (01/11/2026)

## Por qué no se aplica la migración 0027
`reminders.0027_renewal_attachment_metadata` depende de `reminders.0026_user_mfa_pending_administrative_case`, una cadena MFA bloqueada. `renewal_attachments.0001` depende de `reminders.0018` sin MFA. Por tanto, esta prueba **no demuestra la ruta de migración real**: en un PG17 desechable se aplica 0018 + split 0006, y se crea exclusivamente una tabla histórica sintética mediante `schema_editor.create_model(Legacy)`. El estado de `django_migrations` no registra 0027.

## Trabajo versionado
- `offline_mb1_pa_coexist_lab.py`: datos ficticios, tabla histórica temporal, comparación de diez campos, preservación de ID/clave y fecha, detección de registro ausente, divergencia de hash y negativa de borrar automáticamente. Se comprueba el auditor contra un almacén **simulado en memoria**, no un objeto cifrado real; valida flujo/contrato del auditor en el PG17 temporal.
- `scripts/rehearse_mb1_pa_coexist_disposable.sh`: único comando, red Docker interna, PG17 temporal, imagen temporal, cleanup en trap y variables de entorno test-only. Sin acceso al contenedor o la base persistente de DEV, sin claves reales ni migrate global.
- Mantener en PASS los 11 unitarios de metadata, los 11 de object contract y el gate HTTP/rol SQL del paquete anterior, sin reejecutarlos.

## Criterios de salida
`MB1_PA_COEXIST_LAB=OK` y `MB1_PA_COEXIST_RESULT=0` solo acreditarán el contrato con tablas sintéticas. La falta de tal salida o excepción es FAIL/BLOCKED. No implica habilitar cargas/descargas, ni migrar 0027, ni validar custodia, freeze, clamd o recuperación real.

## Aún pendiente
- Ruta migratoria histórica legítima con las dependencias MFA resueltas, ensayo completo de copia/reconciliación/rollback en clon.
- Objetos verdaderamente cifrados en almacenamiento independiente; adversarios, hash, corrupción y congelación DB+FS bajo carga.
- Derechos SQL de ejecución final y segundo host independiente.

**Estado actual: PASS confirmado por operador (01/11/2026).** `MB1_PA_COEXIST_PREFLIGHT=OK`, `MB1_PA_COEXIST_PG17_INTERNAL=OK`, `MB1_PA_COEXIST_LEGACY_SCHEMA_SYNTHETIC=OK`, `MB1_PA_COEXIST_METADATA_RECONCILED=OK`, `MB1_PA_COEXIST_SYNTHETIC_OBJECT_HASH_FAILCLOSED=OK`, `MB1_PA_COEXIST_METADATA_DIVERGENCE_DENIED=OK`, `MB1_PA_COEXIST_NO_AUTOMATIC_DELETION=OK`, `MB1_PA_COEXIST_LAB=OK`, `MB1_PA_COEXIST_PHASE=DONE`, `MB1_PA_COEXIST_RESULT=0`. Limites declarados: fake store TEST_ONLY; MFA migraciones no aplicadas; migración histórica 0027 y almacén cifrado real NOT_RUN. Dos marcadores NOT_RUN aparecen concatenados en la salida copiada, por lo que se leen como límites explícitos, sin atribuirles validación.
`MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_RELEASE_AUTHORIZED=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Progreso formal: 1/15 (6,7%).
