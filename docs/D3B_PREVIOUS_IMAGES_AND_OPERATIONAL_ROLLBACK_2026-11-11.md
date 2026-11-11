# D3-B — Custodia de imágenes anteriores y rollback operativo (11/11/2026)

**Estado: inventario read-only publicado en main, ejecución local pendiente. No es rollback validado.**

## Decisión para acelerar

D1-M y D1-N ya hicieron la restauración de un **snapshot real O5** a PostgreSQL 17 aislado. D1-N también probó migraciones `0019–0027` y reversión de esquema sobre datos reales. D3-A ahora aprobó una restauración **completa** de base sintética y recuperación de Django. Repetir cualquiera de los tres tests no certifica el riesgo nuevo: disponer de una **imagen anterior de API y Web, retenida e identificada**, que pueda usarse conjuntamente con un punto de recuperación de base en una reversión operativa.

## D3-B1 — inventario necesario, sin detener servicios

`scripts/main_d3b_operational_rollback_inventory_readonly.sh` (commit `66181242`, corrección de expansión Bash `835890d4`):

- Exige checkout limpio y HEAD igual a `origin/main`, tolera checkout desacoplado; no hace checkout ni cambia ramas.
- Comprueba identidad `vencira_localcheck` y estado RUNNING de API, DB y web_preview.
- Verifica que las **tres imágenes en ejecución** tienen IDs inmutables `sha256:` disponibles localmente y DB monta un volumen Docker nombrado en `/var/lib/postgresql/data`. No accede al contenido del volumen.
- Para acreditar imágenes **anteriores** exige explícitamente dos variables opcionales `D3B_PREVIOUS_API_IMAGE` y `D3B_PREVIOUS_WEB_IMAGE`, con **IDs completos sha256** distintos de los que están en ejecución, y comprueba su presencia por `docker image inspect`. Nunca acepta `latest` ni infiere arbitrariamente qué imagen fue release anterior. No imprime IDs ni credenciales.
- Si no están documentadas esas imágenes, devuelve `D3B_PREVIOUS_IMAGE_MANIFEST=MISSING`, `D3B_RESULT=4` y **NO** para rollback: es un bloqueo de evidencia, **no un fallo del servicio**.

El inventario no para contenedores, no crea ni elimina imágenes/volúmenes, no consulta base, no lee secretos O5, no descarga un backup, no hace backup ni desplega. Puede pedir `sudo` para `docker inspect`.

### Ejecución inicial — sin IDs previos

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d3b_operational_rollback_inventory_readonly.sh
bash scripts/main_d3b_operational_rollback_inventory_readonly.sh
echo "D3B_SHELL_RESULT=$?"
```

**Esperado por diseño antes de localizar un release anterior** (no atribuir PASS hasta recibir salida): `D3B_MAIN_SYNC=PASS`, `D3B_OPERATIONAL_IDENTITY=PASS`, `D3B_CURRENT_IMAGES_IMMUTABLE_AND_LOCAL=PASS`, `D3B_POSTGRES_NAMED_VOLUME=PASS`, seguido de `D3B_PREVIOUS_IMAGE_MANIFEST=MISSING`, `D3B_OPERATIONAL_ROLLBACK_VERIFIED=NO`, `D3B_RESULT=4`. Si el operador dispone de un manifiesto autenticado de las imágenes anteriores, se podrán suministrar las dos variables de entorno **solo localmente**, sin pegarlas en chat; no identificarlas por la fecha o etiqueta `latest`.

## Lo que falta para D3-B2

Con imágenes previas identificadas y disponibles, preparar un ensayo separado de cambio reversible a esas imágenes contra un **restore de O5 real** en PG17 aislado, con esquema compatible y pruebas HTTP/autenticación sintética sin fuga de datos. No usar imágenes de producción contra el volumen real o respaldos sin aislar. El test D1-N verifica un grafo histórico y no reemplaza una prueba de restauración compatible con la imagen **anterior**. Solo después de validar imagen/BD y reversión del procedimiento, y comprobar rutas reales de producción, se discutirá un piloto con aprobación explícita.

## Barreras permanentes

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D3B_RELEASE_AUTHORIZED=NO
D3B_DEPLOY_EXECUTED=NO
D3B_LIVE_MIGRATIONS_EXECUTED=NO
D3B_LIVE_RESTORE_EXECUTED=NO
D3B_ROLLBACK_EXECUTED=NO
D3B_OPERATIONAL_ROLLBACK_VERIFIED=NO
```

