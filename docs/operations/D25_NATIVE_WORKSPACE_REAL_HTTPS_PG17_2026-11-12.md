# D25 — Flutter ↔ Django HTTPS real para renovación paginada, PG17 aislado

Fecha: 12/11/2026. Rama: **main**. Estado: **implementado; gate VPS pendiente de ejecutar**.

## Alcance

D24 aprobó el gate PG17 de autorización/concurrencia y el contrato Flutter de paginación, pero indicó `D24_ACTUAL_TLS_NETWORK_GATE=NOT_RUN`. D25 ejecuta una conexión de red TLS real entre el cliente Dart/Flutter `IOClient` y el servidor Django HTTPS interno, conservando el mismo flujo de autenticación candidata **server-custodial** de D21 y el lector paginado autorizado de D24.

El laboratorio crea una **red Docker internal**, PostgreSQL17 desechable con tmpfs y migraciones aisladas, servidor HTTPS con certificado autofirmado de un día para `dev.vencira.es` (resuelto **solo dentro de la red Docker de laboratorio**), y un cliente Flutter también interno. Nunca se publica `-p` ni se configura Caddy o Django DEV. Se usa un usuario sintético MFA y un workspace con 75 renovaciones asignadas; el backend emite un bearer de prueba tras password+TOTP. El token se transmite al cliente por un archivo temporal montado de solo lectura, no por una variable de entorno; el contenedor Flutter no obtiene credenciales PG ni la clave MFA.

### Cambios publicados en GitHub

- `scripts/native_i8k_https_server.py`, commit `47308c94`: **solo** si `VENCIRA_D25_WORKSPACE_TLS_LAB=1` junto con flags existentes de lab, selecciona `native_mobile_service.test_d22_urls` para servir login, MFA, `/api/v1/mobile/workspaces/<uuid>/renewals/` y `me` a través de un socket HTTPS real. En todos los demás casos conserva el URLconf I8-K original. `config.urls` no cambia.
- `clients/flutter/test/native_d25_workspace_real_https_pg17_test.dart`, commits `25f56b97` y `148d9776`: usa socket real, CA explícita, verifica rechazo de CA no confiable y de SNI incorrecto, pasa por el transporte Flutter real con bearer y comprueba 50+25 renovaciones sin PII, así como rechazo de lectura de otro workspace y cierre de sesión ante 401. La prueba permanece aislada por flags D25.
- `scripts/main_d25_native_workspace_real_https_pg17_isolated.sh`, commit `7eb94d4c`: configura imagen Django efímera, PG17, servidor HTTPS, `flutter analyze` y `flutter test` por red interna, limpieza de red/containers/volúmenes/material temporal y comparación de identidades DEV.
- `scripts/main_d25_native_workspace_grouped_tls_gate.sh`, commits `7597caea` y `c30d61d0`: comprueba checkout limpio y sincronizado con origin/main, sintaxis del laboratorio, AST Python de bridge sin crear pycache, D18 release fence y gate HTTPS D25; registra `D25_RESULT=0` solamente si todo termina cero.

## Una única ejecución en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d25_native_workspace_grouped_tls_gate.sh
bash -n scripts/main_d25_native_workspace_real_https_pg17_isolated.sh
echo "D25_SYNTAX=$?"
sudo -v
bash scripts/main_d25_native_workspace_grouped_tls_gate.sh
echo "D25_SHELL_RESULT=$?"
git status --short
```

### Evidencias requeridas (todavía no observadas)

```text
D25_MAIN_CLEAN=PASS
D25_SERVER_SYNTAX=PASS
D25_RELEASE_FENCE=PASS
D25_DISPOSABLE_IMAGE=OK
D25_DOCKER_NETWORK_INTERNAL=PASS
D25_PG17_EPHEMERAL_READY=PASS
D25_EPHEMERAL_MIGRATIONS=PASS
D25_SERVER_READY=PASS
D25_ANALYZE=PASS
D25_SERVER_ISSUED_SYNTHETIC_FIXTURE=PASS
D25_TLS_UNTRUSTED_CA_AND_HOST_MISMATCH_DENIED=PASS
D25_REAL_TLS_WORKSPACE_PAGINATION_75=PASS
D25_REAL_TLS_CROSS_WORKSPACE_DENIED=PASS
D25_REAL_FLUTTER_TLS_WORKSPACE_GATE=PASS
D25_REAL_TLS_NO_PUBLIC_PORTS=PASS
D25_OPERATIONAL_ROUTES_ENABLED=NO
D25_DEV_CONTAINERS_UNCHANGED=OK
D25_BOUNDARY_RESULT=0
D25_REAL_HTTPS_PG17_FLUTTER=PASS
D25_PUBLIC_OPERATIONAL_ENDPOINT_ENABLED=NO
D25_RESULT=0
D25_SHELL_RESULT=0
```

## Prohibiciones y límites

`MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No se despliega el emisor, no se añaden endpoints móviles operativos, no se hacen migraciones/restores reales, no se modifican contenedores DEV, no se activa firma de APK Android. El certificado del laboratorio **no es un certificado de producción**, y `dev.vencira.es` en la prueba **no contacta al dominio público**: es un alias DNS interno a Docker. Con resultado 0 se habrá validado TLS real contra la versión D22–D24 del endpoint de prueba, no la cadena de despliegue Android ni la topología proxy pública.

Paginación offset D24 tiene límite 10000 y puede sufrir omisiones/repeticiones si los registros cambian entre páginas. El laboratorio prueba aislamiento por workspace pero no escrituras/adjuntos ni races de autorizaciones mientras los bytes salen por socket. No se debe interpretar como autorización de producción.
