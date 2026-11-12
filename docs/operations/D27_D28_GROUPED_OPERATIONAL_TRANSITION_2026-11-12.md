# VENCIRA D27–D28 — transición controlada del emisor operativo y Android

Fecha: 12/11/2026. Rama exclusiva: `main`.

**Estado real: fase 0 de contrato y regresión IMPLEMENTADA; no validada todavía en VPS. El emisor operacional y la integración Android siguen PENDIENTES.**

## Resultado de la revisión de código

`backend/native_mobile_service/native_server_custody_issuer.py` compone contraseña y MFA bajo claves custodiadas por el servidor, pero invoca `candidate_two_step_issuer`, `candidate_recovery_issuer` y `candidate_challenge_store._require_lab`. Los métodos rechazan el entorno fuera de test. `native_operational_issuer_gate.assert_operational_issuer_unavailable()` niega incluso con todos los flags activados. `backend/config/urls.py` no registra rutas nativas de producción y `VENCIRA_NATIVE_BEARER_ENABLED = False` permanece fijo. En Flutter, `NativeAndroidStartupBoundary` protege el arranque de Android, pero `NativeLoginScreen` y `NativeFirstIssuanceEntry` no están conectados a `main.dart`.

No sería seguro ni correcto copiar rutas `test_d22_urls` al router público o cambiar flags. Para cumplir la opción B hay que construir una implementación explícita de emisor de producción, probarla contra PostgreSQL17 y staging, y entonces conectar Flutter.

## Primer bloque técnico publicado

- `scripts/main_d27d28_operational_boundary_audit.py` (commit `1f3ee0b0`): auditoría de fuentes y comportamiento **read-only**. Valida sintaxis Python del router, settings y emisor; comprueba rutas nativas operativas ausentes, bearer desactivado, issuer con hard deny, `NativeAndroidStartupBoundary` activo y ninguna UI/gateway nativa conectada prematuramente. Solo presenta `D27D28_OPERATIONAL_FENCE_INVARIANTS=PASS` si la política actual sigue cerrada.
- `tests/test_d27d28_operational_boundary_audit.py` (commit `7b5b4066`): regresiones unitarias y mutaciones de las fuentes. Comprueba configuración incompleta, Python inválido, URLs de test insertadas, cambio de bearer, anulación del hard deny y enlaces prematuros al login desde Android.
- `scripts/main_d27d28_grouped_contract_gate.sh` (commit `5a95f2ab`): un solo gate de `main` limpia que ejecuta tests, auditoría y barrera heredada D18 sin Docker, sin migraciones y sin escribir pycache (Python `-B`). **El resultado 0 prueba el bloqueo correcto, no que D27–D28 estén funcionalmente completadas.**

## Comprobación en Termius, una sola vez

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d27d28_grouped_contract_gate.sh
bash scripts/main_d27d28_grouped_contract_gate.sh
echo "D27D28_CONTRACT_RESULT=$?"
git status --short
```

Marcadores previstos, NO observados todavía:

```text
D27D28_MAIN_CLEAN=PASS
D27D28_MUTATION_FENCES=PASS
D27D28_OPERATIONAL_FENCE_INVARIANTS=PASS
D27D28_CODE_AUDIT=PASS
D27D28_LEGACY_RELEASE_FENCE=PASS
D27D28_OPERATIONAL_ISSUER_IMPLEMENTED=NO
D27D28_ANDROID_NATIVE_LOGIN_CONNECTED=NO
D27D28_PHASE0_CONTRACT=PASS
D27D28_RESULT=0
D27D28_CONTRACT_RESULT=0
```

## Trabajo pendiente en este mismo macrogrupo

**D27 implementación real:** nuevo emisor no-lab (no wrapper del emisor candidato), proveedores de secretos de servidor, comprobación de contraseñas y MFA, challenges y emisión/refresh atómicos, scopes multiworkspace, auditoría, antiabuso, revocación y recovery en PG17. Diseño de URLs operativas mínimo y **separación verificable** de endpoints `test_*`. Los permisos de publicación permanecen bloqueados durante construcción y ensayos.

**D28 integración real:** construir coordinador de sesiones y login MFA desde `main.dart` solo después de completar D27 y ensayar credenciales de staging. Conservar Keystore/vault protegido, journaling, revocación, detección de reinicio, no-replay y cursor de D26. Gate final del macrogrupo con Flutter analyze, tests y HTTPS real. No distribuir APK ni migrar DB LIVE.

**No hay todavía aprobación del macrogrupo D27–D28 para release.** `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Gate VPS fase 0 — PASS (12/11/2026)

