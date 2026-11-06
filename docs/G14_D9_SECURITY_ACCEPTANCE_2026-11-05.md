# G14-D9 — Matriz de aceptación de seguridad MFA

Corte: 2026-11-05. **Estado: revisión en curso, no gate superado.** Rama `feature/m3-android-local-notifications`, PR #17 sin merge.

## Evidencia aceptada

- G14-D3: composición test-only no-MFA, emitida bajo una transacción que mantiene el bloqueo del usuario hasta auditoría.
- G14-D4: `finalize_mfa` bloquea cuenta antes de `UserMfaState`; carrera PG17 local PASS.
- G14-D5: tres carreras MFA (TOTP, recovery, epoch); 108 pruebas PG17 PASS.
- G14-D6: AST, 12 archivos y 104 candidatos, inventario heurístico; no prueba exhaustividad.
- G14-D7: análisis de fuentes prioritarias, no cierre del grafo de locks.
- G14-D8: dos nuevas pruebas de rotación/revocación y apertura/issuance, 110 tests PG17 PASS, N1 y build 0.

## Revisión de bloqueos por función

| Ruta | Bloqueos vistos | Evidencia | Pendiente |
|---|---|---|---|
| `mfa_enrollment.finalize_mfa` | usuario → MFA | carrera D4 PASS | transiciones de otros flujos |
| `mfa_admin_recovery_service.open_recovery_case` | usuario → MFA → expediente nuevo | carrera D8 PASS | escritor de expediente/otros cambios, caso pendiente y cierre |
| `mfa_admin_recovery_service.prepare/confirm/finalize_administrative_factor` | expediente → MFA | unitarias existentes, no carrera cruzada completa | verificar permisos externos y estado mutable bajo lock, rotación y auditoría |
| `mfa_factor_rotation.prepare/confirm/finalize_factor_rotation` | MFA | D8 finalización vs revocación PASS | riesgos de carrera con comienzo de recuperación y consumo de challenge |
| `mfa_store.consume_totp/consume_recovery_code` | MFA | D5 exclusión concurrente PASS | integrar en emisor confiable y conservar fallos |
| `mfa_session_revocation.revoke_mfa_sessions` | MFA | D5/D8 PASS | asegurar que todas las vías de revocación compartan reglas |
| `mfa_enrollment_api` y `mfa_challenge` | capa sesión, MFA | fuente leída | gates de flags, custodia, sesión y CSRF |

No se observó inversión de locks concluyente en los recorridos examinados, pero no se puede certificar ausencia de deadlocks por esta muestra. Una prueba de carrera con 2 hilos no cubre todos los interleavings. No ampliar el estado PASS a rutas no ensayadas.

## Bloqueos explícitos antes de autorización operativa

- [ ] Comprobar todos los escritores administrativos, incluidos SQL/alias no detectados por AST.
- [ ] Probar caducidad de aprobaciones, revalidación de verificadores externos y rollback del reemplazo administrativo; no confiar en evidencias simuladas para producción.
- [ ] Definir y probar un emisor de MFA de confianza que verifique contraseña y segundo factor en servidor, con auditoría atómica y sin flags suministrados por el cliente.
- [ ] Confirmar custodia de claves, rotación, revocación, prevención de replay y recuperación tras pérdida de respuesta.
- [ ] Cerrar aislamiento de rutas, permiso por recurso, retención y controles de abuso; gates G0–G9 según su aceptación.
- [ ] Confirmar UAT, backup/restauración, reversión y autorización explícita antes de release.

**Decisión D9 actual:** `SECURITY_REVIEW=PARTIAL`, `TRUSTED_MFA_ISSUER=NOT_IMPLEMENTED`, `RELEASE_AUTHORIZED=NO`. No desplegar, migrar DB persistente ni fusionar PR.

Referencias internas: `docs/G14_D7_MFA_WRITER_REVIEW_2026-11-05.md`, `docs/G14_PROGRESS_CHECKLIST_2026-11-05.md`, `docs/PROGRESS_NATIVE_BETA_G14_2026-11-04.md`.


## 05/11/2026 — D9 lock-site report staged

Added a read-only AST report `scripts/g14_mfa_lock_order_report.py` covering five existing MFA modules (enrollment, store, session revocation, factor rotation, administrative recovery). The report lists `select_for_update` call lines per function; **source-line order is not a dynamic lock-order proof**. Three synthetic parser tests and static N1 presence check are included. All pending local execution; no MFA business logic or production database touched.

