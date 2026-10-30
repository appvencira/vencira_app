# MB1 — inventario real de escritores Docker antes del corte consistente

**30/10/2026: código implementado; ejecución en el VPS pendiente.**

Se incorpora `scripts/inspect_mb1_live_writer_surfaces_readonly.sh` para inspeccionar **únicamente metadatos de los contenedores Docker VENCIRA en ejecución**. Lee identidad de proyecto/servicio, estado, permisos privilegiados y montajes de solo lectura o escritura. **No imprime** rutas de origen del host, variables de entorno, direcciones IP, secretos ni contenidos de datos. No detiene contenedores, ejecuta SQL, escribe ficheros, migra, hace backups o cambia montajes. Exige opt-in `MB1_READONLY_WRITER_CENSUS=YES`.

## Ejecución autorizada: solo lectura en VPS original

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
MB1_READONLY_WRITER_CENSUS=YES bash scripts/inspect_mb1_live_writer_surfaces_readonly.sh
echo "MB1_WRITER_CENSUS_EXIT_CODE=$?"
```

Con la salida hay que decidir **qué proceso debe detenerse o pasar a mantenimiento**, **qué volumen contiene objetos y diarios**, **si hay escrituras desde tareas programadas/sidecars/procesos externos** y **cómo bloquear altas nuevas** antes de capturar PostgreSQL. El censo Docker **no** cubre procesos del host, contenedores no identificados como VENCIRA, sockets externos, tareas programadas ni escritura sobre binds compartidos por servicios ajenos. Los montajes no determinan por sí solos quién puede escribir por red a PostgreSQL.

No ejecutar ninguna acción de freeze/stop/captura hasta verificar el inventario real y disponer de secuencia de rollback. Una vez diseñado, primero realizar ensayo con clones, con un corte cuyo inicio/fin se pueda demostrar, y restaurar en máquina separada. **No confundir inventario con bloqueo de escritores.**

```text
MB1_WRITER_DOCKER_CENSUS=IMPLEMENTED_NOT_RUN
MB1_NONDOCKER_WITERS=NOT_INVENTORIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Inventario ejecutado en VPS (30/10/2026)

`DOCKER_USUARIO_EXIT=1`, `DOCKER_SUDO_EXIT=0`: acceso Docker con `sudo`, no incorporar usuario al grupo docker. El operador informa `MB1_WRITER_CENSUS_RUNNING_VENCIRA=6`, proyectos `vencira_localcheck` y `vencira_preview`, cada uno con API, web_preview y PostgreSQL. Ambos contenedores db montan un volumen Docker RW en `/var/lib/postgresql/data`; `MB1_WRITER_RW_MOUNT_COUNT=2`, `MB1_WRITER_CENSUS_RESULT=INVENTORY_ONLY`, `MB1_WRITER_CENSUS_EXIT_CODE=0`. `MB1_WRITER_FILE_LOCK_COOPERATIVE=UNVERIFIED`, `MB1_WRITER_ENTRYPOINT_COVERAGE=UNVERIFIED`, `MB1_WRITER_NONDOCKER_PROCESSES=NOT_INVENTORIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`.

**Hallazgo operativo:** existen dos proyectos independientes en el VPS; no seleccionar uno ni parar ninguno automáticamente. El informe no identifica montajes de adjuntos en los contenedores en ejecución; eso no descarta otros destinos de almacenamiento. Siguiente inspección estrictamente de lectura: comparar identidad y roles de ambos proyectos y localizar almacenamiento/servicios no Docker sin revelar variables ni secretos.


## M1-03 — Segunda capa: procesos y planificadores del host (pendiente de ejecución)