El operador ejecutó `scripts/main_d27d28_grouped_contract_gate.sh` desde checkout limpio y observó `Ran 5 tests in 0.016s; OK`, `D27D28_MUTATION_FENCES=PASS`, `D27D28_OPERATIONAL_FENCE_INVARIANTS=PASS`, `D27D28_CANDIDATE_BACKEND_REUSED_FOR_PRODUCTION=NO`, `D27D28_CODE_AUDIT=PASS`, `D18_STATIC_FENCE_GATE=PASS`, `D27D28_LEGACY_RELEASE_FENCE=PASS`, `D27D28_PHASE0_CONTRACT=PASS`, `D27D28_RESULT=0`, `D27D28_CONTRACT_RESULT=0`. `git status --short` vacío. Se confirman expresamente `D27D28_OPERATIONAL_ISSUER_IMPLEMENTED=NO`, `D27D28_ANDROID_NATIVE_LOGIN_CONNECTED=NO`, `D27D28_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Cierre: solo FASE 0 PASS (contrato/mutaciones)**. Sigue pendiente implementar y validar D27 emisor operacional y D28 Android real. No asignar un estado PASS a la macrofase completa.

## D28 primera implementación de composición nativa, sin habilitar la aplicación (12/11/2026)

La fase 0 de seguridad ha sido validada en VPS (`D27D28_RESULT=0`, 5/5). En lugar de repetir auditorías, la siguiente entrega introduce **comportamiento Flutter reutilizable**:

- `clients/flutter/lib/api/native_mobile_entry_router.dart`, commit `446df657`: selector de un solo uso de flujo de autenticación. Comparte estrictamente `NativeMobileStartupGate`, `NativeSessionFence`, vault, journal y los controladores G10/G9-B existentes. En dispositivo limpio selecciona solo `NativeFirstIssuanceEntry`; con refresh huérfano o marcador durable selecciona solo `NativeMobileRecoveryEntry`; ante corrupción, dependencias distintas o inspección duplicada bloquea y revoca la sesión, sin hacer fallback. No crea HTTP ni acepta claves de usuarios.
- `clients/flutter/test/native_d28_mobile_entry_router_test.dart`, commit `4eec0b1a`: 4 tests de estado limpio, refresh huérfano, marcador corrupto y dependencia distinta. No simulan autorización del emisor; verifican selección local y cierre del fence antes de solicitudes.
- `scripts/main_d27d28_phase1_router_grouped_gate.sh`, commit `8c0e171b`: valida `main` limpio, gate de seguridad D27–D28 anterior, compara identidades de contenedores DEV, comprueba capacidad de disco temporal y realiza `flutter analyze` junto con tests router, boundary Android y recuperación I8-L en Docker efímero, sin instalación de APK ni despliegue.

**Estado:** código publicado pero **gate de fase 1 PENDIENTE DE VALIDACIÓN en VPS**. Ni `main.dart` ni `config.urls` se modifican, y los componentes no pueden iniciar una sesión por sí mismos. Emisor operativo D27 sigue pendiente.

### Una única ejecución Termius para fase 1

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
sudo -v
bash scripts/main_d27d28_phase1_router_grouped_gate.sh
echo "D27D28_P1_RECHECK_RESULT=$?"
git status --short
```

Marcadores a obtener, **no observados todavía**:

```text
D27D28_P1_MAIN_CLEAN=PASS
D27D28_P1_HARD_RELEASE_FENCES=PASS
D27D28_P1_DEV_IDENTITY=PASS
D27D28_P1_FLUTTER_TEMP_CAPACITY=PASS
D27D28_P1_FLUTTER_ROUTER_REGRESSION=PASS
D27D28_P1_NATIVE_FIRST_VS_RECOVERY_ROUTING_CANDIDATE=YES
D27D28_P1_DEV_CONTAINERS_UNCHANGED=OK
D27D28_P1_OPERATIONAL_ISSUER_ENABLED=NO
D27D28_P1_ANDROID_MAIN_AUTH_ENABLED=NO
D27D28_P1_RESULT=0
D27D28_P1_RECHECK_RESULT=0
```

**Límites:** el router no implementa endpoints operativos, MFA de producción ni login real en `main.dart`. La autorización de publicación se mantiene denegada. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Primera ejecución D28 fase 1 — error de dependencias `pub.dev` (12/11/2026)

El operador informa `D27D28_P1_HARD_RELEASE_FENCES=PASS`, `D27D28_P1_DEV_IDENTITY=PASS`, `D27D28_P1_FLUTTER_TEMP_CAPACITY=PASS` y `D27D28_P1_DEV_CONTAINERS_UNCHANGED=OK`. La prueba **no** llegó a `flutter analyze` ni a los tests de navegación nuevos: `flutter pub get` terminó `Got socket error trying to find package flutter_local_notifications at https://pub.dev`, salida `D27D28_P1_RESULT=69`.

Causa directa verificada en el script anterior: la etapa que resolvía paquetes Flutter arrancaba con Docker `--network none` y un caché `/pub` recién creado, una combinación que impide cualquier descarga. Este fallo no prueba un problema con la dependencia `flutter_local_notifications` ni con el código del router.

**Corrección publicada en `main`, commit `daa735e3`:** se separan tres etapas. 1) Copia del código desde montaje de origen solo lectura a volumen efímero sin red. 2) `flutter pub get --offline` usando volumen público persistente `vencira-d27d28-public-pubcache-flutter344`; si falta un paquete, se permite a **este paso exclusivamente** Docker bridge con tres intentos acotados para completar dependencias públicas. Si todas las descargas fallan, código 69 y `D27D28_P1_DEPENDENCY_RESOLUTION=FAIL_NETWORK_OR_PUBDEV`, sin aparentar pruebas PASS. 3) `flutter analyze --no-pub` y `flutter test --no-pub` exclusivamente sin red, sobre volumen temporal de compilación ≥1 GiB. Solo el volumen público de caché de paquetes persiste; los volúmenes de trabajo y `/tmp` se eliminan al finalizar. Las credenciales de producción, claves MFA y tokens no participan en el gate.

**D28 fase 1 permanece PENDIENTE.** Repetir el mismo gate agrupado tras actualizar `main`. Exigir `D27D28_P1_DEPENDENCY_RESOLUTION=OFFLINE_PASS` o `ONLINE_PASS`, `D27D28_P1_FLUTTER_ROUTER_REGRESSION=PASS` y `D27D28_P1_RESULT=0`. Hasta entonces no se ha validado la nueva lógica Flutter.

## D28 fase 1 — PASS observado en VPS (12/11/2026)

