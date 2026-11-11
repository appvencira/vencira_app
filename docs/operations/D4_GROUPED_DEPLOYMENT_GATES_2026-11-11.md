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

### D4-E — DNS de upstream irresoluble: laboratorio interno de API + Web

El operador confirmó: `D4E_WEB_EXIT_CODE=1`, `D4E_WEB_OOM_KILLED=NO`, `D4E_WEB_EXIT_DIAGNOSIS=NGINX_CONFIGURATION`, `D4E_WEB_NGINX_CONFIG_CAUSE=UPSTREAM_DNS_UNRESOLVED`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7`, Docker `active`, Git limpio. El contenedor Web requiere resolución del hostname upstream configurado; `--network none` bloquea la resolución de nombres de servicio. Este es un fallo del diseño aislado, no prueba de imagen defectuosa.

Commit `71411071`: modifica exclusivamente D4-E para crear una red **Podman interna y privada** bajo el mismo almacenamiento VFS efímero, verifica `network inspect internal=true`, inicia API con alias `api` y Web con alias `web_preview`, sin puertos del host, sin Docker host, sin acceso a DEV, sin restauraciones O5. Ambos contenedores se eliminan antes de eliminar la red y el almacenamiento rootless. La red privada sustituye `--network none` para satisfacer el DNS de Compose, pero no permite egress exterior por `--internal`. No se ha verificado aún que el hostname concreto configurado en Web sea `api`; si no, se mantiene fallo sin degradar aislamiento.

Condiciones de aceptación: `D4E_INTERNAL_NETWORK_ISOLATION=PASS`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_HTTP_LOCAL=PASS`, `D4E_INTERNAL_NETWORK_REMOVED=YES`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=0`; la respuesta HTTP local no demuestra todavía proxy API↔Web íntegro ni O5.

### D4-E — Red interna creada, pero Podman rechaza arranque API (11/11/2026)

Resultados del operador: `D4E_INTERNAL_NETWORK_ISOLATION=PASS`, `D4E_ROOTLESS_IMAGE_IMPORT=PASS`, `D4E_IMPORTED_IMAGE_COUNT_3=PASS`, `D4E_UNIQUE_API_WEB_ROLES=PASS`, `D4E_API_START=FAIL`, `D4E_CONTAINER_RUN_EXECUTED=NO`, `D4E_INTERNAL_NETWORK_REMOVED=YES`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=6`, `D4E_SHELL_RESULT=6`; Docker `active`; árbol Git limpio. La ejecución HTTP Django previa con `--network none` fue PASS. No hay base para atribuir este fallo a Django, Web, datos o imagen.

Commit `cbce01a7`: el propio D4-E ahora clasifica `error.log` privado del intento fallido en el marcador `D4E_API_START_ERROR_CATEGORY`, sin emitir argumentos, identificadores, secretos, rutas ni errores textuales; distingue namespaces rootless, netavark/aardvark, firewall/nft, permisos, DNS, conflictos de nombres, almacenamiento o binario. Se conserva íntegramente la red interna, el almacenamiento VFS, la limpieza y el gate FAIL. **Pendiente de ejecutar en VPS**. No ajustar protecciones ni ejecutar Docker live hasta tener evidencia de la categoría.

### D4-E — Bridge rootless no disponible; alternativa de loopback compartido

El operador confirmó `D4E_API_START_ERROR_CATEGORY=ROOTLESS_NETWORK_NAMESPACE`, `D4E_API_START=FAIL`, `D4E_INTERNAL_NETWORK_REMOVED=YES`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=6`, `D4E_SHELL_RESULT=6`, con Docker `active` y git limpio. La red interna se creaba y verificaba, pero Podman no conseguía iniciar API al asociarla. Diagnóstico **categórico**, no se dispone del error literal; puede haber más de una causa dentro de la categoría.

Commit `75ec5ce0` elimina del **laboratorio únicamente** la dependencia del bridge rootless. API vuelve al `--network none` con que ya pasó HTTP; Web utiliza `--network container:<api>` para compartir el mismo namespace de loopback y `--add-host api:127.0.0.1` para resolver su upstream sin DNS ni salida externa. Se mantiene Podman VFS privado, sin publicación de puertos, sin Docker socket, sin datos O5, sin volúmenes DEV. No se presupone que la versión de Podman acepte la combinación de namespace de otro contenedor y `--add-host`; un eventual `WEB_START=FAIL` exigirá revisar esa compatibilidad, sin abrir red al exterior.

El marcador `D4E_ROOTLESS_BRIDGE_NETWORK_USED=NO` es esperado; `D4E_SHARED_LOOPBACK_NO_EGRESS=YES` es la restricción configurada, no un ensayo de comunicación externa. Continúan obligatorias `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_HTTP_LOCAL=PASS`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=0` antes de dar por superado D4-E. Un PASS no acredita todavía DB real O5 ni rollback. No desplegar.

### D4-E — Namespace compartido rechazado; prueba HTTP Web sin integración (11/11/2026)

El operador confirmó `D4E_ROOTLESS_BRIDGE_NETWORK_USED=NO`, `D4E_SHARED_LOOPBACK_NO_EGRESS=YES`, `D4E_API_START=PASS`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_START=FAIL`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7`, `D4E_SHELL_RESULT=7`, Docker `active` y Git limpio. Esta salida NO identifica el motivo preciso de rechazo de Web; la combinación `--network container:...` / `--add-host` sigue no validada en Podman rootless del VPS.

Commit `1377d029` elimina el intento de compartir namespace. API y Web arrancan cada uno con `--network none` como ya funcionó para API y los shells importados; Web añade únicamente `--add-host api:127.0.0.1` para que el upstream del nginx archivado pueda resolverse **durante el parseo de configuración**, sin conectar realmente Django a Web ni permitir salida externa. No se utiliza bridge, puertos publicados, socket Docker, credenciales O5 ni volúmenes DEV. `D4E_API_WEB_CROSS_CONTAINER_CONNECTIVITY_VERIFIED=NO` se declara expresamente. El éxito de Web HTTP demostraría solo **servidor estático local**; no cerraría prueba de API+Web integrados, ni B1/B2 de recuperación real.

Próximo ensayo con el script corregido: buscar `D4E_WEB_UPSTREAM_NAME_SYNTHETIC_HOSTS=YES`, `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_HTTP_LOCAL=PASS`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES` y `D4E_RESULT=0`. No repetir el camino de bridge rootless salvo que se solucione de forma comprobable fuera del entorno DEV; la integración completa puede usar el laboratorio Docker interno ya históricamente verificado, manteniendo O5 y producción separados.

### D4-E — Configuración Nginx y escucha TCP 8080 verificadas (11/11/2026)

El operador confirmó `D4E_API_HEALTH_HTTP=PASS`, `D4E_WEB_START=PASS`, `D4E_WEB_CONTAINER_STILL_RUNNING=YES`, `D4E_WEB_WGET_AVAILABLE=YES`, `D4E_WEB_NGINX_CONFIG_TEST=PASS`, `D4E_WEB_TCP80_LISTEN=NOT_VERIFIED`, `D4E_WEB_TCP8080_LISTEN=YES`, `D4E_WEB_HTTP80_WGET_EXIT=FAILURE`, `D4E_WEB_HTTP80_RESPONSE_CODE=NOT_OBSERVED`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=7` y `D4E_SHELL_RESULT=7`. El contenedor Web **sí permanece vivo** y escucha TCP 8080; el gate fallaba al probar TCP 80 por una suposición de puerto no sustentada.

Commit `f2c442a2` cambia exclusivamente las dos solicitudes HTTP Web del script para apuntar a `http://127.0.0.1:8080/`, con marcadores de diagnóstico `D4E_WEB_HTTP8080_WGET_EXIT` y `D4E_WEB_HTTP8080_RESPONSE_CODE`. No cambia la configuración Nginx, archivos, host, red, montaje, imagen ni criterio de éxito HTTP. Pendiente de ejecutar de nuevo y observar `D4E_WEB_HTTP_LOCAL=PASS`, `D4E_EPHEMERAL_STORAGE_REMOVED=YES`, `D4E_RESULT=0`. La conexión API↔Web real, PG17/O5 y rollback operativo continúan expresamente **NO VERIFICADOS**.

## D4-E PASS confirmado (11/11/2026)

```text
D4E_MAIN_SYNC=PASS
D4E_ARCHIVE_CHECKSUM=PASS
D4E_ROOTLESS_IMAGE_IMPORT=PASS
D4E_IMPORTED_IMAGE_COUNT_3=PASS
D4E_UNIQUE_API_WEB_ROLES=PASS
D4E_API_START=PASS
D4E_API_HEALTH_HTTP=PASS
D4E_WEB_START=PASS
D4E_WEB_HTTP_LOCAL=PASS
D4E_NO_EXTERNAL_NETWORK=YES
D4E_NO_HOST_DOCKER_SOCKET=YES
D4E_API_WEB_ISOLATED_RUNTIME=PASS
D4E_API_WEB_CROSS_CONTAINER_CONNECTIVITY_VERIFIED=NO
D4E_DATABASE_INTEGRATION_VERIFIED=NO
D4E_REAL_O5_COMPATIBILITY_VERIFIED=NO
D4E_EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED=NO
D4E_OFF_HOST_COPY_VERIFIED=NO
D4E_OPERATIONAL_ROLLBACK_VERIFIED=NO
D4E_EPHEMERAL_STORAGE_REMOVED=YES
D4E_RESULT=0
D4E_SHELL_RESULT=0
```

Docker `active`; Git limpio. **Cerrado el gate D4-E para HTTP independiente de API y Web archivadas**. Nginx escucha 8080. No extrapolar este PASS a comunicación conjunta o recuperación de PostgreSQL/O5.

## D4-F — Stack sintético conectado (preparado; pendiente en VPS)

Se publican `scripts/main_d4f_synthetic_host_images_connected_internal.sh` y el marcador exacto `D4F_CONTAINER_RUN_EXECUTED`. Usan **identificadores de imagen retenidos en images.manifest y presentes en Docker host**, contrastándolos con los tres contenedores DEV antes y después; **no** cargan el archivo a Docker host ni prueban equivalencia exacta entre SHA de config archivada e ID Docker. Es un ensayo aislado de integración de las imágenes del host, no de restauración ejecutable desde el archivo exportado.

