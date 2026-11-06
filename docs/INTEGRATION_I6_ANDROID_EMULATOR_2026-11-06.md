# I6 — Ensayo Android emulado del cliente normal de main

Fecha: 2026-11-06

## Qué aporta I6
- Compila APK Flutter `debug` **normal**, paquete `es.vencira.vencira`, no una variante G8/G12/G13/G15.
- Ejecuta las pruebas Flutter `android_web_access_screen_test.dart` y `device_notice_startup_gate_test.dart`.
- Instala APK en un emulador Android API 35 desechable (Google APIs, x86_64), la arranca y examina la jerarquía de accesibilidad real mediante `adb uiautomator dump`.
- Exige ver la pantalla `Acceso seguro a VENCIRA` y la opción `Abrir VENCIRA en el navegador`, sin convertir la aplicación ordinaria en un emisor de sesiones MFA.
- Toma captura PNG de la pantalla (contenido sintético de acceso), disponible durante tres días como artifact GitHub Actions.
- Guarda la APK DEBUG sin publicación durante siete días en artifacts de GitHub Actions para instalación manual posterior en teléfono del usuario. Los artifacts están vinculados al workflow, no forman parte del repositorio ni de una distribución autorizada.

## Precauciones
- Un PASS en emulador no equivale a PASS en Android físico: faltan permisos/restricciones del fabricante, acción externa de abrir navegador, revocación de alarmas tras reinicio y aceptación visual manual.
- No se habilitan credenciales nativas, MFA real, acceso a adjuntos ni migraciones persistentes.
- No se usa `dev.vencira.es` en las pruebas del emulador; la pantalla muestra una URL de acceso web, pero el test no la abre.
- La APK debug no debe distribuirse como release; sigue sin firma de distribución, revisión de Play Store ni autorización operativa.

## Estado
`I6_ANDROID_EMULATOR_RESULT=PENDING`. PR en borrador hasta observar CI `success` para este HEAD.

`MFA_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