Tras corregir resolución de dependencias `pub.dev` y caché, el operador confirma: `flutter analyze` → **No issues found** (14.0s); `flutter test` → **16/16 All tests passed!**. Incluye las 4 nuevas pruebas de `native_d28_mobile_entry_router_test.dart`, las pruebas de `native_android_startup_boundary_test.dart` y regresiones HTTP/recovery existentes. Marcadores finales `D27D28_P1_FLUTTER_ROUTER_REGRESSION=PASS`, `D27D28_P1_NATIVE_FIRST_VS_RECOVERY_ROUTING_CANDIDATE=YES`, `D27D28_P1_OPERATIONAL_ISSUER_ENABLED=NO`, `D27D28_P1_ANDROID_MAIN_AUTH_ENABLED=NO`, `D27D28_P1_DEV_CONTAINERS_UNCHANGED=OK`, `D27D28_P1_RELEASE_AUTHORIZED=NO`, `D27D28_P1_RESULT=0`. El extracto aportado no incluye `D27D28_P1_RECHECK_RESULT` independiente ni el marcador de resolución de dependencias; no se inventan.

**D28 fase 1 CERRADA PASS (router candidato), pero D28 operacional NO cerrada.** No hay login conectado a `main.dart`; D27 issuer operacional tampoco implementado. Siguiente prioridad: implementación segura de D27 y validación en staging aislado sin rutas públicas. Guardas `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Sincronización de continuidad — D27 fase 3 (12/11/2026)

Se incorpora aquí el estado de D27 posterior al PASS del router D28, para evitar que este documento dé a entender que el núcleo independiente aún no existe. La fuente primaria de resultados y límites es [D27 núcleo independiente](D27_INDEPENDENT_PASSWORD_MFA_CORE_PG17_2026-11-12.md).

- **Código en `main`:** `native_operational_issuer_core.py` implementa contraseña→reto `oc1`→MFA→tokens opacos, validación de acceso, refresh one-time, revocación por replay/dispositivo y reto de recuperación `or1` con revocación atómica de cuenta.
- **Evidencia registrada por el operador:** gate PG17 desechable **92/92 tests PASS** (9 pruebas D27) en la fase 3. Esta es validación del núcleo en test, no HTTP ni producción.
- **Restricciones verificables por código:** `_context()` exige `VENCIRA_ENV=test`, app candidata habilitada, bearer operacional desactivado, custodia sintética configurada y MFA disponible. El módulo no expone rutas operativas.
- **D28:** selector Flutter candidato PASS 16/16 en fase 1. `main.dart` sigue sin conectar autenticación nativa operativa.

### Siguiente corte agrupado: contrato HTTPS de laboratorio, sin activar rutas

Antes de implementar transporte, revisar el contrato de cuatro operaciones de emisión/recuperación (`begin_verified_password`, `complete_verified_mfa`, `begin_recovery_password`, `complete_recovery_mfa`) y las tres operaciones de sesión (`validate_verified_access`, `rotate_verified_refresh`, `revoke_verified_device`). El contrato debe especificar y probar:

1. Negación uniforme y no enumeración de cuentas; límites de tamaños, métodos, cuerpo JSON, respuestas HTTP y ausencia de datos sensibles en logs.
2. HTTPS verificado de extremo a extremo, CSRF/cookies si aplican, `Origin`/host, y tratamiento seguro de IP del proxy *sin confiar en X-Forwarded-For del cliente*.
3. Reutilización de retos, expiración, fallos después del commit (respuesta perdida), refresh repetido y revocación de cuenta/dispositivo sin crear sesiones ambiguas.
4. Custodia de secretos y migraciones únicamente en PG17 aislado; auditoría, retención, concurrencia y limpieza del laboratorio.
5. Validación de contrato Flutter contra una implementación exclusivamente LAB. No registrar `urls.py` productiva ni conectar `main.dart` hasta disponer de gates independientes de operación y release.

**Criterio de cierre siguiente:** código + tests del transporte LAB + gate del SHA final con pruebas HTTP/PG17, fallos de red y barreras de publicación. Un diseño o preflight por sí solos no cuenta como PASS funcional.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27_OPERATIONAL_HTTP_ISSUER_ENABLED=NO
D28_ANDROID_MAIN_AUTH_ENABLED=NO
D27D28_RELEASE_AUTHORIZED=NO
```

## D27 HTTP-LAB fase inicial — código publicado, gate PG17 pendiente (12/11/2026)

En `main` se han incorporado `backend/native_mobile_service/test_d27_http_views.py` y `test_d27_http_urls.py`. Son rutas HTTP **solo para el URLconf de pruebas**, no incluidas en `config.urls`. Exigen `VENCIRA_ENV=test`, `VENCIRA_D27_HTTP_LAB=1`, app candidata activa, bearer operacional desactivado, HTTPS, ausencia de cookies, `Origin`, `Referer` y cabeceras proxy aportadas por el cliente. La IP es únicamente `REMOTE_ADDR` directo del laboratorio. El contrato JSON estricto reutiliza `native_http_contract`.

El puente consume el núcleo D27 independiente para contraseña/MFA, recuperación `or1`, validación access, refresh y revocación. **No es un transporte de producción** ni sustituye el diseño de IP/proxy, custodia, auditoría y fallos de respuesta.

Se añadió `test_d27_http_pg17.py` al runner `scripts/native_i8k_recovery_http_pg17_isolated.sh`, con casos de emisión–refresh–logout, recuperación global y rechazo de HTTP no seguro/metadatos/JSON duplicado/rutas operativas. **No se ha ejecutado todavía en VPS**; no declarar PASS por la mera integración en `main`.

