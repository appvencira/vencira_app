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
