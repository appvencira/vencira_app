# D1-M — Restauración real O5 a PostgreSQL 17 desechable (09/11/2026)

## Prerrequisitos ya validados

El operador obtuvo D1-L:
```text
D1L_SECURE_CONFIG=PASS
D1L_O5_CONFIG_MATCH=PASS
D1L_CREDENTIAL_FILE_PERMISSIONS=PASS
D1L_POSTGRESQL_TAGGED_SNAPSHOT_COUNT=25
D1L_NEWEST_POSTGRESQL_SNAPSHOT_AGE_HOURS=19
D1L_SNAPSHOT_FRESHNESS_48H=YES
D1L_RESTIC_METADATA_CHECK=PASS
D1L_SNAPSHOT_PAYLOAD_FULL_READ=NOT_RUN
D1L_RESTORE_VERIFIED=NO
D1L_RESULT=0
```

**D1-L PASS de metadatos y actualidad**, no de restauración. El origen O5 real quedó constatado por el operador: `/usr/local/libexec/vencira/o5_backup_to_drive.sh` exporta un dump PostgreSQL en formato custom `pg_dump -Fc` a Restic `rclone:vencira_google:VENCIRA-Backups/PostgreSQL`, con etiqueta `vencira-postgresql` y archivo `vencira-postgres.dump`.

## Gate D1-M, alcance explícito

`scripts/main_d1m_o5_real_restore_pg17_isolated.sh` recupera **un snapshot autenticado y real** mediante `restic dump`, envía los bytes descifrados **directamente** a `pg_restore` en un contenedor **nuevo** `postgres:17-alpine`:
- Comprueba que el entorno protegido O5 coincide con el contrato real y sus permisos (root, `config.env`, password file, `rclone.conf`).
- Comprueba la identidad de los tres contenedores DEV sin alterarlos.
- Selecciona el snapshot más reciente con **etiqueta y nombre de archivo esperados**, con antigüedad máxima de 48 h; rechaza datos de metadatos inesperados. No revela el identificador seleccionado.
- Levanta un **contenedor no asociado a Compose**, con nombre aleatorio, red `none`, **sin publicar puertos**, sin directorios host y con datos PostgreSQL en `tmpfs` limitado. No usa volúmenes Docker persistentes. Limita memoria y procesos.
- Restablece el dump real por un **pipe**, sin escribir archivos SQL/dump descifrados en el host. Cancela ante error de descarga o `pg_restore`.
- Comprueba de forma estructural que el historial restaurado contiene `reminders.0018`. No extrae ni imprime nombres, pólizas o registros de usuarios.
- Elimina el contenedor temporal al terminar, incluso ante fallos detectados por el shell, y comprueba que la identidad de los contenedores DEV no ha cambiado.

**Esta fase NO ejecuta migraciones Django** sobre los datos reales restaurados; ese paso está reservado al ensayo posterior D1-N. Tampoco demuestra aún cobertura completa de todas las tablas de negocio ni un procedimiento operacional de recuperación automatizada. La recuperación con PostgreSQL es una evidencia mucho más fuerte que el simple `restic check`.

**Limitación de almacenamiento:** la instancia PG17 se crea en `tmpfs` con límite definido. Si el backup excede el espacio, se abortará y no se escribirá en disco persistente. No incrementar límites sin revisar los recursos reales del VPS.

## Operación en Termius (con revisión previa del script)

Los comandos se deben ejecutar desde el checkout de `main` verificado. **El script corre con privilegios root para acceder a Restic y Docker; revisar su código antes de ejecutarlo.** No compartir variables de entorno ni archivos O5. No ejecutar el script de backup programado ni detener los servicios DEV.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD

bash -n scripts/main_d1m_o5_real_restore_pg17_isolated.sh
sudo bash scripts/main_d1m_o5_real_restore_pg17_isolated.sh
echo "D1M_SHELL_RESULT=$?"
```

### Condiciones de aceptación

```text
D1M_CONFIG_MATCH=PASS
D1M_DEV_IDENTITY=PASS
D1M_RECENT_POSTGRESQL_SNAPSHOT=PASS
D1M_PG17_NETWORK_ISOLATED=PASS
D1M_PG17_TMPFS_READY=PASS
D1M_RESTORE_REAL_O5_PG17=PASS
D1M_HISTORICAL_0018=PASS
D1M_BACKUP_PAYLOAD_PG_RESTORE_VERIFIED=YES
D1M_MIGRATIONS_0019_0027_ON_REAL_DATA=NOT_RUN
D1M_DEV_CONTAINERS_UNCHANGED=OK
D1M_LAB_CONTAINER_REMOVED=YES
D1M_RESULT=0
D1M_SHELL_RESULT=0
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

Cualquier valor distinto bloquea la certificación. No ejecutar un `pg_restore` manual contra un host persistente ni reintentar a ciegas con otras credenciales.

## Próximo bloque

D1-N: migración `0019–0027` y verificación de compatibilidad/rollback en una **segunda copia desechable** derivada del mismo O5, nunca sobre la base DEV. D1-M por sí solo no autoriza desplegar.

## Restricciones vigentes

```text
D1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_DEPLOY_EXECUTED=NO
```
