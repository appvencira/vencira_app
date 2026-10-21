# VENCIRA — API inicial de acceso a vencimientos

Fecha: 20/10/2026. **Solo uso local para pruebas; NO producción**.

## Sesiones y autenticación

La autenticación provisional emplea sesiones Django, cookies HttpOnly y verificación CSRF en modificaciones. El navegador se identifica mediante `GET/POST /accounts/login/` y finaliza sesión mediante `POST /accounts/logout/`. No existen altas públicas ni tokens móviles; Flutter Web ya integra lectura y escrituras con cookie de sesión y CSRF desde el mismo origen. Django Admin tampoco es una interfaz de negocio para esta fase.

**El inicio de sesión cuenta con un limitador provisional por identificador**, pero carece de MFA, defensa frente a abuso distribuido y protección equivalente para Django Admin. No está listo para producción; todas las pruebas deben ejecutarse en loopback.

## Endpoints (versión 1)

| Método y ruta | Requisitos |
|---|---|
| `GET /api/v1/csrf/` | Obtener token CSRF de formulario/mutaciones web (sin datos del usuario) |
| `GET /api/v1/me/` | Usuario autenticado; ID y nombre de usuario |
| `GET /api/v1/workspaces/` | Únicamente membresías propias y roles |
| `GET /api/v1/workspaces/{uuid}/renewals/` | Miembro del workspace; resultados paginados hasta 100/página |
| `POST /api/v1/workspaces/{uuid}/renewals/` | Miembro; referencia, fecha y estado; workspace derivado exclusivamente de ruta autorizada |
| `GET /api/v1/workspaces/{uuid}/renewals/{uuid}/` | Miembro; únicamente dentro de workspace |
| `PATCH /api/v1/workspaces/{uuid}/renewals/{uuid}/` | Miembro; campos editables limitados |

No hay DELETE ni API de administración de usuarios, membresías o espacios de trabajo. Actualmente owner y member pueden modificar vencimientos; permisos más granulares pendientes de acordar.

## Campos del vencimiento

```json
{"customer_reference":"DEMO-001","expires_on":"2027-05-01","notice_deadline_on":"2027-03-31","status":"pending"}
```

`notice_deadline_on` es opcional, puede ser `null`, y nunca puede ser posterior a `expires_on`. El sistema no calcula plazos de preaviso automáticamente. `status`: `pending`, `contacted` o `closed`. `id`, `created_at` y `updated_at` son de solo lectura. `workspace` y `workspace_id` se rechazan en el cuerpo: no se puede mover información entre corredurías manipulando peticiones.

## Garantías comprobadas por tests

- Acceso anónimo denegado.
- Miembro A no lee, edita ni crea en organización B (404).
- Usuario sin membresía tampoco puede acceder.
- No se puede recuperar un vencimiento de B usando la URL de A.
- Asignación forzada de organización desde JSON rechazada (400).
- Cookie de sesión sin token CSRF no autoriza escritura (403).
- Paginación, métodos y validaciones básicos.

**Limitaciones conocidas:** hay auditoría transaccional de cambios vía API, pero no es inmutable ni cubre modificaciones fuera de la API. Faltan políticas de borrado/retención, limitación integral de peticiones, MFA, gestión avanzada de sesiones y controles granulares de permisos. No cargar datos personales ni habilitar el tráfico público.

La interfaz Flutter Web implementa la creación, actualización y cierre de sesión. No expone un endpoint de borrado. La API de negocio continúa restringida a usuarios con membresía.

## Búsqueda y filtros de la lista

`GET /api/v1/workspaces/{uuid}/renewals/?page=1&q=DEMO&status=pending`

- `q`: coincidencia parcial sin distinguir mayúsculas en la referencia, máximo 80 caracteres (se eliminan espacios al inicio y final).
- `status`: opcional, uno de `pending`, `contacted` o `closed`.
- Si `q` está vacío o `status` no se indica, no se aplica dicho filtro; filtros inválidos responden 400.
- La comprobación de membresía y el aislamiento por workspace se realizan **antes** de aplicar filtros y paginación.
- La paginación refleja el número de resultados filtrados, no los de otras organizaciones.
- En Flutter Web, el usuario puede buscar y filtrar por estado; cambiar de organización limpia ambos filtros. Al crear un registro también se limpian para que no quede oculto.