**No confundir custodia de una imagen anterior con recuperación operativa demostrada.**


## D3-B1 ejecución y corrección del criterio previo al upgrade

El operador confirmó `D3B_MAIN_SYNC=PASS`, `D3B_OPERATIONAL_IDENTITY=PASS`, `D3B_CURRENT_IMAGES_IMMUTABLE_AND_LOCAL=PASS`, `D3B_POSTGRES_NAMED_VOLUME=PASS`, seguido por `D3B_PREVIOUS_IMAGE_MANIFEST=MISSING`, `D3B_RESULT=4`. No se hizo deploy ni rollback.

**Corrección conceptual:** el inventario original exigía dos imágenes anteriores *distintas de las que están corriendo*, algo innecesario antes de iniciar una actualización: **las imágenes corrientes son la versión anterior del futuro despliegue**. El test no debe confundir un histórico no documentado con ausencia de punto de retorno *pre-upgrade*. Publicado commit `ec17d9ed` en `scripts/main_d3b_operational_rollback_inventory_readonly.sh`.

La comprobación corregida mantiene los controles de identidad, hash completo de imagen Docker, disponibilidad local y volumen nombrado, y clasifica:

```text
D3B_PRE_UPGRADE_IMAGE_BASELINE_IDENTIFIED=PASS
D3B_PRE_UPGRADE_IMAGE_BASELINE_CURRENT_LOCAL=YES
D3B_PRE_UPGRADE_IMAGE_RETENTION_GUARANTEED=NO
D3B_PRE_UPGRADE_IMAGE_ARCHIVE_VERIFIED=NO
D3B_HISTORICAL_IMAGE_MANIFEST=NOT_PROVIDED
D3B_HISTORICAL_IMAGE_CUSTODY_VERIFIED=NO
D3B_PRE_UPGRADE_ROLLBACK_BASELINE_INVENTORY=PASS
D3B_RESTIC_O5_IMAGE_COMPATIBILITY_VERIFIED=NO
D3B_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO
D3B_OPERATIONAL_ROLLBACK_VERIFIED=NO
D3B_PUBLIC_RELEASE_AUTHORIZED=NO
D3B_RESULT=0
```

Esto **no se ha ejecutado aún** y dichos marcadores son resultados esperados, no hechos comprobados. El 0 final significa que se ha inventariado la versión base; **no garantiza que Docker retenga estas imágenes después de sustituirlas**. Una salvaguarda de retención o exportación de imágenes, con almacenamiento suficiente y verificación de restaurabilidad, es necesaria antes de tocar contenedores operativos.

