# VENCIRA — Indicadores de actividad en la franja semanal

**Referencia revisada:** whitepaper `White_paper_agenda_vencimientos.pdf`, 18/10/2026, §5 y maqueta de página del día (pág. 6); §11, historial solo en ordenador (pág. 13). El documento requiere la franja semanal con día seleccionado, y puntos de colores **expresamente en calendario mensual**. Extender las marcas a la franja semanal es una mejora de consistencia solicitada durante la revisión visual de Android del 22/10/2026, no un requisito literal previo.

## Comportamiento

- Cada casilla **lunes–domingo** presenta los mismos códigos que `Ver mes`: vencimiento (error/rojo), límite de preaviso contractual del prototipo (terciario/violeta), aviso previsto (primario/azul verdoso). **Punto lleno** = pendiente; **círculo sin relleno** = contactado, no cerrado. No implica que se haya enviado un aviso.
- Preservar la fecha seleccionada y permitir pulsar cualquier día. La descripción accesible indica la fecha completa y cuántas anotaciones hay por tipo/estado.
- Al cambiar de semana, borrar inmediatamente los marcadores de la anterior. En la nueva franja se carga un resumen de mes: **una sola solicitud HTTP cuando la semana está en un mes, dos si cruza meses**. No se consultan siete listados completos ni se exponen referencias.
- El resultado se basa en el mismo GET autenticado `/api/v1/workspaces/{uuid}/agenda/month/?month=YYYY-MM` de la vista mensual, respetando rol, asignación, estados y exclusiones. No cambia API, modelo ni DB.
- Evitar solicitudes repetidas al pasar de un día a otro **dentro de la misma semana**. Al regresar de editar una ficha, o pulsar actualizar, solicitar de nuevo el resumen. Los resultados tardíos se descartan con una generación por petición.
- Si falla la consulta, **no dibujar puntos engañosos ni reutilizar los de semanas anteriores**. Mostrar mensaje localizable ES/CA y reintentar con el botón actualizar.
- Si caduca la sesión, eliminar al instante los puntos y no reutilizar resultados de una consulta anterior. Los dispositivos móviles y escritorio comparten el mismo widget y semántica.

## Notas del whitepaper

- §11 reserva el **historial** de gestiones a la interfaz web de ordenador, no a móvil/tablet. Las capturas Android de la ficha y editor no deberían mostrar `Consultar historial`, pero sí permitir ver y editar anotaciones; la app actual cumple esa delimitación.
- §8 distingue **límite legal calculado** de vencimiento, que no se debe representar directamente en agenda. El prototipo actual usa un campo manual `notice_deadline_on`. **No se afirmará que sea el cálculo legal definitivo**. Revisar con §8 cuando se construya la lógica de avisos legales.

## Corrección de alineación de los siete días (22/10/2026)

Validación visual real en Chrome Android: antes del ajuste, los días 27, 29 y 30 de octubre eran más altos porque la `Column` solo añadía la fila de indicadores cuando había actividad. Cada día reserva ahora una franja de **32 píxeles lógicos** para las marcas, esté vacía o no, bajo el nombre y número de día. Así los siete contenedores tienen la misma altura, también cuando coinciden varios tipos de evento. No se cambia la API, los colores, la semántica de los estados ni los permisos.

Pruebas adicionales de widgets comprueban la altura idéntica de los siete controles y el espacio reservado en **320/375/768 píxeles**, ES/CA y temas claro/oscuro; también verifican que los puntos de varios tipos siguen visibles.

## Verificación

- Pruebas widget ES/CA, dark mode y tamaños 320, 375 y 768 px.
- Semana que cruza marzo/abril con datos en ambos lados, marcadores independientes `expiry`/`notice`/`reminder`, combinaciones de estados, navegación entre días sin consultas adicionales y a la semana siguiente sin marcas fantasma.
- Refresh fuerza consulta actualizada. Se conserva la función anterior de consulta diaria y mensual.
- Desplegar **solo** el contenedor `web_preview` del proyecto `vencira_localcheck` tras CI verde. Mantener API, PostgreSQL, Caddy, usuario, datos y el proyecto anterior `vencira_preview` sin cambios.
