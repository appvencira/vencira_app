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
