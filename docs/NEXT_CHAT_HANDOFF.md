# VENCIRA — RESUMEN DE CONTINUIDAD PARA NUEVO CHAT

**Actualizado:** 24/10/2026, tras la confirmación manual de navegación en O7.  
**Propósito:** documento corto que el usuario puede enlazar o pegar en una nueva conversación para continuar exactamente donde quedó el trabajo, sin repetir requisitos, accesos, validaciones o pasos peligrosos.  
**Repositorio privado:** `appvencira/vencira_app` · rama `integration/local-e2e-prep`.  
**Fuentes completas:** `docs/CONTINUITY_RUNBOOK.md`, `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`, `docs/OPERATION_O7_RESULTS.md`, `docs/OPERATION_O8B_REMINDER_PREVIEW.md` y `docs/OPERATION_O5_DAILY_SCHEDULE.md`. Whitepaper original: `White_paper_agenda_vencimientos.pdf` (23 páginas, 18/10/2026).

## Cómo trabajar con el usuario (INSTRUCCIONES DE CONTINUIDAD)

- Hablar **en español**, técnico, práctico. El usuario quiere **máxima ejecución autónoma del código, pruebas y documentación en GitHub**, minimizando rondas.
- El asistente usa la **conexión GitHub** para leer/escribir código y documentación; **no** le pide al usuario que cree archivos manualmente. Usuario ejecuta **un bloque de comandos Bash completo** por prueba/despliegue en Ubuntu y comparte **solo marcadores de salida sin secretos**.
- Reutilizar lo ya respondido; no pedir preguntas repetidas. **No prometer trabajo en segundo plano ni afirmar despliegues o resultados sin salida del servidor**.
- **Preferencia expresa de continuidad:** antes de cambiar a un chat nuevo, dejar una ficha autocontenida y al día; actualizar este archivo **tras hitos significativos** para no depender del contexto del chat. No se puede detectar de forma fiable el límite interno de conversación, por lo que conviene ofrecer este handoff antes del cambio.
- Nunca imprimir/capturar/señalar contraseñas, rclone.conf, clave Restic, URL/códigos OAuth, cookies, datos reales o volcar logs sin revisar.

## Infraestructura y situación estable

- Stack: **Flutter Web (ES/CA), Django/DRF + PostgreSQL 17**, Docker Compose sobre Ubuntu; entorno `vencira_localcheck`, checkout `/home/vencira/vencira-localcheck`; web DEMO **https://dev.vencira.es/**. Rama GitHub arriba indicada.
- Otros proyectos Docker pueden coexistir. **NO TOCAR `vencira_preview`, Caddy, repositorios Restic ni bases ajenas. NO `docker compose down -v`**.
- API endurecida O4: arranca con **`python manage.py migrate --check --noinput`**, nunca migra al reinicio; esquema persistente actual **`reminders.0014_renewal_outcomes`**.
- **O5 backup operativo DEV**: PostgreSQL cifrado Restic a Drive mediante Rclone, OAuth renovado después de pasar Google a `In production`, snapshot original `7a2f5018` recuperado en PG17 aislado anteriormente; NUEVA copia post-OAuth real verificada. Timers activos: diario **03:00 Europe/Madrid** y auditoría de frescura **08:00 Europe/Madrid**. Marcadores `COPIA_TRAS_REAUTORIZACION=SI`, `SNAPSHOTS_POSTGRES_EN_RESTIC=OK`, `TIMERS_ACTIVOS_Y_HABILITADOS=OK`. **No reinstalar timers ni repetir reconexión OAuth**.
- Limitaciones O5: alerta de fallo solo **systemd/journal local** (no email/push externo), sin política automatizada `forget/prune`, sin segundo destino, residencia UE de Google Drive **no acreditada**, no utilizar **datos personales reales** hasta RGPD/MFA/almacenamiento UE verificados. Producción cada 6 horas es política propuesta/aprobada, NO activa.

## Producto y decisiones aprobadas

- VENCIRA = **agenda de vencimientos y avisos de pólizas externas**, no CRM, no gestión de cartera propia. Usuarios Individual/Equipo, por organización y responsable.
- O1–O3 y O6 operativa aceptadas; cuatro desenlaces O3: Conseguido, No aceptó (año próximo), Aún sin decidir (seguimiento), Descartar. **El titular aprobó recuperar del Archivo tanto Conseguidas como Descartadas** (ampliación frente al PDF).
- Archivo funcionalmente aceptado O6, pendiente política blanca del §12: por defecto eliminación a **2 años** de cierre, plazo configurable y avisos antes a 3 y 1 mes; no borrar automáticamente hoy.
- Whitepaper §7: avisos 60, 45 y 35 días por defecto y personalización individual. §8: fecha informativa **un mes civil antes** (no siempre 30 días) y pregunta de control en el último aviso anterior al límite. Casos tardíos, Vida, motivos e incumplimientos figuran en §18 como decisiones pendientes.
- Plan por fases y paralelo: ver `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`. Prioridad motor O8b/O8c→O9→O10; en paralelo UX agenda O11, Equipos O12, Excel/resultados O13, seguridad O14; nativo offline O15 y negocio/publicación O16.

