# VENCIRA — M1-03: alcance de host trust y Django real con rol limitado

Fecha: 31/10/2026; rama `feature/c-ficha-independent-attachments`.

## Base ya comprobada (NO repetir)

El operador confirmó el gate anterior con 11/11 pruebas PASS y `MB1_M103_AUTH_LP_GROUP_RESULT=0`. En DEV y preview: `HOST_TRUST=4`, `LOCAL_TRUST=2`, `BROAD_HOST_SCRAM=1`, `BROAD_HOST_TRUST=0`, `API_USES_DB_SUPERUSER=YES`. El rol limitado pudo hacer CRUD de una tabla sintética y no pudo alterar el esquema, crear roles, leer tabla privada ni suplantar superusuario. Evidencia `docs/MB1_M103_AUTH_PLUS_PG17_LEAST_PRIVILEGE_2026-10-31.md` (`5dcf337`). Se confirmó un riesgo de mínimo privilegio de API. **No hay prueba de exposición pública a Internet ni de que las cuatro reglas host trust estén accesibles desde la red.**

## Entrega nueva — PENDIENTE de ejecutar

`scripts/validate_mb1_m103_scope_and_django_orm_grouped.sh` (commit `e005172`) agrupa **solo comprobaciones nuevas**:

1. **12 pruebas puras** de alcance de host trust (`scripts/test_mb1_m103_host_trust_scope_readonly.py`, `7536ea6`).
2. **Auditoría real solo lectura** de PostgreSQL HBA de ambas DB (`scripts/audit_mb1_m103_host_trust_scope_readonly.py`, `2927eea`, corrección de máscaras IPv6 `5f2e3f2`). Clasifica las direcciones `host trust` como `LOOPBACK_IPV4`, `LOOPBACK_IPV6`, `NONLOOPBACK` o `UNRESOLVED`, sin imprimir direcciones, máscaras, reglas HBA, roles o credenciales. Cuenta cada regla. `LOOPBACK_ONLY_OBSERVED` significa que solo se observaron CIDR loopback; no certifica la ausencia de otras rutas de acceso, cambios futuros ni alcance efectivo de reglas anteriores.
3. **Django ORM real + PostgreSQL 17 temporal:** `backend/reminders/offline_mb1_m103_limited_orm_lab.py` (`2b36b85`) y `scripts/rehearse_mb1_m103_real_django_limited_pg17.sh` (`6502923`). El ejecutor construye una imagen de backend de laboratorio, crea una red Docker **interna** sin publicar puertos y una base `postgres:17-alpine` nueva. Aplica las migraciones **solo al PostgreSQL nuevo** con una identidad administrativa sintética, y crea un login distinto sin superusuario, creación de roles ni DDL, con CRUD y secuencias. Django conectado como login limitado crea/lee/actualiza/elimina `Workspace`, `WorkspaceModality`, `WorkspaceInsurer` y `Renewal` y comprueba denegaciones de `CREATE TABLE`, `TRUNCATE` y `SET ROLE`. El contenedor y el **volumen anónimo** del PostgreSQL de ensayo se eliminan con `docker rm -fv`; imagen y red temporal también se limpian. No se usan datos reales, la red DEV, montajes originales ni credenciales operativas.

**Alcance del grant en laboratorio:** se conceden `SELECT,INSERT,UPDATE,DELETE` de las tablas de esquema `public` y permiso de uso/lectura de secuencias para comprobar compatibilidad básica de ORM, **no para establecer la política final de acceso**. Esto todavía permite DML sobre muchas tablas de Django, incluidas potencialmente autenticación/auditoría. La solución productiva necesita una matriz revisada de grants por tabla/función, distinción de cuentas de API, migraciones y backup, tests de acceso por endpoint y compatibilidad con el O5 programado.

## Un solo comando en VPS (no ejecutado)

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/validate_mb1_m103_scope_and_django_orm_grouped.sh
bash scripts/validate_mb1_m103_scope_and_django_orm_grouped.sh
echo "MB1_M103_SCOPE_ORM_EXIT_CODE=$?"
```

Salida esperada, pero no certificada antes de la ejecución:

```text
Ran 12 tests
OK
MB1_M103_SCOPE_PURE_TESTS=OK
MB1_M103_TRUST_SCOPE_READONLY=OK
MB1_M103_LIVE_HOST_TRUST_SCOPE_READONLY=OK
MB1_M103_DJANGO_REAL_MIGRATIONS_TEMP_ONLY=OK
MB1_M103_DJANGO_REAL_LIMITED_LOGIN=OK
MB1_M103_DJANGO_ORM_CREATE_READ_UPDATE_DELETE=OK
MB1_M103_DJANGO_DENIED_DDL=OK
MB1_M103_DJANGO_DENIED_TRUNCATE=OK
MB1_M103_DJANGO_DENIED_ROLE_ESCALATION=OK
MB1_M103_DJANGO_ROLE_SEPARATION_LAB=OK
MB1_M103_DJANGO_PG17_RESULT=0
MB1_M103_SCOPE_ORM_DONE=OK
MB1_M103_SCOPE_ORM_RESULT=0
MB1_M103_SCOPE_ORM_EXIT_CODE=0
```

Si la lectura detecta `NONLOOPBACK` o `UNRESOLVED` (mayores de cero), NO corregir de inmediato. Inspeccionar en un clon el orden de coincidencia HBA, interfaces y network namespace. Se mantienen los controles de seguridad; ninguna acción de este paquete cambia `pg_hba.conf`, usuarios de DEV, contraseñas, respaldos, timers ni la DB persistente.

## Hitos que NO se cierran con esta prueba

- **M1-03**: faltan revisión de 131 P0, writers por host y otros accesos privilegiados, política de grants por ruta y comportamiento completo por HTTP.
- **M1-04**: no se puede congelar universalmente SQL + filesystem con el actual control cooperativo.
- **M1-05 y M1-06**: O5 operacional PostgreSQL-only, custodia externa pendiente y antirollback externo no integrado.
- **MB2 y MB3**: sin autorización de release.

```text
MB1_M103_LIVE_CREDENTIAL_MIGRATION=NOT_AUTHORIZED
MB1_M103_FULL_WRITER_EXCLUSION=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