Commit `f6a191a` añade `scripts/inspect_mb1_host_writer_surfaces_readonly.sh`. Escanea exclusivamente nombres de ejecutables desde `/proc/PID/comm` y nombres de timers activos/inactivos de `systemctl list-timers --all`. No imprime argumentos, variables, rutas de origen, contenido, secretos ni ejecuta acciones sobre procesos. No requiere privilegios de Docker. No puede demostrar ausencia de escrituras externas SQL, binds compartidos, crontabs de usuarios ni procesos ocultos por permisos: todas esas superficies siguen **NOT_VERIFIED**. Comando:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/inspect_mb1_host_writer_surfaces_readonly.sh
MB1_READONLY_HOST_CENSUS=YES bash scripts/inspect_mb1_host_writer_surfaces_readonly.sh
echo "MB1_HOST_CENSUS_EXIT_CODE=$?"
```

M1-03 sigue abierto hasta contrastar el inventario del host con los proyectos Docker, entradas de escritura del código y tareas fuera de Docker. M1-04 (freeze) no autorizado.


## Evidencia host — PASS inventario, no freeze

Operador: `MB1_HOST_CENSUS_EXIT_CODE=0`; clases: caddy=1, containerd=1, cron=1, dockerd=1, gunicorn=6, nginx=10, postgres=12, python3=1; `/proc` inaccesibles=0. Timers detectados: `dpkg-db-backup.timer`, `vencira-o5-backup.timer`, `vencira-o5-health.timer`. Persisten `MB1_HOST_USER_CRONTABS=NOT_VERIFIED`, `MB1_HOST_EXTERNAL_SQL_WRITERS=NOT_VERIFIED`, `MB1_HOST_SHARED_BIND_WRITERS=NOT_VERIFIED`, `MB1_HOST_NONCOOPERATIVE_WRITERS=NOT_EXCLUDED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`. Los recuentos incluyen todos los servicios del host y no identifican por sí solos qué procesos escriben en VENCIRA. No se debe intervenir O5 ni procesos de DEV. M1-03 sigue pendiente.


## Evidencia censo cron/red del host — PASS parcial

Salida operador: `MB1_SYSTEM_CRONTAB=PRESENT:READABLE`, `MB1_SYSTEM_CRON_D=PRESENT:READABLE`, `MB1_ROOT_CRON_SPOOL=UNKNOWN`, `MB1_USER_CRON_SPOOL_DIR=PRESENT:NOT_READABLE`, `MB1_HOST_TCP_5432_LISTENER_COUNT=0`, `MB1_EXTERNAL_SQL_AUTHORIZATION=NOT_VERIFIED`, `MB1_CONTAINER_NETWORK_EXPOSURE=NOT_VERIFIED`, `MB1_CRON_CONTENT_AND_OTHER_USERS=NOT_VERIFIED`, `MB1_SHARED_BIND_WRITERS=NOT_VERIFIED`, `MB1_NONCOOPERATIVE_WRITERS=NOT_EXCLUDED`, `MB1_SCHEDULER_NETWORK_RESULT=INVENTORY_ONLY`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `MB1_SCHEDULER_CENSUS_EXIT_CODE=0`. La ausencia de listener 5432 en el espacio de red del host no demuestra aislamiento de contenedores o falta de clientes SQL remotos. El censo no inspeccionó contenido de cron ni otros usuarios. **M1-03 sigue abierto.**


## Censo Docker/red y cron — PASS (operador)

`MB1_DOCKER_NETWORK_CENSUS=OK`, `MB1_NETWORK_CRON_EXIT_CODE=0`. Seis contenedores: `vencira_localcheck/{api,web_preview,db}` y `vencira_preview/{api,web_preview,db}`, cada uno con una red; API/web con un binding publicado cada uno; ambas bases con `PUBLISHED_BINDINGS=0`. `/etc/cron.d`: 3 archivos; spool de crontabs: 0 archivos visibles durante inspección con privilegios. Se mantienen `MB1_CRON_COMMANDS=NOT_INSPECTED`, `MB1_EXTERNAL_SQL_CLIENTS=NOT_EXCLUDED`, `MB1_NONCOOPERATIVE_WRITERS=NOT_EXCLUDED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`. Estos resultados no prueban que las bases carezcan de clientes SQL por redes Docker ni autorizan parar servicios. El censo de metadatos se considera suficientemente documentado; siguiente paso es revisar fuentes efectivas de escritura y acceso.
