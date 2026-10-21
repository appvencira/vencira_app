# VENCIRA — Decisiones de producto y arquitectura

Estado: documento de trabajo, actualizado 22/10/2026. Fuente funcional: whitepaper del 18/10/2026. No sustituye sus decisiones ni aprueba asuntos pendientes.

## Decisiones confirmadas

- La v1 es una agenda de pólizas **externas** para mediadores de seguros, no un CRM ni un programa de gestión de cartera propia.
- Idiomas iniciales: **español (es)** y **catalán (ca)**. Usar archivos de localización y códigos estables en API/BD; no almacenar etiquetas traducidas.
- Apariencia: **Sistema** por defecto, con opción de forzar **Claro** u **Oscuro**. El tema debe adaptarse sin reiniciar y la preferencia elegida debe persistirse por usuario.
- Diseño: Flutter Material 3, arquitectura de tema centralizado; iconografía preferentemente **Flaticon** con estilo unificado, licencia comercial verificada e inventario de atribuciones.
- Accesibilidad: no comunicar información solo mediante colores; etiquetas e iconos semánticos, contraste y tamaño táctil adecuados, soporte de teclado/lector de pantalla y diseño adaptable.
- Seguridad: aislamiento por cuenta, mínimos privilegios, registros de auditoría sin datos personales innecesarios, evitar datos reales en preview.
- El código de negocio debe representar Clientes/Candidatos y cuatro resultados de cierre conforme al whitepaper, no traducirlos en almacenamiento.

## Implementado hasta ahora (no confundir con terminado)

- Flutter `VenciraTheme.light/dark` y `ThemeMode.system` para respetar el tema del dispositivo. Sin selector persistente todavía.
- API y modelo inicial de organizaciones/vencimientos; no equivalen al modelo completo del whitepaper.
- Preview web HTTPS privado con Caddy, Django y PostgreSQL. No constituye producción.

## Pendientes prioritarios

1. Internacionalización completa ES/CA de Flutter, autenticación, errores API, notificaciones y futuras exportaciones; pruebas en ambos idiomas.
2. Selector y persistencia de apariencia e idioma; definir contrato entre dispositivo y preferencias de usuario.
3. Diseño y revisión de modelo Anotación y migración retrocompatible (Clientes/Candidatos, asignación, fechas, cierre), con validación y migraciones probadas.
4. Especificación detallada del motor de avisos: zonas horarias, cambios de hora, fechas de mes natural, idempotencia, cancelación y reintentos; sin envíos reales durante pruebas.
5. Diseño offline/sincronización: identificadores, versiones, cola de cambios y resolución explícita de conflictos antes de implementar un cliente sin conexión.
6. Permisos y privacidad: roles, exportaciones, archivo, retención y borrado sujetos a las decisiones pendientes y revisión jurídica.
7. Selección de recursos Flaticon, revisión de licencias, manifest/atribuciones y pruebas visuales claras/oscuras.
8. Pruebas automáticas: migraciones, autorización multicuenta, CSRF, temas, idiomas, accesibilidad y responsividad; validación manual antes de desplegar.

## Normas de implementación

- Separar dominio, UI y persistencia; widgets sin valores de color fijos o cadenas traducibles dispersas.
- No confundir estado interno con texto visible. Mantener contratos API neutrales al idioma.
- Cada cambio de esquema requiere migración reversible cuando sea viable, pruebas en bases vacías y pobladas, y plan de rollback.
- Nunca desplegar automáticamente sobre el VPS desde cambios parciales o sin CI verificada.
- Mantener fuera de Git secretos, tokens, certificados privados y recursos gráficos sin licencia confirmada.

## Documentos de seguimiento

- Issue #2: internacionalización ES/CA.
- Issue #3: diseño, temas e iconografía Flaticon.
- Whitepaper: especificación funcional y lista de puntos expresamente pendientes de aprobación.
