# VENCIRA G5 — Macrobloque 4: política candidata de claves versionadas

**Fecha:** 03/11/2026 · **Rama:** `feature/m3-android-local-notifications` · **PR #17 DRAFT**.

## Estado de validación anterior

El operador comunicó la segunda ejecución `m3-http-contract-20261103T121338Z` con `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_G4_PG17=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. **PASS previo a este bloque 4**. No atribuirlo a los nuevos tests de claves.

## Cambios publicados

- `backend/native_mobile_service/g5_keyring_policy.py`: prototipo puro de política, independiente de Django/BD/HTTP, que recibe materiales binarios de al menos 32 bytes suministrados por un custodio externo. No genera, lee ni persiste secretos.
- Identificadores de clave `k1:<id>:<digest SHA256>`, separación por propósito: `mobile-access`, `mobile-refresh`, `mobile-audit`, `mobile-throttle`.
- Una clave activa de firma; hasta tres anteriores permitidas **solo para verificación** con fecha de caducidad obligatoria en UTC. IDs y materiales duplicados, versiones desconocidas, formato legado y ausencia de fechas se deniegan.
- `test_g5_keyring_policy.py`: 9 pruebas de aislamiento por propósito, rotación y expiración exacta, formato, errores de configuración, claves duplicadas, reloj timezone-aware y fallback rechazado.
- CI de SQLite/PG17, runner PG17 candidato y guard estático incorporan el módulo y su suite.

## Límites críticos, aún pendientes

1. **No está integrado** en `native_mobile_token_primitives.py`, `session_store.py`, auditoría ni throttle. Sigue existiendo una dependencia heredada de `salted_hmac` / `DJANGO_SECRET_KEY` para los digests de token del candidato G4; **la separación de claves real NO está terminada**.
2. El esquema actual de `MobileDeviceSession.access_digest` / `refresh_digest`, `MobileSpentRefresh.digest`, `MobileAuthAuditEvent.actor_digest` y `MobileAuthAttemptBucket.subject_digest` usa `max_length=64`. El formato versionado nuevo excede 64. Antes de integrar hace falta diseño de esquema compatible, migración exclusivamente temporal, plan de rehash/revocación y tests de coexistencia. No truncar el digest ni almacenar formato híbrido sin versión.
3. La custodia externa real de MFA, secretos HMAC y respaldo independiente no está acreditada. No inventar key IDs/material real ni introducirlos en repositorio, CI público, logs o imágenes Docker.
4. La expiración de claves antiguas requiere definir plazo máximo real de refresh (30 días), caducidades de auditoría/antiabuso, retiros forzosos y recuperación ante pérdida de clave. La política prototipo, por sí sola, no garantiza continuidad.
5. No hay autenticación HTTP nativa operativa ni password+MFA verificado, revocación de producción o pruebas físicas Android/iOS.

## Gates

| Control | Resultado |
|---|---|
| Segundo M3 integral (antes de bloque 4) | PASS comunicado, SHA checkout no aportado |
| Código de política versionada y pruebas | COMMITTED, ejecución pendiente |
| CI GitHub Actions de HEAD | SIN CONFIRMACIÓN |
| Rotación integrada de credenciales existentes | NOT_IMPLEMENTED |
| Custodia externa y recuperación | NOT_VERIFIED |
| Endpoints/emisor autorizados | NO |
| MFA/MB1/C-FICHA release | NO |
| GLOBAL_FREEZE | NOT_VERIFIED |
| NO_DEPLOY_NO_LIVE_MIGRATION | 1 |

No ejecutar ninguna migración en el servidor persistente ni realizar merge/deploy. El próximo bloque debe diseñar compatibilidad de digests y custodia operativa antes de integrar el keyring.
