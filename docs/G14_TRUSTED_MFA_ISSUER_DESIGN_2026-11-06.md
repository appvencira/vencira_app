# G14 — Contrato de emisor MFA confiable (diseño, sin implementación operativa)

Fecha: 2026-11-06. Rama: `feature/m3-android-local-notifications`. **Decisión de seguridad: NO autorizar emisión MFA nativa.**

## Riesgo confirmado del límite actual

`native_mobile_service.session_store.issue_verified_candidate_session` admite `user_id`, `verified_mfa`, `mfa_epoch` y `expected_generation` declarados por el llamante. El predicado `require_mobile_identity_gate` verifica que esa declaración es compatible con el estado actual, pero **no verifica que la contraseña o el código TOTP se hayan presentado y validado recientemente**. `test_g14_untrusted_evidence.py` contiene una demostración negativa de emisión después de cambiar la contraseña. Este es un riesgo de diseño conocido; **no conectar la función a rutas operativas, vistas ni complementos**.

La compuerta `VENCIRA_ENV=test` y `VENCIRA_NATIVE_SERVICE_CANDIDATE` debe mantenerse. `scripts/g14_trusted_issuer_boundary.py` hace inventario AST de llamadas directas y permite solo la composición sin MFA `g14_d3_candidate_boundary.py` entre módulos no-test. Sus límites: alias dinámicos, `getattr`, reflexión, otros paquetes, SQL directo y modificaciones de import no equivalen a una comprobación de flujo de datos.

## Contrato de una futura emisión verificada (no aprobado)

1. API interna con entrada mínima: login, contraseña, segundo factor y metadatos de red saneados; no admitir `verified_mfa`, `mfa_epoch`, `user_id` o `credential_version` desde cliente.
2. Preadmisión de abuso y registro de denegación con sujeto HMAC y evento idempotente; sin filtrar si el usuario o el factor existen.
3. En una única transacción PG17: bloquear cuenta, verificar contraseña contra hash actual, bloquear estado MFA, comprobar habilitación/época, caso de recuperación pendiente, bloqueo de intentos, y consumir TOTP o código de recuperación de **uso único**.
4. Obtener identidad, factor verificado y época exclusivamente del estado persistente bloqueado. Un resultado de política `IssuanceSecurityEvidence` no es una capacidad ni prueba criptográfica.
5. Emitir tokens opacos test-only y auditar éxito en la misma transacción. Ante fallo de auditoría, rollback del token y del consumo de prueba según política explícita; las denegaciones y cuotas conservan su propio registro.
6. Revocación y refresco coherentes con la versión de contraseña, cambio de MFA, rotación de factor, recuperación y generation fence, incluyendo carreras contra cambios de estado.
7. Custodia y rotación reales de claves HMAC/Fernet externas, prueba de pérdida de respuesta y replay, control de reloj/TOTP, límites de payload y canales de entrega. No incorporar datos reales en fixtures.

## Pruebas necesarias para aceptación

- [ ] Contraseña errónea, MFA erróneo, MFA deshabilitado, usuario desactivado, caso administrativo pendiente.
- [ ] TOTP concurrente solo una emisión; código de recuperación concurrente solo una emisión; no emisión si falla auditoría.
- [ ] Revocación, cambio de contraseña, apertura de recuperación y reemplazo de factor durante la transacción; demostrar que token obsoleto no queda válido.
- [ ] Resistencia a replay, caída de red y respuesta ambigua; pruebas de abuso desde IP/proxy validado.
- [ ] Ausencia de endpoint público hasta autorización, revisión independiente de cambios y batería CI+PG17+Android.
- [ ] Responsable de claves y runbook de restauración/reversión con autorización explícita.

## Hito estático G14-E0

Se añade un barrido AST del límite de llamadas directas a `issue_verified_candidate_session` con seis pruebas unitarias. Se integra en N1. **Código publicado, pendiente de ejecutar.** No cambia la autenticación ni concede permiso de release.

```
G14_D9D=PASS_LOCAL_118_TESTS
G14_E0_BOUNDARY_GUARD=PUBLISHED_NOT_RUN
TRUSTED_MFA_ISSUER=NOT_IMPLEMENTED
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
