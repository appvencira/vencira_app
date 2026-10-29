# Protección del login — fase de desarrollo

- `ProtectedLoginView` aplica un contador para cada identificador normalizado, clave HMAC derivada del secreto de Django.
- **Cinco fallos en quince minutos** producen bloqueo de quince minutos y HTTP 429 (también para usuarios inexistentes); el éxito limpia los intentos previos.
- Estado almacenado en la BD para compartir entre workers. No se guardan contraseñas ni nombres de usuario en este contador.
- Se evita usar `X-Forwarded-For` sin cadena de proxies de confianza: no hay protección por IP todavía.
- Restricción: un atacante que conozca el nombre puede provocar temporalmente denegación de acceso; se requiere defensa de abuso en el proxy, monitorización y proceso de recuperación.
- Django Admin **no hereda este limitador**; sigue inaccesible desde la fachada Nginx de desarrollo, pero no debe publicarse mientras no se proteja.
- Registros caducados: necesita rutina de limpieza con política de retención validada antes de producción.
- MFA/passkeys, sesiones móviles, token rotation y riesgo de abuso distribuido siguen pendientes.

La prueba automatizada cubre cuenta real, otra cuenta independiente, inexistente, bloqueo, expiración y acceso correcto. **No autoriza un despliegue público ni el uso de datos reales**.
