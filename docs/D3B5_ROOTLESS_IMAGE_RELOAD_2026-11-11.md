# D3-B5 — Importación independiente de imágenes archivadas (11/11/2026)

**Preparado en `main`, NO EJECUTADO en VPS. Sin despliegue.**

## Decisión de diseño

Tras D3-B2 (archivo `docker save` con checksum PASS), D3-B3 (rechazo de IDs originales) y D3-B4 (las tres imágenes del archivo coinciden con las operativas en plataforma, capas y campos inspeccionados; diagnóstico PASS), falta comprobar que otra herramienta de contenedores pueda **leer y recuperar** las tres imágenes sin alterar el daemon Docker que mantiene DEV.

Se utiliza **Podman rootless** como motor de importación separado y un almacenamiento privado **VFS** de un solo uso. No se utiliza `docker load`, ni `sudo podman`, ni Docker-in-Docker privilegiado. La documentación de Podman confirma soporte para `podman load --input` de archivos Docker comprimidos y para un almacenamiento VFS seleccionado por parámetros.

Archivo publicado: `scripts/main_d3b5_rootless_podman_reload_isolated.sh` (commit `d92739f9`).

## Garantías del script

- Exige usuario **no root**, checkout limpio y HEAD exactamente igual a `origin/main`, sin exigir nombre de rama.
- Comprueba SHA256 del archivo original, propietario y directorio privado, espacio libre conservador para un almacén de capas VFS (6 veces el archivo comprimido más 3 GiB de margen).
- Si `podman` no está instalado, emite `D3B5_PREREQUISITE_MISSING=podman` y `D3B5_RESULT=4`; **no instala paquetes ni utiliza Docker como sustituto**.
- Desactiva variables de socket remoto `CONTAINER_HOST`, `DOCKER_HOST`, `PODMAN_HOST`; invoca exclusivamente `podman --remote=false --root <lab>/graph --runroot <lab>/run --storage-driver vfs`. Comprueba mediante `podman info` que el `graphRoot` coincide con el directorio recién creado.
- Importa el `images.tar.gz` original, enumera el almacén privado y exige **tres IDs únicos**. No imprime nombres de imagen, IDs, metadatos, secretos o logs internos.
- El `trap` elimina únicamente su directorio temporal `d3b5-rootless.*`; no se toca el archivo original, ningún contenedor DEV, Caddy, secretos O5 ni el volumen PostgreSQL.
- **No ejecuta las imágenes**: no prueba ni la compatibilidad HTTP/Django, ni la restauración de O5 real ni el rollback operacional. Tampoco demuestra igualdad exacta entre los IDs Docker originales y los IDs importados. Este gate es exclusivamente `ARCHIVED_IMAGES_RELOAD_IN_INDEPENDENT_STORE`.

Rootless Podman es un almacén de imágenes independiente **en el mismo VPS**, no una VM completamente separada. Por tanto, no constituye un test de recuperación ante pérdida de la máquina ni una prueba de ejecución aislada de software no fiable.

## Ejecución en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main

bash -n scripts/main_d3b5_rootless_podman_reload_isolated.sh
bash scripts/main_d3b5_rootless_podman_reload_isolated.sh \
  /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D3B5_SHELL_RESULT=$?"
```

No ejecutar como root ni exportar imágenes/capas al chat. La importación puede consumir espacio y CPU; el script corta preventivamente si el espacio libre calculado es insuficiente. Si no existe Podman rootless, el resultado será un **bloqueo de infraestructura**, no un fracaso del archivo ni una orden de instalarlo sin revisión.

## Marcadores esperados, no verificados

```text
D3B5_MAIN_SYNC=PASS
D3B5_ARCHIVE_CHECKSUM=PASS
D3B5_STORAGE_CAPACITY=PASS
D3B5_ROOTLESS_PRIVATE_STORE=PASS
D3B5_ROOTLESS_IMAGE_IMPORT=PASS
D3B5_IMPORTED_IMAGE_COUNT_3=PASS
D3B5_ARCHIVED_IMAGES_RELOAD_IN_INDEPENDENT_STORE=PASS
D3B5_EPHEMERAL_STORAGE_REMOVED=YES
D3B5_RESULT=0
```

Si aparece `D3B5_ROOTLESS_PODMAN_STORE=FAIL` o `D3B5_ROOTLESS_IMAGE_IMPORT=FAIL`, no afirmar corrupción; distinguir fallo de namespaces/almacén VFS de fallo del formato del archivo antes de corregir.

## Bloqueos para deploy

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D3B5_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D3B5_CONTAINER_RUN_EXECUTED=NO
D3B5_O5_IMAGE_COMPATIBILITY_VERIFIED=NO
D3B5_EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED=NO
D3B5_OFF_HOST_COPY_VERIFIED=NO
D3B5_OPERATIONAL_ROLLBACK_VERIFIED=NO
```

Antes de publicar: ensayo de arranque de imágenes y aplicación con O5 real en entorno aislado apto para servicios, custodia externa cifrada, prueba de reversión integrada con datos y ruta de producción verificada. Conservar los informes históricos: D3-B3 FAIL en la comparación estricta de IDs Docker; D3-B4 PASS únicamente en equivalencia de capas/plataforma/campos seleccionados.


## Primer ensayo B5: Podman ausente, preflight B5P creado

El operador ejecutó B5 y obtuvo `D3B5_PREREQUISITE_MISSING=podman`, `D3B5_RESULT=4`. El script terminó **antes de importar**; no hubo `docker load`, contenedor ejecutado, migración, restauración ni deploy. Es falta de herramienta, no evidencia de archivo corrupto.

Se incorporó el preflight de solo lectura `scripts/main_d3b5p_rootless_prerequisites_readonly.sh` commit `afa237a6`. Evalúa disponibilidad de paquete Podman mediante `apt-cache policy`, `newuidmap`, `newgidmap`, `fuse-overlayfs`, `slirp4netns`, `pasta`, rango /etc/subuid-subgid para usuario actual y sysctls de namespaces. No hace `apt install`, `sysctl -w`, modificaciones de archivos, Docker calls ni `podman info` que pueda inicializar almacenamiento persistente.

Comando Termius:

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash scripts/main_d3b5p_rootless_prerequisites_readonly.sh
echo "D3B5P_SHELL_RESULT=$?"
```

El resultado del preflight tampoco autoriza una instalación: a partir de los indicadores se decidirá si el ensayo puede realizarse con Podman rootless existente, si debe solicitarse permiso para instalar dependencias en el host o si conviene una máquina de laboratorio separada. **B5 importación sigue pendiente**; guardas `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, release no autorizado.