### Comando reducido

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d3b_operational_rollback_inventory_readonly.sh
bash scripts/main_d3b_operational_rollback_inventory_readonly.sh
echo "D3B_SHELL_RESULT=$?"
```

El criterio anterior que exigía imágenes históricas distintas queda **supersedido** por esta sección. No equivale a autorizar deploy, ni rollback operativo real, ni asegurar la retención de imágenes.


## D3-B1 confirmado PASS por operador

La reejecución local corrigió el falso bloqueo de histórico: `D3B_OPERATIONAL_IDENTITY=PASS`, `D3B_CURRENT_IMAGES_IMMUTABLE_AND_LOCAL=PASS`, `D3B_POSTGRES_NAMED_VOLUME=PASS`, `D3B_PRE_UPGRADE_IMAGE_BASELINE_IDENTIFIED=PASS`, `D3B_PRE_UPGRADE_IMAGE_BASELINE_CURRENT_LOCAL=YES`, `D3B_PRE_UPGRADE_ROLLBACK_BASELINE_INVENTORY=PASS`, `D3B_RESULT=0`. **No** se ha demostrado retención de esas imágenes ni rollback de imagen+datos: `D3B_PRE_UPGRADE_IMAGE_RETENTION_GUARANTEED=NO`, `D3B_PRE_UPGRADE_IMAGE_ARCHIVE_VERIFIED=NO`, `D3B_RESTIC_O5_IMAGE_COMPATIBILITY_VERIFIED=NO`, `D3B_OPERATIONAL_ROLLBACK_VERIFIED=NO`.

## D3-B2 preparado: archivo local de las imágenes de retorno

Nuevo script `scripts/main_d3b2_archive_current_images_safe.sh` (commit `c14bd22a`), aún **NO EJECUTADO** en VPS. Su objetivo es conservar fuera de Docker y fuera de Git la versión de retorno, identificada por IDs inmutables de **las tres imágenes operativas actuales (API, PostgreSQL, Web Preview)**. Acciones:

- Requiere HEAD exacto `origin/main`, árbol limpio, identidad Compose `vencira_localcheck`, contenedores corriendo, imágenes SHA256 locales y volumen PG nombrado. No lee su contenido.
- Operador no root con `sudo docker`; crea `~/vencira-release-archives` con permisos 0700, rechaza permisos distintos y symlink directo.
- Calcula reserva mínima conservadora según suma de tamaños virtuales de imágenes + 1 GiB libre. Si no cabe, aborta sin hacer archivo ni tocar servicios.
- `docker image save` por ID de las tres imágenes a un archivo `images.tar.gz` comprimido; `gzip -t`, enumeración de integridad tar y `sha256sum -c` verifican el archivo. Conserva `images.manifest` con IDs y checksum bajo ruta privada; no imprime los SHA de imágenes, nombres de clientes, secretos, certificados ni variables de entorno.
- Comprueba en el `trap` que identidad ID:imagen de los tres contenedores DEV se mantiene; ante fallo elimina el directorio/archivo parcial. No para contenedores, reinicia Caddy, migra, restaura PG ni hace `docker image load`.

**Importante:** archivo checksum/tar íntegro no equivale a verificar `docker load`, restaurabilidad real de imágenes ni compatibilidad con la base O5. Tampoco equivale a una copia independiente del servidor: `D3B2_ARCHIVE_OFF_HOST_VERIFIED=NO`. No autoriza publicación. El archivo contiene capas Docker potencialmente sensibles, por lo que no se debe subir a GitHub ni adjuntar en el chat; acceso privado exclusivamente en VPS.

### Termius — una sola ejecución D3-B2

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d3b2_archive_current_images_safe.sh
bash scripts/main_d3b2_archive_current_images_safe.sh
echo "D3B2_SHELL_RESULT=$?"
```

Resultado por determinar: `D3B2_DISK_CAPACITY=PASS`, `D3B2_IMAGE_SAVE=PASS`, `D3B2_ARCHIVE_STRUCTURAL_INTEGRITY=PASS`, `D3B2_ARCHIVE_CHECKSUM=PASS`, `D3B2_PRE_UPGRADE_IMAGES_ARCHIVED=PASS`, `D3B2_DEV_CONTAINERS_UNCHANGED=OK`, `D3B2_ARCHIVE_PRESERVED=YES`, `D3B2_RESULT=0`. Si capacidad insuficiente, tratar `DISK_CAPACITY=FAIL` como bloqueo real; no eliminar backups ni imágenes operativas para sortearlo.

**Pendiente posterior:** probar `docker load` en laboratorio aislado sin afectar al daemon Docker operativo, cotejar digest/IDs importados y ensayar imagen anterior sobre O5 restaurado, y una copia externa cifrada/retención verificable para disaster recovery. Hasta entonces `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MFA_RELEASE_AUTHORIZED=NO`.


## D3-B2 ejecución validada, D3-B3 comprobación independiente preparada

El operador proporcionó `D3B2_RESULT=0`, `D3B2_MAIN_SYNC=PASS`, `D3B2_CURRENT_IMAGES_PRESENT=PASS`, `D3B2_DB_NAMED_VOLUME=PASS`, `D3B2_DISK_CAPACITY=PASS`, `D3B2_IMAGE_SAVE=PASS`, `D3B2_ARCHIVE_STRUCTURAL_INTEGRITY=PASS`, `D3B2_ARCHIVE_CHECKSUM=PASS`, `D3B2_PRE_UPGRADE_IMAGES_ARCHIVED=PASS`, `D3B2_DEV_CONTAINERS_UNCHANGED=OK`, `D3B2_ARCHIVE_PRESERVED=YES`. El archivo se encuentra **solo en el VPS**, en un directorio protegido bajo `/home/vencira/vencira-release-archives/`. No reproducir su contenido en chat/Git. Según el log `D3B2_ARCHIVE_OFF_HOST_VERIFIED=NO`, `D3B2_IMAGE_RELOAD_TESTED=NO`, `D3B2_OPERATIONAL_ROLLBACK_VERIFIED=NO`. Esto acredita custodia local y checksum, no recuperación conjunta.

