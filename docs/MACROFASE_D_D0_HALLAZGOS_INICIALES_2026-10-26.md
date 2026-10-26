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
