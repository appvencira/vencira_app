# VENCIRA D13 — Recuperación desde el snapshot cifrado D12, ejecución PG17 rootless

Fecha: 11/11/2026. Rama única `main`. **Publicada; pendiente de ejecutar en VPS.**

## Qué prueba realmente

D12 demostró una copia cifrada fuera del VPS, con SHA256 de los bytes recuperados. D13 da un paso más: recupera **desde Restic remoto**, no desde Docker ni desde el archivo local, el archivo histórico de tres imágenes y sus metadatos en un directorio temporal 0700; verifica su checksum; después reutiliza el laboratorio `D4-C` con **Podman rootless**, almacén privado VFS, para importar las tres imágenes y arrancar la PostgreSQL 17 archivada sobre **tmpfs con datos sintéticos** y ejecutar `SELECT 1`. Finalmente elimina contenedor, capas privadas y el tar recuperado.

D13 NO restaura el dump O5 histórico, ni arranca las imágenes API/Web, ni resuelve el mismatch de hashes de las configuraciones Docker exportadas contra los IDs originales retenidos. No toca el volumen persistente DEV ni Docker host, no crea imágenes o contenedores de producción, no usa puertos host, no imprime hashes ni datos O5. No marca B1/B2 completamente cerrados.

Scripts:
- `scripts/main_d13_remote_image_archive_root_helper.sh`: helper privilegiado exclusivo para consultar snapshot remoto D12 por etiquetas y ruta, verificar repositorio/credenciales O5 y recuperar 3 ficheros al directorio temporal de D13.
- `scripts/main_d13_remote_image_pg17_rootless_recovery.sh`: orquestador sin root; preflight de recursos, Git y sudo; descarga remota y utiliza `scripts/main_d4c_pg17_archived_isolated_runtime.sh` ya probado para PG17.
- `scripts/main_d4c_pg17_archived_isolated_runtime.sh`: runner histórico existente; responsable de eliminar su almacén VFS y runtime efímeros. No se ha alterado.

El tamaño del tar remoto consume espacio temporal además del almacenamiento VFS; el runner exige espacio estimado **7× tamaño comprimido + 3 GiB**. Usa solamente `/home/vencira/vencira-release-archives/d13-remote.*` como carpeta nueva, sin sobreescribir el archivo preupgrade original. Si falla el laboratorio, se suprimen sus registros internos, no se imprimen secretos y se conserva el marcador de fallo para diagnóstico. Si falla la eliminación, devuelve código 9 y NO afirma limpieza.

**Ejecutar una sola vez (Termius):**

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d13_remote_image_archive_root_helper.sh
bash -n scripts/main_d13_remote_image_pg17_rootless_recovery.sh
echo "D13_SYNTAX=$?"
sudo -v
bash scripts/main_d13_remote_image_pg17_rootless_recovery.sh
echo "D13_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

**Éxito únicamente si** aparecen:
```text
D13_MAIN_CLEAN=PASS
D13_ROOTLESS_RUNTIME_PREREQUISITES=PASS
D13_CAPACITY_CHECK=PASS
D13_REMOTE_SOURCE_VERIFIED=PASS
D13_D12_SNAPSHOT_SELECTION=PASS
D13_RESTIC_REMOTE_ARCHIVE_DOWNLOADED=PASS
D13_RECOVERED_ARCHIVE_SHA256=PASS
D13_REMOTE_D12_REHYDRATION=PASS
D13_ROOTLESS_ARCHIVED_IMAGES_IMPORT=PASS
D13_PG17_REMOTE_ARCHIVE_RUNTIME=PASS
D13_REMOTE_IMAGE_ARCHIVE_PG17_RECOVERY=PASS
D13_RECOVERED_TAR_REMOVED=YES
D13_RESULT=0
D13_SHELL_RESULT=0
```

**Límites importantes:** la ejecución real de PG17 utiliza datos sintéticos, nunca un snapshot de usuarios. La compatibilidad con O5 0018 y el ascenso 0019–0027 de la candidata `main` ya se estudió por separado en D1-N; el error D4-H fue intentar migrar 0027 con una imagen histórica que solo contiene hasta 0018. Para cerrar B2 de extremo a extremo debe probarse una imagen histórica con el esquema correspondiente, sin forzar 0027 desde ella. Tampoco se sustituye una reversión operacional con escrituras reales por un ensayo aislado.

La ejecución D13 es read-only para Restic remoto, pero temporalmente crea recursos **aislados de prueba** locales mediante Podman rootless. Los servicios DEV y Caddy no deben cambiar. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
