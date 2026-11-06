# I2-C — Consolidación Flutter Web/Android hacia main

## Origen, alcance y preservación
- `main` base: `6375f92dd62e4d44c6d1545af65cf65c77118d7b`, posterior a backend I2-B2.
- Fuente: árbol completo `clients/flutter` del commit `2b770626baa98deccbcde1c79e69679447d9a304` de la rama avanzada.
- Incorporados **146 archivos versionados** desde la fuente a una rama nacida de `main`.
- Se conserva sin sobreescribir el archivo **exclusivo de main** `clients/flutter/lib/ui/control_assessment_card.dart`. El origen tiene otra versión; esta decisión requiere análisis/compilación para detectar incompatibilidades de API y pruebas visuales posteriores.
- Incluye `pubspec.yaml`, `lib/main.dart`, catálogos ES/CA, biblioteca API/UI, notificaciones, configuración Web/Android y pruebas. No se crea un cliente nuevo.

## Límites
- Se versionan también laboratorios G8/G12/G13/G15 y componentes nativos **como código aislado**; no se ejecutan por arranque ordinario. Las variantes Android usan entrypoints y variables de build específicos.
- La app Android normal no usa el emisor MFA test-only: conserva la pantalla de acceso Web existente como fallback. La app móvil operativa requiere integración nativa adicional y sus autorizaciones.
- La configuración Gradle debe **rechazar** firma release sin keystore externo; ningún archivo de claves forma parte de esta PR.
- No se añade ningún endpoint operativo, ni se modifica Caddy, `dev.vencira.es`, ni una BD persistente.
- `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Validación obligatoria antes de fusionar
GitHub Actions `.github/workflows/i2c-flutter-client.yml` ejecuta: `flutter pub get`, `flutter analyze`, regresión dirigida de widgets/contratos y `flutter build web --release --pwa-strategy=none`, sin desplegar. **No considerar PASS antes de recibir resultado del workflow o runner equivalente para este HEAD.**

Se recomienda ejecutar en un checkout temporal:
```bash
cd clients/flutter
flutter pub get
flutter analyze
flutter test test/widget_test.dart test/control_assessment_test.dart test/vencira_api_test.dart test/android_web_access_screen_test.dart test/design_v3_test.dart test/renewal_editor_test.dart test/renewal_attachments_card_test.dart test/device_notice_startup_gate_test.dart
flutter build web --release --pwa-strategy=none
```
No ejecutar `flutter build apk --release` sin firma aprobada. La compilación Web no sustituye la aceptación Android real. GitHub Actions PASS no representa beta aprobada.

## Resultado de preparación
`I2C_STAGED=YES`; `I2C_TESTS=PENDING`; `I2C_MERGE=NO`. El objetivo es fusionar a `main` tras corregir cualquier incompatibilidad conservando la ficha de control de `main`.


## Reconciliación C2 — 06/11/2026

El primer workflow en HEAD 28b3e877 falló en dos regresiones de control_assessment_test.dart: el botón Crear aviso no se ocultaba cuando había un control activo y faltaba el aviso histórico completado. Flutter analyze y los otros 82 tests dirigidos fueron correctos; la compilación Web quedó omitida por el fallo.

Se incorporaron a la ficha original de main los controles de duplicación, la visualización del aviso histórico y el aviso de control ya existente, preservando el reintento idempotente. La corrección no modifica endpoint, base de datos ni despliegue.

NUEVO HEAD: pendiente CI (Flutter analyze, widgets y Flutter Web). No atribuir PASS al HEAD hasta comprobarlo. NO_DEPLOY_NO_LIVE_MIGRATION=1.
