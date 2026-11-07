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


## 07/11/2026 — Primer ensayo Django detenido por dependencia de imagen anterior

El usuario ejecutó `scripts/backend_attachment_split_django_dryrun.sh`, que devolvió `ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=NO` pero el stack trace muestra un **error de inicio antes del autodetector**: `ModuleNotFoundError: No module named 'cryptography'`, importado por `config.urls → reminders.mfa_challenge → reminders.mfa_store → reminders.mfa_secrets`. La imagen usada era la **API DEV histórica**, aunque el volumen montaba fuentes actuales. Por ello el `NO` **no prueba deriva del esquema**. `ATTACHMENT_DRYRUN_LIVE_IMAGE_CHANGED=NO`, ningún servicio/DB afectado.

Se corrigió `scripts/backend_attachment_split_django_dryrun.sh` (commit `26d3b1bd`) para construir una **imagen Docker descartable del backend fuente usando `backend/Dockerfile` y `backend/requirements.txt`**, donde sí figura `cryptography>=44,<47`. La API DEV activa sigue intacta. El nuevo gate distingue `PARITY=YES` (sin diferencias), `PARITY=NO` (migraciones necesarias detectadas) de `PARITY=NOT_VERIFIED` (fallo de arranque/entorno, con exit distinto de cero). La compilación temporal puede precisar acceder a registries/PyPI; la **ejecución del ensayo corregido aún está pendiente**. Sigue sin implicar instalación de MFA, migración viva ni deploy.

Mantener bloqueo del segundo release y no calificar la paridad de migraciones hasta que Django arranque en contenedor independiente.


## 07/11/2026 — Paridad de migraciones PASS; nuevo ensayo PG17 aislado

El operador volvió a ejecutar `scripts/backend_attachment_split_django_dryrun.sh` con imagen construida desde requisitos candidatos y obtuvo `ATTACHMENT_DRYRUN_IMAGE_BUILD=OK`, `ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=YES`, `No changes detected in app 'renewal_attachments'`, `ATTACHMENT_DRYRUN_LIVE_IMAGE_CHANGED=NO`, `ATTACHMENT_DRYRUN_API_DEPLOY_EXECUTED=NO` y `ATTACHMENT_DRYRUN_LIVE_MIGRATIONS_EXECUTED=NO`. **La autodetección de Django no encuentra deriva entre modelos y migraciones existentes para la app independiente.** Esto resuelve la duda anterior sobre migraciones auxiliares: el esquema completo de esa app está cubierto por su historial de migraciones actualmente presente. No presupone que sea desplegable en producción.

Se publicó `scripts/backend_attachment_split_pg17_isolated.sh` (commit `e6fd4e2e`), que crea un PostgreSQL 17 efímero en red Docker `--internal`, directorio de datos tmpfs y sin puertos, ejecuta con `VENCIRA_ENV=test` y flags de laboratorio la migración de `renewal_attachments`, comprueba que `reminders` queda exactamente en `0018_draft_reasons` sin tablas/filas MFA, que se crea la tabla independiente, y deshace las migraciones de adjuntos solo en ese PostgreSQL desechable. Compara IDs e imágenes reales de API, DB y web antes y después y elimina los contenedores/red temporales al terminar. **No hay clon de datos reales, no hay despliegue ni migraciones en DEV**. Ensayo local **PENDIENTE**.

Mantener prohibido usar flags `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL` o `VENCIRA_M103_SPLIT_DELETE_LAB` fuera de `VENCIRA_ENV=test`. Después de PG17 PASS, el trabajo real será diseñar y construir el candidato operativo, con independencia de MFA, comprobando que no se traslada la app de laboratorio sin su aislamiento.


## 07/11/2026 — PG17 aislado PASS; candidata API recortada construible

El operador ejecutó `scripts/backend_attachment_split_pg17_isolated.sh`: `ATTACHMENT_PG17_IMAGE_BUILD=OK`, `ATTACHMENT_PG17_READY=YES`, `ATTACHMENT_PG17_INDEPENDENT_MIGRATE=OK`, `ATTACHMENT_PG17_BASELINE_0018=OK`, `ATTACHMENT_PG17_MFA_MIGRATIONS_APPLIED=0`, `ATTACHMENT_PG17_INDEPENDENT_ATTACHMENT_TABLE=OK`, `ATTACHMENT_PG17_ROLLBACK_SCHEMA=OK`, `ATTACHMENT_PG17_LIVE_CONTAINERS_UNCHANGED=OK`, `ATTACHMENT_PG17_REHEARSAL=PASS`, `ATTACHMENT_PG17_OPERATIONAL_RELEASE=NO`, `ATTACHMENT_PG17_LIVE_DB_MIGRATED=NO`. Esto demuestra migración y reversión **en BD vacía efímera**, no sobre copia representativa de datos reales y no autoriza el despliegue.

