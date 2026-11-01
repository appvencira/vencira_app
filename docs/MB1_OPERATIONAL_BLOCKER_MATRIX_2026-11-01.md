# VENCIRA — Bloqueadores operativos MB1 (01/11/2026)

## Evidencia ya confirmada, no repetir
M1-02: ACK ambiguo simulado tras COMMIT y rollback PG17 PASS. M1-04: escritor cooperativo drenado y captura PG+objeto+diario PASS; bypass de administrador SQL y escritor FS no cooperativo CONFIRMADOS. M1-05: dos generaciones y restauración antirollback sintético PASS; O5 desde Drive restaura PostgreSQL solamente. PB: objeto Fernet real en disco efímero con PG17 PASS. Son ensayos de laboratorio, no autorización operativa.

## Gates pendientes y dependencias

| Gate | Requisito para cierre | Estado |
|---|---|---|
| G1 escritor universal | Completar revisión semántica de todas las rutas API, cron, systemd, administración, redes, SQL, filesystem y diario, incluidas rutas indirectas | BLOCKED: censo heurístico parcial (76 archivos, 264 llamadas, 131 P0) |
| G2 roles segregados | API no superusuario, administración y backup separados, permisos y bypass adversarial en infraestructura representativa | BLOCKED: DEV y preview aún usan rol SQL elevado |
| G3 corte global | Denegar realmente nuevas escrituras PG/FS no cooperativas, drenar writers, impedir privilegios, snapshot y restauración | BLOCKED: bypasses confirmados |
| G4 backup integral | O5 SQL+objeto+diario con manifiesto y antirollback obligatorio, restauración integral | BLOCKED: O5 PG-only |
| G5 custodia externa | Claves y cabeza separadas, otro host real, restauración completa | BLOCKED: último preflight externo ABORT en origen |
| G6 migración histórica | Dependencias MFA 0019-0027 resueltas y migración/rollback en clon | BLOCKED: coexistencia solo mediante tabla sintética |

## Próximo bloque de ingeniería agrupado
Realizar juntos G1–G3 **en diseño, inventario verificable y clon**: revisión semántica por capacidad/escritor, definición de propietarios de recursos, matriz de grants SQL para API/admin/backup y aislamiento de volúmenes/red; gate fail-closed que rechace cualquier canal sin identificar o writer externo no excluido. Una verificación de scripts/regex no prueba universalidad. No correr más capturas sintéticas equivalentes a las ya aprobadas. Prohibido modificar DEV o instalar O5, imponer bloqueo sin autorización, aplicar migraciones MFA o afirmar freeze global.

G4 y G5 se mantienen dependientes de custodia física real; su ejecución no puede sustituirse por un segundo contenedor en el VPS.

## Evidencia de referencia
- docs/MB1_EFFECTIVE_WRITER_COVERAGE_2026-10-30.md
- docs/MB1_M104_FAIL_CLOSED_WRITER_BOUNDARY_2026-10-31.md
- docs/MB1_M102_REAL_PG17_AMBIGUOUS_ACK_2026-10-31.md
- docs/MB1_M105_GATED_TWO_GENERATION_RESTORE_2026-10-31.md
- docs/MB1_M106_INDEPENDENT_O5_DR_GATE_2026-10-31.md
- docs/MB1_PB_FERNET_PG17_DISPOSABLE_2026-11-01.md

**Documento de análisis, no gate ejecutado.** Hitos 1/15 (6,7%). MB1_GLOBAL_FREEZE=NOT_VERIFIED; MB1_RELEASE_AUTHORIZED=NO; MFA_RELEASE_AUTHORIZED=NO; C_FICHA_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1.
