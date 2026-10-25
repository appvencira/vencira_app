# VENCIRA — resumen de continuidad (25/10/2026)

## Estado de DEV confirmado

- Stack `vencira_localcheck` en Ubuntu, `https://dev.vencira.es/`, Flutter Web ES/CA, Django/DRF, PostgreSQL 17. Cuenta `vencira`, checkout `/home/vencira/vencira-localcheck`, GitHub `appvencira/vencira_app` (PRIVADO), rama `integration/local-e2e-prep`. No tocar otros stacks ni Caddy.
- **O8b/O8c**: simulación temporal de avisos y borradores por anotación desplegados. Migración persistente **`reminders.0015_renewal_reminder_drafts`** verificada tras ensayo de copia cifrada O5; no ejecutar de nuevo ninguna migración ya aplicada.
- **O9a**: evaluación de fecha de control **solo lectura** desplegada en commit de código `30a2f20d66836b222c446398d33578f5efd4c222`; terminal `O9A_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; API/DB/Web saludables, HTTP público 200 y endpoints anónimos 403. Captura Android: borrador `20,15`, referencia `21/10/2026`, `Revisión manual pendiente` coherente, sin errores visibles. O9a no envía avisos ni registra respuestas.
- **O5**: backup cifrado Restic hacia Drive, programado 03:00 Europe/Madrid, health 08:00; ensayos restaurados satisfactoriamente. No exponer claves ni alterar temporizadores. Fuente de backup real previa O8c, recibo `/tmp/vencira-o8c-deploy.gst32W6O.receipt`; O9a recibo `/tmp/vencira-o9a-20261025T070242Z_2658759.Zkb4kHCT.receipt`.

## Whitepaper original ya recuperado

Usuario volvió a adjuntar **`White_paper_agenda_vencimientos.pdf`**, 23 páginas, fecha 18/10/2026, @Bibroker Mediadores, S.L.U. SHA-256 PDF `7158c085a0771f1c09c19223284345899ef516394d4ddd77c3b63cdda5598c66`, 828405 bytes.

En GitHub están: [`docs/source/README.md`](source/README.md), transcripción buscable de **las 23 páginas** [`docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md`](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md), [`docs/OPERATION_O9B_RESPONSE_CONTRACT.md`](OPERATION_O9B_RESPONSE_CONTRACT.md), y roadmap reconciliado. **No se ha subido todavía el PDF binario a GitHub** por limitación del conector de escritura: su texto está preservado, pero esquemas e imágenes solo en PDF original aportado.

**Corrección fundamental de O9b según PDF §8 p.11:** pregunta «¿Se ha notificado a la aseguradora su no renovación?»; respuesta **Sí** con tres alternativas exactas: «Avisada por el cliente», «La aseguradora no renueva», «Notificado por mí»; registra opción, usuario, fecha y hora, anotación permanece en agenda. Respuesta **No** con «Avísame dentro de [selector de días]»: genera aviso «Comunicar no renovación de [nombre del cliente]»; §10 p.13 exige repetir la pregunta en la fecha elegida, sin superar fecha límite de un **mes civil** anterior al vencimiento. Si plazo hoy/pasado, indicador rojo; avisar que no conviene apurar el último día. **Estos comportamientos están definidos, no pendientes.**

**Pendientes expresamente §18 p.22**: alta tardía, cero avisos pre-límite, tratamiento especial Vida, motivos por defecto, avisos no atendidos, y decisiones de permisos/empresa/seguridad. No deducir soluciones de propuestas no aprobadas.

## Próxima tarea

**O9b-1**: implementar validador puro sin DB para exactamente 3 alternativas Sí y respuesta No con selección de fecha civil y tope, tests SQLite/PG17 y frontend ES/CA; después diseñar **nueva migración aditiva `0016`** para respuestas+historial inalterable. Antes de migrar DEV exigir protocolo O4 y restauración cifrada O5 real, nunca auto-migrar. **No enviar notificaciones ni cerrar anotación al responder Sí; no afirmar entregas por fechas calculadas**. O9a es solo lectura y debe conservarse.

## Forma de trabajo

Editar código y documentación directamente mediante conexión GitHub. Para Ubuntu, entregar un solo bloque Bash seguro y pedir logs; no reejecutar migraciones completadas. Mantener `docs/NEXT_CHAT_HANDOFF.md` para detalle histórico y actualizar esta ficha breve antes de cambiar de chat. Solo datos DEMO en DEV.
