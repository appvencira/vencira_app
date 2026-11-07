# I8-K — Recuperación nativa HTTP+HTTPS de laboratorio

**Estado 07/11/2026: preparado y publicado en GitHub; pendiente de validar en VPS.**

## Contrato

El núcleo I8-J ya está validado: contraseña fresca, TOTP fresco, revocación atómica de dispositivos anteriores y nueva sesión sobre PostgreSQL 17 desechable. I8-K ofrece **solamente en laboratorio** dos rutas JSON de recuperación:
- `POST /api/v1/mobile/auth/recover/password/` (username/password → `mfa_required` + challenge; **no tokens**).
- `POST /api/v1/mobile/auth/recover/mfa/` (challenge/code → nueva pareja access/refresh **tras** revocación).
- `GET /api/v1/mobile/me/` (Bearer válido tras recuperación).

La URLconf `native_mobile_service.test_i8k_recovery_urls` está separada de `config.urls` y de I8-D. No expone el login normal, ni refresh, ni token/revoke ni el helper privilegiado account-revoke. **No se ha habilitado ningún endpoint operativo.**

Guardias: `VENCIRA_ENV=test`, app candidata, bearer operativo desactivado, `VENCIRA_I8K_RECOVERY_LAB=1`, URLconf exacta; método, JSON limitado, sin cookie web, Origin ni Authorization en POST. Las claves TOTP sintéticas provienen exclusivamente del servidor, nunca de HTTP. Las respuestas de fallo no revelan la existencia de una cuenta. Seguridad de las sesiones y atomicidad implementadas previamente en I8-J.

## Gate único VPS

Tras actualizar la rama `feature/m3-android-local-notifications`, ejecutar:

```bash
cd ~/vencira-m3-localcheck
bash -n scripts/native_i8k_real_https_pg17_isolated.sh &&
bash scripts/native_i8k_real_https_pg17_isolated.sh
echo "NATIVE_I8K_TERMIUS_RESULT=$?"
```

El script: verifica contenedores DEV por ID/imagen, crea imagen efímera, red Docker `--internal` sin puertos publicados, PostgreSQL17 tmpfs, certificado autofirmado temporal con SAN `native-i8k.test`, claves artificiales independientes y migraciones exclusivamente efímeras; ejecuta antes del servidor HTTP las pruebas de I8-K, I8-J e I8-I en base de test temporal dentro de PG17; después crea una única cuenta MFA sintética y arranca WSGI HTTPS con URLconf de recuperación exclusivamente en memoria. El cliente TLS independiente comprueba:
- CA no confiable y hostname incorrecto rechazados sin bypass.
- Cuenta desconocida rechazada.
- Contraseña correcta produce sólo desafío; TOTP erróneo no emite.
- MFA correcto emite y Bearer `/me` devuelve 200.
- Reutilización del mismo desafío denegada.
- Login normal no disponible en la URLconf de recuperación.
- Origin no confiable rechazado, sin cookies de sesión.
- Limpieza de imagen/red/DB/certificado y DEV intacto.

Se esperan, **solo tras ejecución real**, los marcadores:
```text
NATIVE_I8K_RECOVERY_JSON_PG17=PASS
NATIVE_I8K_UNTRUSTED_CA_DENIED=PASS
NATIVE_I8K_HOSTNAME_MISMATCH_DENIED=PASS
NATIVE_I8K_PASSWORD_RECOVERY_CHALLENGE_ONLY=PASS
NATIVE_I8K_TLS_ATOMIC_RECOVERY_ISSUED=PASS
NATIVE_I8K_RECOVERED_BEARER_ME=PASS
NATIVE_I8K_RECOVERY_CHALLENGE_REPLAY_DENIED=PASS
NATIVE_I8K_REAL_HTTPS_GATE=PASS
NATIVE_I8K_LIVE_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
NATIVE_I8K_TERMIUS_RESULT=0
```

## Faltantes

La validación de I8-K **no** equivale a recuperación física Android: aún falta implementar un `NativeRecoveryAuthPort` de transporte HTTPS que utilice el contrato y pruebe respuesta ambigua, marcador duradero, atestación de destino/identidad, fence, escritura Keystore y revocación anterior en teléfono. Tampoco habilita cuentas sin MFA ni autoriza emisión real. Mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
