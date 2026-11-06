# VENCIRA — Progreso G14 y pendientes (05/11/2026)

Estado basado en pruebas locales comunicadas. La aprobación de laboratorio no equivale a autorización de producción.

## Validado en laboratorio
- [x] G14-A: control de admisión.
- [x] G14-B: contrato de evidencia no confiable.
- [x] G14-C: atomicidad de operación candidata.
- [x] G14-D1: verificación bloqueada sin emisor.
- [x] G14-D2: diagnóstico y reproducción del riesgo de metadatos reutilizados (riesgo no resuelto para el emisor de bajo nivel).
- [x] G14-D3: composición sin MFA y carreras de contraseña y revocación.
- [x] G14-D4: coordinación de activación de MFA con bloqueo de cuenta.
- [x] G14-D5: 108 pruebas PostgreSQL 17, incluidos códigos de uso único y época MFA.
- [x] G14-D6: inventario estático validado, 12 archivos y 104 candidatos de revisión.

## Parcial
- [~] G14-D7: clasificación de 104 candidatos. Revisión de recuperación administrativa, enrolamiento y rotación realizada, sin auditoría completa.
- [x] G14-D8: PASS local de 110 pruebas PostgreSQL 17; rotación contra revocación y apertura administrativa contra emisión sintética.
- [~] Beta Android: ensayos físicos G13 positivos en su alcance. No representan aprobación del conjunto de gates.
- [~] Producto Web/Backend: desarrollo y validaciones previas en DEV; aceptación integral de funcionalidades no acreditada.

## Pendiente
- [~] G14-D9: **analizador PASS local** (commit af493c6c; 21 sitios de bloqueo en 5 módulos). Revisión de orden de locks y pruebas administrativas cruzadas aún pendientes; no es un PASS de seguridad integral.
- [ ] Emisor confiable con contraseña y MFA verificadas en servidor, sin aceptar evidencia afirmada por un llamante.
- [ ] Custodia de secretos y procedimiento de recuperación administrativa operativo y autorizado.
- [ ] Reconciliación de gates de beta G0–G9, revisión integral de funcionalidades y aceptación visual.
- [ ] Permiso de release, despliegue controlado y controles posteriores.

## Reglas
No activar rutas de login nativo ni liberar el emisor de laboratorio.
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
GLOBAL_FREEZE=NOT_VERIFIED

## Evidencias
- G14-D5: G14_D5_N1=0; G14_D5_BUILD=0; G14_D5_PG17=0; 108 tests PG17.
- G14-D6: HEAD 0f5af40d; G14_D6_TESTS=0; G14_D6_N1=0; G14_D6_INVENTORY=0; 12 ficheros, 104 candidatos.
- G14-D7: docs/G14_D7_MFA_WRITER_REVIEW_2026-11-05.md

Actualizar casillas únicamente al recibir una prueba verificable. Sin porcentaje global hasta reconciliar aceptación funcional y seguridad.


## 05/11/2026 — Hito G14-D8 preparado

- Archivo: `backend/native_mobile_service/test_g14_d8_admin_rotation_pg17.py` (2 tests PostgreSQL exclusivos, datos sintéticos).
- Incluidos en `scripts/n1_identity_pg17_ephemeral.sh --candidate`, GitHub Actions y `N1_STATIC_g14_d8_pg17_admin_rotation_isolated`.
- Se reutilizan las funciones MFA existentes, sin cambios en su lógica ni el modelo de datos; los tests no conceden permiso de recuperación administrativa real.
- **Estado:** `G14_D8_CODE=PUBLISHED`, `G14_D8_PG17_RESULT=NOT_RUN`. Quedan G14-D9, verificador MFA confiable, custodia, gates de release, UAT y despliegue controlado.


## 05/11/2026 — G14-D8 validado

