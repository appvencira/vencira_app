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
