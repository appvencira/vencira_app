# D1-N — Migraciones 0019–0027 sobre un backup O5 real (09/11/2026)

## Situación inicial

**D1-L PASS:** 25 snapshots PostgreSQL etiquetados, último de 19 horas y `restic check` PASS.

**D1-M PASS:** el operador restauró un snapshot O5 auténtico a PostgreSQL 17 efímero con `pg_restore`; verificó `reminders.0018`, confirmó que no se tocó DEV y que se eliminó el contenedor temporal. El dump de D1-M ya se destruyó: D1-N realiza otra restauración independiente y no modifica aquella prueba.

## Objetivo de D1-N

Ensayar **migraciones Django reales sobre datos históricos auténticos**, seguidas por un rollback de esquema, antes de considerar el despliegue web de DEV.

Código: `scripts/main_d1n_o5_historical_migrations_pg17.sh` (integrado directamente en `main`).

Este script:
1. Usa la **configuración real protegida de O5** y el snapshot reciente etiquetado como PostgreSQL. No ejecuta un nuevo backup.
2. Crea una red Docker interna nueva, **no conectada a la red de DEV**, y un PostgreSQL 17 con datos en `tmpfs`, sin bind mounts ni puertos publicados.
3. Restaura los datos por streaming Restic→`pg_restore`, sin archivo de dump descifrado en el host.
4. Construye una **imagen candidata Django** desde el checkout de `main` (sin desplegarla) y arranca sus comandos de gestión como procesos temporales dentro de la red interna.
5. Verifica que `manage.py check` y `makemigrations reminders --check --dry-run` pasan, comprueba `migrate reminders 0027 --plan` y **aplica `reminders.0019–0027` exclusivamente en esta copia**.
6. Verifica el estado de `django_migrations`, exige que los conteos de tres tablas base (`auth_user`, `reminders_workspace` y `reminders_renewal`) no cambien; compara solo valores numéricos sin imprimirlos.
7. Ensaya `migrate reminders 0018` sobre **esta misma copia efímera** y confirma la desaparición de las migraciones 0019–0027 y conservación de esos conteos.
8. Elimina al salir la instancia PG17, red Docker, imagen candidata y archivo temporal de credenciales de laboratorio, y coteja IDs de los tres contenedores DEV antes/después.

**Límites de alcance:** igualdad de tres conteos no equivale a verificar todos los datos ni el valor de cada campo. El rollback del esquema no sustituye la restauración de backup ante migraciones destructivas o escrituras operativas posteriores. Esta prueba sí debe revelar si las migraciones se pueden aplicar/retroceder sobre el esquema histórico de DEV sin errores, dentro de los límites de esta copia concreta.

## Ejecución desde Termius

Revisar primero el script root que se va a ejecutar. Usar el checkout oficial de `main`, nunca la ruta de despliegue persistente.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD

bash -n scripts/main_d1n_o5_historical_migrations_pg17.sh

sudo bash scripts/main_d1n_o5_historical_migrations_pg17.sh
echo "D1N_SHELL_RESULT=$?"
```

**No ejecutar dentro de un backup activo**; el programa selecciona snapshots por metadatos y lee de Restic, pero no modifica el repositorio. No editar `/etc/vencira-backup`, ni enviar claves/variables al chat. Durante la prueba el sistema puede consumir CPU/RAM, datos transferidos por red y construir una imagen Docker temporal. `tmpfs` está limitado y provocará fallo si el dump crece más de lo disponible, sin recurrir a almacenamiento persistente.

### Condiciones de cierre

```text
D1N_CONFIG_MATCH=PASS
D1N_DEV_IDENTITY=PASS
D1N_RECENT_POSTGRESQL_SNAPSHOT=PASS
D1N_LAB_NETWORK_INTERNAL=PASS
D1N_PG17_NETWORK_ISOLATED=PASS
D1N_PG17_TMPFS_READY=PASS
D1N_RESTORE_REAL_O5_PG17=PASS
D1N_HISTORICAL_0018=PASS
D1N_CANDIDATE_DJANGO_IMAGE=PASS
D1N_BASELINE_COUNTS=PASS
D1N_MODEL_MIGRATION_PARITY=PASS
D1N_MIGRATION_PLAN=PASS
D1N_MIGRATIONS_0019_0027=PASS
D1N_CORE_COUNTS_UP=PASS
D1N_ROLLBACK_TO_0018=PASS
D1N_CORE_COUNTS_DOWN=PASS
D1N_HISTORICAL_MIGRATION_GATE=PASS
D1N_DEV_CONTAINERS_UNCHANGED=OK
D1N_LAB_CONTAINER_REMOVED=YES
D1N_EPHEMERAL_NETWORK_REMOVED=YES
D1N_RESULT=0
D1N_SHELL_RESULT=0
```

Si falla, **no** ejecutar el mismo `migrate` contra DEV, ni aplicar `--fake`, ni modificar tablas reales. Conservar únicamente los marcadores que no contienen información privada para diagnosticar la incompatibilidad.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```

