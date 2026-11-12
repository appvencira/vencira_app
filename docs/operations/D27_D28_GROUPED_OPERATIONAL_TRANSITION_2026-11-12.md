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
