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