**Después de D1-N PASS:** aún se requiere regresión de Django + web con datos y preparación de rollback/ventana de despliegue, con autorización explícita para cualquier cambio en DEV.

## Resultado real del operador — 09/11/2026: D1-N PASS

El operador ejecutó el gate y comunicó:

```text
D1N_READ_ONLY_SOURCE_REPOSITORY=YES
D1N_BACKUP_EXECUTED=NO
D1N_LIVE_RESTORE_EXECUTED=NO
D1N_LIVE_MIGRATIONS_EXECUTED=NO
D1N_DEPLOY_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1N_CONFIG_MATCH=PASS
D1N_DEV_IDENTITY=PASS
D1N_RECENT_POSTGRESQL_SNAPSHOT=PASS
D1N_LAB_NETWORK_INTERNAL=PASS
D1N_PG17_NETWORK_ISOLATED=PASS
D1N_PG17_TMPFS_READY=PASS
D1N_RESTORE_REAL_O5_PG17=PASS
D1N_HISTORICAL_0018=PASS
D1N_BACKUP_PAYLOAD_PG_RESTORE_VERIFIED=YES
D1N_REAL_BACKUP_RESTORED=PASS
D1N_CANDIDATE_DJANGO_IMAGE=PASS
D1N_BASELINE_COUNTS=PASS
D1N_MODEL_MIGRATION_PARITY=PASS
D1N_MIGRATION_PLAN=PASS
D1N_MIGRATIONS_0019_0027=PASS
D1N_CORE_COUNTS_UP=PASS
D1N_ROLLBACK_TO_0018=PASS
D1N_CORE_COUNTS_DOWN=PASS
D1N_REAL_DATA_CONTENT_PRINTED=NO
D1N_HISTORICAL_MIGRATION_GATE=PASS
D1N_DEV_CONTAINERS_UNCHANGED=OK
D1N_LAB_CONTAINER_REMOVED=YES
D1N_LIVE_RESTORE_EXECUTED=NO
D1N_LIVE_MIGRATIONS_EXECUTED=NO
D1N_DEPLOY_EXECUTED=NO
D1N_RESULT=0
```

**Decisión:** D1-N **PASS para el ensayo histórico**. Se recuperó otro snapshot real O5 en PG17 temporal, se comprobó el modelo, se aplicaron migraciones `reminders.0019–0027` sobre esa copia, se conservaron los conteos de tres tablas base y se realizó rollback a `0018`, preservando los mismos conteos. Los contenedores DEV mantuvieron su identidad y el contenedor temporal fue eliminado. No se ejecutaron migraciones contra DEV.

**Matices de evidencia:** en el mensaje aportado no aparecen `D1N_EPHEMERAL_NETWORK_REMOVED` ni `D1N_SHELL_RESULT` (aunque sí `D1N_RESULT=0`). El script contiene lógica de limpieza de la red, pero **no afirmamos su eliminación a partir de una marca ausente**. Si el cierre operativo exige confirmación, puede realizarse inventario de redes temporales sin repetir toda la restauración. La igualdad de conteos de usuarios, workspaces y vencimientos **no prueba igualdad de cada campo ni todas las tablas**. El ensayo no sustituye regresión funcional/HTTPS, plan de recuperación operacional ni autorización de despliegue.

**Próximo bloque recomendado:** D1-O, una regresión integral sobre imagen candidata y entorno desechable, más comprobación de rutas web, CSRF, MFA fail-closed, adjuntos, permisos y continuidad. No añadir más pruebas pequeñas del mismo flujo sin un defecto observado. Posteriormente, preparar una propuesta de despliegue web DEV con rollback y solicitar autorización expresa; mantener acceso nativo y MFA real fuera del release.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```
