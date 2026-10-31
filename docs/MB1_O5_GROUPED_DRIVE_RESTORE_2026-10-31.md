# VENCIRA - MB1 O5 agrupado: restauracion real desde Drive a PostgreSQL temporal
Fecha: 31/10/2026. Rama: feature/c-ficha-independent-attachments.

## Objetivo y limite

El script `scripts/validate_mb1_o5_grouped_remote_restore.sh` (commit `c28aa05`, ajuste `7265e8d`) centraliza **en una sola ejecucion** la siguiente evidencia, cuya ejecucion por el operador ya ha sido confirmada (ver evidencia final):

1. Validacion sintactica de los scripts restaurador y auditor read-only.
2. Diez pruebas unitarias del contrato O5 ya aprobadas previamente, ejecutadas ahora como preflight.
3. Aserciones estaticas sobre ruta del restaurador, contenedor temporal sin red, pg_restore exclusivamente en ese contenedor, y rechazo de algunas operaciones de riesgo.
4. Salud e identidad del PostgreSQL DEV comprobadas antes de acceder a la copia; el script NO ejecuta migraciones ni consulta datos de negocio de DEV.
5. Restauracion desde el ultimo backup PostgreSQL real de Drive en PG17 aislado sin red, mediante el script candidato `scripts/o5_restore_drill.sh`. Comprueba la migracion base 0014 y las tablas esenciales (no exige que 0014 sea la ultima).
6. Identidad y salud del mismo contenedor DEV comprobadas al terminar. Sin upload, sin modificar copia remota, sin paradas ni reinicios; comparte el flock de O5 para evitar coincidencia con la copia programada.

El estado "ultimo backup" se decide por Restic segun la etiqueta `vencira-postgresql`; el laboratorio no verifica aqui la inmutabilidad, antiguedad maxima, cadena anti-rollback externa, cobertura de objetos y diario, ni custodia tras perdida del VPS. Las verificaciones de tablas son basicas; no sustituyen pruebas de negocio o aceptacion.

**No esta desplegado ningun cambio en el servicio O5.** La auditoria read-only previa identifico que el codigo O5 de Git era PG-only y que su pin estatico no coincidia con DEV; esa diferencia motivó la correccion candidata del restaurador versionado.

## Ejecucion realizada por operador — referencia reproducible

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/validate_mb1_o5_grouped_remote_restore.sh
sudo env MB1_GROUPED_O5_RESTORE=YES bash scripts/validate_mb1_o5_grouped_remote_restore.sh
echo "MB1_O5_GROUP_EXIT_CODE=$?"
```

Esperado: `MB1_O5_GROUP_BASH_SYNTAX=OK`, `MB1_O5_GROUP_SCHEMA_TESTS=OK`, `MB1_O5_GROUP_STATIC_BOUNDARY=OK`, `MB1_O5_GROUP_DEV_DB_PRECHECK=OK`, `DRIVE_SNAPSHOT_ACCESIBLE=1`, `PG17_EFIMERO_SIN_RED=OK`, `RESTAURACION_PG17_DESDE_DRIVE=OK`, `O5_RESTORED_BASELINE_SCHEMA=OK`, `POSTGRES_ORIGINAL_INTACTO=1`, `MB1_O5_GROUP_REMOTE_PG17_RESTORE=OK`, `MB1_O5_GROUP_DEV_CONTAINER_ID_AND_HEALTH_UNCHANGED=OK`, `MB1_O5_GROUP_DONE=OK`, `MB1_O5_GROUP_RESULT=0`, `MB1_O5_GROUP_EXIT_CODE=0`.

## Fallo y seguridad

Si O5 esta ejecutandose, su flock compartido deniega el ensayo; NO detener el timer ni reintentar en bucle. El restaurador emite `FASE_FALLIDA` y su log local si hay error. **No pegar secretos, archivos de configuracion, dumps ni trazas con datos de clientes**. Devolver solo marcadores y fase del fallo.

La prueba en VPS accede de forma controlada y solo lectura al backup operativo cifrado, y crea una base temporal con datos reales restaurados durante el ensayo; la base temporal no publica red y se elimina al finalizar. Es una prueba de recuperacion de PostgreSQL existente, NO un despliegue. No confirma que ningun otro actor privilegiado pueda alterar las fuentes.

## Cierre formal

En la checklist maestra M1-05 se mantiene **pendiente**, aun si la restauracion pasa. Sus bloqueos operativos son la cabeza externa anti-rollback, backup integral si se activan adjuntos, custodia y freeze global. M1-06 tambien queda abierto.

```text
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Evidencia definitiva del operador — PASS 31/10/2026

Se recibio `Ran 10 tests in 0.001s`, `OK`, `MB1_O5_GROUP_SCHEMA_TESTS=OK`, `MB1_O5_GROUP_STATIC_BOUNDARY=OK`, `MB1_O5_GROUP_DEV_DB_PRECHECK=OK`, `DRIVE_SNAPSHOT_ACCESIBLE=1`, `PG17_EFIMERO_SIN_RED=OK`, `RESTAURACION_PG17_DESDE_DRIVE=OK`, `O5_RESTORED_BASELINE_SCHEMA=OK`, `O5_RESTORE_SCHEMA_CHECK_IS_MINIMUM_ONLY=1`, `O5_MINIMUM_MIGRATION_PRESENT=0014_renewal_outcomes`, `TABLAS_PUBLIC_RESTAURADAS=25`, `RESTIC_SNAPSHOT_TAG=vencira-postgresql`, `POSTGRES_ORIGINAL_INTACTO=1`, `RESULTADO_GLOBAL=0`, `O5_RESTAURACION_REMOTA_VERIFICADA=1`, `POSTGRES_LOCALCHECK_NO_MODIFICADO=1`, `SIN_DUMP_DESCIFRADO_EN_DISCO=1`, `MB1_O5_GROUP_REMOTE_PG17_RESTORE=OK`, `MB1_O5_GROUP_DEV_CONTAINER_ID_AND_HEALTH_UNCHANGED=OK`, `MB1_O5_GROUP_DONE=OK`, `MB1_O5_GROUP_PHASE=POSTCHECK`, `MB1_O5_GROUP_RESULT=0`, `MB1_O5_GROUP_EXIT_CODE=0`. El log de diagnostico fue generado localmente en `/tmp`; no se adjunta ni expone su contenido.

**Conclusion concreta:** la copia PostgreSQL O5 existente en Drive ha sido restaurada efectivamente en un PG17 temporal sin red, con comprobacion de esquema minimo (25 tablas) y sin cambios detectados de identidad/salud del contenedor DEV. Esto **eleva la evidencia de recuperabilidad operativa de PostgreSQL**, no el cierre M1-05 o M1-06.

**Limitaciones expresas:** `MB1_O5_OPERATIONAL_ANTIROLLBACK=NOT_INTEGRATED`, `MB1_O5_OBJECT_JOURNAL_BACKUP=NOT_INTEGRATED`, `MB1_O5_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La verificacion del schema solo prueba estructura minima, no consistencia completa de registros o freshness/antiguedad real del snapshot. No esta demostrado que el respaldo contenga las ultimas transacciones del sistema ni que un segundo host pueda restaurarlo sin el VPS. El script probado es el candidato de GitHub, no una actualizacion del servicio programado.
