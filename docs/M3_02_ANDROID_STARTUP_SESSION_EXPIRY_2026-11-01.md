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

## Bloqueos que no deben levantarse

- La programación nativa sigue sin usarse desde la UI, no se solicita consentimiento de activación y no hay prueba de alarmas entregadas ni tras reboot/Doze/DST.
- La revocación por 401 está conectada a tres flujos del dashboard; otros subflujos de API podrían requerir interceptación global. No afirmar revocación universal del proceso.
- La cancelación nativa tras fallo OS requiere reintento; no se permite saltar la recuperación.
- M3-02 sigue abierto. **2/15 = 13,3 %**; `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Sin merge ni despliegue.
