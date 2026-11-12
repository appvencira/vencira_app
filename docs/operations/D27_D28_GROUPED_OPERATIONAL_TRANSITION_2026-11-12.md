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
