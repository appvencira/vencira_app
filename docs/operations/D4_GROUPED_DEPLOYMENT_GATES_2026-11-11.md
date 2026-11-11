# D4 — Cinco bloqueos agrupados para acelerar la entrega (2026-11-11)

## Decisión

Agrupar los cinco riesgos pendientes en un único programa D4 sobre `main`, sin nuevas ramas, sin repetir D1-N, D3-A, D3-C, D3-B5, D3-B6C ni D3-B7. El objetivo es minimizar el trabajo de operador: primero un preflight de solo lectura y después **un único laboratorio aislado con criterios de aceptación por bloque**, seguido de un gate de producción separado.

El script `scripts/main_d4_grouped_release_blockers_readonly.sh` **solo inventaría**, no ejecuta el laboratorio ni autoriza despliegue. Su código de salida **4** es deliberado mientras sigan los bloqueos. No interpretar `RESULT=4` como regresión de gates históricos. No se utilizará el daemon Docker operativo para importar imágenes ni el volumen vivo de PostgreSQL para restauraciones.

## Matriz única de ejecución

| Bloque | Evidencia que ya existe | Falta para cerrar | Condición de aceptación |
| --- | --- | --- | --- |
| B1, recuperación de imágenes | D3-B5 carga rootless de 3 imágenes PASS; D3-B6C 46 blobs verificados | Arranque aislado de imágenes archivadas, pruebas de HTTP y servicios | Runtime y aislamiento verificados sin acceso al Docker operativo |
| B2, rollback imagen + O5 | D1-N restore O5 real aislado; D3-A restore sintético; D3-B4 mapeo rootfs | Combinar imágenes anteriores con backup O5 real aislado, compatibilidad de migraciones y procedimiento de retorno | Recuperación reversible probada con datos controlados y ninguna alteración DEV |
| B3, retención externa | Archivo privado y checksum local PASS | Copia cifrada independiente del VPS y restauración de muestra | Destino externo, integridad, restaurabilidad y custodia comprobados |
| B4, regresión final main | Suites históricas backend/Flutter/HTTPS y pruebas Android | Reejecutar selectivamente el candidato final: Django/PG17, Flutter analyze/test/build, sesión/CSRF/MFA según alcance, adjuntos/calendario | Un gate del SHA final, sin falsos PASS heredados |
| B5, producción | D3-C Caddy DEV/TLS PASS | Configuración real de `vencira.es`, host/CSRF/cookies, secretos, plan de publicación, observabilidad, revisión de restricciones | Preflight producción verificado y aprobación operativa explícita |

**Riesgo transversal:** D3-B3 sigue FAIL en coincidencia exacta entre ID Docker histórico y digest de configuración archivada. D3-B7 demuestra seis coincidencias contenedor↔Docker inspect↔manifiesto externo. No equivale a identidad exacta de la exportación ni puede declararse resuelto de forma automática. Un proceso de autorización deberá valorar el riesgo residual con evidencia técnica y registro explícito.

## Política operativa

1. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta que los gates correspondientes se aprueben expresamente.
2. No instalar/modificar servicios en DEV, cargar imágenes en Docker host ni recuperar PostgreSQL vivo durante D4.
3. No afirmar recuperación operativa antes de B1 y B2; no afirmar DR externo antes de B3.
4. No volver a ejecutar pruebas costosas ya cerradas salvo que el código candidato haya cambiado materialmente.
5. **Primera autorización a considerar**: piloto DEV, no producción, con control de cambios, backup y reversión. Producción se aprueba aparte después de B4/B5.

## Ejecutar el inventario agrupado en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4_grouped_release_blockers_readonly.sh
bash scripts/main_d4_grouped_release_blockers_readonly.sh
echo "D4_SHELL_RESULT=$?"
```

La salida inicial esperada identifica el archivo existente, las evidencias previas y **cinco bloqueos pendientes**. `D4_RESULT=4` es el bloqueo de autorización previsto, no autorización de release.

## Próxima entrega técnica

Diseñar B1+B2 como **un solo ensayo** de runtime de imágenes archivadas y base O5 aislada, con protecciones de red, ausencia de sockets, volúmenes efímeros, datos no expuestos, recursos limitados y limpieza verificable. Antes de ejecutar, deberá existir gate de preflight de aislamiento y permisos. Los bloques B3-B5 pueden prepararse documentalmente en paralelo en `main` sin alterar sistemas.

```text
D4_DEPLOY_EXECUTED=NO
D4_LIVE_MIGRATIONS_EXECUTED=NO
D4_LIVE_RESTORE_EXECUTED=NO
D4_PUBLIC_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Resultado D4 y siguiente ejecución D4-A

