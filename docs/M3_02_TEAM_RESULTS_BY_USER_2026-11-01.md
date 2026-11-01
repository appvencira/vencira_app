# VENCIRA — M3-02: resultados por usuario del administrador (01/11/2026)

## Implementación del whitepaper §11

Anteriormente la pantalla de resultados de escritorio mostraba únicamente totales de la cuenta. Ahora `GET /api/v1/workspaces/{workspace_id}/results/` incluye `by_user` con un desglose por usuario **solo para el propietario**. El endpoint ya rechazaba a los miembros con HTTP 403 y oculta la existencia de cuentas ajenas mediante HTTP 404; no se han ampliado sus permisos.

### Regla de atribución

- `won`, `declined` y `discarded`: por **actor histórico** que registró el `RenewalOutcome`, con límites de tiempo civil Europe/Madrid ya vigentes en el endpoint. Un cambio de responsable de la póliza no reescribe el autor de una operación pasada.
- `pending`: por **responsable actual** de una `Renewal` activa cuya expiración corresponde al periodo.
- Se enumeran miembros actuales del workspace (también si sus contadores son cero). Los resultados de operadores dados de baja y las anotaciones sin asignación van a una fila residual anónima `user_id=null,name=null`, mostrada con etiqueta localizada.
- `by_user` reconcilia exactamente las cuatro métricas de toda la cuenta; no se exponen referencias de clientes ni pólizas en el informe.

### Cliente Web

El modelo `VenciraResultsSummary` valida filas y totales, rechaza usuarios duplicados y datos inconsistentes; la pantalla `results_screen.dart` incorpora una tabla adaptable horizontalmente con cuatro métricas y nombre de operador. Etiquetas y explicación de la metodología en recursos ES/CA. La tabla no aparece en la pantalla móvil ni concede permisos de estadísticas a los miembros.

### Pruebas y ejecución REAL

- Backend `test_results.py`: totales reconciliados, actores históricos, miembros dados de baja, acceso restringido y DST; integrado en la batería M3 SQLite y PG17.
- Flutter `results_test.dart`: contratos de parseo, filas inválidas, totales discrepantes, etiquetas traducidas y tabla de escritorio.
- CI de la rama aislada validada en commit `e74be67bfb8eab127ee9fc109c93b4efbe2ab228`, run `41308100174`:
  - Django SQLite job `124852578665`: **73/73 PASS**.
  - Django PostgreSQL 17 efímero job `124852578535`: **73/73 PASS**.
  - Flutter job `124852578588`: **flutter analyze PASS**, **62/62 tests PASS**, **flutter build web release PASS**.
- MB1 auditoría estática `41308100084`: **success**; no equivale a congelación operativa.

### Incidencia de integración

El análisis inicial Flutter encontró un fragmento de código de preview de avisos nativos fuera de su clase en `vencira_api.dart`. La rama fue corregida en `e74be67`; la ejecución posterior sobre ese commit confirma el análisis, los tests y la compilación en verde. Las capacidades del preview siguen siendo informativas, **sin alarmas nativas, almacenamiento offline ni envío**. No considerar este contrato una implementación de notificaciones operativas.

### Bloqueos

El informe por usuario cubre una funcionalidad aprobada de V1, pero **no cierra M3-02**: faltan avisos nativos offline, decisiones pendientes §18, ciclo de notificaciones, aceptación móvil y controles de liberación. No se han utilizado datos reales ni migrado/desplegado la BD persistente. PR #14 permanece en borrador.

```text
M3_02_OWNER_PER_USER_REPORT=IMPLEMENTED
M3_02_DJANGO_SQLITE_73=PASS
M3_02_DJANGO_PG17_73=PASS
M3_02_FLUTTER_62=PASS
M3_02_WEB_BUILD=PASS
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Checklist formal: 2/15 (13,3 %).**