El operador confirmó `G14_D8_N1=0`, `G14_D8_BUILD=0`, `G14_D8_PG17=0`, `N1_STATIC_g14_d8_pg17_admin_rotation_isolated=OK`, `N1_STATIC_GATE_RESULT=OK` y `Ran 110 tests in 15.865s`. La línea `G5_CANDIDATE_PG17_RESULT` llegó sin valor legible; no se adjudica un marcador específico a G5, aunque el comando PG17 terminó con código cero. **G14-D8 PASS local**. No implica autorización MFA operativa ni revisión completa del grafo de escritores.

Próximo bloque: G14-D9, revisión integral de locks, recuperación y gates de autorización. Mantener `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 05/11/2026 — D9 informe de bloqueos preparado

Nuevo informe de solo lectura `scripts/g14_mfa_lock_order_report.py`, pruebas `scripts/test_g14_mfa_lock_order_report.py` y marcador N1 `g14_d9_lock_report_readonly`. **Sin validación local aún.** El informe lista puntos `select_for_update` por función y orden de línea, pero no infiere orden dinámico entre transacciones ni certifica ausencia de interbloqueos. Los controles de recuperación administrativa y su evidencia externa siguen pendientes de validación completa. No hay modificación de lógica MFA ni despliegue.


## 05/11/2026 — G14-D9 informe validado (parcial)

El operador aportó `G14_D9_HEAD=af493c6c`, `G14_D9_TESTS=0`, `G14_D9_N1=0`, `G14_D9_REPORT=0`, `N1_STATIC_g14_d9_lock_report_readonly=OK`, `N1_STATIC_GATE_RESULT=OK` y `G14_D9_LOCK_SITES=21`. El informe es de solo lectura, no certifica seguridad transaccional. Próxima prioridad: contrastar conflictos entre el orden usuario→MFA de apertura administrativa, expediente→MFA de sustitución y MFA exclusivo de rotación; conservar controles fail-closed y ensayar PG17 efímero. Emisor MFA confiable y release siguen pendientes.


## 06/11/2026 — D9-B: cuatro regresiones negativas de verificador administrativo

**Publicado, pendiente de ejecutar.** `backend/native_mobile_service/test_g14_d9_recovery_guards_pg17.py`: verificador externo ausente, rechazo, valor truthy distinto de True y excepción; comprueba que no aparezca expediente ni cambie `session_epoch` en PostgreSQL 17 efímero. Añadido al runner `--candidate`, workflow y gate `N1_STATIC_g14_d9_recovery_verifier_failclosed_tests`.

- [x] D9-B fail-closed: **PASS local**; 114 pruebas PostgreSQL 17, controles N1 y build correctos.
- [ ] Carreras con modificación simultánea de expediente y sustitución de factores; auditoría definitiva del grafo de locks.
- [ ] Emisor MFA autoritativo / custodia operativa / autorización.

No se modificaron servicios MFA ni endpoints, no deploy, no migración persistente.


## 06/11/2026 — D9-B validación local confirmada

El operador informa: `G14_D9B_N1=0`, `G14_D9B_BUILD=0`, `G14_D9B_PG17=0`, `N1_STATIC_g14_d9_lock_report_readonly=OK`, `N1_STATIC_g14_d9_recovery_verifier_failclosed_tests=OK`, `N1_STATIC_GATE_RESULT=OK`, `Ran 114 tests in 19.592s`, `G5_CANDIDATE_PG17_RESULT=0`. **D9-B PASS local**. No se adjuntó SHA del checkout para el lote; no inferir CI remoto. Alcance: cuatro casos negativos de verificador administrativo sin expediente ni cambio de época. **D9 integral permanece parcial** hasta validar sustitución administrativa, carreras de caso y custodia/verificación operativa. Sin despliegue ni migración persistente.


## 06/11/2026 — D9-C carrera cancelación vs sustitución MFA: código listo

- [x] **G14-D9C**: PASS local, 116 pruebas PG17 (cancelación vs finalización y rechazo sin verificador). `backend/native_mobile_service/test_g14_d9c_admin_finalization_pg17.py`.
- Carrera real en base temporal: `cancel_recovery_case` contra `finalize_administrative_factor` con expediente y dos aprobaciones sintéticas; no pueden terminar ambas con éxito. Si el factor se sustituye, expediente cerrado y epoch incrementado; si se cancela, factor y epoch originales intactos.
- Segundo ensayo: falta del verificador externo de ejecución => rechazo, sin sustitución, sin cierre de expediente y sin revocación.
- Integrado en runner `--candidate`, GitHub Actions (skip SQLite) y N1 `g14_d9c_admin_factor_finalization_pg17`. **No se ha ejecutado todavía**. La evidencia externa positiva del test es un callback sintético, no un sistema de custodia real.
- Pendientes posteriores: pruebas de expiración simultánea, rechazo administrativo concurrente, callbacks externos transaccionales, emisor confiable MFA, custodia de claves, gates G0–G9 y UAT de beta.


## 06/11/2026 — G14-D9C PASS local (116 tests PG17)

El operador comunica `G14_D9C_N1=0`, `G14_D9C_BUILD=0`, `G14_D9C_PG17=0`, `N1_STATIC_g14_d9c_admin_factor_finalization_pg17=OK`, `N1_STATIC_GATE_RESULT=OK`, `Ran 116 tests in 18.464s`, `G5_CANDIDATE_PG17_RESULT=0`. **G14_D9C=PASS_LOCAL** para exclusión concurrente cancelación/finalización administrativa y rechazo sin verificador externo. Es prueba con datos sintéticos, no autorización de ejecución real. Quedan caducidad/rechazo frente a finalización, emisor verificado MFA, custodia, reconciliación de gates y UAT. `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — G14-D9D: terminales de expediente en carrera (pendiente PG17)

