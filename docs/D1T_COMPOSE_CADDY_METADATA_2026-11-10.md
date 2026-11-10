# VENCIRA — D1-T, metadatos de Compose/Caddy sin lectura de secretos (10/11/2026)

**PUBLICADO, SIN VALIDACIÓN EN VPS.** El inventario D1-R y la regresión D1-S se han cerrado según la evidencia del operador. D1-T es el siguiente paso de bajo impacto, no un ensayo de proxy del candidato ni un plan de rollback certificado.

## Alcance exacto

El ejecutor `scripts/main_d1t_compose_caddy_metadata_readonly.py` usa `docker inspect` en la API DEV existente para obtener **internamente** directorio de trabajo y nombres de los ficheros Compose, exige el par `compose.yaml` y `compose.preview.yaml`, verifica ambos como archivos regulares no simbólicos en el directorio esperado y comprueba que la unidad `caddy` está activa mediante `systemctl is-active`. No muestra rutas, contenido Compose, datos de variables, encabezados HTTP, credenciales ni configuración de Caddy.

La presencia de archivos no demuestra que su interpolación sea segura ni que Caddy use una configuración concreta. La configuración realmente cargada, rutas proxy, imagen web candidata y recuperación de datos siguen sin comprobarse.

## Comando para Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 scripts/main_d1t_compose_caddy_metadata_readonly.py
echo "D1T_SHELL_RESULT=$?"
```

Aceptar solo si `D1T_COMPOSE_TWO_FILES_PRESENT=PASS`, `D1T_CADDY_UNIT_ACTIVE=PASS`, `D1T_RESULT=0` y `D1T_SHELL_RESULT=0`. Si falla el directorio por una disposición real diferente, investigar; no saltar restricciones ni mover ficheros. Este es un gate de **presencia y metadatos, no de semántica Compose ni TLS**.

## Riesgos abiertos y progreso

- D1-N/O/P/Q/R completados para sus alcances; D1-S suite publicada y D1-O reejecutado con `D1O_RESULT=0`. No consta `D1S_BACKEND_SHELL_RESULT` aislado, ni conteo individual de casos.
- Antes de promover DEV: HTTPS **del candidato**, permisos y operaciones de ficha/adjuntos en aislamiento, lectura controlada del manifiesto/Caddy efectivos, plan real de rollback de imágenes+volumen PostgreSQL, autorización explícita.
- No atribuir un porcentaje exacto de avance global: una cifra orientativa 75–80 % de **preparación web en DEV** se basa en hitos realizados, no en una métrica de cobertura o completitud del producto. APK Android nativa y producción son pistas separadas.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```
