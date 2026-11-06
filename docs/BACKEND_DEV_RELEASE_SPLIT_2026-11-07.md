# VENCIRA — Segundo corte DEV: backend y separación del esquema (07/11/2026)

## Evidencia viva y decisión

El operador ejecutó la comparación de migraciones del checkout con la API DEV activa:

```text
BACKEND_DEV_SOURCE_MIGRATION_COUNT=27
BACKEND_DEV_APPLIED_MIGRATION_COUNT=18
BACKEND_DEV_NEW_MIGRATIONS=9
BACKEND_DEV_NEW_MIGRATION=0019_user_mfa_state
BACKEND_DEV_NEW_MIGRATION=0020_mfa_attempt_limits
BACKEND_DEV_NEW_MIGRATION=0021_mfa_prepared_at
BACKEND_DEV_NEW_MIGRATION=0022_mfa_admin_recovery_cases
BACKEND_DEV_NEW_MIGRATION=0023_user_mfa_session_epoch
BACKEND_DEV_NEW_MIGRATION=0024_mfa_pending_rotation
BACKEND_DEV_NEW_MIGRATION=0025_mfa_pending_rotation_codes
BACKEND_DEV_NEW_MIGRATION=0026_user_mfa_pending_administrative_case
BACKEND_DEV_NEW_MIGRATION=0027_renewal_attachment_metadata
BACKEND_DEV_LIVE_NOT_IN_SOURCE=0
BACKEND_DEV_SCHEMA_PARITY=NO
BACKEND_DEV_MIGRATIONS_EXECUTED=NO
BACKEND_DEV_DEPLOY_EXECUTED=NO
BACKEND_SCHEMA_INVENTORY_RESULT=0
```

El código fuente demuestra que **`0027_renewal_attachment_metadata` depende de `0026_user_mfa_pending_administrative_case`**, y esta última depende de `0025_mfa_pending_rotation_codes` y así sucesivamente hasta `0019_user_mfa_state`. **No es posible aplicar 0027 desde la rama actual sin arrastrar la cadena 0019–0026.** No usar `migrate reminders 0027`, `--fake`, editar arbitrariamente `django_migrations`, ni aplicar las ocho migraciones de seguridad simplemente para activar una tarjeta de adjuntos.

## Funcionalidad disponible, límites de aceptación

- DEV actual: Flutter Web V2 desplegado y revisión del operador concluida; API, esquema y contenedores previos no modificados.
- Cliente web V2 deja `VENCIRA_WEB_ATTACHMENTS_ENABLED=false` y `VENCIRA_MFA_UI_ENABLED=false`; ambas funciones son todavía invisibles y no publicables.
- `backend/reminders/attachment_api.py` describe una API de **consulta de metadatos solamente**. Los POST de adjuntos, descarga y DELETE devuelven denegación 403. La migración 0027 solo define metadatos y estado, no autoriza custodia física, antivirus, subida ni descarga.
- `device-notice-preview` pertenece a integración nativa y tampoco se publica en la API DEV por este corte.
- Los cuatro endpoints MFA faltantes, su esquema y el emisor transaccional G14-E2 siguen bloqueados para despliegue.

## División de trabajo acordada para un siguiente release funcional

1. **Separar módulo y grafo de migraciones de adjuntos de MFA**. Preparar en rama/candidato independiente con base `0018_draft_reasons`, sin cambiar retrospectivamente las migraciones MFA ya versionadas. Evaluar una app Django distinta (`attachments`) o una separación formal del grafo en un historial nuevo bajo protocolo O4. La decisión debe contrastarse con `makemigrations --check`, grafo completo y PostgreSQL 17 clonado; no reutilizar simplemente 0027 reescribiendo su dependencia en la rama general.
2. **Definir el corte real:** inicialmente solo lectura de metadatos (sin upload/download/delete); antes de activarlo comprobar utilidad funcional, permisos workspace/usuario, acceso cruzado, consultas denegadas e inventario vacío. Un simple endpoint nuevo sin posibilidad de añadir adjuntos no aporta toda la funcionalidad esperada; no declararlo módulo terminado.
3. **Validar el candidato separado:** clon O5/restic o DB efímera representativa del esquema 0018, pruebas de migración hacia adelante, ensayos de rollback, pruebas Django/API/Flutter y puertas de seguridad. Sin alterar BD DEV hasta aprobación específica.
4. **Deploy API separado:** solo tras verificación de copia O5 fresca, compatibilidad del frontend actual, rollback de imagen y plan de recuperación de esquema si una migración realmente se aplica. Ejecutar API y DB en operaciones explícitamente diferentes; no mezclar con PR #17 ni G14-E2.
5. Para el resto de funcionalidades nuevas sin esquema, seleccionar un subconjunto concreto libre de MFA. No inferir que la rama backend completa es segura porque varias rutas sean independientes.

## Script y próximo paso

`scripts/backend_dev_release_dependency_gate.py` inspecciona el grafo de migraciones mediante AST sin importarlas, imprime dependencias requeridas por 0027 y mantiene `BACKEND_DEV_RELEASE_MIGRATION_GO=NO`. **Publicación en GitHub no equivale a validación ejecutada en VPS**. Ejecutar únicamente pruebas estáticas de ese script y revisar el resultado; después diseñar el corte independiente sin modificar la base real.

**Estado:** `BACKEND_DEV_SCHEMA_PARITY=NO`; `BACKEND_DEV_RELEASE=BLOCKED_PENDING_SPLIT`; `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
