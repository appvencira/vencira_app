# VENCIRA — Preparación de avisos (sin envíos)

## Alcance de este avance

Se crean **reglas y candidatos internos**, no notificaciones enviadas:
- `ReminderPolicy`: una anticipación de 0 a 365 días, ligada a una organización; **desactivada por defecto**. Campo `basis`: `expiry` (default compatible) o `notice_deadline` (requiere fecha opcional `Renewal.notice_deadline_on`).
- `ReminderCandidate`: referencia a vencimiento y regla, fecha prevista, estado `planned/cancelled` y clave única de deduplicación. Distintas bases con igual número de días pueden coexistir en la misma organización.
- Servicio `refresh_candidates(workspace_id, today, horizon_days)`: sincroniza candidatos solo de esa organización y dentro de la ventana. No tiene canal (email, push, SMS) ni destinatarios.
- Cambiar vencimiento, límite de preaviso, estado o desactivar la regla permite **cancelar** candidatos futuros obsoletos al ejecutar de nuevo la conciliación. Rehabilitar una regla puede reactivar candidatos. Una regla de preaviso sin fecha explícita no genera candidatos.

## Ejecución manual para pruebas

Solo con datos sintéticos locales, tras crear una `ReminderPolicy(enabled=True)` de prueba:

```bash
docker compose exec api python manage.py prepare_reminder_candidates \
  --workspace UUID_DE_UNA_ORGANIZACION_DE_PRUEBA --horizon-days 30
```

Las reglas se gestionan por ahora únicamente desde Django shell, sin endpoint ni UI. **No hay tarea programada, proceso de entrega ni envío por correo/push.**

## Requisitos antes de enviar nada

1. Reglas funcionales: destinatarios, anticipación, calendario laboral, zona horaria por cliente/entidad, horarios silenciosos y opt-in/consentimiento.
2. Motor persistente con locks/idempotencia de eventos de entrega; manejo de errores, deduplicación multiworker, límites por usuario y registro de auditoría.
3. Supresión por opt-out, eliminación de datos, revocación de permisos y cambios de vencimiento.
4. Contrato de proveedor, RGPD, minimización del contenido notificado, monitorización y pruebas de recuperación.
5. Cancelación de candidatos ya preparados y política de retención (incluidos estados históricos).

Los candidatos no se exponen en API ni se usan con datos reales hasta completar las garantías anteriores.