- [x] **G14-D9D**: dos tests PostgreSQL 17 PASS local en `backend/native_mobile_service/test_g14_d9c_admin_finalization_pg17.py`: `test_expiry_vs_finalization_cannot_both_succeed` y `test_rejection_vs_finalization_cannot_both_succeed`.
- Verifican que `EXPIRED` o `REJECTED` y `CLOSED` no resulten simultáneamente exitosos; si no se finaliza, factor activo y `session_epoch` se conservan. Si se finaliza, factor cambia y época se incrementa.
- El test de rechazo usa un tercer revisor autorizado sintético para que la denegación compita con dos aprobaciones ya almacenadas; el de caducidad inyecta una hora de expiración futura solo en la rama de caducidad. Ninguno simula custodia externa real.
- Registrado N1 `g14_d9d_terminal_case_races_pg17`. Como se amplió una suite existente ya incluida en el runner y CI, no se repiten entradas ni se cambia comportamiento de MFA.
- **G14_D9D_CODE=PUBLISHED; G14_D9D_PG17=NOT_RUN.** G14-D9 global permanece parcial; trusted MFA issuer, claves y autorización pendientes.


## 06/11/2026 — D9-D validación local confirmada (118 pruebas)

El operador confirma `G14_D9D_N1=0`, `G14_D9D_BUILD=0`, `G14_D9D_PG17=0`, `N1_STATIC_g14_d9d_terminal_case_races_pg17=OK`, `N1_STATIC_GATE_RESULT=OK`, `Ran 118 tests in 19.205s`, `G5_CANDIDATE_PG17_RESULT=0`. Los dos escenarios adicionales de expiración/rechazo frente a finalización son PASS en PostgreSQL 17 efímero; no se dispone de recibo CI remoto. **D9-D completado en laboratorio.** D9 global continúa parcial: cobertura exhaustiva de escritores/locks, evidencia externa real, custodia y emisión MFA confiable sin finalizar. No release, no despliegue ni migraciones persistentes.


## 06/11/2026 — G14-E0: inventario de llamadas al emisor de laboratorio (pendiente local)

