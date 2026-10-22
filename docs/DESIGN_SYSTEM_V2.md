# VENCIRA — Dirección visual V2 (2026-10-22)

**Aprobación solicitada por usuario:** estética «brutal» de producto profesional, no formulario CRUD administrativo. La interfaz actual mostraba botones de tamaños heterogéneos y numerosos dropdowns encima de los registros. La prioridad es rediseñar **navegación, densidad, jerarquía, calendario y editor**, no solo la paleta.

## Investigación externa (referencias visuales, NO copiar activos)
- https://dribbble.com/search/flutter-calendar — conceptos y exploración visual, propuesta del usuario.
- https://dribbble.com/shots/26656195-Unify-Calendar-App-Design — semana/mes compacto, agenda por tarjetas.
- https://dribbble.com/shots/26857640-Task-Management-App-Calendar-page-design — fechas protagonistas, eventos de lectura rápida.
- https://dribbble.com/shots/24385435-Dashboard-Mindall-CRM — mezcla de agenda y fichas CRM.
- https://dribbble.com/shots/17719078-Responsive-UI — jerarquías consistentes para paneles de productividad.
- https://www.notion.com/es-es/product/calendar — reducción de ruido, fecha y planificación protagonistas.
- https://flexibits.com/fantastical-ios/help/calendar-views — DayTicker vinculado a agenda, gestos entre días.
- https://saasinterface.com/pages/calendar/ — galería de calendarios SaaS.
- https://www.saasui.design/ — patrones de producto SaaS real.
- https://mobbin.com/ — flujos de aplicaciones publicadas (algunos ejemplos requieren cuenta).
- https://adminlte.io/blog/saas-dashboard-design-examples/ — referencias comparativas: Linear (sobriedad), Stripe (datos), Vercel (economía cromática).

**Criterio:** referencias conceptuales solo para inspiración; validar con UX de aplicaciones reales, accesibilidad y estado real de desarrollo. No incluir imágenes o fragmentos licenciados ajenos en VENCIRA.

## Diseño objetivo

1. **Inicio orientado a decisiones:** entidad activa compacta; máximo dos acciones visibles de alto nivel («Agenda» y «Añadir»); a continuación registros/recuento. Evitar un bloque de navegación como contenido dominante.
2. **Descubrimiento progresivo:** filtros avanzados y administración de catálogos en paneles plegables; en escritorio pueden permanecer expuestos filtros apropiados.
3. **Agenda diaria primero:** fechas y registros por delante de filtros. Navegación de fechas rápida; filtros secundarios plegados en móviles.
4. **Calendario mensual limpio:** celdas de tamaño acotado; marcado semántico de vencimiento, preaviso y aviso; contraste marcado del día presente; evitar mosaico de cajas grises.
5. **Fichas y editor:** datos agrupados por identidad, póliza y calendario; no convertir toda la pantalla en una única lista interminable. Próxima fase: editor móvil a pantalla completa o formulario seccionado y ficha resumen con acciones fijas.
6. **Sistema visual:** color primario petróleo/azul corporativo; semántica roja para vencimientos, tercer color para preaviso, superficies sin recuadros redundantes; tamaños táctiles >=48 lógico; modos claro/oscuro y ca/es.
7. **Responsivo:** 320/375/768/desktop, texto largo y escalado, teclado y scroll, sin overflow ni ocultar acciones cruciales.

## Cambios V2 implementados en rama integración (NO verificados en Flutter, NO desplegados)
- `a067d60d` + `85507535`: `dashboard_screen.dart`; cabecera más compacta, entidad única como rótulo, fila simétrica Agenda/Añadir, catálogos plegables para propietario, filtros plegables en móvil y accesibles en escritorio. Preserva IDs/semántica de filtros.
- `e734502b`: `day_agenda_screen.dart`; filtros diarios plegables en móvil, mejor jerarquía de fecha, sin alterar el contrato de calendario.
- `20f15763`: `month_agenda_screen.dart`; cuadrícula más ligera y compacta, mantiene estados y marcas.

## Validación obligatoria antes de desplegar
- Flutter `pub get`, `flutter analyze`, `flutter test`, `flutter build web --release --pwa-strategy=none`.
- Comprobar pruebas de filtros y multi-workspace en 800/1024 y render sin overflow a 320, 375, 768; vista mensual con días con múltiples marcas.
- Solo si todo pasa: verificar checkout/proyecto `vencira_localcheck`, actualizar exclusivamente `web_preview`, esperar healthcheck y rutas HTTP 200; preservar `vencira_preview`, API y PostgreSQL.
- Validez visual aún pendiente: capturas Android de inicio, agenda diaria, mes y formulario; recoger fallos y no dar por aprobado solo por pasar tests.
- Documentar resultados completos en `docs/CONTINUITY_RUNBOOK.md` y continuar con editor/ficha una vez validado este pase.

## Flujo de trabajo
Todos los cambios y descubrimientos han de estar documentados para nuevos chats. El asistente realiza código/inspección en GitHub; cuando se necesite servidor enviar **un único script integral por fase**, nunca cerrar SSH ni mostrar secretos. No usar GitHub Actions (cuota agotada). Datos reales prohibidos hasta revisión seguridad/RGPD.
