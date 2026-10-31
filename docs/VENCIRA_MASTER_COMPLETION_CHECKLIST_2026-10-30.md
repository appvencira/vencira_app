# VENCIRA — Checklist maestra de cierre (30/10/2026)

Fuente de seguimiento: esta checklist en la rama `feature/c-ficha-independent-attachments`. Marcar `[x]` únicamente con salida PASS del operador y evidencia documentada. **No confundir ensayos sintéticos con liberación operativa.**

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
- [ ] **M1-03** Censo completo de escritores y vías externas (API, cron/systemd, scripts, acceso SQL, objetos/diario)
- [ ] **M1-04** Definir e implantar el corte consistente de DB + archivos bajo concurrencia, primero en laboratorio; exclusión efectiva de nuevos escritores y ausencia de escrituras no cooperativas
  - **Captura única de laboratorio PASS (31/10):** ensayo `680ab7f`, PG17 + objeto Fernet + `IntakeJournal` con igual UUID/SHA256, copia durante una única ventana de `IsolatedProcessFence.capture()`, restore PG17 y descifrado/diario. Confirmado por operador: `MB1_REAL_JOINT_SINGLE_CAPTURE_WINDOW=OK`, `MB1_REAL_JOINT_PG17_OBJECT_JOURNAL_RESTORED=OK`, `MB1_REAL_JOINT_HASH_AND_DECRYPT_VERIFIED=OK`, `MB1_PG17_FENCE_EXIT_CODE=0`; evidencia `docs/MB1_PG17_CONNECTION_FENCE_LAB_2026-10-31.md`.
  - **Prueba adversarial PASS (31/10):** `MB1_UNCOOPERATIVE_FS_WRITE_BYPASS=CONFIRMED`, `MB1_NONCOOPERATIVE_SQL_ADMIN_WRITE_BYPASS=CONFIRMED`, `MB1_UNIVERSAL_FREEZE_FAIL_CLOSED=OK`, `MB1_NONCOOPERATIVE_EXIT_CODE=0`. Esto demuestra que los mecanismos actuales **son eludibles**; no representa una autorización de freeze.
  - **Aislamiento del dominio sintético PASS (31/10):** `MB1_DOMAIN_REAL_SQL_AND_FILE_WRITER=OK`, `MB1_DOMAIN_WRITER_PROCESS_DRAINED=OK`, `MB1_DOMAIN_QUIESCENCE_CROSS_RESOURCE=OK`, `MB1_DOMAIN_READONLY_MOUNT_DENIES_WRITE=OK`, `MB1_DOMAIN_QUIESCED_SNAPSHOT_RESTORE=OK`, `MB1_DOMAIN_ISOLATION_RESULT=0`, `MB1_DOMAIN_EXIT_CODE=0`; evidencia `docs/MB1_M104_FAIL_CLOSED_WRITER_BOUNDARY_2026-10-31.md` (`233afb5`). Quedan excluidos **solo** los escritores del dominio temporal controlado. **Persisten bypass SQL superusuario y actores externos del host**; mantener `MB1_GLOBAL_FREEZE=NOT_VERIFIED` y **no marcar [x]**.
- [ ] **M1-05** Backup completo con manifiesto, anti-rollback y restauración cruzada, evidencias en segundo host
  - Manifiesto HMAC sintético B09, retención no destructiva y restauración independiente PG17 + archivos previamente validados. **Anti-rollback puro PASS (31/10):** 11 tests OK y `MB1_ANTIROLLBACK_EXIT_CODE=0` con `offline_antirollback_head_mb1.py` (`ff0367f`), pruebas `a000126`.
  - **Integración física propuesta, SIN VALIDAR:** adaptación a los tres ficheros `capture.enc`, `manifest.json`, `manifest.mac` (`c6dde95`) y 12 pruebas nuevas (`4d148d3`), documentadas en `docs/MB1_M105_ANTIROLLBACK_TRUSTED_HEAD_2026-10-31.md`. La cabeza externa real, custodia, antirollback operativo y su acoplamiento a recuperación real siguen pendientes; no marcar [x].
- [ ] **M1-06** Custodia **operativa** externa de backup y claves, retención, rotación, custodia independiente y recuperación tras pérdida total del VPS
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
