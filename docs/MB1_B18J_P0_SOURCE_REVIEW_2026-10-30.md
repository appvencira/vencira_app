# VENCIRA — B18J: cola de revisión P0 de escritores

**Fecha:** 30/10/2026. B18I detectó 264 llamadas candidatas (P0 131, P1 15, P2 118; operador, exit 0). Es una clasificación por nombres, no evidencia de 131 mutaciones reales.

## B18J fase 1: cola de inspección

`scripts/review_b18j_p0_queue.py` consume el JSON local B18I, exige esquema y consistencia de totales y genera una cola de revisión por archivo con líneas, llamadas y categorías. El JSON de salida se guarda **solo en el VPS**; no comunica secretos ni modifica servicios. La cola NO convierte candidatos automáticamente en revisados. `source_reviewed=0` y `coverage_verified=false` hasta que se inspeccionen archivos, wrappers, call sites y permisos operativos.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
python3 scripts/review_b18j_p0_queue.py /tmp/vencira-b18i-triage.json --output /tmp/vencira-b18j-p0-review.json
echo "B18J_EXIT_CODE=$?"
```

La cola agrupa las 131 llamadas P0 por archivo. Tras ejecución, compartir `B18J_P0_FILES`, `B18J_P0_CALLS` y exit code; evitar pegar rutas privadas no necesarias. En la siguiente intervención, inspeccionar módulos de dominio, clasificar **confirmado/no mutador/condicional/sin resolver**, documentar qué protege B06B y qué no, y generar una lista curada con evidencia del código. Los métodos `.create` y `.write` no bastan para confirmar efectos sin contexto.

## Limitaciones críticas

El detector B18H puede omitir wrappers indirectos, writers de otras tecnologías, shell y procesos. Incluso una revisión de 131 candidatos no certifica cobertura universal. Los guardas B06B están restringidos a ensayo y los bloqueos DB no congelan el diario/objetos. No avanzar a captura operativa ni declarar DR restaurable hasta probar barrera de entrada global, coherencia temporal y recuperación en entorno independiente.

```text
B18J_QUEUE=PENDING_EXECUTION
B18J_P0_SOURCE_REVIEW=NOT_COMPLETED
B18J_FULL_WRITER_COVERAGE=NO
MB1_OPERATIONAL_CAPTURE=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
