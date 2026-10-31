# VENCIRA — Checklist maestra de cierre (30/10/2026)

Fuente de seguimiento: esta checklist en la rama `feature/c-ficha-independent-attachments`. Marcar `[x]` únicamente con salida PASS del operador y evidencia documentada. **No confundir ensayos sintéticos con liberación operativa.**

## PANEL DE PROGRESO — actualización 31/10/2026

| Bloque | Hitos cerrados | Total | Cierre por hitos |
|---|---:|---:|---:|
| MB1 — Copias y recuperación | **1** | 7 | **14,3 %** |
| MB2 — MFA y adjuntos | **0** | 4 | **0 %** |
| MB3 — Producto y comercialización | **0** | 4 | **0 %** |
| **TOTAL** | **1** | **15** | **6,7 %** |

**Método:** solo cuenta `[x] **M1-01**` y los otros 14 hitos principales del inventario; `[ ]` sigue pendiente aunque tenga diez o cien subpruebas PASS. Esta cifra **mide cierre formal**, no funcionalidad implementada, cobertura de tests, madurez general ni porcentaje de trabajo restante. Todos los hitos pueden tener distinto esfuerzo.

**Último avance confirmado (31/10): restauración PostgreSQL real desde la copia cifrada O5 de Google Drive en PG17 temporal, sin red.** 10 pruebas del validador `OK`, 25 tablas restauradas, `O5_RESTORED_BASELINE_SCHEMA=OK`, `MB1_O5_GROUP_DEV_CONTAINER_ID_AND_HEALTH_UNCHANGED=OK`, `MB1_O5_GROUP_RESULT=0`, `MB1_O5_GROUP_EXIT_CODE=0`. Documento `docs/MB1_O5_GROUPED_DRIVE_RESTORE_2026-10-31.md`, commit `04cc24d`. El ensayo ejecutó el restaurador candidato versionado; el O5 instalado y su planificador no fueron sustituidos.

**Siguiente avance requerido:** dejar de repetir restauraciones PG17 ya superadas y demostrar custodia independiente fuera del VPS, prueba de recuperación desde segundo host con esas credenciales y, cuando haya adjuntos operativos, captura integral + cierre de escritores. `MB1_O5_OPERATIONAL_ANTIROLLBACK=NOT_INTEGRATED`, `MB1_O5_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`. **Porcentaje de hitos sin cambios**.

**Bloque en validación (M1-02):** 22 pruebas agrupadas de fallos de intake, conciliación conservadora y archivos/diarios dañados en Docker efímero; 8 casos nuevos. No cuentan como PASS hasta recibir salida del operador. Evidencia preparada: `docs/MB1_M102_GROUPED_FAILURE_M106_EXTERNAL_CUSTODY_2026-10-31.md` (`e55e56b`).

**Subpruebas relevantes validadas, sin cierre de hito:** M1-04 captura conjunta PG17/objeto/diario; detección de bypasses SQL/FS; aislamiento de escritor temporal; M1-05 11 tests anti-rollback, 23 tests paquete físico, dos generaciones/restauración protegida; lectura O5 y comparación de migraciones; contrato O5 corregido. Los controles de laboratorio están documentados debajo de sus hitos.

**Bloqueos que impiden cierre:** M1-04 escritores privilegiados/externos; M1-05 verificación y recuperación operativa con ancla externa; M1-06 custodia externa auténtica; MB2 MFA/adjuntos sin autorización; MB3 aceptación comercial. **No despliegue, no migración live.**

**Regla de seguimiento para próximas sesiones:** registrar cada resultado PASS/FAIL con fecha, evidencia y commit en el hito correspondiente; actualizar este panel y anotar explícitamente lo que sigue pendiente. No incrementar porcentaje porque haya más tests si no se ha cerrado un hito.



## MB1 — Copias y recuperación

- [x] E2E PG17 sintético: pg_dump/restauración y paquete cifrado autenticado; prueba de clave incorrecta/manipulación
- [x] Restauración en Ubuntu x86_64 **independiente** con paquete y claves sintéticas separadas; PG17 + objeto + diario + hashes recuperados `4b13842`
- [x] Persistencia de volúmenes Docker de objetos/diario tras recrear contenedor `860f53c`
- [x] Integración Django / `PrivateQuarantineStore` / `IntakeJournal` / PG17 efímero `0797ea8`
- [x] Contrato de seis interrupciones simulado `c43405e`
- [x] Clasificador puro de inventarios incompletos (10 pruebas) `cb138f4`
- [x] Inventario inicial de los dos proyectos Docker y confirmación de Caddy: DEV servido por `vencira_localcheck`
- [x] **M1-01** Integración del clasificador con inventario PG17 + volúmenes temporales; estados incompletos detectados. PASS operador: `MB1_INTEGRATED_PG17_ORPHAN_CLASSIFICATION=OK`, `MB1_INTEGRATED_RESULT=0`, `MB1_INTEGRATED_EXIT_CODE=0`. Implementación `52464eb`
- [ ] **M1-02** Pruebas de interrupción real de procesos, pérdidas parciales y recuperación/reconciliación fail-closed: ninguna eliminación automática
  - **Nuevo bloque agrupado, pendiente de operador:** `scripts/validate_mb1_m102_grouped_failclosed.sh` (`d9fa85f`) ejecuta en una sola imagen 6 tests históricos de intake, 8 B18L y 8 nuevos de almacén Fernet/diario (`67f5de1`) para corrupción, truncamiento y fsync fallidos. El SIGKILL PG17 real con exit 137 ya fue PASS previo y no se repite. Documentación `docs/MB1_M102_GROUPED_FAILURE_M106_EXTERNAL_CUSTODY_2026-10-31.md` (`e55e56b`). Aún falta commit ambiguo, pérdida de energía real y reparación operativa; no cerrar M1-02.
