# VENCIRA G5 — Macrobloque 2: antiabuso transaccional candidato (03/11/2026)

**Rama:** `feature/m3-android-local-notifications`; **PR #17:** borrador; **release:** NO. Complementa [macrobloque 1](G5_MOBILE_SECURITY_MACROBLOCK_2026-11-03.md).

## Implementación de laboratorio publicada

- Modelo `MobileAuthAttemptBucket` (`backend/native_mobile_service/models.py`), único por `scope` (cuenta/IP) y digest HMAC de sujeto; incluye ventana, intentos y duración de bloqueo. **No guarda direcciones IP ni identificadores de cuentas en claro.**
- Migración `native_mobile_service.0002_mobileauthattemptbucket`, registrada exclusivamente al activar `VENCIRA_NATIVE_SERVICE_CANDIDATE=1` con `VENCIRA_ENV=test`. **NUNCA ejecutar contra PostgreSQL persistente.**
- `g5_throttle.py`: consume simultáneamente cuota de cuenta e IP en una transacción de base de datos; crea o bloquea las filas en orden global fijo y usa `select_for_update`. Límites candidatos: 5 intentos por cuenta, 20 por IP; ventana y bloqueo de 15 minutos. El quinto o vigésimo intento se deniega; no se distingue cuenta existente de inexistente. El llamador ha de normalizar de forma idéntica los identificadores de cuentas existentes y desconocidas.
- Derivación HMAC SHA-256 con dominio distinto por propósito, sin fallback a `DJANGO_SECRET_KEY`; la clave `VENCIRA_G5_ABUSE_KEY` **solo se inyecta sintéticamente en pruebas**. No habilitar en runtime hasta diseñar custodia, versionado y rotación externos.
- Pruebas: `test_g5_throttle.py` (8 métodos de contrato), `test_g5_pg17_races.py` (concurrencia multi-conexión PostgreSQL17), `test_g5_network_identity.py` (7 métodos). CI SQLite/PG17 y `n1_static_security_gate.py` ampliados para revisar el límite test-only.

**Advertencias:** `consume_candidate_auth_attempt` es un componente interno **sin conexión a vistas, endpoints, inicio de sesión, password/MFA ni producción**. Una denegación Boolean no equivale a seguridad del flujo de login ni a antienumeración HTTP validada. Requiere diseño adicional ante DoS por bloqueo de cuentas, límites distribuidos, configuración real de proxies y retención de digests.

## Resultado por gate

| Verificación | Estado a 03/11/2026 |
|---|---|
| Código de política/red y ledger transaccional | COMMITTED; candidato aislado |
| Modelo y migración 0002 únicamente en rama | COMMITTED; **no migrada** en DB persistente |
| Tests de contrato SQLite | PENDING CI / local |
| Tests PG17 de concurrencia y migración seca | PENDING CI / local |
| Gate estático y runner M3 post-G4 | PENDING CURRENT HEAD |
| Antiabuso HTTP real, identidad de proxy y reintentos seguros | NOT_IMPLEMENTED |
| Auditoría persistente/retención/soporte y eventos de seguridad | NOT_IMPLEMENTED |
| Emisión autenticada password+MFA | NOT_IMPLEMENTED |
| HMAC keyring/custodia/rotación | NOT_IMPLEMENTED |
| Android/iOS físicos | NOT_VERIFIED |
| MFA, MB1 y C-FICHA release | NO |
| GLOBAL_FREEZE | NOT_VERIFIED |

Ningún resultado local o de GitHub Actions se debe presumir por el mero hecho de haber publicado los archivos. Ninguna prueba anterior a estos commits valida el nuevo código.

## Ejecución local necesaria para aceptar el macrobloque

Tras comprobar que el checkout del operador está limpio y actualizarlo con fast-forward, ejecutar exclusivamente con PostgreSQL17 temporal del runner existente:

```bash
# En ~/vencira-m3-localcheck, comprobar primero git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 scripts/n1_static_security_gate.py
bash scripts/m3_native_http_contract_batch.sh
```

El runner debe ser revisado para confirmar que incorpora G5 en el segmento candidato; **CI de rama sí incluye G5**, pero el runner local M3 todavía puede invocar sólo las suites G4 explícitas. Si falta, añadir primero G5 al segmento `--candidate` antes de declarar integral G5. Guardar salida y exit status; no trasladar dumps, credenciales ni logs privados al repositorio.

## Próximo bloque

Auditoría persistente mínima sin material sensible; retención/purga, deduplicación; keyring con IDs de versión, política de expiración y revocación; tests de replay y carreras. Después revisar coste/beneficio y amenaza de bloqueo de cuentas antes de conectar cualquier emisor real. Mantener el PR en borrador y prohibido el despliegue/merge.