### Gate agrupado del candidato

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
sudo -v
bash scripts/main_d27_independent_issuer_pg17_grouped_gate.sh
echo "D27_HTTP_LAB_RECHECK_RESULT=$?"
git status --short
```

Exigir `D27_LAB_HTTP_ISSUE_ROTATE_REVOKE_PG17=PASS`, `D27_LAB_HTTP_ACCOUNT_RECOVERY_PG17=PASS`, `D27_LAB_HTTP_TLS_AND_PUBLIC_ROUTE_FENCES_PG17=PASS`, `NATIVE_I8K_LOCAL_RESULT=0` y `D27_P2_RESULT=0`. No avanzar a integración Android si falla alguno.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27_OPERATIONAL_HTTP_ISSUER_ENABLED=NO
D28_ANDROID_MAIN_AUTH_ENABLED=NO
D27D28_RELEASE_AUTHORIZED=NO
```

## D27 HTTP-LAB — PG17 95/95 PASS informado por operador (12/11/2026)

Tras incorporar `test_d27_http_pg17.py` al runner I8-K, el operador ejecutó el gate agrupado sobre `main` y aportó:

```text
D27_P2_MAIN_CLEAN=PASS
D27_P2_INDEPENDENT_AST_AND_LAB_FENCE=PASS
D27D28_PHASE0_CONTRACT=PASS
D27_P2_RELEASE_BARRIERS=PASS
NATIVE_I8K_PG17_READY=OK
NATIVE_I8K_MIGRATION_PARITY=OK
NATIVE_I8K_DISPOSABLE_SCHEMA=OK
Found 95 test(s).
Ran 95 tests in 56.760s
OK
D27_LAB_HTTP_TLS_AND_PUBLIC_ROUTE_FENCES_PG17=PASS
D27_LAB_HTTP_ISSUE_ROTATE_REVOKE_PG17=PASS
D27_LAB_HTTP_ACCOUNT_RECOVERY_PG17=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D27_P2_PG17_ISSUER_AND_SECURITY=PASS
D27_P2_INDEPENDENT_CORE_VALIDATED=YES
D27_P2_RESULT=0
D27_P2_PRODUCTION_ISSUER_ENABLED=NO
D27_P2_ANDROID_MAIN_AUTH_ENABLED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Cierre delimitado:** adaptador HTTP D27 exclusivo del URLconf LAB y sus tres tests pasan PG17 en el runner agrupado. La salida compartida no contiene el eco externo `D27_HTTP_LAB_RECHECK_RESULT` ni el `git status --short` final; no inferirlos. No se ejecutó Flutter en este gate (`NATIVE_I8K_FLUTTER_GATE=NOT_RUN_SEPARATE`). El núcleo sigue sin ruta operacional, custodia productiva ni login Android conectado.

**Siguiente trabajo (aún NO validado):** simular pérdida de respuesta tras commit en emisión, refresh y recovery y comprobar conciliación del cliente sin reutilizar refresh ni crear sesiones ambiguas. Separar pruebas de transporte de pruebas de lógica transaccional. Mantener el bloqueo de publicación y no activar rutas de `config.urls`.

## D27 pérdida de respuesta posterior al commit — tres pruebas nuevas, pendientes de VPS (12/11/2026)

La suite `test_d27_http_pg17.py` amplía D27 HTTP-LAB con tres casos PG17, sin modificar backend operacional ni URLconf pública:

- `D27_LAB_HTTP_LOST_ISSUE_RESPONSE_FAIL_CLOSED_PG17`: emisión confirmada en servidor, respuesta descartada, segundo uso del reto rechazado y una única sesión registrada (puede quedar **huérfana** si el cliente no recibió tokens).
- `D27_LAB_HTTP_LOST_REFRESH_REPLAY_REVOKES_PG17`: refresh rotado, respuesta descartada, reintento con refresh gastado denegado y dispositivo revocado (fail-closed, pero exige recuperación en cliente).
- `D27_LAB_HTTP_LOST_RECOVERY_RESPONSE_OLD_REVOKED_PG17`: recuperación global confirmada, respuesta descartada, reto consumido sin reemisión y sesiones previas revocadas; queda una sesión nueva inaccesible al cliente hasta una recuperación posterior.

Las pruebas simulan **pérdida de respuesta en el test HTTP tras finalizar la petición**; no simulan corte TCP/TLS físico ni prueban reconexión Android. El comportamiento es deliberadamente conservador: no inventar idempotencia ni responder con credenciales nuevas ante reintentos ambiguos. Queda pendiente diseñar conciliación explícita y segura en Flutter.

Con estas tres pruebas, el runner I8-K debería detectar **98 tests** si el resto de la suite no cambia. Esta cifra es expectativa, **no PASS observado**. Repetir `scripts/main_d27_independent_issuer_pg17_grouped_gate.sh` sobre `main` limpio y exigir salida cero y los tres marcadores. La autorización de producción sigue denegada.

## D27 pérdida de respuesta: 98/98 PASS en PG17 aislado (12/11/2026)

El operador confirmó el nuevo gate `scripts/main_d27_independent_issuer_pg17_grouped_gate.sh` con `Found 98 test(s)`, `Ran 98 tests in 57.249s`, `OK` y los siguientes resultados:

```text
D27_LAB_HTTP_LOST_ISSUE_RESPONSE_FAIL_CLOSED_PG17=PASS
D27_LAB_HTTP_LOST_REFRESH_REPLAY_REVOKES_PG17=PASS
D27_LAB_HTTP_LOST_RECOVERY_RESPONSE_OLD_REVOKED_PG17=PASS
D27_LAB_HTTP_ISSUE_ROTATE_REVOKE_PG17=PASS
D27_LAB_HTTP_ACCOUNT_RECOVERY_PG17=PASS
D27_LAB_HTTP_TLS_AND_PUBLIC_ROUTE_FENCES_PG17=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D27_P2_INDEPENDENT_CORE_VALIDATED=YES
D27_P2_RESULT=0
D27_P2_PRODUCTION_ISSUER_ENABLED=NO
D27_P2_ANDROID_MAIN_AUTH_ENABLED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

