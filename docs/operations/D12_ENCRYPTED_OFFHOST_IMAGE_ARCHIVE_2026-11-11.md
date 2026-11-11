# D12 — custodia cifrada externa del archivo de imágenes

Fecha: 11/11/2026. Rama `main`. **Publicada, no ejecutada.**

## Objetivo

Cerrar una parte concreta de B3: copiar fuera del VPS, mediante el repositorio Restic/rclone cifrado O5 ya protegido, el archivo local pre-upgrade de API, PG17 y Web; después **leer desde el repositorio remoto** el tar y los dos ficheros de control, calcular sus SHA256 en streaming y compararlos con los bytes locales. La prueba de copia no implica recuperación operativa de Docker, PostgreSQL o la configuración Caddy.

Script: `scripts/main_d12_encrypted_offhost_archive_custody.sh`. Es una acción con efecto externo: crea **un nuevo snapshot remoto** y consume almacenamiento/tráfico Google Drive. No modifica/elimina snapshots previos, ni cambia el backup periódico O5 de PostgreSQL, ni toca el archivo local, Docker, servicios DEV, Caddy o DNS. Puede competir por el bloqueo Restic con el backup automático: el backup se aborta sin falsos PASS si el repositorio está ocupado.

## Seguridad y selección

- Se ejecuta mediante `sudo` **solo después de revisar el script**. Comprueba sincronía de Git, SHA del tar original y ruta del archivo; verifica permisos 0700 de `/etc/vencira-backup`, 0600 de `config.env`, el repositorio Restic exacto, contraseña en fichero 0600 y configuración rclone protegida.
- Reutiliza `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` y cifrado Restic: **misma infraestructura externa de O5**, no repositorio ni proveedor de desastre independientes. La retención/rotación de snapshots de imagen necesita política posterior; no borrar copias sin verificar.
- Identifica inequívocamente el nuevo snapshot con una etiqueta aleatoria `d12-vencira-images-...` y una etiqueta fija `vencira-image-archive`. No imprime ID, contraseña, ruta privada, nombres internos de usuarios ni datos.
- Usa `restic dump` y `sha256sum` por tubería, sin guardar un tar descifrado; cualquier diferencia/fallo aborta. La integridad de la copia se valida sobre el snapshot externo de esa ejecución, no solo desde el caché local de Docker.

## Ejecución única, solo para B3

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d12_encrypted_offhost_archive_custody.sh
echo "D12_SYNTAX=$?"
sudo -v
sudo bash scripts/main_d12_encrypted_offhost_archive_custody.sh
echo "D12_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

No ejecutar dos veces por comodidad: cada vez crea otro snapshot remoto. Si falla la copia/validación, conservar el resultado y diagnosticar antes de repetir. Duración y tráfico dependerán del tamaño real del archivo y Google Drive.

Condiciones necesarias para acreditar una **copia cifrada externa y bytes restaurables**:

```text
D12_LOCAL_ARCHIVE_CHECKSUM=PASS
D12_REMOTE_REPOSITORY_CONFIG=PASS
D12_ENCRYPTED_OFF_HOST_SNAPSHOT_CREATED=YES
D12_UNIQUE_REMOTE_SNAPSHOT=PASS
D12_REMOTE_ARCHIVE_BYTES_EQUAL=PASS
D12_REMOTE_METADATA_BYTES_EQUAL=PASS
D12_REMOTE_PAYLOAD_VERIFIED=YES
D12_ENCRYPTED_OFF_HOST_ARCHIVE_CUSTODY=PASS
D12_RESULT=0
D12_SHELL_RESULT=0
```

**Límites:** aun con PASS, `D12_REMOTE_RESTORE_TO_NEW_RUNTIME_VERIFIED=NO`, `D12_ARCHIVE_CONFIG_ID_EQUIVALENCE_VERIFIED=NO`, `D12_OPERATIONAL_ROLLBACK_VERIFIED=NO`. Debe probarse recuperación ejecutable en un runtime limpio, además de política RPO/RTO y gestión de escrituras tras snapshot. No significa que Caddy, Android o producción estén autorizados.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Resultado del operador — D12 PASS (11/11/2026)

El operador informó: `D12_MAIN_CLEAN=PASS`, `D12_LOCAL_ARCHIVE_CHECKSUM=PASS`, `D12_REMOTE_REPOSITORY_CONFIG=PASS`, `D12_ENCRYPTED_OFF_HOST_SNAPSHOT_CREATED=YES`, `D12_UNIQUE_REMOTE_SNAPSHOT=PASS`, `D12_REMOTE_ARCHIVE_BYTES_EQUAL=PASS`, `D12_REMOTE_METADATA_BYTES_EQUAL=PASS`, `D12_REMOTE_PAYLOAD_VERIFIED=YES`, `D12_ENCRYPTED_OFF_HOST_ARCHIVE_CUSTODY=PASS`, `D12_RESULT=0`. Los indicadores `...SNAPSHOT_CREATED=NO` y `...PAYLOAD_VERIFIED=NO` del inicio de la salida son marcadores de estado previo, sustituidos por las verificaciones posteriores. No consta eco separado `D12_SHELL_RESULT`.

**Cierre parcial de B3:** copias cifradas fuera del VPS en el repositorio Restic O5 y verificación de lectura integral del tar y sus dos metadatos. No demostrar independencia de proveedor/credenciales respecto a O5, recuperación desde una instalación nueva, equivalencia exacta de IDs Docker ni restauración/rollback operacional. No repetir D12: crearía un segundo snapshot remoto. Registrar política de conservación en el procedimiento de recuperación.

Invariantes: `D12_DEPLOY_EXECUTED=NO`, `D12_LIVE_MIGRATIONS_EXECUTED=NO`, `D12_LIVE_RESTORE_EXECUTED=NO`, `D12_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO`, `D12_CONTAINER_RUN_EXECUTED=NO`, `D12_CADDY_RELOAD_EXECUTED=NO`, `D12_DNS_CHANGED=NO`, `D12_PUBLIC_RELEASE_AUTHORIZED=NO`. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
