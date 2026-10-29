# Flutter — VENCIRA

Cliente Flutter de **consulta, alta y edición de vencimientos** mediante API Django en mismo origen, con datos sintéticos exclusivamente en tests.

## Qué existe

- Peticiones GET de organizaciones y vencimientos; POST/PATCH con formulario validado y CSRF obtenido de `/api/v1/csrf/`.
- Selector de organización; lista de vencimientos y paginación. Se presentan por separado el vencimiento y el límite contractual de preaviso cuando viene informado; nunca se infiere.
- Estado de carga, error y sesión caducada, enlace al formulario Django, cierre de sesión con POST/CSRF, editor con calendario de fechas y estados.
- No conserva contraseñas, tokens ni cookies explícitamente; delega la sesión en el navegador.
- Pruebas de contrato HTTP y widget tests con datos de prueba falsos.

## Cómo probar sin usar datos reales

```bash
cd clients/flutter
flutter pub get
flutter analyze
flutter test
```

Para compilar Flutter Web, ahora existe `web/index.html`:

```bash
flutter build web --release --pwa-strategy=none
```

Hay un **proxy Nginx local opcional** en `compose.web.yaml` para servir el cliente y Django desde el mismo origen `http://127.0.0.1:18732`, evitando problemas de cookies entre puertos y CORS. Instrucciones completas en [WEB_LOCAL.md](../../docs/WEB_LOCAL.md). Si ejecutas `flutter run -d chrome` directamente, usa otro origen y el flujo autenticado no funcionará como en el proxy. No emplear `vencira.es` para pruebas con datos reales.

En Android/iOS/desktop hace falta un mecanismo de autenticación nativo revisado (OAuth/OIDC con PKCE o equivalente), almacenamiento seguro de tokens y cierre de sesión. El prototipo actual NO lo implementa y no debe considerarse listo para móvil.

## Próximos desarrollos

- Autenticación web endurecida, limitación de intentos, MFA.
- Proxy local de integración para comprobar cookies de sesión y CSRF.
- Mejorar permisos comerciales granulares, validación de negocio, accesibilidad y flujos de edición.
- Accesibilidad, internacionalización ES/CA (castellano y catalán), filtros y métricas fiables de negocio.
- Configuración host para las plataformas y builds firmadas, sin publicar todavía.

La primera demo instalable en servidor está documentada en [SERVER_PREVIEW.md](../../docs/SERVER_PREVIEW.md). No requiere Flutter SDK en el host si se construye mediante Docker.

## Identidad visual y apariencia

- El cliente arranca con `ThemeMode.system`, y `VenciraTheme` define de manera centralizada los temas Material 3 claro y oscuro.
- Todas las pantallas nuevas deben usar `Theme.of(context).colorScheme` en lugar de colores fijos.
- **Pendiente:** selector visible Sistema/Claro/Oscuro, persistencia por usuario y sincronización de preferencias entre dispositivos.
- Iconos de Flaticon: pendientes de seleccionar y licenciar; mantener un registro de atribución y no reutilizar recursos no autorizados. No se han añadido activos externos al repositorio.
- **Pendiente:** internacionalización real de widgets, mensajes y fechas con catálogos ES/CA. No confundir documentación o preparación con soporte multilingüe ya implementado.

Ver las incidencias #2 (idiomas) y #3 (identidad visual y temas).
