# VENCIRA — D1-P HTTPS público de DEV existente (10/11/2026)

**Estado: publicado en `main`, NO EJECUTADO.** D1-O superado con `D1O_RESULT=0` en el alcance PostgreSQL17 sintético, Django tests HTTP y Flutter web. No confundir con HTTPS real.

## Contrato

`scripts/main_d1p_existing_dev_https_readonly.sh` consulta exclusivamente `https://dev.vencira.es` con `curl` y CA del sistema, sin `--insecure`, sin seguir redirecciones, sin POST y sin autenticación. Comprueba código 200 de `/api/health/`, `/api/ready/`, `/accounts/login/` y `/api/v1/csrf/`; comprueba códigos 404 de **cuatro rutas nativas de muestra**. Abortará si existe proxy HTTP/HTTPS en el entorno para evitar mezclar rutas. No captura cuerpos, cookies, credenciales, certificados ni encabezados privados en el log.

**Importante:** comprueba el DEV **actual ya desplegado**, no la imagen candidata de `main`; no es una prueba del contrato HTTPS del candidato, ni de todas las rutas nativas, ni prueba de login navegador, CSRF POST, permisos de ficha, adjuntos o configuración interna de Caddy/Compose. Los códigos 404 de una muestra no prueban que no haya otros alias. Una respuesta 403/405 de una ruta exige investigar, no reetiquetar a PASS.

## Termius — una ejecución

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
bash scripts/main_d1p_existing_dev_https_readonly.sh
echo "D1P_SHELL_RESULT=$?"
```

Todos los cambios se integran directamente en `main`. No iniciar despliegue DEV ni migrar PostgreSQL persistente. Requiere `D1P_TLS_TRUSTED_CA_AND_HEALTH=PASS`, `D1P_READY_HTTP=PASS`, `D1P_LOGIN_GET=PASS`, `D1P_CSRF_GET=PASS`, `D1P_SAMPLED_NATIVE_ROUTES_404=PASS`, `D1P_EXTERNAL_HTTPS_EXISTING_DEV=PASS`, `D1P_RESULT=0` y `D1P_SHELL_RESULT=0` antes de declarar este subgate superado. El script declara explícitamente `D1P_CANDIDATE_HTTPS_TESTED=NO`.

Siguientes tareas independientes: inspección de solo lectura de configuración Compose/Caddy, revisión de plan de rollback imagen+BD y tests de permisos de ficha/adjuntos; **siempre** aprobación expresa para promoción posterior.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
```
