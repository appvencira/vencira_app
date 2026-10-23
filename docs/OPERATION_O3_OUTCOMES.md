# VENCIRA — Operativa O3: cuatro desenlaces de pólizas externas

**Estado vigente:** O3 **validada íntegramente en aislamiento** (Django SQLite, PostgreSQL 17 temporal, Flutter analyze/test/build; `RESULTADO_GLOBAL=0`, commit `4d5270be3ebb7ab32d4bab103208ed34002f0082`). **Todavía NO existe copia pre0014 validada, ni migración real ni despliegue O3.** Actualizado 23/10/2026. Rama: `integration/local-e2e-prep`.

## Hito anterior y fuente funcional
- O2 «Recuérdamelo» aceptada funcionalmente en Android. Confirmación expresa: reprogramar fecha, cancelar y marcar como atendido funciona. Despliegue O2 `e8d5ccf9` healthy, migración `0013` aplicada y backup pre0013 íntegramente restaurado. No volver a probar O2 salvo regresión.
- White paper original `White_paper_agenda_vencimientos.pdf`, apartado 9 / página 12: 4 desenlaces. Apartado 12: archivo y retención 2 años; apartado 10/11 historial por fecha, usuario, acción; no CRM, no cartera propia. La antigua etiqueta técnica `Renewal.status=closed` no es por sí misma una decisión comercial.

## Contrato O3 (una anotación = UNA póliza externa)
| Acción | Cambio en anotación | Seguimiento y agenda | Auditoría |
| --- | --- | --- | --- |
| Conseguido (`won`) | `status=closed`, `archive_outcome=won`, `archived_at=ahora`. Si era `prospects`, SOLO esta anotación pasa a `clients`; **no existe ficha CRM global**. | Deja agenda. Cancela seguimientos O2 pendientes y candidatos de aviso previstos, sin borrarlos. | Evento con actor/fecha/kind y entrada anterior para restaurar |
| No aceptó (`declined`) | Sigue abierta, `status=pending`; vencimiento avanza 1 año civil, 29/02→28/02 cuando procede. Preaviso explícito avanza también 1 año, conservando su desplazamiento. Notas, contacto, documentos y aseguradora se preservan. | Cancela candidatos/siguimientos previstos antiguos; reconstruye **candidatos** exclusivamente de `ReminderPolicy` habilitadas de esa cuenta para fechas futuras (pueden ser fechas civiles pasadas si una anotación ya vencida). **No envía notificaciones**. | Evento con fecha anterior y nueva |
| Aún sin decidir (`undecided`) | No cierra ni cambia vencimiento. | Exige `scheduled_for:YYYY-MM-DD`, reprograma una sola O2 `planned` dentro de la misma transacción; figura en agenda violeta. | Evento con fecha de seguimiento |
| Descartar (`discarded`) | Cierra y archiva con motivo `discarded`; no cambia Entrada. | Fuera de agenda; cancela candidatos/siguimientos previstos, conservando historial. | Evento con actor/fecha/motivo |
| Recuperar (`restored`) | Solo si archivada por O3. Vuelve a `pending`, limpia marcador de archivo, y en una ganada originalmente candidata restaura `prospects`. | Reconstruye candidatos de políticas habilitadas; no reabre mensajes antiguos. | Evento distinto de recuperación |

## Cambios versionados propuestos
- `backend/reminders/models.py`: `Renewal.archived_at` (nullable), `Renewal.archive_outcome` (won/discarded); `RenewalOutcome` guarda actor, momento, resultado, vencimiento antiguo/nuevo, día de seguimiento, entrada anterior, sin datos personales.
- Migración **aditiva `backend/reminders/migrations/0014_renewal_outcomes.py`**. Nada se elimina ni convierte automáticamente de estados `closed` anteriores. No hay jobs destructivos.
- `backend/reminders/outcomes.py`: GET de eventos O3 autorizados (máximo 50) y POST de un resultado exacto. POST serializa por anotación mediante `select_for_update` en una única transacción, limita estrictamente el JSON, aplica eventos O3 y auditoría sin PII, no comunica a clientes. Es necesario estar en organización y poder acceder a esa anotación según propietario/miembro.
- `backend/reminders/views.py`: listado principal excluye archivados nuevos; selección `Estado=Cerrado` permite consultar archivo y cerrados antiguos para recuperación/inspección. Las agendas diaria y mensual ya excluyen `status=closed`.
- `backend/reminders/serializers.py`: `archived_at` y `archive_outcome` SOLO lectura. Se prohíbe el salto `status=closed` mediante PATCH/POST genérico; requiere flujo O3 auditado; edición genérica de O3 archivados devuelve HTTP 409.
- `clients/flutter/lib/api/vencira_api.dart`: método `applyOutcome` con CSRF, UUIDs, enum y fecha civil validada; lectura del resultado de archivo.
- `clients/flutter/lib/ui/renewal_detail_screen.dart`: tarjeta de desenlaces / menú premium de cuatro acciones, fecha O2 para indecisión, pantalla de confirmación, recuperación de archivo, estado y mensajes ES/CA. En el historial técnico de escritorio se muestra el tipo exacto de desenlace además del usuario y momento; móvil no expone auditoría técnica.
- `clients/flutter/lib/ui/renewal_editor.dart`: el editor general no ofrece «Cerrado» para anotaciones activas, porque no es un resultado O3.
- `backend/reminders/test_outcomes.py`: tests de archive/restore, conservar original y paso anual bisiesto, candidato reprogramado, O2 «indeciso», aislamiento de tenant, payload estricto, CSRF y metadatos no sensibles.
- `clients/flutter/test/outcomes_test.dart`, `clients/flutter/test/vencira_api_test.dart`: móvil ES/CA en 375px, confirmación, recuperación, fecha civil y no enviar datos inesperados. Tests globales existentes siguen obligatorios.
- `scripts/validate_operativa_o3_preflight.sh`: ejecución aislada de **toda Django en SQLite**, O3+O2 en **PostgreSQL 17 temporal**, Flutter analyze/tests completos/build release. No recrea `vencira_localcheck`, no migra PostgreSQL persistente, no altera `vencira_preview`.

