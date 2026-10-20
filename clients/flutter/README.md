# Flutter — VENCIRA

Cliente **de solo lectura** del primer panel real de datos para la API Django, con inyección de repositorio simulado exclusivamente en tests.

## Qué existe

- Peticiones HTTP GET a `/api/v1/workspaces/` y `/api/v1/workspaces/{id}/renewals/?page=N`.
- Selector de organización; lista de vencimientos y paginación. Se presentan por separado el vencimiento y el límite contractual de preaviso cuando viene informado; nunca se infiere.
- Estado de carga, error y sesión caducada, con enlace al formulario Django.
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
- Pantallas de alta/edición tras diseñar auditoría y permisos comerciales.
- Accesibilidad, internacionalización ES/EN, filtros y métricas fiables de negocio.
- Configuración host para las plataformas y builds firmadas, sin publicar todavía.
