# VENCIRA — Operativa O1: registro manual de contacto

Fecha: 23/10/2026. Rama: `integration/local-e2e-prep`.

## Estado del producto y decisión
- **V3.1 aceptada visualmente en Android por el usuario.** Las tres capturas del 23/10 confirman el nuevo panel de filtros, el selector Estado (bottom sheet) y Preferencias (idioma/apariencia). El usuario solicita pasar del pulido visual a la funcionalidad.
- Whitepaper original `White_paper_agenda_vencimientos.pdf` (18/10/2026, §6): cada anotación representa una póliza externa independiente; Clientes y Candidatos no son una ficha global CRM. Se quiere gestionar seguimiento y recordatorios, con desenlaces futuros «Conseguido», «No aceptó», «Aún sin decidir» y «Descartar».
- **Límite de esta entrega O1**: facilitar el paso entre `pending` y `contacted` desde la ficha, con confirmación explícita, sin apertura del editor completo. Aún no se implementa «Recuérdamelo», ninguno de los cuatro desenlaces, ni comunicaciones reales. `closed` no es equivalente a «Conseguido» y la acción rápida no permite cierre.
- Registrar como contactado **significa que el usuario afirma haber efectuado el contacto fuera de VENCIRA**. Nunca afirmar que VENCIRA haya enviado un mensaje o un aviso. No registrar contenido nuevo de comunicaciones ni sustituir las notas.

## Implementación
1. `clients/flutter/lib/api/vencira_api.dart`: nueva operación `changeRenewalStatus(workspaceId, renewalId, status)`, con implementación predeterminada que falla para dobles antiguos. `HttpVenciraApi` valida UUID y permite solo `pending` o `contacted`, obtiene CSRF en mismo origen y hace PATCH **exclusivamente** `{"status": "..."}` en la ruta autorizada ya existente. Exige respuesta 200, coincidencia de ID y estado y no divulga errores internos.
2. `clients/flutter/lib/ui/renewal_detail_screen.dart`: tarjeta «Seguimiento / Seguiment» con explicaciones y botón «Marcar como contactado / Marcar com a contactat» o «Volver a pendiente / Tornar a pendent». Siempre pide confirmación y permite cancelar sin escribir. Al confirmar, deshabilita acciones mientras guarda, actualiza ficha y el historial técnico de escritorio si ya estaba consultado. Mensajes de éxito y error ES/CA. La acción no se muestra para `closed`.
3. Backend Django **sin cambios**: el PATCH parcial existente usa membresía y alcance `_visible_renewals`, `select_for_update`, `RenewalSerializer(partial=True)`, solo campos enviados, y `make_audit_event` transaccional que registra `status` como campo cambiado sin notas/PII en metadatos. No hay migraciones ni cambios de BD.
4. Tests nuevos/actualizados:
   - `clients/flutter/test/vencira_api_test.dart`: CSRF, JSON PATCH solo `status`, sin sustituir notas/fechas, UUID/valor permitido y respuesta de otra anotación rechazada.
   - `clients/flutter/test/contact_followup_test.dart`: móvil ES/CA, confirmación cancelable sin mutación, cambio pendiente→contactado y conservación de notas sintéticas. Scroll real en móvil.
5. `scripts/validate_operativa_o1.sh`: copia especializada de script web-only de V3.1, suma tests O1, análisis y suite Flutter completa + build release, verificación Docker Compose `vencira_localcheck`, despliegue solo `web_preview`, HTTP/health. Protege SSH y deja backend/DB intactos.

## Aceptación
- Abrir una anotación **pendiente** de demostración; ver acción de seguimiento, cancelarla y comprobar que no cambió estado.
- Repetir y confirmar «Marcar como contactado»; estado se actualiza y conserva fechas, notas y resto de datos. Desde `contacted` puede volver a pendiente mediante confirmación.
- Acciones y mensajes claros en Español/Català, sin afirmaciones de notificaciones enviadas.
- Nunca exponer historial técnico en móvil; sigue disponible solo en web de escritorio, como acordado.
- La suite completa ha de pasar antes de actualizar Web; vigilar el histórico de 320px catalán.
- **Estado ahora**: código y tests preparados en GitHub, SIN VALIDAR NI DESPLEGAR hasta obtener evidencia `RESULTADO_GLOBAL=0` del servidor.

## Próximas fases funcionales
**O2: «Recuérdamelo» real y persistente, sin envíos automáticos todavía.** Definir fecha de seguimiento por anotación y comportamiento de posponer, cancelar y mostrar en agenda mensual/diaria; nueva migración aditiva y pruebas de permisos, aislamiento, zona horaria local y restauración/backup antes de migrar `vencira_localcheck`. Distinguir explícitamente seguimiento manual de fecha de aviso contractual y notificación efectivamente enviada.

**O3: desenlaces del whitepaper**, modelar de forma independiente «Conseguido», «No aceptó», «Aún sin decidir» y «Descartar», y sus transiciones/historial. No equiparar hoy `closed` con ninguna de ellas. Sin habilitar envíos, adjuntos ni tratamientos con datos reales antes de cumplir seguridad, permisos, GDPR y backups.

## Flujo de servidor
Sin GitHub Actions (cuota agotada), usar una sola ejecución posterior a cambios:

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash scripts/validate_operativa_o1.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

No ejecutar migraciones, no reiniciar API/Postgres y no alterar el stack `vencira_preview`.
