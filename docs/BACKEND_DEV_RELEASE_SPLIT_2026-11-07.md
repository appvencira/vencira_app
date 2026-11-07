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


## 07/11/2026 — Dependencias confirmadas; aislamiento existente localizado

El operador ejecutó `scripts/backend_dev_release_dependency_gate.py`, `BACKEND_DEPENDENCY_RESULT=0`, `BACKEND_DEV_ATTACHMENT_REQUIRES_POST_BASELINE=9`, `BACKEND_DEV_MFA_DEPENDENCY_COUNT=8`, `BACKEND_DEV_ATTACHMENT_REQUIRES_MFA_CHAIN=YES`, `BACKEND_DEV_ATTACHMENT_MIGRATION_INDEPENDENT=NO`, `BACKEND_DEV_RELEASE_MIGRATION_GO=NO`, `BACKEND_DEV_API_DEPLOY_EXECUTED=NO` y `BACKEND_DEV_LIVE_MIGRATIONS_EXECUTED=NO`. El posterior `syntax error near unexpected token ')'` es un paréntesis suelto de shell, **no evidencia de error del gate**.

**Hallazgo nuevo en la fuente, sin ejecutar Django:** la app `backend/renewal_attachments` **ya existe** y dispone de su propia migración `0001_initial.py`, dependiente de `reminders.0018_draft_reasons` y usuario swappable, sin dependencias MFA. Sus modelos incluyen metadatos, evidencia de escaneo, outbox de descarte y casos de recuperación. Sin embargo, en `backend/config/settings.py` solo se registra al establecer `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1` con `VENCIRA_ENV=test`; su registro en desarrollo/producción lanza `ImproperlyConfigured`. `backend/reminders/attachment_model_router.py` dirige al modelo de `reminders` por defecto y exige entorno test para el modelo separado. El modelo histórico `reminders.RenewalAttachment` permanece registrado salvo el flag **exclusivamente test** `VENCIRA_M103_SPLIT_DELETE_LAB`. Ambos modelos y sus tablas no están todavía reconciliados para despliegue operativo. **No habilitar una bandera de test en DEV, ni aplicar la migración aislada arbitrariamente.**

Se creó `scripts/backend_attachment_split_release_readonly.py` (commit `56ced809`) que revisa sin ejecutar Django ni consultar la BD que existe esa app separada, que su migración se apoya en 0018, que el registro/router son test-only y que persiste el doble modelo. **Gate nuevo pendiente de ejecución local.** No duplicar la app ni reescribir 0027: el siguiente esfuerzo técnico es convertir **el aislamiento ya ensayado** en un candidato operativo separado con un nuevo límite de despliegue, eliminar el conflicto de modelo en ese candidato sin tocar las migraciones históricas y demostrar `makemigrations --check`/PG17/rollback sobre clon.

**Decisión:** Backend API DEV y esquema persistentemente intactos; `ATTACHMENT_SPLIT_DEV_RELEASE_READY=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No publicar una API de solo lectura como si la función completa de adjuntos estuviera terminada.


## 07/11/2026 — Segundo gate superado y revisión de cobertura de migraciones

El operador confirmó `ATTACHMENT_SPLIT_INDEPENDENT_0018_BASE=YES`, `ATTACHMENT_SPLIT_REGISTERED_ONLY_IN_TEST=YES`, `ATTACHMENT_SPLIT_DUAL_MODEL_REGISTRATION_CONFLICT=YES`, `ATTACHMENT_SPLIT_MODEL_ROUTER_TEST_ONLY=YES`, `ATTACHMENT_SPLIT_ATTACHMENT_WRITE_AND_DOWNLOAD_BLOCKED=YES`, `ATTACHMENT_SPLIT_SOURCE_REVIEW=PASS`, `ATTACHMENT_SPLIT_DEV_RELEASE_READY=NO` y `ATTACHMENT_SPLIT_CHECK_RESULT=0`. El comando se ejecutó con éxito sin cambios en el backend ni la base viva.

La inspección del modelo `backend/renewal_attachments/models.py` evidencia, además de `RenewalAttachment`, `AttachmentScanEvidence`, `AttachmentDiscardJob` y `AttachmentRecoveryCase`. En la migración `0001_initial.py` revisada solo se crean los metadatos iniciales. Antes de plantear siquiera el candidato integrado hay que comprobar todas las migraciones reales para estos otros modelos (sin suponer que falten, pues pueden existir migraciones posteriores con nombres diferentes).

Nuevo script `scripts/backend_attachment_split_django_dryrun.sh` (commit `404b0caa`): copia fuentes backend a un directorio efímero, ejecuta `manage.py makemigrations renewal_attachments --check --dry-run` dentro de un contenedor aislado **sin red**, con SQLite, secreto efímero y banderas de ensayo `VENCIRA_ENV=test` existentes, y compara que la imagen de API real permanezca intacta. **Este gate aún está pendiente de ejecución del operador.** `ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=NO` significa que todavía se necesitan migraciones/modelado; no significa que haya fallado la infraestructura ni autoriza generarlas/aplicarlas sin revisar. `ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=YES` sería solo paridad estática, no release.

No cambiar flags test-only por fuera, no habilitar adjuntos en Flutter Web, no publicar rutas hasta resolver migración independiente y controles operativos.