El laboratorio crea una red `docker network create --internal` efímera, PG17 en tmpfs sin persistencia, credenciales sintéticas, API Django con `VENCIRA_ENV=test` y MFA no habilitado, Web Nginx escuchando 8080. Comprueba `pg_isready`, HTTP 200 JSON en `/api/ready/` (Django consultando PG17), HTTP Web local, y HTTP directo Web→API usando DNS de la red interna. No publica puertos, no monta carpetas o volúmenes DEV, no usa O5, no ejecuta migraciones, no realiza despliegue. Finalmente elimina los tres contenedores, la red y los secretos temporales, comparando los IDs inmutables de los tres contenedores DEV. Su ejecución sobre host Docker es **laboratorio aislado controlado**, no rootless Podman; exige `sudo -v` previo.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4f_synthetic_host_images_connected_internal.sh
echo "D4F_SYNTAX=$?"
sudo -v
bash scripts/main_d4f_synthetic_host_images_connected_internal.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D4F_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

Buscamos `D4F_PG17_READY=PASS`, `D4F_DJANGO_PG17_READY_HTTP=PASS`, `D4F_WEB_HTTP_8080=PASS`, `D4F_WEB_TO_API_PRIVATE_HTTP=PASS`, `D4F_NO_HOST_PORTS=PASS`, `D4F_DEV_CONTAINERS_UNCHANGED=YES`, `D4F_EPHEMERAL_CLEANUP=DONE`, `D4F_RESULT=0`. Esta prueba **no** certifica reverse proxy end-to-end ni restauración O5 ni rollback operativo. Si falla una etapa, no reproducir ni modificar DEV; analizar el marcador antes de cualquier corrección.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D4F_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D4F_REAL_O5_COMPATIBILITY_VERIFIED=NO
```

## D4-F PASS confirmado y D4-G preparado (11/11/2026)

Confirmación de operador en D4-F: `D4F_MAIN_CLEAN=PASS`, `D4F_ARCHIVE_CHECKSUM=PASS`, `D4F_LIVE_IMAGE_IDENTITY=PASS`, `D4F_INTERNAL_NETWORK=PASS`, `D4F_PG17_READY=PASS`, `D4F_DJANGO_PG17_READY_HTTP=PASS`, `D4F_WEB_HTTP_8080=PASS`, `D4F_WEB_TO_API_PRIVATE_HTTP=PASS`, `D4F_NO_HOST_PORTS=PASS`, `D4F_SYNTHETIC_PG17_DJANGO_WEB_INTERNAL_NETWORK=PASS`, `D4F_DEV_CONTAINERS_UNCHANGED=YES`, `D4F_EPHEMERAL_CLEANUP=DONE`, `D4F_RESULT=0`. El `echo "D4F_SHELL_RESULT=$?"` aparece intercalado en el pegado pero no el valor resultante; no se inventa. D4-F acredita **comunicación privada real Web→Django→PG17 con DB sintética**, usando las **imágenes retenidas en Docker host**. No carga el archivo archivado; el hash exacto de la configuración exportada sigue sin reconciliarse.

D4-G publicado en `scripts/main_d4g_synthetic_reverse_proxy_pg17.sh`: reproduce el ensayo aislado del host Docker con red `--internal`, base PG17 exclusivamente en tmpfs, credenciales sintéticas, contenedores DEV intocados, sin host ports ni migraciones operativas. Añade una prueba estricta a través de **Nginx mismo**: HTTP a `127.0.0.1:8080/api/ready/` desde Web y validación privada de JSON `{"status":"ready"}`, que solo responde 200 cuando Django consulta correctamente PostgreSQL. No imprime cuerpos, credenciales ni configuración. La URL es local al contenedor Web y no pasa por el Caddy operativo. El reverse proxy de Web sólo se considerará verificado si `D4G_WEB_REVERSE_PROXY_HTTP=PASS`, `D4G_WEB_REVERSE_PROXY_JSON=PASS`, `D4G_WEB_REVERSE_PROXY_PATH_VERIFIED=YES`, `D4G_DEV_CONTAINERS_UNCHANGED=YES`, `D4G_EPHEMERAL_CLEANUP=DONE`, `D4G_RESULT=0`. **No ejecutado todavía en VPS.**

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4g_synthetic_reverse_proxy_pg17.sh
echo "D4G_SYNTAX=$?"
sudo -v
bash scripts/main_d4g_synthetic_reverse_proxy_pg17.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D4G_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

Lo aún abierto tras D4-F: **B1** recuperación operacional *desde* el archivo (no solo imágenes ya presentes); **B2** restauración O5 real y compatibilidad en el mismo laboratorio conectado; **B3** custodia off-host cifrada y verificación de recuperación; **B4** regresión final integrada en main; **B5** controles TLS, dominio y autorización pública. No mezclar los resultados de D4-F/G con el cierre de B1/B2.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D4F_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D4F_REAL_O5_COMPATIBILITY_VERIFIED=NO
D4F_OPERATIONAL_ROLLBACK_VERIFIED=NO
```

## D4-G PASS confirmado (11/11/2026)

El operador confirmó `D4G_MAIN_CLEAN=PASS`, `D4G_ARCHIVE_CHECKSUM=PASS`, `D4G_LIVE_IMAGE_IDENTITY=PASS`, `D4G_INTERNAL_NETWORK=PASS`, `D4G_PG17_READY=PASS`, `D4G_DJANGO_PG17_READY_HTTP=PASS`, `D4G_WEB_HTTP_8080=PASS`, `D4G_WEB_TO_API_PRIVATE_HTTP=PASS`, `D4G_NO_HOST_PORTS=PASS`, `D4G_WEB_REVERSE_PROXY_HTTP=PASS`, `D4G_WEB_REVERSE_PROXY_JSON=PASS`, `D4G_WEB_REVERSE_PROXY_PATH_VERIFIED=YES`, `D4G_DEV_CONTAINERS_UNCHANGED=YES`, `D4G_EPHEMERAL_CLEANUP=DONE`, `D4G_RESULT=0`. D4G confirma Web Nginx→Django→PG17 **con datos sintéticos**, empleando imágenes ya presentes en Docker. El texto recibido está truncado antes del eco del exit shell; `D4G_SHELL_RESULT` no se presupone.

## D4-H — Ensayo O5 real con las imágenes retenidas en Docker (preparado; no ejecutado)

Se publica `scripts/main_d4h_retained_images_real_o5_pg17_isolated.sh` derivado del procedimiento exitoso D1-N, sin reconstruir imágenes. Selecciona con criterio de edad y etiqueta el snapshot PostgreSQL de restic O5, usa `restic --no-lock dump` directamente por streaming hacia `pg_restore` dentro de un PostgreSQL 17 efímero en red Docker `--internal`, con PGDATA en tmpfs y sin puertos, volúmenes ni montaje persistente. Verifica identidad de las tres imágenes retenidas en host Docker mediante `images.manifest`, y ejecuta `manage.py check`, paridad de modelos, migración 0019–0027 y rollback de migraciones a 0018 **solo dentro del laboratorio**, usando la imagen API retenida. Comprueba recuentos de entidades antes y después sin imprimir valores, elimina contenedor/red y verifica que los tres contenedores DEV siguen intactos. Secretos O5 accesibles solo mediante `sudo`, nunca se imprimen.

**Alcance limitado:** este ensayo **no restaura las imágenes desde el tar** a un runtime nuevo y no demuestra que el export sea equivalente al ID Docker original; tampoco prueba Web contra datos reales O5. Demuestra compatibilidad de los dos componentes **ya retenidos en Docker host** con la restauración histórica real en un laboratorio aislado. No cerrar B1 ni B2 completos con ese resultado; tampoco arregla la discrepancia D3-B3.

**Ejecutar solo tras revisar el script root y comprobar sintaxis:**

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4h_retained_images_real_o5_pg17_isolated.sh
echo "D4H_SYNTAX=$?"
sudo -v
sudo bash scripts/main_d4h_retained_images_real_o5_pg17_isolated.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D4H_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

Condiciones relevantes: `D4H_RESTORE_REAL_O5_PG17=PASS`, `D4H_HOST_IMAGE_IDENTITY=PASS`, `D4H_MIGRATIONS_0019_0027=PASS`, `D4H_ROLLBACK_TO_0018=PASS`, `D4H_DEV_CONTAINERS_UNCHANGED=OK`, `D4H_RESULT=0`. Los marcadores `D4H_LIVE_RESTORE_EXECUTED=NO`, `D4H_LIVE_MIGRATIONS_EXECUTED=NO`, `D4H_ARCHIVE_EXPORT_EXECUTABLE_EQUIVALENCE_VERIFIED=NO` deben permanecer en su estado restrictivo.

## D4-H — Restauración O5 PASS, plan de migraciones FAIL (11/11/2026)

El operador ejecutó `sudo bash scripts/main_d4h_retained_images_real_o5_pg17_isolated.sh` y confirmó `D4H_SYNTAX=0`, `D4H_ARCHIVE_CHECKSUM=PASS`, `D4H_ARCHIVE_MANIFEST=PASS`, `D4H_CONFIG_MATCH=PASS`, `D4H_DEV_IDENTITY=PASS`, `D4H_HOST_IMAGE_IDENTITY=PASS`, `D4H_RECENT_POSTGRESQL_SNAPSHOT=PASS`, `D4H_LAB_NETWORK_INTERNAL=PASS`, `D4H_PG17_NETWORK_ISOLATED=PASS`, `D4H_PG17_TMPFS_READY=PASS`, `D4H_RESTORE_REAL_O5_PG17=PASS`, `D4H_HISTORICAL_0018=PASS`, `D4H_BASELINE_COUNTS=PASS`, `D4H_MODEL_MIGRATION_PARITY=PASS` y **`D4H_MIGRATION_PLAN=FAIL`**. `D4H_DEV_CONTAINERS_UNCHANGED=OK`, `D4H_LAB_CONTAINER_REMOVED=YES`, `D4H_REAL_O5_DATA_OUTPUT_PRINTED=NO` y `D4H_RESULT=8`. El resultado del `echo D4H_SHELL_RESULT` no consta en el fragmento recibido.