No se aportaron los ecos independientes posteriores `D27_RESPONSE_LOSS_RESULT` ni `git status --short`. El runner se cerró correctamente según sus propios marcadores.

**Alcance:** simulación en test HTTP de pérdida de respuesta **después del commit**. No valida interrupciones TCP/TLS físicas, reconexión Flutter, custodia real, transporte operacional ni publicación.

**Siguiente bloque de ingeniería:** revisar la política de conciliación ya existente en Flutter; ante respuesta incierta nunca reintentar un refresh gastado ni dar por recuperada una sesión sin evidencia. Añadir pruebas sobre el almacenamiento local duradero, reinicio y decisión explícita entre primera emisión y recuperación, sin conectar `main.dart` ni rutas públicas. El PASS de Flutter deberá demostrarse por un gate separado.

## D28 — lote de conciliación por reinicio y contrato oc1/or1 publicado (12/11/2026)

Se ha incorporado en `main` un lote único de pruebas Flutter, **pendiente del gate VPS**:

- Tres nuevos casos en `native_d28_mobile_entry_router_test.dart`: emisión con respuesta perdida y marcador persistente; refresh incierto con credencial huérfana; recuperación global incierta con dos reinicios. Todos exigen `fullReauthentication`, gateway de recuperación y sesión inactiva, sin HTTP.
- Se identificó una incompatibilidad real: D27 emite `oc1` (emisión) y `or1` (recuperación), mientras los gateways Flutter solo aceptaban `lc1`. Se ampliaron los validadores **candidatos** para aceptar `lc1|oc1` exclusivamente en primera emisión y `lc1|or1` exclusivamente en recuperación, preservando rechazo cruzado y validación de entropía/codificación canónica.
- Dos tests nuevos por gateway comprueban aceptación del prefijo D27 correcto y rechazo del prefijo de la otra operación; no se altera `main.dart` ni se crea cliente HTTP.
- El gate `scripts/main_d27d28_phase1_router_grouped_gate.sh` incorpora ahora también `native_first_issuance_entry_test.dart` y `native_recovery_login_gateway_test.dart` a su `flutter analyze` + `flutter test` agrupado.

**No declarar PASS hasta ejecutar el gate sobre el SHA actualizado y observar `D27D28_P1_FLUTTER_ROUTER_REGRESSION=PASS`, `D27D28_P1_DEV_CONTAINERS_UNCHANGED=OK` y `D27D28_P1_RESULT=0`.** Las pruebas de reinicio no equivalen a TLS físico ni garantizan que la integración de puertos reales esté completa. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
sudo -v
bash scripts/main_d27d28_phase1_router_grouped_gate.sh
echo "D28_RESTART_CONTRACT_RESULT=$?"
git status --short
```

## D28 — Flutter 48/48 PASS con marcadores de reinicio y retos D27 (12/11/2026)

El operador confirmó la ejecución de `scripts/main_d27d28_phase1_router_grouped_gate.sh`: `flutter analyze` → **No issues found** (15.3 s), `flutter test` → **48/48 All tests passed**, incluyendo tres escenarios de marcador durable/reinicio tras pérdida de respuesta y cuatro casos nuevos de separación de dominios MFA (`oc1` emisión, `or1` recuperación). Los resultados de la ejecución son:

```text
D27D28_P1_FLUTTER_ROUTER_REGRESSION=PASS
D27D28_P1_NATIVE_FIRST_VS_RECOVERY_ROUTING_CANDIDATE=YES
D27D28_P1_OPERATIONAL_ISSUER_ENABLED=NO
D27D28_P1_ANDROID_MAIN_AUTH_ENABLED=NO
D27D28_P1_DEV_CONTAINERS_UNCHANGED=OK
D27D28_P1_RELEASE_AUTHORIZED=NO
D27D28_P1_RESULT=0
```

No constan en el extracto aportado `D28_RESTART_CONTRACT_RESULT` ni `git status --short` final; no se presuponen. **D28 fase de contrato y recuperación candidata PASS en Flutter**, pero **D28 operacional NO**: no existe aún un puerto HTTP D27 integrado y probado extremo a extremo ni autenticación principal Android. Las pruebas de reinicio reutilizan almacenamiento simulado, no implican ensayo físico de TLS/reinicio del dispositivo. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Siguiente ingeniería:** comparar el contrato Dart del adaptador HTTP existente con el wire JSON D27 y añadir un adaptador específico LAB con certificados validados; impedir cualquier conexión a `main.dart` o dependencia de rutas operativas hasta superar tests y auditoría independientes.

## D27/D28 — puente Flutter IOClient HTTPS real con D27 PG17 aislado (12/11/2026)

Implementación publicada directamente en `main`, **sin ejecución confirmada en VPS**:

- `scripts/native_i8k_https_server.py` admite un modo nuevo `VENCIRA_D27_REAL_TLS_LAB=1` que selecciona exclusivamente `native_mobile_service.test_d27_http_urls`, exige flags de laboratorio, inyecta las claves de auditoría/antiabuso sintéticas en `settings` y evita insertar la cabecera de proxy `X-Forwarded-Proto` (prohibida por el contrato D27). El modo heredado I8-M/I8-K conserva su comportamiento anterior.
- `clients/flutter/test/native_d27_real_https_pg17_test.dart` reutiliza `NativeHttpAuthPort` y `NativeRecoveryLoginGateway` sobre IOClient con CA temporal de confianza exclusiva. Comprueba rechazo TLS con CA no confiable y hostname incorrecto, `oc1` por primer acceso, `or1` por recuperación con journal y vault, revocación del access anterior y logout por HTTPS.
- `scripts/main_d27_flutter_real_https_pg17_isolated.sh` crea red Docker `--internal`, PG17 `tmpfs`, Django de prueba con URLconf D27, certificado y claves sintéticas, contenedores Flutter efímeros. El test Flutter no recibe contraseña DB ni clave privada TLS y no publica puertos al host. El script comprueba tras el test el estado de revocación en PG17 y que los contenedores DEV conserven identidad, y limpia al salir.

**Estado:** código y runner publicados, NO PASS todavía. Solo habilitaría un contrato real TLS de **laboratorio**, no servicio público ni release. No sustituye pruebas de fallo físico/reinicio Android o la revisión de custodia y proxy operacional. El runner I8-M histórico permanece separado; no repetir sus suites salvo regresión material.

### Ejecución única

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
bash -n scripts/main_d27_flutter_real_https_pg17_isolated.sh
python3 -m py_compile scripts/native_i8k_https_server.py
sudo -v
bash scripts/main_d27_flutter_real_https_pg17_isolated.sh
echo "D27_D28_REAL_TLS_RESULT=$?"
git status --short
```

