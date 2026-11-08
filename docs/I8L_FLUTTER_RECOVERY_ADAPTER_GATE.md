# I8-L — Adaptador Flutter de recuperación real y barrera de MFA

**08/11/2026 — Implementación y tests publicados, gate Flutter PENDIENTE de VPS.**

## Hallazgo corregido

El código anterior de `NativeHttpAuthPort.recoverPassword` aceptaba
`{"status":"authenticated","access":"…","refresh":"…"}` sin desafío.
El `NativeRecoveryLoginGateway` también podía activar un grant así
recibido desde cualquier `NativeRecoveryAuthPort`. El contrato del
backend I8-K garantiza `password → challenge → MFA → nueva sesión`;
el cliente no debe depender exclusivamente de que el servidor respete
ese contrato. **Se suprime la elevación desde contraseña a sesión
tanto en el HTTP port como en el gateway:** la única transición a
`_confirm` ocurre tras `recoverMfa`.

Cambios:
- `clients/flutter/lib/api/native_http_auth_port.dart` (commit
  `ff3a5019`): `recoverPassword` rechaza respuestas de tokens.
- `clients/flutter/lib/api/native_recovery_login_gateway.dart`
  (`d87480a8`): rechaza grants directos incluso de un port futuro.
- Tests antiguos actualizados para exigir desafío y MFA
  (`deb67692`, `6e4d0325`).
- `clients/flutter/test/native_i8l_http_recovery_integration_test.dart`
  (`c56ccc31`): instancia realmente `NativeHttpAuthPort`,
  `NativeMobileRecoveryEntry`, `NativeMobileStartupGate`,
  `NativeRecoveryLoginGateway`, `NativeRefreshRecoveryJournal`,
  `NativeRefreshCredentialVault`, `NativeSessionFence` y HTTP
  mockable en la misma integración. Cubre seis caminos:
  marcador huérfano→MFA→confirmación de refresh protegido;
  intento de token directamente tras password;
  respuesta de MFA ambigua y fence cerrado; fallo de escritura
  protegida y revocación best-effort fallida; marcador corrupto;
  reinicio tras respuesta MFA ambigua.
- `scripts/native_i8l_flutter_recovery_adapter_gate.sh` (`9f3873c0`)
  analiza fuentes Dart y ejecuta 6 suites, comprobando contenedores
  DEV por identificador/imagen antes y después.

## Ejecutar en VPS

```bash
cd ~/vencira-m3-localcheck
bash -n scripts/native_i8l_flutter_recovery_adapter_gate.sh &&
bash scripts/native_i8l_flutter_recovery_adapter_gate.sh
echo "NATIVE_I8L_TERMIUS_RESULT=$?"
```

Marcadores objetivo **no obtenidos todavía**:
```text
NATIVE_I8L_FLUTTER_ANALYZE=OK
NATIVE_I8L_HTTP_ADAPTER_JOURNAL_GATE=PASS
NATIVE_I8L_PASSWORD_ONLY_RECOVERY_REJECTED=PASS
NATIVE_I8L_AMBIGUOUS_MFA_FENCED=PASS
NATIVE_I8L_DURABLE_RESTART_RECOVERY=PASS
NATIVE_I8L_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8L_LOCAL_RESULT=0
NATIVE_I8L_TERMIUS_RESULT=0
```

## Alcance pendiente

Los tests Flutter I8-L actuales usan **MockClient** y una memoria de
secreto falsa para ejercitar la lógica del adaptador. No prueban TLS
real, Android Keystore ni que el túnel SSH siga activo. I8-K certifica
por separado el backend de recuperación por HTTPS con CA verificable
y PostgreSQL17. El siguiente paso, **si I8-L pasa**, es integrar el
adaptador en un test HTTPS aislado con CA temporal y después el
flujo en teléfono físico, con marcador/vault Android reales.

El endpoint I8-K no proporciona `/api/v1/mobile/token/revoke/` para
limpieza individual. Si falla el guardado protegido tras emisión, el
cliente deja el journal duradero, fence cerrado y debe repetirse
**recuperación completa de cuenta**: jamás reintentar ciegamente
MFA/refresh o dar la sesión por recuperada.

No se ha conectado I8-L a `main.dart`, no se han añadido migraciones,
no se ha alterado configuración operativa ni se autoriza publicación.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
