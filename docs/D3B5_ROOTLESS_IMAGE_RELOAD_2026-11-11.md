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


## D3-B5P — interrupción SIGPIPE 141 corregida (11/11/2026)

El operador obtuvo `D3B5P_UNPRIVILEGED_OPERATOR=PASS` y `D3B5P_PODMAN_INSTALLED=NO`, con retorno final `141`, antes de emitir `PODMAN_APT_CANDIDATE`. El primer script contenía `apt-cache policy podman | awk '/Candidate:/ {print $2; exit}'` bajo `set -o pipefail`; el `exit` anticipado de AWK puede cerrar la tubería mientras `apt-cache` sigue emitiendo y provocar SIGPIPE. Por tanto **no es posible inferir de esa salida disponibilidad de paquete, soporte rootless ni estado completo del preflight**.

Corregido directamente en `main` commit `bf544996`: AWK continúa consumiendo toda la salida de apt-cache y solo imprime la primera coincidencia; si falla la consulta se marca `D3B5P_PODMAN_APT_QUERY=ERROR` en vez de confundirla con falta de candidato. **No se instalaron paquetes y no se cambió configuración**. La ejecución corregida continúa pendiente de Termius. El valor aportado `D3B5P_SHLL_RESULT=141` procede del `echo` introducido por el operador y no de un marcador interno del script (el script no llegó a `D3B5P_RESULT`).

Repetir únicamente `bash scripts/main_d3b5p_rootless_prerequisites_readonly.sh` tras sincronizar `main`; no repetir importación D3-B5 ni ejecutar `apt install` todavía. Guardas `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## D3-B5P — preflight del host CONFIRMADO PASS (11/11/2026)

El operador ha aportado dos ejecuciones idénticas, ambas con `D3B5P_RESULT=0`, `D3B5P_UNPRIVILEGED_OPERATOR=PASS`, `D3B5P_PODMAN_INSTALLED=NO`, `D3B5P_PODMAN_APT_CANDIDATE=AVAILABLE`, `D3B5P_SUBUID_SUBGID_RANGE=PASS`, `D3B5P_USER_NAMESPACES_KERNEL=ENABLED`, `D3B5P_UNPRIVILEGED_USERNS_CLONE=ENABLED`. Los ejecutables auxiliares `newuidmap`, `newgidmap`, `fuse-overlayfs`, `slirp4netns` y `pasta` constan como `NO` disponibles. `D3B5P_ROOTLESS_PODMAN_RUNTIME_VERIFIED=NO`; `D3B5P_PACKAGE_INSTALL_AUTHORIZED=NO`.

**Clasificación:** PASS de *inventario de requisitos*, NO de Podman operativo. Un paquete candidato y namespaces habilitados no certifican ejecución rootless. El siguiente paso necesita una decisión operativa explícita sobre instalar `podman` y dependencias de UID/GID en el VPS o usar una máquina de laboratorio externa. No instalar ni modificar sysctl/subuid o paquetes por inferencia automática. Si se opta por VPS, primero verificar simulación APT (`apt-get -s install podman uidmap`) y efectos de dependencias; `fuse-overlayfs` no es obligatorio para VFS, ni `slirp4netns`/pasta para importación de imágenes sin ejecutar contenedores. Separar rigurosamente el alta de software base del ensayo de recuperación y auditar cualquier cambio.

**El gate D3-B5 de importación continúa NO EJECUTADO** por falta de Podman; `D3B5P_RESULT=0` no desbloquea por sí solo `D3B5_ROOTLESS_IMAGE_IMPORT`. Persisten `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin alteraciones de Docker operativo, O5 o DEV.


## APT simulación aportada por operador (11/11/2026)

`apt-get -s install podman uidmap` devuelve **0 upgraded, 15 newly installed, 0 to remove, 22 not upgraded** en Ubuntu 24.04. Candidatos: `podman 4.9.3+ds1-1ubuntu0.2`, `uidmap`, `fuse-overlayfs`, `slirp4netns`, `passt` y las demás dependencias de Podman/Buildah/Netavark. La simulación **no incluye eliminación o actualización de los paquetes Docker en uso**, pero no constituye prueba de que no haya efectos sobre systemd, espacio en disco o configuración operativa durante una instalación real.

