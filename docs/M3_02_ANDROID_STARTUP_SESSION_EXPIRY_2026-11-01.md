# VENCIRA — Android: arranque seguro, sesión caducada y revocación por membresía
**Fecha:** 2026-11-01. **Rama:** `feature/m3-android-local-notifications`. **PR:** #17, borrador.

## Implementación

- `device_notice_startup_gate.dart`: en el cliente Android real, la interfaz autenticada **no se monta** hasta que concluye `revokePersistedAndroidAlarms()`. La operación es exclusivamente de cancelación de alarmas anteriores, sin programación. Si falla la recuperación, se conserva el inventario cifrado y aparece un reintento ES/CA que no se puede omitir. Web y APIs simuladas permanecen fuera de la ruta nativa.
- `main.dart`: las cancelaciones en arranque, logout, cambio de workspace y sesión expirada comparten una operación *single-flight* para evitar invocaciones nativas simultáneas. Los datos de clientes no se solicitan antes de terminar la barrera.
- `dashboard_screen.dart`: respuestas 401 de la carga de workspaces, renovaciones y guardado ocasionan ocultación inmediata de datos y revocación local. Un error de cancelación bloquea futuras recargas hasta un reintento correcto. Si una actualización de membresías elimina el workspace activo, primero se revocan las alarmas antes de seleccionar otro.
- Seguridad del menú Android: acción **«Cancelar avisos locales del dispositivo»** ES/CA. Realiza la misma cancelación, ofrece feedback y **no activa el envío**. Solo visible en Android con callback nativo real; una interfaz de consentimiento para nuevas programaciones sigue pendiente de aceptación.
- Test `device_notice_startup_gate_test.dart`: bloqueo hasta cancelación, fallo y reintento, nueva instancia de app, y cliente de pruebas sin plugins. `device_notice_logout_widget_test.dart`: caducidad HTTP, reintento tras fallo, pérdida remota de membresía, bloqueo ante cancelación fallida, logout y acción de ajustes.

## CI

La revisión inicial (`c8f29f6a`) está verificada en GitHub Actions run **41316823207**: Django **73/73 SQLite**, **73/73 PostgreSQL 17 efímero**, Flutter **115/115**, `flutter analyze` PASS y `flutter build web` PASS. Estos resultados solo cubren el código presente en ese commit.

La última revisión de esta fase incorpora el manejo de cambios automáticos de workspace y la acción de ajustes. Sus workflows deben quedar en verde de forma independiente antes de afirmar aceptación. Compilar APK no demuestra avisos reales ni funcionamiento offline en un terminal físico.

## Ampliación: cancelación manual y pérdida de membresía

- En ajustes de seguridad Android se ha incorporado una acción funcional de **cancelación voluntaria**, sin permitir opt-in ni programación hasta liberación del producto. La interfaz usa ES/CA y muestra confirmación o error según el resultado real.
- La actualización de workspaces contempla la **pérdida remota de pertenencia**. Si la selección automática del servidor cambia de workspace, se revocan las alarmas anteriores *antes* de mostrar el nuevo espacio. Si falla, se limpia la vista y se impide el cambio.
- Widget tests adicionales prueban pérdida de pertenencia con y sin fallo de revocación y cancelación voluntaria desde ajustes Android.

### Incidencia de prueba identificada

En run `41317117956` Django SQLite y PG17 finalizaron PASS. Flutter obtuvo **117 PASS / 1 FAIL** por no restablecer `debugDefaultTargetPlatformOverride` antes del final del test de ajustes. **No fue una excepción del adaptador de notificaciones ni una alarma real**, pero el job completo fue FAIL. La corrección está en commit `1a20c8c7` y se está revalidando en workflow `41317331030`; no asumir PASS hasta ver los tres jobs finales.

## Resultado final de contratos y corrección de la incidencia

- **Commit funcional verificado:** `1a20c8c7fd3e8073016aa094c827e99c6dde4001` (corrección del test que restaura la plataforma simulada antes de finalizar).
- Workflow **M3 product contracts**, run **41317331030**: tres jobs `success`. Django SQLite **73/73 PASS**, Django PostgreSQL 17 efímero **73/73 PASS**, Flutter `analyze` **PASS**, **118/118 tests Flutter PASS**, `flutter build web` **PASS**.
- La ejecución anterior `41317117956` conserva su resultado real: **117 pruebas PASS y una FAIL**, sin build Web de ese job; se corrigió el test y se ejecutó la batería íntegra, no se omitió ningún caso.
- Workflow de compilación APK Android de este commit: `41317331055`, **todavía en ejecución** al registrar este resultado. Una compilación anterior `41317117946` sí terminó `success` (código anterior). No extrapolar al commit posterior.

## Bloqueos que no deben levantarse