- [ ] **M1-03** Censo completo de escritores y vías externas (API, cron/systemd, scripts, acceso SQL, objetos/diario)
- [ ] **M1-04** Definir e implantar el corte consistente de DB + archivos bajo concurrencia, primero en laboratorio; exclusión efectiva de nuevos escritores y ausencia de escrituras no cooperativas
  - **Captura única de laboratorio PASS (31/10):** ensayo `680ab7f`, PG17 + objeto Fernet + `IntakeJournal` con igual UUID/SHA256, copia durante una única ventana de `IsolatedProcessFence.capture()`, restore PG17 y descifrado/diario. Confirmado por operador: `MB1_REAL_JOINT_SINGLE_CAPTURE_WINDOW=OK`, `MB1_REAL_JOINT_PG17_OBJECT_JOURNAL_RESTORED=OK`, `MB1_REAL_JOINT_HASH_AND_DECRYPT_VERIFIED=OK`, `MB1_PG17_FENCE_EXIT_CODE=0`; evidencia `docs/MB1_PG17_CONNECTION_FENCE_LAB_2026-10-31.md`.
  - **Prueba adversarial PASS (31/10):** `MB1_UNCOOPERATIVE_FS_WRITE_BYPASS=CONFIRMED`, `MB1_NONCOOPERATIVE_SQL_ADMIN_WRITE_BYPASS=CONFIRMED`, `MB1_UNIVERSAL_FREEZE_FAIL_CLOSED=OK`, `MB1_NONCOOPERATIVE_EXIT_CODE=0`. Esto demuestra que los mecanismos actuales **son eludibles**; no representa una autorización de freeze.
  - **Aislamiento del dominio sintético PASS (31/10):** `MB1_DOMAIN_REAL_SQL_AND_FILE_WRITER=OK`, `MB1_DOMAIN_WRITER_PROCESS_DRAINED=OK`, `MB1_DOMAIN_QUIESCENCE_CROSS_RESOURCE=OK`, `MB1_DOMAIN_READONLY_MOUNT_DENIES_WRITE=OK`, `MB1_DOMAIN_QUIESCED_SNAPSHOT_RESTORE=OK`, `MB1_DOMAIN_ISOLATION_RESULT=0`, `MB1_DOMAIN_EXIT_CODE=0`; evidencia `docs/MB1_M104_FAIL_CLOSED_WRITER_BOUNDARY_2026-10-31.md` (`233afb5`). Quedan excluidos **solo** los escritores del dominio temporal controlado. **Persisten bypass SQL superusuario y actores externos del host**; mantener `MB1_GLOBAL_FREEZE=NOT_VERIFIED` y **no marcar [x]**.
