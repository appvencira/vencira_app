# Seguridad: anotaciones asignadas en organizaciones (MVP)

Estado: implementación propuesta en rama `feat/team-assignment-isolation`, separada de idioma/UI y **sin despliegue**. Fecha 22/10/2026. Whitepaper: cuentas Individual/Equipo, propietario/administrador ve todas las anotaciones; miembros solo las asignadas.

## Brecha corregida

Antes: pertenecer a un workspace permitía ver y modificar todos sus `Renewal`, sin importar el usuario del equipo.  
Ahora (propuesto): todas las consultas se filtran por organización; para `member` se añade el filtro `assigned_to_id=request.user.id` **antes** de buscar, paginar o abrir/bloquear una fila. Respuestas a registros ajenos: 404.

## Contrato de API (provisional)

- `Renewal.assigned_to`: FK al usuario, nullable, índice compuesto workspace/responsable/vencimiento.
- `owner`: ve la agenda completa del workspace, puede crear y asignar a **miembros válidos de ese mismo workspace**, incluido sí mismo; si omite el campo al crear, se le asigna.
- `member`: ve y edita solamente los registros asignados a sí mismo, y los nuevos que crea se autoasignan. No puede enviar ni modificar `assigned_to`.
- Propietario puede poner `assigned_to: null`: registro a la espera de asignación, no visible para ningún miembro.
- El campo se expone en GET/POST/PATCH como identificador de usuario interno; nunca implica aceptar `workspace` desde JSON.
- Usuario inexistente/no perteneciente al workspace produce error de validación; registros ajenos, aunque se conozca el UUID, no se revelan.
- Códigos de dominio `pending`, `contacted`, `closed` se mantienen sin traducciones en base de datos.
- Las reasignaciones se auditan por **nombre de campo modificado**, sin almacenar referencias personales de clientes ni ID de usuarios en el metadata del evento.

## Migración

`0007_renewal_assignment.py` añade un FK nullable y un índice. **No autoasigna filas existentes**, porque no existe suficiente información para saber el responsable. Todas las antiguas quedan sin asignar y solo el propietario podrá abrirlas y asignarlas. Es un cambio restrictivo de acceso deliberado que se debe avisar a usuarios de la demo antes de integrar.

No cambiar ni eliminar el registro histórico en una migración de estructura. Antes de producción, acordar conservación y gestión de responsables cuando salen del equipo. `on_delete=SET_NULL` cubre eliminación de cuenta de usuario, pero la mera eliminación de una membresía **no borra automáticamente la asignación**; se requiere workflow de desactivación y reasignación.

## Pruebas obligatorias

- `python manage.py makemigrations --check --dry-run`
- `python manage.py test` tanto en SQLite como PostgreSQL 17 (workflow `backend-security.yml`).
- Usuario miembro A solo ve sus datos; no puede leer ni PATCH los del miembro B, ni desasignados.
- Filtrado por estado/referencia y paginación nunca filtran datos antes de aplicar el alcance.
- Propietario puede ver todos y asignar solo dentro del workspace; no permitir ID de otra organización.
- Altas de miembros quedan autoasignadas.
- CSRF, auditoría y transaccionalidad de actualizaciones sin regresiones.
- Comprobar migración en esquema vacío y poblado; verificar rollback con backup, no hacer `migrate ... zero` en ningún entorno compartido.

## Pendiente fuera de alcance

- UI para elegir responsable y vistas de miembros, según whitepaper.
- Política de baja, suspensión y transferencia de anotaciones de un empleado.
- MFA y gestión de usuarios de equipos.
- Cierre contractual, calendario completo, notificaciones offline, archivos privados y RGPD.

## Liberación

No fusionar ni desplegar hasta CI verde y revisión de semántica de las asignaciones por el propietario. Nunca usar datos personales de clientes en el preview actual. Ver issue #5: https://github.com/appvencira/vencira_app/issues/5.
