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

## Evidencia de código y contrato añadida

- `backend/reminders/views.py`: `workspace_members` devuelve explícitamente **403** cuando el usuario está autenticado pero no es propietario; `_membership` oculta workspaces sin pertenencia mediante **404**. `/api/v1/me/` permite comprobar la identidad de la sesión.
- Commit `adf5bce`: dos pruebas Django de regresión verifican que `403` por rol y `404` por falta de membresía pueden coexistir con `GET /api/v1/me/` **200** dentro de la misma sesión. Se ejecutarán tanto sobre SQLite como PostgreSQL17 por el workflow M3 existente.
- Implicación: la política que traduce indiscriminadamente `403` a `VenciraUnauthorized` debe revisarse; la pérdida de rol y la caducidad no son idénticas. **No** se ha modificado la interpretación Flutter mientras no queden cubiertas las variantes de CSRF y autenticación DRF.
- Estado de las dos pruebas nuevas: pendiente de resultado GitHub Actions; no atribuirles PASS de workflows de commits anteriores.

## Contrato de sesión anónima y logout — ampliación

- Commit `7e605c3`: tests backend adicionales verifican que un usuario anónimo no puede consultar identidad ni miembros y que, después del logout, `/api/v1/me/` deja de devolver 200.
- **Punto crítico:** con DRF SessionAuthentication, una petición anónima puede devolver `403` en lugar de `401` si no existe una cabecera de desafío de autenticación; por eso no es correcto clasificar solo por código HTTP. Los nuevos tests aceptan 401 o 403 para denegación anónima, pero comprueban que no se autoriza.
- Un `403` por falta de rol con sesión válida sigue diferenciándose mediante `/api/v1/me/` 200. El cliente Flutter **no se ha modificado** para hacer una petición adicional en cada fallo: primero deben definirse reglas ante pérdida de red, concurrencia y retirada de membresía.
- Pruebas añadidas pendientes de resultado CI del commit correspondiente; no publicar PASS sin consultar su conclusión.

## Macrobloque de clasificación pura — 01/11/2026

- `clients/flutter/lib/api/session_denial_classifier.dart`: decisión pura con tres estados (`expired`, `forbidden`, `unknown`) y tres resultados de comprobación de identidad (`authenticated`, `unauthenticated`, `unavailable`). Tanto 401 como 403 requieren evidencia sobre identidad; si la comprobación no está disponible, el estado queda desconocido.
- `clients/flutter/test/session_denial_classifier_test.dart`: siete pruebas que incluyen 401/403 con identidad válida, ausente o indeterminada y códigos no asociados a pérdida de sesión.
- Workflow M3 actualizado para ejecutar explícitamente dichas pruebas y dispararse cuando cambian el clasificador o sus tests.
- **No conectado todavía al cliente HTTP ni a la UI.** Se mantiene el comportamiento actual hasta comprobar CI y definir cuidadosamente la sonda de identidad, protección contra carreras, respuesta con red desconectada y pérdida de membresía. Los tests nuevos no demuestran revocación Android universal.
- Sin notificaciones reales, sin merge, despliegue o migración persistente. Estado formal 2/15.

```text
M3_02_AUTH_CLASSIFIER=IMPLEMENTED_UNWIRED_AWAITING_CI
M3_02_AUTH_PROBE=NOT_IMPLEMENTED
M3_02_GLOBAL_HTTP_INTEGRATION=NOT_IMPLEMENTED
M3_02_OS_SCHEDULING_ENABLED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Primer adaptador integrado para GET — 01/11/2026

- Commits `41d6214` y `ea25d11`: el método común `HttpVenciraApi._fetch` comprueba una vez `/api/v1/me/` después de una respuesta 401/403. El sondeo se hace con el mismo cliente HTTP, sin recursión.
- Si la sonda de identidad devuelve 401/403, se genera `VenciraUnauthorized`; si confirma 200 con ID entero válido o falla por red/formato, **no se declara sesión caducada**, y se genera error de API genérico.
- Tests de integración con cliente HTTP simulado cubren ambos códigos, identidad válida, identidad denegada y pérdida de red.
- Alcance limitado deliberadamente a solicitudes GET del helper `_fetch`. Las escrituras manuales POST/PATCH y las pantallas secundarias no están homologadas; el clasificador de estados puro está separado y aún no orquesta globalmente la UI.
- Posible mejora posterior: verificar pertenencia del workspace cuando se deniega una solicitud pero la sesión permanece válida; no usar solamente el resultado `/me/` para tomar decisiones sobre alarmas del workspace.
- **CI de esta revisión pendiente**; compilación APK no equivale a entrega real en dispositivo Android.

## Tratamiento de escrituras POST/PATCH — 01/11/2026

- Commit `aac9ef7`: doce bloques existentes de respuesta HTTP 401/403 en `HttpVenciraApi` pasan a usar un helper de comprobación de identidad. No reenvía ni repite la escritura denegada.
- Si `GET /api/v1/me/` responde 401/403, la escritura comunica `VenciraUnauthorized`; identidad válida o sonda indeterminada comunica `VenciraApiException`. Así no se interpreta una denegación de rol/CSRF como logout confirmado.
- Commit `b361726`: pruebas HTTP de denegación en escrituras con identidad válida (403 y 401), manteniendo la prueba de sesión rechazada.
- Alcance: clasificación HTTP y prevención de revocación global falsa. **Pendiente** tratar pérdidas concretas de membresía y respuesta de las pantallas secundarias. No significa recuperación ni reintento automático de operaciones parcialmente ejecutadas.
- Bloque funcional en revisión: no atribuir PASS sin ejecución Actions exitosa del commit correspondiente. Sin activar avisos.
