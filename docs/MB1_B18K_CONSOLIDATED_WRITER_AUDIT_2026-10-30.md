# VENCIRA — Macrobloque 1 / B18K: auditoría concentrada de mutadores

30/10/2026. Objetivo: dejar de crear microfases y resolver el cuello de botella de escritores. **No hay prueba de captura operativa.**

## Entrega conjunta

1. `scripts/gate_b18k_critical_primitive_calls.py` escanea AST del backend y **falla** si detecta una llamada directa nueva a `stage_private_attachment`, `record_intent`, `put_quarantine` o `discard_quarantine` que no figure en la lista de pares archivo/call bajo revisión, o si falta un par previsto. La lista se ha construido sobre los seis módulos examinados en B18J2. No se ha ejecutado el gate todavía; pueden existir rutas adicionales y entonces un FAIL es un hallazgo, no razón para ampliar una allowlist automáticamente. La comprobación no protege ejecución dinámica, aliases ni acceso directo a SQL o filesystem.
2. `scripts/build_b18k_p0_source_review_pack.py` usa la cola B18J para generar **de golpe** un documento Markdown local con fragmentos de código de ±3 líneas por cada una de las 131 llamadas P0 de 34 archivos. Los candidatos permanecen UNREVIEWED; solo la lectura de contexto, verificación de call-sites y consecuencias permitirá aprobar/rechazar cobertura.
3. Todo el proceso es lectura local de código y JSON, sin Django, Docker, migraciones ni acceso a DEV.

## Único comando Ubuntu

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
python3 scripts/build_b18k_p0_source_review_pack.py \
  /tmp/vencira-b18j-p0-review.json \
  --output /tmp/vencira-b18k-p0-source-review.md
echo "B18K_SOURCE_EXIT=$?"
python3 scripts/gate_b18k_critical_primitive_calls.py
echo "B18K_STATIC_EXIT=$?"
```

**No asumir PASS**. Un cambio de fuente no inventariado debe bloquear el gate, y un FAIL debe investigarse con su ruta/call. Compartir los contadores y los nombres de parejas inesperadas, nunca claves/secretos.

## Trabajo aún necesario

- Clasificar realmente los 131 candidatos con revisión de código, determinar call sites, aliases, shell, endpoints, workers y escrituras indirectas. Corregir las primitivas que no exijan protección y conciliar intenciones persistentes tras fallos.
- Asegurar bloqueo operacional efectivo de nuevas escrituras DB + filesystem y drenaje, no solo advisory locks.
- Validar snapshot inmutable y restauración consistente con fallos simulados en PG17 y almacenamiento efímero.
- Resolver custodia independiente real de claves; autorización humana específica.

```text
B18K_EXECUTION=PENDING
B18K_SOURCE_REVIEWED=0
MB1_OPERATIONAL_CAPTURE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Resultado comunicado por operador — 30/10/2026

`B18K_P0_CONTEXTS=131`, `B18K_MISSING_SOURCE_FILES=0`, `B18K_SOURCE_REVIEWED=0`, `B18K_OPERATIONAL_CAPTURE=BLOCKED`, `B18K_SOURCE_PACK=OK`, `B18K_SOURCE_EXIT=0`. Gate de primitivas: `B18K_REVIEWED_CALLSITE_PAIRS=5`, `B18K_UNEXPECTED_CALLSITE_PAIRS=0`, `B18K_SOURCE_ERRORS=0`, `B18K_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED`, `B18K_RELEASE_AUTHORIZED=NO`, `B18K_STATIC_GATE=OK`. El valor de `B18K_STATIC_EXIT` no se incluyó. La validación estática no equivale a revisión de 131 casos ni freeze universal. Documento de contextos permanece local en `/tmp/vencira-b18k-p0-source-review.md`.