Exigir `D27_REAL_TLS_CA_AND_HOSTNAME=PASS`, `D27_FLUTTER_REAL_TLS_FIRST_ISSUANCE=PASS`, `D27_FLUTTER_REAL_TLS_RECOVERY_AND_REVOKE=PASS`, `D27_FLUTTER_REAL_TLS_DEVICE_REVOKE=PASS`, `D27_REAL_TLS_PG17_RECOVERY_AND_LOGOUT=PASS`, `D27_REAL_TLS_INTEGRATION_GATE=PASS`, `D27_REAL_TLS_DEV_CONTAINERS_UNCHANGED=OK`, `D27_REAL_TLS_BOUNDARY_RESULT=0` y resultado del comando `0`. Si falla, recoger el primer marcador FAIL; no desactivar TLS ni relajar aislamiento.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27_OPERATIONAL_HTTP_ISSUER_ENABLED=NO
D28_ANDROID_MAIN_AUTH_ENABLED=NO
D27D28_RELEASE_AUTHORIZED=NO
```

## D27/D28 — IOClient HTTPS + PG17 real LAB PASS (12/11/2026)

El operador confirma la ejecución de `scripts/main_d27_flutter_real_https_pg17_isolated.sh`. Evidencias recibidas:

```text
No issues found! (ran in 9.9s)
D27_REAL_TLS_ANALYZE=PASS
D27_REAL_TLS_FIXTURE_READY=PASS
D27_REAL_TLS_CA_AND_HOSTNAME=PASS
D27_FLUTTER_REAL_TLS_FIRST_ISSUANCE=PASS
D27_FLUTTER_REAL_TLS_RECOVERY_AND_REVOKE=PASS
D27_FLUTTER_REAL_TLS_DEVICE_REVOKE=PASS
All tests passed! (1 test)
D27_REAL_TLS_REAL_CLIENT=PASS
D27_REAL_TLS_PG17_RECOVERY_AND_LOGOUT=PASS
D27_REAL_TLS_INTEGRATION_GATE=PASS
D27_REAL_TLS_DEV_CONTAINERS_UNCHANGED=OK
D27_REAL_TLS_DEPLOY_EXECUTED=NO
D27_REAL_TLS_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27_REAL_TLS_BOUNDARY_RESULT=0
```

**Cierre:** transporte candidato Flutter–Django con IOClient, CA/hostname verificados, protocolo `oc1/or1` y ciclo de sesión/revocación autenticado en PG17 **aislado PASS**. Este gate está respaldado por sockets HTTPS y un servidor WSGI temporal, no exclusivamente por `secure=True` del cliente Django. No se observó en el extracto el eco externo `D27_D28_REAL_TLS_RESULT` ni el `git status` final.

**Aún NO operativo:** rutas públicas Django, integración de `main.dart`, Android físico con el contrato D27, identidad de IP/proxy en Caddy, gestión y rotación de claves reales y autorización de despliegue. La CA temporal no acredita el TLS operativo.

**Siguiente corte:** validar integración controlada en Android LAB, interrupción física de transporte y persistencia del marcador en Keystore sin habilitar login normal ni abrir rutas de producción. Separar esta fase del cierre D4 de backups/rollback.

## D27 Android físico — ensayo PG17/HTTPS/Keystore preparado, SIN RESULTADO aún (12/11/2026)

Se ha añadido `scripts/main_d27_android_ssh_https_pg17_lab.sh`, adaptación **independiente** del runner físico I8-P, que conserva el mismo punto de entrada **Android DEBUG** `clients/flutter/lib/main_i8p_android_https_lab.dart`, misma CA pública temporal incorporada al APK y mismo relay cifrado `127.0.0.1:18743` por SSH autenticado. Las banderas y el código de ese punto de entrada siguen denominadas **I8-P** por compatibilidad; los resultados del runner nuevo se marcan **D27_ANDROID**.

Diferencia importante respecto de I8-P: el servidor Django usa `VENCIRA_D27_REAL_TLS_LAB=1`, `VENCIRA_D27_HTTP_LAB=1`, `test_d27_http_urls` y claves sintéticas D27; el usuario `i8p-recovery` es nuevo en la PG17 desechable y **no hay emisión previa por el candidato antiguo**. Android parte de refresh sintético huérfano, exige autenticación completa contraseña+`or1`, guarda en Keystore y revoca el nuevo dispositivo vía HTTPS; el postcheck de PG17 exige **una sesión, revocada**, con generación de recuperación 1.

**Alcance correcto:** demuestra recuperación `or1` sobre el dispositivo físico, verificación TLS/hostname, Keystore y revocación; **NO prueba primer acceso `oc1` físico, reinicio físico, desconexiones de red durante MFA ni refresh rotado en Android**. Esos escenarios requieren futuras fases y pruebas independientes. Sin despliegues, migraciones live ni puertos públicos. La prueba requiere un operador con móvil Android, Termux/SSH y APK debug; no se ha ejecutado todavía.

Preflight:

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
bash -n scripts/main_d27_android_ssh_https_pg17_lab.sh
python3 -m py_compile scripts/native_i8k_https_server.py scripts/main_i8p_ssh_tls_loopback_relay.py
sudo -v
bash scripts/main_d27_android_ssh_https_pg17_lab.sh
echo "D27_ANDROID_OPERATOR_RESULT=$?"
git status --short
```