**Estado:** simulación satisfactoria; la instalación **no ha sido ejecutada**. La operación de instalar Podman debe distinguirse del deploy VENCIRA y evaluarse como cambio administrativo controlado; no autoriza despliegue, cambios de DB ni MFA. Tras una instalación autorizada, comprobar `podman --version`, `newuidmap`, `newgidmap`, espacio libre, identidades de contenedores DEV, y volver al gate D3-B5 de importación. No activar un socket Podman ni cambiar el runtime de Docker.


## D3-B5 — Podman rootless instalado, almacén privado VFS no inicializa (11/11/2026)

El operador confirma Podman 4.9.3, `newuidmap`/`newgidmap`, `podman info` normal con `Rootless=true`, `GraphDriver=overlay`, subuid/subgid 65536, Docker systemd activo, seis contenedores DEV/Preview healthy y 171 GiB libres. Ensayo D3-B5 en almacén privado VFS: `D3B5_MAIN_SYNC=PASS`, `D3B5_ARCHIVE_CHECKSUM=PASS`, `D3B5_STORAGE_CAPACITY=PASS`, **`D3B5_ROOTLESS_PODMAN_STORE=FAIL`**, `D3B5_EPHEMERAL_STORAGE_REMOVED=YES`, `D3B5_RESULT=4`. **No se intentó `podman load`**, ni se usó Docker operativo.

La causa raíz **aún no está establecida**. El fallo del `podman info` con parámetros privados `--root`, `--runroot`, `--storage-driver vfs` debe diferenciarse de un problema de contenido del archivo. `podman info` rootless normal con `overlay` no prueba que VFS privado inicialice bajo el cambio temporal de HOME.

Se integró en `main` commit `fa4df2ff` un clasificador cerrado del error `podman info` dentro de `scripts/main_d3b5_rootless_podman_reload_isolated.sh`. Solo imprime `D3B5_PODMAN_INFO_ERROR_CATEGORY` y `D3B5_PODMAN_INFO_EXIT_CODE`; nunca registra stderr bruto, variables o rutas. No cambia el modo de almacenamiento, no relaja la igualdad de `graphRoot` ni la prohibición de tocar Docker host.

Repetir D3-B5 solo una vez tras actualizar `main` para obtener la categoría; **si el fallo se repite, detenerse**, no añadir `sudo podman` ni cambiar `storage.conf` o sysctls manualmente. D3-B5 sigue pendiente de importación, D3-B3 sigue sin identidad exacta, y `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` se mantienen.


## D3-B5 — reensayo: categoría de fallo del runtime rootless

Salida del operador: `D3B5_MAIN_SYNC=PASS`, `D3B5_ARCHIVE_CHECKSUM=PASS`, `D3B5_STORAGE_CAPACITY=PASS`, `D3B5_PODMAN_INFO_ERROR_CATEGORY=RUNTIME_DIRECTORY_FAILURE`, `D3B5_PODMAN_INFO_EXIT_CODE=125`, `D3B5_ROOTLESS_PODMAN_STORE=FAIL`, `D3B5_EPHEMERAL_STORAGE_REMOVED=YES`, `D3B5_RESULT=4`. La clasificación es orientativa y **no demuestra causa raíz**; no ha comenzado la importación.

Se detectó que el script original reescribía `HOME` y `XDG_CONFIG_HOME` a un directorio temporal, además de definir almacenes `--root`/`--runroot` independientes. Dado que Podman rootless utiliza el contexto de usuario y directorios runtime, esa sustitución es una **hipótesis plausible** del error. Corrección `aeb37369`: conserva `HOME`, `XDG_CONFIG_HOME` y `XDG_RUNTIME_DIR` del operador, verifica la propiedad del directorio runtime cuando existe; mantiene `--remote=false`, almacén VFS nuevo `--root` y `--runroot`, y limpieza de laboratorio. No requiere cambios a `storage.conf`, `sudo podman`, Docker operativo o configuración del kernel.

**Validación pendiente del operador**; no se puede declarar D3-B5 PASS antes del nuevo resultado. Si continúa `ROOTLESS_PODMAN_STORE=FAIL`, analizar de forma acotada el error clasificado y evitar repetir ciclos sin evidencia nueva. Mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin deploy ni migraciones.
