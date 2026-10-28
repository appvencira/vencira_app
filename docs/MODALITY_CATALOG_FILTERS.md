# VENCIRA — Catálogo de modalidades y filtros combinables

**Fuente:** whitepaper `White_paper_agenda_vencimientos.pdf` (18/10/2026), §5 (filtros), §6 (modalidades), §12 (seguridad) y §13 (idiomas). Revisado antes del desarrollo.

## Contrato funcional de esta iteración

1. Cada **cuenta** tiene un catálogo lógico propio. Al crear cuenta, aparecen automáticamente las 12 modalidades del whitepaper sin crear filas; las personalizaciones se guardan como overrides en `WorkspaceModality`.
2. El administrador/propietario puede **añadir**, **renombrar**, **desactivar** y **reactivar** opciones. Los usuarios miembros pueden leer el catálogo y seleccionar opciones activas, pero **no modificarlo**.
3. Cada modalidad conserva su **código inmutable**. Renombrar cambia el nombre visible, no `Renewal.modality`. Eliminar desde UI desactiva la opción; se conserva en BD para las anotaciones existentes. No se destruye una póliza por cambiar el catálogo.
4. Un mismo nombre activo no se acepta dos veces en la cuenta (comparación insensible a mayúsculas). Las nuevas anotaciones no pueden usar modalidades desactivadas o de otra organización. El editor permite conservar sin modificar el código desactivado/legacy de una anotación histórica.
5. La API devuelve `{code,label,active,builtin}`. Para las opciones predeterminadas sin nombre cambiado, Flutter usa traducciones ES/CA; las personalizadas se muestran según el nombre escrito por el administrador. Esta primera versión **no traduce automáticamente nombres personalizados**.
6. Filtros de **Entrada (Todas/Clientes/Candidatos)** y **Modalidad (Todas/opción)** combinables en lista de anotaciones y agenda diaria; los filtros permanecen al abrir calendario mensual. La API filtra **antes** de paginar o calcular agregados.
7. `GET /api/v1/workspaces/{id}/modalities/`, `POST` (crear), `PATCH /modalities/{code}/` (nombre o reactivar) y `DELETE /modalities/{code}/` (desactivar). Escrituras solo por sesión con CSRF, pertenencia y rol owner. Separación estricta por workspace.
8. Conserva las versiones previas, PostgreSQL, proyectos Compose separados y datos ficticios. Migración `0009_workspace_modality` **no destructiva**: nueva tabla independiente sin modificar pólizas existentes.
9. `Clientes/Candidatos` siguen siendo Entradas de **pólizas externas individuales**. No crear entidad global de cliente o CRM. Los puntos de evento diario/semanal/mensual siguen codificando vencimiento, preaviso y avisos previstos, no Entrada.
10. Los campos con personas reales, DNI y adjuntos siguen deshabilitados como datos reales hasta completar cifrado en reposo, retención y controles RGPD. La API de catálogo solo acepta nombres de modalidades (no valores libres de pólizas).

## Consultas

```text
GET /api/v1/workspaces/{id}/renewals/?entry=clients&modality=hogar&page=1
GET /api/v1/workspaces/{id}/agenda/?day=2026-10-29&entry=clients&modality=hogar
GET /api/v1/workspaces/{id}/agenda/month/?month=2026-10&entry=clients&modality=hogar
```

Se preservan los permisos de owner (toda cuenta) y miembro (asignación propia) antes de aplicar los filtros; no se exponen recuentos de otros usuarios o empresas. Mes no contiene identificadores ni referencias de pólizas.

## Verificación

- Pruebas Django SQLite/PostgreSQL17: defaults sin filas, autorización del owner, aislamiento, alta/renombrado/desactivación/reactivación, datos legacy, validaciones y filtros en lista/mes/día.
- Flutter: cliente HTTP de origen único y CSRF, parseo del catálogo y validación de filtros, editor de modalidades, pantallas ES/CA y estados.
- E2E Docker: login real, petición privada catálogo, escritura con CSRF, desactivación sin destruir referencia, creación y consulta con filtros.
- Despliegue previsto solo tras CI verde con **backup PostgreSQL verificado**, Git SSH, `api web_preview` del proyecto `vencira_localcheck`. Sin `down -v`, sin reiniciar base de datos, sin tocar `vencira_preview` ni Caddy.

## Pendientes de whitepaper

Listas editables de motivos de aviso, aseguradoras, filtros por aseguradora/usuario, datos personales obligatorios, archivos y cierre funcional del §9. Se implementarán como etapas separadas después de completar seguridad e integración.
