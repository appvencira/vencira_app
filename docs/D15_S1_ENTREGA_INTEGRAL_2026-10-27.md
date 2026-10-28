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

## Validación del control de entrada MFA
El ensayo aislado comunicó `S1_DEPLOY_ENTRY_FAIL_CLOSED=OK` y `S1_PG17_GATE_RESULT=0`. No se desplegó ni migró la base persistente. La autorización de activación continúa denegada. Pendientes: recuperación integral, custodia externa y conexión al despliegue operativo.

## Gate de rotación MFA 0025 — validación aislada
Commit validado: `179d60af69cd70c728b110ce6fb4cf9af3c5bc14`. Resultado comunicado: `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `S1_RELEASE_FAIL_CLOSED=OK`, `S1_DEPLOY_ENTRY_FAIL_CLOSED=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0`, `RESULTADO_FINAL=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La validación de 0025 no implica migración persistente. MFA_RELEASE_AUTHORIZED=NO.

## Gate de bloqueo de sesión durante recuperación
Commit de código verificado: `37526f8481d82bbaec39c44448241791c439e61e`. El operador confirmó `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `S1_RELEASE_FAIL_CLOSED=OK`, `S1_DEPLOY_ENTRY_FAIL_CLOSED=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0` y `RESULTADO_FINAL=0`. Sin despliegue ni migración persistente; MFA permanece sin autorización. Esta prueba no equivale a recuperación administrativa completa.

## Gate recuperación: casos cerrados y cancelados
Validación aislada del commit `fc76b3b3e6ee86b1af865563da09f4641e0669f3`: SQLite OK, PG17 temporal OK, concurrencia OK, controles fail-closed OK, limpieza OK, resultado final 0. No hubo despliegue ni migración persistente. Sigue sin autorizarse la activación MFA.

## Gate apertura de recuperación administrativa
Validación aislada del commit `f992fd2803e78616cdcea855a6e557d139c2365a`: pruebas SQLite OK, PostgreSQL 17 temporal OK, revisión y concurrencia OK, bloqueos de publicación OK, limpieza OK, resultado global 0. La función de apertura de expediente revoca sesiones; no sustituye factores. No hubo despliegue ni migración persistente. MFA permanece desactivado.

## Gate MFA y Fernet sintético
Commit validado `90150029dd0f0607ce7f56389fd34c0e940425f6`. Ejecución aislada: SQLite OK, PostgreSQL 17 temporal OK, pruebas sintéticas Fernet OK, entrada de despliegue bloqueada correctamente, limpieza OK, resultado final 0. No se modificó el entorno persistente. Custodia externa real y recuperación integral siguen pendientes.

## Gate de preflight y custodia documental
Commit validado `9fb4d5f4250ba0345035b42104e40c384d700905`. Salida reportada: SQLite OK, PostgreSQL 17 temporal OK, bloqueos de publicación OK, limpieza OK y resultado final 0. No se comprobó mediante una prueba negativa específica el rechazo de archivos sin seguimiento. Sin despliegues ni migraciones persistentes. La custodia real externa de Fernet continúa pendiente.

## Gate negativo de archivo sin seguimiento
Validación del commit `5b06b3687ca096b545e55a2529e7bb429bbcc52c`: `S1_UNTRACKED_FILES_REJECTED=OK`, `S1_DEPLOY_ENTRY_FAIL_CLOSED=OK`, `S1_PG17_GATE_RESULT=0`, `RESULTADO_FINAL=0`, `CLEANUP=OK`, sin despliegue ni migraciones persistentes. Esta prueba verifica el rechazo de un archivo temporal sin seguimiento en el preflight; no acredita aún integración del guard con todas las rutas operativas de despliegue.

## Gate verificador de identidad de recuperación
Commit validado `502895890027eeca786b6a41a3c9615810237eca`. Pruebas sintéticas SQLite y PostgreSQL 17, rechazo sin verificador, concurrencia, bloqueo de publicación, rechazo de archivos no seguidos y limpieza: OK. Resultado global 0. No acredita un proveedor de verificación externo real ni la recuperación administrativa completa. No se desplegó ni migró PostgreSQL persistente.

## Gate de indisponibilidad del verificador de identidad
Commit validado `99d2c34615b360bb0b70501bf943eb6502da3824`. Gate aislado SQLite y PostgreSQL 17: OK. Protección ante fallo de verificador, control de publicación, prueba negativa de archivos no seguidos y limpieza: OK. `S1_PG17_GATE_RESULT=0`, `RESULTADO_FINAL=0`, `MFA_RELEASE_AUTHORIZED=NO`; sin despliegue ni migración persistente. La recuperación por pérdida total aún carece de integración de identidad externa real y sustitución de factores.

## Regresión rotación durante recuperación administrativa (27-10-2026)
El gate previo reveló que finalize_factor_rotation permitía finalizar una rotación pese a un expediente administrativo pendiente. Corregido en commit d86f1c17edd70ef57ec77317a826b51a109dc324. El operador volvió a ejecutar el gate integral: S1_SQLITE_SECURITY=OK, PG17_EPHEMERAL=OK, S1_POSTGRES_REVIEW_AND_RACE=OK, S1_RELEASE_FAIL_CLOSED=OK, S1_DEPLOY_ENTRY_FAIL_CLOSED=OK, S1_UNTRACKED_FILES_REJECTED=OK, CLEANUP=OK, S1_PG17_GATE_RESULT=0, RESULTADO_FINAL=0, NO_DEPLOY_NO_LIVE_MIGRATION=1. Log local privado: /tmp/vencira-s1-pg17.y6CyrAdS.log. MFA_RELEASE_AUTHORIZED=NO. Recuperación administrativa efectiva y custodia real siguen pendientes.

## Gate del ciclo administrativo sintético
El operador informa: S1_SQLITE_SECURITY=OK, PG17_EPHEMERAL=OK, S1_POSTGRES_REVIEW_AND_RACE=OK, S1_STATIC_CANDIDATE_GUARD=OK, S1_RELEASE_FAIL_CLOSED=OK, S1_DEPLOY_ENTRY_FAIL_CLOSED=OK, S1_UNTRACKED_FILES_REJECTED=OK, CLEANUP=OK, S1_PG17_GATE_RESULT=0, RESULTADO_FINAL=0, MFA_RELEASE_AUTHORIZED=NO y NO_DEPLOY_NO_LIVE_MIGRATION=1. Código bajo prueba: 681a50a113d92e5b8272fc45b7b6db0a7575fa1d. Registro local: /tmp/vencira-s1-pg17.1LR2Tluk.log. Pendiente: carrera concurrente específica de finalización administrativa, integración de identidad y custodia Fernet real. Sin despliegue.

## Gate de bloqueo de intentos administrativos (27-10-2026)
Operador confirmó tras fe342d340121c5d9bc2ac1c44058884d64ee9aa1: S1_SQLITE_SECURITY=OK, PG17_EPHEMERAL=OK, S1_POSTGRES_REVIEW_AND_RACE=OK, S1_STATIC_CANDIDATE_GUARD=OK, S1_RELEASE_FAIL_CLOSED=OK, S1_DEPLOY_ENTRY_FAIL_CLOSED=OK, S1_UNTRACKED_FILES_REJECTED=OK, CLEANUP=OK, S1_PG17_GATE_RESULT=0, NO_DEPLOY_NO_LIVE_MIGRATION=1 y MFA_RELEASE_AUTHORIZED=NO. Registro local: /tmp/vencira-s1-pg17.Evq6MHru.log. Sin despliegue ni migración persistente. Siguen pendientes identidad externa, entrega y custodia operativa.

## Comprobación de carga Fernet desde archivo protegido
Operador comunica que el gate aislado correspondiente a fb3d6269ef255fef2f2ded8492e1ae227292a8cb ha terminado con S1_SQLITE_SECURITY=OK, PG17_EPHEMERAL=OK, S1_POSTGRES_REVIEW_AND_RACE=OK, S1_STATIC_CANDIDATE_GUARD=OK, S1_RELEASE_FAIL_CLOSED=OK, S1_DEPLOY_ENTRY_FAIL_CLOSED=OK, S1_UNTRACKED_FILES_REJECTED=OK, CLEANUP=OK y S1_PG17_GATE_RESULT=0. Estado MFA_RELEASE_AUTHORIZED=NO y NO_DEPLOY_NO_LIVE_MIGRATION=1. Registro local privado: /tmp/vencira-s1-pg17.zYPYv3hQ.log. Pendiente verificar montaje de archivo sintético en contenedor de usuario no privilegiado, sin clave operativa ni BD persistente.
