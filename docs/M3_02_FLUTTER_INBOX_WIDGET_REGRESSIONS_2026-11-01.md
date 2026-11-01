# VENCIRA — M3-02: fiabilidad de la bandeja Flutter y estados internos (01/11/2026)

## Cambios funcionales revisados en código
- **Resultado de acción incierto**: `operational_inbox_screen.dart` fuerza una nueva lectura tras un error genérico de `updateOperationalReminder`. El servidor podría haber confirmado la escritura antes de perderse el ACK; la lista antigua no vuelve a ser accionable sin reconciliar. Una pérdida de autorización elimina el listado y bloquea acciones.
- **Recarga fallida**: la protección ya implementada mantiene oculta la lista anterior mientras persiste `_failed`, mostrando reintento. Las acciones no se permiten durante la carga.
- **Estados visibles**: las tarjetas muestran `Programado`, `Pendiente` o `Aplazado` mediante traducciones ES/CA que **ya existían** (`opStatePlanned`, `opStatePending`, `opStateSnoozed`). La fecha (hoy, atrasado, próximo) es un indicador independiente del estado.
- **Contrato de lectura**: `VenciraOperationalReminder.fromJson` ahora rechaza estados no admitidos, además de cualquier indicador de entrega distinto de `not_implemented`.

## Regresiones añadidas
- `clients/flutter/test/operational_inbox_widget_test.dart`: cuatro escenarios de widget: error de recarga, reintento posterior satisfactorio, pérdida de autorización, error de resultado incierto en acción y visualización del estado aplazado. [Los escenarios de recarga y recuperación se agrupan en el mismo test.]
- `clients/flutter/test/operational_inbox_test.dart`: test adicional que rechaza un estado no reconocido.
- `.github/workflows/m3-product-contracts.yml`: `flutter analyze` y ejecución de ambas baterías Flutter, más las pruebas Django previamente integradas.

## Afirmaciones y límites
Se han publicado código, tests y CI. **No hay resultado PASS verificado de Flutter ni Android en esta sesión.** No se han ejecutado pruebas locales por ausencia del SDK Flutter en el entorno de trabajo; las pruebas de widget pueden requerir correcciones tras la primera ejecución de Actions. Se mantiene la revisión funcional de los estados del servidor y las pantallas, sin considerar entrega de notificaciones, servicio externo o aceptación UX real.

No se han tocado DEV, PostgreSQL persistente, migraciones MFA ni copias O5. M3-02 sigue abierto y el total formal se mantiene en **2/15 (13,3 %)**.
