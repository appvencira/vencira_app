# VENCIRA — ficha rápida para continuar en otro chat

**Fecha:** 25/10/2026. **Estado verificable:** O8b está desplegada y aceptada; O8c probada y con migración 0015 ensayada en clon, **pero NO desplegada en DEV**.

## Fuente de verdad

GitHub privado `appvencira/vencira_app`, rama `integration/local-e2e-prep`. Checkout Ubuntu `/home/vencira/vencira-localcheck`; stack exclusivo `vencira_localcheck`: Django/DRF, PostgreSQL 17 y Flutter Web ES/CA, `https://dev.vencira.es/`. Whitepaper `White_paper_agenda_vencimientos.pdf` (23 págs). Docs fundamentales: `docs/NEXT_CHAT_HANDOFF.md`, `docs/CONTINUITY_RUNBOOK.md`, `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`, `docs/OPERATION_O8C_PERSISTED_RULES_PLAN.md`.

## Hitos y pruebas

- O1–O3, O6 operativa/archivo; O7 resultados mes/trimestre/año validada manualmente; O8a fechas puras; O8b simulador con 60/45/35 y 20/15 en detalle validado manualmente. **O8b NO guarda ni envía.**
- O4 backend `migrate --check --noinput` al iniciar: migraciones siempre explícitas. Estado DB persistente `reminders.0014_renewal_outcomes` antes de O8c.
- O5 cifrado Restic vía Rclone Google Drive a las 03:00 Europe/Madrid, salud 08:00; copia cifrada y restauración PG17 temporal confirmadas, timers sin tocar. **No imprimir claves/secretos ni incluir datos reales en DEV**.
- O8c nueva tabla `RenewalReminderDraft` 1:1, solo estado `draft`, JSON anticipaciones, revisión CAS, actores; GET/PUT autenticado con scope owner/assigned, sin activar avisos. Flutter ES/CA muestra `Guardar solo borrador`. Tests Django SQLite/PG17 y Flutter **TODOS VERDES** en commit fuente `80a5ac618f476a2d3b256499047dfdd1ada01c12`.
- Ensayo O8c restaurando snapshot cifrado Restic `0b838739` en PG17 aislado, migración `0015_renewal_reminder_drafts` SOLO en clon y checks de constraints/conteos todos verdes. Terminal `ENSAYO_O8C_0015_AISLADO=OK`, `RESULTADO_GLOBAL=0`. Recibo root `600`: `/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt`. LIVE 0014 intacta.

## Próximo paso exacto

Nuevo script controlado GitHub `scripts/deploy_o8c_0015_guarded.sh`; chequeo estático `scripts/check_o8c_deploy_static.sh`. **Los scripts están preparados en repo pero el usuario aún no los ha ejecutado ni aprobado el resultado del gate**. Gate de receta reciente de ensayo + fuentes SHA congeladas + O5 sana + esquema live 0014; etiqueta imágenes anteriores, compila API/Web, `migrate --plan`, crea respaldo O5 cifrado nuevo y luego migra explícitamente `0015`, comprueba DB/API/Web/HTTP y rutas privadas 401/403; NO migración automática, NO despliegue de DB, NO rollback automático. Si falla tras migrar, verificar estado y NO repetir ciegamente. No usar script O8b.

Comando desde cuenta Ubuntu `vencira`: entrar checkout, `git fetch origin integration/local-e2e-prep`, `git merge --ff-only FETCH_HEAD`, ejecutar `bash scripts/check_o8c_deploy_static.sh`, después `sudo bash scripts/deploy_o8c_0015_guarded.sh`; recoger `RESULTADO_GLOBAL` y salida terminal. **Hasta que aparezca `O8C_DESPLIEGUE_0015_LOCALCHECK=OK` no afirmar implantación O8c.**

Tras éxito: UAT con datos DEMO: abrir una anotación activa, expandir simulador, guardar borrador `20,15`, salir y volver; comprobar persistencia solo en esa anotación, aislamiento de otras y ausencia de avisos enviados. Seguientes O9 preguntas de control, O10 notificaciones internas, O11 agenda HOY. Las decisiones de motivos, Vida, tardíos y canales siguen pendientes de aprobación.

**Regla de trabajo:** cambiar código y documentos directamente en GitHub mediante conexión; al usuario un único bloque Bash para puertas de control. Registrar cada resultado en `docs/NEXT_CHAT_HANDOFF.md` y mantener esta ficha breve al día. No repetir O5 ni O8b. Nunca solicitar ni exponer contraseñas/Restic/OAuth en el chat.