**Interpretación estricta:** backup real O5 restaurado correctamente a PG17 con imagen retenida en host Docker y datos iniciales accesibles. No hay evidencia de que la base operativa se haya modificado. El plan `migrate reminders 0027 --plan` falló en Django antes de ejecutar migraciones de ensayo; NO se acredita compatibilidad hasta 0027, ni rollback, ni B2 completo. La hipótesis de imagen Django retenida con migraciones anteriores a 0027 necesita verificación: `makemigrations --check --dry-run` PASS no acredita que exista 0027.

Se publica `scripts/main_d4h_image_migration_inventory_readonly.sh` (commits `c67b2a07`, `149f7cfa`). Compara los **números** de migraciones presentes en la imagen API retenida contra el árbol `main`, ejecutando solo un Python en contenedor `--network none --read-only --rm`; sin acceso a DB ni O5, sin imprimir el inventario de archivos. Señala presencia de 0018, 0027 y completitud 0019–0027, además de un máximo numérico. `D4H2_RESULT=0` indica que la inspección concluyó, **no** que las migraciones coincidan: revisar `D4H2_IMAGE_MAIN_NUMBERED_MIGRATION_PARITY` y `D4H2_MIGRATION_PLAN_FAILURE_EXPLAINED_BY_MISSING_TARGET`.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4h_image_migration_inventory_readonly.sh
sudo -v
bash scripts/main_d4h_image_migration_inventory_readonly.sh
echo "D4H2_SHELL_RESULT=$?"
git status --short
```

**No repetir la restauración real O5** hasta resolver la diferencia de migraciones y no reconstruir/reemplazar el archivo archivado para forzar un PASS. Se mantiene `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D4-H2 — causa confirmada de fallo de migración (11/11/2026)

Operador confirmó `D4H2_API_IMAGE_IDENTIFIED=PASS`, `D4H2_IMAGE_0018_PRESENT=YES`, `D4H2_IMAGE_0027_PRESENT=NO`, `D4H2_IMAGE_0019_0027_COMPLETE=NO`, `D4H2_IMAGE_MAX_MIGRATION_NUMBER=18`, `D4H2_MAIN_0018_PRESENT=YES`, `D4H2_MAIN_0027_PRESENT=YES`, `D4H2_MAIN_0019_0027_COMPLETE=YES`, `D4H2_MAIN_MAX_MIGRATION_NUMBER=27`, `D4H2_IMAGE_MAIN_NUMBERED_MIGRATION_PARITY=FAIL`, `D4H2_MIGRATION_PLAN_FAILURE_EXPLAINED_BY_MISSING_TARGET=YES`, `D4H2_O5_REAL_RESTORE_REEXECUTED=NO`, `D4H2_DEV_CONTAINERS_MODIFIED=NO`, `D4H2_RESULT=0`. No consta eco separado `D4H2_SHELL_RESULT` en el mensaje pegado.

**Causa raíz demostrada:** la imagen histórica API retenida en Docker solo incorpora hasta `reminders.0018`; el ensayo D4-H le exigía `migrate reminders 0027 --plan`, imposible al faltar 0027. Una prueba de modelo/paridad con `makemigrations --check` no acreditaba presencia del fichero `0027`. La discrepancia es **entre versiones de código**; no se atribuye corrupción de O5 ni de las imágenes exportadas.

**Dos rutas distintas:**
1. **Recuperación histórica**: DB O5 restaurada con imagen PostgreSQL retenida y el Django histórico 0018, sin pedir migraciones posteriores; D4-H ya verificó restauración real, recuentos y comprobaciones Django. No se ha demostrado todavía un flujo completo de operaciones de usuario tras recuperar el archivo.
2. **Actualización de esquema**: usar imagen candidata con código de `main` (hasta 0027), y migraciones solamente en PG17 de laboratorio. D1-N ya registró prueba histórica de 0019–0027 con rollback. No sustituir en secreto la imagen retenida 0018 por una construida a partir de `main` para declarar recuperación binaria del archivo.

Corrección preventiva de D4-H en commits `83f81a29` y `8a381292`: un preflight sin red ni acceso a O5 inspecciona los archivos de migración de la imagen retenida antes de leer las credenciales de backup o recuperar datos. Si no existe `0027`, emite `D4H_TARGET_0027_PRESENT_IN_RETAINED_API=FAIL`, `D4H_O5_CREDENTIALS_ACCESSED=NO`, `D4H_REAL_O5_RESTORE_REEXECUTED=NO`, `D4H_MIGRATION_PLAN=PRECHECK_BLOCKED` y `D4H_RESULT=8`. **No se debe repetir D4-H**: el diagnóstico ya ha demostrado que el preflight lo bloqueará. La guarda conserva el procedimiento histórico, pero evita un costoso restore innecesario.

B1 (rehidratar y ejecutar imágenes exportadas en un runtime independiente), B2 (compatibilidad integral real O5 con el ejecutable recuperado, y protocolo reversible), B3 (custodia cifrada fuera del VPS), B4 (regresión final) y B5 (producción/autorización) siguen abiertos. El antiguo hash mismatch de D3-B3 continúa sin cerrar.

## D5 — Fase agrupada de aceleración de publicación (11/11/2026)

**Decisión:** no repetir los ensayos D4-E/F/G de integración sintética, ni la restauración O5 D4-H que ya recuperó datos y falló únicamente al intentar exigir migraciones 0027 a una imagen histórica terminada en 0018. D4-H2 confirmó la causa. Priorizar una ejecución de regresión candidata de `main` seguida de un informe único de bloqueos.

**Nuevo script:** `scripts/main_d5_grouped_final_candidate_regression.sh` (commit `5ae2913f`). Verifica `main` sincronizada y limpia, archivo privado y SHA256, y ejecuta una sola vez el procedimiento existente `scripts/main_d1o_candidate_integral_gate.sh`. Este crea su propia red Docker interna y PostgreSQL sintético en tmpfs, construye una **imagen candidata nueva desde main**, ejecuta `Django check --deploy`, integridad de migraciones, migraciones de laboratorio, pruebas HTTP/seguridad/Django, y Flutter `pub get`, `analyze`, `test`, `build web` en una copia temporal. El gate D1-O ya contiene cleanup y comprobación de IDs de contenedores DEV. No reescribe imágenes archivadas ni utiliza credenciales/restauración O5.

El script D5 **no despliega ni aprueba publicación**. Si D1-O falla, `D5_CANDIDATE_REGRESSION=FAIL`, `D5_RESULT=5`; si D1-O supera los ensayos, `D5_CANDIDATE_REGRESSION=PASS`, `D5_B4_MAIN_DJANGO_FLUTTER_SYNTHETIC_GATE=PASS`, pero `D5_RESULT=4` y `D5_RELEASE_READINESS=BLOCKED` permanecen porque B1/B2/B3/B4 nativo/B5 y la discrepancia D3-B3 no están cerrados. No interpretar código 4 como error técnico de tests: es denegación intencional de autorización operativa.

### Orden única de ejecución D5

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d5_grouped_final_candidate_regression.sh
echo "D5_SYNTAX=$?"
sudo -v
bash scripts/main_d5_grouped_final_candidate_regression.sh
echo "D5_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

### Plan de cierre sin falsos positivos

- **B1**: recuperación desde imágenes del archivo en un almacén independiente, con servicios y datos de laboratorio ejecutándose conjuntamente; los hashes de configuración del tar no equivalen actualmente a los IDs originales de Docker/Containerd.
- **B2**: restaurar O5 real en laboratorio funcional con un ejecutable compatible. La imagen histórica `0018` no debe realizar migraciones `0027`; la imagen nueva de `main` se prueba por separado para la actualización. Requiere rollback reversible ensayado.
- **B3**: copia **cifrada y externa al VPS** del archivo completo + verificación de integridad y ejercicio de recuperación desde destino externo. Tener el archivo local y O5 DB en Google Drive no demuestra custodia externa de las imágenes.
- **B4**: candidato `main` Django/Flutter con D5 y, todavía, Android nativo/HTTPS/seguridad del candidato final. El PASS de un build web no equivale a APK final validada.
- **B5**: configuración pública de `vencira.es` (DNS, TLS, Caddy, CSRF, cookies, rollback operativo), aprobación expresa y ventana de despliegue. El preflight DEV de `dev.vencira.es` no suple estos controles.

