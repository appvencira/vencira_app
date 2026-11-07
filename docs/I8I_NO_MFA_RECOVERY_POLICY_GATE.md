# VENCIRA — I8-I: política negativa de cuentas sin MFA y recuperación nativa

**07/11/2026 — Candidato publicado. Validación PostgreSQL 17 y Flutter PENDIENTE.**

## Alcance

El protocolo candidato de I8-C/I8-D autoriza sesiones únicamente después de
contraseña **y TOTP verificado** dentro de la misma transacción de PostgreSQL.
`candidate_password_to_challenge` consulta `_state(user)`, que exige
`UserMfaState.enabled=True`. En consecuencia una cuenta sin MFA o con MFA
deshabilitado devuelve error genérico **401** y no recibe desafío ni tokens.

Este comportamiento es deliberadamente fail-closed, pero **NO significa que
la autenticación de cuentas sin MFA esté implementada**. Para admitirlas sería
necesario definir una política explícita por tenant/organización, identidad,
gestión de dispositivos, verificación de contraseña/abuso/auditoría,
revocación y modelo de amenaza, nunca cambiar simplemente `_state` para
omitir TOTP. El contrato público y los requisitos del whitepaper deben
revisarse antes de decidir si está permitido emitir tokens sin MFA.

La recuperación G9/G10 del cliente Flutter usa un marcador duradero y mantiene
el fence cerrado. Sus tests simulan un `NativeRecoveryAuthPort`, **pero la URLconf
HTTP I8-D no contiene** las rutas `/api/v1/mobile/auth/recover/password/` ni
`/api/v1/mobile/auth/recover/mfa/`, por lo que **no existe todavía recuperación
de cuenta nativa extremo a extremo** en el emisor candidato I8-H. Su
implementación requeriría un emisor test-only separado que, después de nuevos
factores válidos, revoque **todas las sesiones antiguas** bajo el mismo bloqueo
de cuenta, garantice orden de bloqueos, commit atómico, auditoría y limpieza
de respuesta ambigua; no debe exponerse directamente el helper privilegiado
`revoke_all_candidate_devices` como endpoint HTTP.

## Gate agrupado I8-I

Archivos:
- `backend/native_mobile_service/test_i8i_non_mfa_recovery_policy_pg17.py`
  (8 escenarios negativos), que comprueba respuesta uniforme, ausencia de
  desafíos/tokens, falta de endpoints de recuperación y de emisor público.
- `scripts/native_i8i_negative_policy_pg17_isolated.sh`: ejecuta los tests I7
  de ausencia de emisor, I8-D regresión HTTP y I8-I sobre PostgreSQL 17 efímero
  en Docker `--internal` con identidades sintéticas. Posteriormente ejecuta
  tests Flutter existentes de `NativeMobileRecoveryEntry`,
  `NativeMobileStartupGate` y `NativeRefreshRecoveryJournal`. No modifica
  rutas operativas, modelos o migraciones y comprueba identidad de los
  contenedores DEV antes y después.

Ejecutar tras un fast-forward del checkout:
```bash
cd ~/vencira-m3-localcheck
bash -n scripts/native_i8i_negative_policy_pg17_isolated.sh
bash scripts/native_i8i_negative_policy_pg17_isolated.sh
echo "NATIVE_I8I_TERMIUS_RESULT=$?"
```

Marcadores esperados **únicamente si termina sin errores**:
```text
NATIVE_I8I_MIGRATION_PARITY=OK
NATIVE_I8I_FLUTTER_RECOVERY_ANALYZE=OK
NATIVE_I8I_FLUTTER_RECOVERY_POLICY=PASS
NATIVE_I8I_NO_PUBLIC_ISSUER=PASS
NATIVE_I8I_NO_MFA_DENIAL_POLICY=PASS
NATIVE_I8I_RECOVERY_ENDPOINTS_ABSENT=PASS
NATIVE_I8I_PG17_NEGATIVE_POLICY_GATE=PASS
NATIVE_I8I_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8I_LOCAL_RESULT=0
NATIVE_I8I_TERMIUS_RESULT=0
```

No etiquetar este gate como recuperación real PASS ni login sin MFA PASS. Es
un **gate negativo** de que ninguno de los dos escenarios permite acceso por
accidente. Próximo desarrollo efectivo: diseño revisado de recuperación
nativa atómica en PG17 aislado; definir separadamente si se admite la ruta
sin MFA y cuáles son sus defensas antes de codificar un emisor.

`MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
