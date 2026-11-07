# I8-J — Recuperación atómica candidata MFA, PostgreSQL 17 aislado

**07/11/2026 — Implementada como núcleo test-only, NO VALIDADA en VPS.**

## Decisión de seguridad

No utilizar el helper privilegiado `revoke_all_candidate_devices` como
endpoint HTTP, ni permitir que un desafío normal de login active revocación de
cuenta. Los desafíos de recuperación utilizan el mismo formato opaco `lc1`
pero se almacenan con una **huella de desafío ligada criptográficamente a
la finalidad recovery** mediante SHA-256 con dominio distinto. Esto permite
reutilizar `MobilePendingChallenge` sin migraciones y rechaza el intercambio
de un desafío de login ordinario por uno de recuperación y viceversa. El
servidor sigue verificando usuario, contraseña, estado MFA, epoch, generación,
expiración, secreto del desafío, TOTP fresco y auditoría.

Nuevo módulo `backend/native_mobile_service/candidate_recovery_issuer.py`:
- `recovery_password_to_challenge` consume los presupuestos de G5 antes
  de verificar contraseña y produce exclusivamente un desafío recovery;
- `recovery_mfa_to_atomic_session` bloquea usuario→estado MFA→desafío,
  consume TOTP, incrementa la generación de cuenta y revoca **todas**
  las sesiones previas, consume desafío, emite una sesión nueva y
  escribe dos eventos auditados, todo bajo **una transacción de PG17**;
- Error de TOTP/auditoría/DB debe impedir nueva emisión. Error de
  auditoría en el camino de éxito revierte también consumo TOTP,
  revocación de sesiones previas, generación y nueva sesión.
- Se impide reutilizar el desafío o elevar uno de login normal.

**No hay vistas HTTP nuevas, URLconf nueva, migraciones ni conexión con
`main.dart`.** El backend operativo continúa sin emisor móvil.
En este bloque no se ha demostrado el contrato HTTPS recovery, el
manejo de respuesta ambigua en Android ni custodia definitiva de claves.

## Gate agrupado

`backend/native_mobile_service/test_i8j_recovery_pg17.py` contiene
**11 tests** de revocación de sesiones anteriores, emisión de una sola
nueva sesión, separación de propósitos, contraseña/TOTP incorrectos,
challenge caducado o repetido, invalidación de desafío de login pendiente, bloqueo de cuenta desactivada, rollback de auditoría y carrera de
dos confirmaciones simultáneas.

`scripts/native_i8j_atomic_recovery_pg17_isolated.sh` reúne los tests
I7, I8-D, I8-I, I8-J en una imagen nueva y PG17 temporal `--internal`
y conserva las regresiones Flutter para G9/G10 (startup, fence, journal,
recovery). Comprueba la identidad de los contenedores DEV antes/después;
sin deploy ni migración persistente.

Tras actualizar la rama por fast-forward:
```bash
cd ~/vencira-m3-localcheck
bash -n scripts/native_i8j_atomic_recovery_pg17_isolated.sh
bash scripts/native_i8j_atomic_recovery_pg17_isolated.sh
echo "NATIVE_I8J_TERMIUS_RESULT=$?"
```

Los marcadores `NATIVE_I8J_ATOMIC_RECOVERY_CORE=PASS`,
`NATIVE_I8J_PG17_ATOMIC_RECOVERY_GATE=PASS`,
`NATIVE_I8J_DEV_CONTAINERS_UNCHANGED=OK` y
`NATIVE_I8J_TERMIUS_RESULT=0` son **objetivos pendientes**; no se han
obtenido todavía. Este gate **no** valida recuperación HTTP ni física Android.

## Siguientes condiciones

Si el gate pasa, preparar I8-K URLconf **test-only** para endpoints de
recovery separados, reutilizando guardias JSON, CA temporal y un servidor
HTTPS sintético. Después conectar `NativeRecoveryAuthPort` a esos endpoints
con protección de marcadores y revocación confirmada sobre dispositivo.

La política para cuentas sin MFA sigue sin definirse. Su denegación segura
I8-I ya está validada; no convertirla en login sin MFA por defecto.

Invariantes: `MFA_RELEASE_AUTHORIZED=NO`,
`NO_DEPLOY_NO_LIVE_MIGRATION=1`.
