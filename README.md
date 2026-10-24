# VENCIRA

> **Plan whitepaper 24/10/2026:** revisión completa de las 23 páginas y fases O7–O16 documentadas en [plan de ejecución](docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md). **O7 resultados agregados solo escritorio** y **O8a cálculo civil del límite legal y fechas 60/45/35** están versionados con tests, pero **aún sin preflight verde ni despliegue**. Ejecutar primero `scripts/validate_o7_o8_preflight.sh`; no aplicar migraciones ni comunicaciones. Ver [O7](docs/OPERATION_O7_RESULTS.md) y [O8a](docs/OPERATION_O8_DATE_ENGINE.md). La instalación de DEV y los backups O5 existentes continúan sin cambios.

> **24/10/2026 — O5 DEV operativo:** confirmadas copias PostgreSQL cifradas a Google Drive mediante Restic y OAuth renovado; copia inmediata posterior a autorización correcta, snapshot remoto nuevo verificado, temporizador diario **03:00 Europe/Madrid** y chequeo local **08:00 Europe/Madrid**, ambos activos y habilitados. Restauración aislada PG17 previamente probada. **Pendientes**: alertas externas, política automatizada de retención/poda, residencia UE verificada y preparación RGPD para información real. O6 Archivo aceptada, incluida recuperación de «Conseguido». El historial inferior puede reflejar estados anteriores; ver [operativa O5](docs/OPERATION_O5_DAILY_SCHEDULE.md) y [continuidad](docs/CONTINUITY_RUNBOOK.md).

> **Actualización 24/10/2026 — O5/O6:** O6 «Archivo» aceptada por el titular; se aprobó recuperar también «Conseguido». La cadencia propuesta de copias es DEV 24 h a las 03:00 Europe/Madrid y producción futura 6 h, pero **no hay aún temporizadores instalados/activados en el VPS**. La nueva automatización y sus gates de OAuth están preparadas en `docs/OPERATION_O5_DAILY_SCHEDULE.md`. Falta reautorizar el remoto Rclone existente tras pasar Google OAuth a In production y ejecutar el instalador controlado; no usar datos reales.


> **Estado 24/10/2026 (más reciente):** el titular confirma que el cliente Google OAuth `VENCIRA Internal Backups` está **In production** en Google Cloud y el sitio informativo `https://oauth.vencira.es/` dispone de HTTPS comprobado (las tres páginas HTTP 200). Esto **no es** un lanzamiento comercial de VENCIRA. `https://dev.vencira.es/` es accesible sin HTTP Basic Auth pero mantiene login Django y API anónima 403; **solo DEMO**. O5 cuenta con copia PostgreSQL cifrada/restaurada; **pendiente reautorizar el remoto Rclone con un token emitido tras publicación**, verificar snapshot existente y definir backups automáticos/retención/alertas. El desarrollo de producto continúa con **O6 «Archivo y cerrados»**: fuentes Flutter y tests en GitHub, aún **sin validación ni despliegue**. Ver `docs/OPERATION_O6_ARCHIVE.md` y `docs/CONTINUITY_RUNBOOK.md`. Los párrafos históricos inferiores describen estados anteriores y no sustituyen este hito.


**Continuidad entre conversaciones:** antes de desarrollar o desplegar, leer [docs/CONTINUITY_RUNBOOK.md](docs/CONTINUITY_RUNBOOK.md). Incluye rama vigente, PR/migraciones, servidor objetivo, validación local sin GitHub Actions, backups, despliegue y restricciones de seguridad.

**Anticipamos vencimientos. Creamos oportunidades.**

Proyecto comercial de gestión de vencimientos y seguimiento de oportunidades, inicialmente para mediadores de seguros.

**Repositorio único y privado:** `appvencira/vencira_app`. No se copiará ni sincronizará código con ninguna otra cuenta.

Estado (23/10/2026): **entorno de desarrollo DEV en `https://dev.vencira.es`**, bajo control de acceso adicional, con API Django/PostgreSQL 17 y Flutter Web. **O1, O2 y O3 validadas funcionalmente por el usuario desde Android y O4 (protección de migraciones automáticas) desplegada y verificada**; migraciones hasta `0014_renewal_outcomes` aplicadas en el stack aislado `vencira_localcheck`. No utilizar datos personales reales, no considerar apto para producción ni habilitar comunicaciones hasta completar seguridad, RGPD, cifrado externo de copias y otras puertas de lanzamiento.

## Tecnología
- Django 5.2 LTS, Python 3.12 y Django REST Framework.
- PostgreSQL 17 en red interna.
- Flutter para web y, en fases posteriores, móvil.
- Docker Compose local y GitHub Actions.

