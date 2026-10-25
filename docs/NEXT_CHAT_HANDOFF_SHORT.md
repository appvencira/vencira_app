# VENCIRA — continuidad rápida (estado 25/10/2026)

**Estado comprobado en terminal: O8c DESPLEGADA TÉCNICAMENTE EN DEV.** Pendiente aceptación funcional MANUAL del guardado de borradores en navegador. No ejecutar otra vez la migración ni el despliegue.

## Fuente de verdad

- GitHub privado `appvencira/vencira_app`, rama `integration/local-e2e-prep`; checkout Ubuntu `/home/vencira/vencira-localcheck`; stack Docker `vencira_localcheck`, NO interferir con otros stacks, Caddy ni O5.
- API Django/DRF, PostgreSQL 17, Flutter Web ES/CA. Web `https://dev.vencira.es/`.
- Consulta `docs/NEXT_CHAT_HANDOFF.md`, `docs/CONTINUITY_RUNBOOK.md`, `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md` y `docs/OPERATION_O8C_PERSISTED_RULES_PLAN.md`. Whitepaper original 23 páginas.
- El usuario prefiere cambios directamente en GitHub y un solo bloque Bash seguro para verificación en Ubuntu. Registrar hitos en el documento de continuidad y actualizar esta ficha antes de cambiar de chat.

## Hitos

- O1–O3 y O6: anotaciones, desenlaces/archivo y modalidades. O7: resultados por mes, trimestre, año con cambio visual aceptado (no extrapolar a exactitud contable).
- O4: API arranca con `migrate --check --noinput`, nunca aplicar migraciones al reinicio.
- O5: copias cifradas Restic en Drive, 03:00 y salud 08:00 Europe/Madrid. No tocar credenciales ni temporizadores.
- O8a fechas civiles; O8b vista previa con 60/45/35 y 20/15 **desplegada y aceptada manualmente**. No guarda ni envía avisos.
- **O8c: guardado por anotación SOLO en estado `draft`**, 1..12 anticipaciones únicas 0..365, revision/CAS 409, owner o miembro asignado, CSRF y aislamiento tenant; Flutter ES/CA `Guardar solo borrador`. No se crean avisos ni notificaciones. Pruebas Django SQLite/PG17 efímero y Flutter verdes en fuente `80a5ac618f476a2d3b256499047dfdd1ada01c12`.
- Ensayo pre-migración: snapshot cifrado O5 `0b838739` restaurado en PG17 aislado; `0015_renewal_reminder_drafts` migrada únicamente en clon, tablas antiguas y conteos preservados: `ENSAYO_O8C_0015_AISLADO=OK`. Recibo root 600: `/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt`.
- **Despliegue O8c confirmado por el usuario:** fuente Web `9c404380e5801d8f9fd2d4dfe260d51df78264d6`, script `scripts/deploy_o8c_0015_guarded.sh` ejecutado con `MIGRACION_0015_VERIFICADA=OK`, `POSTGRES_0015_SIN_REINICIO=OK`, `API_O8C_DESPLEGADA=OK`, `FLUTTER_WEB_O8C_DESPLEGADA=OK`, `ENDPOINTS_PRIVADOS_PROTEGIDOS=OK`, salud API/DB/Web healthy, proxy y HTTPS HTTP 200, `O8C_DESPLIEGUE_0015_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. DB persistente en **`reminders.0015_renewal_reminder_drafts`**, sin reinicio. Backup fresco O5 previo OK.
- Etiquetas rollback (conservar): `vencira-o8c-before-api:20261025T061256Z_2623430`, `vencira-o8c-before-web:20261025T061256Z_2623430`. Recibo de despliegue `/tmp/vencira-o8c-deploy.gst32W6O.receipt` y log `/tmp/vencira-o8c-deploy.6ggUPoJg.log`. **No restaurar BD automáticamente ni ejecutar rollout por segunda vez.**

## Acción siguiente

**UAT manual O8c en datos DEMO, desde navegador:** abrir anotación activa > desplegar `Simular avisos` > sección `Guardar borrador de avisos` > introducir `20,15` > `Guardar solo borrador`. Salir y volver: debe mantener `20,15` y mostrar borrador guardado. Otra anotación debe seguir con default `60,45,35`. Revisar mensajes ES/CA, que nunca aparezcan avisos entregados, y no confundir simulador O8b sin persistencia con borrador O8c. Si hay fallo, diagnosticar en GitHub y ejecutar sólo pruebas apropiadas, no repetir migración.

Después de aceptar O8c: continuar O9 (pregunta de control/repetición), O10 (notificaciones) y O11 (agenda HOY), pendientes las decisiones §18 del whitepaper sobre motivos, Vida, altas tardías, reintentos y canales. No activar envíos sin resolverlas. 