El operador confirmó el inventario D4: `D4_MAIN_SYNC=PASS`, `D4_CLEAN_TREE=PASS`, archivo de imagen PRESENT, evidencias B1/B2/B4 documentadas, Caddy ACTIVE, `D4_BLOCKERS_OPEN=5`, `D4_RELEASE_READINESS=BLOCKED`, `D4_RESULT=4` y `D4_SHELL_RESULT=4`. No se ejecutó ningún despliegue, carga de imágenes, restauración ni contenedor. **Este código 4 es el cierre correcto del inventario, no un gate funcional fallido.**

Para evitar otro inventario genérico, se publicó `scripts/main_d4a_b1b2_joint_lab_preflight_readonly.sh`. Este control comprueba de una vez las condiciones previas para el laboratorio conjunto B1+B2: permisos del archivo, Podman rootless, runtime de usuario, documentación técnica D1-N/B5/B6C y existencia/permisos del contrato O5. No descifra copias, no importa ni ejecuta imágenes y no toca Docker operativo. La verificación de permisos O5 puede quedar `UNVERIFIED` si no se dispone de autorización de sudo no interactiva: no es prueba de inexistencia de copias.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4a_b1b2_joint_lab_preflight_readonly.sh
sudo -v
bash scripts/main_d4a_b1b2_joint_lab_preflight_readonly.sh
echo "D4A_SHELL_RESULT=$?"
```

Un `D4A_RESULT=0` solamente acredita la **preparación de laboratorio**; B1/B2 continuarán NO verificados hasta ejecutar el ensayo aislado conjunto. No regenerar el archivo original ni repetir D3-B5/B6C/B7.

## D4-A PASS y D4-B runtime de imágenes preparado (11/11/2026)

El operador confirmó D4-A: `D4A_MAIN_SYNC=PASS`, `D4A_PRIVATE_ARCHIVE_DIRECTORY=PASS`, `D4A_PRIVATE_ARCHIVE_FILES=PASS`, `D4A_XDG_RUNTIME=PASS`, `D4A_PODMAN_ROOTLESS_ENV=PASS`, `D4A_O5_CREDENTIAL_PATH_PERMISSIONS=PASS`, `D4A_LAB_PREFLIGHT=PASS`, `D4A_RESULT=0`. `D4A_SHELL_RESULT` no aparece en la salida aportada; no se presupone. B1 y B2 permanecen sin ejecución.

Nuevo `scripts/main_d4b_isolated_archive_runtime_smoke.sh`: reutiliza el almacenamiento VFS de Podman rootless que pasó D3-B5, importa exclusivamente las tres imágenes a un almacén temporal, y prueba **únicamente** iniciar `/bin/sh -c 'exit 0'` en cada una con `--network none`, `--read-only`, `--cap-drop all`, `--security-opt no-new-privileges`, recursos limitados, sin volúmenes ni credenciales. El cierre elimina contenedores del almacén aislado y capas VFS con `podman unshare`. No es arranque completo de API/Web/PostgreSQL; no acredita O5, compatibilidad ni rollback. Los marcadores `D4B_CONTAINER_RUN_EXECUTED=YES` y `D4B_RESULT=0` (si pasan) indican solo **ejecución de prueba aislada**, no despliegue.

**No ejecutado aún en VPS.** Ejecutar únicamente tras revisar sintaxis, con `main` limpio:

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4b_isolated_archive_runtime_smoke.sh
bash scripts/main_d4b_isolated_archive_runtime_smoke.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D4B_SHELL_RESULT=$?"
```

