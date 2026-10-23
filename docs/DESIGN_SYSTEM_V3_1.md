# VENCIRA — pulido premium V3.1 (23/10/2026)

## Motivo y evidencia visual
Tras la validación V3 en Android, el usuario considera mucho mejor la estructura y las tarjetas, pero señala dos carencias concretas:
1. Los menús desplegables Material por defecto (Estado, Entrada, Modalidad, Aseguradora, Idioma/Apariencia y selección de organización) tienen un estilo pobre, especialmente los menús grandes que tapan otros controles.
2. Las etiquetas son demasiado neutras: Pendiente, Contactado y Cerrado deberían diferenciarse visualmente y mejorar el reconocimiento instantáneo, sin llenar toda la app de colores.

## Solución implementada en la rama `integration/local-e2e-prep`

- **Componente común** `clients/flutter/lib/ui/vencira_select.dart`: `VenciraSelect<T>` y `VenciraOption<T>`. Campo discreto con etiqueta + valor y un icono, alto mínimo de 62 dp, borde ausente, color `surfaceContainer`. Al abrir: **bottom sheet** con esquinas superiores redondeadas (26px), agarre, título contextual, cerrar, opciones de al menos 48dp, selección clara con `check_circle`, scroll a 78% de la altura con tope de 520px en escritorio. La elección y el evento `onChanged` viven en el widget padre, evitando nuevos estados inconsistentes. La lista puede incluir opciones desactivadas históricas; se mantiene accesible. No añade dependencias.
- **Estados** `VenciraStatusBadge` en el mismo archivo. `pending` → ámbar (`#FFEBC7/#815000` en claro); `contacted` → petróleo/azul (`#DBF2F8/#135D71`); `closed` → verde (`#DDF4E5/#246B43`). El modo oscuro usa parejas específicas de fondo y texto para contraste. Icono+texto acompañan color (no se depende del color únicamente); estado desconocido neutro.
- **Dashboard** `dashboard_screen.dart`: todos los filtros de Estado, Entrada, Modalidad y Aseguradora migrados a selector premium; controles a todo el ancho de móvil; selector de organización también migrado para uniformidad. Tarjetas de vencimientos muestran el nuevo estado.
- **Agenda diaria** `day_agenda_screen.dart`: los tres filtros se convierten en un selector premium de ancho completo en móvil; los eventos llevan estado semántico y chips con suave tinte rojo/terciario/primario según vencimiento/preaviso/aviso previsto.
- **Editor** `renewal_editor.dart`: campos Entrada, Modalidad, Aseguradora y Estado ahora usan el selector común. Modalidades activas y heredadas, aseguradora actual y opción "No definida" siguen siendo seleccionables. Estado en formulario conservado como datos, sin nuevas migraciones.
- **Ficha** `renewal_detail_screen.dart`: chip de estado semántico con icono.
- **Idioma/Apariencia** en dashboard: menú desplegable gris reemplazado por un **bottom sheet de ajustes**, separado por Idioma y Apariencia con opciones seleccionadas e iconos, manteniendo las preferencias ES/CA y Sistema/Claro/Oscuro.
- **Pruebas**: `clients/flutter/test/premium_components_test.dart` comprueba opciones y cambio en anchos 320/375 y temas claro/oscuro, y que los 3 estados usan tintes distintos. `clients/flutter/test/widget_test.dart` mantiene la prueba de cambio de organización contra el selector nuevo. Se preserva suite de editor y agenda.
- **Despliegue**: `scripts/validate_ui_v3_1.sh` es una evolución del script V3 validado: identidad Docker, trabajo Git limpio salvo lock generado, validación de Compose, Flutter `pub get`, `analyze`, tests premium y mes V3, suite completa, build release y despliegue **solo Web** tras todas las pruebas. Health API/DB/Web y cuatro respuestas HTTP 200; curl HTTPS externo informativo sin credenciales. Conserva SSH en caso de fallo.

## Criterios de aceptación
- En Android el menú Estado abre hoja compacta con "Todos / Pendiente / Contactado / Cerrado" y selección en color, sin lista gris flotante sobre campos.
- Igual para Entrada, Modalidad y Aseguradora, tanto en filtros de búsqueda como agenda diaria; no recortar textos largos.
- Idioma y tema funcionan y persisten sin recargar registros ni perder selección.
- Contraste de Pendiente/Contactado/Cerrado en claro y oscuro, con significado comunicado también por texto e icono.
- Pruebas sin overflow en 320/375/768px y sin pérdidas de filtros, autenticación o workspace.
- **Estado actual al documentar:** código preparado en GitHub, pendiente ejecutar tests del servidor y despliegue V3.1. No declararlo desplegado antes de obtener `RESULTADO_GLOBAL=0`.
- No tocar API/BD, ni `vencira_preview`. Datos reales prohibidos hasta puerta seguridad/RGPD.

## Flujo estable
El asistente implementa/documenta primero vía GitHub, envía una única ejecución completa en Ubuntu `vencira` y el usuario comparte el resultado consolidado. La documentación permanente está en `docs/CONTINUITY_RUNBOOK.md`. No GitHub Actions (cuota agotada). Si falla compilación/tests, corregir en GitHub y repetir **el mismo script**, nunca ejecutar el despliegue manualmente sin superar calidad. Revisar capturas Android tras el despliegue.