Hasta autorización explícita: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D5_DEPLOY_EXECUTED=NO`, `D5_LIVE_RESTORE_EXECUTED=NO`, `D5_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO`.

## D5 — Regresión candidata PASS; liberación sigue BLOQUEADA (11/11/2026)

El operador confirmó `D5_SYNTAX=0`, `D5_MAIN_CLEAN=PASS`, `D5_ARCHIVE_CHECKSUM=PASS`, `D5_CANDIDATE_SCRIPT_SYNTAX=PASS`, `D1O_DEV_IDENTITY=PASS`, `D1O_INTERNAL_NETWORK=PASS`, `D1O_PG17_SYNTHETIC_TMPFS=PASS`, `D1O_CANDIDATE_IMAGE_BUILD=PASS`, `D1O_DJANGO_DEPLOY_CHECK=PASS`, `D1O_MODEL_PARITY=PASS`, `D1O_SYNTHETIC_MIGRATIONS=PASS`, `D1O_SECURITY_HTTP_CONTRACT=PASS`, `D1O_DJANGO_REMINDERS_SUITE=PASS`, `D1O_FLUTTER_ANALYZE_TEST_WEB_BUILD=PASS`, `D1O_CANDIDATE_INTEGRAL_GATE=PASS`, `D1O_DEV_CONTAINERS_UNCHANGED=OK`, `D1O_EPHEMERAL_CLEANUP=DONE`, `D1O_RESULT=0`, `D5_CANDIDATE_REGRESSION=PASS`, `D5_B4_MAIN_DJANGO_FLUTTER_SYNTHETIC_GATE=PASS`, `D5_BLOCKERS_OPEN=5`, `D5_RELEASE_READINESS=BLOCKED`, `D5_RESULT=4`. El texto intercalado de comandos oculta `D5_SHELL_RESULT`, no se inventa su eco. El aviso Flutter Wasm dry-run no es un test fallido.

**Decisión:** cierre de **B4 backend + Flutter web sintéticos** para el candidato `main` probado. **B4 nativo Android / APK y dispositivo físico pendientes**. B1 export real independiente, B2 acoplamiento O5+imagen exportada, B3 custodia off-host cifrada, B5 TLS/dominio de producción y aprobación, así como discrepancia de hashes D3-B3, siguen abiertos.

El siguiente bloque debe priorizar evidencias no repetidas y no repetir D4-E/F/G ni D5. `D5_RESULT=4` significa denegación de publicación por condiciones abiertas, no regresión fallida. No generar un release nuevo ni alterar la base viva antes del gate B1/B2/B3/B5 y aprobación expresa.

## D6 — Auditoría agrupada posterior al PASS de D5 (11/11/2026)

**Objetivo:** ejecutar un solo procedimiento **read-only** que contraste los bloqueos actuales sin reconstruir Django/Flutter, reejecutar D4-E/F/G ni volver a leer/restaurar O5. Script `scripts/main_d6_grouped_release_blocker_audit.sh`, commit `8c1c86ab`. Requiere `main` actualizada y limpia, archivo local y SHA256 válido, y sudo ya autenticado; no expone IDs, rutas privadas, secretos o contenido de backup.

Efectúa:
- Verificación offline D3-B3 de hashes de configuración Docker exportados y clasificación de la discrepancia como `UNRESOLVED` si no pasa (no modifica el archivo original).
- Lectura D3-B7 del encadenamiento imagen/manifest/servicios DEV, además del inventario D3-B de volumen de PostgreSQL e imágenes disponibles.
- Preflight HTTPS de **DEV** Caddy y conexión HTTPS a `https://vencira.es/` con TLS verificado, sin imprimir página, cabeceras, cookies, DNS/IP o certificados. El estado `D6_PUBLIC_APEX_TLS_HTTP_REACHABLE=YES` indica **únicamente** HTTP/TLS de la raíz, no configuración del backend de producción.
- Resumen separado de B1–B5 con flags restrictivos. Un `D6_RESULT=4` final significa que quedan bloqueos de publicación, **no** que fallen todos los controles.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d6_grouped_release_blocker_audit.sh
echo "D6_SYNTAX=$?"
sudo -v
bash scripts/main_d6_grouped_release_blocker_audit.sh
echo "D6_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

**Próxima fase de cierre**, en lugar de más regresiones sintéticas: B1 y discrepancia D3-B3; B2 compatibilidad O5 con versión histórica, sin imponer migración 0027 a imagen 0018; B3 custodia off-host cifrada, integridad y recuperación real; B4 APK Android y validación nativa; B5 HTTPS/CSRF/cookies/dominio de publicación, plan operativo reversible y aprobación explícita. No afirmar preparación pública basándose únicamente en una respuesta HTTPS 200.

La regresión D5 fue `PASS` para Django/PG17/Flutter web del `main` candidato probado; `D5_RESULT=4` proviene de los bloqueos. Continúan `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D6 ejecutada — D7 diagnóstico conjunto de las dos causas pendientes (11/11/2026)

Operador confirmó `D6_MAIN_CLEAN=PASS`, `D6_ARCHIVE_CHECKSUM=PASS`, `D6_ARCHIVE_CONFIG_IDS_FROM_D3B3=UNRESOLVED`, `D6_RUNNING_MANIFEST_IMAGE_ID_CHAIN=PASS`, `D6_ROLLBACK_BASELINE_INVENTORY=PASS`, `D6_DEV_CADDY_HTTPS_PREFLIGHT=PASS`, `D6_PUBLIC_APEX_TLS_HTTP_REACHABLE=NO`, `D6_B1_ARCHIVE_EXACT_ID_AND_RUNTIME_RECOVERY=VERIFIED_NO`, `D6_B2_EXPORT_RESTORED_IMAGE_REAL_O5_END_TO_END=VERIFIED_NO`, `D6_B3_OFF_HOST_ENCRYPTED_IMAGE_CUSTODY=VERIFIED_NO`, `D6_B4_MAIN_DJANGO_FLUTTER_WEB_D5_HISTORICAL=PASS_RECORDED`, `D6_B4_ANDROID_FINAL_APK_AND_DEVICE=VERIFIED_NO`, `D6_B5_PRODUCTION_CADDY_LOADED_CONFIG_COOKIES_CSRF=VERIFIED_NO`, `D6_B5_PUBLIC_APPROVAL=NO`, `D6_BLOCKERS_OPEN=5`, `D6_RELEASE_READINESS=BLOCKED`, `D6_RESULT=4`. El eco de salida del shell no se observa en la salida recibida.

Los dos problemas concretos sin clasificar son: (a) ID de configuración en el archivo frente a IDs Docker retenidos, aun con SHA256, blobs y ejecución de imágenes aisladas verificadas; (b) HTTPS de dominio público apex no alcanzó el criterio del script D6, cuya causa real no se conoce (DNS, TCP, TLS o respuesta HTTP).

**D7, prueba de causa raíz de una sola ejecución**, `scripts/main_d7_archive_tls_root_cause_readonly.py`, commits `6f8848d5` y `4ff63feb`. Comprueba otra vez checksum, pero no arranca contenedores, lee secretos ni restaura O5; utiliza D3-B3 y D3-B4 preexistentes para emitir solamente marcadores de comparación por rol, sin hashes o metadatos originales; DNS de `vencira.es` solo como booleano; curl con TLS verificado y sin imprimir datos de respuesta, direcciones IP, cabeceras o contenidos, emitiendo categoría del error, código de salida y estatus HTTP.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -m py_compile scripts/main_d7_archive_tls_root_cause_readonly.py
sudo -v
python3 scripts/main_d7_archive_tls_root_cause_readonly.py
echo "D7_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

Se espera `D7_RESULT=4` mientras siga la prohibición pública; el diagnóstico solo es válido si los marcadores intermedios se emiten. Un TLS satisfactorio en apex no acredita cookies/CSRF, proxy Django, MFA ni aprobación. Una coincidencia parcial de rootfs tampoco acredita identidad exacta de la exportación. No repetir D5 ni D4-H por estos motivos. Se mantiene `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D7 — Diagnóstico confirmado; D8 transporte público agrupado (11/11/2026)

Operador confirmó `D7_MAIN_CLEAN=PASS`, `D7_ARCHIVE_SHA256=PASS`, `D7_ARCHIVE_CONFIG_HASH_INTEGRITY=PASS`, `D7_ARCHIVE_MANIFEST_IMAGE_ID_MATCH=UNRESOLVED`; los tres `D7_CONFIG_ID_API/DB/WEB_MATCH=NO`, `D7_ARCHIVE_OFFLINE_CHECK_RESULT=3`. El comparador de configuración/rootfs D3-B4 terminó `D7_ARCHIVE_ROOTFS_CHECK_RESULT=0`: exactamente una coincidencia rootfs+plataforma para API, DB y Web, con 6/7/8 campos de configuración de runtime comparados respectivamente y **cero diferencias** en los comparados. **No** es identidad exacta de imagen. El export OCI conserva capas y ejecución en lo observado, pero los SHA de config no son los IDs retenidos en Docker host. Se debe mantener el archivo histórico y estudiar la conversión/normalización OCI sin sustituirlo o alterar el inventario.

`D7_APEX_DNS_RESOLVES=YES`, `D7_APEX_CURL_EXIT=35`, `D7_APEX_HTTP_STATUS=000`, `D7_APEX_TLS_VERIFY_CODE=1`, `D7_APEX_TRANSPORT_CLASS=TLS_HANDSHAKE_FAILURE`, `D7_APEX_HTTPS_ACCEPTED=NO`, `D7_RESULT=4`, `D7_SHELL_RESULT=4`. Docker `active`, Git limpio. Curl falla antes de recibir HTTP en el dominio público; `ssl_verify_result=1` en un handshake fallido no identifica por sí mismo un defecto de certificado. DNS sí resolvió; no se ha identificado la causa TCP/TLS definitiva.

**D8**: script `scripts/main_d8_public_tls_transport_split_readonly.py` (commits `63cba41f`, `94d04841`), sin root, sudo, Docker, O5, cambios Caddy ni secretos. Revisa IPv4 e IPv6 separadamente en `dev.vencira.es` y `vencira.es` y compara `curl` HTTPS con verificación TLS, más `openssl s_client -brief` con SNI para TLS1.2 y TLS1.3; no imprime DNS, IP, certificados, cabeceras ni respuesta. Emite categorías de error (EOF, reset, handshake rechazado, versión, connect, timeout), no el texto sin filtrar. Es una única prueba de transporte, no un deploy. `D8_RESULT=4` sigue siendo bloqueo deliberado. No inferir alcance completo de Caddy, CSRF ni cookies aunque una de las variantes TLS funcione.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -m py_compile scripts/main_d8_public_tls_transport_split_readonly.py
echo "D8_SYNTAX=$?"
python3 scripts/main_d8_public_tls_transport_split_readonly.py
echo "D8_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

El siguiente cambio operativo debe responder a un fallo concreto de transporte verificado; no modificar firewall, Caddy, DNS ni producción a ciegas. Siguen pendientes B1 identidad/export y recuperación, B2 O5 integrado, B3 custodia off-host, B4 Android final, B5 publicación y permiso expreso.

## D8 — TLS DEV sano, apex IPv4 reset; D9 host/DNS/Caddy (11/11/2026)

