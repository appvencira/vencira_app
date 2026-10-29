# VENCIRA — Plan integrado de tres macrobloques (29/10/2026)

Referencia funcional: [whitepaper original](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md); secuenciación de producto: [plan maestro](WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md). Estados técnicos: [B18B](B18B_D10_CAPTURE_COORDINATION_2026-10-29.md), [B18A](B18A_WRITER_CAPTURE_AUDIT_2026-10-29.md), [B18 brechas](B18_INTEGRAL_RECOVERY_GAP_2026-10-29.md).

## Macrobloque 1 — recuperación, fallos y consistencia

**Ya acreditado**: B18B D10 PG17 focalizado pasó sobre `7758784` según salida del operador, sin autorizar producto. B09 ya desarrolla manifiesto autenticado, backup de objetos+diario y verificación integral cifrada; no rehacerlo.

**Preparado en GitHub**: `scripts/validate_mb1_synthetic_recovery.sh` (commit `fe654acd`) empaqueta una batería de tests EXISTENTES B09 manifiesto, B09 restauración verificada, B06A consistencia de marcadores y D3 doble fallo. Usa Docker `--network none` y SQLite test para estas pruebas sin base persistente, sin publicar puertos ni montar claves reales. **No equivale a un disaster-recovery drill PG17**.

**Pendiente técnico de mayor valor**: inventario completo y bloqueo real de escritores no cooperativos; prueba concurrente DB+objetos+diario con corte y crash en PG17 efímero; verificación de un conjunto desde soporte independiente con restauración completa. El protocolo operativo aún carece de freeze transversal.

Ejecutar una sola vez sobre checkout limpio, preservando `clients/flutter/pubspec.lock`:
```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/validate_mb1_synthetic_recovery.sh
echo "MB1_SYNTHETIC_EXIT_CODE=$?"
```

Esperar `MB1_RESULT=0`, `MB1_SYNTHETIC_EXIT_CODE=0`. Si falla, no se cierra ningún gate; investigar `MB1_FAILED_PHASE`.

## Macrobloque 2 — custodia MFA, adjuntos y lanzamiento protegido

Acreditar custodios independientes reales, custodia de claves antiguas, recuperación sin factores, O5+objetos/diario/clave, permisos y circuito ClamAV, compatibilidad de esquemas sin desbloquear la genealogía 0027, control de rollback y autorizaciones explícitas separadas. Gates existentes B14/B17 no se repiten salvo modificaciones relevantes.

## Macrobloque 3 — alineación whitepaper y V1 comercial

Matriz exhaustiva de requisitos §§1–18 → código/API/Flutter/test/UAT → resultado PASS/PARTIAL/BLOCKED, sin inferir envíos email/push, offline real, import/export, equipos, pagos o RGPD de simples borradores. Resolver solo huecos priorizados; full regression, aceptación Android/PC, evidencia de recuperación, despliegue y seguimiento.

## Condiciones innegociables
```text
MB1_SYNTHETIC_TESTS=PENDING_OPERATOR_EXECUTION
MB1_OPERATIONAL_RECOVERY=BLOCKED
MB2_RELEASE_AUTHORIZED=NO
MB3_COMMERCIAL_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

Toda decisión, gate y evidencia se registra en GitHub. No habilitar adjuntos ni MFA ni migrar PostgreSQL persistente sin autorización documentada.


## Resultado MB1 sintético — operador, 29/10/2026

Ejecución reportada: `Ran 41 tests in 0.018s`, `OK`, `MB1_SYNTHETIC_BACKUP_MANIFEST=TESTED`, `MB1_SYNTHETIC_DB_OBJECT_JOURNAL_RECOVERY=TESTED`, `MB1_CAPTURE_FENCE_AND_DOUBLE_FAILURE=TESTED`, `MB1_RESULT=0`, `MB1_SYNTHETIC_EXIT_CODE=0`. El runner acredita **41 pruebas sintéticas superadas**; no certifica captura universal ni disaster recovery. Permanecen explícitamente `MB1_OPERATIONAL_WRITER_FREEZE=NOT_VERIFIED`, `MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_FULL_RECOVERY_DRILL=NOT_RUN`. La custodia externa y la recuperación integral con PG17 deben verificarse antes de permitir despliegue. `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
