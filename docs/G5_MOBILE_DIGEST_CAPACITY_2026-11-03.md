# VENCIRA G5 — Macrobloque 5: capacidad de digests versionados (03/11/2026)

**Repositorio:** `appvencira/vencira_app` · **Rama:** `feature/m3-android-local-notifications` · **PR #17 DRAFT**.

## Evidencia de entrada

El operador comunicó el tercer lote local `m3-http-contract-20261103T125155Z`:
```
M3_HTTP_STATIC=0
M3_HTTP_BUILD=0
M3_HTTP_PG17_LAB=0
M3_HTTP_G4_PG17=0
M3_HTTP_FLUTTER=0
M3_HTTP_RESULT=0
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
Este resultado es **anterior a los cambios de capacidad de digests de este bloque**. No incluye el SHA del checkout ni un recibo de CI por GitHub Actions. Los logs privados se mantienen únicamente en `/home/vencira/vencira-m3-results/m3-http-contract-20261103T125155Z`.

## Cambios realizados

- `MobileDeviceSession.access_digest`, `MobileDeviceSession.refresh_digest`, `MobileSpentRefresh.digest`, `MobileAuthAttemptBucket.subject_digest` y `MobileAuthAuditEvent.actor_digest`: capacidad `max_length=96` frente a los 64 anteriores.
- `native_mobile_service/migrations/0004_digest_envelope_capacity.py`: cinco alteraciones de campos, **exclusivamente del modelo candidato registrado con entorno test**. No se ha ejecutado en una BD persistente.
- El formato `k1:<key_id>:<sha256 hex>` de `g5_keyring_policy.py` ocupa 69–88 caracteres, en función del identificador de clave. El máximo de 88 entra en las columnas de 96.
- `test_g5_digest_capacity.py`: comprueba capacidad de cinco columnas, coexistencia de 64 caracteres heredados y digests versionados en BD descartable, y no emisión de digests con claves antiguas.
- Añadido a CI SQLite, CI PostgreSQL17 temporal, runner PG17 `--candidate` y guard estático N1.

## Límites de este bloque

**Capacidad no es integración.** Los servicios operativos del candidato siguen calculando/verificando digests antiguos de 64 caracteres, dependientes de la clave Django mediante `salted_hmac`; el `CandidateKeyring` no está conectado a ellos. Los registros antiguos no se convierten automáticamente y no se añade una ruta fallback que acepte tokens legacy como autenticación versionada. El diseño de revocación o sustitución de sesiones en una futura migración debe ser explícito y probado.

El ledger de intentos y la auditoría no están conectados a endpoints de login. No se ha acreditado custodia externa de claves, cadena de integridad de auditoría ni validación física Android/iOS. El esquema candidato no se instala ni se migra en producción.

## Estado de gates

| Control | Estado |
|---|---|
| Tercer batch M3 (anterior a bloque 5) | PASS comunicado |
| Migración 0004 y nuevo test de esquema | COMMITTED; **PENDING nueva ejecución** |
| `makemigrations native_mobile_service --check --dry-run` con 0004 | PENDING |
| CI GitHub Actions del nuevo HEAD | PENDING |
| Integración keyring con tokens, throttle y auditoría | NOT_IMPLEMENTED |
| Custodia externa de claves | NOT_VERIFIED |
| Emisión verificada password+MFA | NOT_IMPLEMENTED |
| MFA/MB1/C-FICHA release | NO |
| GLOBAL_FREEZE | NOT_VERIFIED |
| NO_DEPLOY_NO_LIVE_MIGRATION | 1 |

Se exige una verificación local del runner integral **una sola vez** para la revisión posterior a este bloque, sin tocar bases persistentes. No se autoriza merge, despliegue ni activación de APIs móviles.
