# VENCIRA — Matriz de control visual y responsive

Fecha: 22/10/2026. Alcance de la rama `feat/flutter-preferences-i18n` (PR #4).
No contiene capturas de pantalla ni equivale a una revisión manual aprobada.

## Requisitos transversales

- Castellano y catalán deben mostrar todas las etiquetas existentes en Flutter sin cadenas mezcladas.
- Apariencia: Sistema (sigue los cambios del dispositivo), Claro y Oscuro; contrastes correctos.
- Flaticon es el origen previsto de iconografía, pero los recursos no están añadidos sin licencia y atribución verificadas.
- Referencias reales de pólizas, nombres y documentos personales están prohibidos en preview y pruebas.
- Mantener foco/teclado, semántica de controles, contraste y estados de error.

## Matriz

| Ancho CSS lógico | Idioma | Tema | Prueba principal |
|---|---|---|---|
| 320 px | ca | oscuro | Etiquetas largas, filtros y ficha; sin RenderFlex overflow |
| 375 px | ca | oscuro | Navegación, menú preferencias y scroll |
| 768 px | ca | oscuro | Adaptación intermedia, separación de tarjetas |
| 320 px | es | claro | Panel, editor de vencimiento y menú |
| 375 px | es | sistema | Cambio de brillo en marcha |
| 1440 px | es/ca | claro/oscuro | Aprovechamiento del espacio y límites máximos |
| 320 px con fuente 200 % | es/ca | claro/oscuro | Accesibilidad, botones, diálogos y campos |

## Evidencia automática

- El workflow `.github/workflows/flutter-i18n.yml` valida catálogos, gen-l10n, análisis, widget tests y compilación web.
- Los widgets tests de anchura `320/375/768` ejercitan el tema oscuro, traducciones catalanas y una anotación sintética con referencia larga.
- **Limitación:** un widget test detecta errores de layout/renderizado en esos escenarios, pero **no sustituye** una revisión humana de legibilidad, contraste, ergonomía o aspecto premium.

## Revisiones manuales pendientes antes de integrar o desplegar

1. Entrar con usuario sintético en preview y recorrer agenda, filtros, editor y preferencias.
2. Cambiar a catalán; comprobar alertas, validaciones y estados `pending/contacted/closed` sin traducir los valores de API.
3. Comprobar ambos temas y la reacción en modo Sistema; recargar y verificar persistencia.
4. Probar teclado y lector de pantalla; comprobar que iconos poseen tooltip o etiqueta accesible.
5. Revisar escala de texto 200 %, referencias largas y tamaño del editor en móvil.
6. Confirmar aislamiento de datos cuando se cambia de organización (sin datos reales).
7. Registrar captura/reporte aprobado y commit exacto; solo entonces marcar la revisión visual finalizada.

## Bloqueantes de producto independientes de esta PR

- Permisos por anotación de miembros del equipo no están acabados; no usar información real.
- Autenticación nativa para Android/iOS pendiente.
- Acceso offline/sincronización, notificaciones y archivo RGPD pendientes.
- Selección/licencia efectiva de iconos Flaticon pendiente.

## Enlaces

- PR #4: https://github.com/appvencira/vencira_app/pull/4
- Seguimiento idiomático: https://github.com/appvencira/vencira_app/issues/2
- Sistema de diseño: https://github.com/appvencira/vencira_app/issues/3
- Guía detallada: `docs/FLUTTER_LOCALE_THEME.md`

## Historial de validación responsive (22/10/2026)

- [Workflow #9](https://github.com/appvencira/vencira_app/actions/runs/39716146403): **fallo real detectado** en las pruebas a 320 px (RenderFlex +131 px) y 375 px (+76 px); 768 px correcto. Análisis de Dart, generación de idioma y catálogos correctos. Ese resultado **no debe declararse verde**.
- Correcciones posteriores: campo de búsqueda y filtro dimensionados por `LayoutBuilder`; ficha con chip en el subtítulo y edición compacta; cabecera con botón de salida solo iconográfico (tooltip); selector de organización `isExpanded` con elipsis.
- Pruebas anteriores ajustadas para identificar salida por tooltip accesible.
- [Workflow #12](https://github.com/appvencira/vencira_app/actions/runs/39716446445): repetición automática de la suite. **Pendiente de resolución cuando se añadió este registro**. Anotar resultado final posteriormente.
