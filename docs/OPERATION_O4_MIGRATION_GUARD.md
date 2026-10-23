# VENCIRA O4 — Arranque de API sin migraciones automáticas

Estado 23/10/2026: **CAMBIO IMPLEMENTADO EN GITHUB, PENDIENTE DE EJECUCIÓN/VALIDACIÓN EN UBUNTU**. Entorno exclusivo: `vencira_localcheck`. O1–O3 ya aceptadas funcionalmente por el usuario. **No modificar `vencira_preview`.**

## Problema resuelto por diseño

El 23/10/2026, al arrancar una imagen O3, el comando original de `compose.yaml` ejecutó automáticamente `python manage.py migrate --noinput`. Se aplicó `0014_renewal_outcomes` a las 12:29:47 UTC antes de la verificación del script de despliegue. La API y Web O3 funcionaron y O3 fue aceptada, pero ese orden podía dejar la BD cambiada antes de los controles y la copia correspondiente.

## Contrato O4

- El servicio API **ya no ejecutará migraciones** al arrancar/reiniciar. En su lugar `sh -ec "python manage.py migrate --check --noinput && exec gunicorn ..."`. `--check` comprueba migraciones pendientes y sale con error en lugar de aplicarlas; si falta alguna, la API **no arranca**. Gunicorn se ejecuta con `exec` para manejar señales correctamente. Un reinicio no puede aplicar una nueva migración inadvertidamente.
- Este cambio de Compose afecta también a cualquier proyecto Compose que reutilice esa configuración. En una BD nueva deben crearse las migraciones **por un comando explícito** antes de iniciar la API. No ejecutar un `docker compose up` de una API nueva esperando que inicialice el esquema.
- **No se crea migración O4**, no hay cambios de modelo ni de Flutter ni de API Python. O3 sigue en esquema `0014`. El objetivo es un control operacional de despliegue, no una nueva prestación de negocio.

## Script de una sola ejecución, con respaldo nuevo

`scripts/harden_api_migrations_o4.sh` valida rama, cambios versionados y código O3 idéntico al preflight aprobado `4d5270be3ebb7ab32d4bab103208ed34002f0082`; exige el nuevo Compose del commit `9fe0f15945b6361a14d1d8ca2f912bfc9baf4cb2`, configuración de API `CHECK_ONLY`, identidad `vencira_localcheck` y comando viejo efectivamente automático. Rechaza repetir O4 sobre una API ya endurecida.

Antes de reiniciar cualquier contenedor:

1. Comprueba PostgreSQL real en `0014_renewal_outcomes` (tabla, índice y dos columnas), y memoriza ID de DB y firma de migración.
2. Genera **otra copia del estado ACTUAL de O3**, no una copia antigua `pre0014`, en `/home/vencira/vencira-db-backups/post0014_o4_*.dump` con permisos 600 bajo directorio 700. Valida `pg_restore -l`, SHA-256 y restauración integral PostgreSQL 17 **sin red ni volumen**; compara contadores de workspaces, renovaciones, desenlaces O3, O2, candidatos, auditoría y migraciones. Guarda `.sha256` y `.verified`. **Dump no cifrado, solo local privado**.
3. Valida Bash `-n`, Django `check` y `makemigrations --check --dry-run`, vuelve a ejecutar suite SQLite Django del backend sin conexión a BD real, construye API y ejecuta únicamente `manage.py migrate --check --noinput` sobre la DB existente, comprobando que la firma de `0014` no cambia.
4. Conserva imágenes actuales API y Web con etiquetas de recuperación `vencira-prev-o4-...` y recibo privado `deploy_o4_*.receipt`. Recrea **solo API** con nuevo Compose, verifica health y el comando efectivo `CHECK_ONLY`. Luego recrea **solo el contenedor de proxy Web** (sin recompilar Flutter) para que Nginx renueve el upstream DNS.
5. Comprueba que el mismo contenedor PostgreSQL sigue activo, que `0014` está intacta, backup SHA sin alteraciones, los tres servicios `healthy`, rutas locales HTTP 200, endpoints anónimos O2/O3 401/403 y bundle Flutter O3 original presente. Deja un recibo de éxito.

Falla antes de recrear servicios si falta cualquiera de las verificaciones previas. Si falla después de recrear API, informa `FASE_FALLIDA`, `API_RECREADA`, `WEB_RECREADA`, conserva los respaldos y **no realiza rollback de BD automático**. Evitar repetir O4; investigar logs y estado primero.

## Futuras migraciones: procedimiento obligatorio

Cuando Django incluya `0015` o superior, **no** lanzarla al arrancar contenedores. Preparar en otra fase y para un target explícito:

1. Preflight aislado con pruebas/migración en BD temporal, versión de código y requisitos de compatibilidad.
2. Snapshot nuevo **anterior** a esa migración, SHA y restauración comprobada; preservación de imágenes y verificación de identidad del proyecto.
3. Consulta **sin mutaciones** de `python manage.py migrate --plan`, comprobando que el target esperado es el único cambio autorizado. Aprobar ventana de migración/downtime.
4. Ejecutar **explícitamente** `docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml run --rm --no-deps api python manage.py migrate --noinput` **solo dentro de un futuro script específico protegido por los gates anteriores**, nunca como instrucción aislada. Verificar tabla `django_migrations`, esquema y auditoría.
5. Solo después recrear API/Proxy y comprobar salud/HTTP/roles. No restaurar automáticamente un dump anterior si ya existen escrituras posteriores.

**O2/O3 despliegues antiguos son históricos**, especialmente `scripts/deploy_operativa_o3.sh`: no utilizarlos para desplegar próximas migraciones. Mantener el entorno de desarrollo solo con datos ficticios. MFA, copias externas cifradas, RGPD, retención legal, seguridad de adjuntos y envío real de notificaciones siguen pendientes de cierre.

## Resultado pendiente

No declarar O4 desplegada ni verificada hasta recibir la salida de `scripts/harden_api_migrations_o4.sh`, incluyendo `BACKUP_RESTAURACION_VERIFICADOS=1`, `REGRESION_API_O3=OK`, `API_RUNTIME_MIGRATE_POLICY=CHECK_ONLY`, `POSTGRES_Y_MIGRACION_0014_INALTERADOS=1`, `HEALTH_api/db/web_preview=healthy`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`.
