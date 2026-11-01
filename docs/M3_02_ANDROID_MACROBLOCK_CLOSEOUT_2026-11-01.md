# VENCIRA — M3-02: cierre por macrobloques (01/11/2026)

## Política de trabajo

Evitar ciclos de un commit por incidencia y una respuesta por commit. Cada macrobloque debe entregar código, pruebas, CI, documentación y un veredicto explícito. No se contabilizará un hito completo por pruebas unitarias aisladas.

## Baseline verificada

Commit `b54cc5931e67454ad119666bb9cbc4b8cf789ef7`:
- GitHub Actions M3 product contracts `41332033103`: **success**.
- Android adapter compile `41332033101`: **success**.
- MB1 static security gates `41332033105`: **success**.
- Android scaffold verification `41332033246`: **skipped**, no PASS.
- PR #17 sigue draft; sin release, deploy o migraciones persistentes.

## MACROBLOQUE A — sesión y navegación transversales

Alcance: rutas secundarias (ficha, editor, agenda, bandeja, modalidades, aseguradoras, historial), invalidez de identidad, retirada de membresía y control del ciclo de vida de widgets. Evitar que una ruta ya montada vuelva a mostrar datos después de una revocación.

Criterio de cierre: test widget de revocación propagada desde cada ruta con datos visibles, reintento fallido y respuesta tardía; ausencia de rutas residuales al cerrar sesión; Flutter analyze + tests + Web + Android debug en verde. Hasta entonces, `SESSION_CROSS_ROUTE=OPEN`.

## MACROBLOQUE B — avisos Android reales con consentimiento

Alcance: pantalla opt-in explícito por usuario/workspace; permiso Android solicitado solo mediante gesto del usuario; reconciliación con la base cifrada; cancelación por logout/revocación; reinicio y recuperación; política de alarmas inexactas.

Criterio de cierre: tests de contrato + prueba instrumentada o manual documentada en terminal Android físico con activación, notificación local, denegación/revocación de permisos, modo avión, reinicio, Doze y fecha/huso. La construcción APK no prueba entrega. Mantener `OS_SCHEDULING_ENABLED=NO` hasta aprobar criterios.

## MACROBLOQUE C — liberación controlada

Alcance: integración de las ramas dependientes, revisión whitepaper, custodia externa de claves, gates MB1/MFA/C-FICHA, preflight PG17 aislado y estrategia de rollback. NO ejecutar despliegue o migración persistente hasta autorización explícita fundada en evidencia.

Criterio de cierre: documentación de riesgos, pruebas finales y autorizaciones verificadas. Estado actual: `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`.

## Regla de reporting

Reportar una vez por macrobloque: cambios funcionales, commit, ejecución CI, errores pendientes, bloqueo físico y porcentaje formal justificado. Avanzar a continuación sin celebrar cada corrección como un hito.

