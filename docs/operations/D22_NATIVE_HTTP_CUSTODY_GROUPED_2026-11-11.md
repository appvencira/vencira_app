# D22 — integración HTTP de emisor con custodia MFA del servidor (sin release)

Fecha: 11/11/2026. Rama: **main**. Estado: **implementado; pendiente de gate VPS**.

## Alcance de la fase agrupada

D21 demostró en 65 tests PG17 un emisor candidato capaz de verificar contraseña/TOTP, leer claves MFA desde el servidor y revocar sesiones con recuperación. D22 añade la pieza que faltaba entre el contrato JSON y el emisor: **vistas HTTP Django ejecutadas con el cliente de pruebas sobre PG17 efímero**, preservando la ausencia de rutas operativas.

1. `backend/native_mobile_service/test_d22_http_views.py` (`413c5f3e`): vistas de password/MFA, recuperación password/MFA, revocación y `me`. Invocan `native_server_custody_issuer.py`, no admiten claves MFA ni tiempos enviados por el cliente. El parser común `native_http_contract.py` impone cuerpo exacto y JSON sin duplicados; no hay cookies ni caché en respuestas. Todas las vistas deniegan si falta cualquiera de `VENCIRA_ENV=test`, candidato explícito, bearer deshabilitado, URLconf aislado `test_d22_urls` y flag efímero `VENCIRA_D22_HTTP_LAB=1`. Exigen `request.is_secure()`, no admiten Cookie, Origin ni Referer, ni Authorization en POST.
2. `backend/native_mobile_service/test_d22_urls.py` (`4e65100f`): URLconf **exclusivamente de laboratorio**. No se importa desde `backend/config/urls.py`.
3. `backend/native_mobile_service/test_d22_http_pg17.py` (`3bfbec76`): cinco tests PG17 con usuario sintético, secreto MFA y keyring efímeros: emisión servidor + MFA por HTTP, recuperación MFA con revocación de token anterior y revoke posterior, bloqueo de HTTP no seguro/cookie/origin/referer/bearer, clave inválida y JSON duplicado rechazados, ausencia de rutas operativas y flag off 404. No prueba aún autorización por workspace.
4. `scripts/native_i8k_recovery_http_pg17_isolated.sh` (`1e45497f`): añade el módulo de test D22 a la batería existente de PostgreSQL17 efímero y emite `NATIVE_I8K_D22_SERVER_CUSTODY_HTTP_PG17=PASS` solo tras el éxito global.
5. `scripts/main_d22_native_http_custody_grouped_gate.sh` (`6f77b4ca`): una sola ejecución comprueba Git limpio/sincronizado, revisión estática de rutas de D18 y suite I8-K+D22, sin deployments ni migraciones LIVE.

## Validación única en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d22_native_http_custody_grouped_gate.sh
echo "D22_SYNTAX=$?"
sudo -v
bash scripts/main_d22_native_http_custody_grouped_gate.sh
echo "D22_SHELL_RESULT=$?"
git status --short
```

Los marcadores determinantes:
```text
D22_MAIN_CLEAN=PASS
D22_PRODUCTION_ROUTE_FENCE=PASS
D22_SERVER_CUSTODIED_HTTP_ISSUANCE=PASS
D22_HTTP_RECOVERY_ATOMIC_REVOKE=PASS
D22_HTTP_CLIENT_METADATA_FENCED=PASS
D22_KEY_FAILURE_AND_DUPLICATE_JSON_DENIED=PASS
D22_OPERATIONAL_ROUTES_ABSENT=PASS
NATIVE_I8K_D22_SERVER_CUSTODY_HTTP_PG17=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D22_SERVER_CUSTODY_HTTP_PG17=PASS
D22_OPERATIONAL_ISSUER_ENABLED=NO
D22_WORKSPACE_AUTHORIZATION_GATE=NOT_VERIFIED
D22_RESULT=0
D22_SHELL_RESULT=0
```

**No hay D22 PASS hasta recibir marcadores del VPS.** El laboratorio prueba la pila de vistas HTTP Django con claves de servidor de prueba y sesiones desechables; `secure=True` simula la solicitud HTTPS en el test client y **no** verifica un handshake TLS de red, sin tocar DEV, sin instalar endpoints ni migrar datos reales. Una prueba del cliente Flutter por HTTPS ya figura en D18, pero **no utiliza estas nuevas vistas D22**; se requiere un gate específico antes de atribuir compatibilidad cliente→D22.

## Bloqueos reales de salida

Todavía falta integrar y comprobar autorización por workspace y objeto, custodia y rotación operativa de las claves de token/HMAC y MFA, aislamiento de DRF bearer por vista, topología de proxy confiable real, concurrencia y pruebas de fallos en el protocolo HTTP candidato, restauración/rollback de migraciones de esquema operativo, conexión del APK Android real y autorización explícita. Un gate con `D22_RESULT=0` no habilita producción.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`