## ESTADO VERIFICADO AL CIERRE DE ESTE CHAT

1. **O7 — Resultados web escritorio:** API agregada GET solo owner por mes/trimestre/año, sin PII, frontend Flutter ES/CA accesible en web >=800 px. Suite completa verde en SQLite/PG17 y Flutter. **DESPLEGADO en DEV** sobre SHA `b61e357f06b7396d1018cb072ef39b6bc0974777` tras rollout controlado: API/DB/web healthy, HTTP 200, endpoint anónimo 403, cero migraciones. **Aceptación manual parcial confirmada por el titular:** «Sí pude cambiar entre mes, trimestre y año». Quedan sin confirmar manualmente exactitud de cifras con registros ficticios y permisos de miembro de Equipo; no confundir con que la navegación sí está aceptada.
2. **O8a — Fechas puras:** límite legal civil, 60/45/35, pregunta en aviso válido, casos bisiestos: suite verde y lógica incluida en el despliegue anterior. **No entrega ni programa avisos.**
3. **O8b — Vista previa de anticipaciones por anotación:** código **EN GITHUB, NO DESPLEGADO, SIN PREFLIGHT DESPUÉS DEL ÚLTIMO CAMBIO**. Nuevos archivos `backend/reminders/reminder_planning.py`, `reminder_preview.py`, `test_reminder_planning.py`, `test_reminder_preview.py` y ruta GET de solo lectura `/api/v1/workspaces/<uuid>/renewals/<uuid>/reminder-preview/`. Acepta 1–12 días personalizados únicos (0–365), defaults 60/45/35, detecta retrasos, falta de pregunta pre-límite, marca modalidad Vida para revisión; no notificaciones, ni cambios de base, ni datos de contacto en salida. Ver `docs/OPERATION_O8B_REMINDER_PREVIEW.md`.
4. **Último rollout de O7/O8a:** controlado sin migraciones, `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, `HEALTH_api/db/web_preview=healthy`, `RESULTADO_GLOBAL=0`. Imágenes de recuperación `vencira-o7-pre-api:20261024T214020Z_2326206` y `vencira-o7-pre-web:20261024T214020Z_2326206`. Recibo local privado `/tmp/vencira-o7-o8-20261024T214020Z_2326206.bc7EwG0D.receipt`; **no ejecutar otra vez** `scripts/deploy_o7_o8_no_migrations.sh`: fue para ese SHA y ese gate.

## SIGUIENTE ACCIÓN CONCRETA (SIN DESPLEGAR)

**O8b preflight nuevo:** pedir UNA sola ejecución Bash a usuario, que haga:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  echo "COMMIT=$(git rev-parse HEAD)"
  bash -n scripts/validate_o7_o8_preflight.sh || exit 1
  bash scripts/validate_o7_o8_preflight.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
Esperar marcadores `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`. Si falla: corregir en GitHub y volver a probar; no saltar gates.

**Después:** continuar con lógica editable por anotación y motivos O8c (requiere especificar decisiones §18) y flujos O9/O10; en paralelo mejorar pantalla Inicio Agenda HOY O11 y robustecer seguridad. Si O8b se despliega, crear **nuevo script** de rollout seguro amarrado al SHA probado; **no** reutilizar el script O7/O8a. Si hay migración `0015`, primero O4: backup nuevo + restauración probada en PG17 aislado, migrate --plan, gate y migración explícita, sin auto-migraciones ni rollback ciego.

## Preguntas todavía abiertas del whitepaper (no presumir respuesta)

Motivos por defecto 60/45/35; recordatorios vencidos/no atendidos; alta tardía; ningún aviso antes del tope; excepciones Vida; repetición de «Comunicar no renovación»; permisos de empleados en resultados/Excel; conflictos offline y almacenamiento nativo cifrado; tamaño/seguridad de adjuntos; MFA, RGPD, supresión; residencia UE garantizada; proveedores de notificación; tarifas, pagos y sociedad titular.

## DOCUMENTACIÓN PRIORITARIA

- `docs/CONTINUITY_RUNBOOK.md` — registro técnico histórico completo, amplio.
- `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md` — requisitos §1–18 y planificación O7–O16.
- `docs/OPERATION_O8B_REMINDER_PREVIEW.md` — objetivo inmediato y criterios de pruebas.
- `docs/OPERATION_O7_RESULTS.md` — implementación y pruebas de O7, más aceptación manual de navegación.
- `docs/OPERATION_O5_DAILY_SCHEDULE.md` — copias automáticas DEV y límites.
- `docs/OPERATION_O4_MIGRATION_GUARD.md` — seguridad para futuras migraciones.

**Instrucción inicial para un nuevo chat:** «Continúa VENCIRA a partir de este documento de GitHub. Comprueba el HEAD de `integration/local-e2e-prep` y lee el runbook; no rehagas O1–O7 ni el backup O5. Valida primero O8b en Ubuntu, corrige lo que falle y desarrolla en paralelo las siguientes fases del whitepaper. Guarda todo el código y la documentación en GitHub; dame un único bloque Bash para cada gate. Mantén este resumen actualizado antes de pasar a otro chat». 