El runner queda interactivo hasta que el operador termine la prueba en el móvil; **no pulsar ENTER antes de la verificación**. El APK se genera bajo `~/vencira-d27-android-phone/`; se instala solamente como DEBUG I8-P (`es.vencira.vencira.i8plab`), no como aplicación operativa. Conectar Termux al VPS usando el túnel `ssh -N -L 127.0.0.1:18743:127.0.0.1:18743` hacia el host SSH habitual. Comprobar los mensajes `I8P_ANDROID_...` en la pantalla del APK, luego pulsar ENTER para el postcheck PG17 y cierre del laboratorio.

Esperado al completar: `D27_ANDROID_PG17_SYNTHETIC_ACCOUNT=PASS`, `D27_ANDROID_SSH_RELAY_LOOPBACK_ONLY=PASS`, `D27_ANDROID_APK_DEBUG_BUILD=PASS`, `D27_ANDROID_PG17_RECOVERED_SESSION_REVOKED=PASS`, `D27_ANDROID_TLS_MFA_KEYSTORE_GATE=PASS`, `D27_ANDROID_DEV_CONTAINERS_UNCHANGED=OK` y `D27_ANDROID_LAB_RESULT=0`. Ninguno ha sido confirmado aún.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27D28_RELEASE_AUTHORIZED=NO
D28_ANDROID_MAIN_AUTH_ENABLED=NO
```

## D27 Android físico — PG17 HTTPS MFA Keystore PASS (12/11/2026)

El operador aportó captura del teléfono Android con los cinco marcadores visibles de la aplicación debug I8-P: `I8P_ANDROID_TLS_HOSTNAME=PASS`, `I8P_ANDROID_RECOVERY_MFA_KEYSTORE=PASS`, `I8P_ANDROID_REMOTE_REVOKE=PASS`, `I8P_ANDROID_ACCESS_AFTER_REVOKE_401=PASS`, `I8P_ANDROID_LAB_CLEANUP=PASS`. El nombre I8-P corresponde al punto de entrada reutilizado; por sí sola, la captura no identifica el backend.

Después de pulsar ENTER para cerrar `scripts/main_d27_android_ssh_https_pg17_lab.sh`, el operador compartió los siguientes marcadores del runner **D27**:

```text
D27_ANDROID_PG17_RECOVERED_SESSION_REVOKED=PASS
D27_ANDROID_TLS_MFA_KEYSTORE_GATE=PASS
D27_ANDROID_DEV_CONTAINERS_UNCHANGED=OK
D27_ANDROID_DEPLOY_EXECUTED=NO
D27_ANDROID_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27_ANDROID_LAB_RESULT=0
```

**Cierre del alcance:** D27 en Android físico con recuperación `or1`, verificación de certificado/hostname, Keystore, revocación HTTP 401 y PG17 aislado **PASS**. No se ejecutó despliegue ni migración persistente; contenedores DEV inalterados.

**No inferir:** primer acceso `oc1` físico, rotación de refresh tras caída del transporte, ensayo de reinicio real, configuración de proxy operacional, publicación ni MFA productivo. Conservar `D27D28_RELEASE_AUTHORIZED=NO` y revisar estos bloqueos antes de otra fase. No repetir el ensayo PASS para justificar activación en `main.dart`.

## D28 Android físico — emisión oc1, respuesta perdida y reinicio (12/11/2026)

**Código publicado en `main`, no ejecutado todavía:**

- `clients/flutter/lib/main_d28_android_response_loss_lab.dart`: punto de entrada Android DEBUG independiente con namespace de Keystore propio `vencira_d28_mobile_tls_lab_v1`, CA sintética de una ejecución y túnel SSH `127.0.0.1:18743` cifrado extremo a extremo, sin modificar `main.dart`. Usa `NativeMobileEntryRouter`, `NativeFirstIssuanceEntry`, `NativeSessionCoordinator` y `NativeMobileRecoveryEntry` existentes.
- **Fase 1:** sobre un almacén realmente limpio, inicia contraseña+`oc1` vía HTTPS; el wrapper de prueba `_LoseMfaResponse` descarta la respuesta **solo después de recibir credenciales válidas del servidor**. El journal ya estaba armado antes de la primera petición. Comprueba que el refresh no se persiste, el marcador sí y el fence permanece inactivo. Muestra `D28_ANDROID_OC1_ISSUED_RESPONSE_LOST=PASS` y `D28_ANDROID_DURABLE_MARKER=PASS`.
- **Fase 2:** tras cerrar por completo la aplicación y reiniciar Android, el router deberá seleccionar `fullReauthentication` por el marcador en Keystore; contraseña+`or1` produce nueva credencial que revoca la primera. Tras revocar también la sesión recién recuperada, el bearer debe devolver 401. Muestra `D28_ANDROID_RECOVERY_AFTER_RESTART=PASS`, `D28_ANDROID_KEYSTORE_RECOVERY=PASS`, `D28_ANDROID_REVOKE_401=PASS` y `D28_ANDROID_LAB_CLEANUP=PASS`.
- `scripts/main_d28_android_response_loss_pg17_lab.sh`: adapta el runner Android D27 aislado con credenciales sintéticas del usuario `d28-android`. Genera APK DEBUG (paquete de laboratorio compatible `es.vencira.vencira.i8plab`), servidor D27 con PG17 `tmpfs`, red Docker interna y relay en loopback. Mantiene el servidor temporal hasta completar ambas fases. Postcheck exige generación de recuperación 1, exactamente **dos sesiones revocadas** y ninguna activa. El script no abre puertos públicos ni modifica DEV.

**Alcance de la simulación:** la pérdida de respuesta se inyecta dentro de Dart después de una respuesta HTTPS auténtica y un commit de emisión; no corta físicamente Wi-Fi/LTE ni prueba la rotación del refresh bajo desconexión. El reinicio real del teléfono requiere la acción y evidencia del operador; el backend solo puede verificar sesiones y revocaciones, no certificar que el móvil efectivamente reinició.

**Procedimiento recomendado:** sincronizar `main` limpio, comprobar sintaxis del runner, ejecutar `bash scripts/main_d28_android_response_loss_pg17_lab.sh` en sesión persistente, instalar APK DEBUG separado, conectar el túnel SSH desde Termux, completar fase 1, reiniciar Android, reabrir Termux y el túnel, completar fase 2; **solo entonces** pulsar ENTER en el runner. Capturar pantalla en cada fase. Confirmar `D28_ANDROID_PG17_RECOVERED_SESSION_REVOKED=PASS`, `D28_ANDROID_TWO_STAGE_RESPONSE_LOSS_GATE=PASS`, `D28_ANDROID_DEV_CONTAINERS_UNCHANGED=OK`, `D28_ANDROID_LAB_RESULT=0`. Estos son resultados **esperados, NO verificados**.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D27D28_RELEASE_AUTHORIZED=NO
D28_ANDROID_MAIN_AUTH_ENABLED=NO
```