## Ejecución VPS — D22 PASS (11/11/2026)

El operador ejecutó el gate `scripts/main_d22_native_http_custody_grouped_gate.sh` en el checkout de main. Marcadores: `D22_MAIN_CLEAN=PASS`, `D18_OPERATIONAL_URLCONF_LAB_ABSENT=PASS`, `D18_NATIVE_BEARER_PRODUCTION_OFF=PASS`, `D18_REAL_ANDROID_ISSUER_UNWIRED=PASS`, `D18_STARTUP_PROTECTED_FENCE=PASS`, `D18_ISSUANCE_RECOVERY_CHECKPOINTS=PASS`, `D18_BROWSER_FALLBACK_RETAINED=PASS`, `D18_CLIENT_CONTRACT_DEFINITIONS=PASS`, `D18_STATIC_FENCE_GATE=PASS`, `D22_PRODUCTION_ROUTE_FENCE=PASS`. Se generó imagen desechable, red interna PG17, migraciones de prueba en paridad y base temporal.

Django informó **70 tests ejecutados, OK**, incluyendo `D22_HTTP_RECOVERY_ATOMIC_REVOKE=PASS`, `D22_SERVER_CUSTODIED_HTTP_ISSUANCE=PASS`, `D22_KEY_FAILURE_AND_DUPLICATE_JSON_DENIED=PASS`, `D22_OPERATIONAL_ROUTES_ABSENT=PASS`, `D22_HTTP_CLIENT_METADATA_FENCED=PASS`. Regresiones: `NATIVE_I8K_D22_SERVER_CUSTODY_HTTP_PG17=PASS`, `NATIVE_I8K_D21_SERVER_CUSTODY_ISSUER_PG17=PASS`, `NATIVE_I8K_D20_ISSUER_REVIEW_GATE=PASS`, `NATIVE_I8K_NATIVE_JSON_CONTRACT=PASS`, `NATIVE_I8K_NO_PUBLIC_ISSUER=PASS`, `NATIVE_I8K_NO_MFA_DENIAL_POLICY=PASS`, `NATIVE_I8K_ATOMIC_RECOVERY_CORE=PASS`, `NATIVE_I8K_RECOVERY_HTTP_JSON=PASS`, `NATIVE_I8K_RECOVERY_ENDPOINTS_ABSENT=PASS`, `NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS`, `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK`, `NATIVE_I8K_LOCAL_RESULT=0`, `D22_SERVER_CUSTODY_HTTP_PG17=PASS` y `D22_RESULT=0`.

El transcript no incluye `D22_SHELL_RESULT` separado; sí el resultado final del gate `D22_RESULT=0`. El marcador `NATIVE_I8K_FLUTTER_GATE=NOT_RUN_SEPARATE` es esperado. Permanecen `D22_OPERATIONAL_ISSUER_ENABLED=NO`, `D22_WORKSPACE_AUTHORIZATION_GATE=NOT_VERIFIED`, `D22_DEPLOY_EXECUTED=NO`, `D22_LIVE_MIGRATIONS_EXECUTED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**D22 PASS para la pila HTTP de pruebas de Django + PG17 y custodia server-side de claves MFA; no prueba un enlace TLS de red con estas nuevas vistas, permisos por workspace, integración con el APK real ni condiciones de despliegue.** No repetir D22 sin cambios que afecten el contrato o estos componentes. Priorizar el acceso limitado por workspace y las pruebas cruzadas de autorización, sin exponer endpoints de laboratorio.
