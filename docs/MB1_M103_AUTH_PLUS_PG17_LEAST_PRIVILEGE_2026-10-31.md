# VENCIRA — M1-03: autenticación real y ensayo de mínimo privilegio PG17

Fecha: 31/10/2026. Rama: `feature/c-ficha-independent-attachments`. **Preparado, pendiente de ejecución**.

## Contexto

El censo real M1-03 del 31/10/2026 verificó que tanto `vencira_localcheck` como `vencira_preview` tienen un solo rol habilitado para login, y ese rol es superusuario. Cada DB comparte red con tres contenedores del propio proyecto; no se detectaron miembros foráneos en la instantánea. Cada PostgreSQL reportó seis reglas HBA con `trust` (incluyendo potencialmente `local`) y una regla de host con dirección amplia. **La primera inspección no permite afirmar que exista acceso público ni que `trust` esté habilitado en el acceso de red.**

La inspección del `compose.yaml` versionado demuestra que la API y la DB reciben el mismo `POSTGRES_USER`; `postgres:17-alpine` crea como superusuario al usuario de inicialización. Hay que verificar que los contenedores activos comparten efectivamente esa identidad con el gate HBA/API. No actuar sobre producción basándose únicamente en el archivo de Compose.

## Entrega: un solo bloque de comprobación sin repeticiones

- `scripts/validate_mb1_m103_hba_identity_focused.sh` (ya preparado, `3ed78ef`): 11 tests puros y comprobación real, solo lectura, de reglas HBA `local/host`, autenticación de regla amplia y comparación sin revelar identidades entre API y DB.
- `scripts/rehearse_mb1_m103_pg17_least_privilege_disposable.sh` (commits `c7e3acc`, `e4cd275`): crea **una nueva** instancia `postgres:17-alpine` con `--network none`, sin volúmenes de VENCIRA ni puertos; prepara un rol administrativo y un login de app independiente, con datos sintéticos. Conecta **como usuario limitado auténtico por TCP loopback y contraseña de laboratorio**, no mediante `SET ROLE` dentro de sesión superusuario.
  - Acepta lectura/creación/modificación/borrado ordinarios de una tabla sintética y uso de secuencia.
  - Deniega con SQLSTATE `42501` lectura de tabla privada, `ALTER TABLE`, `CREATE TABLE`, `TRUNCATE`, `CREATE ROLE` y `SET ROLE` administrativo.
  - Vuelve a verificar que el login limitado sigue funcionando y destruye únicamente su contenedor efímero al terminar.
- `scripts/validate_mb1_m103_auth_plus_pg17_least_privilege.sh` (`05bb519`): reúne ambos gates y emite una salida global. No vuelve a ejecutar los censos M1-03 completos ya superados.

**El ensayo de privilegios es representativo, NO una ejecución completa de Django sobre el esquema real.** Tampoco ha demostrado compatibilidad de migraciones, reportes, triggers, funciones ni respaldo O5 con identidades separadas. Cualquier promoción a DEV requerirá ensayar el modelo de usuarios sobre clon, backup previo validado, soporte de migración explícita, cambio de credenciales, rollback y aprobación independiente.

## Ejecutar una vez — en el VPS, sin modificar DEV

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/validate_mb1_m103_auth_plus_pg17_least_privilege.sh
MB1_M103_AUTH_LP_GROUP=YES bash scripts/validate_mb1_m103_auth_plus_pg17_least_privilege.sh
echo "MB1_M103_AUTH_LP_EXIT_CODE=$?"
```

La comprobación HBA requiere `sudo` para leer Docker y los catálogos PG, y el ensayo de la nueva base usa `sudo docker` sin ejecutar el archivo entero como root. No se ejecuta `ALTER ROLE`, `REVOKE`, `GRANT` ni `pg_hba` sobre DB en servicio. Las sentencias con creación/grants afectan **solo** al contenedor nuevo de laboratorio.

Marcadores críticos que deben observarse, sin inferirlos antes de recibir resultados:

```text
MB1_M103_DETAIL_HBA_API_IDENTITY=OK
MB1_M103_AUTH_LP_HBA_AND_RUNTIME_IDENTITY=OK
MB1_M103_LP_RESTRICTED_ROLE_CRUD=OK
MB1_M103_LP_REJECTED_PRIVATE_AUDIT_READ=OK
MB1_M103_LP_REJECTED_DDL_ALTER=OK
MB1_M103_LP_REJECTED_DDL_CREATE=OK
MB1_M103_LP_REJECTED_TABLE_TRUNCATE=OK
MB1_M103_LP_REJECTED_ROLE_CREATE=OK
MB1_M103_LP_REJECTED_ADMIN_ROLE_IMPERSONATION=OK
MB1_M103_LP_ADMIN_ESCALATION_DENIED=OK
MB1_M103_LP_DISPOSABLE_ROLE_SEPARATION=OK
MB1_M103_LP_RESULT=0
MB1_M103_AUTH_LP_GROUP_DONE=OK
MB1_M103_AUTH_LP_RESULT=0
MB1_M103_AUTH_LP_EXIT_CODE=0
```

## Criterios para la fase siguiente

Según la salida HBA real:
- Si `HOST_TRUST` es positivo, analizar el **orden** y alcance de las reglas en un clon, pues clientes alcanzables podrían autenticarse sin contraseña. No cambiar `pg_hba.conf` en vivo sin backup y rollback.
- Si `BROAD_HOST_TRUST` es positivo, la prioridad de revisión de autenticación aumenta; ello no demuestra publicación de TCP/5432 en Internet.
- Si `API_USES_DB_SUPERUSER=YES`, preparar clon con usuario de API limitado y usuario de migración/administración separado; no basta crear el rol sin ajustar `compose` y grants.
- Si `API_USES_DB_SUPERUSER=UNKNOWN` o `NOT_MATCHED`, no inferir que está seguro: ampliar lectura dirigida de identidad o fuentes de configuración.
- Mantener un papel de backup dedicado con permisos suficientes para recuperación, comprobado en clon. El O5 programado actual podría depender del superusuario y **no se modifica** en este ensayo.

Un PASS de laboratorio permite validar una técnica de mínimo privilegio, no demostrar seguridad integral ni cerrar M1-03/M1-04. Los 131 candidatos P0, actores externos/privilegiados, custodia de segundo host y freeze universal continúan pendientes.

```text
MB1_M103_LP_REAL_DJANGO_APP_COMPATIBILITY=NOT_VERIFIED
MB1_M103_LP_DEV_ROLE_CHANGE=NOT_AUTHORIZED
MB1_M103_WRITER_EXCLUSION=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