Se preparó **D3-B3** `scripts/main_d3b3_verify_archived_images_offline.py` (commit `8bf132f9`, corrección tar `6a89f9a0`), un comprobador independiente de **solo lectura** que:
- Exige directorio y archivos propiedad del operador, sin symlinks y sin permisos para grupo/otros.
- Verifica formato exacto de `images.manifest` con tres SHA256 Docker, el checksum SHA256 del archivo comprimido y estructura tar segura (archivos y directorios únicamente, sin symlinks ni rutas escapadas).
- Lee `manifest.json` de `docker save`, calcula SHA256 de los JSON de configuración y exige que los tres IDs inmutables archivados aparezcan realmente entre las imágenes. Verifica que las referencias de capas en el índice existan. No muestra identificadores, datos ni contenido de capas.
- **No hace `docker load`, no arranca contenedores ni accede al volumen PostgreSQL, a O5, a Caddy o a credenciales.** La comprobación del contenido comprimido implica lecturas intensivas del archivo; no volver a ejecutarla sin necesidad una vez PASS.

### Ejecución D3-B3 en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -m py_compile scripts/main_d3b3_verify_archived_images_offline.py
python3 scripts/main_d3b3_verify_archived_images_offline.py \
  /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D3B3_SHELL_RESULT=$?"
