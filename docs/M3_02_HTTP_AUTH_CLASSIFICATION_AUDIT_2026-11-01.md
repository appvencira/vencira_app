# VENCIRA — M3-02: auditoría de clasificación HTTP 401/403
Fecha: 2026-11-01. Rama: `feature/m3-android-local-notifications`. PR #17 (draft).

## Hallazgo técnico y alcance

El cliente `clients/flutter/lib/api/vencira_api.dart` contiene múltiples rutas que convierten tanto `response.statusCode == 401` como `403` en `VenciraUnauthorized`. Se observó directamente en las operaciones de activación de avisos operativos, modificación de avisos, escritura de anotaciones y resolución de seguimiento manual. `VenciraDashboardScreen` revoca alarmas al recibir dicha excepción en los flujos que ya gestionan la caducidad.

**No es correcto asumir que cualquier 403 significa sesión caducada.** Puede representar falta de permisos, CSRF fallido o política del servidor; el tratamiento definitivo requiere examinar las respuestas reales y el contrato del backend Django. Tampoco es seguro eliminar la revocación para todos los 403 sin comprobar la política de autenticación. No se modifica aún el significado HTTP en producción.

## Contratos que deben comprobarse en backend antes de refactorizar

1. Sesión realmente caducada: código HTTP, cuerpo estructurado y comportamiento al repetir solicitud.
2. Usuario autenticado sin acceso al workspace o recurso: respuesta inequívoca, minimización de datos y cancelación de alarmas del workspace anterior.
3. CSRF fallido en escritura: no confundir con caducidad de sesión; mostrar error sin exponer datos.
4. Roles y permisos retirados durante sesiones válidas: revocar solamente alarmas del ámbito retirado antes de continuar.
5. Errores de sesión desde pantallas secundarias: evitar cachés visibles y respuestas tardías que reintroduzcan datos, coordinando invalidaciones.

## Trabajo cerrado y evidencia

- `5ace851`: catálogo de modalidades y aseguradoras gestiona `VenciraUnauthorized`; widget tests de ambos endpoints.
- CI asociado a `5ace851`: contratos M3 run `41323281334` PASS en sus tres jobs; Android debug run `41323281277` PASS.
- `f3dbc69`: borra cachés de los catálogos al invalidarse una sesión y evita repetir revocación desde esos dos cargadores ya invalidados.
- CI del HEAD posterior: **no afirmar PASS hasta confirmación**. La compilación APK tampoco equivale a entrega real de avisos en hardware.

## Criterio para el siguiente cambio funcional

Primero establecer pruebas de contrato Django y Flutter separando `401` y `403` con los casos reales. Después aplicar un clasificador central a todas las peticiones, preservando la revocación inmediata ante pérdida **confirmada** de identidad o pertenencia y el comportamiento fail-closed. No permitir activación de notificaciones para verificar esta clasificación.

```text
M3_02_HTTP_401_403_CLASSIFICATION=REVIEW_REQUIRED
M3_02_OS_SCHEDULING_ENABLED=NO
M3_02_DEVICE_DELIVERY_EVIDENCE=NO
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

M3-02 sigue abierto. Progreso formal: 2/15 hitos (13,3 %).
