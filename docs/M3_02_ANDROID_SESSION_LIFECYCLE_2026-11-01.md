# VENCIRA — M3-02: vínculo de sesión, consentimiento y revocación Android

Fecha: 01/11/2026. Rama: `feature/m3-android-local-notifications`, PR #17 **en borrador**. Sin merge, sin despliegue ni migración a PostgreSQL persistente.

## Integración realizada

1. **Identidad autenticada:** el cliente Flutter consulta `GET /api/v1/me/` para el ID entero del sujeto. Ya existía el endpoint Django, que devuelve `request.user.pk`; su nuevo cliente rechaza identificadores no enteros, booleanos, ausentes, negativos y sesiones caducadas. El coordinador comprueba además la pertenencia actual a `GET /api/v1/workspaces/`. No deduce identidad de nombres de usuario ni del campo visual de la cuenta.
2. **Consentimiento privado:** `device_notice_consent.dart` contiene un modelo de opt-in explícito, versionado y cifrado en Android Secure Storage, vinculado al par usuario/workspace. Valor inexistente, corrupto o de otro usuario = permiso no concedido; escribir, sobrescribir o revocar pertenece a ese mismo sujeto. La habilitación no está accesible desde la interfaz de producción.
3. **Coordinación serializada:** `device_notice_session_coordinator.dart` procesa cambios de workspace, activación, reconciliación y logout mediante una cola, valida el usuario autenticado y la pertenencia, y vuelve a validarlos tras recibir la vista previa remota antes de tocar el SO. Rechaza previews incompletas e inventarios de otra cuenta. El flag de construcción `nativeRolloutApproved` vale **false** por defecto. No se instancia en `main.dart`, y no se llama a ningún método de programación durante el arranque.
4. **Recuperación entre sesiones:** `device_notice_inventory.dart` extrae el propietario de un inventario **validado**, de modo que, al cambiar de usuario tras reiniciar, el cliente puede revocar primero las alarmas del propietario anterior; los diarios pendientes cifrados mantienen las identidades necesarias tras caídas.
5. **Revocación conectada a la interfaz:** `device_notice_revocation.dart` es una ruta nativa exclusivamente de cancelación, no crea alarmas. `main.dart` la conecta mediante `beforeSessionBoundary` al `VenciraDashboardScreen` real en Android. Se ejecuta **antes** de la petición de cierre de sesión y antes de cambiar el workspace. Si la cancelación o el almacenamiento fallan, la operación se bloquea; no se borra la identidad criptográfica ni se da el logout por realizado. En Web se omite la ruta de Android. Los tests con API inyectada no invocan plugins nativos.
6. **Pruebas:** `device_notice_session_coordinator_test.dart`, `device_notice_auth_identity_test.dart`, `device_notice_consent_test.dart`, `device_notice_logout_widget_test.dart` y test de propietario recuperado en `device_notice_inventory_test.dart`. Incluyen cambio de cuenta, sesión HTTP revocada, respuesta remota tardía, fallo de cancelación, reintento y orden cancelación/logout.

## Evidencia CI

**Código validado en commit `d4f5289fc853fdb2d7e3d63f6c02d855966f1470`:** workflow M3 `41315494796`, tres jobs `success`:
- Django SQLite temporal: **73/73 PASS**.
- Django PostgreSQL17 temporal: **73/73 PASS**.
- Flutter analyze: **PASS**.
- Tests Flutter: **108/108 PASS**.
- Flutter Web release build: **PASS**.

La última modificación de un test de recuperación de propietario y de comentarios se produjo en commits posteriores: **no atribuir estos PASS a ellos** hasta completar su CI.

La compilación Android del último commit está siendo comprobada en un workflow separado. La compilación APK de un commit anterior **no prueba** que los cambios de UI o revocación de este bloque hayan sido instalados en un teléfono.

## Riesgos y trabajo pendiente

- Conectar una pantalla de consentimiento y ajustes nativos, incluida solicitud de permiso OS solo por acción explícita, y un único punto de inicialización tras login. **No activarlo** hasta tener garantía de serialización a través de todo el proceso y ausencia de tareas concurrentes en otros isolates.
- Validar con Android físico las alarmas reales, bloqueo de pantalla, reinicios, modo avión, Doze, cambio de hora/DST, denegación de permiso y baja remota de membresía. La ruta actual solo permite **cancelación** desde la UI; la programación real no se ejecuta en producción.
- Revocación por caducidad de sesión detectada durante operaciones secundarias y al reabrir la app, además del cierre de sesión explícito y cambio manual de workspace.
- Aceptación UX, whitepaper §18, custodias y bloqueos de liberación MB1/MFA/C-FICHA.

```text
M3_02_NATIVE_SESSION_BOUNDARY=WIRED_CANCEL_ONLY
M3_02_AUTH_ME_IDENTITY=IMPLEMENTED
M3_02_ENCRYPTED_CONSENT=IMPLEMENTED_NOT_EXPOSED
M3_02_OS_SCHEDULING_ENABLED=NO
M3_02_DEVICE_DELIVERY_EVIDENCE=NO
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

M3-02 sigue **abierto**. Progreso formal **2/15 = 13,3 %**.