El operador confirmó `D8_MAIN_CLEAN=PASS`, `D8_DEV_DNS_IPV4=YES`, `D8_DEV_DNS_IPV6=NO`, `D8_DEV_IPV4_CURL_EXIT=0`, `D8_DEV_IPV4_HTTP_STATUS=200`, `D8_DEV_IPV4_TLS_VERIFY_CODE=0`, `D8_DEV_TLS12_OPENSSL=HANDSHAKE_OK`, `D8_DEV_TLS13_OPENSSL=HANDSHAKE_OK`; `D8_APEX_DNS_IPV4=YES`, `D8_APEX_DNS_IPV6=NO`, `D8_APEX_IPV4_CURL_EXIT=35`, `D8_APEX_IPV4_HTTP_STATUS=000`, `D8_APEX_IPV4_TLS_CLASS=TLS_PEER_RESET`, `D8_APEX_TLS12_OPENSSL=OTHER_OR_UNCLASSIFIED`, `D8_APEX_TLS13_OPENSSL=TCP_REFUSED`, `D8_RESULT=4` y `D8_SHELL_RESULT=4`. Docker `active` y Git limpio. La falta de IPv6 también afecta a DEV y **no explica** por sí sola el fallo exclusivo de apex. El handshake falla antes de HTTP y de cualquier control Django/CSRF/cookies. No se concluye aún si apex resuelve a otro destino, si falla el enrutamiento/filtrado externo o si el Caddy activo carece de host TLS para apex.

**D9** `scripts/main_d9_apex_dns_caddy_sni_readonly.py` (commit `1c5ca23e`) compara los conjuntos de destinos IPv4 de apex y DEV **sin imprimir las IP**, inspecciona (si disponible) la configuración activa de Caddy mediante Admin API local en modo GET solo para identificar rutas explícitas de ambos dominios, y prueba HTTPS con SNI validado contra loopback Caddy usando curl `--resolve hostname:443:127.0.0.1`. Es solo lectura: no imprime material TLS, respuesta HTTP, secretos, configuración o direcciones; no modifica DNS, Caddy, Docker ni el proxy. La presencia de una ruta Caddy no acredita su estado real, y la ausencia de coincidencia explícita puede deberse a un catch-all: no marcarlo como causa definitiva sin más evidencia.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -m py_compile scripts/main_d9_apex_dns_caddy_sni_readonly.py
echo "D9_SYNTAX=$?"
python3 scripts/main_d9_apex_dns_caddy_sni_readonly.py
echo "D9_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

**No repetir D4–D8 ni modificar la configuración pública a ciegas.** D9 categoriza cuál de DNS, ruta Caddy local o camino exterior requiere corrección; las cinco puertas de despliegue permanecen cerradas.

## D9 — DNS de apex distinto de DEV y ausencia de host Caddy (11/11/2026)

El operador confirmó `D9_MAIN_CLEAN=PASS`, `D9_DEV_IPV4_DNS=YES`, `D9_APEX_IPV4_DNS=YES`, `D9_APEX_ALL_IPV4_DESTINATIONS_MATCH_DEV=NO`, `D9_APEX_ANY_IPV4_DESTINATION_SHARED_WITH_DEV=NO`, `D9_CADDY_LOADED_CONFIG_READ=PASS`, `D9_DEV_EXPLICIT_HOST_ROUTE_PRESENT=YES`, `D9_DEV_EXPLICIT_HOST_PROXY_PRESENT=YES`, `D9_APEX_EXPLICIT_HOST_ROUTE_PRESENT=NO`, `D9_APEX_EXPLICIT_HOST_PROXY_PRESENT=NO`, `D9_DEV_LOCAL_CADDY_SNI_CURL_EXIT=0`, `D9_DEV_LOCAL_CADDY_SNI_HTTP_STATUS=200`, `D9_DEV_LOCAL_CADDY_SNI_TLS_VERIFY=0`, `D9_APEX_LOCAL_CADDY_SNI_CURL_EXIT=35`, `D9_APEX_LOCAL_CADDY_SNI_HTTP_STATUS=000`, `D9_APEX_LOCAL_CADDY_SNI_TLS_VERIFY=1`, `D9_RELEASE_READINESS=BLOCKED`, `D9_RESULT=4` y `D9_SHELL_RESULT=4`. Docker `active` y Git limpio.

**Hallazgo verificado:** los conjuntos de destinos IPv4 de apex y DEV son disjuntos; Caddy cargado en el VPS expone ruta explícita de `dev.vencira.es` y no expone ruta explícita de `vencira.es`. DEV satisface un handshake TLS validado en loopback, apex no. La combinación explica que el dominio de publicación no esté habilitado en este Caddy, pero **no** demuestra si el destino DNS de apex es erróneo: puede representar un servicio intencionado distinto. La comprobación no prueba la existencia o ausencia de una ruta catch-all ni que el fallo TLS público sea causado exclusivamente por Caddy del VPS, puesto que apex tiene otra ruta DNS.

**Acción operativa pendiente B5, no autorizada:** decidir el destino final de apex y su tratamiento de contenido existente; preparar configuración de Caddy de producción con TLS automático, rutas backend/web, cookies Secure, ALLOWED_HOSTS, CSRF y verificación. Acordar ventana de cambio/rollback de DNS, comprobar propagación y TLS sin exponer el servicio antes de pruebas, y obtener aprobación expresa. No cambiar DNS, Caddy ni DEV ahora.

**No repetir D7/D8/D9** para esta misma evidencia. D5 backend/web PASS no sustituye Android físico, archivo restaurado exacto, O5 ligado al binario archivado, custodia cifrada externa ni reversión. Se mantienen:
```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D9_DEPLOY_EXECUTED=NO
D9_CADDY_RELOAD_EXECUTED=NO
D9_DNS_CHANGED=NO
D9_PUBLIC_RELEASE_AUTHORIZED=NO
```

## D10 — Opción 2: configuración de apex separada (preparada; NO activada)

A petición del operador se preparó el fichero de configuración **independiente** `ops/caddy/vencira.es.Caddyfile.candidate` (commit `b664da99`). Define únicamente `vencira.es`, sin reconfigurar `dev.vencira.es`, con rutas mutuamente excluyentes para `/api/*`, `/accounts/*`, `/admin/*` dirigidas al **futuro** API de producción en `127.0.0.1:18741` y el resto al **futuro** Web de producción en `127.0.0.1:18742`. Estos puertos son **propuestos/reservados**, no comprobados abiertos, no servicios existentes ni un permiso para exponerlos. Se evita deliberadamente reutilizar DEV (18731/18732) para no publicar sus datos.

`scripts/main_d10_apex_caddy_candidate_static_gate.sh` (commit `cc21bbe6`) realiza inspección estática del candidato y `caddy validate --adapter caddyfile` sin tocar `/etc/caddy/Caddyfile`, reiniciar/reload, modificar DNS, desplegar Docker ni leer credenciales. **Validar su sintaxis no prueba conectividad TLS, DNS, CSRF, cookies ni el funcionamiento de las futuras aplicaciones.**

Ejecución de validación estática:
```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d10_apex_caddy_candidate_static_gate.sh
echo "D10_SYNTAX=$?"
bash scripts/main_d10_apex_caddy_candidate_static_gate.sh
echo "D10_SHELL_RESULT=$?"
git status --short
```

Precondiciones antes de cualquier activación: aprovisionar API/Web producción **separados** de DEV, revisar política de rutas y acceso a media/estáticos, `DJANGO_ALLOWED_HOSTS=vencira.es`, `DJANGO_CSRF_TRUSTED_ORIGINS=https://vencira.es`, `DJANGO_HTTPS_BEHIND_PROXY=1`, cookies Secure y secretos de producción independientes, asegurar PostgreSQL segregado y backups/custodia, probar TLS del dominio con DNS adecuado, definir ventana y rollback reversible y pedir aprobación explícita. **Ningún cambio operativo autorizado** (`MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`). Este candidato no debe importarse al Caddy activo antes de que esas condiciones se cumplan.

## D10 — PASS validación estática de apex (11/11/2026)

El operador confirmó `D10_MAIN_CLEAN=PASS`, `D10_APEX_HOST_EXPLICIT=PASS`, `D10_SEPARATE_API_WEB_UPSTREAMS=PASS`, `D10_DEV_PORTS_EXCLUDED=PASS`, `D10_CADDYFILE_CANDIDATE_SYNTAX=PASS`, `D10_RESULT=0` y `D10_SHELL_RESULT=0`. Los invariantes restrictivos fueron `D10_DEPLOY_EXECUTED=NO`, `D10_CADDY_RELOAD_EXECUTED=NO`, `D10_CADDY_CONFIG_CHANGED=NO`, `D10_DNS_CHANGED=NO`, `D10_LIVE_MIGRATIONS_EXECUTED=NO`, `D10_PRODUCTION_UPSTREAMS_DEPLOYED=NO`, `D10_DNS_CUTOVER_AUTHORIZED=NO`, `D10_PUBLIC_RELEASE_AUTHORIZED=NO`. `git status --short` terminó sin cambios.

**Cerrado:** gramática del Caddyfile candidato, host apex explícito, endpoints de futuro backend y frontend separados y ausencia de puertos DEV. **No cerrado:** servicios operativos en 18741/18742, revisión de configuración real, certificado y dominio, seguridad CSRF/cookies, restauración operativa, custodia off-host, Android final y aprobación.

### Puerta consolidada hacia publicación

