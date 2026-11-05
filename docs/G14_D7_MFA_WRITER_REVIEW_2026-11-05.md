# G14-D7 — Clasificación del inventario MFA (revisión de código)

Fecha: 2026-11-05. Rama: `feature/m3-android-local-notifications`. **Auditoría parcial, no autorización de release.**

## Evidencia cuantitativa

Inventario G14-D6 del operador: **12 ficheros, 104 coincidencias**. `G14_D6_TESTS=0`, `G14_D6_N1=0`, `G14_D6_INVENTORY=0`, HEAD `0f5af40d`. El informe clasifica AST y puede duplicar marcadores de la misma operación (p. ej., asignación + `save`). Ni todos los hallazgos son fallos, ni todos los escritores quedan necesariamente detectados.

| Ruta (relativa a backend) | Candidatos | Clasificación / alcance |
|---|---:|---|
| `reminders/mfa_admin_recovery_service.py` | 34 | Crítico: abrir casos, auditoría, preparación, confirmación y sustitución administrativa MFA |
| `reminders/mfa_enrollment.py` | 22 | Crítico: enrolamiento y `finalize_mfa` (usuario → estado MFA protegido desde G14-D4) |
| `reminders/mfa_factor_rotation.py` | 19 | Crítico: rotación normal y cambio de época |
| `reminders/mfa_store.py` | 14 | Crítico: TOTP anti-replay, recovery code único, intentos fallidos |
| `renewal_attachments/offline_rejection_recovery.py` | 4 | Revisión manual: coincidencia por nombre o contexto; no asumir mutación MFA |
| `native_sessions_lab/tests.py` | 3 | Laboratorio; no vía operativa de escritura |
| `reminders/mfa_session_revocation.py` | 2 | Crítico: revocación de época |
| `native_sessions_lab/g7_d2_https_fixture.py` | 2 | Fixture efímera; no vía operativa |
| `renewal_attachments/offline_recovery_persistence_d10.py` | 1 | Revisión manual, dominio de adjuntos |
| `reminders/mfa_middleware.py` | 1 | Revisión manual: comprobar si lectura o mutación |
| `reminders/mfa_enrollment_api.py` | 1 | Endpoint protegido por flag OFF; revisar guard y sesiones |
| `reminders/mfa_challenge.py` | 1 | Reto MFA web; verificar integración con claves externas |

Total por tipo declarado: 42 asignaciones a campos, 17 saves en módulos MFA, 15 locks de modelos, 8 deletes de modelos, 8 locks en módulos MFA, 6 creates, 5 bulk creates, 1 update, 1 save, 1 get_or_create. Los contadores por archivo y por tipo no son necesariamente disjuntos.

## Grafo de bloqueo observado en las fuentes revisadas

- `mfa_enrollment.finalize_mfa`: **usuario → UserMfaState** en una transacción. Verificado por test G14-D4 PG17 y PASS del operador.
- `mfa_admin_recovery_service.open_recovery_case`: **usuario → UserMfaState → inserción de caso**, con bloqueo y aumento de `session_epoch`; carece aún de prueba dirigida de carrera con emisión candidata.
- `mfa_admin_recovery_service.prepare/confirm/finalize_administrative_factor`: **caso → UserMfaState**. Verificación de evidencia externa sigue sin implementarse para ejecución operativa. Su lectura de aprobaciones y llamadas al verificador requieren revisión adicional de snapshot/idempotencia; no afirmar seguridad completa.
- `mfa_factor_rotation.prepare/confirm/finalize_factor_rotation`: **UserMfaState**. `finalize` sustituye secreto y códigos e incrementa `session_epoch` en una transacción; faltan pruebas PG17 contra revocación/inicio de sesión simultáneos.
- `mfa_store.consume_totp/consume_recovery_code`: **UserMfaState**, demostrado uso único concurrente en G14-D5.
- `mfa_session_revocation.revoke_mfa_sessions`: **UserMfaState**, incremento de época demostrado con dos llamadas concurrentes en G14-D5.

**Diagnóstico:** No se ha demostrado una inversión de locks en estos recorridos conocidos, pero la política global tampoco está cerrada. Los escritores que solo toman `UserMfaState` no constituyen por sí mismos una inversión de orden. No cambiar masivamente su orden hasta verificar los caminos de acceso administrativos y los posibles locks adicionales de sus verificadores.

## Plan de aceptación enfocado (sin desplegar)

1. Añadir tests PostgreSQL reales de **rotación normal vs revocación de época** y **apertura/cuarentena administrativa vs emisión**; comprobar invalidación de sesiones al confirmar factor y después de abrir caso.
2. Auditar `open_recovery_case` y las operaciones de cierre de recuperación contra `require_mobile_identity_gate`. Un verificador externo solo se simulará en datos efímeros; nunca convertir su resultado sintético en autorización operativa.
3. Revisar la asociación de revisores, autorizaciones y eventos a la misma transacción, las condiciones de expiración, la custodia y las garantías de retención; dejar guard de rechazo por defecto si falta evidencia externa.
4. Revisar rutas de `reminders` y otros módulos no cubiertos por AST, SQL indirecto y setters genéricos. El inventario no prueba exhaustividad.
5. Repetir solo N1 y candidato PG17 si se cambia lógica backend; Flutter/Android solo ante cambio de protocolo.

## Estado

```
G14_D6_INVENTORY=PASS_LOCAL
G14_D7_HIGH_PRIORITY_FILES_REVIEWED=3
G14_D7_LOCK_ORDER=PARTIAL_REVIEW
G14_D7_PG17_ADMIN_ROTATION=NOT_RUN
G14_MFA_OPERATIONAL_ISSUER=NOT_IMPLEMENTED
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
