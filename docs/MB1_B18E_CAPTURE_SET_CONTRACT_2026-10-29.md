# VENCIRA — Macrobloque 1 / B18E: contrato integral de corte

**Fecha:** 29/10/2026. Código test-only; no captura operativa.

## Alcance y mecanismo

B18C demostró que locks consultivos son insuficientes contra ORM no cooperativo. B18D ensayó un lock real de **una tabla** PostgreSQL con éxito, pero ello no protege almacenamiento privado ni diario.

Se añade `backend/renewal_attachments/offline_capture_set_b18e.py`, verificador **puro, sin efectos secundarios**, que exige en una captura sintética:
- Lista de escritores conocidos sin participantes faltantes y señal de drenaje declarada.
- Identidad del corte y época iguales al inicio y fin.
- Coincidencia exacta de IDs de registros DB, objetos cifrados y diarios.
- Digest SHA-256 de bytes cifrados y del diario ligado al registro de BD, más SHA-256 del inventario ligado al marcador.
- Formato e identidad consistente de cada diario.
- Salida `release_authorized=False`, también cuando los contratos pasan.

**Advertencia importante:** `drained=True` y `missing_writers=()` son afirmaciones del llamador; el verificador no las puede demostrar. Las huellas también pueden proceder de una única fuente falsa y no aseguran independencia o autenticidad. Un atacante con control de catálogo y bytes puede fabricar un conjunto internamente consistente. No se ha implementado bloqueo efectivo universal ni un corte atómico SQL/filesystem, ni verificación de custodia de claves, ni restauración de producción.

## Casos de prueba nuevos

`backend/renewal_attachments/test_capture_set_b18e.py`: 12 pruebas sintéticas para conjunto correcto y rechazo de escritor ausente, no drenado, época/snapshot cambiado, objeto/diario ausente, manipulación de contenido, objeto inesperado, digest de inventario incorrecto e identidad del diario alterada.

`scripts/validate_b18e_capture_set_synthetic.sh`: construye imagen aislada, ejecuta **solo** módulo B18E con Docker `--network none`, sin PG17, puertos o claves reales. No repite B09E, B18B, B18C o B18D.

## Un único gate pendiente

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/validate_b18e_capture_set_synthetic.sh
echo "B18E_EXIT_CODE=$?"
```

Esperado: 12 tests OK, `B18E_SYNTHETIC_CONTRACTS=OK`, `B18E_RESULT=0`, `B18E_EXIT_CODE=0`. **No ejecutado a fecha de creación**.

## Sigue pendiente para cerrar el macrobloque 1

1. Censo exhaustivo de escritores operativos y control de su exclusión/drenaje; registrar altas futuras y rechazo fail-closed.
2. Protocolo efectivo de frontera SQL + archivos + diario (sin depender de una afirmación `drained=True`).
3. Restauración integral tras caída desde soporte independiente en PG17 clon con claves externas reales bajo custodia separada y aceptación humana.
4. RPO/RTO, retención y pruebas de fallo en cortes temporales reales.

```text
B18E_CONTRACT_CODE=READY
B18E_TESTS=PENDING
MB1_OPERATIONAL_CAPTURE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
