# D15 — HTTP de API histórica y Nginx sobre O5 real, todo aislado

Estado 11/11/2026: **candidato publicado en main, no ejecutado**.

## Objetivo

D14 confirmó que un respaldo O5 real se recupera en PG17 efímero y que la imagen histórica Django 0018 pasa paridad/migraciones sin aplicar 0019–0027. D15 **conserva exactamente esas guardas** y suma arranque API (Gunicorn) y Web (Nginx) en una red Docker interna con la base recuperada.

Script: `scripts/main_d15_real_o5_historical_stack_http_isolated.sh`.

### Gate incluido

1. Identidad de tres imágenes **retenidas** en host y checksum/manifiesto del archivo local, sin `docker load`.
2. Preflight Python en contenedor sin red sobre migraciones 0018-only. Origen O5 autorizado, snapshot PostgreSQL más reciente con etiqueta/fichero correcto.
3. Identidad de DEV antes/después. Red `--internal` efímera; PG17 con datos en `tmpfs`, sin montar PGDATA de DEV ni publicar puertos; `pg_restore` real por streaming, sin escribir el dump en disco.
4. `django check`, paridad y plan 0018, preservación de recuentos.
5. Arranque histórico Gunicorn enlazado a la base restaurada en la red interna, validación de `/api/health/` HTTP 200 y JSON `status: ok` desde **dentro** del contenedor API.
6. Arranque Nginx histórico en la misma red privada; validación de web estática en 8080 y `/api/health/` a través del proxy Nginx, desde **dentro** del contenedor Web, sin visualizar datos personales.
7. Eliminación de contenedores temporales, red y archivo de entorno generado; confirmación de los tres IDs DEV.

El test de salud HTTP por sí solo **no prueba queries SQL funcionales ni autorización**. La conexión a PG17 se comprueba mediante `django check`, paridad y plan; el proceso HTTP se prueba de forma separada, por eso no es un end-to-end funcional completo. No hay APK, TLS público, cookie/csrf sobre dominio ni rollback real.

### Ejecución única en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d15_real_o5_historical_stack_http_isolated.sh
echo "D15_SYNTAX=$?"
sudo -v
sudo bash scripts/main_d15_real_o5_historical_stack_http_isolated.sh /home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7
echo "D15_SHELL_RESULT=$?"
git status --short
```

### Evidencia necesaria

```text
D15_RESTORE_REAL_O5_PG17=PASS
D15_HISTORICAL_API_O5_COMPATIBILITY=PASS
D15_API_HTTP_START=PASS
D15_API_HTTP_HEALTH_WITH_O5=PASS
D15_WEB_HTTP_START=PASS
D15_WEB_HTTP_STATIC=PASS
D15_WEB_API_HTTP_PROXY_WITH_O5=PASS
D15_RESTORED_HISTORICAL_STACK_HTTP=PASS
D15_DEV_CONTAINERS_UNCHANGED=OK
D15_LAB_CONTAINER_REMOVED=YES
D15_API_LAB_REMOVED=YES
D15_WEB_LAB_REMOVED=YES
D15_RESULT=0
D15_SHELL_RESULT=0
```

**Si D15 da FAIL:** no relanzar D12–D14 ni activar ningún servicio, revisar el primer marcador D15 fallido. Si falla proxy puede deberse a contrato Nginx del archivo histórico; no asumir que falla PostgreSQL. Si falla API puede tratarse de configuración histórica, no de corrupción O5.

## Condiciones de autorización

`MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La ejecución transitoria de contenedores históricos en red `--internal` es laboratorio; **no es despliegue público ni autorización de release**. Ningún puerto de host expuesto; nada de cambios Caddy, DNS, certificados, volúmenes ni contenedores DEV.

Además siguen pendientes: identidad exacta de IDs Docker de archivo exportado, instalación desde máquina limpia con copia externa, APK nativo final/HTTPS recuperación, activación segura dominio apex y procedimiento de rollback operativo.