Si falla el arranque del shell por ausencia de `/bin/sh` en una imagen, no implica corrupción: requerirá adaptar la prueba a su ejecutable real tras inspección de metadatos sin secretos. En un PASS, el siguiente ensayo conjunto B1/B2 deberá incorporar **servicios reales** y O5 en un laboratorio aislado separado; la mera ejecución de shell nunca cerrará el bloque B1.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D4B_DEPLOY_EXECUTED=NO
D4B_LIVE_RESTORE_EXECUTED=NO
D4B_OPERATIONAL_ROLLBACK_VERIFIED=NO
```

## D4-B PASS confirmado por operador (11/11/2026)

```text
D4B_MAIN_SYNC=PASS
D4B_ARCHIVE_CHECKSUM=PASS
D4B_ROOTLESS_PRIVATE_STORE=PASS
D4B_HOST_DOCKER_SOCKET_MOUNTED=NO
D4B_ROOTLESS_IMAGE_IMPORT=PASS
D4B_IMPORTED_IMAGE_COUNT_3=PASS
D4B_IMAGE_1_ISOLATED_SHELL=PASS
D4B_IMAGE_2_ISOLATED_SHELL=PASS
D4B_IMAGE_3_ISOLATED_SHELL=PASS
D4B_ISOLATED_RUNTIME_SHELLS_3=PASS
D4B_EPHEMERAL_STORAGE_REMOVED=YES
D4B_CONTAINER_RUN_EXECUTED=YES
D4B_IMAGE_APPLICATION_STARTUP_VERIFIED=NO
D4B_IMAGE_POSTGRES_READY_VERIFIED=NO
D4B_IMAGE_O5_COMPATIBILITY_VERIFIED=NO
D4B_EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED=NO
D4B_OPERATIONAL_ROLLBACK_VERIFIED=NO
D4B_RESULT=0
D4B_SHELL_RESULT=0
```

Docker `active`, árbol Git limpio. El valor `CONTAINER_RUN_EXECUTED=YES` corresponde a **tres ejecuciones efímeras de /bin/sh**, no a un despliegue. Se ha demostrado ejecución mínima de los tres sistemas de archivos OCI recuperados, no arranque de Django, PostgreSQL ni Nginx. Próximo control D4-C: arrancar solo el PostgreSQL archivado con red `none` y PGDATA `tmpfs`, comprobar `pg_isready`, conservar cero datos y limpiar. Todavía no se acopla O5 ni se cierra B1/B2.

## D4-C — Arranque real de PostgreSQL archivado (preparado, no ejecutado)

El gate `scripts/main_d4c_pg17_archived_isolated_runtime.sh` importa de nuevo el archivo en un almacén VFS efímero **distinto de Docker host**. Identifica por metadatos la única imagen PG17 archivada, inicia su entrypoint real en rootless Podman, red `none`, sin puertos, FS raíz read-only, PGDATA y rutas auxiliares en `tmpfs`, usuario/base/contraseña sintéticos, y comprueba `pg_isready` más `SELECT 1`. Nada de O5 ni volúmenes DEV. El script borra los contenedores temporales y los almacenes privados mediante `podman unshare`.

Si falla `PG17_START`, no implica corrupción de la imagen: podría deberse a permisos rootless/tmpfs o restricciones del entrypoint. No reducir el aislamiento como atajo. Si pasa, **solo cierra arranque básico PG17**, no compatibilidad O5, ni API/Web, ni rollback conjunto.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4c_pg17_archived_isolated_runtime.sh
bash scripts/main_d4c_pg17_archived_isolated_runtime.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D4C_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

`D4C_RESULT=0` y `D4C_EPHEMERAL_STORAGE_REMOVED=YES` son las condiciones de cierre del ensayo; el script debe seguir imprimiendo `D4C_IMAGE_O5_COMPATIBILITY_VERIFIED=NO` y `D4C_OPERATIONAL_ROLLBACK_VERIFIED=NO`.

## D4-C PASS real — PostgreSQL 17 archivado (operador, 11/11/2026)

Operador confirmó `D4C_MAIN_SYNC=PASS`, `D4C_ARCHIVE_CHECKSUM=PASS`, `D4C_ROOTLESS_PRIVATE_STORE=PASS`, `D4C_IMPORTED_IMAGE_COUNT_3=PASS`, `D4C_ARCHIVED_PG17_ROLE_IDENTITY=PASS`, `D4C_PG17_START=PASS`, `D4C_PG17_READY=PASS`, `D4C_PG17_SYNTHETIC_SQL=PASS`, `D4C_NO_EXTERNAL_NETWORK=YES`, `D4C_NO_HOST_DOCKER_SOCKET=YES`, `D4C_NO_PERSISTENT_PGDATA=YES`, `D4C_EPHEMERAL_STORAGE_REMOVED=YES`, `D4C_RESULT=0`, `D4C_SHELL_RESULT=0`. Docker operativo `active`. La última línea `git status --short` aparece truncada al final del pegado; no se declara árbol limpio a posteriori.

**Alcance:** arranque verdadero del entrypoint PostgreSQL archivado con base de datos sintética y consulta SQL. No ha participado O5 real ni han arrancado API y Web. `D4C_CONTAINER_RUN_EXECUTED=YES` es ejecución efímera aislada, no despliegue. Continúan `D4C_IMAGE_API_WEB_STARTUP_VERIFIED=NO`, `D4C_IMAGE_O5_COMPATIBILITY_VERIFIED=NO`, `D4C_EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED=NO`, `D4C_OPERATIONAL_ROLLBACK_VERIFIED=NO`.

**Próximo corte D4-D:** identificar de forma inequívoca los roles API/Web sin adivinar tags; reutilizar los fingerprints rootfs/plataforma de D3-B4 y comprobar los argumentos de arranque efectivos sin exponer entornos/secretos. Después diseñar un laboratorio de aplicación con DB **sintética** en primer término. No ejecutar API con credenciales o datos reales O5 hasta justificar aislamiento y compatibilidad.

## D4-D preparado: roles y contrato de arranque API/Web

Script `scripts/main_d4d_archived_api_web_launch_contract_readonly.py` publicado en main. Compara tres configuraciones archivadas con imágenes activas por rootfs diff IDs, OS y arquitectura, exige mapeo único y emite únicamente indicadores booleanos de presencia de entrypoint, CMD y Env sin imprimir valores. No importa, ejecuta ni modifica imágenes. Un PASS no prueba el arranque de Django/Nginx ni su compatibilidad con O5.

Ejecutar después de sincronizar main: `python3 -m py_compile scripts/main_d4d_archived_api_web_launch_contract_readonly.py` y `python3 scripts/main_d4d_archived_api_web_launch_contract_readonly.py /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7`; registrar `D4D_SHELL_RESULT=$?`. No se ha ejecutado todavía en VPS.

## D4-D PASS validado por operador (11/11/2026)

```text
D4D_MANIFEST_SCHEMA=PASS
D4D_LIVE_IDENTITY=PASS
D4D_ARCHIVED_CONFIGS=3
D4D_API_ROOTFS_PLATFORM_MATCH_COUNT=1
D4D_API_LAUNCH_ENTRYPOINT_PRESENT=NO
D4D_API_LAUNCH_CMD_PRESENT=YES
D4D_DB_ROOTFS_PLATFORM_MATCH_COUNT=1
D4D_DB_LAUNCH_ENTRYPOINT_PRESENT=YES
D4D_DB_LAUNCH_CMD_PRESENT=YES
D4D_WEB_ROOTFS_PLATFORM_MATCH_COUNT=1
D4D_WEB_LAUNCH_ENTRYPOINT_PRESENT=YES
D4D_WEB_LAUNCH_CMD_PRESENT=YES
D4D_UNIQUE_ROLE_MAPPING=PASS
D4D_API_WEB_STARTUP_VERIFIED=NO
D4D_O5_IMAGE_COMPATIBILITY_VERIFIED=NO
D4D_EXACT_HISTORICAL_ID_VERIFIED=NO
D4D_OPERATIONAL_ROLLBACK_VERIFIED=NO
D4D_RESULT=0
D4D_SHELL_RESULT=0
```

El árbol Git reportado está limpio. Hay asignación única de imagen archivada a API, DB y Web por plataforma y rootfs. El backend tiene CMD de arranque pero no ENTRYPOINT; Web y PostgreSQL tienen ambos. No se ejecutaron contenedores en este gate.

**Evitar más inventarios parciales:** la próxima fase debe agrupar en un único ensayo ejecución real de API y Web con configuración de pruebas, red/laboratorio aislados, DB sintética, test HTTP local y limpieza verificada. Un paso posterior distinto acoplará O5 real únicamente tras comprobar que no hay fuga de acceso desde la aplicación aislada al entorno DEV. Sin evidencia de ejecución funcional, mantener B1/B2 abiertos. La copia off-host B3, la regresión final B4 y producción B5 continúan pendientes.

## D4-E — Una ejecución API+Web HTTP aislada (preparada, NO ejecutada)

Se publicó `scripts/main_d4e_archived_api_web_isolated_http.sh`. En una sola importación privada VFS se identifican las dos imágenes por su contrato de arranque (`gunicorn` y `nginx`, no por tags). El script arranca API y Web en **contenedores separados con red `none`**, filesystem read-only, `tmpfs` para directorios temporales, sin puertos del host, sin montajes de volúmenes DEV ni acceso a Docker operativo. Django recibe `VENCIRA_ENV=test`, secreto aleatorio efímero, SQLite no persistente y MFA desactivado: comprueba HTTP 200 JSON de `/api/health/` desde el **mismo contenedor**. Web arranca su entrypoint y se prueba HTTP local 80 mediante `wget` interno.

El criterio web presupone disponibilidad del cliente `wget` y escucha en 80; un FAIL no es corrupción, puede ser discrepancia del contrato HTTP y debe diagnosticarse antes de ajustar prueba. El test **no conecta API/Web entre sí**, ni PostgreSQL ni O5: B1 funcional completo y B2 siguen abiertos. No bajar protecciones para forzar un PASS.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4e_archived_api_web_isolated_http.sh
bash scripts/main_d4e_archived_api_web_isolated_http.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D4E_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

Buscamos: `D4E_UNIQUE_API_WEB_ROLES=PASS`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_HTTP_LOCAL=PASS`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=0`. En todo caso `D4E_REAL_O5_COMPATIBILITY_VERIFIED=NO` y `D4E_OPERATIONAL_ROLLBACK_VERIFIED=NO`.

## D4-E — Primer ensayo: API PASS, Web HTTP FAIL (11/11/2026)

Salida real: `D4E_UNIQUE_API_WEB_ROLES=PASS`, `D4E_API_START=PASS`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_START=PASS`, `D4E_WEB_HTTP_LOCAL=FAIL`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7`, `D4E_SHELL_RESULT=7`. El resultado de `systemctl is-active docker` está truncado en el mensaje; no atribuirlo. El cleanup sí reportó PASS. D4-E **no está superada**. La comprobación anterior depende de `wget` y puerto 80: no distingue fallo de cliente, servidor detenido, puerto/config distinto o respuesta HTTP no-2xx. No inventar causa, no degradar la prueba HTTP a PASS y no inferir corrupción del archivo.

Próxima actuación: diagnóstico **sanitizado dentro del mismo almacén efímero**, antes del cleanup, que distinga estado del contenedor, disponibilidad del cliente HTTP, validez de la configuración Nginx, socket HTTP y código de respuesta, sin emitir logs, metadatos ni cuerpos. Conservar aislamiento y exigir una respuesta HTTP verificable antes de pasar.

### Diagnóstico D4-E publicado

Commits `117adf64`, `0921152d`: cuando falle `WEB_HTTP_LOCAL`, el mismo ensayo emitirá antes de limpiar el estado del contenedor, disponibilidad de `wget`, resultado de `nginx -t`, posibles escuchas de TCP 80/8080 y código de respuesta HTTP observado. No expone logs, configuraciones ni cuerpos de respuesta; conserva exactamente el fallo `D4E_RESULT=7` si no hay HTTP satisfactorio. No cambia puertos, permisos, imágenes, red ni la condición PASS. El operador puede hacer una **única** reejecución para categorizar la causa. Si el diagnóstico identifica incompatibilidad del cliente `wget`, la próxima corrección debe utilizar una sonda adecuada independiente del servidor, no marcar PASS automáticamente.

### D4-E — segundo diagnóstico: Web termina antes de HTTP

Operador confirmó `D4E_API_START=PASS`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_START=PASS`, `D4E_WEB_CONTAINER_STILL_RUNNING=NO`, `D4E_WEB_HTTP_LOCAL=FAIL`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7`, `D4E_DIAGNOSTIC_RESULT=7`, Docker `active` y árbol Git limpio.

La sonda `wget` no explica el fallo: el proceso contenedor Web deja de ejecutarse. Commit `8ba5e8cc` añade únicamente **diagnóstico seguro tras la salida del proceso**: `WEB_EXIT_CODE`, `WEB_OOM_KILLED`, `WEB_EXIT_DIAGNOSIS` según patrones de logs (sin imprimir su contenido); todo se guarda y elimina dentro del workspace privado. El gate HTTP permanece FAIL si no responde, sin rebajar aislamiento.

Reejecutar D4-E una vez, ya con esta clasificación, para seleccionar una corrección basada en evidencia. No se ha identificado aún si es un problema de filesystem read-only, permisos, configuración, puertos u otra causa. No afirmar corrupción de imagen.

### D4-E — Causa clasificada: escritura contra filesystem read-only

Resultado del operador: `D4E_WEB_EXIT_CODE=1`, `D4E_WEB_OOM_KILLED=NO`, `D4E_WEB_EXIT_DIAGNOSIS=READONLY_FILESYSTEM`, `D4E_WEB_CONTAINER_STILL_RUNNING=NO`, `D4E_WEB_HTTP_LOCAL=FAIL`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7`. Se sabe que Nginx intenta escribir contra un sistema de archivos solo lectura, pero aún se desconoce la ruta exacta. No concluir fallo de imagen ni actualizar el gate a PASS.