## D28 Android físico — dos fases oc1 → reinicio → or1, PASS (12/11/2026)

El operador aportó capturas separadas del dispositivo: **fase 1** con `D28_ANDROID_TLS_HOSTNAME=PASS`, `D28_ANDROID_OC1_ISSUED_RESPONSE_LOST=PASS`, `D28_ANDROID_DURABLE_MARKER=PASS` y el aviso de cerrar/reiniciar; **fase 2** con `D28_ANDROID_TLS_HOSTNAME=PASS`, `D28_ANDROID_RECOVERY_AFTER_RESTART=PASS`, `D28_ANDROID_KEYSTORE_RECOVERY=PASS`, `D28_ANDROID_REVOKE_401=PASS`, `D28_ANDROID_LAB_CLEANUP=PASS`.

Tras completar ambos pasos, el operador aportó el cierre del runner en VPS:

```text
D28_ANDROID_PG17_RECOVERED_SESSION_REVOKED=PASS
D28_ANDROID_TWO_STAGE_RESPONSE_LOSS_GATE=PASS
D28_ANDROID_DEV_CONTAINERS_UNCHANGED=OK
D28_ANDROID_DEPLOY_EXECUTED=NO
D28_ANDROID_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D28_ANDROID_LAB_RESULT=0
```

**Resultado del gate D28 Android físico: PASS** para emisión D27 `oc1` con respuesta descartada tras commit, persistencia del marcador en Keystore, recuperación `or1` en segunda ejecución y revocación final de ambas sesiones en PG17 aislado. La evidencia visual y del runner es coherente; la acción física de reiniciar el teléfono depende de la declaración del operador y no puede acreditarse únicamente con el marcador final.

**Restricciones intactas:** ningún despliegue, migración live ni activación de `main.dart`. La pérdida es **inyección de respuesta descartada**, no corte TCP/radio físico. Siguen pendientes pruebas de caída real durante refresh, diseño del proxy/IP de confianza, custodia de claves productivas y puertas de publicación D4. No declarar MFA operacional autorizado.

## Aceleración operativa — gate maestro D27/D28 (12/11/2026)

Se evita el ciclo de múltiples peticiones manuales al operador para cada test. Añadido `scripts/main_d27d28_single_gate.sh` directamente a `main`, con un único preflight del SHA limpio en `main`, scripts Bash validados sintácticamente y fallo temprano si cualquier subgate falla. Mantiene explícitas las prohibiciones de despliegue, migraciones live, MFA release y Android operativo.

Modos:

```bash
# Solo cuando haya cambios materiales a validar en toda la integración automática:
bash scripts/main_d27d28_single_gate.sh --automated

# Solo cuando exista un nuevo escenario físico Android pendiente:
bash scripts/main_d27d28_single_gate.sh --phone

# Cierre de macrofase: automático y después una sola sesión física:
bash scripts/main_d27d28_single_gate.sh --all
```

`--automated` ejecuta secuencialmente los gates D27 PG17, D28 Flutter (analyze/test), D27-D28 Flutter IOClient TLS real. `--phone` y `--all` incluyen **el ensayo Android D28 ya existente**, con pausa manual para el operador, no un nuevo ensayo de refresh físico. **La nueva rotación de refresh bajo corte físico sigue pendiente de implementación** y no debe declararse cubierta por este wrapper.

El script no elimina el coste de construir imágenes o preparar laboratorios en cada subgate; solo elimina la intervención repetida y proporciona un único resultado `D27D28_MASTER_RESULT=0` si todos pasan. No se requiere volver a ejecutar gates históricos por cambios solo de documentación. La ejecución completa `--all` tampoco equivale a autorización de producción ni al cierre de bloqueos D4 (recuperación de backup, rollback, imagen final, identidades operativas y liberación).

El nuevo script ha sido publicado, **sin ejecución confirmada** en VPS. Para comprobarlo, `bash -n scripts/main_d27d28_single_gate.sh`; los subgates están validados en ejecuciones individuales previas, pero no como master conjunto.