1. **Infraestructura segregada:** confirmar que los puertos 18741 y 18742 están libres y se pueden reservar sin interferir con DEV; definir proyecto Compose y base PostgreSQL de producción independientes, secretos separados y no montar volúmenes DEV; crear un runbook de activación y retirada, pero no ejecutarlo aún.
2. **Recuperación:** identidad/rehidratación de las imágenes exportadas en runtime independiente (discrepancia D3-B3), restauración O5 coherente con la versión histórica 0018, custodia externa cifrada con verificación de recuperación y decisión sobre escrituras posteriores al snapshot.
3. **Cliente:** Android APK final, prueba física de HTTPS, ciclo de inicio/cierre de sesión, recuperación y almacenamiento seguro; no deducirlo de tests Flutter web.
4. **Seguridad pública:** validar configuración de Caddy candidata frente a producción, TLS, proxy, `DJANGO_ALLOWED_HOSTS`, `DJANGO_CSRF_TRUSTED_ORIGINS`, cookies Secure, HSTS y el comportamiento del frontend/backend. Confirmar el destino previsto del apex antes del cambio DNS; la discrepancia IPv4 observada en D9 no da permiso para sustituir el contenido del dominio actual.
5. **Autorización y reversión:** evidencias de salud y recuperación, ventana/criterios de rollback y aprobación específica para cualquier despliegue, migración de la base operativa o conmutación DNS/Caddy. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` salvo decisión expresa separada.

**Progreso cualitativo:** D5 cierra la regresión Django+PG17+Flutter web del candidato; D10 cierra la sintaxis y aislamiento declarativo del Caddyfile apex. Los bloqueos de publicación aún requieren ejecuciones de pruebas específicas y no deben darse por superados con una validación estática.

## D11 — Candidato Compose de producción segregado, sin despliegue (11/11/2026)

Tras D10 PASS (operador verificó sintaxis Caddy y exclusión de DEV con `D10_RESULT=0`), se publican en `main`:

- `ops/production/compose.production.candidate.yaml`: proyecto `vencira_prod`, servicios exclusivos `db`, `api`, `web`; red `prod_internal` solo interna; DB PG17 con volumen nuevo y sin puerto host; API y Web solo en loopback 18741/18742, compatibles con el candidato D10; imágenes obligatoriamente declaradas por variables, nunca tags implícitos.
- `ops/production/production.env.reference.txt`: contrato de variables Django/PG17 **sin secretos ni env operativo**.
- `scripts/main_d11_production_compose_dryrun.py`: verificación exclusivamente sintética de Docker Compose a través de `docker compose config --format json`, más validaciones estructurales de aislamiento y puertos observacionales. Nunca `up/pull/build/run`.
- `docs/operations/D11_PRODUCTION_ISOLATED_COMPOSE_CANDIDATE_2026-11-11.md`: ejecución y riesgos.

Commits: `fa3bcaa8` (Compose), `c08f6193` (gate), `62d9f008` (sudo/variables sintéticas), `d3b1d239` (contrato env), `c86cd11e` (runbook).

**Estado D11: publicado y no ejecutado.** No acreditar PASS del script ni inferir que puertos/red/PG17 ya estén provisionados. Seguridad: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. D11 solamente prepara configuración de la infraestructura, mientras B1/B2/B3/B4-nativo/B5 y autorización operativa continúan pendientes.

## D11 PASS; D12 copia externa cifrada preparada (11/11/2026)

El operador confirmó `D11_MAIN_CLEAN=PASS`, `D11_DEV_ISOLATION=PASS`, `D11_SEPARATE_COMPOSE_PROJECT=PASS`, `D11_COMPOSE_PARSE=PASS`, `D11_PRIVATE_NETWORK_ONLY=PASS`, `D11_PG17_HOST_PORTS=NONE`, `D11_PG17_NAMED_VOLUME_SEPARATE=PASS`, `D11_HOST_LOOPBACK_PORTS=PASS`, `D11_PRODUCTION_COMPOSE_CANDIDATE=PASS`, `D11_PROPOSED_PORT_18741_NO_LISTENER_OBSERVED=YES`, `D11_PROPOSED_PORT_18742_NO_LISTENER_OBSERVED=YES`, `D11_PORTS_RESERVED=NO`, `D11_DEPLOY_AUTHORIZED=NO`, `D11_RESULT=0`, `D11_SHELL_RESULT=0`; Docker activo y Git limpio. D11 valida **exclusivamente** el Compose candidato, sin desplegar servicios ni reservar puertos.

Se publica D12 con `scripts/main_d12_encrypted_offhost_archive_custody.sh` (commits `268837a7`, `8ffaa6a0`) y `docs/operations/D12_ENCRYPTED_OFFHOST_IMAGE_ARCHIVE_2026-11-11.md` (commit `74dc57d8`): backup real **cifrado vía Restic/rclone** del archivo histórico de imágenes a Google Drive y readback SHA256 desde un snapshot remoto etiquetado de forma única, sin plaintext a disco. D12 **sí escribe un snapshot en el repositorio externo**, aunque no modifica servicios, bases DEV, Docker, Caddy ni DNS. No ejecutado todavía; no marcar B3 PASS hasta ver `D12_RESULT=0` y todas las comprobaciones de lectura externa.

D12 comparte proveedor/repositorio remoto con O5, por lo que la independencia de fallo frente al sistema externo O5 y la recuperación operativa desde un Docker limpio continúan sin demostrar. B1/B2/B4 Android/B5 producción no se cierran por una copia cifrada.

Seguridad: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, no ejecución de despliegue, migración real ni rollback operativo.

## D12 PASS: custodia externa cifrada y readback de imágenes (11/11/2026)

Resultado informado por operador: `D12_MAIN_CLEAN=PASS`, `D12_LOCAL_ARCHIVE_CHECKSUM=PASS`, `D12_REMOTE_REPOSITORY_CONFIG=PASS`, `D12_ENCRYPTED_OFF_HOST_SNAPSHOT_CREATED=YES`, `D12_UNIQUE_REMOTE_SNAPSHOT=PASS`, `D12_REMOTE_ARCHIVE_BYTES_EQUAL=PASS`, `D12_REMOTE_METADATA_BYTES_EQUAL=PASS`, `D12_REMOTE_PAYLOAD_VERIFIED=YES`, `D12_ENCRYPTED_OFF_HOST_ARCHIVE_CUSTODY=PASS`, `D12_RESULT=0`. D12 queda cerrado para custodia cifrada fuera del VPS y lectura integral validada; sus marcadores iniciales NO reflejan estado antes de la operación, no fallo final. No repetir D12 para evitar snapshots duplicados.

Los límites permanecen `D12_REMOTE_RESTORE_TO_NEW_RUNTIME_VERIFIED=NO`, `D12_ARCHIVE_CONFIG_ID_EQUIVALENCE_VERIFIED=NO`, `D12_OPERATIONAL_ROLLBACK_VERIFIED=NO`. Restic está en el mismo proveedor/repositorio lógico de O5 y no prueba redundancia independiente.

**Prioridad real siguiente:** ensayo de rehidratación del archivo desde custodia externa sobre runtime aislado, identificar diferencia exacta de hashes/config Docker antes de afirmar recuperación histórica; después probar coherencia de PostgreSQL/O5 con la imagen histórica de `0018` sin imponerle `0027`. Android final y la publicación permanecen pendientes. No modificar DEV, Caddy, DNS ni base viva. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D13 — Desde el snapshot D12 al runtime PG17 aislado (11/11/2026)

**Estado: candidato D13 publicado y NO ejecutado.** La fase D12 está documentada como `PASS` para custodia remota y readback cifrado, pero no como recuperación ejecutable. D13 recupera el último snapshot que tenga las etiquetas originales `vencira-image-archive` y `d12-vencira-images-...` y la ruta del archivo histórico, usando la configuración root O5 ya autenticada, **sin escribir en el repositorio Restic**. Descarga el tar y metadatos a carpeta temporal privada, verifica SHA256 y reutiliza D4-C para importar las imágenes en almacén **Podman rootless VFS propio**, arrancar PostgreSQL 17 con datos exclusivamente sintéticos y comprobar SQL. El runner D4-C limpia su almacenamiento y el wrapper D13 limpia la copia remota temporal incluso ante fallos.

Archivos publicados: `scripts/main_d13_remote_image_archive_root_helper.sh` (commits `f3f3d10d`, `9692c894`), `scripts/main_d13_remote_image_pg17_rootless_recovery.sh` (`34b67777`, `dd81023c`) y `docs/operations/D13_REMOTE_IMAGE_PG17_ROOTLESS_RECOVERY_2026-11-11.md` (`eb8287cf`). La ejecución y marcadores aceptables están en D13. No interpretar un resultado previo D4-C local como D13 remoto.

Si D13 PASS: quedará acreditada la rehidratación y ejecución de **PostgreSQL 17 archivado** a partir de copia externa, con datos sintéticos. **No** estarán acreditados API/Web desde el remoto, recuperación del dump O5 unido a la imagen histórica 0018, identidad exacta Docker antes/después, rollback operacional ni Android/publicación. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No activar Caddy/DNS, no montar volúmenes DEV, no levantar servicios producción.

## D13 — Error 2 por bug propio del script; corregido en main (11/11/2026)

El operador ejecutó D13 y obtuvo mensajes `fatal: not a git repository`, seguidos de `D13_MAIN_CLEAN=PASS` (falso positivo), `D13_SCRIPT_MISSING=FAIL`, `D13_SHELL_RESULT=2`; Docker activo y Git status del worktree limpio. La causa no era el repositorio: **el wrapper D13 tenía un literal `$$` en la expansión Bash de BASH_SOURCE**, calculaba mal la raíz; los comandos Git fallaron con salidas vacías y el guardia permitía un PASS incorrecto. El helper privilegiado compartía el defecto de expansión `$$` en variables RESTIC. No se accedió al backup remoto ni se arrancaron contenedores durante esa ejecución.

Cambios publicados: `7a6d9c16` corrige cálculo de raíz y exige éxitos explícitos de los tres comandos Git; `d54b6ff6` corrige la expansión del helper; `ff5171e3` añade diagnóstico a documentación D13. **No dar D13 por superada** hasta ejecutar de nuevo la versión corregida y observar todos sus marcadores reales. No repetir D12.

## D13-R PASS: importación de archivo histórico + PG17 arrancado (11/11/2026)

D13 descargó desde Restic el snapshot D12 y verificó SHA256, pero falló en la fase combinada de runtime `D13_RESULT=5` (causa del error D4-C no registrada en aquella ejecución). D13-R reutilizó el archivo local ya probado con igual SHA256 que el tar remoto y obtuvo `D13R_D4C_ROOTLESS_IMAGE_IMPORT=PASS`, `D13R_D4C_IMPORTED_IMAGE_COUNT_3=PASS`, `D13R_D4C_ARCHIVED_PG17_ROLE_IDENTITY=PASS`, `D13R_D4C_PG17_START=PASS`, `D13R_D4C_PG17_READY=PASS`, `D13R_D4C_PG17_SYNTHETIC_SQL=PASS`, `D13R_D4C_EPHEMERAL_STORAGE_REMOVED=YES`, `D13R_D4C_RESULT=0`, `D13R_PG17_LOCAL_RUNTIME=PASS`, `D13R_PRIVATE_LOG_REMOVED=YES`, `D13R_RESULT=0` y `D13R_SHELL_RESULT=0`.

**Conclusión válida:** respaldo externo D12 verificado byte a byte; recuperación remota del tar D13 verificada; archivo equivalente importado en Podman independiente y PostgreSQL17 archivado funcionando con datos sintéticos D13-R. **No afirmar D13 end-to-end PASS** ni rehidratación completa del servicio/API/Web, identidad original exacta, ni restauración real O5/rollback operacional. No es necesario volver a descargar y ejecutar la misma carga solo para duplicar evidencia; la prioridad operativa pasa a coherencia entre O5 histórico `0018` y API retenida sin solicitar `0027` a ese binario.

Documentación extendida: `docs/operations/D13_REMOTE_IMAGE_PG17_ROOTLESS_RECOVERY_2026-11-11.md` (commit `aefeb7ec`). Los controles `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` permanecen.

## D14 — compatibilidad del backup real O5 con API histórica 0018 (11/11/2026)

La evidencia D12 y D13-R permite conservar la integridad off-host y la importación/ejecución de PG17 archivado sin repetir esos ensayos. Quedaba un fallo conceptual en D4-H: pedir `migrate reminders 0027` a la imagen histórica Django que D4-H2 confirmó limitada a migración 0018.

**D14 publicada en main, NO ejecutada todavía.** `scripts/main_d14_historical_api_o5_pg17_isolated.sh` (commits `c96c2c3a`, `646b9422`) adapta el laboratorio seguro D4-H al esquema histórico real. Preflight 0018-only del binario retenido antes de leer el backup; restaura un snapshot O5 real a PG17 temporal en red interna y PGDATA tmpfs; Django `check`, paridad modelo 0018 y `migrate reminders 0018 --plan` (no aplica migraciones), ausencia de registro 0019–0027, conservación de recuentos core, cleanup DEV y red. Se excluye explícitamente `migrate reminders 0027` en esta imagen; la candidata `main` 0019–0027 quedó validada separadamente en D1-N.

Runbook `docs/operations/D14_HISTORICAL_API_O5_PG17_ISOLATED_2026-11-11.md` (commit `d51db74e`). Se ejecuta con `sudo bash` y la ruta existente del archivo local, sin `docker load`, restauración de la BD viva ni publicación. El éxito no resuelve por sí mismo el mismatch de IDs Docker exportados, prueba end-to-end desde almacenamiento remoto ni reversión operativa.

**No autorizar aún el despliegue**: Android nativo final, ruta pública/DNS/Caddy activa, recuperación integral y permiso operativo todavía sin cerrar. Invariantes `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D14 primer intento — preflight falso negativo (11/11/2026)

