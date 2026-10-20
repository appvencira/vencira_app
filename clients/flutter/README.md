# Flutter — VENCIRA

Cliente **de solo lectura** del primer panel real de datos para la API Django, con inyección de repositorio simulado exclusivamente en tests.

## Qué existe

- Peticiones HTTP GET a `/api/v1/workspaces/` y `/api/v1/workspaces/{id}/renewals/?page=N`.
- Selector de organización; lista de vencimientos y paginación.
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

Para probar la navegación web, genera primero los proyectos host con una instalación local de Flutter estable:

```bash
flutter create --platforms=web .
flutter run -d chrome
```

**Limitación importante:** el servidor de desarrollo de Flutter usa normalmente otro origen/puerto distinto a Django, por lo que la sesión de Django no se comparte. Verás un error de carga, no la API autenticada. Esto es normal y no se soluciona abriendo CORS indiscriminadamente ni exponiendo cookies entre dominios.

La **integración real de navegador** requerirá configurar un proxy *same-origin* en un entorno local aislado: el mismo `https://host/` debe servir Flutter y enrutar `/api/` y `/accounts/` a Django. Todavía **no existe** ese proxy ni hay despliegue. No emplear `vencira.es` para pruebas con datos de usuarios.

En Android/iOS/desktop hace falta un mecanismo de autenticación nativo revisado (OAuth/OIDC con PKCE o equivalente), almacenamiento seguro de tokens y cierre de sesión. El prototipo actual NO lo implementa y no debe considerarse listo para móvil.

## Próximos desarrollos

- Autenticación web endurecida, limitación de intentos, MFA.
- Proxy local de integración para comprobar cookies de sesión y CSRF.
- Pantallas de alta/edición tras diseñar auditoría y permisos comerciales.
- Accesibilidad, internacionalización ES/EN, filtros y métricas fiables de negocio.
- Configuración host para las plataformas y builds firmadas, sin publicar todavía.