Para avanzar a código backend real sin arrastrar G14/MFA se publicó `scripts/backend_attachment_api_candidate_build.sh` (commit `e8f7d531`). A diferencia de empaquetar la rama Android, este script:

- Parte del checkout histórico `/home/vencira/vencira-localcheck` cuya API vive en DEV y exige el ID exacto de su imagen, su estado y limpieza tracked.
- Verifica que el archivo `reminders.0018_draft_reasons` sea byte a byte idéntico entre histórico y candidato; aborta ante divergencia.
- Extrae fuentes tracked del checkout histórico con `git archive`, incorpora únicamente `backend/renewal_attachments`, `reminders/attachment_api.py` y `reminders/attachment_gate.py` de la rama actual. En el **directorio temporal de compilación** registra la app independiente, fija un router al modelo independiente y añade únicamente dos rutas GET de metadatos, manteniendo 403 a POST/DELETE y sin habilitar subida/descarga. No modifica los dos repositorios de trabajo.
- Exige que las migraciones `reminders` del candidato terminen en 0018 sin introducir 0019–0027; construye una imagen candidata etiquetada y ejecuta `manage.py check` con SQLite y variables de test en contenedor sin red.
- Verifica que los IDs e imágenes de API, DB y Web activos sean idénticos antes y después. No aplica migraciones y mantiene bandera explícita `ATT_API_CANDIDATE_RELEASE_AUTHORIZED=NO`.

**Estado: script publicado, validación local y BUILD aún pendientes.** Un `BUILD=PASS` demostraría una candidata de API recortada, NO que su contrato o migración sea apto para despliegue. Tras ello hay que repetir PG17 para **esa imagen recortada exacta**, comprobar API HTTP y permisos con sesiones DEMO en aislamiento, verificar `migrate --check` y rollback de imagen/BD real con O5 fresco. El frontend actual tiene adjuntos **ocultos por defecto**, por lo que incluso publicar metadatos no equivale a habilitar la funcionalidad completa. No tocar el contenedor API DEV hasta cierre de esos gates y autorización explícita.

## 07/11/2026 — Candidata bloqueada por checkout base avanzado (sin build)

Salida del operador: `ATT_API_CANDIDATE_BASE_SHA=64e936b9cb6511f288ce53bc70de2353717a1ccb`, `ATT_API_CANDIDATE_SOURCE_SHA=468507ed7da7783be2d8e6a8584b80c48a90ae9c`, `ATT_API_CANDIDATE_BASE_0018=IDENTICAL`. La aserción sobre migraciones falló porque el backend archivado desde el `HEAD` de `/home/vencira/vencira-localcheck` incluye `0025`, `0026` y `0027` (no termina en 0018). Revisión remota de ese SHA confirma además referencias a MFA en `config/urls.py` y rutas MFA/adjuntos en `reminders/urls.py`. **La coincidencia del único archivo 0018 no acredita que el código base sea la API histórica desplegada.** El fallo precedió a la construcción Docker, sin evidencia de cambios en DEV.

Corrección `b1d493b0`: `scripts/backend_attachment_api_candidate_build.sh` comprueba por anticipado el conjunto de migraciones y ausencia de rutas MFA/adjuntos del ref base. Ante un checkout demasiado avanzado emite `ATT_API_CANDIDATE_BUILD=BLOCKED_BASELINE_MISMATCH` en vez de una aserción Python tardía. Permite indicar `ATT_API_BASE_REF` como commit histórico explícito; por defecto sigue HEAD y **no debe ejecutarse como release**. La comprobación de candidato corregido todavía NO se ha ejecutado localmente. Se requiere identificar y verificar una revisión anterior a la introducción de 0019, sin recortar migraciones ni eliminar dependencias a ciegas. El plan de integrar cambios con `main` debe tener un gate distinto, pues `main...feature/m3-android-local-notifications` sigue divergiendo y no equivale a desplegar al VPS.

Estado: candidato NO construido, API/DB DEV sin modificación acreditada por esta ejecución, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