Resultado operador: `D14_ARCHIVE_CHECKSUM=PASS`, `D14_ARCHIVE_MANIFEST=PASS`, `D14_HISTORICAL_API_0018_ONLY=FAIL`, `D14_O5_CREDENTIALS_ACCESSED=NO`, `D14_REAL_O5_RESTORE_EXECUTED=NO`, `D14_RESULT=8`. No se llegó a restauración O5 ni a arranque de laboratorio PG17. La revisión del código encontró regex Python raw sobreescapada para comprobar archivo `0018_*.py`. Corregido en `main` commit `22d981e3` para comparar nombre y sufijo directamente; detalle en `docs/operations/D14_HISTORICAL_API_O5_PG17_ISOLATED_2026-11-11.md` commit `4a41f263`. **D14 no está aprobada**; repetir solo su versión corregida, no D12/D13. Mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D14 PASS — backup O5 histórico y API Django 0018 compatibles (11/11/2026)

**Evidencia del VPS:** `D14_HISTORICAL_API_0018_ONLY=PASS`, `D14_CONFIG_MATCH=PASS`, `D14_DEV_IDENTITY=PASS`, `D14_HOST_IMAGE_IDENTITY=PASS`, `D14_RECENT_POSTGRESQL_SNAPSHOT=PASS`, `D14_LAB_NETWORK_INTERNAL=PASS`, `D14_PG17_NETWORK_ISOLATED=PASS`, `D14_PG17_TMPFS_READY=PASS`, `D14_RESTORE_REAL_O5_PG17=PASS`, `D14_HISTORICAL_0018=PASS`, `D14_BACKUP_PAYLOAD_PG_RESTORE_VERIFIED=YES`, `D14_REAL_BACKUP_RESTORED=PASS`, `D14_MODEL_MIGRATION_PARITY=PASS`, `D14_HISTORICAL_0018_MIGRATION_PLAN=PASS`, `D14_HISTORICAL_MIGRATION_SET=PASS`, `D14_CORE_COUNTS_UNCHANGED=PASS`, `D14_HISTORICAL_API_O5_COMPATIBILITY=PASS`, `D14_DEV_CONTAINERS_UNCHANGED=OK`, `D14_LAB_CONTAINER_REMOVED=YES` y `D14_RESULT=0`.

Se ha demostrado que la copia O5 real se restaura en PG17 temporal y que **la imagen histórica Django 0018 retenida en Docker host** valida el esquema, el plan de migraciones y los recuentos sin aplicar migraciones 0019–0027. `D14_CONTAINER_RUN_EXECUTED=YES` corresponde al contenedor de laboratorio, no a despliegue. No se efectuaron operaciones en las bases activas, ni cargas de imágenes, ni despliegues, ni cambios DEV. Documentado `docs/operations/D14_HISTORICAL_API_O5_PG17_ISOLATED_2026-11-11.md` commit `f410b53b`.

**Límites críticos:** D14 no ejecutó servidor HTTP API/Web recuperado, no utilizó el tar externo como origen runtime, no resolvió la discrepancia de IDs de imagen Docker, no efectuó rollback operacional y no validó aún APK/HTTPS Android final ni Caddy/DNS de apex. Mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D14_PUBLIC_RELEASE_AUTHORIZED=NO`.

Priorizar pruebas de extremo a extremo de la pila recuperable y la ruta Android/publicación; no repetir D12–D14 sin motivo técnico nuevo.

## D15 — HTTP API + Nginx históricos sobre O5 real, aislados (11/11/2026)

D14 fue superada en el VPS y demuestra restauración O5 + compatibilidad esquema 0018. Para acelerar, se publica la puerta **D15**, que reutiliza su restauración protegida y añade arranque de la imagen API histórica en la **misma red Docker --internal**, comprobación HTTP 200 JSON salud, arranque Nginx histórico, GET estático 8080 y GET salud de la API a través del proxy Nginx, todo **desde dentro de los contenedores**, sin puertos host ni acceso a datos desde exterior. Los tres contenedores de laboratorio (PG/API/Web), red y entorno temporal se destruyen al salir; se verifica inmutabilidad de IDs de DEV.

Script `scripts/main_d15_real_o5_historical_stack_http_isolated.sh`, commit `2ec68fc5`. Runbook `docs/operations/D15_HISTORICAL_O5_API_WEB_HTTP_ISOLATED_2026-11-11.md`, commit `aecc4dad`. **D15 publicada y NO ejecutada**. Es un gate HTTP/infra, no una validación del conjunto de operaciones funcionales ni autorización de publicación. No cerrar mismatch IDs de Docker exportados, HTTPS/Caddy, Android ni reversión operativa sin pruebas propias.

Controles: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D15 PASS — API histórica + Nginx + PostgreSQL17 O5 real (11/11/2026)

Validación operador: `D15_RESTORE_REAL_O5_PG17=PASS`, `D15_HISTORICAL_0018=PASS`, `D15_MODEL_MIGRATION_PARITY=PASS`, `D15_HISTORICAL_API_O5_COMPATIBILITY=PASS`, `D15_API_HTTP_START=PASS`, `D15_API_HTTP_HEALTH_WITH_O5=PASS`, `D15_API_DJANGO_DB_CHECK_AND_HTTP=PASS`, `D15_WEB_HTTP_START=PASS`, `D15_WEB_HTTP_STATIC=PASS`, `D15_WEB_API_HTTP_PROXY_WITH_O5=PASS`, `D15_RESTORED_HISTORICAL_STACK_HTTP=PASS`, `D15_HOST_PORTS_PUBLISHED=NO`, `D15_LIVE_DATA_HTTP_EXPOSED=NO`, `D15_DEV_CONTAINERS_UNCHANGED=OK`, `D15_LAB_CONTAINER_REMOVED=YES`, `D15_API_LAB_REMOVED=YES`, `D15_WEB_LAB_REMOVED=YES`, `D15_RESULT=0`. Ejecutaron contenedores PG/API/Web exclusivamente en red interna efímera; no hubo deploy, migración/restore vivo ni `docker load`.

**D15 PASS** cierra la prueba **HTTP de la pila histórica retenida** con copia O5 real restaurada en laboratorio. No implica endpoints autenticados funcionales, recuperación exclusivamente desde archivo off-host ni identidad exacta del tar, ni HTTPS público. Detalle y marcadores adicionales en `docs/operations/D15_HISTORICAL_O5_API_WEB_HTTP_ISOLATED_2026-11-11.md`, commit `1d8a1ec1`. Se mantiene `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

El próximo trabajo de mayor impacto para publicación es el paquete Flutter/Android de release con conexiones HTTPS nativas/credenciales, y confirmar la intención y enrutamiento del dominio apex, sin tocar todavía producción. Evitar repetir D12–D15 salvo cambios materiales.

## D16 — Candidata Android REAL desde Flutter main.dart (11/11/2026)

Se preparó la próxima puerta para publicación Android: `scripts/main_d16_android_main_candidate_debug_gate.sh` (commit `ed2df74a`). **Estado: publicada en `main`, sin ejecución/resultado aún.** Verifica Git limpio/sin ramas adicionales, Docker DEV identidades, `flutter analyze`, pruebas de recuperación y contratos HTTP, compilación nativa **debug** desde `lib/main.dart` mediante Docker Flutter 3.44.0, contenido básico ZIP y SHA256 de artefacto privado por commit. No construye otra app LAB, no requiere/acepta credenciales signing release, no publica APK, no instala en teléfono ni modifica producción. Procedimiento `docs/operations/D16_ANDROID_MAIN_CANDIDATE_GATE_2026-11-11.md` (commit `a91b5c63`).

