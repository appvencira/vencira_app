# VENCIRA — Sistema visual V3 · edición de 22/10/2026

## Contexto y decisión de diseño
El usuario rechazó como poco profesional el exceso de bordes, selectores y botones; en capturas de Android destacó expresamente que las celdas del calendario mensual eran rectangulares, no cuadradas, y que los puntos de evento apenas coloreaban el día. El objetivo es un producto B2B cuidado y elegante, móvil primero, sin degradar funcionalidad ni accesibilidad.

Inspiración, **sin copiar activos ajenos**:
- [Notion Calendar](https://www.notion.com/product/calendar): planificación inmediata, baja distracción.
- [Fantastical, Calendar Views](https://flexibits.com/fantastical-ios/help/calendar-views): semana vinculada a agenda, indicadores por fecha, navegación fluida.
- [Linear — How we redesigned the UI](https://linear.app/now/how-we-redesigned-the-linear-ui): superficies sobrias, reducción de ruido, consistencia y jerarquía.
- [Vinçon, calendario minimalista](https://octagon-design.com/en-eu/products/vincon-best-wall-calendar-2026): cuadrícula ortogonal limpia con énfasis selectivo.
- [Dribbble, Flutter Calendar](https://dribbble.com/search/flutter-calendar): referencias aportadas por el usuario, solo inspiración.
- Más investigaciones y V2: [DESIGN_SYSTEM_V2.md](DESIGN_SYSTEM_V2.md).

## Sistema V3 (implementado en GitHub, pendiente de validar en servidor)

1. **Colores corporativos**: petróleo `#176D83`, superficies claras `#F7F9FB` / tarjetas blancas; oscuro `#0E151B` / tarjetas `#152129`. Color de texto y semántica se resuelven por `ColorScheme` para ambos temas.
2. **Controles**: campos de fondo tonal suave, sin recuadro gris permanente; anillo de foco 1,6px y errores bien visibles. Alturas y radios coherentes (14px controles; 20px tarjetas). Reducir bordes y ruido; mantener tamaño táctil de acciones >=48dp.
3. **Mes**: cuadrícula `childAspectRatio:1` (celdas cuadradas); al existir actividad **se colorea toda la celda** con tinta tonal transparente y borde suave, en claro y oscuro. Prioridad: **vencimiento (error rojo) > límite de preaviso (terciario) > aviso previsto (primario)**. En coincidencias, el color principal responde a esa prioridad y **se mantienen puntos de cada tipo/estado** para no perder significado; día actual con borde primario distinto.
4. **Leyenda del mes**: se ha movido a un panel plegable `month-legend` posterior al calendario para darle protagonismo a las fechas. No confundir avisos previstos con notificaciones enviadas.
5. **Semana diaria**: las columnas altas rectangulares se sustituyen por **días circulares** dentro de elementos táctiles, con estado seleccionado claro; se preserva la franja de 32px para las marcas y las teclas/gestos de navegación.
6. **Tarjetas de vencimientos**: jerarquía nombre/referencia, fecha, preaviso, entrada y estado; icono contenido en una superficie suave; edición como acción secundaria. Mantener textos exactos usados por pruebas y destino de edición.
7. **Editor**: sección de identificación, póliza y fechas con jerarquía y pequeños iconos; campos de teléfono/email con teclado apropiado, sin autofoco en móvil; diálogo de ancho adaptativo, fechas en botones de ancho completo. Respeta validaciones y la búsqueda manual de contacto existente.
8. **Ficha de anotación**: secciones independientes (contacto, póliza, fechas y notas), datos más legibles y estado visible arriba, en lugar de una lista indiferenciada.
9. **Internacionalización**: nuevos encabezados ES/CA se resuelven por locale; no modificar modelo, API, permisos, migraciones ni catálogo. Todo con datos sintéticos.
10. **Responsive**: probar 320, 375 y 768px en ambos temas, nombres largos y textos aumentados; prestar atención a desbordamientos en modales y marcas múltiples.

## Implementación de la rama (NO equivale a despliegue)
- `clients/flutter/lib/ui/vencira_theme.dart`: commit `224aeaf2`, corrección `3630a7d3`.
- `month_agenda_screen.dart`: `3628324a` y leyenda plegable `65d92436`.
- `day_agenda_screen.dart`: `af0ffae4`.
- `dashboard_screen.dart`: `a20e4671`.
- `renewal_editor.dart`: `b1ee9bfb`, ancho seguro `cb31a4f7`.
- `renewal_detail_screen.dart`: `5345c7ff`.
- Prueba `clients/flutter/test/design_v3_test.dart`: `cd4c0f43`, selector robusto `083741c3`; verifica celdas semánticas claras/oscuras, prioridad de vencimiento, puntos secundarios y forma redondeada cuadrada.
- Validación integral/rollout web: `scripts/validate_ui_v3.sh` creado en commit `6246a4a0`.

## Puerta de calidad antes de cualquier despliegue
**Estado a la escritura:** V3 aún NO validada en Flutter sobre servidor y NO desplegada. No afirmar éxito.

El asistente trabaja primero sobre GitHub, documenta decisiones, y solo entonces presenta al usuario **un único bloque**:
```bash
if (
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash scripts/validate_ui_v3.sh
); then echo EJECUCION_COMPLETADA=1
else echo EJECUCION_COMPLETADA=0
fi
echo CONSOLA_ABIERTA
```

Script protege la shell SSH (proceso hijo), revisa cambios versionados sin borrar artefactos locales, identifica Docker Compose **`vencira_localcheck`**, `flutter pub get`, `flutter analyze`, test V3 específico, todos los tests, build web release, build/deploy exclusivo de `web_preview` si pasan, health de API/BD/web y HTTP local 200. Una comprobación HTTPS externa solo informativa. **No usar GitHub Actions (cuota agotada); no tocar PostgreSQL, migraciones ni el stack `vencira_preview`.**

Una vez validado: recoger capturas Android de calendario, agenda, formulario, ficha y panel oscuro/claro y clasificar problemas. Actualizar `docs/CONTINUITY_RUNBOOK.md` con SHA, prueba, despliegue, limitaciones y siguiente fase. Producción/datos reales prohibidos hasta puerta seguridad y RGPD.

## Incidencias y validación de V3 (23/10/2026)

- Primera ejecución del script en Ubuntu: `flutter pub get` OK, `flutter analyze` falló con dos errores de sintaxis (`Expected to find ')'`) en `test/design_v3_test.dart:42:53` y `:52:57`. No se alcanzó la compilación web ni el despliegue.
- Causa: faltaban llaves de cierre `}` en los parámetros opcionales de los métodos simulados `fetchAgendaDay` y `fetchRenewalHistory`.
- Corrección `19ec2e8b` en GitHub. Próximo estado: **pendiente de repetir el script completo**; otros fallos que no llegó a detectar el analizador todavía no pueden descartarse.
- Resumen y continuidad: `docs/CONTINUITY_RUNBOOK.md`.
