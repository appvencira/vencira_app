# VENCIRA — M3-02: Android WAL, revocación y manifiesto mínimo (01/11/2026)

## Resumen de la fase

En la rama `feature/m3-android-local-notifications` (PR #17, **borrador**) se ha implementado una fase de seguridad y durabilidad para las notificaciones locales opcionales, **sin activarlas en `main.dart` ni en DEV**.

### 1. Manifest Android (rama base aislada)

`clients/flutter/android/app/src/main/AndroidManifest.xml` declara únicamente `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y los receptores no exportados `ScheduledNotificationReceiver` y `ScheduledNotificationBootReceiver` (acciones `BOOT_COMPLETED` y `MY_PACKAGE_REPLACED`). No solicita `USE_EXACT_ALARM` ni `SCHEDULE_EXACT_ALARM`; el adaptador usa `inexactAllowWhileIdle`. `scripts/check_android_platform_security.py` detecta receptores inesperados, permisos adicionales, exposición exterior, firma release con debug, backups automáticos y tráfico HTTP sin cifrar. Validación CI de la rama base: GitHub Actions run `41311838684` **success** y auditoría MB1 `41311838677` **success**.

### 2. Diario duradero cifrado (PR #17)

`device_notice_transaction.dart` y `device_notice_inventory.dart` registran **antes de cualquier llamada al sistema operativo** las identidades opacas de todas las alarmas que podrían modificarse. Tras un éxito se guarda el inventario final y se limpia el journal; si una confirmación se pierde, falla un almacenamiento, una cancelación o muere el proceso, el journal bloquea nueva programación hasta que `recoverInterruptedDeviceNotices` cancele los identificadores afectados y actualice el inventario de forma comprobada. Un fallo de recuperación mantiene el journal; **no se afirma entrega ni cancelación exitosa**.

`EncryptedAlarmInventory` utiliza `flutter_secure_storage` con namespace aislado. Impide sobrescribir o borrar una lista de otro `workspace/user` y obliga a resolver el journal antes de eliminar la clave principal. Los datos persistidos son identificadores técnicos y fechas, nunca nombres, referencias, teléfonos ni mensajes de clientes.

### 3. Revocación

`revokeAllDeviceNotices` cancela la lista verificada antes de vaciar su inventario, con ensayo de recuperación ante cancelación fallida. `AndroidLocalAlarmPort.prepareForRevocation` permite *solo cancelar* incluso cuando el permiso de notificaciones ya no está concedido; dicho modo impide programar. El registro de IDs permite reintentar cancelaciones verificadas sin abrir acceso a claves de otra cuenta. La inicialización para programar **sigue exigiendo** consentimiento, permisos, plataforma Android, inventario verificado y zona `Europe/Madrid`.

### 4. Pruebas nuevas

- `device_notice_transaction_test.dart`: journal previo a OS, ACK perdido, caída entre OS y commit, fallo de almacenamiento, cancelación fallida y recuperación, cambio de fecha, referencias de otra cuenta, revocación y reintentos.
- `device_notice_inventory_test.dart`: rechazo de sustitución cruzada entre cuentas.
- `android_local_alarm_port_test.dart`: registro de IDs y cancelación idempotente.
- CI M3 ejecuta pruebas en SQLite, PG17 efímero, Flutter y Web; CI Android adicional intenta build APK debug sin distribuir. Guardar **los resultados exactos solo después de comprobar cada job**.

## Pendientes que bloquean activación

1. Implementar el coordinador **único** del ciclo de sesión autenticada (login, selección de workspace, logout, revocación), serialización de transacciones y cambio de cuenta sin pérdidas ni colisiones; resolver el caso de almacenamiento recuperable de un usuario anterior.
2. Añadir una interfaz explícita de consentimiento/denegación y revocación, sin activación automática en `main.dart`, y persistir el opt-in de forma privada.
3. Verificar en dispositivos Android físicos: permisos Android 13–16, modo sin red, reinicio de móvil y reinstalación, Doze, actualización de la app, horarios de verano y saltos del reloj. Un build APK no acredita entrega ni supervivencia a reinicio.
4. Cerrar las decisiones de UX/reglas §18 del whitepaper y auditoría de seguridad de extremo a extremo.
5. Resolver bloqueos globales MB1 y MFA/C-FICHA antes de cualquier despliegue.

```text
ANDROID_NATIVE_ALARM_CODE=PREPARED_NOT_ENABLED
ANDROID_SCHEDULE_ON_STARTUP=NO
ANDROID_LIVE_NOTIFICATION_DELIVERY=NOT_TESTED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

Hito M3-02 **abierto**, progreso formal **2/15 (13,3%)**, PR #17 permanece en borrador y sin merge.