- [x] **G14-E0**: script `scripts/g14_trusted_issuer_boundary.py` publicado; seis regresiones sintéticas `scripts/test_g14_trusted_issuer_boundary.py`, gate N1 `g14_trusted_issuer_direct_call_boundary`. Rechaza llamadas directas al emisor de bajo nivel en módulos no-test fuera del límite `g14_d3_candidate_boundary.py`. **Sin ejecución local todavía; no afirmar PASS.**
- [x] **G14-D9D**: 118 pruebas PG17 PASS local, evidencia recibida y documentada.
- [ ] **Emisor MFA confiable**: contrato de aceptación, riesgos y orden de bloqueos documentados en `docs/G14_TRUSTED_MFA_ISSUER_DESIGN_2026-11-06.md`; implementación y pruebas de emisión MFA real pendientes.
- [ ] Aprobación de recuperación administrativa con evidencias externas reales, custodia de claves, auditoría integral de escritores y gates G0–G9.

La comprobación AST no detecta toda llamada indirecta, no verifica contraseña/TOTP y no autoriza login nativo. Sin cambios operativos, sin despliegue y sin migraciones.


## 06/11/2026 — G14-E0: escaneo y N1 validados; tests unitarios sin recibo

Recibo aportado: `G14_E0_N1=0`; `G14_TRUSTED_BOUNDARY_DIRECT_CALLS=1`, `G14_TRUSTED_BOUNDARY_UNREVIEWED_CALLS=0`, `G14_TRUSTED_ISSUER_IMPLEMENTED=NO`, `G14_TRUSTED_BOUNDARY_SCAN=PASS`; `N1_STATIC_g14_trusted_issuer_direct_call_boundary=OK`, `N1_STATIC_GATE_RESULT=OK`. **E0 escaneo y N1: PASS local**. No se aportaron los indicadores `G14_E0_TESTS` y `G14_E0_AUDIT` ni el contenido de su log de tests: **no marcar pruebas unitarias E0 como PASS separado**. La salida del informe acredita su propio veredicto PASS, no el código de salida recibido. El emisor MFA confiable sigue sin implementar, y los hallazgos AST son sintácticos, no demostración completa de ausencia de llamadas indirectas. Siguiente bloque E1: prueba segura transaccional de contraseña y factor, sin endpoints ni autorización operativa.


## 06/11/2026 — G14-E0 cerrado con recibo completo

Recibo complementario del operador: `G14_E0_TESTS=0`, `G14_E0_AUDIT=0`. Junto con los marcadores anteriores `G14_E0_N1=0`, `G14_TRUSTED_BOUNDARY_UNREVIEWED_CALLS=0`, `G14_TRUSTED_BOUNDARY_SCAN=PASS`, `N1_STATIC_g14_trusted_issuer_direct_call_boundary=OK`, queda **G14-E0=PASS_LOCAL** para tests unitarios, escaneo AST y N1. La herramienta es una protección sintáctica parcial; `G14_TRUSTED_ISSUER_IMPLEMENTED=NO`. Próxima fase G14-E1 en laboratorio, sin habilitar rutas ni migrar la base persistente.


## 06/11/2026 — G14-E1 prueba autoritativa de contraseña + TOTP (pendiente local)

- [x] **G14-E1**: implementado en rama de laboratorio `backend/native_mobile_service/g14_e1_locked_mfa_verifier.py`. Pide credenciales originales, bloquea usuario→estado MFA en una transacción PostgreSQL y consume TOTP mediante el escritor anti-replay existente. Rechaza recuperación administrativa pendiente, no devuelve identidad, época ni capacidad, y **no emite ningún token**.
- Cinco regresiones PG17 en `native_mobile_service.test_g14_e1_locked_mfa_verifier`: verificación y replay, contraseña incorrecta, TOTP incorrecto, recuperación pendiente, input inválido.
- Integrado en el runner `--candidate`, CI y N1 `g14_e1_locked_mfa_proof_without_issuer`. **Publicado pero NO ejecutado localmente**.
- Es solo la primera etapa de un verificador compuesto, **no** el trusted issuer. Quedan cotas de abuso/auditoría, códigos de recuperación, errores, rollback, emisión atómica y carreras reales con cambios de cuenta/factor.
- Sin rutas operativas, despliegue ni migración persistente.