**No confundir D16 PASS con APK listo para producción:** faltarán validación física HTTPS/Keystore del artefacto real, build firmada release, instalación/update, certificados y dominio apex. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No repetir los gates recuperados D12–D15. Priorizar ejecución D16 y resolver cualquier error de Flutter concreto.

## D16 PASS — Android Flutter `main.dart` debug candidate (11/11/2026)

**Comprobación ejecutada en VPS:** `D16_FLUTTER_ANALYZE_TEST_BUILD=PASS`, `D16_APK_ZIP_INTEGRITY=PASS`, `D16_APK_SHA256_RECORDED=PASS`, `D16_APK_MAIN_ENTRYPOINT=YES`, `D16_APK_DEBUG_ONLY=YES`, `D16_DEV_CONTAINERS_UNCHANGED=OK`, `D16_DEPLOY_EXECUTED=NO`, `D16_RELEASE_AUTHORIZED=NO` y `D16_RESULT=0`. El artefacto debug quedó bajo `/home/vencira/vencira-android-candidate/b0a8b60ca1a873ce36c481d14827513c0ab054b5/VENCIRA-main-candidate-debug.apk`. No se comunicó hash ni `D16_SHELL_RESULT` independiente. Evidencia detallada en `docs/operations/D16_ANDROID_MAIN_CANDIDATE_GATE_2026-11-11.md` commit `38b28aac`.

**No confundir con distribución:** `D16_APK_PHYSICAL_DEVICE_TEST=NOT_RUN`, `D16_APK_NATIVE_HTTPS_RELEASE_GATE=NOT_VERIFIED`, `D16_APK_RELEASE_SIGNING_GATE=NOT_VERIFIED`. Prioridad D17: instalación física controlada del candidato main y examen de flujos reales Android; D18: firma release, permisos y canal de distribución. No se autorizan despliegue ni MFA real: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D17 — revisión visual de APK Android main (11/11/2026)

Dos capturas del operador muestran (1) pantalla nativa `Acceso seguro a VENCIRA` y transferencia al navegador, y (2) Chrome `dev.vencira.es` con `Agenda diaria` representada para el 11/11/2026. Lectura del código confirma ruta deliberada: `clients/flutter/lib/main.dart` devuelve `AndroidWebAccessScreen` en Android real sin API inyectada; `clients/flutter/lib/ui/android_web_access_screen.dart` abre URL de desarrollo con `LaunchMode.externalApplication`. El shell nativo de laboratorio requiere `!kReleaseMode` e inyección; **D16 PASS no demuestra login nativo integrado**.

D17 visual: `ANDROID_APP_LAUNCH_VISUAL=PASS`; `EXTERNAL_WEB_HANDOFF_VISUAL=PASS`; `NATIVE_AUTHENTICATED_LOGIN=NOT_IMPLEMENTED`; `NATIVE_HTTPS_SESSION_VERIFIED=NO`; `NATIVE_KEYSTORE_REAL_APP_VERIFIED=NO`; `RELEASE_SIGNING_VERIFIED=NO`. No hay prueba de seguridad real autenticada del APK. La ruta nativa está bloqueada por diseño, no por fallo de build. Detalle en `docs/operations/D17_ANDROID_VISUAL_FENCE_2026-11-11.md`, commit `084a03a9`.

**Bloqueo funcional de publicación Android:** un APK que solo abre la web no puede declararse aplicación Android nativa autenticada; para cambiarlo hacen falta emisor autorizado real, manejo de vault/HTTPS, reanudación/revocación de sesión y prueba física completa. No ocultar el fence visual hasta superar estos controles. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D17-B — native Android startup inspection integrated into real main (11/11/2026)

The D17 phone screenshots and a source inspection established that `main.dart` routes production Android directly to the browser-launch screen. The existing native auth components are prototypes/ports with no operationally authorized real issuer. **Not appropriate to activate those credentials through main.dart merely because debug laboratory gates passed.**

Published native startup integration **in `main`, tests still awaiting VPS**:
- `clients/flutter/lib/ui/native_android_startup_boundary.dart`, commit `47290ff5`: constructs real `FlutterNativeSecretStore`, `NativeRefreshCredentialVault`, `NativeRefreshRecoveryJournal`, `NativeMobileStartupGate` and classifies Android protected state before browser handoff. A previous/orphan refresh stays blocked and requests full reauthentication (not yet operational); secure-store failure blocks native activity.
- `clients/flutter/lib/ui/android_web_access_screen.dart`, commit `f6f5c23f`: optional clear native state warning, without pretending native authentication exists.
- `clients/flutter/lib/main.dart`, commit `90eeb9ff`: real Android startup now uses this boundary after the native alarm cancellation gate; the browser alternative remains.
- `clients/flutter/test/native_android_startup_boundary_test.dart`, commit `f02e9c80`: tests for clean login, old credential, secure store failure and asynchronous pending state.
- `scripts/main_d17b_android_startup_boundary_gate.sh`, commit `cc6a7330`: test runner (Flutter analyze + startup and recovery regressions) against clean main; no APK installation, backend mutation or release.
- Runbook `docs/operations/D17B_ANDROID_NATIVE_STARTUP_INTEGRATION_2026-11-11.md`, commit `a1cc7504`.

**D17-B not yet PASS**; requires local output `D17B_FLUTTER_GATE=PASS` and `D17B_RESULT=0`. This phase completes only safe startup inspection integration, NOT native issuance, full recovery, HTTPS mobile authentication, or release signing. Maintaining `MFA_RELEASE_AUTHORIZED=NO` and `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Next meaningful separate gate is audited native issuer + account-wide recovery and physical-device validation; do not remove the browser fallback or expose credentials until that gate passes.

## D17-B — incidencia visual corregida; revalidación pendiente (11/11/2026)

El primer gate Flutter de D17-B tuvo `flutter analyze` sin incidencias, I8-Q/I8-L sin fallos observados y **un test fallido**: aviso de recuperación Android largo provocó `RenderFlex overflowed by 28 pixels on the bottom` en `android_web_access_screen.dart`. `D17B_FLUTTER_GATE=FAIL`, `D17B_DEV_CONTAINERS_UNCHANGED=OK`, `D17B_RESULT=4`. Corrección en `main` `d9098499`: scroll vertical seguro de la vista web; regresión `847af3c3` en viewport 320x480 que comprueba ausencia de overflow y botón nativo inaccesible; documentación `1d7dcafb`. No modifica autenticación ni servidor. **No declarar D17-B PASS** hasta resultado de repetición del script `scripts/main_d17b_android_startup_boundary_gate.sh`. No repetir D16 ni compilar APK hasta confirmación.

## D17-B PASS — Android real inspecciona almacén seguro antes del acceso (11/11/2026)

Gate VPS validado tras corrección del scroll: `flutter analyze` **0 issues**; **15 tests PASS** (boundary Android, I8-Q fallos y I8-L recuperación). Marcadores: `D17B_FLUTTER_GATE=PASS`, `D17B_NATIVE_STARTUP_INTEGRATED=YES`, `D17B_AUTH_PRODUCTION_ENABLED=NO`, `D17B_DEV_CONTAINERS_UNCHANGED=OK`, `D17B_RESULT=0`. La integración principal usa `NativeAndroidStartupBoundary` y `NativeMobileStartupGate` con secure store y recovery journal: un marcador o refresh huérfano obliga a recuperación, error de store cierra acceso y la UI no ofrece login nativo. El scroll resuelve el overflow en viewport 320x480. Documentación D17-B commit `98600e07`.

**Límite:** D17-B no integra todavía autenticación nativa operativa ni aprueba un issuer; no se ha reconstruido el APK después de estos cambios ni probado físicamente. Siguientes puertas: integrar contrato seguro real del backend + emisión/rotación/revocación, HTTPS dispositivo y nuevo APK firmado; no desplegar ni habilitar MFA hasta autorización. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## D18 — Gate agrupado de seguridad nativa + Django PG17 + Flutter HTTPS (11/11/2026)

Tras D17-B PASS, la auditoría constató que Django `config.urls` **no expone** los endpoints de emisión/recuperación LAB; `VENCIRA_NATIVE_BEARER_ENABLED=False`; `native_mobile_service` existe únicamente en tests con flag explícito. La aplicación Android `main.dart` integra ahora solo el arranque seguro fail-closed, sin `NativeHttpAuthPort` conectado al issuer real. NO es correcto convertir el test endpoint I8-D/I8-K en issuer operacional sin un control completo de claves, abuso, MFA, revocación y sesión.

Para acelerar sin reiterar D12–D17, **D18 publicada en `main`; ejecución VPS pendiente**:
- `scripts/main_d18_native_auth_release_fence_static.py` (`95dbf983`): valida URLconf Django, flags, fence Flutter, journal durable y bloqueo de issuer en app real sin network ni datos.
- `scripts/main_d18_native_auth_grouped_security_gate.sh` (`ea490a28`): orquesta gate estático, test real PG17 de contrato backend `native_i8k_recovery_http_pg17_isolated.sh` y HTTPS de cliente Flutter `main_i8m_flutter_real_https_pg17_isolated.sh`, todos en entornos desechables, con IDs DEV invariables.
- Procedimiento `docs/operations/D18_NATIVE_AUTH_GROUPED_SECURITY_GATE_2026-11-11.md`, commits `26ec21fa` y `f5addc3d`.

Un `D18_RESULT=0` demostrará exclusivamente que **los contratos LAB continúan validados y el entorno operativo no expone un emisor nativo no autorizado**; el marcador esperado es `D18_NATIVE_AUTH_OPERATIONAL_READINESS=BLOCKED` y `D18_AUTH_PRODUCTION_ENABLED=NO`. No anunciar login nativo real ni liberar APK. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Siguiente implementación sustantiva requerirá diseño y pruebas del issuer operacional aislado, no elevar un endpoint `test_*` a producción.