## Migraciones y arranque seguro (O4)

El arranque de API se endurece en O4 para **comprobar migraciones pendientes sin aplicarlas automáticamente** (`manage.py migrate --check --noinput`). Las migraciones futuras se ejecutarán expresamente, con preflight, respaldo y restauración comprobada, según [el procedimiento O4](docs/OPERATION_O4_MIGRATION_GUARD.md). **O4 ya está desplegada y comprobada en Ubuntu el 23/10/2026**: `API_RUNTIME_MIGRATE_POLICY=CHECK_ONLY`, respaldo del esquema O3 con restauración completa en PostgreSQL 17, 119 pruebas Django, API/DB/Web saludables y `RESULTADO_GLOBAL=0`. El arranque no aplica migraciones. Consulta [el acta O4](docs/OPERATION_O4_MIGRATION_GUARD.md).

## Copias externas cifradas (O5, validación DEV en curso)

El **24/10/2026** el titular confirmó que Google Drive de la cuenta interna `appvencira@gmail.com` está autorizado mediante Rclone con OAuth propio `drive.file`, que el repositorio Restic cifrado `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` fue creado, y que la prueba sintética de subida, recuperación y `restic check` fue correcta. La clave operativa está bajo root 0600 y el titular confirmó custodia externa de la clave de recuperación. **No repetir OAuth ni inicialización de Restic.**

**Primera copia real PostgreSQL DEV cifrada y restaurada (24/10/2026):** snapshot Restic `7a2f5018`, recuperación desde Drive en PG17 efímero sin red, 21 tablas públicas y esquema `0014_renewal_outcomes` verificados; `RESULTADO_EJECUCION=0`, DB original intacta. Scripts: `scripts/o5_backup_to_drive.sh` y `scripts/o5_restore_drill.sh`. **No hay copias diarias programadas ni cobertura de producción.** Antes de automatizar, confirmar en Google Auth Platform el publishing status de la app OAuth (External/Testing da refresh tokens de 7 días), asegurar renovación, establecer retención, alertas y recuperación independiente. Procedimiento y evidencia: [O5 Google Drive](docs/OPERATION_O5_DRIVE_BACKUPS.md). No enviar dumps descifrados a Drive, GitHub ni al chat.

## Primer arranque
```bash
python3 scripts/init_env.py
docker compose up --build -d
curl -fsS http://127.0.0.1:18731/api/health/
curl -fsS http://127.0.0.1:18731/api/ready/
```

Documentación: [desarrollo](docs/LOCAL_DEVELOPMENT.md), [arquitectura](docs/ARCHITECTURE.md), [seguridad](docs/SECURITY.md), [API](docs/API_MVP.md).

Dominio elegido: `vencira.es`; pedido OVHcloud 20/10/2026 pendiente de confirmación de activación. Correo previsto: `soporte@vencira.es`, aún no configurado.

## API y cliente Flutter

Autenticación provisional por sesión Django y API v1 de vencimientos restringida a miembros. Flutter dispone de un panel para consultar, crear y editar vencimientos, con acceso por sesión, CSRF, paginación, distinción entre vencimiento y preaviso y cierre de sesión. El proxy de mismo origen y su integración HTTP se verifican en CI. Consulta [clients/flutter/README.md](clients/flutter/README.md).

**No habilitar públicamente ni usar datos reales.** El login solo tiene una defensa provisional, la auditoría se limita a la API y faltan MFA, controles RGPD, retención y copias externas.

## Web y API desde una sola dirección local

Se añade `compose.web.yaml` con proxy Nginx en `http://127.0.0.1:18732`. Compila Flutter Web antes de arrancar el proxy. Procedimiento, verificación HTTP autenticada y limitaciones en [docs/WEB_LOCAL.md](docs/WEB_LOCAL.md).

## Primera prueba en servidor aislado

Para probar sin instalar Flutter en el anfitrión, existe [**docs/SERVER_PREVIEW.md**](docs/SERVER_PREVIEW.md) con `compose.preview.yaml`, build Docker multi-stage, usuario y contratos sintéticos, y acceso por túnel SSH. Los puertos locales 18731/18732 no interfieren con MASBITCOIN. **Actualización (23/10/2026):** esa descripción corresponde al primer prototipo. Ya existe un entorno de prueba remoto separado, `vencira_localcheck`, accesible mediante `dev.vencira.es`, con O1–O3 instaladas y validadas. No confundirlo con producción ni con `vencira_preview`. El estado operativo y las medidas de protección vigentes se documentan en [`docs/CONTINUITY_RUNBOOK.md`](docs/CONTINUITY_RUNBOOK.md).
