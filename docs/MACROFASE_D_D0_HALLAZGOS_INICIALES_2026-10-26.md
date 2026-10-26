# VENCIRA — D0: evidencia inicial de seguridad (26/10/2026)

**Estado:** inspección estática parcial del repositorio, no auditoría concluida. Sin modificación operativa.

## Controles observados en código
- `backend/reminders/views.py`: `_membership` restringe pertenencia al workspace mediante usuario autenticado; `_visible_renewals` limita a los miembros no owner a anotaciones asignadas.
- `backend/reminders/views.py`: `me`, `workspaces`, `workspace_members` y endpoints de anotaciones usan `IsAuthenticated` según fragmentos inspeccionados. Consulta de miembros requiere rol owner.
- `backend/reminders/explicit_control_api.py`: operación POST de control explícito exige `IsAuthenticated`, resuelve membresía y anotación visible, valida payload y emplea transacción/idempotencia; no acredita envío real.
- `backend/reminders/operational_api.py`: lectura y acciones de ocurrencias se limitan a anotación visible tras membresía, usan `IsAuthenticated`.

## Hallazgos / riesgos a comprobar
- **D0-P1/pendiente de confirmar:** demostrar que **todas** las rutas multiusuario reutilizan comprobación tenant/asignación, incluidas respuestas, exportaciones, historial, borradores y endpoints auxiliares; comprobar relaciones de objetos antes de operaciones de escritura.
- **D0-P1/pendiente:** MFA y protección frente a intentos de autenticación, invalidación de sesiones al revocar miembros, CSRF y cookies de la configuración DEV.
- **D0-P1/pendiente:** verificar integridad, bloqueo y permisos de adjuntos, operaciones de borrado y retención; no utilizar datos personales reales.
- **D0-P2/pendiente:** análisis de paquetes, imágenes Docker, logging de secretos, cabeceras HTTPS y política de restauración O5.

No son vulnerabilidades confirmadas: son puntos de verificación. Las protecciones observadas en pocas API no prueban cobertura global.

## Gate siguiente
Inventariar rutas y permisos Django, tests de negación cruzada por tenant/usuario, MFA y settings de producción sin imprimir tokens, contraseñas o contenidos de datos. Priorizar pruebas negativas en SQLite y PostgreSQL17 efímero, sin tocar BD persistente.


## D0 revisión adicional de pruebas existentes (26/10)

El operador obtuvo inventario de **26 rutas** y archivos de tests. Revisión directa en la rama `integration/local-e2e-prep`:

- `test_api.py`: `test_anonymous_denied_all_business_routes`, `test_removing_membership_revokes_access_immediately`, `test_member_cannot_read_or_patch_teammate_or_unassigned_record`, `test_owner_cannot_assign_to_nonmember_or_foreign_tenant`, `test_cannot_see_or_mutate_other_workspace`, `test_session_authentication_rejects_missing_csrf_on_write`, entre otras. Son pruebas de cobertura de acceso al API, no acreditan invalidación completa de sesión.
- `test_operational_api.py`: acceso ajeno denegado y pertenencia de recordatorios a otro workspace.
- `test_history_read.py`: historia por asignación y acceso cruzado.
- `test_control_assessment.py`: no autorizado, cross-workspace y no asignado.
- `test_operational_inbox.py` y `test_operational_history.py`: controles por tenant y asignación.
- `test_reminder_activate.py`: `test_cross_tenant_denied`.

**Pendientes:** comprobar cobertura completa de 26 rutas con matriz de autorización, ejecución íntegra de los tests sobre PG17 temporal, MFA, protección frente a fuerza bruta y caducidad/revocación de sesiones. No elevar ningún pendiente a vulnerabilidad confirmada sin reproducción.

**HTTPS efectivo comprobado por el operador:** HTTP 308 a HTTPS, HTTPS 200, `referrer-policy: same-origin`, `x-content-type-options: nosniff`, `x-frame-options: DENY`. No se vio `Strict-Transport-Security`, proponer endurecimiento de Caddy con cautela, sin subdominios/preload, gate independiente. Django efectivo: `DEBUG=False`, `SESSION_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True`, `CSRF_COOKIE_SECURE=True`, `SECURE_SSL_REDIRECT=False`, `SECURE_HSTS_SECONDS=0`, y `SECURE_PROXY_SSL_HEADER` configurado. No alterar DEV ahora.


## D1 · Revocación efectiva con cookie de navegador — VALIDADO

