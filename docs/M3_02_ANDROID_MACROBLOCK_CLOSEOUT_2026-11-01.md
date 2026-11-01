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