To accept: run tests, N1, and report, then classify the resulting lock-site lines. This remains a tool supporting review, not completion of G14-D9 or permission to expose mobile identity endpoints. Real administrative-execution evidence and operational issuer remain unverified.


## 05/11/2026 — Informe de 21 puntos de bloqueo validado localmente

El operador comunica HEAD `af493c6c`, `G14_D9_TESTS=0`, `G14_D9_N1=0`, `G14_D9_REPORT=0`, gate N1 OK y `G14_D9_LOCK_SITES=21`, sin fallos de ejecución. Los 21 corresponden a cinco módulos, no 21 defectos.

**Distribución contrastada con líneas del informe:**
- `mfa_enrollment.py`: 4 puntos; `prepare_mfa` (31), `confirm_mfa` (55), `finalize_mfa` (101 y 105, cuenta→estado).
- `mfa_store.py`: 2 puntos de estado (TOTP 46, recovery 68).
- `mfa_session_revocation.py`: 1 punto de estado (19).
- `mfa_factor_rotation.py`: 3 puntos de estado (32, 68 y 103).
- `mfa_admin_recovery_service.py`: 11 puntos; revisión/cancelación/expiración de expediente, apertura usuario→MFA y preparación/confirmación/finalización expediente→MFA.

**Dictamen:** inventario y pruebas del analizador `PASS_LOCAL`, **auditoría transaccional integral D9 todavía abierta**. No afirmar ausencia de deadlocks, carreras o seguridad del emisor. Prioridad técnica: comprobar el grafo de transacciones que mezclan cuenta, expediente y MFA, especialmente la apertura administrativa contra cualquier cierre de factor o modificación de expediente. Distinguir órdenes sintácticos de locks efectivos (FK, ORM y callbacks externos). Mantener release bloqueado.


## 06/11/2026 — D9-B pruebas de fallo cerrado preparadas

Cuatro escenarios negativos de verificación independiente en `test_g14_d9_recovery_guards_pg17.py`: callback no configurado, False, valor no exactamente True (1) y error de callback. En cada escenario el resultado esperado es ausencia de expediente y ausencia de revocación de época. Test-only, PG17 aislado. Conectados N1, `--candidate` y CI; resultado pendiente. No equivale a validar ejecución administrativa de sustitución; pendientes los interleavings de caso→MFA y las garantías de custodia.

```
G14_D9_B_CODE=PUBLISHED
G14_D9_B_LOCAL_RESULT=NOT_RUN
G14_D9_SECURITY_ACCEPTANCE=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## 06/11/2026 — D9-B PG17 local PASS

Evidence from operator: `G14_D9B_N1=0`, `G14_D9B_BUILD=0`, `G14_D9B_PG17=0`, `N1_STATIC_g14_d9_lock_report_readonly=OK`, `N1_STATIC_g14_d9_recovery_verifier_failclosed_tests=OK`, `N1_STATIC_GATE_RESULT=OK`, `Ran 114 tests in 19.592s`, `G5_CANDIDATE_PG17_RESULT=0`. **D9-B PASS local**. The result validates only these synthetic negative-verifier cases in temporary PG17, not end-to-end administrative authorization. Checkout HEAD not included; remote Actions status not established.

Remaining: cross-transaction races involving case cancellation/expiry/finalization, complete independent authorization and delivery/custody evidence, trusted MFA issuer and release gates. `G14_D9_SECURITY_ACCEPTANCE=PARTIAL`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — D9-C pruebas transaccionales administrativas preparadas

Se incorporan dos pruebas PG17 a la rama de laboratorio: cancelación de expediente frente a finalización de reemplazo del factor (exclusión mutua de éxito y ausencia de estado mixto) y ausencia de verificador externo de ejecución (reemplazo denegado). Suite: `native_mobile_service.test_g14_d9c_admin_finalization_pg17`. Integradas en N1 y CI, resultado local pendiente. El ensayo usa aprobaciones y verificadores sintéticos, no habilita recuperación real ni demuestra ausencia de deadlocks en interleavings no cubiertos.

```
G14_D9B=PASS_LOCAL_114_TESTS
G14_D9C_CODE=PUBLISHED
G14_D9C_PG17_RESULT=NOT_RUN
G14_D9_SECURITY_ACCEPTANCE=PARTIAL
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
