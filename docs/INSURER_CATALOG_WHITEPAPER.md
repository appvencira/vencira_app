# VENCIRA — Aseguradoras en la ficha, filtrado y gestión por cuenta

**Fecha:** 22/10/2026. **Fuente:** whitepaper original `White_paper_agenda_vencimientos.pdf` del 18/10/2026, §§5, 6, 12 y 15.

## Decisiones de producto

- Cada **anotación es una póliza externa independiente**; la aseguradora es un atributo opcional de la póliza, no una nueva ficha de cliente.
- El §6 pide un selector buscable de aseguradora, listado ampliable, y plantea **como fuente sugerida** el registro público de la Dirección General de Seguros y Fondos de Pensiones (DGSFP), que además alimentaría direcciones para una futura carta de no renovación (§15).
- **Esta fase no precarga ni afirma verificar el registro DGSFP.** El catálogo inicial está vacío y el propietario de cada cuenta añade *nombres ficticios* para pruebas. La carga oficial, su sincronización/licencia/procedencia y normalización de denominaciones y direcciones quedan pendientes de una tarea separada con fuente pública actualizada. NO deben usarse compañías reales como prueba antes de cumplir las medidas RGPD del §12.
- Se conserva `customer_reference` como referencia ficticia y no se agregan nombre, DNI, teléfono, correo, notas libres ni documentos. El historial sigue sin exponer nombres de póliza ni valores arbitrarios.

## Modelo y migración

- Migración `0010_workspace_insurer` crea `WorkspaceInsurer` con `workspace`, `name`, `normalized_name`, `active`, identificador UUID; `Renewal.insurer` nullable y FK protegida.
- Única combinación `workspace + normalized_name`: la misma cuenta no puede tener dos denominaciones equivalentes cambiando mayúsculas. Renombrar mantiene el UUID y, por tanto, los vínculos existentes. Desactivar oculta la opción en altas nuevas; registros previos pueden **conservar** su aseguradora desactivada. No se hace `DELETE` físico.
- No se altera ningún vencimiento, límite de preaviso ni recordatorio previo. El campo de las anotaciones históricas permanece `null`. Las futuras mejoras de V1 tendrán que definir nombres oficiales, códigos regulatorios y correspondencia entre marcas comerciales y entidades.

## API y seguridad

```text
GET    /api/v1/workspaces/{workspace_id}/insurers/?q=texto
POST   /api/v1/workspaces/{workspace_id}/insurers/
PATCH  /api/v1/workspaces/{workspace_id}/insurers/{insurer_uuid}/
DELETE /api/v1/workspaces/{workspace_id}/insurers/{insurer_uuid}/
```

- Miembro autorizado de la cuenta puede leer (máximo 100 coincidencias por solicitud, búsqueda `icontains` con longitud máxima 80). Solo el propietario puede crear, renombrar, desactivar o reactivar opciones; las escrituras exigen sesión y CSRF. Nunca aceptar `workspace` desde datos cliente.
- La póliza acepta una FK de aseguradora solo si pertenece al mismo workspace; opciones desactivadas no se asignan a pólizas nuevas, pero una anotación existente puede retenerla al actualizar otros campos.
- Los filtros opcionales `insurer=<uuid>` se aplican **después** del ámbito de permiso (owner o asignado) y **antes** de paginar/agregar en lista, agenda diaria y mensual. Los resúmenes mensuales no contienen IDs de clientes ni referencias.
- Auditoría registra únicamente el nombre de campo `insurer_id`, nunca el nombre de la aseguradora. El historial técnico del whitepaper aún requiere garantías de inmutabilidad en DB (append-only).

## Flutter

- Panel propietario: botón «Gestionar aseguradoras», con búsqueda remota, añadir, renombrar, desactivar y reactivar. Otros miembros no ven el botón, aunque sí leen opciones.
- Editor de anotación: campo opcional «Aseguradora» con filtro de texto dentro de las primeras 100 opciones, conservando la opción seleccionada aunque esté desactivada.
- Filtros Entrada/Modalidad/Aseguradora combinables en panel, agenda diaria y mensual. Las traducciones ES/CA se mantienen en los ARB.
- **Límite conocido**: el selector de anotación solo carga las primeras 100 opciones; para catálogos grandes falta un selector con búsqueda remota. La pantalla «Gestionar aseguradoras» sí busca en servidor y limita la respuesta a 100.

## Validaciones / próxima operación

- Django pruebas SQLite y PostgreSQL 17: migración no destructiva, pertenencia/rol, búsqueda, altas y bajas lógicas, cambio de nombre, auditoría mínima, filtros de pólizas en lista/día/mes.
- Flutter: análisis estático, tests ES/CA, tamaño móvil 320/375/768, contrato de filtros y CSRF, compilación real en Docker.
- E2E HTTP: login, CRUD catálogo ficticio, vincular aseguradora, filtrado, desactivación que conserva asociación y bloqueo tras logout.
- **No desplegar antes de CI verde.** Cuando esté validado, copia `pg_dump -Fc` del proyecto `vencira_localcheck`, verificación `pg_restore -l`, `git pull --ff-only` por SSH y reconstruir exclusivamente `api web_preview` del Compose `vencira_localcheck`. No tocar `vencira_preview`, Caddy, .env, PostgreSQL histórico ni credenciales. No usar `down -v`.
