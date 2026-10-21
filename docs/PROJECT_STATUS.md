# Estado del proyecto VENCIRA — actualizado 21/10/2026

**Último hito:** VPS de desarrollo IONOS creado en España con Ubuntu 24.04, 4 vCore, 8 GB y 240 GB NVMe, IP 93.93.112.172. **Pendiente conexión SSH y despliegue en ese VPS; la preview local de Ubuntu sí funciona** según confirmó el usuario. Ver `docs/VPS_IONOS.md`. La indicación anterior de no contratar VPS ha quedado superada por este hito.

Bootstrap de código y primeras integraciones, todavía en **PR borrador**, sin despliegue ni datos reales.

- Nombre VENCIRA y repositorio privado exclusivo `appvencira/vencira_app` confirmados.
- Dominio `vencira.es`: pedido OVHcloud del 20/10/2026 por 7,25 € con IVA; justificante en estado «Validando...», pendiente de activación final.
- Correo previsto `soporte@vencira.es`, aún no configurado.
- Backend: modelos mínimos, pruebas y health/readiness; API v1 de vencimientos limitada por pertenencia a organización, con sesiones web y CSRF.
- Tests backend SQLite y PostgreSQL 17: superados en la ejecución anterior.
- Flutter: interfaz de consulta de organizaciones y vencimientos mediante API; lista paginada, estados de sesión, cambio de organización y pruebas de contrato/widget. **Proxy de mismo origen añadido para pruebas locales con Nginx; la prueba HTTP autenticada E2E está en CI y las pruebas visuales reales de navegador continúan pendientes**.
- Envío de avisos, alta/edición web, MFA, límites adicionales por IP y seguridad de login Admin, RGPD, copias externas y producción: pendientes.
- No comprar VPS hasta necesitar pruebas externas o despliegue real.

Documentación: `docs/API_MVP.md`, `docs/WEB_LOCAL.md` y `clients/flutter/README.md`. CI anterior de compilación web e integración same-origin: superada. CI del refuerzo de login y candidatos internos: superada (27 tests en SQLite y PostgreSQL, además de Flutter y web).

- Login provisional: límite por cuenta HMAC persistido en BD, 5 fallos/15 minutos -> bloqueo 15 minutos. Sin MFA ni protección frente a abuso distribuido.

- Base de avisos: reglas inactivas por defecto, candidatos futuros deduplicados y conciliación manual por organización. **Nunca envía mensajes**.

- Auditoría API v1: eventos de creación y cambios de vencimientos registrados en la misma transacción, sin conservar valores de referencias de clientes. Cobertura limitada a API v1, sin salida pública. Ver `docs/AUDIT.md`.
- Reglas comerciales: opciones y dudas documentadas en `docs/REMINDER_RULES_DRAFT.md`; sin aprobación de parámetros comerciales ni entregas reales.
- CI del registro de auditoría: superada con 34 tests SQLite + 34 PostgreSQL, y Flutter/Web.

- Se añaden fecha opcional de límite contractual de preaviso, base de regla seleccionable y visualización Flutter separada. No se infieren plazos legales ni cambian reglas de destinatarios. CI de código y pruebas de esta revisión: 43 tests en SQLite y 43 en PostgreSQL, Flutter y Nginx-Django, todo correcto en GitHub Actions #35. Consultar siempre el estado del último commit antes de fusionar.

## Preparación de primera prueba en servidor — 21/10/2026

- Frontend Flutter Web con **alta/edición de vencimientos**, validación de fechas y cierre de sesión.
- Django ofrece un endpoint CSRF de mismo origen y mantiene la autorización por organización y auditoría de escrituras.
- `compose.preview.yaml` compila Flutter dentro de Docker y levanta una preview independiente `vencira_preview`, solo puertos 127.0.0.1:18731/18732.
- Comando `seed_preview` disponible exclusivamente en preview de desarrollo, crea una organización y seis vencimientos **ficticios**, además de credenciales de usuario sin privilegios.
- Guía y scripts en `docs/SERVER_PREVIEW.md`, `scripts/preview-up.sh`, `scripts/preview-seed.sh` y `scripts/preview-down.sh`.
- CI integra construcción del Docker de preview y smoke de login, alta, edición y logout sobre los servicios reales. Ver último workflow de la PR antes de utilizar.
- **No desplegado en el servidor del usuario** por falta de acceso SSH desde las herramientas disponibles. No se ha contratado VPS ni cambiado DNS.

## Primera prueba real en Ubuntu — 21/10/2026 (información del usuario)

- El usuario confirma clonado y arranque de la preview en su servidor Ubuntu, último commit y acceso desde navegador. No existe acceso SSH remoto desde el conector de GitHub, por tanto no se atribuyen verificaciones de navegador no ejecutadas.
- Se diagnosticó un error CSRF de login con `Origin: null` y se corrigió la política `Referrer-Policy` de Nginx para permitir formularios HTML del mismo origen sin desactivar CSRF. GitHub Actions #49 validó los servicios y la cabecera.
- **Próxima aceptación manual:** confirmar login, visualizar seis registros sintéticos, crear, editar, filtrar, cerrar sesión.
- Se incorpora API y UI de búsqueda por referencia y filtro por estado, con aislamiento multi-organización y pruebas. Los filtros no modifican datos ni notifican.
- La PR de trabajo sigue en borrador, sin fusionar con `main` ni despliegue público. Los datos de prueba no deben contener clientes reales.

### Procedimiento de aceptación — filtros web

1. Actualizar rama de preview con `git pull --ff-only origin chore/bootstrap-vencira` y reconstruir el contenedor web y API (ver `scripts/preview-up.sh`).
2. Acceder como `vencira_demo` por `http://127.0.0.1:18732/`, solo con datos ficticios.
3. Buscar una referencia parcial, cambiar estado, comprobar que limpiar filtros devuelve la lista completa y que paginación preserva filtros.
4. Crear una referencia DEMO, editarla y cerrar sesión. Confirmar que no hay fuga entre organizaciones ni envíos de avisos.

Nota: la primera prueba manual del navegador sigue siendo necesaria; CI no sustituye al uso real.
