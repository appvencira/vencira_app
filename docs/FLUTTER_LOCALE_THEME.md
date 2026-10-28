# Implementación ES/CA y apariencia — VENCIRA

**Estado:** rama experimental `feat/flutter-preferences-i18n`; PR borrador #4. **No fusionar ni desplegar sin las verificaciones indicadas.**  
**Fecha:** 22/10/2026. Documento base: whitepaper de agenda de vencimientos externos, 18/10/2026.  
**Entorno actual del VPS:** continúa con `chore/bootstrap-vencira` en el último despliegue confirmado; no se actualiza como parte de esta rama.

## Objetivo y decisiones

1. Dos idiomas iniciales de la v1: **es** (castellano) y **ca** (catalán), según el whitepaper. Las etiquetas visibles se traducen; los códigos de la API (`pending`, `contacted`, `closed`) **no**.
2. Tres apariencias: `ThemeMode.system` (predeterminada), `light` y `dark`. Cambiar el tema no debe invalidar la sesión ni vaciar la lista.
3. Todos los elementos nuevos deben utilizar el sistema de diseño `lib/ui/vencira_theme.dart` y los catálogos ARB; no copiar colores fijos ni textos de estado al almacenamiento.
4. Los iconos Flaticon se usarán **solo después** de verificar derechos de distribución y atribución. Actualmente no se han añadido sus activos.
5. La preferencia local no sustituye a una futura sincronización autenticada de preferencias por usuario.

## Archivos y contratos

- `lib/l10n/app_es.arb` y `app_ca.arb`: catálogos de mensajes.
- `l10n.yaml`: configuración de `gen-l10n`; `flutter.generate: true` en `pubspec.yaml`.
- `lib/main.dart`: selección de `Locale`, delegados de localización, `ThemeMode`, restauración y persistencia en `SharedPreferences`.
- `lib/ui/vencira_preferences.dart`: estado y callbacks de presentación compartidos con las pantallas.
- `lib/ui/vencira_theme.dart`: `ThemeData` Material 3 centralizados para claro/oscuro.
- `lib/ui/dashboard_screen.dart` y `renewal_editor.dart`: uso progresivo de mensajes localizados.
- `test/widget_test.dart`: pruebas de cambio de idioma/tema y regresión funcional existente.

Valores de almacenamiento local (no sensibles):
- `vencira.ui.locale.v1`: `es` o `ca`; desconocido → `es`.
- `vencira.ui.theme.v1`: `system`, `light` o `dark`; desconocido → `system`.

El cliente elige por defecto castellano. **Decisión futura**: considerar detección inicial del idioma del dispositivo, siempre restringida a idiomas soportados, y definir preferencia remota por cuenta.

## Cómo validar en un equipo con Flutter

Desde la raíz del repositorio, usando esta rama:

```bash
cd clients/flutter
flutter --version
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none
```

Criterios de aceptación:
- La aplicación arranca en español sin lanzar excepciones.
- Seleccionar Català traduce la cabecera, editor, filtros y mensajes; volver a español restaura sus etiquetas.
- Modo Sistema reacciona al sistema operativo; Claro y Oscuro fuerzan la apariencia.
- Las opciones persisten tras recarga y no modifican la organización seleccionada ni el estado de autenticación.
- No se produce overflow en anchuras estrechas, con fuentes grandes o etiquetas catalanas.
- `flutter analyze`, `flutter test` y `flutter build web` finalizan sin errores; verificar informe CI del commit exacto antes de fusionar.

**Situación de pruebas a 22/10/2026:** en la sesión de edición con GitHub no se dispone del ejecutable `flutter` ni de `dart`. Se han revisado claves ARB y código estáticamente, pero **no se atribuye estado verde a CI ni a pruebas no ejecutadas**.

## Limitaciones actuales

- Persistencia **por dispositivo y navegador**, no por cuenta; en equipos compartidos las preferencias pueden ser comunes al perfil del navegador.
- Formularios de acceso Django y mensajes devueltos por backend requieren catálogo propio; Flutter solo controla su interfaz.
- Las fechas visibles de agenda/editor usan `intl.DateFormat('dd/MM/yyyy', locale)`; la API conserva las fechas ISO y nunca debe convertir una fecha contractual a otro día por zona horaria. Pendiente extender esta estrategia a avisos, emails y exportaciones.
- La v1 final deberá contemplar pluralización, género, accesibilidad, notificaciones, emails, exportaciones y futuras pantallas completas.
- Los estados de dominio y cierres deben redefinirse con arreglo al whitepaper en una migración aparte, no en esta PR.
- Ningún dato real de clientes ni cambios de BD participan en este bloque.

## Integración y despliegue seguro