Commits `ebd7333a`, `f712b9f1`: diagnóstico clasifica, solo a partir de líneas de error de lectura restringida, la **familia** de la ruta afectada (por ejemplo ETC_NGINX_CONF_D, VAR_CACHE_NGINX, VAR_RUN_NGINX, RUN_NGINX, VAR_LOG_NGINX o UNKNOWN) sin imprimir rutas completas ni registros. No cambia el modo read-only ni los límites del laboratorio. Hacer un único retest D4-E y revisar `D4E_WEB_READONLY_PATH_FAMILY` antes de añadir un tmpfs puntual; si es UNKNOWN, no improvisar un montaje sobre /etc/nginx.

No se han ejecutado despliegue, migraciones, restauración O5 ni rollback operativo.

### D4-E — Corrección acotada del arranque Nginx

El operador confirmó `D4E_WEB_EXIT_CODE=1`, `D4E_WEB_OOM_KILLED=NO`, `D4E_WEB_EXIT_DIAGNOSIS=READONLY_FILESYSTEM`, `D4E_WEB_READONLY_PATH_FAMILY=ETC_NGINX`, `D4E_WEB_HTTP_LOCAL=FAIL`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7` y `D4E_PATH_DIAGNOSTIC_RESULT=7`. Docker continúa `active` y el árbol Git limpio.

El archivo Nginx contiene configuración en `/etc/nginx`; ocultarlo con un `tmpfs` puede invalidar la configuración real. Para que la imagen original ejecute su entrypoint, commit `beb0637b` retira `--read-only` **solo del contenedor Web aislado**, permitiendo escribir únicamente en su capa rootfs VFS privada y eliminable; API sigue read-only. Se mantienen Podman rootless, `--network none`, `--security-opt no-new-privileges`, sin puertos, sin montajes, sin credenciales O5 y cleanup completo. La reducción del endurecimiento de rootfs se declara con `D4E_WEB_PRIVATE_EPHEMERAL_ROOTFS_WRITABLE=YES`: es una decisión del **laboratorio desechable**, no propuesta de configuración operativa.

**Nuevo ensayo pendiente de ejecución:** misma orden D4-E y `D4E_RESULT=0` solo si API y Web responden HTTP. Un PASS no demuestra endurecimiento read-only de Nginx, comunicación interna entre servicios, ni compatibilidad O5. No cambia ni autoriza despliegue.

### D4-E — Permisos de escritura resueltos; fallo de configuración (11/11/2026)

Operador: `D4E_WEB_PRIVATE_EPHEMERAL_ROOTFS_WRITABLE=YES`, `D4E_WEB_START=PASS`, `D4E_WEB_CONTAINER_STILL_RUNNING=NO`, `D4E_WEB_EXIT_CODE=1`, `D4E_WEB_OOM_KILLED=NO`, `D4E_WEB_EXIT_DIAGNOSIS=NGINX_CONFIGURATION`, `D4E_WEB_READONLY_PATH_FAMILY=UNKNOWN`, `D4E_WEB_HTTP_LOCAL=FAIL`, `D4E_RESULT=7`, `D4E_SHELL_RESULT=7`. El bloqueo previo del filesystem de solo lectura ya no es el diagnóstico dominante; la causa concreta de configuración no se conoce. Docker `active`.

Commit `5c4c143c`: añade solo un marcador de causa fija `D4E_WEB_NGINX_CONFIG_CAUSE` a partir de logs privados dentro del laboratorio (DNS upstream, endpoint inválido, TLS, sintaxis, include ausente, bind, template u otro). No imprime hostname, rutas, valores, ni contenido de logs, no altera configuración ni red, y mantiene FAIL hasta que HTTP pase. No adjudicar a DNS ni a certificados sin nueva evidencia.

Para el siguiente ensayo sincronizar `main` y ejecutar la misma D4-E una vez. Se reparará únicamente la causa clasificada; no cambiar permisos de Docker operativo, ni tocar DEV/O5.
