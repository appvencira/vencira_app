# VENCIRA G5 — Macrobloque 3: auditoría mínima candidata (03/11/2026)

**Rama:** `feature/m3-android-local-notifications` · **PR #17 DRAFT** · **NO_DEPLOY_NO_LIVE_MIGRATION=1**.

## Evidencia anterior al bloque

El operador comunicó que el runner integral `m3-http-contract-20261103T095043Z` terminó con `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_G4_PG17=0`, `M3_HTTP_FLUTTER=0` y `M3_HTTP_RESULT=0`, sin despliegue ni migración persistente. **Este resultado es previo al presente bloque de auditoría** y no lo valida.

## Código publicado

- `MobileAuthAuditEvent` candidato en `backend/native_mobile_service/models.py` y migración `0003_mobileauthauditevent.py` **sólo aplicables en DB desechable al activar `VENCIRA_ENV=test` + `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`**.
- Campos mínimos: identificador UUID aportado por el llamador, tipo de evento restringido, digest HMAC del identificador lógico opcional, UUID de sesión opcional y marca temporal. No se almacenan tokens, contraseñas, códigos MFA, IP ni nombres en claro por diseño del esquema.
- `g5_audit.py`: inserción con idempotencia por UUID y rechazo de reuso incompatible, HMAC independiente mediante `VENCIRA_G5_AUDIT_KEY` inyectada en tests, allowlist cerrada de tipos: `auth_denied`, `auth_verified`, `refresh_rotated`, `refresh_replay`, `device_logout`, `account_revoke`.
- Política de retención candidata de 30 días con purga **explícita**, no servicio de cron, y denegación de purga de eventos más recientes.
- `test_g5_audit.py`: 8 métodos sobre idempotencia, redacción, colisión, clave ausente, actores inválidos, purga y test-only gate. Integrados en CI SQLite/PG17 y runner PG17 `--candidate`.
- Gate estático ampliado para verificar que el módulo de auditoría permanece aislado.

## Límites de seguridad — aún sin cerrar

1. **No hay conexión a los eventos reales** de `session_store` ni de las vistas HTTP. Esto evita aparentar seguridad de auditoría productiva: ninguna autenticación efectiva genera aún estas filas.
2. La idempotencia secuencial y la carrera de inserción del mismo UUID están ahora **cubiertas por código y por dos tests PG17 nuevos**, con `get_or_create` y bloqueo de fila tras el insert ganador. **Los tests nuevos todavía NO se han ejecutado localmente ni tienen CI confirmada**, por lo que no declarar deduplicación concurrente PASS.
3. El esquema no proporciona por sí solo protección de integridad frente a administradores DB maliciosos o capacidad de borrado arbitrario; falta cadena verificable, exportación, custodia y permisos DB mínimos.
4. La pseudonimización no convierte necesariamente los eventos en datos anónimos a efectos RGPD: falta evaluación formal, política de acceso, retención aprobada y mecanismo programado de purga.
5. El llamador todavía podría pasar una cadena sensible como `actor`; será obligatorio tipar y normalizar identidades antes de conectar el módulo a un endpoint. No registrar errores completos, headers ni bodies de login.
6. El modelo de claves sigue **sin custodia ni rotación externa aprobada**. Nunca subir las claves ni configurar credenciales reales en Actions.
7. El bloqueo por cuenta/IP puede ser abusado para denegación de servicio. Antes de activarlo: evaluar escalada de tiempos, cuotas por red, heurísticas, respuesta HTTP uniforme y recuperación segura.

## Gates

| Gate | Estado |
|---|---|
| Suite integral M3/G4/G5 anterior (03/11/2026) | PASS comunicado por operador |
| Nueva auditoría (migration 0003, tests, estático) | **PENDING** |
| CI GitHub Actions en HEAD del bloque 3 | **PENDING** |
| Auditoría integrada con autenticación real | NOT_IMPLEMENTED |
| Antiabuso conectado a HTTP | NOT_IMPLEMENTED |
| Emisor verificado password+MFA | NOT_IMPLEMENTED |
| Custodia HMAC externa | NOT_VERIFIED |
| MFA/MB1/C-FICHA release | NO |
| GLOBAL_FREEZE | NOT_VERIFIED |
| NO_DEPLOY_NO_LIVE_MIGRATION | 1 |

El runner `scripts/m3_native_http_contract_batch.sh` reconstruye la imagen de test y ejecuta `scripts/n1_identity_pg17_ephemeral.sh --candidate` con la nueva suite. Revalidar únicamente después de que el lote de implementación esté estable; no reutilizar los marcadores del lote anterior como PASS de este bloque.

## Próximo trabajo

Tratar explícitamente concurrencia de la auditoría y la atribución de eventos, versionado de claves y rotación, supresión/desidentificación y controles de acceso antes de habilitar una ruta pública. Toda migración se ejecutará solo en base descartable.

## Refuerzo de concurrencia posterior

Se añadió `test_g5_audit_pg17_races.py`: (1) dos procesos que insertan el mismo UUID deben producir una única fila y un único `created=True`; (2) dos tipos de evento distintos con UUID idéntico deben aceptar uno y rechazar el otro sin doble inserción. El runner PG17, CI y el guard estático incluyen estos casos. **Estado: pendientes de ejecución.**
