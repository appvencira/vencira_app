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