1. Revisar cambios de PR #4 contra `chore/bootstrap-vencira` y comprobar versiones de Flutter/paquetes.
2. Ejecutar las tres comprobaciones de Flutter y pruebas visuales ES/CA claro/oscuro; corregir fallos.
3. Registrar evidencia de CI. Fusionar solo tras aprobación técnica.
4. En VPS: `git fetch`, verificar rama/commit y trabajar con respaldo de la versión desplegada.
5. Reconstruir **solo el servicio web_preview** con Compose del proyecto `vencira_preview`; Django y DB no precisan cambios de esta PR.
6. Validar login, logout, anotaciones sintéticas y cabeceras HTTPS con Caddy; rollback reconstruyendo la versión anterior si hay incidencia.
7. Documentar commit desplegado, fecha, resultado de smoke, pruebas de idiomas/temas y posibles incidencias en `docs/PROJECT_STATUS.md`.

**No ejecutar automáticamente el paso 5** por el mero hecho de que una rama exista. No subir claves, contraseñas ni hash de Basic Auth.

## Trazabilidad

- Whitepaper: sección 13, idiomas y recursos traducibles.
- [Issue #2](https://github.com/appvencira/vencira_app/issues/2): ES/CA.
- [Issue #3](https://github.com/appvencira/vencira_app/issues/3): diseño, temas y Flaticon.
- [PR #4](https://github.com/appvencira/vencira_app/pull/4): implementación en revisión.
- `docs/PRODUCT_DECISIONS.md`: acuerdos transversales y asuntos aún pendientes.

## Verificación automática incorporada

- Workflow GitHub Actions: `.github/workflows/flutter-i18n.yml`.
- Disparo: PR hacia `chore/bootstrap-vencira` con cambios en Flutter o scripts de i18n; también `workflow_dispatch`.
- Ejecuta: verificador de ARB → instalación Flutter estable → dependencias → generación l10n → análisis → pruebas → compilación web.
- Primer run: [Flutter ES-CA validation #1](https://github.com/appvencira/vencira_app/actions/runs/39687941162). **La ejecución inicial fue iniciada, pero su resultado aún no estaba disponible al documentar esta revisión.**
- La prueba de validación de estructura de catálogos terminó correctamente en el primer run; no confundir este paso con aprobar toda la compilación.
- La revisión estática detectó 58 claves traducibles por idioma, sin nombres de claves divergentes ni referencias faltantes en dashboard y editor.

## Validación ejecutada — 22/10/2026

**GitHub Actions [Flutter ES-CA validation #3](https://github.com/appvencira/vencira_app/actions/runs/39688278246)** sobre commit `da3afd6788ad1ccfa2ef61d587f393c21d54772e`.

- Catálogos ARB ES/CA: **superado**.
- Instalación Flutter y dependencias: **superada**.
- `flutter gen-l10n`: **superado**.
- `flutter analyze`: **superado**.
- `flutter test`: **superado**.
- `flutter build web --release --pwa-strategy=none`: **superado**.

La primera ejecución falló por una prueba de brillo que cambiaba el valor simulado pero no disparaba la notificación a widgets. Corregida en commit `da3afd6` usando `tester.binding.handlePlatformBrightnessChanged()`; las pruebas se han repetido con éxito.

**Alcance:** CI acredita compilación, tests y análisis del cliente, no revisión visual real en navegador, autenticación móvil ni preparación para producción. Mantener PR #4 como borrador hasta inspección visual y aceptación de integración.

## Refuerzo de integración y usabilidad — 22/10/2026

- Se han añadido casos de prueba para recuperar las preferencias `ca/dark` y aplicar fallback `es/system` ante valores almacenados desconocidos (`test/widget_test.dart`).
- La paginación en el panel usa `Wrap` para que los controles puedan saltar de línea en tamaños estrechos; no garantiza por sí solo ausencia de overflow en toda la pantalla.
- Ejecución de CI posterior a estos cambios: [workflow #6](https://github.com/appvencira/vencira_app/actions/runs/39688991620). **No marcar completado hasta ver su resultado.**
- Inspección visual real pendiente: 320/375/768/1440 px, zoom y escala de texto 200 %, ES y CA, Claro/Oscuro/Sistema, teclado, avisos y formulario de edición; verificar explícitamente que no aparecen datos de una organización distinta durante transiciones.
- Servidor HTTPS privado y BD quedan intactos hasta cerrar PR #4 y aprobar despliegue.

## Consolidación responsive y fechas — 22/10/2026

- CI de la mejora móvil [run #12](https://github.com/appvencira/vencira_app/actions/runs/39716446445): los tests de anchura 320/375/768, el análisis estático y la estructura de catálogos figuran superados al actualizar esta sección; verificar el resultado global de build antes de considerar este run completo.
- Se ha sustituido el formato manual de fechas en `dashboard_screen.dart` y `renewal_editor.dart` por `intl.DateFormat` con locale activo. El formato visible se mantiene `dd/MM/yyyy` para ES y CA, sin modificar valores del backend.
- CI de la actualización de fechas: [run #14](https://github.com/appvencira/vencira_app/actions/runs/39716620036). No asumir éxito hasta comprobarlo.
- Matriz de pruebas visuales y evidencia: `docs/FLUTTER_VISUAL_QA.md`.
