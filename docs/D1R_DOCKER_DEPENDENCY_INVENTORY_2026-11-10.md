# VENCIRA — D1-R inventario de dependencias Docker (10/11/2026)

**Estado: ejecutor publicado en main, NO EJECUTADO.**

D1-Q identificó `vencira_localcheck`, `compose.yaml`, `compose.preview.yaml`, timers O5 activos, `D1B_RESULT=0`. D1-R continúa solo con metadatos de los tres contenedores persistentes de DEV: API, PostgreSQL y Web. El propósito es clasificar riesgos de rollback antes de revisar manifiestos y configuraciones sensibles.

El fichero `scripts/main_d1r_dev_docker_dependency_readonly.py` llama a `docker inspect` (con sudo si hace falta) y solo publica: comprobación de identidad Compose, presencia de digest de imagen (sin mostrarlo), recuentos de bind mounts, volúmenes, tmpfs, existencia de puertos publicados, política de reinicio y estado read-only del rootfs. No imprime rutas, puertos, IDs completos, network names, env, logs, labels completas, secretos ni contenido Caddy. No ejecuta `docker compose`, reinicia, crea, elimina, despliega ni migra.

## Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 scripts/main_d1r_dev_docker_dependency_readonly.py
echo "D1R_SHELL_RESULT=$?"
```

**Aceptación:** `D1R_RESULT=0`, `D1R_THREE_DISTINCT_LIVE_CONTAINERS=PASS` y `D1R_SHELL_RESULT=0`; los indicadores de mounts y puertos se **interpretan** y no se presuponen. Un resultado 0 solo significa que los metadatos se han podido clasificar; NO certifica rollback. El código no fue probado todavía en VPS. La comprobación posterior de los contenidos Compose/Caddy debe ser controlada y redactada, no volcar ficheros completos al chat.

## Reglas de seguridad

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```

**Pendientes de promoción:** imagen anterior preservada, integridad de artefactos estáticos, comprobaciones HTTPS del candidato en laboratorio, permisos de ficha y adjuntos, mapeo de mounts persistentes, política de recuperación y aprobación explícita de DEV.


## Resultado recibido del operador — 10/11/2026

**D1-R PASS para inventario de metadatos, NO prueba de rollback.** El ejecutor informó `D1R_RESULT=0`, `D1R_THREE_DISTINCT_LIVE_CONTAINERS=PASS`, identidad de proyecto PASS para API, DB y WEB, digests presentes en las tres imágenes, reinicio configurado en los tres servicios. Recuentos de mounts: API bind=0/volume=0/tmpfs=0; DB bind=0/volume=1/tmpfs=0; WEB bind=0/volume=0/tmpfs=0. Puertos publicados en API/WEB; DB sin puertos publicados. Los tres rootfs no son read-only. No se desplegó ni migró DEV y no se ejecutó rollback. **El operador no adjuntó `D1R_SHELL_RESULT`**, aunque el propio marcador del script `D1R_RESULT=0` sí consta.

```text
D1R_COMPOSE_MANIFEST_CONTENT_READ=NO
D1R_CADDY_CONFIG_CONTENT_READ=NO
D1R_ROLLBACK_EXECUTED=NO
D1R_ROLLBACK_VERIFIED=NO
```

**Consecuencia:** el volumen Docker único de PostgreSQL es un activo persistente crítico; no inferir que basta con conservar el identificador del contenedor. Una promoción posterior requiere fijar imagen previa, configuración Compose/Caddy verificada, backup anterior a la ventana y plan de recuperación consistente con escrituras concurrentes. Los nombres/orígenes de los volúmenes y los contenidos de Compose/Caddy permanecen sin inspección en este gate.
