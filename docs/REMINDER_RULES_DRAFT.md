# Reglas de avisos — propuesta para validación comercial

**Estado: borrador de producto, no requisitos aprobados.** No activar notificaciones externas.

## Lo implementado actualmente (no es una política comercial definitiva)

- Las reglas se configuran **por organización** y permanecen desactivadas por defecto.
- Anticipación posible: de 0 a 365 **días naturales** antes del vencimiento. La fecha se calcula restando días a la fecha del vencimiento. La implementación usa `Europe/Madrid` para determinar el día actual.
- Solo se generan candidatos para vencimientos con estado `pending`. Los marcados `contacted` o `closed` se excluyen actualmente.
- La preparación se ejecuta **manualmente**, para una organización y una ventana futura (30 días por defecto); no recupera automáticamente avisos de días anteriores.
- El sistema concilia candidatos si se modifica la fecha, el estado del vencimiento o la regla, evitando duplicar la misma combinación de vencimiento, regla y día. NO hay envíos, reintentos, usuarios destinatarios ni motor programado.

## Decisiones pendientes con implicaciones comerciales

| Aspecto | Alternativas para decidir | Riesgo si se presupone |
|---|---|---|
| ¿Qué fecha vigilar? | Fecha contractual, vencimiento renovable, fecha límite de preaviso de baja | Alertar demasiado tarde para actuar |
| Ventanas de anticipación | 90/60/30/15/7/1 días o personalizadas | Exceso de avisos o pérdida de oportunidades |
| Estado `contacted` | Seguir vigilando / posponer / suprimir por evento | La lógica técnica actual suprime próximos candidatos |
| Día no laborable | Mantener fecha natural / adelantar al hábil anterior / ajustar por calendario local | Oportunidades perdidas por fines de semana y festivos |
| Prioridad | Por proximidad, importe o tipo de vencimiento | Listados engañosos |
| Destinatario | Mediador responsable / equipo / cliente final con consentimiento | Privacidad y comunicaciones no autorizadas |
| Frecuencia | Un aviso por tramo / resumen diario / escalado por incumplimiento | Fatiga y duplicados |
| Cambio de contrato | Cancelar y recrear avisos / conservar registro histórico | Avisos incorrectos tras actualización |
| Obligaciones RGPD | Finalidad, base jurídica, DPA, retención y derechos | Tratamiento de datos no autorizado |

## Propuesta de MVP para discutir (NO activada)

Un calendario de trabajo para el **profesional** con alertas internas editables 30/15/7 días antes de la *fecha de acción* de cada vencimiento; sin mensajes automáticos a clientes finales. Guardar responsable del expediente y registro de cambios. Confirmar si corresponde avisar antes del **plazo de preaviso contractual** y no simplemente de la fecha de vencimiento.

**Criterio previo a implementar entrega:** aprobar tipos de vencimiento, definición de fecha operativa, cambios de estado y destinatarios. Hasta entonces, el sistema seguirá preparando únicamente candidatos internos con datos de prueba.
