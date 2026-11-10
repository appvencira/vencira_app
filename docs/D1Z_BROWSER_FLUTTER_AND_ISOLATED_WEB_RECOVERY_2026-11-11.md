# VENCIRA — D1-Z: prueba real de navegador y recuperación de contenedor web en laboratorio

Fecha: 11/11/2026. Destino exclusivo: `main`. **IMPLEMENTADO, NO EJECUTADO. No atribuir PASS.**

## Motivo

D1-W certificó la entrega de artefactos Flutter Web por Nginx y Caddy a nivel HTTP, pero no el arranque en un navegador. D1-X/Y certificaron estructura de Caddy cargada y disponibilidad de imágenes actuales, no rollback de una versión anterior. D1-Z incorpora un navegador Chromium automatizado y una recuperación de servicio web en la misma infraestructura sintética, sin tocar DEV.

## Componentes

- `scripts/main_d1z_browser_web_recovery_isolated.sh`: evolución de D1-W. Construye Flutter Web desde el repositorio, Gunicorn/Django candidato y PostgreSQL 17 en una red `--internal`, Nginx y Caddy 2.11.7 con certificado sintético `d1z-proxy`. Realiza `pg_dump` y `pg_restore` de un esquema sintético y valida los controles HTTP existentes. Sin puertos host publicados, sin acceso a volumen de DEV, sin migraciones persistentes. Elimina red, contenedores, imágenes temporales y artefactos al salir, verificando identidad de los tres contenedores DEV.
- `scripts/main_d1z_flutter_caddy_probe.py`: GET de HTML/JS y rutas API, CSRF, cookies Secure, CA desconocida rechazada, derivados del D1-W PASS.
- `scripts/Dockerfile.d1z-playwright`: ejecuta `npm install playwright@1.56.1` sobre la imagen oficial `mcr.microsoft.com/playwright:v1.56.1-noble`. La imagen se construye en la red de build Docker, después se ejecuta en la red del laboratorio `--internal`. No recibe contraseña de BD ni variables de Django.
- `scripts/main_d1z_chromium_smoke.js`: abre `https://d1z-proxy/` en Chromium de verdad, acepta únicamente el certificado sintético del laboratorio (`ignoreHTTPSErrors`, **no** aplicable a DEV), espera a que se inserte `flutter-view`, comprueba `fetch("/api/health/")` del navegador sobre HTTPS y falla ante errores JavaScript observados. No automatiza credenciales de usuarios ni demuestra un flujo completo de login, calendario, ficha o notificaciones.
- Tras el primer PASS del navegador, elimina y recrea **solo Nginx del laboratorio** con los **mismos artefactos web**, espera respuesta HTTP 200 y vuelve a ejecutar Chromium. Esto prueba que el servicio es recuperable desde esos artefactos, pero **no** que una imagen antigua pueda restaurarse tras una migración de BD o revertirse la configuración Caddy operativa.

El primer navegador puede detectar errores reales de la app o de recursos externos bloqueados por el aislamiento. Mantener FAIL y diagnóstico por fase hasta identificar causa, sin silenciar pruebas críticas.

## Gate agrupado Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d1z_browser_web_recovery_isolated.sh
bash scripts/main_d1z_browser_web_recovery_isolated.sh
echo "D1Z_SHELL_RESULT=$?"
```

Criterios: `D1Z_FLUTTER_RELEASE_BUILD=PASS`, `D1Z_CADDY_TLS_HTTP_CONTRACT=PASS`, `D1Z_CHROMIUM_FLUTTER_VIEW=PASS`, `D1Z_CHROMIUM_SAME_ORIGIN_API=PASS`, `D1Z_CHROMIUM_JS_ERRORS=NONE`, `D1Z_CHROMIUM_SMOKE=PASS`, `D1Z_CHROMIUM_RENDER_GATE=PASS`, `D1Z_WEB_RECOVERY_RESTART=PASS`, `D1Z_CHROMIUM_AFTER_WEB_RESTART=PASS`, `D1Z_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, `D1Z_DEV_CONTAINERS_UNCHANGED=OK`, `D1Z_EPHEMERAL_CLEANUP=DONE` y `D1Z_RESULT=0`. El script depende de poder obtener imágenes Flutter, Nginx, Caddy y Playwright cuando no están ya disponibles.

## Excepciones y riesgos pendientes

**Incluso con PASS**, la prueba es un *smoke test visual real* en Chromium, pero no inspección manual de las pantallas ni pruebas de login/calendario/ficha, ni ejecución con un certificado CA validado operacional. El segundo arranque de Nginx recupera la misma versión de Flutter, no revierte a una imagen web anterior.

El rollback de DEV sigue pendiente: conservar y validar imágenes/versiones anteriores, manifiestos Caddy y Compose previos, prueba de recuperación íntegra sobre una copia real O5 después de cualquier actualización candidata, política RPO/RTO y control de escrituras. Los gates D1-N y D1-X proporcionan evidencias parciales de restauración, **no** justifican un rollback sobre volumen DEV. Para aumentar cobertura de navegador podrían añadirse recorridos e2e autenticados con usuarios sintéticos en laboratorio, sin pedir credenciales DEV.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_LIVE_RESTORE_EXECUTED=NO
```