Commit de prueba `086cb0e73df468d9ca52e8cc316eaa2ff0d2ba72` (`backend/reminders/test_api.py`): un `Client()` Django inicia sesión auténtica, comprueba acceso propio y denegación tenant ajeno, elimina membresía y confirma HTTP 404 en listado y detalle revocados; la sesión global permanece válida para `/api/v1/me/` y devuelve lista de workspaces vacía. Gate integral confirmado por el operador: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_REVOCACION=0`, log `/tmp/vencira-o7-o8-preflight.HQktjXsE.log`. Ningún deploy o migración persistente. **No equiparar revocación de membresía con cierre global de sesión.** Siguiente: definir alcance de invalidación de sesión (cuenta completa vs membresía específica), diseñar MFA/recuperación segura, y pruebas aisladas antes de activar.


## D1.2 · Pruebas de sesiones multidispositivo (pendientes de gate)

Commit `5adc51b4eb6c96e6d5a6ca8c36defe17fb3dced9`: `backend/reminders/test_session_revocation.py` comprueba con dos clientes Django autenticados que (a) retirar una membresía preserva acceso a una segunda organización y la sesión global; (b) desactivar `is_active` del usuario deniega acceso autenticado a ambos clientes; (c) rotar contraseña invalida sesiones previas y permite un nuevo inicio con la contraseña nueva. Emplea usuarios y organizaciones sintéticos y DB temporal de pruebas. **No se ha ejecutado todavía gate con estas pruebas**, no presentar resultados como aprobados. Esto comprueba mecanismos existentes, no implementa todavía una interfaz de cierre remoto ni MFA. Ningún deploy ni migración persistente.


## D1.2 · Gate multidispositivo APROBADO (26/10/2026)

El operador ejecutó `scripts/validate_o7_o8_preflight.sh` con test `backend/reminders/test_session_revocation.py` incluido: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_2=0`, log `/tmp/vencira-o7-o8-preflight.qBjXq49y.log`. Confirma comportamiento bajo tests: revocar una membresía preserva el acceso a otras; desactivar cuenta deja sin autenticación a dos sesiones; cambiar contraseña invalida ambas sesiones previas. No se implementó control de cierre remoto selectivo ni MFA. Sin despliegue ni cambios de base persistente.


## D1.3 — Revocar otras sesiones: IMPLEMENTADO EN RAMA, SIN GATE

Se añadió `POST /api/v1/me/logout-other-sessions/` en `backend/reminders/session_security.py` y `backend/reminders/urls.py`, protegido por autenticación Django/DRF de sesión y comprobación CSRF, exigencia de contraseña actual, respuesta sin datos de sesión, conservación de la sesión invocante, cierre de las otras sesiones de la misma cuenta solamente, sin tocar las de otros usuarios. Sólo acepta almacenamiento de sesión DB e impone límite de exploración de 5000 sesiones activas: solución provisional con coste O(sesiones), destinada a reemplazarse por un índice de sesiones por usuario antes de escala comercial. Pruebas en `backend/reminders/test_session_security.py`: autenticación, CSRF, contraseña, aislamiento, sesión actual y cierre remoto. Commits `b4129874`, `d776d46c`, `eadb36b8`, `9ce211b4`. **Pendiente gate integral** antes de declarar válido o publicar. No se ha implementado botón Flutter ni MFA. No desplegar / no migrar DB persistente.


## D1.3 — Gate integral aprobado

El operador confirmó tras incorporar `backend/reminders/session_security.py`, su ruta y tests: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_3=0`; log `/tmp/vencira-o7-o8-preflight.rQbzywZf.log`. Implementación **solo backend**, no botón Flutter ni despliegue. Sigue pendiente un diseño indexado por usuario para escalabilidad comercial y revisión de interfaz/autenticación MFA. No migración persistente ni alteración Caddy/Restic.


## D1.4 · UI cierre sesiones otras máquinas — GATE PENDIENTE

Flutter: método `VenciraApi.logoutOtherSessions` con CSRF, JSON y verificación de respuesta (`clients/flutter/lib/api/vencira_api.dart`, commit `18b02b6a`); en hoja de Ajustes de Dashboard, opción «Cerrar sesiones en otros dispositivos» (ES/CA), diálogo de contraseña oculta y confirmación, barra con total revocado y mantenimiento de sesión actual (`clients/flutter/lib/ui/dashboard_screen.dart`, commit `17e9824e`). Sólo se muestra si hay organización seleccionada. No se ha ejecutado preflight después de cambios, no declarar final ni desplegar. Sin migraciones, sin activar MFA. Pendiente revisar experiencia real móvil, ejecutar tests y decidir si se requiere indexado de sesiones antes de escala comercial.
