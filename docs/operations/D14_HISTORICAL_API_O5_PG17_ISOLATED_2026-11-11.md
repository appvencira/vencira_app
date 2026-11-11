# VENCIRA D14 — API histórica 0018 + O5 real restaurado en PG17 aislado

Fecha: 11/11/2026. Solo `main`. **Publicada, pendiente de validación en VPS.** Reutiliza D4-H con corrección del objetivo de esquema: **0018**, no 0027.

## Alcance y evidencia previa

- D1-N ya superó la recuperación O5 y la migración candidata de `main` 0019–0027 con rollback, todo en PG17 aislado.
- D4-H recuperó O5 sobre la imagen PG17 retenida pero falló al intentar `migrate reminders 0027` desde el antiguo binario Django; D4-H2 mostró que la imagen histórica termina en 0018. Ese fallo era de incompatibilidad de versión de código, no prueba de corrupción O5.
- D12 cifró las imágenes en repositorio externo y recuperó idénticos bytes; D13 verificó descarga desde Restic, D13-R importó el archivo equivalente a Podman rootless y arrancó PG17 con SQL sintético. No hay prueba completa de API/Web/BD restauradas simultáneamente desde la exportación.

## D14 — puerta agrupada

Archivo: `scripts/main_d14_historical_api_o5_pg17_isolated.sh`.

1. Acepta explícitamente la ruta del archivo preupgrade; comprueba SHA256, manifiesto de 3 IDs y ausencia de cambios en contenedores DEV.
2. Preflight **sin red y sin volúmenes** de la imagen histórica API: exige migración 0018 y ausencia de 0027 **antes de leer credenciales O5**. Si la imagen no cumple, aborta.
3. Exige repositorio Restic/rclone de O5 y archivos de claves root 0600, selecciona un snapshot PostgreSQL reciente y con etiqueta y ruta esperadas. Un snapshot antiguo, ambiguo o de otra familia no se admite.
4. Crea una red Docker **interna y efímera** y solo una PG17 del ID retenido en host, con PGDATA en tmpfs (sin volúmenes ni puertos host). Restaura el dump real O5 por streaming a PostgreSQL, sin archivo de datos desprotegido en disco.
5. Verifica esquema histórico 0018, tres recuentos core que no se imprimen, `django check`, paridad modelos/migraciones de ese binario y `migrate reminders 0018 --plan` **sin efectuar migraciones**. Rechaza registros 0019–0027 en el snapshot; comprueba recuentos invariantes.
6. Elimina red/contenedor/archivo temporal; compara identidades de los tres contenedores DEV antes y después. No altera `api` ni `web_preview` operativos.

La prueba usa **imágenes históricas retenidas en Docker host, identificadas por manifiesto**, NO imágenes reimportadas desde el tar cifrado. El resultado D14 acota compatibilidad de datos/histórico real. D1-N ya cubre en otro laboratorio las migraciones actuales de la candidata `main`; D14 no debe mezclarlas.

## Ejecutar una vez, no repetir D4-H

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d14_historical_api_o5_pg17_isolated.sh
echo "D14_SYNTAX=$?"
sudo -v
sudo bash scripts/main_d14_historical_api_o5_pg17_isolated.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D14_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

**PASS necesario:** `D14_HISTORICAL_API_0018_ONLY=PASS`, `D14_ARCHIVE_CHECKSUM=PASS`, `D14_CONFIG_MATCH=PASS`, `D14_DEV_IDENTITY=PASS`, `D14_HOST_IMAGE_IDENTITY=PASS`, `D14_RECENT_POSTGRESQL_SNAPSHOT=PASS`, `D14_LAB_NETWORK_INTERNAL=PASS`, `D14_PG17_TMPFS_READY=PASS`, `D14_RESTORE_REAL_O5_PG17=PASS`, `D14_HISTORICAL_0018=PASS`, `D14_MODEL_MIGRATION_PARITY=PASS`, `D14_HISTORICAL_0018_MIGRATION_PLAN=PASS`, `D14_HISTORICAL_MIGRATION_SET=PASS`, `D14_CORE_COUNTS_UNCHANGED=PASS`, `D14_HISTORICAL_API_O5_COMPATIBILITY=PASS`, `D14_DEV_CONTAINERS_UNCHANGED=OK`, `D14_RESULT=0` y `D14_SHELL_RESULT=0`.

Una respuesta interrumpida o `D14_RESULT != 0` NO se debe marcar PASS.

## Lo que D14 no autoriza

La restauración se hace en un laboratorio Docker aislado, pero ejecuta transitoriamente contenedores de prueba. No hace `docker load`, despliegue, restauración en la base operativa, migraciones de base viva, Caddy reload, DNS, pruebas del cliente Android, ni rollback con escrituras posteriores. No cierra identidad exacta de config SHA de export OCI versus ID Docker host ni acredita recuperar toda la pila desde un servidor vacío.

Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La siguiente fase prioritaria tras D14 PASS es el cierre de APK Android / HTTPS nativo y la revisión de activación pública, no la repetición de toda la regresión D5.