- La programación nativa sigue sin usarse desde la UI, no se solicita consentimiento de activación y no hay prueba de alarmas entregadas ni tras reboot/Doze/DST.
- La revocación por 401 está conectada a tres flujos del dashboard; otros subflujos de API podrían requerir interceptación global. No afirmar revocación universal del proceso.
- La cancelación nativa tras fallo OS requiere reintento; no se permite saltar la recuperación.
- M3-02 sigue abierto. **2/15 = 13,3 %**; `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Sin merge ni despliegue.

## Endurecimiento posterior: transición dinámica de barrera (01/11/2026)

- Commits `aebf1b0` y `0167467`: el widget de arranque invalida comprobaciones anteriores si cambia la función de revocación o el indicador de habilitación. Un resultado asíncrono obsoleto no puede dar acceso al dashboard.
- Nuevos widget tests: sustitución de callback durante cancelación pendiente y transición de modo exento a modo protegido.
- CI para `0167467` lanzado: **M3 product contracts** run `41323071904` (pending), **Android scaffold verification** run `41323071886` (in progress), **Android adapter compile** run `41323071814` (queued) en la comprobación inicial. No atribuir PASS hasta que GitHub registre conclusión exitosa del commit.
- Continúa pendiente la intercepción universal de 401, consentimiento UX y entrega real en dispositivo. No se modifica la autorización de release.

```text
M3_02_DYNAMIC_STARTUP_GATE=IMPLEMENTED_AWAITING_CI
M3_02_DEVICE_DELIVERY_EVIDENCE=NO
M3_02_OS_SCHEDULING_ENABLED=NO
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Bloque ampliado — revocación de catálogos y evidencia CI

- GitHub Actions para commit `5ace851`: run M3 `41323281334` con los tres jobs `success` (Flutter, Django SQLite, Django PostgreSQL17); Android debug run `41323281277` `success`. La verificación de scaffold se omitió (`skipped`); no contabilizarla como PASS.
- Los flujos de carga de modalidades y aseguradoras ahora distinguen `VenciraUnauthorized` de errores genéricos y solicitan revocación local de alarmas al perder sesión. Tests widget añadidos para ambos endpoints.
- Commit `f3dbc69`: al detectar sesión caducada, se descartan también las cachés de modalidades y aseguradoras; respuestas asíncronas de los dos catálogos no repiten la revocación si ya se invalidó la sesión.
- Estos cambios posteriores a `5ace851` requieren su propio CI; **no extender los PASS previos al HEAD**.
- Se mantienen pendientes los subflujos de pantallas secundarias y una estrategia global para autentificación que evite pérdida accidental de errores `401`. Un `403` puede representar denegación de permisos sin caducidad; distinguir correctamente ambos códigos antes de modificar el contrato HTTP.

```text
M3_02_CATALOG_AUTH_REVOCATION=IMPLEMENTED_AWAITING_NEW_CI
M3_02_DEVICE_DELIVERY_EVIDENCE=NO
M3_02_OS_SCHEDULING_ENABLED=NO
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Bloque adicional de pertenencia remota — 01/11/2026

- CI previo en commit `04ad55e`: M3 contracts run `41328965010` **success**, Android debug run `41328965055` **success**, MB1 static run `41328965024` **success**; scaffold run `41328965072` **skipped**.
- Commit `abc5b0e`: si el servidor elimina el workspace activo y falla la cancelación nativa, el dashboard oculta también las cachés de modalidades y aseguradoras e invalida peticiones pendientes. Conserva el estado de fallo para bloquear recargas hasta reintentar la cancelación.
- Commit `d82c27f`: test widget de denegación de pertenencia con cancelación fallida, ocultación de espacios anterior y nuevo, y recuperación posterior.
- Los cambios de este bloque **requieren nuevo CI**; no inferir resultado desde el commit previo. M3-02 abierto, sin avisos Android reales ni autorización de despliegue.

## Control de respuestas tardías de catálogos (01/11/2026)

- CI de la revisión anterior `12b55c0`: M3 `41330260382`, Android `41330260363` y MB1 `41330260361` finalizaron `success`; scaffold `41330260417` fue `skipped`.
- `b7df09d`: el dashboard asigna una generación de sesión a peticiones de modalidades y aseguradoras. Al cambiar de cuenta, detectar caducidad o cerrar sesión invalida la generación anterior. Los resultados y errores de autenticación tardíos de una generación obsoleta se descartan.
- `214785d`: prueba de regresión que mantiene pendiente la carga de modalidades, cierra sesión y después entrega un error de autenticación antiguo; no debe provocar una segunda revocación ni mostrar el workspace anterior.
- Esta protección se limita a los cargadores del dashboard; no demuestra seguridad universal en pantallas secundarias ni revocación completa a través de todas las rutas.
- **Pendiente CI de esta revisión.** No habilitar avisos, fusionar, desplegar ni ejecutar migraciones persistentes.

## Ficha secundaria: aislamiento de datos revocados (01/11/2026)

- Commits `a26042a` y `a6c9588`: en `renewal_detail_screen.dart`, una denegación de autenticación al consultar aseguradoras ya no se oculta como error genérico; se propaga al controlador y se vacían anotación, historial, seguimiento y lista de aseguradoras. Si el seguimiento invalida la sesión, se descarta la generación actual y no se inicia la siguiente consulta.
- `c2c5a85`: se incorpora la ficha de anotación a los disparadores de M3 product contracts. Sin modificar el backend ni los permisos Android.
- **Límite importante:** la ficha aún no dispone de notificación centralizada al dashboard ni de cierre automático de otras rutas abiertas. Esta corrección impide conservar los datos del estado local afectado, no demuestra revocación universal de la aplicación.
- Se espera nueva validación CI; no atribuir PASS de revisiones anteriores a estos cambios. Continúan `M3_02_OS_SCHEDULING_ENABLED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` y autorizaciones MB1/MFA/C-FICHA en NO.
