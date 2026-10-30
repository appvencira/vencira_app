# VENCIRA — MB1 B18I: clasificación inicial de candidatos a escritor

30/10/2026. Partimos del B18H confirmado por operador: 76 archivos, 264 llamadas candidatas, 0 errores de AST. No se dispone en GitHub del JSON local detallado; no inventar cifras por categoría.

## Implementación

`scripts/triage_b18i_candidate_writers.py` consume el JSON generado por B18H y etiqueta **todos** los registros según el origen de llamada (posible BD, filesystem, proceso externo) y prioridad de revisión. P0: ruta cuyo nombre alude a adjuntos/diario/cuarentena/outbox/recuperación/backup; P1: filesystem/proceso en otra ruta; P2: candidato restante. Estas son **heurísticas de priorización**, no vulnerabilidades demostradas ni clasificación verificada de efectos. En todos los registros `status=UNREVIEWED`; `reviewed=0` y `release_authorized=false`. Verificar que la suma coincide con el total de B18H.

## Comando en VPS

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
python3 scripts/triage_b18i_candidate_writers.py \
  /tmp/vencira-b18h-writer-candidates.json \
  --output /tmp/vencira-b18i-triage.json
echo "B18I_EXIT_CODE=$?"
```

Compartir resumen `B18I_CANDIDATES`, `B18I_P0`, `B18I_P1`, `B18I_P2`. No es necesario pegar los 264 registros al chat. El JSON permanece en /tmp y no se envía a GitHub automáticamente.

## Próximo trabajo

Revisar P0 módulo por módulo, con especial atención a `offline_intake`, `attachment_quarantine_intake`, `offline_intake_journal`, `offline_transport_receiver_b17`, `offline_rejection_recovery`, `offline_recovery_persistence_d10`; resolver *también* mutadores indirectos sin patrones AST y scripts shell, endpoints y procesos ajenos. Una vez cerrada esa revisión, definir mecanismo único con control efectivo de acceso a BD y almacenamiento durante instantánea, y ensayar recuperación completa sobre clon.

```text
B18I_TRIAGE_EXECUTION=PENDING
B18I_MANUAL_REVIEW=NOT_STARTED
B18I_CENSUS_EXHAUSTIVE=NO
MB1_GLOBAL_FREEZE=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Ejecución operador — 30/10/2026

Resultado comunicado: `B18I_CANDIDATES=264`, `B18I_P0=131`, `B18I_P1=15`, `B18I_P2=118`, `B18I_REVIEWED=0`, `B18I_GLOBAL_FREEZE=NOT_VERIFIED`, `B18I_EXIT_CODE=0`. Suma comprobada: 131+15+118=264. Clasificación automática correcta según resultado aportado; sin revisión manual ni prueba de exhaustividad. Próximo paso: inspección focalizada de los 131 P0 usando su JSON local y clasificación de mutadores reales frente a falsos positivos. No desplegar ni migrar.
