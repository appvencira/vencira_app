# D1.5 — S1: Entrega integral (sin subfases)

Fecha: 27/10/2026. Rama: integration/local-e2e-prep.
Referencia: HANDOFF_MACROFASE_D15_ABC_2026-10-27.md, D15_CUSTODIA_MFA_Y_GATE_OPERATIVO_2026-10-27.md y whitepaper §12.

## Decisión de ejecución
Agrupar el trabajo pendiente S1 en un solo paquete de código, documentación y pruebas. Evitar el ciclo commit/SSH/validación por cada pequeño arreglo. Las pruebas históricas O5 y S1A–S1E ya aceptadas no se repiten de forma aislada.

## Trabajo requerido en el paquete
- Autorización administrativa inequívoca de revisores, desde configuración y custodia del servidor separadas de entrada HTTP; comprobación de identidad y permisos.
- Casos de recuperación y aprobaciones transaccionales en PostgreSQL 17 con bloqueo, expiración, cuarentena, replay e idempotencia; auditoría de transiciones y rechazos.
- Recuperación sin bypass de segundo factor: control del proceso, revocación de sesiones y factores antiguos, inscripción de nuevos factores antes de restaurar acceso completo. NO exponer endpoint mientras falte seguridad.
- Puerta de despliegue MFA nueva que compruebe candidato y esquema/estado real antes de migraciones y ante reversiones. Fallo cerrado si el estado es desconocido.
- Custodia Fernet con dos copias cifradas independientes y ensayo de recuperación criptográfica controlado. El procedimiento en código no sustituye ejecución real por custodios.
- Revisión de script O5 para reportar limpieza y estado real sin falsos positivos; conservar ensayos históricos.
- Tests agrupados: Django SQLite, PostgreSQL 17 temporal con concurrencia, seguridad/abuso y Flutter ES/CA relevantes.

## Gate único
Un script de preflight sin despliegue, con SHA fijado, resultados resumidos y sin secretos, comprueba migraciones, suites y seguridad. Solo se pedirá ejecución al operador cuando el paquete esté implementado y revisado. Si falla, resolver errores en GitHub y volver a ejecutar únicamente el gate del paquete actualizado.

## Restricciones
- PostgreSQL persistente documentado en migración 0018; migraciones 0019–0024 preparadas pero NO autorizadas en vivo.
- MFA enrollment y UI apagados, sin publicación ni cambios OAuth/Caddy/Restic.
- No afirmar cierre S1 antes de validar código y completar la custodia real externa.
- Un despliegue exige autorización expresa adicional; la activación de enrolamiento requiere autorización independiente.

## Situación de entrada
S1E validado por operador: RESULTADO_D15_S1E=0 sobre 22f3cc0e66b24b93d514685f9c318f25d47e90c5. S1E documentado en 71d689af78d19659ce63fa166d794bb45d7c1189. Pruebas anteriores registradas en D15_CUSTODIA_MFA_Y_GATE_OPERATIVO_2026-10-27.md.

## Cierre del gate técnico — evidencia posterior
El gate SQLite + PostgreSQL 17 efímero + concurrencia + guard estático superó con `S1_PG17_GATE_RESULT=0`, `CLEANUP=OK`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, tras corregir el falso positivo de la ruta de acuse de códigos y registrar session_epoch en la sesión de alta. Evidencia detallada en `D15_CUSTODIA_MFA_Y_GATE_OPERATIVO_2026-10-27.md`. No repetir hasta cambios de código relevantes.

