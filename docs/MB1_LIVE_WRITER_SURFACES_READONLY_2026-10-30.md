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