- [ ] **M1-05** Backup completo con manifiesto, anti-rollback y restauración cruzada, evidencias en segundo host
  - Manifiesto HMAC sintético B09, retención no destructiva y restauración independiente PG17 + archivos previamente validados. **Anti-rollback puro PASS (31/10):** 11 tests OK y `MB1_ANTIROLLBACK_EXIT_CODE=0` con `offline_antirollback_head_mb1.py` (`ff0367f`), pruebas `a000126`.
  - **Integración física sintética PASS (31/10):** `Ran 23 tests in 0.031s`, `OK`, `MB1_ANTIROLLBACK_PACKAGE_EXIT_CODE=0` (11 tests de cabeza y 12 de los tres archivos `capture.enc`, `manifest.json`, `manifest.mac`), código `c6dde95` y `4d148d3`; evidencia `docs/MB1_M105_ANTIROLLBACK_TRUSTED_HEAD_2026-10-31.md` (`c938efa`). **Sigue sin verificarse custodia externa de cabeza ni integración de la comprobación como preflight obligatorio antes de restaurar**; no marcar [x].
  - **Gate integrado de dos generaciones — PASS (31/10):** script `scripts/rehearse_mb1_antirollback_gated_restore_disposable.py` (`9da9b99`) superado por operador: `MB1_STALE_VALID_PACKAGE_REJECTED_BEFORE_RESTORE=OK`, `MB1_CURRENT_PG17_RESTORE_AFTER_GATE=OK`, `MB1_CURRENT_OBJECT_JOURNAL_RESTORE=OK`, `MB1_ANTIROLLBACK_GATED_E2E_LAB=OK`, `MB1_ANTIROLLBACK_E2E_RESULT=0`, `MB1_ANTIROLLBACK_E2E_EXIT_CODE=0`. Evidencia completa: `docs/MB1_M105_GATED_TWO_GENERATION_RESTORE_2026-10-31.md` (`f86e43c`). **Cabeza simulada en el mismo host, sin custodia externa ni integración O5 ni freeze global.** M1-05 continúa [ ].
  - **Auditoría O5 real solo lectura PASS (31/10):** `MB1_O5_RESTORE_PIN_MATCHES_LIVE=NO`, `MB1_O5_SUCCESS_MARKER=RECENT`, `MB1_O5_READONLY_AUDIT_RESULT=0`, `MB1_O5_READONLY_EXIT_CODE=0`. O5 en Git sigue siendo solo PostgreSQL; no se ha probado restaurabilidad remota. Evidencia `docs/MB1_O5_OPERATIONAL_GAP_AUDIT_2026-10-31.md` (`761c60a`).
  - **Corrección de pin O5 — VALIDADA en fuentes (31/10), SIN DESPLEGAR:** `o5_restore_drill.sh` (`82e1fa0`) comprueba base `0014_renewal_outcomes` + tablas restauradas mediante `scripts/o5_restore_schema_contract.py` (`c249f43`); batería versionada de 10 casos (`59c646b`) confirmada por operador con `OK`, `MB1_O5_SCHEMA_FIX_EXIT_CODE=0`. Evidencia `docs/MB1_O5_OPERATIONAL_GAP_AUDIT_2026-10-31.md` (`81e0869`). El instalador/servicio O5 sigue sin cambiar; falta prueba de restauración desde Drive y validación integral. No cerrar M1-05.
  - **Restauración agrupada O5 desde Drive PASS (31/10):** `validate_mb1_o5_grouped_remote_restore.sh` (`7265e8d`), 10 tests OK, PG17 efímero sin red, `RESTAURACION_PG17_DESDE_DRIVE=OK`, esquema minimo y **25 tablas recuperadas**, `POSTGRES_ORIGINAL_INTACTO=1`, `MB1_O5_GROUP_RESULT=0`, `MB1_O5_GROUP_EXIT_CODE=0`. Evidencia `docs/MB1_O5_GROUPED_DRIVE_RESTORE_2026-10-31.md` (`04cc24d`). Esto acredita restauración remota PG-only desde Drive, **no** custodia externa independiente, antirollback operacional, adjuntos o freeze. M1-05 continúa [ ].
- [ ] **M1-06** Custodia **operativa** externa de backup y claves, retención, rotación, custodia independiente y recuperación tras pérdida total del VPS
  - **Requisitos externos definidos y pendientes:** destino A con paquete cifrado, custodio B independiente con claves y cabeza antirollback, restaurador C en otro equipo sin VPS original. Documento `docs/MB1_M102_GROUPED_FAILURE_M106_EXTERNAL_CUSTODY_2026-10-31.md`. No generar ni exponer secretos. La restauración PG17 desde Drive en el mismo VPS no satisface el requisito.
- [ ] **M1-07** Gate integrado final, restauración y revisión de seguridad, con decisión explícita de autorización

## MB2 — Seguridad y adjuntos

- [x] Pruebas sintéticas de MFA/custodia y recuperación administrativa (gates previos)
- [x] Ensayos aislados ClamAV/PG17 para adjuntos
- [ ] **M2-01** Custodia externa MFA real y prueba de recuperación; `MFA_RELEASE_AUTHORIZED=NO`
- [ ] **M2-02** Completar compuertas de adjuntos: scanner, firmas, aislamiento, ciclo de vida, integración ORM y pruebas adversariales
- [ ] **M2-03** Migraciones en clon, prueba de rollback y aceptación; no tocar esquema DEV sin autorización
- [ ] **M2-04** Revisión de seguridad y liberación separada de MFA y adjuntos

## MB3 — Producto V1 y salida comercial

- [ ] **M3-01** Reconciliar funciones actuales con el whitepaper y registrar diferencias verificadas
- [ ] **M3-02** Completar flujos y UX móvil premium, recordatorios y reglas de vencimiento
- [ ] **M3-03** Pruebas E2E, accesibilidad, rendimiento y documentación de uso
- [ ] **M3-04** Preparar despliegue gradual, backup, observabilidad y validación de aceptación

## Límites actuales

```text
MB1_OPERATIONAL_RELEASE=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

La lista recoge los **trabajos de cierre conocidos**, no plazos ni porcentajes. Se puede ampliar si aparecen fallos. No tachar por código publicado: solo tras ejecución confirmada.
