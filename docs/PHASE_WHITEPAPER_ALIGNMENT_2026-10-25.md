# VENCIRA — fase única de correcciones de alineación §5/6/9/13

**Fecha:** 25/10/2026. **Estado:** TODOS los cambios de código y las pruebas adicionales incorporados en la rama de integración. **No desplegados ni validados aún en Ubuntu**. **Ninguna migración nueva:** esquema actual DEV `reminders.0015_renewal_reminder_drafts`. **Avisos automáticos y envíos permanecen inactivos.**

Referencia: [Auditoría completa](AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md), whitepaper original transcrito [23 páginas](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md). Se agrupan TODAS las discrepancias concretas de funcionalidades YA construidas en un único lote, incluido inicio en HOY, sin incorporar O9b ni O10.

## Cambios incluidos

### A-01 — Alta de anotaciones (§6)

- `backend/reminders/serializers.py`: **solo nuevos registros** deben incluir `entry` Clientes/Candidatos, `full_name` no vacío y `expires_on`. `customer_reference` deja de ser requisito; si falta o se envía vacía, Django genera `V-<UUID v4 hexadecimal>` sin PII. No cambia ni rellena históricos.
- `clients/flutter/lib/ui/renewal_editor.dart`: oculta «Referencia» en creación, la conserva editable en anotaciones legadas y valida nombre con recursos ES/CA; no fuerza nombres inventados al editar registros antiguos. El envío de nueva anotación deja referencia vacía y la genera la API.
- Pruebas: `test_renewal_entry.py`, `test_api.py`, `test_audit.py` actualizados con altas conformes; `renewal_editor_test.dart` comprueba ausencia de referencia obligatoria en alta.

### A-02 — «No aceptó» y reinicio anual de anticipaciones (§9)

- `backend/reminders/outcomes.py`: al desplazar vencimiento +1 año en una transacción, si existe borrador personalizado, vuelve a `[60,45,35]`, incrementa `revision`, registra actor y un evento de auditoría sin datos personales. Si no hay borrador, los defaults implícitos de O8a/O8c ya son `[60,45,35]` y no se genera fila innecesaria.
- `test_outcomes.py`: caso con borrador `20,15` y `revision=4` que tras `declined` pasa a `60,45,35`, revision=5, nuevo evento, vencimiento bisiesto ajustado y **cero avisos enviados**. Los `ReminderCandidate` de políticas voluntarias preexistentes mantienen su lógica, pero NO equivalen al programador O10 futuro.
- **Alcance:** se reestablece la configuración lógica para el nuevo ciclo; no se programan ni envían mensajes ni trabajos automáticos mientras O10 esté pendiente.

### A-03 — candidato ganado → cliente sugerido en anotaciones posteriores (§6)

- `person_suggestions.py` devuelve `suggested_entry='clients'` solo desde una anotación autorizada y **explícitamente seleccionada** que está clasificada como cliente. No cruza organizaciones/usuarios asignados ni correlaciona por coincidencia insegura de nombres.
- Cliente tipado `VenciraPersonSuggestion`; al copiar contacto desde una anotación `clients` a una **nueva** anotación, el selector Entrada propone `Clientes`. No modifica retroactivamente otras pólizas.
- Pruebas backend y Dart para `suggested_entry`, tenencia, exclusión y fuentes no convertidas.

### A-04 — centralización de textos (§13)

- Extraídos a `app_es.arb` y `app_ca.arb` los textos en línea de O8b (simulador), O8c (borrador), O9a (pregunta de control informativa), desenlaces y ficha de detalle, alta/editor y rótulos restantes de agenda día/mes/panel. Mantiene literalmente los mensajes aprobados del UI y los errores de conflicto.
- `scripts/check_flutter_l10n.py` compara las claves y placeholders ES/CA; `flutter analyze/test/build` verifica las propiedades generadas. Cadenas técnicas, nombres de marca, formato de fechas y el texto de demos/test no deben traducirse.
- **Límite de auditoría:** se han migrado los literales localizados detectados de estos módulos. La traducción final de correos, push y pantallas aún no implementadas corresponde a sus fases; no certificar cobertura de contenido inexistente.

### A-05 — entrada directamente en agenda HOY (§5)

- `VenciraApp` activa `openTodayOnLoad` en sesión real. Si solo existe un workspace, tras carga autorizada abre `VenciraDayAgendaScreen` en fecha actual, sin forzar elección arbitraria. Si hay varios, deja seleccionar y después abre HOY. Al retroceder se mantiene el panel y no provoca un bucle de redirección.
- Inyección de API de tests mantiene el panel estable salvo cuando se prueba `openTodayOnLoad:true`; `widget_test.dart` incluye ambas rutas.

## Validación/despliegue de una sola fase — secuencia protegida

**Nueva orden:** `scripts/validate_and_deploy_whitepaper_alignment.sh`.

1. `scripts/check_whitepaper_alignment_static.sh`: Bash syntax, ausencia de migraciones destructivas, 0015 fijo, continuidad de las cinco correcciones, esquemas ARB ES/CA iguales.
2. `scripts/validate_o7_o8_preflight.sh`: chequeo y compilación backend aislada, migraciones secas, Django suite completa en SQLite y PG17 efímero, Flutter analyze/test/build, salud live PRE/POST. Si cualquiera falla, **NO desplegar**.
3. `scripts/deploy_whitepaper_alignment_no_migrations.sh`: comprueba que backend/clients/compose/deploy corresponden exactamente al commit de código validado **`c4886728f3a9c53c592911d19096056bc56a0949`**, O5 cifrada reciente y sana (solo lectura), DB persistente 0015 y API check-only; etiqueta imágenes anteriores, construye API/Web sin tocarlas, `migrate --check --noinput` (NO `migrate`), verifica contenedores originales, recrea únicamente API/Web, confirma DB id y cantidad de migraciones intactas, HTTP locales y rechazo anónimo de O7/O8b/O8c/O9a/O3, salud final y recibo privado.

**Peligros / stop conditions:** Si falla durante compilación, no cambia DEV. Si falla tras recrear contenedores, no repetir a ciegas: revisar etiquetas previas y recibo, sin restaurar DB automáticamente. No ejecutar script de O8c ni `0015` otra vez. No modificar O5, OAuth, Caddy, DNS o datos de producción. Solo demo.

**No se puede marcar esta fase como completada** hasta recibir `WP_ALIGNMENT_STATIC=OK`, `WP_PREFLIGHT_INTEGRAL=OK`, `WP_ALIGNMENT_DESPLIEGUE_SIN_MIGRACION=OK`, `WP_ALIGNMENT_PHASE_COMPLETE=OK` y `RESULTADO_EJECUCION=0` del servidor, y posterior prueba visual de alta, entrada HOY y desenlaces.

## Fuera de la fase (correctamente pendiente)

O9b (respuestas Sí/No y auditoría), O10 (entrega/repetición real), gestión de equipos, adjuntos, Excel, offline nativo, MFA/RGPD y políticas de retención. Se mantienen en roadmap, NO habilitados en este lote.