## 06/11/2026 — G14-E1 PASS local, 123 PG17 tests

Recibo del operador: `G14_E1_HEAD=60c3bbfae`, `G14_E1_N1=0`, `G14_E1_BUILD=0`, `G14_E1_PG17=0`, `N1_STATIC_g14_e1_locked_mfa_proof_without_issuer=OK`, `N1_STATIC_GATE_RESULT=OK`, `Ran 123 tests in 23.421s`, `G5_CANDIDATE_PG17_RESULT=0`. **G14-E1 PASS LOCAL** para verificación aislada de contraseña y TOTP bajo lock, sin token ni identidad devuelta al llamante. Sudo falló al primer intento pero el build/test concluyeron OK. **Siguiente fase E2:** composición transaccional de verificación de contraseña/MFA, emisión candidata y auditoría; diseñar y probar rollback, replay y carreras PG17 sin rutas operativas. No asumir emisión confiable antes de aceptación y revisión independiente. `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — G14-E2 contrato publicado, implementación bloqueada

- [x] Matriz de aceptación y rollback de un futuro emisor MFA: `docs/G14_E2_ATOMIC_ISSUANCE_ACCEPTANCE_2026-11-06.md`.
- [ ] **G14-E2 código**: NO publicado; intento de escritura de la composición de emisión bloqueado por controles de seguridad.
- [ ] **G14-E2 tests PG17**: no ejecutados; no existe evidencia que permita un PASS de emisión.
- [ ] **G14-E3** concurrencia y replay del emisor: pendiente.
- [ ] Autorización de MFA y beta: bloqueada.

Mantener la base previa de E1 (123 tests PASS local), sin atribuirle emisión segura. No se modificó ningún servicio operativo ni la base persistente.


## 06/11/2026 — G14-E1B validado con log PG17 adjunto

El operador entregó `vencira-e1b-pg17.log`: `N1_PG17=isolated (private internal network, tmpfs, no published ports)`, `N1_PG17_POSTGRES_READY=OK`, `Found 127 test(s).`, `System check identified no issues (0 silenced).`, `Ran 127 tests in 26.610s`, `OK`, `G4_CANDIDATE_PG17_RESULT=0`, `G5_CANDIDATE_PG17_RESULT=0`. N1 y Docker se habían informado OK en el lote previo. **G14-E1B=PASS_LOCAL_PG17_127_TESTS**. La ejecución está registrada en log de usuario, sin un SHA HEAD nuevo acreditado en ese log. Concurrencia MFA, bloqueo y presupuesto probados únicamente con datos sintéticos. G14-E2 emisor confiable aún no implementado; sin despliegue ni migración persistente.


## 06/11/2026 — G14-E1C rollback de verificación MFA (publicado, sin PASS)

- [~] E1C: se añaden tres pruebas PG17 test-only en `native_mobile_service.test_g14_e1c_transaction_rollback_pg17`: consumo TOTP con rollback exterior, contador de intentos fallidos con rollback exterior y rollback de savepoint interno seguido de prueba válida.
- Integradas en runner `--candidate`, workflow GitHub y N1 `g14_e1c_pg17_outer_savepoint_rollback`.
- **Evidencia local pendiente**. Base validada hasta E1B: 127 pruebas PG17 PASS; el nuevo lote debería contar 130 si no cambian otras suites.
- Estas pruebas usan directamente el verificador sin emitir sesiones; demuestran semántica de transacciones sobre el MFA sintético y no el compromiso atómico real token+auditoría. E2 continua sin emisor implementado.
- No cambian MFA operativo, rutas, migraciones ni despliegue.