```text
M3_02_SESSION_CROSS_ROUTE=OPEN
M3_02_DEVICE_DELIVERY_EVIDENCE=NO
M3_02_OS_SCHEDULING_ENABLED=NO
M3_02_RELEASE_AUTHORIZED=NO
GLOBAL_PROGRESS=2/15
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## A1 — Consolidación de escrituras de ficha (01/11/2026)

- Commit `5a127a0`: cinco manejadores de `VenciraUnauthorized` en las escrituras de la ficha (seguimiento y operaciones de anotaciones) dejan de limitarse a una bandera local; pasan por `_invalidateSession()`, que invalida datos, notifica al dashboard y solicita revocación nativa antes de cerrar la ruta.
- La integración sustituye solo manejadores con excepción de sesión **confirmada**; no convierte un simple 403 de permisos en cierre de sesión, porque la capa HTTP ya distingue identidad.
- La prueba `detail_expiry_navigation_test.dart` y el gate de Flutter permanecen en el workflow M3; aun así el flujo específico de escritura denegada requiere prueba de regresión antes del cierre del macrobloque A.
- `SESSION_CROSS_ROUTE=OPEN`: bandeja, agenda, catálogo, editor e historial necesitan revisión; no se declara finalización por este cambio.

## A2 — Catálogo de modalidades

- `3e12f2f` y `8c1ec79`: las consultas y escrituras del catálogo que confirman `VenciraUnauthorized` borran los datos locales y propagan la invalidación al dashboard, incluyendo solicitud de cancelación nativa y salida de la ruta secundaria.
- Quedan sin cerrar agenda, bandeja y demás superficies, y falta CI del último head. El macrobloque A continúa OPEN. No despliegue ni avisos reales.

## A3 — Agenda y bandeja (01/11/2026)

- Commits `6f2194e`, `b87216e` y `dd3f6d8`: propagan la pérdida confirmada de identidad desde las pantallas de agenda y bandeja al dashboard y sus barreras de cancelación, invalidan generaciones de consultas, vacían datos sensibles y cierran rutas tras el callback. Las aperturas de detalle desde agenda/bandeja conservan la cadena de revocación.
- El historial y sus rutas anidadas continúan bajo auditoría; no declarar macrobloque A completo.
- CI de la revisión pendiente; no activación de avisos ni despliegue.

## A4 — Historial y rutas anidadas

- Baseline `ef15e1b`: M3 contracts `41335397190` PASS, Android debug `41335397115` PASS, MB1 static `41335397151` PASS; scaffold `41335397147` SKIPPED.
- Historial operativo e índice eliminan eventos y filas cuando hay `VenciraUnauthorized`, notifican mediante callback opcional y cierran la ruta secundaria. Ficha y bandeja transmiten el callback a los historiales anidados.
- CI de esta revisión no confirmado; no se declara cierre de A ni entrega de notificaciones Android. Debe revisarse con tests la navegación anidada y el alcance de otras pantallas.

## A4 — Corrección de navegación anidada

- La propagación desde historial individual → índice/bandeja → ficha → dashboard podía intentar varios `Navigator.pop()` sucesivos sobre rutas distintas. Se sustituyó la salida de los controladores de invalidación por `Navigator.popUntil((route) => route.isFirst)`, condicionado a que exista callback de revocación del controlador padre.
- Este comportamiento todavía exige una prueba widget de navegación anidada y CI del commit final. No convertirlo en veredicto de finalización de macrobloque A.

## A4 — Prueba de navegación anidada

- Commits `92a17e4` y `1edd647`: nueva prueba de widget `detail_expiry_navigation_test.dart` para abrir dos rutas (intermedia e historial), simular `VenciraUnauthorized` durante carga del historial, contar una sola notificación al controlador padre y comprobar el retorno directo al inicio.
- La firma simulada usa `VenciraOperationalHistory`, coherente con la API declarada.
- CI del conjunto aún por comprobar. El macrobloque A no se declara completo con una única prueba de navegación.

## A4 — Recuperación de evidencias CI

- Los commits `57c5f7a` y `812bfc6` no mostraron ejecuciones vinculadas a PR mediante la consulta disponible, por lo que **no existe evidencia verificada de PASS** para A4.
- `770a817`: el workflow M3 ahora también escucha `push` de `feature/m3-android-local-notifications`, y su filtro `pull_request` incluye expresamente ambos archivos del historial. Los jobs siguen siendo tests Django aislados, Flutter y compilación web; no despliegan ni migran persistente.
- **Limitación del verificador**: la consulta de ejecuciones por commit disponible filtra eventos de pull request. La ausencia de resultados en ella no prueba que no haya ejecuciones por push. Confirmar resultados desde GitHub Actions antes de cerrar A.

## A4 — Barrera de limpieza y verificación de PR

- PR #17 comprobada abierta en borrador, head `ed8d4d1`, base `feature/mb1-m104-transition-contract-batch` antes de esta tanda.
- Commit `0b62541`: test widget adicional con `Completer` que obliga a mantener abierta la ruta de historial mientras la cancelación en el controlador padre está pendiente, y solo permite volver a la raíz al completar la barrera. Verifica notificación única.
- La consulta de ejecuciones por commit sigue sin mostrar resultados PR del head anterior. **No hay PASS verificable** de esta tanda en esta comprobación. El workflow habilita `push` para la rama M3, pero el conector consultado muestra únicamente runs PR; revisar Actions directamente antes de autorizar el cierre.

## A4 — Fallo de cancelación nativa (01/11/2026)

- `8184416` y `41605de`: si el callback de limpieza del padre falla, las vistas de historial conservan la ruta con los eventos/filas sensibles ya borrados y no ejecutan salida de navegación. El bloqueo persistente y el reintento de la barrera corresponden al controlador principal.
- `68615e8`: prueba widget de fallo de la barrera: una excepción simulada en la cancelación no debe devolver automáticamente al usuario a la raíz ni reintroducir eventos.
- Queda pendiente CI de estos cambios y una auditoría de reentrada para otras pantallas. Macrobloque A **NO cerrado**.

## A5 — Consistencia de barrera entre rutas (01/11/2026)

- Commits `8d2d66f`, `726902a`, `99ebbd7`, `3e17b77`: ficha, bandeja, agenda y catálogo capturan el fallo del callback de revocación nativa, conservan estado invalidado y evitan cerrar la ruta si no hay confirmación. Se unifica la conducta que ya aplicaban los historiales.
- Commit `aa2a01f`: adaptador `_handleExpiredSessionFromChild` del dashboard comunica a las rutas hijas el fallo de la barrera nativa, después de limpiar el estado global. El manejador local previo sigue compatible con rutas originales.
- **CI de esta tanda aún no confirmado**. Pendiente revisión de rutas adicionales y prueba widget específica del adaptador dashboard. Sin inferir autorización global.

## A5 — Cierre de regresiones de fallo de cancelación

- PR #17 continúa draft. Head anterior `c549d55`, sin resultados CI PR disponibles en el conector; no atribuir PASS.
- `c291f4e`: prueba widget de ruta de ficha con `VenciraUnauthorized` y rechazo del callback de cancelación nativa. Exige que la ruta permanezca montada, sin abrir automáticamente otra ruta.
- Se mantienen las pruebas equivalentes del historial, la espera de barrera con `Completer`, clasificación HTTP y cancelación desde dashboard.
- **Pendiente** comprobar CI vía GitHub Actions, analizar otras rutas y ejecutar ensayos reales de Android. Estado A=OPEN, B=BLOCKED, autorizaciones de release=NO.

## A6 — Eliminación de la incertidumbre de disparo CI

- Commits `d20eabb` y `4213ccd`: workflow M3 configurado para ejecutar contratos en **todas** las actualizaciones de PR y disponible para `workflow_dispatch`. El evento `push` de la rama M3 se mantiene; se eliminan filtros de rutas para `pull_request` que podían dejar nuevas revisiones sin cobertura.
- Esta configuración no confiere permisos de despliegue ni migraciones. Los resultados de los nuevos runs deben verificarse antes de considerar A cerrado. El conector usado para consultar ejecuciones por commit solo devuelve runs de PR; no debe inferirse que un push sin resultado esté fallando o pasando.
