# G5 — Macrobloque 1: atribución de red y controles de emisión móvil (03/11/2026)

**Rama:** `feature/m3-android-local-notifications`; **PR:** #17, borrador. **Entorno:** pruebas exclusivamente. **NO_DEPLOY_NO_LIVE_MIGRATION=1**.

## Alcance publicado

- `backend/native_mobile_service/g5_network_identity.py`: primitiva aislada que obtiene `REMOTE_ADDR` validado. Descarta una IP falsificada en `X-Forwarded-For` cuando el peer no está en la lista exacta de proxies controlados.
- Para un peer explícitamente confiable, exige exactamente un único `X-Forwarded-For` sintácticamente válido, rechaza cadenas, ambigüedad, valores malformados, `Forwarded` concurrente y un encabezado que repite la dirección del propio proxy.
- Normaliza IPv4-mapped IPv6 y rechaza listas CIDR en el inventario de proxies: la configuración debe tener IPs exactas y auditadas.
- `backend/native_mobile_service/test_g5_network_identity.py`: 7 escenarios de pruebas en el módulo, algunos con subcasos de valores malformados.
- `.github/workflows/m3-product-contracts.yml`: incorpora las nuevas pruebas en SQLite y PG17 efímeros. Este commit **no acredita que GitHub Actions las haya ejecutado**.

La función no recibe directamente ninguna petición HTTP operativa, no se conecta a `session_store`, no crea ni valida tokens y **NO aplica rate limiting**. Es la primera pieza necesaria para la atribución de red del antiabuso, no un antiabuso completado.

## Riesgos pendientes y criterios G5

| Control | Estado | Requisito previo al cierre |
|---|---|---|
| IP atribuida sin confiar en cabeceras de cliente | CODE CANDIDATE; pruebas pendientes | Configuración real de cadena Caddy/Nginx y tests de integración proxy |
| Bloqueo por cuenta y por IP compartido entre procesos | NOT_IMPLEMENTED | Contadores transaccionales, ventanas temporales, concurrencia PG17 y no enumeración |
| Auditoría persistente, retención y privacidad | NOT_IMPLEMENTED | Modelo mínimo, eventos, permisos, redacción, limpieza verificable |
| Separación, custodia y rotación de clave HMAC | NOT_IMPLEMENTED | ID de versión, keyring externo y política de compatibilidad; no escribir claves en el repositorio |
| Emisor contraseña + MFA validado | NOT_IMPLEMENTED | Vincular prueba real a principal/fence antes de emitir y definir revocación |
| G4 candidata y G6 post-G4 integral | PENDING CURRENT HEAD | `makemigrations --check --dry-run`, PG17 aislado, carreras y runner integral |
| GitHub Actions HEAD G5 | PENDING | Verificar ejecución y resultado real |
| MFA/MB1/C-FICHA y global freeze | NO / NOT_VERIFIED | Evidencia independiente y autorización expresa |

## Restricciones de seguridad no negociables

1. La aplicación `native_mobile_service` permanece disponible **solo** con `VENCIRA_ENV=test` y opción explícita; `VENCIRA_NATIVE_BEARER_ENABLED=False` por defecto.
2. Ninguna ruta móvil en `config.urls` ni en `reminders.urls`. El emisor sintético `issue_verified_candidate_session` sigue siendo exclusivamente un inyector de pruebas.
3. No merge, deploy, alteración de rutas operativas, migración de BD persistente ni publicación de datos/secretos.
4. No declarar `MFA_RELEASE_AUTHORIZED`, `MB1_RELEASE_AUTHORIZED` o `C_FICHA_RELEASE_AUTHORIZED` como `YES`. `GLOBAL_FREEZE=NOT_VERIFIED`.
5. No interpretar un test de política de IP como prueba de defensa distribuida: falta la infraestructura de contadores, el origen proxy confiable y la integración HTTP.

## Validación pendiente en local

En checkout limpio y actualizado del operador, tras verificar `git status`, ejecutar exclusivamente sobre un entorno de pruebas:

```bash
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 -m compileall -q backend/native_mobile_service/g5_network_identity.py backend/native_mobile_service/test_g5_network_identity.py
python3 scripts/n1_static_security_gate.py
# Con entorno Django de test configurado y DB descartable:
# VENCIRA_ENV=test VENCIRA_NATIVE_SERVICE_CANDIDATE=1 python backend/manage.py test native_mobile_service.test_g5_network_identity
```

Estos comandos son **pendientes**, no se han ejecutado ni implican acceso a la BD persistente. El gate de GitHub Actions también requiere resultado verificado. Evitar `reset --hard` o cambios al checkout sin comprobar si hay trabajo no rastreado.

## Próximo bloque

Modelo antiabuso persistente aislado en PostgreSQL17 temporal, operaciones atómicas por cuenta/IP, tests de carreras y denegación uniforme; después auditoría y política de claves. Un único runner integral posterior a completar cambios importantes, evitando repetir pruebas ya acreditadas sobre commits anteriores.