```

**Esperado, pendiente de validación:** `D3B3_IMMUTABLE_MANIFEST=PASS`, `D3B3_ARCHIVE_CHECKSUM=PASS`, `D3B3_DOCKER_ARCHIVE_CONFIG_IDS=PASS`, `D3B3_OFFLINE_ARCHIVE_STRUCTURE=PASS`, `D3B3_RESULT=0`.

**Siguiente decisión operativa:** decidir prueba real de importación/ejecución en daemon aislado, compatibilidad con O5 restaurado y copia cifrada externa; no retirar guardas `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` ni aprobar release por este archivo.


## D3-B3 primer ensayo: fallo del verificador de nombres (no del checksum)

El operador ejecutó D3-B3: `D3B3_IMMUTABLE_MANIFEST=PASS`, `D3B3_ARCHIVE_CHECKSUM=PASS`, `D3B3_CONFIG_NAME=FAIL`, `D3B3_RESULT=3`. La comparación de hash del archivo comprimido es satisfactoria; **el nombre `Config` contenido en el índice Docker no cumple la única expresión regular permitida en la versión anterior**. No se acredita todavía que el contenido sea correcto ni que el fallo sea exclusivamente un formato admitido: la única conclusión es que el parser falló antes de contrastar los bytes de configuración.

Se han publicado las correcciones `c8031274` y `1edec477` en `scripts/main_d3b3_verify_archived_images_offline.py`: ahora se aceptan exactamente dos representaciones *content-addressed* conocidas del campo `Config`: `<64hex>.json` o `blobs/sha256/<64hex>`. En ambos casos se verifica SHA256 de **los bytes reales del JSON** contra el digest codificado en el nombre. Continúan rechazándose rutas arbitrarias, archivos faltantes, duplicados, symlinks y manifiestos inconsistentes, y nunca se imprimen datos del archivo. **El fallo previo no justifica regenerar ni borrar el archivo de imágenes**.

**Retest:** actualizar `origin/main` y volver a lanzar exactamente el comando D3-B3 sobre el archivo existente. El nuevo resultado **no está validado aún**. Si llega a `CONFIG_HASH=FAIL` o `LAYERS_MISSING=FAIL`, analizar el formato interno sin asumir corrupción ni desactivar verificaciones. `D3B3_IMAGE_LOAD_EXECUTED=NO`, `D3B3_ROLLBACK_EXECUTED=NO`, `D3B3_OFF_HOST_COPY_VERIFIED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` se mantienen.


## D3-B3 segundo ensayo: digest global correcto, falta correspondencia de IDs

El operador repitió D3-B3 tras permitir nombres de configuración Docker válidos. Resultado: `D3B3_IMMUTABLE_MANIFEST=PASS`, `D3B3_ARCHIVE_CHECKSUM=PASS`, `D3B3_EXPECTED_IMAGE_IDS_MISSING=FAIL`, `D3B3_RESULT=3`. Los archivos de configuración presentes **han superado sus hashes por nombre**, pero la comparación entre los hashes de configuración archivados y el manifiesto externo de **las tres imágenes en ejecución** no se satisface. **No se puede afirmar que el archivo incluya exactamente las tres imágenes.** Tampoco se concluye corrupción de backup porque el checksum global coincide y los miembros leídos son coherentes.

Se añadió el diagnóstico seguro en commit `ccaf5dfd` sin modificar archivo, Docker ni el contrato de aceptación. Marcadores: `D3B3_ARCHIVED_CONFIG_ENTRY_COUNT`, `D3B3_ARCHIVED_CONFIG_UNIQUE_COUNT`, `D3B3_EXPECTED_IMAGE_UNIQUE_COUNT`, `D3B3_EXPECTED_API_CONFIG_ID_MATCH`, `D3B3_EXPECTED_DB_CONFIG_ID_MATCH`, `D3B3_EXPECTED_WEB_CONFIG_ID_MATCH`, `D3B3_DOCKER_IMAGE_ID_EQ_CONFIG_DIGEST`. Se emiten solo conteos y booleanos; nunca identificadores, datos de configuración ni capas. La prueba **continúa FAIL** si falta cualquier ID. No regenerar ni eliminar el archivo y no forzar un PASS mediante comparación parcial.

Repetir comando D3-B3 existente después de actualizar main; investigar según qué rol falte. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin operaciones sobre DEV.


## D3-B3 tercer ensayo: tres configuraciones, cero coincidencias por ID

El operador informa `D3B3_ARCHIVED_CONFIG_ENTRY_COUNT=3`, `D3B3_ARCHIVED_CONFIG_UNIQUE_COUNT=3`, `D3B3_EXPECTED_IMAGE_UNIQUE_COUNT=3`, `D3B3_EXPECTED_API_CONFIG_ID_MATCH=NO`, `D3B3_EXPECTED_DB_CONFIG_ID_MATCH=NO`, `D3B3_EXPECTED_WEB_CONFIG_ID_MATCH=NO`, `D3B3_EXPECTED_IMAGE_IDS_MISSING=FAIL`, `D3B3_RESULT=3`. El checksum global del archivo y los hashes de las configuraciones que contiene siguen verificándose correctamente, pero **no** se ha acreditado su identidad como las imágenes ejecutadas. No convertir el gate D3-B3 en PASS sin evidencia de equivalencia y sin probar restauración. No regenerar ni borrar el archivo original.

Para evitar nuevas modificaciones especulativas del gate, se publicó un **diagnóstico independiente D3-B4** (`scripts/main_d3b4_archive_vs_running_metadata_readonly.py`, commit `a02af3ad`). Inspecciona metadatos actuales de las tres imágenes Docker y sus contenedores de forma **read-only** (`sudo -n docker container/image inspect`), exige que los contenedores sigan usando los tres IDs registrados al archivar y compara internamente, sin imprimir identificadores, variables de entorno ni contenido, el OS/arquitectura y los `rootfs.diff_ids` archivados contra `RootFS.Layers` del host. Si hay exactamente una coincidencia por rol, compara una selección de campos efectivos de configuración y emite **solo conteos de diferencias**. No supone que esas capas y campos basten para acreditar identidad bit-a-bit: aun si coinciden, `D3B4_ARCHIVE_EXACT_IMAGE_IDS_VERIFIED=NO`, `D3B4_IMAGE_RELOAD_TESTED=NO`, `D3B4_OPERATIONAL_ROLLBACK_VERIFIED=NO`. Un `D3B4_RESULT=0` indica solo que el diagnóstico se completó, nunca aprobación de release.

### Comando único D3-B4

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -m py_compile scripts/main_d3b4_archive_vs_running_metadata_readonly.py
sudo -v
python3 scripts/main_d3b4_archive_vs_running_metadata_readonly.py \
  /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D3B4_SHELL_RESULT=$?"
```

D3-B4 **NO ejecutado aún en VPS**. Los marcadores más útiles son `D3B4_DEV_IMMUTABLE_IDENTITY`, `D3B4_ARCHIVE_CONFIG_COUNT`, `D3B4_EXPECTED_API_ROOTFS_PLATFORM_MATCH_COUNT`, `D3B4_EXPECTED_DB_ROOTFS_PLATFORM_MATCH_COUNT`, `D3B4_EXPECTED_WEB_ROOTFS_PLATFORM_MATCH_COUNT` y respectivos `RUNTIME_FIELDS_COMPARED`/`RUNTIME_FIELDS_DIFFERENT`. No publicar `docker inspect` bruto, que puede exponer secretos. Las tres copias Docker siguen intactas en el archivo original y no se ha ejecutado ninguna carga de imágenes ni restauración operacional.