## BLOQUE FINAL OPERATIVO — requisitos bloqueantes, no autorizados
1. **Custodia Fernet real.** Designar dos custodios independientes del VPS, GitHub y acceso a Restic; cada custodio recibe copia cifrada independiente con verificación fuera de banda. No colocar claves en Git, mensajes, logs ni commits. Ensayar restauración criptográfica sintética usando la copia custodiada y registrar solo huellas no reversibles y acta de éxito. Sin doble custodia comprobable, bloqueo.
2. **Recuperación de pérdida total.** El procedimiento no puede ser equivalente a reset de TOTP por un administrador. Requiere solicitud atribuible al titular, canal previamente verificado con prueba exterior al sistema, cuarentena 24h, dos revisores independientes activos, comprobación justo antes de ejecutar, aviso independiente al titular, supervisión de abuso y nueva inscripción MFA sin intervalo de acceso password-only. Falta implementación de sustitución administrativa completa; `inspect_recovery_preconditions` **NO** concede autorización. No exponer API ni comando para reset hasta cerrar este diseño y pruebas de regresión.
3. **Rotación normal vs recuperación administrativa.** `mfa_factor_rotation.py` implementa solo la rotación normal con TOTP anterior. Los diez nuevos códigos se devuelven a una primitiva interna: diseñar entrega protegida, prueba de custodia y manejo de respuesta perdida antes de habilitar HTTP. No interpretar este cambio como solución a pérdida total.
4. **Sesiones.** session_epoch invalida solicitudes autenticadas previas bajo middleware, pero evaluar las rutas alternativas y las sesiones que no pasan por Django antes de declarar revocación global integral. No modificar factores si la revocación no es verificable.
5. **Rollback y puesta en marcha.** La puerta actual es estática e informativa: **no está conectada obligatoriamente** a la ruta de despliegue ni comprueba estado runtime de PostgreSQL persistente. El pipeline debe abortar ante fallo de guard, esquema desalineado, material Fernet no recuperable, falta de evidencia operativa o presencia de sesiones/factores incompatibles. No aceptar `MFA_CANDIDATE_STATIC_GATE=OK` como autorización.
6. **Autorizaciones separadas.** Primera autorización explícita: aplicar migraciones 0019–0024 y desplegar con flags apagados tras backup fresco y ensayo de rollback. Segunda autorización distinta: enrolamiento/activación MFA tras UAT ES/CA Android/PC y cumplimiento de custodia real. Mientras tanto `MFA_RELEASE_AUTHORIZED=NO`.

## Criterio verificable de cierre
No anunciar «MFA completado» sin evidencias de: ejecución técnica (Django y PG17), custodia externa con dos responsables, pérdida total probada con credenciales ficticias sin bypass, sesiones antiguas rechazadas, protección de despliegue efectivamente conectada, y autorizaciones independientes para cada paso. Si faltan evidencias, indicar PENDIENTE, no OK.

## Evidencia posterior de gate consolidado
El operador confirmó el 27/10/2026: S1_SQLITE_SECURITY=OK, PG17_EPHEMERAL=OK, S1_POSTGRES_REVIEW_AND_RACE=OK, S1_STATIC_CANDIDATE_GUARD=OK, CLEANUP=OK, S1_PG17_GATE_RESULT=0, RESULTADO_FINAL=0, NO_DEPLOY_NO_LIVE_MIGRATION=1. Corresponde a la validación tras endurecer los bloqueos de rotación TOTP. Log privado conservado en servidor. MFA_RELEASE_AUTHORIZED=NO. La validación NO acredita custodia externa de Fernet, recuperación por pérdida total de factores ni puerta de despliegue obligatoria.

## Gate de publicación fail-closed — 27/10/2026
Operador confirmó `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `S1_RELEASE_FAIL_CLOSED=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0`, `RESULTADO_FINAL=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` y `MFA_RELEASE_AUTHORIZED=NO`. Log privado `/tmp/vencira-s1-pg17.RvNeKw1F.log`. La prueba demuestra denegación con estado no cero del preflight de publicación; no demuestra integración del control en despliegue real. Custodia externa y recuperación de pérdida total siguen pendientes.

## Hallazgo de integración de despliegue (auditoría de rutas)
Se han localizado múltiples scripts históricos de despliegue en scripts/deploy_*.sh (Macro A, B, O8 y O9), con contratos y commits inmovilizados diferentes. El nuevo guard MFA estático NO es invocado obligatoriamente por esas rutas. Los hashes de validación que exigen varios de esos scripts ayudan a evitar despliegues de cambios nuevos, pero NO equivalen a protección MFA centralizada.
**Decisión:** no alterar indiscriminadamente scripts históricos ya usados ni anunciar protección integrada. Antes de autorizar el primer despliegue con MFA se requiere un único entrypoint nuevo, sujeto a revisión, que valide candidato inmutable, migraciones/estado runtime y custodia, y que bloquee explícitamente cualquier ruta alternativa. Mientras no exista, MFA_RELEASE_AUTHORIZED=NO.
