# VENCIRA — MB1 B18L: conciliación segura de intenciones pendientes

30/10/2026. Revisión estática: `reminders/attachment_quarantine_intake.py` registra intención durable antes del objeto y metadata. Si el objeto falla, la intención permanece; si falla metadata, intenta descartar el objeto, pero la intención sigue pendiente. El diario es evidencia que debe conciliarse; **eliminarlo automáticamente ocultaría estados incompletos**.

B18L entrega un clasificador puro `offline_pending_intent_reconcile_b18l.py` de seis estados de presencia e integridad que devuelve siempre revisión humana requerida, sin permitir borrado ni publicación; ocho tests negativos/positivos de contrato y un gate Docker aislado. No lee el almacén ni conecta a PG17, no recompone un backup ni comprueba cobertura de escritores; las evidencias de entrada deben autenticarse de manera independiente antes de una reconciliación operativa.

Ejecución:
```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/validate_b18l_pending_intents.sh
echo "B18L_EXIT_CODE=$?"
```

Esperado 8 tests OK, `B18L_PENDING_INTENT_CONTRACTS=OK`, `B18L_RESULT=0`, `B18L_EXIT_CODE=0`. **Pendiente ejecución**. No repetir B18B–K. B18K static gate superado por operador: 131 contextos, cero inesperados entre cinco parejas de llamada vigiladas; no constituye revisión completa.

```text
B18L_RUNTIME=PENDING
B18L_OPERATIONAL_RECONCILIATION=NOT_IMPLEMENTED
MB1_CAPTURE_AND_DR=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