## Riesgos y tareas no incluidas en esta fase
1. **Retención / borrado a los 2 años según whitepaper**: NO se activa ahora. Faltan política RGPD/LOPDGDD, definición de relación entre eventos de auditoría y conservación, posibilidad de restauración y tarea cron con protección. Modelo `RenewalAuditEvent` tiene `on_delete=PROTECT`, por lo que automatizar `DELETE` sin una política explícita fallaría o degradaría auditoría. No prometer eliminación automática hasta resolver este diseño y aprobar la seguridad.
2. No hay nuevos mensajes, notificaciones, envíos a aseguradoras ni automatización de avisos: `ReminderCandidate.planned` sigue siendo **previsión**, no entrega.
3. No hay entidad transversal `Cliente`; pasar de Candidatos a Clientes solo cambia Entrada de una anotación. No altera otras pólizas de esa persona.
4. Reglas activas de aviso por defecto: solo políticas `enabled=True` ya configuradas para la cuenta. No inventar un calendario global ni afirmar candidatos creados cuando no existe política.
5. Los cerrados *legados* con `archived_at=null` no se asignan retroactivamente a `won` ni `discarded`; el usuario o una migración explícita deberá resolver su tratamiento.
6. El archivo se consulta de forma provisional con filtro **Estado → Cerrado**. Pantalla independiente «Archivo», búsqueda específica, exportación y recuperación masiva quedan como refinamiento posterior.
7. Posible prioridad UX para fechas pasadas, renovación Feb-29 y notas al posponer; deben validarse y corregirse si los tests muestran una interpretación errónea del whitepaper.

## Gates y continuidad
- Primero `scripts/validate_operativa_o3_preflight.sh` sobre código versionado, hasta `RESULTADO_GLOBAL=0`; corregir GitHub ante errores y documentar.
- **Nunca** aplicar `0014` antes de otra copia `pg_dump -Fc` restaurada en PostgreSQL temporal y comprobada, sobre `vencira_localcheck-db-1`. El respaldo pre0013 pertenece a la fase anterior, no sustituye un pre0014 nuevo.
- Despliegue API+Web solo `vencira_localcheck`, plan `migrate --plan`, imágenes anteriores conservadas y health checks de DB/HTTP/ruta O3; no rollback automático de BD. Tras éxito, verificar manualmente Android con **datos ficticios** las cuatro decisiones, 29/02 y archivo/recuperación.
- En este momento O3 **NO probada, NO desplegada y migración 0014 NO aplicada**. O2 sigue saludable y aceptada.

## O3 preflight completo OK — respaldo pre0014 separado (23/10/2026)

- El usuario aportó salida completa de `scripts/validate_operativa_o3_preflight.sh`: `DJANGO_CHECK_Y_MIGRACION_EN_SECO=OK`, `DJANGO_SQLITE_SUITE=OK`, `POSTGRES_EFIMERO=OK`, `DJANGO_POSTGRES_O3_TESTS=OK`, `FLUTTER_O3_SUITE_Y_BUILD=OK`, `DJANGO_SQLITE_POSTGRES_FLUTTER_O3=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; commit `4d5270be3ebb7ab32d4bab103208ed34002f0082`, log `/tmp/vencira-operativa-o3-preflight.SANjeL4q.log`. No tocar la base persistente todavía.
- Preparado `scripts/prepare_operativa_o3_backup.sh` (commit `21c98303876c9e00a6ff84c4d19e496da4dc78c0`). Verifica identidad de stack, código inalterado, migración existente `0013`, ausencia de tabla `RenewalOutcome`, respaldo pg_dump custom nuevo pre0014, SHA-256, restauración íntegra offline PostgreSQL 17, esquema y contadores incluyendo `RenewalFollowUp` y `ReminderCandidate`. Ficheros modo 600 bajo directorio 700; **no están cifrados**. Solo se genera `.verified` si restauración y comparación superan pruebas; el contenedor temporal se destruye y no se reinicia ningún servicio real.
- El script de respaldo se ha subido, **aún NO ejecutado**. El siguiente hito verificable será `BACKUP_RESTAURACION_VERIFICADOS=1`, `RESULTADO_GLOBAL=0` sobre el nuevo pre0014. No reutilizar pre0013 de O2. Después, y en ejecución independiente, desplegar `0014` mediante API y Web con `migrate --plan`, validaciones de huella y salud. No restaurar automáticamente un backup antiguo si aparece un fallo después de escrituras reales.
