# G14-E2 — Criterios de aceptación de emisión MFA atómica

Fecha: 2026-11-06. Rama `feature/m3-android-local-notifications`.

**Estado: contrato de seguridad diseñado; emisión MFA no implementada ni autorizada.**

## Base validada

- E0: revisión estática del límite de llamada al emisor; unit, auditoría y N1 PASS local.
- E1: verificación de contraseña y TOTP bajo lock en PG17, sin emitir tokens. 123 pruebas PASS local, N1/build/PG17=0.
- D9: carreras de recuperación y cambios de factor cubiertas parcialmente hasta 118 pruebas PASS, pero auditoría integral y evidencia externa real pendientes.

## Condiciones mínimas para un emisor confiable

1. El cliente solo entrega credenciales y datos de conexión. Ninguna afirmación de `user_id`, `verified_mfa`, `mfa_epoch`, `credential_version` o identidad verificada es aceptable como autorización.
2. Conservar el lock de cuenta y MFA desde la verificación hasta finalizar la escritura del token y la auditoría, con orden inequívoco entre transacciones.
3. No utilizar una devolución booleana de E1 como prueba reutilizable fuera de su transacción. Todo consumo de factor, emisión de sesión y auditoría positiva debe ser una única unidad atómica.
4. El token y la auditoría de éxito deben confirmar conjuntamente. Una excepción de auditoría o almacenamiento no puede dejar token persistente ni código TOTP consumido sin resultado inequívoco. Registrar de forma independiente los intentos denegados según una política que conserve las cuotas.
5. Un TOTP se consume como máximo una vez, incluso si dos intentos compiten; contemplar el comportamiento cuando se pierde la respuesta después de commit.
6. Comprobar rechazo ante credenciales incorrectas, desactivación de cuenta, recuperación pendiente, revocación, rotación de contraseña o factor y ausencia de custodia. No revelar diferencias al cliente.
7. Conservar `VENCIRA_ENV=test` y las restricciones de despliegue mientras no haya revisión, pruebas completas y autorización explícita.

## Matriz de pruebas pendientes

| Caso | Invariante esperado | Estado |
|---|---|---|
| Credenciales correctas | Una sesión y una auditoría positiva, misma transacción | Pendiente |
| Contraseña incorrecta | Sin sesión, sin consumo MFA | Pendiente |
| TOTP erróneo / repetido | Sin emisión, límite de intentos, sin reutilización | Pendiente |
| Fallo al registrar éxito | Rollback total de sesión, token y consumo MFA | Pendiente |
| Fallo de almacenamiento de sesión | Sin auditoría positiva ni consumo irreversible | Pendiente |
| Dos intentos concurrentes | A lo sumo una sesión válida para el mismo TOTP | Pendiente |
| Revocación o cambio MFA concurrente | No queda una sesión obsoleta válida | Pendiente |
| Respuesta perdida tras commit | Reautenticación controlada sin replay ni emisión duplicada | Pendiente |

## Restricción de esta fase

El intento de publicar la composición de emisión candidata fue bloqueado por controles de seguridad de la conexión. No se publicó ese código, no se construyó imagen nueva y no se ejecutaron pruebas E2. El documento no sustituye tests.

```
G14_E1=PASS_LOCAL_123_TESTS
G14_E2_CODE=NOT_PUBLISHED
G14_E2_PG17=NOT_RUN
TRUSTED_MFA_ISSUER=NOT_IMPLEMENTED
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## 06/11/2026 — G14-E1C pruebas de rollback previas a emisión

Tres nuevas pruebas con `TransactionTestCase` para PostgreSQL 17: rollback del TOTP consumido tras excepción exterior, rollback de contador de fallos en excepción exterior y recuperación de un savepoint interno sin consumir TOTP. Integración N1 y runner candidato preparada. **No hay pruebas locales E1C todavía**; estas regresiones no acreditan persistencia ni rollback de tokens y auditoría. E2 continúa sin publicación de emisor.


## Revisión consolidada de garantías (06/11/2026)

**Verificado con resultados aportados:** E1C tiene 130 tests PG17 OK, N1 específico OK y Docker OK. Esto cubre verificación y rollback del factor **sin emitir token**.

**Hallazgos de código que bloquean la aceptación E2:**

- `g14_e1_locked_mfa_verifier.verify_candidate_password_and_totp` devuelve un booleano. Su `transaction.atomic()` es interno; sin transacción externa supervisada, un `True` no acredita que el llamante conserve el bloqueo de usuario y MFA cuando inicie la emisión. El booleano jamás debe usarse como credencial para emitir.
- `session_store.issue_verified_candidate_session` recibe `verified_mfa` y `mfa_epoch` del llamante. La validación posterior comprueba coherencia, no prueba de contraseña y TOTP, por lo que permanece limitado al laboratorio.
- `mfa_store.consume_totp` actualiza contador antirreutilización dentro de una transacción. La prueba E1C evidencia que una excepción exterior revierte el consumo y también el presupuesto de errores; el diseño E2 debe especificar qué efectos se revierten y cómo persisten los intentos denegados.
- El predicado de identidad móvil consulta el estado MFA y casos pendientes, pero no constituye un autenticador HTTP ni una prueba de procedencia de token.

**Condiciones de salida de una única macrovalidación futura:** trazabilidad del servidor desde contraseña y TOTP hasta sesión y auditoría; misma transacción y bloqueos hasta commit; una sola emisión ante carrera; cero sesiones válidas ante excepción o fallo de auditoría; denegaciones con cuota y evidencia; cambio de contraseña, revocación MFA y recuperación pendientes fail-closed; reintento ante respuesta ambigua; ausencias verificadas de rutas operativas; ejecutables N1, CI y PG17 aislado.

`G14_E2_STATUS=BLOCKED_NOT_IMPLEMENTED`. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No sustituir estas condiciones por pruebas sintéticas de una primitiva aislada.


## 06/11/2026 — Lote E1D sobre fallos de custodia (sin sesión)

Se añaden cuatro regresiones PG17 aisladas para verificar que una clave ausente/extraña y los estados de cuenta inactiva o recuperación pendiente no consumen TOTP, no cambian época y no generan sesiones. N1 `g14_e1d_pg17_key_custody_failclosed` y runner `--candidate` integrados. **E1D pendiente de validación local.**

**Riesgo señalado:** la llave de descifrado incorrecta desencadena `ValueError` en el verificador E1, lo que no constituye una respuesta uniforme de autenticación. En ausencia de endpoint público, no existe filtración HTTP operativa de este flujo; la futura integración debe capturar la excepción y distinguir internamente indisponibilidad de custodia de una contraseña incorrecta, sin exposición de detalles al cliente.


## 06/11/2026 — G14-E1D2, cierre del error de clave antes de E2

La verificación de contraseña/TOTP bajo locks ahora convierte errores de descifrado de clave en `CandidateMfaDenied` sin encadenamiento explícito. Casos de clave incorrecta y clave malformada integrados en E1D. **No acreditado por pruebas locales aún**; se esperan 135 tests PG17 y gate N1 `g14_e1d_uniform_custody_denial`. Ello no implementa la emisión MFA ni la auditoría atómica requeridas para E2.
