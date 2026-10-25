# VENCIRA — CONTINUIDAD OPERATIVA (leer al comenzar un chat)

> **LECTURA PRIORITARIA / CORTE VIGENTE 25/10/2026.** Consultar primero [cierre B y handoff C](HANDOFF_MACROFASE_C_2026-10-25.md), [auditoría C0](MACROFASE_C_C0_AUDITORIA_2026-10-25.md) y [maestro actualizado](WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md). Todo lo que figura debajo de esta cabecera es **cronología de operaciones**, no estado operativo vigente: las entradas tempranas (p. ej. «O8c 0015 pendiente») están superadas. **A y B cerradas/aceptadas por el usuario**; cierre B premium sin inventar recibo ausente. **Esquema DEV documentado: 0018**, pendiente confirmación live antes de tocar BD. **C0** auditoría estática documentada, **C1** decisiones §18 aún abiertas, **C2–C3** sin iniciar. Control Sí/No manual y repetición interna YA existen; ninguna entrega real de email/push/local/offline. Conservar histórico íntegro y no repetir despliegues, O5/OAuth/Caddy ni migraciones. Fuente primaria normativa de producto: [whitepaper original transcrito](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md), sin cambios.


## Estado confirmado el 25/10/2026 — O8c DEPLOY DEV CORRECTO; aceptación manual pendiente

**EVIDENCIA REAL aportada por el usuario** al ejecutar `scripts/deploy_o8c_0015_guarded.sh` sobre fuente `9c404380e5801d8f9fd2d4dfe260d51df78264d6`: `RECIBO_RESTAURACION_O8C_VALIDO=OK`, `O5_CIFRADO_ACTIVO=OK`, `IMAGENES_O8B_CONSERVADAS=OK`, `BUILD_API_WEB=OK`, `PLAN_MIGRACION_0015=OK`, `BACKUP_O5_PRE0015_FRESCO=OK`, `APLICAR_0015_EXPLICITAMENTE=OK`, `MIGRACION_0015_VERIFICADA=OK`, `TABLA_BORRADORES_VACIA_Y_RESTRINGIDA=OK`, `CHECK_MIGRACIONES_POST0015=OK`, `API_O8C_DESPLEGADA=OK`, `FLUTTER_WEB_O8C_DESPLEGADA=OK`, `POSTGRES_0015_SIN_REINICIO=OK`, `ENDPOINTS_PRIVADOS_PROTEGIDOS=OK` (HTTP 403 sin sesión para O7/O8b/O8c/O3), `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, proxy local 200 y `DEV_VENCIRA_HTTPS_HTTP=200`, `O8C_GUARDADO_SOLO_BORRADOR=OK`, `O8C_DESPLIEGUE_0015_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. PostgreSQL LIVE está ahora en `reminders.0015_renewal_reminder_drafts`, **no 0014**. NO volver a ejecutar la migración ni el script de despliegue.

**Recibo local privado** `/tmp/vencira-o8c-deploy.gst32W6O.receipt`, **log** `/tmp/vencira-o8c-deploy.6ggUPoJg.log`. Imágenes anteriores recuperables: `vencira-o8c-before-api:20261025T061256Z_2623430` y `vencira-o8c-before-web:20261025T061256Z_2623430`. Se realizó copia cifrada O5 nueva antes de migrar y no se cambiaron timers, Caddy u OAuth.

**Pendiente únicamente UAT funcional O8c (NO afirmarlo aceptado):** abrir `https://dev.vencira.es/` con anotación ficticia abierta, expandir «Simular avisos de vencimiento», localizar «Guardar borrador de avisos», escribir `20,15` y guardar. Debe figurar borrador guardado; salir/volver y comprobar persistencia solo de esa anotación; otra anotación debe mantener defaults 60/45/35. Verificar que no existe notificación enviada, programada ni regla habilitada. Simulación O8b sigue temporal/no persistente; O8c solo guarda días como **draft**. Si falla UAT, corregir sin volver a aplicar 0015.

**Fuente rápida para nuevo chat:** `docs/NEXT_CHAT_HANDOFF_SHORT.md`. Siguiente bloque tras UAT: O9, revisión de preguntas de control, plazos/repeticiones y decisiones whitepaper §18, sin activar notificaciones prematuramente.


Fecha de revisión: 2026-10-24. Fuente de verdad: repositorio privado `appvencira/vencira_app`, rama `integration/local-e2e-prep`. Este documento describe **estado probado en GitHub y pasos pendientes**, no garantiza el estado de un servidor.

## CONTRATO DE TRABAJO PERMANENTE — obligatorio en todos los chats

**Esta sección gobierna la colaboración de VENCIRA y debe conservarse, actualizarse y consultarse al iniciar cualquier chat.** No depende de recordar la conversación anterior.

1. **Todo debe quedar documentado en GitHub.** Cada decisión técnica o funcional, corrección, cambio de arquitectura, comando que funcionó o falló, configuración/despliegue, versión/SHA, pruebas y resultados, pendientes y riesgos debe anotarse en documentación versionada (`docs/CONTINUITY_RUNBOOK.md` y el documento temático pertinente). **Actualizar la documentación en el mismo ciclo que el cambio; nunca dejarla para una hipotética conversación posterior.** Si cambia el flujo de trabajo, documentar también el nuevo flujo.
2. **Continuidad entre nuevos chats.** Comenzar leyendo este runbook, luego README y archivos específicos relevantes desde el repositorio **privado correcto** `appvencira/vencira_app`. Distinguir: código subido, probado, desplegado, validado por usuario y pendiente. Reanudar desde último hito comprobado sin reiniciar preguntas ni repetir trabajos.
3. **El asistente realiza directamente el desarrollo.** Inspeccionar, crear, editar, auditar y documentar fuentes en GitHub con el conector disponible; resolver fallos detectados antes de pedir instrucciones de terminal al usuario. No delegar programación, búsqueda del código, edición de fuentes ni tareas de GitHub en el usuario.
4. **Intervención local mínima, idealmente una por fase.** Cuando sea imprescindible ejecutar en Ubuntu del usuario, entregar **un único bloque/script integral** que reúna todas las verificaciones disponibles de esa fase (entorno/identidad, versión, permisos, build, pruebas, migraciones, salud, HTTP, etc.). Solo dividir cuando lo exijan seguridad, dependencia de resultados o riesgo de despliegue.
5. **Scripts robustos y salidas compactas.** En comandos pegados en SSH envolver ejecución en subshell `( ... )` y emitir `CONSOLA_ABIERTA` fuera de él; evitar `set -e`, `exit` o trampas que puedan finalizar la shell del usuario. Que el bloque compruebe errores, imprima fases, devuelva un resumen de estados y permita entregar **toda la salida en un solo envío**; evitar inundar con registros irrelevantes. Jamás imprimir secretos, cookies, contraseñas, tokens o PII en logs.
6. **Separar pruebas de despliegue.** Primero preparar cambios y probar en aislamiento, luego confirmar backup, proyecto Compose, plan de migraciones; solo después aplicar cambios persistentes. Evitar órdenes mutantes si aún falta evidencia crítica. Nunca confundir `vencira_localcheck` con `vencira_preview`. Respetar la cuota agotada de GitHub Actions.
7. **Pruebas completas y verificables.** Cuando proceda: Python/Django, PostgreSQL temporal o test DB, Flutter analyze/test/build, revisión de migraciones, servicios health, rutas HTTPS, permisos y ensayo funcional Android con datos ficticios. No afirmar que un paso está superado por inferencia: respaldarlo con resultado real.
8. **Cierre obligatorio de cada fase.** Registrar qué cambió, SHA/branch, qué se validó, salida/resumen aportado por usuario, situación real en servidor, limitaciones y **siguiente paso inequívoco**. Ajustar instrucciones previas marcadas «pendientes» cuando ya estén terminadas para que el documento no contradiga el estado actual.
9. **Seguridad permanente.** No usar datos personales reales ni habilitar adjuntos, notificaciones reales o producción hasta superar las puertas de seguridad y RGPD. No publicar información sensible aparecida en capturas o logs.
10. **Prioridad de experiencia de usuario:** ahorrar pasos, consolidar ejecuciones, dar órdenes reproducibles y encargarse de documentación y soluciones. El usuario aporta resultados de servidor preferiblemente una sola vez por ronda.

**Estado vigente 2026-10-24:** O1/O2/O3 validadas; O4 desplegada y verificada, PG17 migración `0014`, API/DB/Web healthy, sin migraciones automáticas. O5: Restic `0.19.1`, Rclone `1.60.1`, OAuth Google Drive **verificado** sobre cuenta interna `appvencira@gmail.com`, remoto `vencira_google` con `drive.file`, acceso Rclone y token correcto. **Sin repositorio cifrado Restic remoto ni backup PostgreSQL confirmado.** Último intento de `scripts/o5_init_restic_drive.sh` en checkout `b2d0bf698ff208a2986aab24d9cc99563e3ebad7` abortó en `CUSTODIA_CLAVE` con Python `io.UnsupportedOperation: File or stream is not seekable`, `RESULTADO_GLOBAL=1` / `RESULTADO_EJECUCION=1`; `CLAVE_PRIVADA_EN_SERVIDOR=0`, `REPO_RESTIC_REMOTO_INICIALIZADO=0`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA=0`, `POSTGRES_NO_RESPALDADO_AUN=1`. No se generó clave persistente ni repo/backup; no tocar OAuth ni DB. **Corregido en GitHub `scripts/o5_init_restic_drive.sh` commit `48a95556d7cbd4c5cc026824a04cf734eb77508a`**: `/dev/tty` lectura/escritura ahora separadas (ya no `r+`), mantiene reentrada oculta y confirmación externa de clave, probado en pseudo-tty aislada (`exit 0`, clave guardada). **Próxima acción** sincronizar GitHub, `bash -n` y ejecutar corregido `sudo bash scripts/o5_init_restic_drive.sh` en subshell. Escribir 256 bits de recuperación solo en gestor externo a Ubuntu/Drive y no copiar transcripción al chat; compartir únicamente marcadores de estado. **Si falla tras guardar clave o repo no reintentar**. Solo tras prueba cifrada/restauración remota sintética: primera copia de PostgreSQL, ensayo PG17 efímero, y luego gestionar OAuth *In production* antes de backups recurrentes; datos reales/producción siguen prohibidos. Documento `docs/OPERATION_O5_DRIVE_BACKUPS.md`.


## Incidencia real de git status — Flutter genera archivos locales

- Usuario confirmó `RAMA_LOCAL=integration/local-e2e-prep` y `ESTADO_GIT=CAMBIOS_LOCALES` debido exclusivamente a cuatro archivos **untracked**: `clients/flutter/lib/l10n/app_localizations.dart`, `app_localizations_ca.dart`, `app_localizations_es.dart` y `clients/flutter/pubspec.lock`. `RESULTADO_GLOBAL=3`, `FASE_FALLIDA=GIT_WORKTREE`; no se ejecutaron pruebas ni despliegue.
- Se revisaron `clients/flutter/pubspec.yaml` (`flutter: generate: true`), `clients/flutter/l10n.yaml` (ARBs como fuente) y `.gitignore`. Los tres `app_localizations*.dart` se generan con Flutter; agregados a `.gitignore` en commit `a209f51c`.
- El lock `pubspec.lock` es generado localmente y todavía no está versionado: por ahora permitido **solo de forma explícita** por script, no ignorado globalmente; documentar posterior decisión sobre fijar dependencias para release. Cambio de preflight en `scripts/validate_ui_v2.sh` commit `c0bdca16`: bloquea cambios de archivos versionados, staged y cualquier otro archivo nuevo, pero acepta únicamente el lock local y las traducciones generadas ya ignoradas. **Nunca hacer `git clean` ni `git reset --hard` sobre el servidor para superar un preflight.**
- Nueva ejecución pendiente: sincronizar código y ejecutar script consolidado; si Flutter analyze/test/build falla, arreglar fuentes en GitHub; solo desplegar Web después de todos los tests. Mantener consola SSH abierta.

## Incidencia de preflight UI V2 — pendiente de diagnóstico

- Usuario ejecutó `scripts/validate_ui_v2.sh` después de sincronizar el repositorio. Salida: `=== REPOSITORIO Y PRECONDICIONES ===`, `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=inicio`, `EJECUCION_COMPLETADA=0`. **No comenzó Flutter ni despliegue.** Se desconoce aún cuál condición inicial falló.
- El script original usaba `test "$(git branch --show-current)"` y `test -z "$(git status --porcelain)"` sin explicación. Corregido en commit `3ce75938` con diagnóstico explícito de rama, limpieza del checkout y servicio que se está verificando, sin tocar cambios locales ni cerrar SSH.
- Pedir una sola ejecución para sincronizar el script nuevo y obtener el motivo concreto. No ejecutar `git reset --hard`, `git clean` ni borrar trabajos locales automáticamente. No dar por desplegada V2 hasta pruebas Flutter y salud.

## Diseño V2 — rediseño estructural tras feedback de capturas

- El usuario señaló explícitamente que la UI existente **NO parece limpia ni bien estructurada**: exceso de botones heterogéneos, apilados y selectores; quiere un salto visual de calidad empresarial. Solicitó buscar más webs además de Dribbble.
- Investigación, fuentes, decisiones de UX y próximos pasos: **`docs/DESIGN_SYSTEM_V2.md`** (incluye Dribbble, Mobbin, SaaS Interface, SaaSUI, Notion Calendar, Fantastical y Linear).
- Cambios Flutter ya escritos en `integration/local-e2e-prep`:
  - `a067d60d` / `85507535`: inicio con jerarquía compacta, fila Agenda/Añadir, administración plegable y filtros avanzados plegados en móvil pero visibles en escritorio.
  - `e734502b`: filtros plegables en la agenda diaria móvil, encabezado de fecha enfatizado.
  - `20f15763`: calendario mensual con cuadrícula menos abultada y superficies sin recuadros grises redundantes.
- **Todavía no se han probado ni desplegado estos cambios V2.** No afirmar éxito ni presentar capturas anteriores como prueba de la nueva versión.
- Se creó **`scripts/validate_ui_v2.sh`** (commit `00747154`): script integral reejecutable, ejecutado por `bash` como proceso hijo para no cerrar SSH. Verifica checkout limpio/rama, identidad de los tres contenedores, configuración Compose, Flutter pub get/analyze/test/build, reconstruye **solo Web** tras pruebas, valida health de API/DB/Web y HTTP 200, registra log en `/tmp`, informa `RESULTADO_GLOBAL` y `CONSOLA_ABIERTA`. No aplica migraciones ni recrea API/DB.
- **Próxima acción única del usuario** (si servidor disponible): `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep && git merge --ff-only FETCH_HEAD && bash scripts/validate_ui_v2.sh ); echo CONSOLA_ABIERTA`. Comprobar salida. Si falla, asistente corrige en GitHub y solicita una única repetición.
- Después de éxito técnico: probar en Android `https://dev.vencira.es` inicio, agenda diaria, mes y editor; recoger capturas y valorar design V2. Luego continuar diseño integral del editor/ficha con el mismo criterio.

## Línea de diseño empresarial — prioridad de producto

**Objetivo:** VENCIRA debe sentirse como un software de empresa elegante, claro, moderno, intuitivo y confiable, no un prototipo. Funcionalidad y experiencia visual tienen igual importancia en los criterios de aceptación.

- **Jerarquía:** acción primaria inequívoca, acciones secundarias discretas, títulos y secciones comprensibles; no competir visualmente con demasiados botones.
- **Consistencia:** tokens globales para color, tipografía, radios, bordes, estados, superficies, densidad, espacios y controles; temas claro y oscuro contrastados. Evitar colores fijos dispersos.
- **Móvil primero:** controles táctiles de al menos 48 px, formularios legibles, teclado apropiado, navegación comprensible, scroll correcto y modales que no corten acciones ni solapen etiquetas, ayudas o contadores.
- **Formularios profesionales:** grupos semánticos, ayudas junto a sus controles sin superposición, validación específica, estados de carga/guardado, botones visibles y ancho adecuado para tablet/escritorio.
- **Accesibilidad y confianza:** contraste, escalado de texto, feedback de éxito/error, foco visible, estados vacíos y de carga claros; datos ficticios durante desarrollo.
- **Validación por fase:** Flutter analyze/test/build y, cuando hay cambio de layout, inspección visual real Android y escritorio antes de considerar diseño aprobado.
- **Evolución:** conservar funcionalidad, identidad de marca VENCIRA y textos locales; evitar rediseños masivos sin cobertura. Documentar cambios, pruebas, screenshots y pendientes.
- **Estado diseño en GitHub, no desplegado:** commit `dd9ba521` corregía espaciado/ayuda de referencia; commit `f43766d9` introduce tokens empresariales compartidos en tema (diálogos, botones, campos). Ambos **pendientes de validación y despliegue**.
- **Próximos pases:** simplificar dashboard y filtros en móvil, jerarquía de CTA, agrupación de campos del editor, tratamiento del modal largo, revisar estados vacíos y oscuro/claro.

## Objetivo y normas permanentes

VENCIRA es agenda multiplataforma (Flutter + Django/PostgreSQL) de pólizas externas individuales, **no CRM**. Seguir el whitepaper original, especialmente §6: Clientes/Candidatos, identificación, modalidad/aseguradora personalizadas, fechas, estado, responsable, notas y adjuntos seguros. Los datos de anotaciones distintas **no están vinculados**: las sugerencias copian por decisión explícita sin sincronizar registros.

**Forma de trabajo acordada:** asistente desarrolla y actualiza GitHub; realiza cuanto pueda de forma autónoma. Pedir al usuario **solo bloques de consola para comprobaciones o despliegues que requieren su servidor**, nunca inspecciones repetidas que ya podamos efectuar desde GitHub. El usuario pega salidas; el asistente interpreta, corrige en GitHub, repite pruebas si procede. Mantener cambios documentados, comandos reproducibles y reversión. Evitar datos personales reales hasta pasar barreras de seguridad.

## Repositorio, ramas y cambios validados

- Integración: `integration/local-e2e-prep`; los PR de la fase están fusionados.
- PR #11 (identidad): commit de fusión `47f30738fa8eaa27e9a5304bf8c62b1b263d1c65`. Campos `full_name`, `nickname`, `phone`, `email`, `policy_number`; migración `0011_renewal_policy_identity`; serializador, editor Flutter y búsqueda; CI #79 verde.
- PR #12 (notas): commit `8eed7f47597f511543414b09628e578d91110658`. Migración `0012_renewal_notes`; editor y lectura, hasta 4000 caracteres desde API; CI #80 verde. Adjuntos **solo especificación**, aún desactivados: `docs/ATTACHMENTS_SECURITY_GATE.md`.
- PR #13 (sugerencias): commit `189065aa166e9ffd948fde1e28114e6eb48bc5d5`. Sin migración. Endpoint y Flutter para copiar contacto desde anotaciones visibles. Pruebas locales: Django 105 tests OK, Flutter analyze/test/build web OK.
- `0010_workspace_insurer` ya existe en integración; el servidor anterior estaba solamente hasta `0009_workspace_modality`.
- **GitHub Actions tiene la cuota agotada**: no volver a activar o depender de ejecuciones CI; preferir Docker local efímero. No afirmar CI verde para commits posteriores sin evidencia.

## Servidor conocido (solo descripción histórica, volver a comprobar antes de escribir)

- Usuario `vencira`, Ubuntu. Checkout correcto `/home/vencira/vencira-localcheck`, con remoto SSH de solo lectura `git@github-vencira-ro:appvencira/vencira_app.git`. Antes de esta fase rama `integration/local-e2e-prep`, commit `5d48225696f2ba426ba8eb6346b9123a12d3c9ad`, limpio. El remoto puede haber avanzado: comprobar FETCH_HEAD y origin.
- Contenedores del stack a conservar: `vencira_localcheck-api-1`, `vencira_localcheck-db-1`, `vencira_localcheck-web_preview-1`. **Existen también contenedores `vencira_preview-*` de otra instalación**. Jamás confundir stacks, volúmenes ni nombres Compose.
- Otro checkout: `/home/vencira/vencira-preview` con código más antiguo; **no usar para este despliegue**.
- Backups históricos: `/home/vencira/vencira-db-backups/`. Realizar nuevo `pg_dump -Fc` de la base del stack correcto, comprobar `pg_restore -l`, guardar `sha256sum` y permisos 600, antes de construir/reiniciar/aplicar migraciones.
- Los contenedores API ejecutan `python manage.py migrate --noinput` al arrancar (ver `compose.yaml`): **un `docker compose up --build -d` puede aplicar migraciones automáticamente**. No construir ni levantar API conectada a PostgreSQL existente antes de disponer de backup probado.
- Las pruebas recientes usaron worktree efímero `/tmp/vencira-suggestions.RIC9UU/source`, imagen `vencira-suggestions-check:local` y Flutter mediante `ghcr.io/cirruslabs/flutter:stable`. El worktree no es despliegue.
- No usar GitHub Actions; verificar Docker local con SQLite y, cuando proceda, PostgreSQL efímero `-p` exclusivo distinto de los nombres Compose presentes.

## Última evidencia del servidor

- Usuario confirmó `BACKUP_VERIFICADO=1` tras `pg_dump -Fc` y `pg_restore -l` en el contenedor validado `vencira_localcheck-db-1`.
- Archivo: `/home/vencira/vencira-db-backups/pre0010-0012_uti0uvWX.dump`.
- Al finalizar el respaldo indicó `DESPLIEGUE_AUN_NO_REALIZADO=1`. **No confundir respaldo con migración.**
- La verificación de restauración integral todavía está pendiente; `pg_restore -l` verifica la lectura del índice, no la restauración completa.

## Pasos siguientes del despliegue (todavía NO realizados)

1. Desde servidor, lectura única: comprobar rama, remoto, checkout limpio, `git fetch`, `git rev-parse HEAD` y `origin/integration/local-e2e-prep`; ver nombres exactos de proyectos y Compose con `docker compose ls`, `docker inspect` y `docker ps` antes de mutar.
2. Usar checkout/imagen **aislados** para confirmar Django check/makemigrations/test, incluyendo migraciones 0010–0012 con PostgreSQL temporal, y Flutter analyze/test/build. La prueba 105/Flutter ya se realizó sobre #13; repetir sobre SHA definitivo si cambia.
3. Backup `pg_dump -Fc` desde **la BD localcheck**; verificar con `pg_restore -l`, checksum, propietario/permisos. Evitar comandos que cambien contenedores `vencira_preview-*`.
4. Comprobar plan SQL con `manage.py migrate --plan` en entorno correcto; revisar cambios antes de aplicar. Actualizar únicamente stack localcheck, vigilar salud, registros y `showmigrations`.
5. Probar APIs, catálogo, notas, identidad, sugerencias, autenticación, aislamiento y dispositivo Android con **datos ficticios**. Preparar procedimiento de restauración; no intentar revertir migraciones destructivamente.
6. Registrar SHA desplegado, fecha, resultado de comandos, identificador no sensible de backup, estado de migraciones y estado posterior en este archivo o bitácora específica.

## Incidencia resuelta en código, pendiente de repetir prueba local

- Primer intento de construir la API nueva: `PermissionError: [Errno 13] Permission denied: '/app/reminders/models.py'`, antes de `showmigrations`. Ninguna migración aplicada; no se reiniciaron contenedores.
- Causa: Dockerfile copiaba los fuentes con el propietario del contexto y después ejecutaba como usuario `vencira` sin permiso para leer algún archivo.
- Corrección integrada en `integration/local-e2e-prep`: commit `9205ed03269b5bce5f3edef704e9b229fecf1a52`, `COPY --chown=vencira:vencira . /app`.
- Próximo paso: sincronizar ese commit, reconstruir solo la imagen, comprobar lectura de código en un contenedor efímero y volver a ejecutar `showmigrations` y `migrate --plan` sin aplicar.

## Hito confirmado por usuario: migraciones de localcheck

- La imagen API reconstruida leyó correctamente `/app/reminders/models.py` (`LECTURA_MODELS_OK=True`).
- Plan confirmado: `0010_workspace_insurer` (catálogo + relación), `0011_renewal_policy_identity` (cinco campos), `0012_renewal_notes` (notas), sin borrados previstos.
- El usuario ejecutó bloque con validación SHA-256 del backup, identidad del proyecto Docker, `migrate --noinput`, `showmigrations` y `migrate --plan`; informó `MIGRACIONES_VERIFICADAS=1` y `CONSOLA_ABIERTA`.
- **API y Flutter Web del stack persistente aún no se han recreado.** Siguiente paso: reconstruir/actualizar `api` y `web_preview` solo con `-p vencira_localcheck`; comprobar salud, migraciones y rutas. Mantener el backup `pre0010-0012_uti0uvWX.dump` intacto.
- No se han activado adjuntos ni habilitado uso con datos personales reales.

## Despliegue localcheck — evidencia de servicios

- Usuario confirmó `ACTUALIZACION_SERVICIOS_COMPLETADA=1` tras `docker compose -p vencira_localcheck ... up -d --no-deps api` y `up -d --no-deps --build web_preview`.
- API `vencira_localcheck-api-1`: `running/healthy`, ligado a `127.0.0.1:28731`.
- PostgreSQL `vencira_localcheck-db-1`: `running/healthy`, sin puerto público.
- Web `vencira_localcheck-web_preview-1`: `running/starting` inmediatamente tras recreación, ligado a `127.0.0.1:28732`. **Pendiente demostrar healthy y HTTP end-to-end**.
- Stack `vencira_preview` conservado por separado en `127.0.0.1:18731/18732`.
- `nginx -t` y `manage.py check` superados en el bloque completo que el usuario ejecutó; `migrate --plan` se invocó, pero la salida textual no se adjuntó.
- Confirmación final pendiente: salud Web estable, HTTP /api/health /api/ready a través del proxy, autenticación/E2E con datos sintéticos, Android. No activar datos reales.

## Verificación posterior al despliegue — completada

Confirmado por salida del servidor: `vencira_localcheck-web_preview-1` **healthy**; API `/api/health/` y `/api/ready/` en `127.0.0.1:28731` devuelven 200. Proxy web `127.0.0.1:28732` devuelve HTTP 200 para `/`, `/api/health/`, `/api/ready/` y `/accounts/login/`. `python manage.py migrate --plan`: **No planned migration operations**. Resultado `COMPROBACION_FINALIZADA=1`, `CONSOLA_ABIERTA`.

**Queda pendiente** prueba funcional autenticada de identidad, notas, sugerencias y permisos con datos sintéticos; esta verificación HTTP por sí sola no valida funcionalidad de negocio. No introducir datos personales reales.

## Pruebas PostgreSQL posteriores al despliegue

- El usuario ejecutó las pruebas Django `reminders.test_policy_identity` y `reminders.test_person_suggestions` mediante contenedor efímero apuntado al servicio PostgreSQL de `vencira_localcheck`.
- Resultado confirmado: `Destroying test database for alias 'default'...`, `RESULTADO_POSTGRESQL=0` y `CONSOLA_ABIERTA`.
- Django utiliza una base de pruebas separada y la elimina al terminar. No constan fallos.
- Pendiente: validación visual y funcional desde Android bajo acceso restringido, usando solo datos ficticios.

## Acceso Android confirmado por usuario

- El usuario confirma que el acceso **HTTPS `https://dev.vencira.es` ya está configurado** y existe un usuario de prueba. **No volver a pedir Termius, Termux, Chrome ni crear un túnel SSH** para la verificación Android.
- Usar esa URL para pruebas visuales y funcionales con **datos ficticios**; verificar inicio de sesión, creación/edición de anotación, identidad, modalidad, aseguradora, notas y copia manual de contactos.
- No suponer que el host público apunta al stack `vencira_localcheck` actualizado sin evidencia de la versión servida. Antes de dar por validado el acceso externo, comprobar funcionalmente en navegador y, si procede, cotejar cabeceras/respuestas sin divulgar credenciales.
- No introducir datos personales reales hasta cerrar barreras de seguridad.

## Android / HTTPS: comprobación funcional confirmada por usuario

- El usuario reporta **«Todo ok»** desde Chrome Android en **https://dev.vencira.es** y aporta capturas de la página principal y del formulario **Editar vencimiento**.
- Las capturas muestran campos de identidad, número de póliza, botón «Buscar datos en otras anotaciones», selector de entrada, modalidad, aseguradora, notas con límite 4000 y fechas de vencimiento/preaviso. Es evidencia de que el frontend desplegado incluye las características recientes.
- El usuario confirma la prueba funcional; no hay error informado de guardado. No se han verificado mediante captura separada todos los casos de aislamiento de registros, que sí cuentan con pruebas backend.
- **Mejora visual no bloqueante:** en una captura móvil, el mensaje de ayuda bajo «Referencia» se solapa con la etiqueta «Nombre y apellidos o razón social». Revisar espaciado vertical del formulario y disposición del modal en pantallas pequeñas.
- No copiar a documentación valores de nombre, contacto ni número de póliza visibles en las capturas. No utilizar datos personales reales hasta aprobación de seguridad/RGPD.
- Estado: **despliegue técnico + smoke web + pruebas Django/PostgreSQL + aceptación funcional Android confirmados**. Aún no equivale a autorización de producción.

## Pase visual empresarial: validación y despliegue web completados

- Cambios: `dd9ba521` (espaciado del editor en móvil), `f43766d9` (tokens globales de diálogos, botones y campos), `a18024ac` (normativa visual y criterios).
- El usuario ejecutó el bloque consolidado de `git fetch/merge --ff-only`, Flutter `pub get`, `analyze`, `test` y `build web --release --pwa-strategy=none`, comprobación de identidad del proyecto Docker, build de `web_preview`, recreación exclusiva de web, espera de estado `healthy` y HTTP 200 de `/`, `/api/health/` y `/api/ready/`.
- Resultado confirmado: `RESULTADO_GLOBAL=0`, `RESULTADO_SCRIPT=0` y `CONSOLA_ABIERTA`. **Primera fase visual desplegada en `vencira_localcheck`; no modifica API/DB ni el stack `vencira_preview`.**
- Pendiente: aceptación visual desde Android con capturas (formularios, solapamientos, scroll y botones), y siguiente pase de UX en dashboard y editor. No confundir código compilado con aprobación visual.
- Mantener procedimiento de **un script integral por fase** con todas las comprobaciones posibles, salida agrupada y protección de la sesión SSH.

## UI V2 — desplegada y validada técnicamente en servidor

- El usuario ejecutó la actualización a `5fcbfd82c3633a15019082b88949cc57d86c4689`, que incluye cambios de `dashboard_screen.dart`, `day_agenda_screen.dart`, `month_agenda_screen.dart`, `docs/DESIGN_SYSTEM_V2.md`, script de verificación y solución de archivos Flutter generados.
- Reportó desde `scripts/validate_ui_v2.sh`: rama correcta, lock local admitido, fuentes versionadas limpias, Docker Compose correcto; Flutter pub get/analyze/test/build `OK`; web build/deploy `OK`; `WEB_HEALTH=healthy`; proxy HTTP 200 en `/`, `/api/health/`, `/api/ready/`, `/accounts/login/`; salud `api/db/web_preview=healthy`.
- `DESPLIEGUE_WEB_LOCALCHECK=OK`, `SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1`, `RESULTADO_GLOBAL=0`, `EJECUCION_COMPLETADA=1`, `CONSOLA_ABIERTA`. Log servidor: `/tmp/vencira-ui-v2.QGWdavHA.log`.
- **No pedir repetir pruebas técnicas recién superadas.** La aprobación visual es distinta de la técnica: solicitar comparación y capturas Android de panel, agenda y calendario en `https://dev.vencira.es`, revisar si los filtros están colapsados y si se redujo el exceso de botones.
- **Siguiente fase objetivo:** pulido de fichas, editor y calendario hasta experiencia corporativa cuidada; todo implementado/documentado primero en GitHub y verificado con un script consolidado por fase. No usar datos reales.

## V3 premium — código implementado, pendiente de pruebas locales

**Contexto:** tras revisar capturas de Android del rediseño V2 (salud técnica correcta), el usuario pidió elevar calidad y profesionalidad: eliminar campos con borde duro, evitar rectángulos de calendario y colorear **el día entero** según los puntos de actividad. Solicita ejecución autónoma y un único script local por fase.

- Fuente técnica/diseño: [`docs/DESIGN_SYSTEM_V3.md`](DESIGN_SYSTEM_V3.md) (paleta, semántica de calendario, accesibilidad, referencias Notion/Fantastical/Linear, pantallas, pruebas, commits, procedimiento).
- Cambios ya en GitHub `integration/local-e2e-prep`, **NO probados ni desplegados en el servidor al escribir esto**:
  - Tema V3: base petróleo, superficies quietas claro/oscuro, campos rellenos suaves sin contorno persistente, radios, botones, tarjetas y focus accesible (`vencira_theme.dart`, `224aeaf2`, `3630a7d3`).
  - Mes: casillas 1:1, tintado íntegro prioritario vencimiento > preaviso > aviso, marcas de estados múltiples, hoy con anillo, leyenda plegada al pie (`month_agenda_screen.dart`, `3628324a`, `65d92436`).
  - Agenda: tira semanal con fechas circulares y marcadores conservados (`day_agenda_screen.dart`, `af0ffae4`).
  - Inicio: tarjetas de vencimiento legibles, nombre/referencia, fechas y estado (`dashboard_screen.dart`, `a20e4671`).
  - Editor: apartados agrupados, teclado adaptado, fechas más cómodas, diálogos móviles con ancho acotado (`renewal_editor.dart`, `b1ee9bfb`, `cb31a4f7`).
  - Ficha: contacto, póliza, fechas, notas en tarjetas distintas (`renewal_detail_screen.dart`, `5345c7ff`).
  - Nuevo test de estilo del mes claro/oscuro y prioridad de marcas: `clients/flutter/test/design_v3_test.dart` (`cd4c0f43`, `083741c3`).
- Script de verificación y despliegue V3 en **`scripts/validate_ui_v3.sh`**, commit `6246a4a0`. Basado en el script V2 ya comprobado, añade test específico del calendario y HTTPS externo informativo.
- **Siguiente paso**: sincronización GitHub y ejecutar UNA vez el script completo con `bash scripts/validate_ui_v3.sh` desde `/home/vencira/vencira-localcheck`; solo si test Flutter+build superan, recrear `web_preview` del proyecto `vencira_localcheck`. Si falla, el asistente corrige GitHub y repite solo esta prueba. Sin Actions, sin tocar BD/API/otro stack.
- **Después del resultado verde**: capturas Android V3 (mes con evento, agenda semanal, inicio, editor y ficha), comprobar 320/375px, modo claro/oscuro. No dar por satisfactoria experiencia visual solo por tests. Registrar resultado y SHA.

## Diagnóstico confirmado y corregido — Flutter V3 (23/10/2026)

- El usuario compartió el archivo `/tmp/vencira-ui-v3.uf8GYuLt.log` de la primera ejecución. Checkout: `integration/local-e2e-prep`, SHA previo `e4c6852`, solamente `clients/flutter/pubspec.lock` sin seguimiento (permitido).
- `flutter pub get` terminó bien. `flutter analyze` detectó exactamente dos errores `Expected to find ')'` en `test/design_v3_test.dart` (líneas 42:53 y 52:57). Causa real: **faltaba `}` de cierre en los argumentos opcionales con nombre** de `fetchAgendaDay` y `fetchRenewalHistory` de la API ficticia usada por el nuevo widget test, no un fallo del servidor.
- **Corregido en GitHub:** `19ec2e8b` (`clients/flutter/test/design_v3_test.dart`, añade `}) async` en ambos métodos). Sin nuevas migraciones y sin cambios API/DB.
- Próximo paso: sincronizar `integration/local-e2e-prep` y volver a correr **una sola vez** `bash scripts/validate_ui_v3.sh`. El script detiene el rollout antes de tocar Web si alguna prueba falla; puede aparecer otro fallo de prueba/código aún no observado, que se corregirá en GitHub según su log. Conservar la consola SSH.
- V3 **NO está validado ni desplegado todavía** a partir del log recibido. No afirmar que un build o despliegue se ejecutó.

## Última ejecución UI V3: error todavía sin detalle

- El usuario informó solo `CONSOLA_ABIERTA`, `EJECUCION_COMPLETADA=0`, `CONSOLA_ABIERTA` tras ejecutar el bloque V3. **No se conoce todavía si falló `git fetch/merge`, una precondición, Flutter, Docker build o rollout**; no afirmar que no hubo despliegue ni que hubo un fallo de compilación.
- Script `scripts/validate_ui_v3.sh` guarda la salida de pruebas/build en `/tmp/vencira-ui-v3.XXXXXXXX.log` e imprime `RESULTADO_GLOBAL`, `FASE_FALLIDA` en stdout. El usuario solo envió el final, insuficiente para diagnóstico.
- Paso siguiente: **un solo comando de diagnóstico no mutante** para mostrar `git status --short --branch`, SHA local, último log UI V3 (últimas 120 líneas; sin secretos) y marca de hora, conservando `CONSOLA_ABIERTA`. Corregir en GitHub según error real, sin volver a ejecutar despliegue a ciegas.
- V3 sigue pendiente de confirmación de tests y despliegue; no confundir con V2 que sí fue validada.

## V3 segunda validación: fallo real en API ficticia de prueba (23/10/2026)

- Usuario confirmó ejecución sobre commit `d52cfe3902fab62eca6bc6b0ccf22ff8f3078021`, proyecto Docker correcto y limpio salvo `pubspec.lock`. `COMPOSE_CONFIG=OK`. `FLUTTER_PUB_GET_ANALYZE_TEST_BUILD` falló durante **flutter analyze**, antes de build o despliegue; `RESULTADO_GLOBAL=1`, log `/tmp/vencira-ui-v3.pUDcXijt.log`.
- Salida: 14 diagnósticos en `test/design_v3_test.dart`; raíz única de sintaxis en líneas 42 y 52: `String ... {int page = 1},` antes de `})`, es decir, llave del argumento nombrado mal cerrada y una coma extra. El parche anterior `19ec2e8b` había añadido una llave al cierre pero **no corregía la llave/coma dentro de la línea de argumentos**. Los errores de métodos abstractos/annotaciones se derivan de ese fallo.
- **Corrección completa en GitHub:** `2ec0d9fef72ecf4b78c4cc4783d00fcf26e771fb` reorganiza las dos declaraciones como `String workspaceId, DateTime day, {\n int page = 1,\n })` y lo propio para historial. No cambiar API de negocio ni PostgreSQL.
- Pendiente ejecución única `scripts/validate_ui_v3.sh` tras `git fetch` + `git merge --ff-only`. Si el analizador o tests descubren otro error, no se recrea Web hasta superar todas las fases. No calificar V3 como validada/desplegada antes de salida verde.
- Mantener el procedimiento de una ejecución por fase, logs completos y SSH abierto. No introducir datos personales reales.

## V3 premium — despliegue validado en localcheck (23/10/2026)

- **Usuario confirma éxito integral** de `scripts/validate_ui_v3.sh` sobre commit `bf6d087a7c3422c95a1ee8b240ccf52b291f53e6` (`integration/local-e2e-prep`): rama y archivos rastreados limpios; solo `pubspec.lock` generado; etiquetas Compose `vencira_localcheck` correctas.
- `COMPOSE_CONFIG=OK`; `FLUTTER_PUB_GET_ANALYZE_TEST_BUILD=OK`; `FLUTTER_V3_Y_TESTS=OK` (incluye prueba `design_v3_test.dart` de colores de celda y todos los tests); `WEB_BUILD=OK`; `WEB_DEPLOY=OK`.
- Postdespliegue `WEB_HEALTH=healthy`; proxy interno `/`, `/api/health/`, `/api/ready/`, `/accounts/login/` **HTTP 200**; `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`.
- `DESPLIEGUE_WEB_V3_LOCALCHECK=OK`, `SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `CONSOLA_ABIERTA`. Log local `/tmp/vencira-ui-v3.3fUh9fU0.log`.
- **HTTPS público** `https://dev.vencira.es/`: `HTTP 401` **sin credenciales** en curl. No inferir indisponibilidad de aplicación a partir de una comprobación anónima ni retirar la protección de acceso. Verificar en Android mediante sesión existente. El 401 no demuestra por sí solo que el dominio esté enrutado al stack correcto; comprobar visualmente.
- **Pendiente única puerta V3:** aceptación visual Android de inicio, calendario mensual con actividad coloreada, agenda diaria, editor y ficha. Valorar legibilidad de casillas cuadradas y estados múltiples en 320/375px y modos claro/oscuro. No dar por aprobada la UX solo por pruebas técnicas.
- Referencias y detalles del diseño: `docs/DESIGN_SYSTEM_V3.md`. No repetir build ni pruebas ya superadas salvo nuevo cambio de código. Nunca usar datos reales hasta seguridad/RGPD.

## V3.1 premium — menús propios y estados cromáticos (pendiente de validar y desplegar)

**Motivación capturas Android:** usuario valida V3 como mejora sustancial pero ve pobres los selectores desplegables de filtros/ajustes; solicita acabado premium y un poco más de color para estado Pendiente, Contactado y Cerrado. Debe conservar elegancia y limpieza visual.

- **Diseño/criterios/tests:** `docs/DESIGN_SYSTEM_V3_1.md`. Incorpora `VenciraSelect<T>` con bottom sheet accesible, desplazable, color de seleccionado y opciones anchas; `VenciraStatusBadge` con estados ámbar/petróleo/verde y variantes oscuro/claro.
- **Cambios código en GitHub `integration/local-e2e-prep`:**
  - `2ae0fa56`: `clients/flutter/lib/ui/vencira_select.dart`, nuevo componente de opción y badge semántico, sin dependencias adicionales.
  - `b4743d49`, `2620b0c1`, `b94f0ea3`: filtros de panel, badges, ajuste de ancho móvil y selector multi-organización.
  - `40449b46`, `fea6288e`: agenda con selectores a todo el ancho, estado de los registros y tinte de tipos de evento.
  - `10cb4ce9`: editor con selectores Entrada, Modalidad, Aseguradora y Estado sin perder valores históricos.
  - `7247da58`: ficha de anotación, estado semántico.
  - `f66c686f`: ajustes Idioma/Apariencia rediseñados de menú Material desplegable a hoja organizada con marcas de selección.
  - `8e1a9868`: `premium_components_test.dart`, casos 320/375 y claro/oscuro + distinción cromática.
  - `3e28d10c`: actualización prueba cambio de organización `widget_test.dart` para componente propio.
  - `515e367f`: script consolidado seguro `scripts/validate_ui_v3_1.sh`. `d70658c8`: documentación V3.1.
- **Estado:** los cambios V3.1 están preparados en GitHub, **no hay todavía salida de Flutter analyze/test/build ni despliegue validado**. No prometer éxito ni que el navegador ya refleja los cambios.
- **Próxima acción única en Ubuntu** (sin cerrar consola):
  ```bash
  (
    cd /home/vencira/vencira-localcheck || exit 1
    git fetch origin integration/local-e2e-prep || exit 1
    git merge --ff-only FETCH_HEAD || exit 1
    bash scripts/validate_ui_v3_1.sh
  )
  echo "RESULTADO_EJECUCION=$?"
  echo "CONSOLA_ABIERTA"
  ```
- El script debe parar antes de cambiar Web si falla Git/Compose/Flutter. No alterar API, PostgreSQL ni `vencira_preview`. Si falla, corregir directamente en GitHub, documentar causa y repetir una sola ejecución. Tras éxito, capturas Android de los filtros desplegados (Estado/Entrada/Aseguradora), ajustes y badges en panel/ficha en claro/oscuro.
- Datos de clientes reales prohibidos antes de seguridad/RGPD. No usar GitHub Actions por cuota consumida.

## V3.1 — Primera ejecución, analizador detenido y corrección (23/10/2026)

- El usuario ejecutó `scripts/validate_ui_v3_1.sh`; salió `RESULTADO_GLOBAL=1` y `FASE_FALLIDA=FLUTTER_PUB_GET_ANALYZE_TEST_BUILD`. Flutter pub get tuvo éxito, pero **flutter analyze** detectó `duplicate_definition` en `lib/ui/vencira_select.dart:70:39`: `separatorBuilder: (_, _) => ...`. En esta versión Dart dos parámetros de un mismo callback no pueden llamarse ambos `_`.
- **Parche GitHub `60d92832aa4fa11222f19a125d24d9c71daf178b`**: `separatorBuilder: (context, index) => const SizedBox(height: 5)`. No toca contratos, autenticación, modelos, BD ni API.
- El script no llegó al build/rollout: la V3.1 **NO se ha desplegado** por esta ejecución. La V3 anterior sigue siendo la última confirmada en `vencira_localcheck`.
- Próximo paso: sincronizar rama `integration/local-e2e-prep` y repetir el **mismo script integral V3.1** una sola vez. Si fallan nuevas pruebas, corregir en GitHub según el log. Conservar siempre shell SSH; prohibido borrar archivos locales para pasar preflight.
- Ver `docs/DESIGN_SYSTEM_V3_1.md` para criterio visual de selectores y badges.

## V3.1 — Fallo de suite completa, 2 tests (23/10/2026)

- El usuario ejecutó `scripts/validate_ui_v3_1.sh`; `flutter analyze` y pruebas premium específicas progresaron; la suite completa falló en **dos** casos de `test/widget_test.dart`, `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=FLUTTER_PUB_GET_ANALYZE_TEST_BUILD`, log remoto **`/tmp/vencira-ui-v3-1.ytQ64C8t.log`**. No se llegó a `WEB_BUILD` ni `WEB_DEPLOY`; V3 estable sigue activa.
- Caso 1: `agenda sin desbordamiento a 320 px en catalán oscuro`, excepción capturada por `tester.takeException()` en línea 224. La salida aportada solo incluye **las últimas 100 líneas** del log, omitiendo el mensaje primario de la excepción. **No se conoce aún qué RenderObject/widget falló**. No introducir cambios de diseño especulativos; recuperar del log remoto la **primera** sección `EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK` sin volver a compilar.
- Caso 2: `solo muestra vencimientos del workspace seleccionado`, línea 417: `find.byKey(ValueKey('11111111-1111-4111-8111-111111111111'))` devolvió cero. Código usaba `ValueKey(_selected?.id)`, que puede inferir `ValueKey<String?>` y no casar con `ValueKey<String>` en la prueba. **Corregido en GitHub**: selector con clave fija `ValueKey('workspace-select')` (commit `529181af`); test usa la misma clave fija (commit `9e3c3f1b`). No altera aislamiento ni cambio de organización.
- Script `scripts/validate_ui_v3_1.sh` reforzado commit `43684b70` para imprimir **la primera excepción** y también últimas 100 líneas si falla, evitando diagnósticos incompletos en futuras fases.
- **Siguiente acción:** solicitar al usuario un ÚNICO bloque de lectura no mutante del log existente que extraiga el primer `EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK` y 65-80 líneas posteriores, sin reinstalar ni desplegar. Con esa evidencia corregir la UI responsable de 320 px en GitHub, documentar y luego pedir una sola ejecución integral V3.1. No confundir errores de tests con indisponibilidad pública. No cerrar SSH ni tocar PostgreSQL.
- Mantener `docs/DESIGN_SYSTEM_V3_1.md` coherente con estado y próximos hitos; no declarar V3.1 desplegada hasta que pase todo.

## V3.1 — diagnóstico Flutter 320px y correcciones preparadas (23/10/2026)

- El usuario extrajo la primera excepción del log `/tmp/vencira-ui-v3-1.ytQ64C8t.log` sin ejecutar nuevamente pruebas. Caso `agenda sin desbordamiento a 320 px en catalán oscuro`: `FlutterError: A RenderFlex overflowed by 5.5 pixels on the right`, capturado por `tester.takeException()` en `test/widget_test.dart:224`. **El mensaje no identifica el widget/RenderFlex específico**; no presentar una localización como confirmada.
- Causa plausible introducida V3.1: el estado `contacted` está en una insignia nueva con `Row(mainAxisSize:min)` y texto sin flexible dentro de la tarjeta estrecha, y el test 320px en CA utiliza registro `status:'contacted'`. Corrección preventiva/robusta GitHub **`a9dc73a8`**: el texto del `VenciraStatusBadge` pasa a `Flexible(Text(maxLines:1,overflow:ellipsis,softWrap:false))`, de modo que no puede obligar a la fila a crecer lateralmente. Test explícito `premium_components_test.dart` **`8111abc3`**: insignia de texto largo confinada a 94 dp en viewport 320; debe completar sin overflow.
- Comprobación adicional de anchura para 320px: dos acciones en la cabecera del workspace usaban `OutlinedButton.icon` y `FilledButton.icon` en mitades de una fila; en catalán «Afegeix» + icono y padding podía consumir más que el espacio disponible. **Parche GitHub `9df8806a`**: para contenedores <340dp muestra botones de texto compacto sin iconos y reutiliza `_openAgenda` en ambas variantes. Esta es otra salvaguarda plausible, **no se ha identificado de forma inequívoca qué RenderFlex produjo 5.5px**.
- Segundo fallo confirmado de organización en test 417 ya corregido previamente: `ValueKey('workspace-select')` estable en dashboard `529181af` y prueba actualizada `9e3c3f1b`. El test puede seguir fallando por otra causa, se comprobará al correr suite completa.
- Script **`scripts/validate_ui_v3_1.sh`** actualizado `43684b70` para imprimir primera excepción además del final del log. No se ha vuelto a ejecutar; **V3.1 no está validada ni desplegada**. V3 anterior estaba saludable.
- **Próxima operación única**: sincronizar rama `integration/local-e2e-prep` y ejecutar el mismo script V3.1 por completo. Si aparecen más errores, analizar la primera excepción y corregir el componente real. No desplegar manualmente, ni tocar API/DB/stack antiguo.

## V3.1 verificada (23/10/2026)

Suite Flutter, web build y despliegue localcheck completados sobre `ab5b12b3`: `RESULTADO_GLOBAL=0`. API/DB/Web healthy y cuatro rutas HTTP 200. Sin migraciones. Pendiente inspección visual Android de selectores y etiquetas. Detalle en `docs/DESIGN_SYSTEM_V3_1.md`.

## Hito UX aceptado y fase operativa O1 desarrollada (23/10/2026)

- El usuario **aprueba el diseño V3.1** de VENCIRA: menús `VenciraSelect` con hoja de opciones, iconos, acentos, selección y Preferencias; capturas reales Android del 23/10/2026 de filtros y ajustes. No volver a rediseñar sin necesidad funcional.
- V3.1 verificada y desplegada previamente: `ab5b12b3e5b0420e13444a84dcb046abf1910a1b`, `RESULTADO_GLOBAL=0`, API/DB/Web saludables. **Aprobación visual explícita del usuario** este turno.
- Usuario pide avanzar con la **operativa según whitepaper**, no CRM. Se implementa **O1: registro rápido y confirmado de contacto externo** desde ficha, entre pendiente/contactado; PATCH mínimo solo `status`, token CSRF y UUID, sin modificar notas/fechas. No envía mensajes ni notificaciones, no cierra anotación. Backend audit/permissions ya existentes, sin migraciones.
- Nuevo documento autoritativo `docs/OPERATION_O1_MANUAL_CONTACT.md`: cambios y tests, delimitaciones, plan O2 «Recuérdamelo» persistente sin envío y O3 cuatro desenlaces `Conseguido/No aceptó/Aún sin decidir/Descartar`; no equiparar estado `closed` actual a un desenlace.
- Archivos de O1: `clients/flutter/lib/api/vencira_api.dart`, `clients/flutter/lib/ui/renewal_detail_screen.dart`, `clients/flutter/test/vencira_api_test.dart`, `clients/flutter/test/contact_followup_test.dart`. Script `scripts/validate_operativa_o1.sh`.
- **Estado O1:** cambios y documentación listos en GitHub; **todavía NO hay pruebas de servidor ni despliegue O1 confirmados.** No presentar esta fase como desplegada. API/BD/stack antiguo quedan intactos.
- Próxima acción única: sincronizar `integration/local-e2e-prep` y `bash scripts/validate_operativa_o1.sh` en `/home/vencira/vencira-localcheck`. Recopilar `RESULTADO_GLOBAL`; si falla Flutter analizar primera excepción y corregir en GitHub. Una vez verde, Android con datos ficticios: cancelar confirmación, marcar contacto, devolver pendiente y comprobar que la ficha mantiene datos y notas.
- Después O1 visual/funcional, O2 deberá tener nueva migración con backup `pg_dump -Fc` verificado antes de recrear API, además de Django tests y aislamiento de usuarios; no migrar sin gates.

## O1 — prueba integral y despliegue completados; O2 diseñada (23/10/2026)

- Reporte servidor de O1: `integration/local-e2e-prep`, `ESTADO_GIT=FUENTES_VERSIONADAS_LIMPIAS`, commit `a2f109ee2d2bb33561d50561130017642ba4834e`, `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`.
- `FLUTTER_PUB_GET_ANALYZE_TEST_BUILD=OK`, `FLUTTER_OPERATIVA_O1_Y_TESTS=OK`, `WEB_BUILD=OK`, `WEB_DEPLOY=OK`; `WEB_HEALTH=healthy`; `HEALTH_api/db/web_preview=healthy`; respuestas HTTP 200 por el proxy interno para `/`, `/api/health/`, `/api/ready/` y `/accounts/login/`. `DESPLIEGUE_WEB_OPERATIVA_O1_LOCALCHECK=OK`, `SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `CONSOLA_ABIERTA`.
- Log `/tmp/vencira-operativa-o1.L4zH4RDp.log`. Curl anónimo público `https://dev.vencira.es` devuelve 401 por acceso protegido (no implica por sí solo fallo).
- **O1 técnica, despliegue y aceptación funcional Android APROBADOS**: el usuario confirmó dos veces «Funciona correctamente» (23/10/2026) tras la secuencia de cancelación/confirmación de «Contactado» y reversión a «Pendiente». No volver a pedir comprobación O1 salvo nuevas regresiones. Las pruebas y el flujo previo usan registros ficticios.
- `docs/OPERATION_O1_MANUAL_CONTACT.md` registra el cierre O1. **Nuevo** `docs/OPERATION_O2_FOLLOW_UP_PLAN.md` documenta el requisito de «Recuérdamelo» contrastado con whitepaper, arquitectura, peligros, pruebas y gate de backups/migración. **O2 aún NO implementada.**
- Ruta posterior: tras O1 funcional, implementar O2 como fecha civil de seguimiento por anotación abierta, agenda/estado y auditoría con API limitada por membresía. Primero pruebas Django/Flutter y PostgreSQL efímero; antes de toda migración permanente backup verificado del `vencira_localcheck-db-1`, comprobación de migraciones y solo entonces despliegue autorizado. Mantener envíos reales/adjuntos desactivados.

## O1 aceptada y O2 preparada para preflight AISLADO (23/10/2026)

- Usuario confirma explícitamente **«Funciona correctamente»** dos veces tras validar en Android O1 (cancelar, marcar contactado, volver a pendiente). O1 termina con aceptación funcional; versión desplegada `a2f109ee` y `RESULTADO_GLOBAL=0`. No solicitar nuevas pruebas de O1.
- **O2 «Recuérdamelo» código implementado en GitHub** en la rama `integration/local-e2e-prep`, con nueva tabla `RenewalFollowUp`, migración aditiva `0013_renewal_manual_followups`, API con operaciones GET/POST/PATCH autenticadas y auditoría, agenda mensual/diaria y ficha Flutter con fechas rápidas y cancelación/atendido. **La migración O2 NO está aplicada y el código O2 NO está probado ni desplegado aún.**
- Diseño, detalle de archivos, contratos, pruebas y gates: `docs/OPERATION_O2_FOLLOW_UP_PLAN.md` (actualizado con implementación).
- **Preflight sin cambios persistentes:** `scripts/validate_operativa_o2_preflight.sh`: estado Git/identidad Compose; imagen API independiente; Django check y makemigrations --check; tests Django SQLite y Postgres 17 con red+contenedor temporales; Flutter analyze/test/build completo. No se llama `docker compose up`, no se reconstruye API/DB real ni se migra `vencira_localcheck`.
- **Siguiente paso único en Ubuntu:** `cd /home/vencira/vencira-localcheck; git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash scripts/validate_operativa_o2_preflight.sh` dentro de subshell, imprimir `RESULTADO_EJECUCION=$?` y `CONSOLA_ABIERTA`. Si falla, reparar en GitHub y repetir el mismo preflight. No dar por verde sin evidencia.
- **Cuando y solo cuando preflight sea verde:** diseñar script separado y seguro de respaldo `pg_dump -Fc` verificado, restauración probada en Postgres temporal, `migrate --plan`, despliegue controlado de API y Web **solo localcheck** y healthchecks. `api` autoaplica migraciones al arrancar: prohibido recrearla antes del backup. Ninguna notificación real habilitada.

## O2 primera ejecución de preflight — contrato mensual actualizado (23/10/2026)

- Ejecución real de `scripts/validate_operativa_o2_preflight.sh`: Django SQLite ejecutó **112 pruebas, 1 fallo** en `reminders.test_agenda_month.MonthAgendaTests.test_member_bob_cannot_infer_alice_counts`. El código O2 agrega `follow_up: {pending: 0, contacted: 0}` para cada día, pero ese test hacía `assertEqual` con contrato anterior sin `follow_up`. No es fallo de migración ni se ha probado aún la fase posterior de PostgreSQL efímero / Flutter (preflight abortó antes).
- **Parche GitHub `5ed71bb2`** (`backend/reminders/test_agenda_month.py`): actualizar igualdad exacta incluyendo `follow_up` en cero, **sin debilitar la aserción**; añadir una prueba que crea seguimientos manuales para Alice/Bob en la misma organización y comprueba que ni los días ni los contadores de un miembro aparecen a otro. Código de producción sin cambios.
- Resultado del intento: `RESULTADO_EJECUCION=1`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`, log `/tmp/vencira-operativa-o2-preflight.ZvpsrqJ1.log`. **O1 continúa funcionando**, O2 sin migración real ni despliegue.
- Siguiente operación única: `git fetch`, `git merge --ff-only` en `/home/vencira/vencira-localcheck` y repetir exactamente `bash scripts/validate_operativa_o2_preflight.sh`, sin tocar stacks ni PostgreSQL persistente. Esperar pruebas SQLite/Postgres efímero/Flutter antes de preparar script de backup+migración, nunca despliegue directo.

## O2 segunda prevalidación — SQLite/Postgres OK; test Flutter móvil corregido (23/10/2026)

- El usuario ha ejecutado `scripts/validate_operativa_o2_preflight.sh` sobre commit `a6614836c24445c7f0794747f7ed9dda31dc7559`. Rama `integration/local-e2e-prep`, `ESTADO_GIT=FUENTES_VERSIONADAS_LIMPIAS`, `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`, `BUILD_API_PRUEBA_AISLADA=OK`, `DJANGO_CHECK_Y_MIGRACION_EN_SECO=OK`, **`DJANGO_SQLITE_SUITE=OK`**, `POSTGRES_EFIMERO=OK`, **`DJANGO_POSTGRES_O2_TESTS=OK`**.
- Fase pendiente `FLUTTER_O2_SUITE_Y_BUILD`: test `clients/flutter/test/manual_follow_up_test.dart` falló en móvil a 375×900 tanto en ES como CA, al pulsar `schedule-follow-up` fuera de pantalla (Offset y ≈1017/1001 > viewport 900). A continuación no se abrió la hoja de fechas y `find.text('En 3 días')` devolvió 0. **Causa precisa: `tester.scrollUntilVisible` puede no mover un ListView cuyos hijos ya están construidos; localizar el widget no garantiza que sea visible/hit-testable.** No es error funcional demostrado del selector ni de la API.
- **Parche GitHub `08380e0c`**: test usa `await tester.ensureVisible(schedule/complete)` y `await tester.pumpAndSettle()` antes de cada `tap`, para forzar desplazamiento real en móvil. Código de producción sin cambios en este parche. Repetir misma validación integral; pueden aparecer otros fallos de pruebas aún no alcanzadas.
- Resultado de ejecución anterior `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=FLUTTER_O2_SUITE_Y_BUILD`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`. **O1 permanece desplegada y aceptada**, O2 NO aplicada ni desplegada. No llamar a migra/deploy hasta preflight completamente verde.
- Una única ejecución posterior: `git fetch origin integration/local-e2e-prep`, `git merge --ff-only FETCH_HEAD`, `bash scripts/validate_operativa_o2_preflight.sh` en sub-shell desde `/home/vencira/vencira-localcheck`, devolver `RESULTADO_GLOBAL`, `LOG_LOCAL` y `RESULTADO_EJECUCION`.
 
## O2 — preflight completamente VERDE, backup y restauración preparados (23/10/2026)

- **Usuario confirma preflight O2 integral exitoso** en `vencira_localcheck`, rama `integration/local-e2e-prep`, commit **`f7a62e3debe1e7534572ed6ec5e0e81ce1913539`**: `ESTADO_GIT=FUENTES_VERSIONADAS_LIMPIAS`, `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`, `BUILD_API_PRUEBA_AISLADA=OK`, `DJANGO_CHECK_Y_MIGRACION_EN_SECO=OK`, `DJANGO_SQLITE_SUITE=OK`, `POSTGRES_EFIMERO=OK`, `DJANGO_POSTGRES_O2_TESTS=OK`, `FLUTTER_O2_SUITE_Y_BUILD=OK`, `DJANGO_SQLITE_POSTGRES_FLUTTER_O2=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`. Log `/tmp/vencira-operativa-o2-preflight.CIKXNCqx.log`.
- **Ninguna migración se ha aplicado**: O1 sigue siendo lo desplegado y aceptado; `0013` está solo en GitHub. No confundir preflight exitoso con despliegue.
- **Siguiente fase deliberadamente separada por seguridad**: nuevo `scripts/prepare_operativa_o2_backup.sh` (código `46276ee8`, robustez `82dcfe2f`). Verifica rama/checkout, identidad del proyecto, y que no hay diferencias de código de producción desde `f7a62e3d`; consulta la migración real `0012_renewal_notes` y rechaza estado inesperado; hace `pg_dump -Fc` SOLO de `vencira_localcheck-db-1` al directorio `/home/vencira/vencira-db-backups` (permisos directorio 700, archivo/huella/recibo 600); checksum SHA-256 e índice `pg_restore -l`. Restaura el respaldo íntegro con `pg_restore --exit-on-error` a un PostgreSQL 17 contenedor temporal `--network none --rm` sin puertos ni volúmenes compartidos, coteja la última migración y los conteos no sensibles entre DB viva y restaurada; limpia el contenedor temporal. Solo con éxito crea `.verified` ligado al SHA del respaldo y commit validado.
- **El script backup/restauración no reinicia servicios ni toca la base original**, aparte de leerla con `pg_dump`; sin `docker compose up` ni Django `migrate`. El dump se **protege por permisos, pero NO está cifrado**; almacenar solo en servidor y no compartir el archivo ni el SHA en capturas públicas. Limpieza del contenedor temporal supervisada. Cualquier fallo frena el flujo y reporta `FASE_FALLIDA`. No confiar en un dump sin `BACKUP_RESTAURACION_VERIFICADOS=1`.
- Comando único desde Ubuntu: `cd /home/vencira/vencira-localcheck && git fetch origin integration/local-e2e-prep && git merge --ff-only FETCH_HEAD && bash scripts/prepare_operativa_o2_backup.sh` dentro de subshell, luego `echo "RESULTADO_EJECUCION=$?"` y `echo "CONSOLA_ABIERTA"`. **Esperar resultados antes de preparar/aplicar migración `0013` y despliegue API+Web.** No permitir cambios API o Flutter posteriores sin nuevo preflight, ya que el script ata fuentes a `f7a62e3d`.
- **Estado actual** al registrar esto: script nuevo preparado en GitHub, aún **NO ejecutado**, respaldo O2 no verificado y migración real no aplicada. Archivo funcional detallado: `docs/OPERATION_O2_FOLLOW_UP_PLAN.md`.

## O2 — copia real restaurada; despliegue controlado listo, aún NO ejecutado (23/10/2026)

- **Usuario confirma backup y RESTAURACIÓN integral EXITOSA** sobre `vencira_localcheck`: `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`, `ULTIMA_MIGRACION=0012_renewal_notes`, `PG_DUMP=OK`, `PG_RESTORE_INDEX=OK`, `SHA256=OK`, `RESTAURACION_INTEGRAL=OK`, `CONTENIDO_RESTAURADO=VERIFICADO`, `MIGRACION_0013_AUN_NO_APLICADA=1`, **`RESULTADO_GLOBAL=0`, `BACKUP_RESTAURACION_VERIFICADOS=1`, `RESULTADO_EJECUCION=0`, `NO_SE_APLICARON_MIGRACIONES=1`, `NO_SE_REINICIARON_SERVICIOS_LOCALCHECK=1`**.
- Archivo privado verificado en servidor: `/home/vencira/vencira-db-backups/pre0013_20261023T084917Z_EQESO7FF.dump`, SHA256 `6f3df512b225a361182248a25a718715106fb4d566af5f11f1e479cace7b8f1c`; recibo protegido `.verified` y `.sha256`, log `/tmp/vencira-o2-backup.thwFlo0Y.log`. **El contenido del dump NO está cifrado; nunca publicar el archivo ni adjuntarlo.** Copia evaluada mediante restauración completa sin red ni volúmenes compartidos.
- **Preflight código O2 previamente verde** en commit `f7a62e3debe1e7534572ed6ec5e0e81ce1913539` (`DJANGO_SQLITE_POSTGRES_FLUTTER_O2=OK`, `RESULTADO_GLOBAL=0`). Los cambios desde ese commit para esta etapa solo pueden ser scripts/docs; un guard de `git diff` para `backend clients compose.yaml compose.preview.yaml deploy` frena cualquier actualización de producción no ensayada.
- **Creado `scripts/deploy_operativa_o2.sh` commit `bf5c0d4d` (pendiente ejecutar)**. Exige rama correcta, checkout limpio, identidad y salud de contenedores del proyecto `vencira_localcheck`, fuente idéntica al preflight y huella/recibo de backup real. Consulta estado inicial de esquema `0012` y ausencia de tabla `reminders_renewalfollowup`. Conserva IMÁGENES antiguas API/Web bajo etiquetas de rollback y crea recibo local con permisos 600. Construye ambas imágenes `api/web_preview` SIN tocar servicios, comprueba `python manage.py migrate --plan` en contenedor temporal de API con `--no-deps`, exige que incluya `0013`; solo entonces recrea API, que ejecuta `migrate --noinput` al arrancar. Tras API healthy verifica aplicación de `0013`, tabla e índice parcial `uniq_planned_followup`. Finalmente recrea Web para actualizar resolución de API y verifica healthy, HTTP interno 200 y denegación anónima 401/403 del endpoint O2. Estado HTTPS externo 401 se registra como informativo por protección. Nunca toca `vencira_preview`, ni DB container, ni activa notificaciones. **No restaurar BD automáticamente tras errores de migración o deploy**: riesgo de perder escrituras posteriores; inspeccionar log y decidir recuperación manual. Las etiquetas de imágenes anteriores permiten recuperación de código sin borrar datos, previa evaluación.
- **Estado al final de este ciclo:** backup O2 verificado, imágenes todavía O1 en funcionamiento, migración `0013` NO aplicada, desplegable O2 subido a GitHub pero **NO ejecutado**. Próximo paso inequívoco: usuario corre un solo bloque `cd /home/vencira/vencira-localcheck; git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash scripts/deploy_operativa_o2.sh` dentro de subshell con `RESULTADO_EJECUCION` y `CONSOLA_ABIERTA`. Registrar `RESULTADO_GLOBAL`, `MIGRACION_0013_APLICADA`, `HEALTH_*`, `COMMIT_VALIDADO` y puerto HTTP, y corregir si hay fase fallida.
- Tras despliegue verde: usuario valida en Android (registro ficticio) fecha rápida, reprogramación, atender/cancelar, marcas violeta de agenda/mes y rastro de historial web, sin envíos reales. Solo entonces O2 funcional aprobada. Siguiente O3 = cuatro desenlaces conforme al whitepaper.

- Guardia de frescura del respaldo añadida al deploy, commit `43e31191`: rechazar copia `pre0013` de más de 24 horas o fecha incongruente. El usuario ya dispone del respaldo verificado; si el tiempo expira, NO forzar, tomar y verificar una copia nueva antes de migrar.

## O2 «Recuérdamelo» — despliegue real completado y evidencia Android (23/10/2026)

- **Usuario ejecutó `scripts/deploy_operativa_o2.sh` con éxito** en `/home/vencira/vencira-localcheck`, rama `integration/local-e2e-prep`, `COMMIT_VALIDADO=e8d5ccf96bed82f9a91183577bd5211bd20c7a57`, código de producción idéntico al preflight `f7a62e3debe1e7534572ed6ec5e0e81ce1913539`. `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`, `BACKUP_RESTAURACION_VERIFICADOS=1`, `COPIA_PRE0013_INTACTA=1`, respaldo con 0 horas de antigüedad.
- `CONSTRUIR_API_Y_WEB=OK`, `PLAN_MIGRACION_0013=OK`, `PLAN_MIGRACION_INCLUYE_0013=1`, **`DESPLEGAR_API_Y_MIGRAR_0013=OK`**, **`MIGRACION_0013_APLICADA=1`**, `TABLA_E_INDICE_O2=OK`, `DESPLEGAR_WEB=OK`, `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`.
- HTTP 200 en `/`, `/api/health/`, `/api/ready/` y `/accounts/login/` mediante proxy local; `FOLLOW_UP_SIN_SESION_HTTP=403` (autenticación exigida), `DEV_VENCIRA_HTTPS_HTTP=401` en consulta externa anónima (protegida, no indica problema). **`RESULTADO_GLOBAL=0`, `DESPLIEGUE_OPERATIVA_O2_LOCALCHECK=OK`, `RESULTADO_EJECUCION=0`**, `SOLO_STACK_VENCIRA_LOCALCHECK=1`, `SIN_RESTAURACION_AUTOMATICA=1`.
- Conservar referencias para recuperación manual: imagen API anterior `vencira-prev-o2-api:20261023T090605Z_1107929`, Web anterior `vencira-prev-o2-web:20261023T090605Z_1107929`; recibo `/home/vencira/vencira-db-backups/deploy_o2_20261023T090605Z_1107929.receipt`, log servidor `/tmp/vencira-o2-deploy.rPicfp4d.log`. Respaldo pre0013 previamente verificado en directorio restringido, **no cifrado**. No revertir esquema ni restaurar backup automáticamente.
- **Captura Android aportada por usuario** confirma la agenda diaria **30/10/2026** con `Anotaciones del día: 2`: demo de vehículo con `Límite contractual de preaviso` y demo de servicio con chip violeta `Seguimiento manual`; franjas de estado y marcas semanales diferenciadas. No se aprecia desbordamiento. La imagen **evidencia que un seguimiento programado se muestra correctamente en agenda**, pero NO demuestra por sí sola la reprogramación, `Atendido`, `Cancelar` ni el calendario mensual.
- **Estado vigente:** V3.1 y O1 aceptados; **O2 desplegada, comprobación visual parcial satisfactoria en Android**. Para cerrar aceptación funcional O2 queda probar con datos ficticios: cambiar la fecha activa, comprobar traslado del marcador; cancelar y comprobar desaparición; volver a programar y marcar atendido, verificando que no se muestra como aviso enviado, y revisar marcas de agenda mensual. No exigir nuevas pruebas de despliegue ya verdes.
- Próxima fase funcional tras aceptación O2: **O3 cuatro desenlaces del whitepaper** (`Conseguido`, `No aceptó`, `Aún sin decidir` con `Recuérdamelo`, `Descartar`), modelados sin deducir resultado de `Renewal.status = closed`, con auditoría/aislamiento y nuevas migraciones solo después de un backup distinto y pruebas aisladas. Sin comunicaciones automáticas.

## O2 aceptada, O3 cuatro desenlaces implementados en GitHub, preflight PENDIENTE (23/10/2026)

- El usuario confirma dos veces que **«reprogramar una fecha, cancelar el seguimiento y marcarlo como atendido funciona correctamente»**. Junto con migración `0013`, health/HTTP y captura de agenda violeta, **O2 se cierra funcionalmente**. No reabrir pruebas ya completadas. La pantalla mensual no se verificó expresamente, no afirmar esa prueba por inferencia.
- White paper `White_paper_agenda_vencimientos.pdf`, §9 / página 12, contrastado directamente: **Conseguido** archiva como ganada y cambia Entrada Candidatos→Clientes solo para esa anotación; **No aceptó** conserva abierta y pospone vencimiento 1 año, notas intactas, reinicia candidatos según políticas; **Aún sin decidir** mantiene abierta y crea seguimiento O2; **Descartar** archiva recuperable. Cada decisión debe quedar asociada a fecha/usuario/historial.
- **O3 implementada en GitHub**, ver **`docs/OPERATION_O3_OUTCOMES.md`**. `backend/reminders/models.py` añade `archived_at`, `archive_outcome` y `RenewalOutcome` (auditoría comercial), con migración **aditiva `0014_renewal_outcomes`**. Nuevo endpoint autenticado `GET/POST .../renewals/{uuid}/outcomes/` con `select_for_update`, respuesta sin PII, CSRF y aislamiento. Archivo visible en filtro Estado=Cerrado, excluido del listado activo. RESTAURAR es una acción auditada; la categoría técnica `closed` no se equipara a una decisión comercial.
- UI Flutter: en ficha `Desenlace/Desenllaç`, hoja premium ES/CA con cuatro opciones, confirmación y día rápido de seguimiento para «Aún sin decidir»; archivados pueden recuperarse. Cliente HTTP protegido por CSRF y tipos/IDs. Historial web muestra resultado/actor/hora; el historial técnico móvil sigue oculto. Editor normal ya no permite cerrar directamente. API/BD de O2 **NO modificadas** por estas escrituras GitHub.
- Tests O3 en `backend/reminders/test_outcomes.py`, `clients/flutter/test/outcomes_test.dart`, `clients/flutter/test/vencira_api_test.dart`. **Script nuevo `scripts/validate_operativa_o3_preflight.sh`** (SQLite Django completo, PostgreSQL 17 temporal tests O2/O3, Flutter analyze/test/build completo), sin migrar ni desplegar.
- **ESTADO REAL:** O3 NO validada, NO desplegada, migración `0014` NO aplicada, no existe backup pre0014 validado. O2 `e8d5ccf9` permanece saludable y funcional. Antes de migrar debe superar `RESULTADO_GLOBAL=0` en preflight, después backup **nuevo** pre0014 con restauración completa y un script de despliegue exclusivo `vencira_localcheck`. No reutilizar respaldo anterior para nuevos datos.
- Retención del archivo 2 años, prevista en whitepaper, **NO implementada por seguridad/RGPD**; los eventos `RenewalAuditEvent` utilizan `PROTECT` y se precisa política de conservación antes de borrado automático. Tampoco existe entidad CRM de cliente ni notificaciones salientes.
- Próxima acción única del usuario en SSH: `cd /home/vencira/vencira-localcheck; git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash scripts/validate_operativa_o3_preflight.sh` en subshell, seguido de `RESULTADO_EJECUCION` y `CONSOLA_ABIERTA`. Si falla, asistente corrige fuentes GitHub y documenta antes de otro preflight. No tocar DB/API real.

## O3 — primer preflight parcial verde y error de sintaxis Flutter reparado (23/10/2026)

- Usuario ejecutó `scripts/validate_operativa_o3_preflight.sh` sobre `7fd95f8527ec01c25908bc7b543f752cd3f6281e`. `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`, `BUILD_API_PRUEBA_AISLADA=OK`, `DJANGO_CHECK_Y_MIGRACION_EN_SECO=OK`, **`DJANGO_SQLITE_SUITE=OK`** con 119 tests, **`POSTGRES_EFIMERO=OK`** y **`DJANGO_POSTGRES_O3_TESTS=OK`** con 13 tests. Django y migración `0014` consistente; sin aplicación persistente.
- ÚNICO fallo visible: `FLUTTER_O3_SUITE_Y_BUILD`, `flutter analyze` marcó `Expected to find ')'` en `clients/flutter/lib/api/vencira_api.dart` líneas 42 y 1132. En ambos sitios el parámetro opcional nombrado terminaba en `{DateTime? scheduledFor},` antes del paréntesis final; **se corrigió en GitHub commit `d4d1c8b7d5c5409911aa3bcdfc239b5206a56bdb`**, moviendo la coma dentro de las llaves y cerrando `})`. Contrato y sobreescritura corregidos, comportamiento funcional sin cambios.
- Salida del intento: **`RESULTADO_GLOBAL=1`**, `FASE_FALLIDA=FLUTTER_O3_SUITE_Y_BUILD`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`, log `/tmp/vencira-operativa-o3-preflight.CZVgXTTW.log`, `RESULTADO_EJECUCION=1`. O2 sigue desplegada y aprobada.
- **Próxima acción**: sincronizar `integration/local-e2e-prep` con `git fetch` y `git merge --ff-only`, ejecutar de nuevo `bash scripts/validate_operativa_o3_preflight.sh`, recoger `RESULTADO_GLOBAL`. Si aparece un nuevo fallo Flutter, analizar salida y corregir en GitHub sin desplegar. Solo después del preflight completo verde preparar respaldo **pre0014 nuevo** y ensayo de restauración antes de aplicar `0014`.

## O3 — segundo preflight Django OK, fallo finder Flutter resuelto en test (23/10/2026)

- El usuario ha repetido el preflight tras la corrección Dart de parámetros nombrados. **Django sigue completamente verde:** `DJANGO_SQLITE_SUITE=OK`, `DJANGO_POSTGRES_O3_TESTS=OK` (119 tests SQLite + 13 Postgres efímero en ejecución anterior). `flutter analyze` ya ha avanzado a `flutter test test/outcomes_test.dart`.
- **Fallo identificado**: en 3 tests `O3 resultado ganado archivado y recuperable en móvil es/ca` y `O3 aún sin decidir utiliza fecha civil y O2`, `StateError: Bad state: No element` en `tester.ensureVisible(choose)`, `clients/flutter/test/outcomes_test.dart` líneas 108/160. El widget `choose-outcome` está al final del `ListView` bajo tarjetas O1/O2 y la lista puede construir perezosamente sus hijos; `ensureVisible` necesita que el elemento exista en árbol. **No se ha demostrado fallo de la app**, es un fallo de navegación del test.
- **Corrección GitHub `639a353b25ef194f304a1ab4f3bdf2b67601e070`**: antes de `ensureVisible`, en ambos tests `scrollUntilVisible(choose, 180, scrollable: find.byType(Scrollable).first)`. Deja que el Sliver construya el botón y luego lo desplaza a la zona tocable. No hay cambios de producción en este parche.
- **Resultado previo** `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=FLUTTER_O3_SUITE_Y_BUILD`, log `/tmp/vencira-operativa-o3-preflight.MZ2BobjR.log`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`, `RESULTADO_EJECUCION=1`. La versión O2 desplegada y migración `0013` siguen intactas y saludables; **O3 NO aplicada**.
- **Próximo paso** sincronizar rama `integration/local-e2e-prep` y ejecutar el mismo `bash scripts/validate_operativa_o3_preflight.sh`. Revisar cualquier fallo Flutter posterior antes de planificar backup pre0014. No desplegar ni tocar PostgreSQL real.

## O3 — prueba Flutter de desenlaces fuera de vista corregida (23/10/2026)

- Último resultado aportado por el usuario: `scripts/validate_operativa_o3_preflight.sh` dio `RESULTADO_EJECUCION=1`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`, log `/tmp/vencira-operativa-o3-preflight.MZ2BobjR.log`; **tres tests en `clients/flutter/test/outcomes_test.dart`** fallaron `StateError: Bad state: No element` al ejecutar `tester.ensureVisible` con buscador `choose-outcome` aún no construido en el `ListView` a 375 px. Dos casos archivo/recuperación ES/CA y caso indeciso. Esto **no demuestra un fallo del API ni de las transiciones reales**; indica un finder que intenta obtener un widget todavía perezoso, antes de desplazar la lista.
- Tras ese intento, la rama de GitHub ya contenía un cambio en `outcomes_test.dart`: **`scrollUntilVisible(choose, 180, scrollable: find.byType(Scrollable).first)`** previo a `ensureVisible(choose)` en los tres tests. Verificado con lectura del contenido actual. Además, corrección `6c53e3fdf0d25f765632f0b256a10f3c15154728`: extender el desplazamiento al botón `restore-outcome` después de guardar el archivo, evitando la misma excepción si la tarjeta se reconstruye fuera del viewport. Sin alteraciones a lógica backend/API/UI en esa corrección.
- **No hay todavía preflight O3 completo verde** tras ajustar el scroll. Django SQLite (119) y PostgreSQL temporal O3 (13) pasaron en la corrida previa; el bloqueo reportado ahora es en Flutter test. **O2 sigue en producción de desarrollo**, aprobada. Migración `0014` no aplicada ni desplegada, sin nuevo backup pre0014.
- Próximo paso único: `git fetch origin integration/local-e2e-prep`, `git merge --ff-only FETCH_HEAD`, `bash scripts/validate_operativa_o3_preflight.sh`; recoger `RESULTADO_GLOBAL`, `FASE_FALLIDA` y primeras excepciones si aparecen. No adelantar backup/migración/despliegue hasta verde.
 
## O3 — preflight integral verde, copia pre0014/restauración preparada (23/10/2026)

- El usuario confirmó `scripts/validate_operativa_o3_preflight.sh` **APROBADO COMPLETO** en `vencira_localcheck` sobre commit **`4d5270be3ebb7ab32d4bab103208ed34002f0082`**: `ESTADO_GIT=FUENTES_VERSIONADAS_LIMPIAS`, `COMPOSE_IDENTITY=OK`, `COMPOSE_CONFIG=OK`, `BUILD_API_PRUEBA_AISLADA=OK`, `DJANGO_CHECK_Y_MIGRACION_EN_SECO=OK`, `DJANGO_SQLITE_SUITE=OK`, `POSTGRES_EFIMERO=OK`, `DJANGO_POSTGRES_O3_TESTS=OK`, `FLUTTER_O3_SUITE_Y_BUILD=OK`, `DJANGO_SQLITE_POSTGRES_FLUTTER_O3=OK`; `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`, `MIGRACION_0014_AUN_NO_APLICADA=1`. Log servidor `/tmp/vencira-operativa-o3-preflight.SANjeL4q.log`. No repetir tests con código de producción inalterado.
- **Nuevo script** `scripts/prepare_operativa_o3_backup.sh` incorporado a GitHub (commit `21c98303876c9e00a6ff84c4d19e496da4dc78c0`). Hereda el procedimiento O2 de backup/restauración comprobado, actualizado a **pre0014** y preflight validado `4d5270be`. Verifica checkout limpio, comparación de código de producción `backend/clients/compose/deploy` con preflight, identidad `vencira_localcheck`, Compose y DB en migración **`0013_renewal_manual_followups`**; rechaza si ya existe la tabla `reminders_renewaloutcome`. Genera `pg_dump -Fc` protegido (directorio 700, ficheros 600), huella SHA-256, valida el índice y restaura COMPLETO en PostgreSQL 17 temporal **sin red ni volúmenes**. Comprueba que esquema restaurado sigue en 0013 y compara conteos no sensibles de workspaces, renovaciones, seguimientos manuales, candidatos, auditoría y migraciones. Solo entonces genera recibo `.verified` con commit/huella. La DB viva solo se lee; no se detienen API/DB/Web. El dump **NO está cifrado**: conservar privado en Ubuntu, nunca adjuntar ni publicar.
- **Estado actual:** script pre0014 preparado en GitHub, **no ejecutado**, backup aún no verificado, migración `0014` NO aplicada, O3 NO desplegada. O2 sigue funcionando. Próxima acción única: subshell en `/home/vencira/vencira-localcheck`, `git fetch origin integration/local-e2e-prep`, `git merge --ff-only FETCH_HEAD`, `bash scripts/prepare_operativa_o3_backup.sh`, `echo "RESULTADO_EJECUCION=$?"`, `echo "CONSOLA_ABIERTA"`. Comprobar `BACKUP_RESTAURACION_VERIFICADOS=1` y `RESULTADO_GLOBAL=0`. Sólo después diseñar/desplegar fase controlada `0014` a partir del backup restaurado, con plan y salud.
 
## O3 — salida parcial de backup y despliegue preparado con gate autónomo (23/10/2026)

- Usuario contestó al paso `scripts/prepare_operativa_o3_backup.sh` únicamente **`_EJECUCION=0`** y `CONSOLA_ABIERTA`. La salida de `RESULTADO_GLOBAL`, `BACKUP_RESTAURACION_VERIFICADOS`, `RESTAURACION_INTEGRAL`, ruta y hash no llegó completa; **no afirmamos como hecho que la copia ha quedado íntegramente verificada a partir de ese fragmento**. Una ejecución con código de salida 0 apunta a finalización satisfactoria, pero la prueba de respaldo debe comprobarse antes de migrar.
- GitHub: `scripts/deploy_operativa_o3.sh` creado `15929921` y corregidos indicadores `c7206dda`. Recupera de forma automática un archivo `/home/vencira/vencira-db-backups/pre0014_*.dump` con acompañantes `.sha256` y `.verified` realmente presentes, propiedad del usuario, permisos 600, directorio modo 700, SHA-256 del propio archivo igual al manifiesto y al recibo, `RESTORE_TEST=OK`, `VALIDATED_SHA=4d5270be3ebb7ab32d4bab103208ed34002f0082`, antigüedad máxima 24 horas. **Si falta un solo guard, sale `RESULTADO_GLOBAL != 0` ANTES de crear imágenes/reiniciar servicios/migrar.** El respaldo no se expone ni restaura automáticamente.
- Guarda imágenes API/Web O2 bajo etiquetas `vencira-prev-o3-api:` y `vencira-prev-o3-web:`, recibo `deploy_o3_*.receipt`. Exige rama limpia y mismo código backend/flutter/compose/deploy que el preflight verde; valida identidad/health actuales `vencira_localcheck`, migración real `0013_renewal_manual_followups` y ausencia de columnas O3/tabla `reminders_renewaloutcome`. Construye ambas imágenes antes de mutar, consulta `manage.py migrate --plan` sin migrations, exige `reminders.0014_renewal_outcomes`, entonces aplica la migración **automática al levantar API**; verifica tabla, índice, columnas, migración aplicada, API/DB/Web healthy, HTTP local 200 y endpoint `/outcomes/` anónimo 401/403. Consulta HTTP público 401 como informativo. **Nunca toca `vencira_preview`, no reinicia DB, no habilita envíos, no restaura DB automáticamente ante fallo.**
- **Estado actual**: script versionado pero NO ejecutado; O3 sigue sin desplegar, `0014` no aplicada. Siguiente paso único: desde checkout `/home/vencira/vencira-localcheck`, `git fetch`, `git merge --ff-only`, `bash scripts/deploy_operativa_o3.sh` en subshell y eco de `RESULTADO_EJECUCION`/`CONSOLA_ABIERTA`; registrar salida `BACKUP_RESTAURACION_VERIFICADOS`, `PLAN_MIGRACION_INCLUYE_0014`, `MIGRACION_0014_APLICADA`, `HEALTH_api/db/web_preview`, `RESULTADO_GLOBAL`. Si falla gate de backup y no hay mutación, tomar nuevo respaldo y ensayar la restauración, SIN forzar despliegue.
 
## O3 — bloqueo seguro PREMIGRACION en despliegue, causa por diagnosticar (23/10/2026)

- Usuario ejecutó `scripts/deploy_operativa_o3.sh` desde commit `7ff974a8a163ac5585ab2f03becc8c6cd89ca2a0`. **Respaldo pre0014 CONFIRMADO en el servidor**: `BACKUP_RESTAURACION_VERIFICADOS=1`, `COPIA_PRE0014_INTACTA=1`, antigüedad 0 horas, SHA de código prevalidado `4d5270be3ebb7ab32d4bab103208ed34002f0082`, Compose/identidad OK.
- **Bloqueo ANTES de cualquier modificación**: `ERROR: esquema distinto de 0013; abortar`, `RESULTADO_GLOBAL=5`, `FASE_FALLIDA=PREMIGRACION`, `MIGRACION_PUDO_HABERSE_APLICADO=0`, `RESULTADO_EJECUCION=5`, log `/tmp/vencira-o3-deploy.InmliE66.log`. NO arrancó construcción ni recreación ni migración `0014`; O2 sigue con servicios intactos.
- El script de backup pre0014 original había validado esquema máximo `0013_renewal_manual_followups`; por tanto, la discrepancia actual es inesperada. **No deducir ni forzar** el valor real de la migración. Podría deberse a cambio intermedio o discrepancia de consulta, solo evidencia read-only decidirá. No repetir el deploy ni restaurar el respaldo automáticamente.
- **Preparado** `scripts/diagnose_operativa_o3_schema.sh` commit `b706f4b01cc8c285b066285ed2452b7c526cd3d2`: operación **solo lectura**, comprueba identidad Docker, health, últimos seis nombres de migración desde DB real, longitud del nombre y existencia de tabla O2, tabla O3, columnas O3 e índice O3. NO utiliza `docker compose run/up/build`, no aplica migrations ni altera PostgreSQL. Siguiente paso ejecutar en SSH una vez tras `git fetch; git merge --ff-only`, `bash scripts/diagnose_operativa_o3_schema.sh`, remitir salida. Interpretar antes de editar/deploy.
- Estado: **O3 NO desplegada, migración `0014` NO atribuible al script abortado**, backup pre0014 sí verificado, O2 funcional. No afirmar que la BD sigue en 0013 hasta lectura diagnóstica.

## O3 — migración 0014 ya aplicada por vía no identificada; falta conciliar API/Web (23/10/2026)

- El usuario ejecutó `scripts/diagnose_operativa_o3_schema.sh`, commit local `5bdcb1a2b4feedc89597ee973b3d24172ae8c736`: `ESTADO_GIT=LIMPIO`, `HEALTH_api=db=web_preview=healthy`, `COMPOSE_IDENTITY=OK`, `ULTIMA_MIGRACION_REAL=0014_renewal_outcomes`, `NOMBRE_MIGRACION_LONGITUD=21`, migraciones 0014,0013,0012,0011,0010,0009. **`TABLA_O2_PRESENTE=t`, `TABLA_O3_PRESENTE=t`, `COLUMNAS_O3_PRESENTES=2`, `INDICE_O3_PRESENTE=t`, `ESQUEMA_REAL=0014_APLICADA_POR_OTRA_RUTA`**, `RESULTADO_DIAGNOSTICO=0`, `RESULTADO_EJECUCION=0`, `SIN_MIGRACION_NI_DESPLIEGUE=1`; log `/tmp/vencira-o3-schema.8QRiVV4M.log`.
- **Hecho probado**: PostgreSQL real ya tiene 0014, aunque el script `deploy_operativa_o3.sh` se detuvo ANTES de reiniciar los servicios porque su guard exigía `0013`. Eso no permite atribuir la aplicación de 0014 a ese script ni concluir que API/Web están en versión O3. **No repetir migraciones, no restaurar backup pre0014 ni ejecutar el mismo deploy.** La migración 0014 es aditiva; servicios healthy no prueban compatibilidad funcional O3.
- **Posibilidad a comprobar, no certeza**: `compose.yaml` configura `api.command` como `python manage.py migrate --noinput && gunicorn ...`. Una recreación/arranque posterior de API con una imagen que ya contenga 0014 puede haber aplicado la migración automáticamente. Git fetch/merge y backup de solo lectura no migran por sí mismos.
- **Nuevo script `scripts/diagnose_operativa_o3_runtime.sh`**, commit `666eab6e11464e44b3de20675b02f3df1df243b6`, SOLO LECTURA, comprobar SHA/identidad/health/imagen, `Created`/`StartedAt` de API, DB y Web; timestamp `applied` de 0013 y 0014, número agregado de eventos/archivados, si el contenedor API contiene `outcomes.py`/migration/ruta O3, GET anónimo local a `outcomes/` y `follow-up/`, si el bundle Flutter Web contiene etiqueta específica `Elegir desenlace`, e indicios de `Applying reminders.0014...` en logs filtrados. **No imprime credenciales, datos de clientes ni cuerpos de HTTP**. No ejecuta `docker compose up/build/run`, `migrate` ni restart.
- **Siguiente acción**: usuario sincroniza con `git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD` y ejecuta `bash scripts/diagnose_operativa_o3_runtime.sh` dentro de subshell, seguido de `RESULTADO_EJECUCION`/`CONSOLA_ABIERTA`. Con el resultado determinar si hace falta conciliar API/Web con imagen O3 nueva **sin reaplicar 0014**, usando respaldo actualizado de la BD si se han producido escrituras desde la copia pre0014. Toda actualización real debe tener gate propio y no alterar `vencira_preview`.
 
## O3 — análisis final de runtime confirma instalación completa: aceptar en Android (23/10/2026)

- El usuario ejecutó `scripts/diagnose_operativa_o3_runtime.sh` sobre commit de documentación `39b7e2d5ceebdd0852103d685711bb0cdf401734`, `ESTADO_GIT=LIMPIO`, `COMPOSE_IDENTITY=OK`, `RESULTADO_DIAGNOSTICO=0`, `RESULTADO_EJECUCION=0`, `SIN_MIGRACION_NI_DESPLIEGUE=1`, `SIN_MODIFICACION_DATOS=1`; log `/tmp/vencira-o3-runtime.UwsXe1eE.log`.
- **Confirmado origen inmediato de la migración 0014**: `vencira_localcheck-api-1` CREATED **2026-10-23T12:29:36Z**, STARTED **12:29:46Z**; registro `django_migrations` `0014_renewal_outcomes` aplicado **12:29:47 UTC**, y logs reales del contenedor API: **`Applying reminders.0014_renewal_outcomes... OK`**. La orden Compose de API incluye `python manage.py migrate --noinput` al arrancar; por tanto, **la API inició la migración al arrancar**, justo antes de servir tráfico. No consta el motivo exacto por el cual se recrearon API y Web a esa hora; no inventarlo. La ejecución posterior del script O3 que falló `PREMIGRACION` **no realizó esa migración**, sino que encontró 0014 ya aplicada.
- Web `vencira_localcheck-web_preview-1` CREATED **2026-10-23T12:29:57Z**, STARTED **12:29:57Z** y `WEB_INCLUYE_ETIQUETA_O3=1`, `WEB_BUNDLE_EXISTE=1`. API **`API_CONTIENE_MODULOS_O3=1` y `API_RUTA_O3_EN_CODIGO=1`**. Puertos HTTP local: `HTTP_outcomes=403` y `HTTP_follow-up=403` sin sesión, `HTTP_WEB_LOCAL=200`; todos `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`. PostgreSQL con tabla O3, dos columnas e índice `0014` comprobados anteriormente. **O3 desplegada funcionalmente a nivel API/Web en DEV**, sin necesidad de desplegar otra vez.
- Evidencia de utilización: `EVENTOS_O3_CONTABILIZADOS=3`; `ANOTACIONES_ARCHIVADAS_O3=0` al momento del diagnóstico. **Estos recuentos no demuestran por sí solos que los cuatro desenlaces funcionan ni constituyen aceptación de usuario**.
- **Siguiente paso, SIN comandos SSH**: probar desde móvil Android en `dev.vencira.es` con ANOTACIONES FICTICIAS: `Conseguido` sobre `Candidatos` y comprobar Archivo/Clientes, restaurar y comprobar vuelta a Candidatos; `No aceptó` y comprobar vencimiento + 1 año (29/02→28/02) y notas intactas; `Aún sin decidir` elegir fecha de seguimiento y ver marcador violeta; `Descartar` comprobar Archivo y Recuperar. Comprobar que no salen comunicaciones y no se pierden datos/historial. Solicitar sólo la aceptación funcional, no nuevas pruebas backend ya verdes. Documentar resultado.
- **Prohibido** ejecutar de nuevo script `scripts/deploy_operativa_o3.sh` (guard diseñado solo para aplicar 0014 pendiente), intentar revertir la BD a pre0014, reejecutar migraciones o activar envíos por esta situación. Estado global: V3.1/O1/O2 aceptadas, O3 instalada y healthy pero aceptación UX por usuario pendiente. Persisten límites de lanzamiento, RGPD y retención a 2 años no implementada.

## O3 — ACEPTACIÓN FUNCIONAL Y CIERRE DEL HITO (23/10/2026)

- El usuario, tras las pruebas Android solicitadas de conseguido, no aceptó, aún sin decidir, descartar y recuperación del archivo, confirmó expresamente **«Funciona perfectamente»**. **O3 aceptada funcionalmente en DEV**. No inventar pruebas individuales detalladas, capturas, o aceptación de producción que no se hayan aportado.
- Backend Django SQLite 119 tests y PostgreSQL 17 temporal 13 tests verde; Flutter analyze/test/build aprobado en commit de preflight `4d5270be3ebb7ab32d4bab103208ed34002f0082`; copia pre0014 respaldada y restaurada íntegramente, SHA verificada (`BACKUP_RESTAURACION_VERIFICADOS=1`); API/Web O3 activas `vencira_localcheck`, migración `0014` aplicada 23/10 a las 12:29:47 UTC en arranque API, health de los tres servicios OK. No confundir el bloqueo seguro posterior `PREMIGRACION` con falta de despliegue.
- O3 completa en DEV: ganado→archivo, rechazado→anualidad nueva, indeciso→O2 manual, descartado→archivo recuperable. No borrado automático a los dos años ni notificaciones externas. Evitar reprobar O3 o ejecutar antigua migración/despliegue salvo regresión real.
- Próximo hito se decide según roadmap/whitepaper; antes de uso con datos reales obligatorios controles de seguridad, RGPD, backups cifrados externos, retención/adjuntos y consentimiento/envío de avisos. Continuar con fase separada y no modificar servicio actual sin preflight y respaldo actual.

## O4 — Separación de migraciones y arranque API, un solo despliegue con gates (23/10/2026)

- **Origen:** incidente O3; `compose.yaml` ejecutaba `python manage.py migrate --noinput && gunicorn`; al recrear API aplicó `0014` antes del procedimiento independiente de migración. Usuario ya aceptó O1/O2/O3 y confirmó «Funciona perfectamente».
- **Código nuevo GitHub**: `compose.yaml`, commit `9fe0f15945b6361a14d1d8ca2f912bfc9baf4cb2`: `sh -ec "python manage.py migrate --check --noinput && exec gunicorn ..."`. `migrate --check` es control de pendientes, no aplica cambios; si están pendientes, API no arranca. `exec` correcto para señales. No hay cambios de backend Python ni Flutter ni nueva migración; O3 sigue en `0014`.
- **Script de única ejecución** `scripts/harden_api_migrations_o4.sh` (correcciones de seguridad y regresión incorporadas hasta `a4b577de70a3c5b2fcf40e72c7e174bb519aff5f`; el commit de documentación posterior no cambia el código ejecutable): valida checkout limpio, backend/clients/deploy iguales al preflight O3 `4d5270be`, Compose exactamente como commit `9fe0f159`, stack `vencira_localcheck` y arranque API antiguo con migración automática (impide repetir). Construye **copia nueva del estado O3 con `0014` ya aplicada**, nombre `post0014_o4_*.dump`, permisos 600 bajo directorio 700, SHA-256, índice pg_restore y **restauración íntegra y conteos idénticos en PostgreSQL 17 offline sin volúmenes/red**. No confundir con `pre0014`: datos/eventos O3 posteriores se perderían al restaurar una copia antigua.
- Luego validación `bash -n`, `django check`, `makemigrations --check --dry-run`, Django SQLite regresión completa, construye API, **`migrate --check --noinput`** en BD real sin cambiar migraciones; conserva imágenes anteriores API/Web y un recibo local privado; recrea solo API y proxy Web del stack `vencira_localcheck` (Nginx resuelve API al arrancar), **sin reconstruir Flutter** ni reiniciar PostgreSQL. Comprueba comando efectivo API, firma `0014` sin alteraciones, contenedor DB idéntico, health y HTTP 200, endpoints O2/O3 401/403 y bundle O3 conservado. No rollback automático sobre PostgreSQL.
- **Documentación** `docs/OPERATION_O4_MIGRATION_GUARD.md` establece protocolo O4 y futura ejecución explícita de migraciones individuales con preflight+backup/restore+plan+aplicación deliberada+salud. Una BD de desarrollo nueva debe migrarse explícitamente antes de arrancar API; aplicar `--check` evitará inicialización accidental. Viejos scripts de despliegue O2/O3 son históricos y no deben reejecutarse.
- **ESTADO REAL AÚN PENDIENTE:** script y Compose solo en GitHub. No afirmar `O4_API_SIN_MIGRACION_AUTOMATICA=OK` hasta que el usuario ejecute una vez en Ubuntu y aporte los resultados. Comando consolidado: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/harden_api_migrations_o4.sh || exit 1; bash scripts/harden_api_migrations_o4.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. **Si falla, no repetir automáticamente**. Revisar `FASE_FALLIDA`, `API_RECREADA`, `WEB_RECREADA` y logs sin secretos; documentar resultados.
 

## O4 — fallo seguro en retención de imagen antigua y corrección (23/10/2026)

- Primera ejecución del usuario sobre SHA `c6710f5202a02644c89eecfcd6fffb334b0b48f0`: `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=CONSERVAR_IMAGENES_O3`, `API_RECREADA=0`, `WEB_RECREADA=0`, `BACKUP_VERIFICADO=1`, `MIGRACIONES_APLICADAS_POR_O4=0`, `POSTGRES_SIN_REINICIAR=1`, log `/tmp/vencira-o4-hardening.UsrYfWBN.log`. La imagen anterior API referida en el contenedor **`sha256:28adf880561ea19639fbb64f0d1ca59e2ba655723aac5e9d7ff8c87e97c3ad54`** no estaba en almacén Docker al intentar `docker tag`. No confundirlo con imagen existente porque el contenedor sigue ejecutándose. El script ya había reconstruido `vencira_localcheck-api:latest` desde el backend O3 sin cambios.
- Hitos verdes previos al bloqueo: `COMPOSE_GUARD_CHECK_ONLY=OK`, `ESQUEMA_O3_ACTUAL=OK`, backup **nuevo `post0014_o4`**, índice SHA-256 y **restauración íntegra PG17 temporal con conteos verificados** (`RESTAURACION_INTEGRAL=OK`, `CONTENIDO_RESTAURADO=VERIFICADO`); `DJANGO_CHECK_Y_MIGRACIONES_EN_SECO=OK`, `REGRESION_DJANGO_SQLITE=OK` (119 tests), `BUILD_API_COMPOSE=OK`, `MIGRATE_CHECK_READ_ONLY=OK`, `CHECK_MIGRACION_SOLO_LECTURA=OK`. **No se aplicó migración ni se recreó servicio** antes del fallo.
- GitHub corrections `scripts/harden_api_migrations_o4.sh`: **`8f5c3be8`** detecta si la imagen previa API ha desaparecido, etiqueta imagen recién construida con **código O3 validado** como recuperación pero señala expresamente `RECOVERY_API_NO_EQUIVALE_BINARIAMENTE_A_ORIGINAL=1`. **`8213c054`** evita recrear Web (también podría faltar la imagen antigua), reinicia **el contenedor original Web**, comprueba mismo ID, salud y bundle Flutter O3. **`6f4b2a6a`** mejora trazabilidad para no afirmar rollback idéntico. No modifica migraciones, código Django ni Flutter.
- **Próxima acción**: usuario sincroniza GitHub, ejecuta `bash -n scripts/harden_api_migrations_o4.sh` y `bash scripts/harden_api_migrations_o4.sh` dentro de subshell; salida con `RESULTADO_EJECUCION`/`CONSOLA_ABIERTA`. **Último ajuste `310b2311`**: no reconstruye otra vez API durante recreación (`--no-build`), conserva/reinicia el contenedor Web original, reporta original faltante frente a reconstrucción funcional no idéntica bit a bit y registra indicadores de imágenes realmente disponibles en recibo; O4 aún pendiente de resultado en Ubuntu. El script hará **backup NUEVO y prueba completa otra vez** para incluir escrituras posteriores al primer backup. Rerun solo permitido porque `API_RECREADA=0` y `WEB_RECREADA=0`, guard de API antigua bloquea repeticiones tras completar O4. Si falla después de recrear API, NO repetir sin diagnóstico, NO restaurar BD automáticamente.
- Criterios O4 para cerrar: `O4_API_SIN_MIGRACION_AUTOMATICA=OK`, `API_RUNTIME_MIGRATE_POLICY=CHECK_ONLY`, `WEB_CONTENEDOR_ORIGINAL_CONSERVADO=1`, `POSTGRES_Y_MIGRACION_0014_INALTERADOS=1`, tres health healthy y `RESULTADO_GLOBAL=0`. Documentar salida del servidor.

## O4 — DESPLIEGUE EXITOSO Y CIERRE (23/10/2026)

- Segundo intento O4 ejecutado por el usuario sobre checkout `81fe687353329fcc8242b07df988b977613513ea` (antes de actualizar documentación posterior). `COMPOSE_IDENTITY=OK`, salud inicial API/DB/Web OK, comprobación de política Compose `CHECK_ONLY` OK, esquema PostgreSQL `0014_renewal_outcomes` OK. La ejecución final **se completa**: `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `O4_API_SIN_MIGRACION_AUTOMATICA=OK`.
- **Copia actual, ya con datos O3**: `PG_DUMP=OK`, `PG_RESTORE_INDEX=OK`, `SHA256=OK`, `RESTAURACION_INTEGRAL=OK`, `CONTENIDO_RESTAURADO=VERIFICADO`, `RESTAURACION_POSTGRES_TEMPORAL=VERIFICADA`, `BACKUP_RESTAURACION_VERIFICADOS=1`. Ubicación en servidor `/home/vencira/vencira-db-backups/post0014_o4_20261023T135927Z_04qhuB8S.dump`; SHA256 `34da8dc2a3b16e5a728c13a5eec639b89bf4a71ecb969110bd4718a4c4778fdc`. **No cifrada ni externa; protegerla, no publicar, jamás restaurar automáticamente sobre datos posteriores**.
- **Pruebas:** `SINTAXIS_SCRIPT=OK`, `BUILD_API_AISLADA=OK`, `DJANGO_CHECK_Y_MIGRACIONES_EN_SECO=OK`, `REGRESION_DJANGO_SQLITE=OK` (119 en primera corrida, suite completa OK en segunda), `BUILD_API_COMPOSE=OK`, `MIGRATE_CHECK_READ_ONLY=OK`, `CHECK_MIGRACION_SOLO_LECTURA=OK`. No introducir cambios adicionales sin nuevos tests.
- **Rollout:** imagen API anterior no disponible en Docker `IMAGEN_ANTERIOR_API_DISPONIBLE=0` (purgada; no confundir con el contenedor antiguo). Imagen etiquetada para recuperación reconstruida desde fuentes O3 aprobadas; `RECOVERY_API_NO_EQUIVALE_BINARIAMENTE_A_ORIGINAL=1`. `IMAGEN_ANTERIOR_WEB_DISPONIBLE=1`. Se recreó **solo la API** con nueva política `python manage.py migrate --check --noinput && exec gunicorn`, `API_RUNTIME_MIGRATE_POLICY=CHECK_ONLY`; se **reinició el mismo contenedor Web** con `WEB_CONTENEDOR_ORIGINAL_CONSERVADO=1` y Flutter O3 intacto. `HEALTH_api/db/web_preview=healthy`; `HTTP_/=200`, `HTTP_/api/health/=200`, `HTTP_/api/ready/=200`, `HTTP_/accounts/login/=200`, `HTTP_outcomes_ANONIMO=403`, `HTTP_follow-up_ANONIMO=403`; `POSTGRES_Y_MIGRACION_0014_INALTERADOS=1`, `MIGRACIONES_APLICADAS_POR_O4=0`, `POSTGRES_SIN_REINICIAR=1`.
- Recibo privado `/home/vencira/vencira-db-backups/deploy_o4_20261023T135750Z_1275743.receipt`; log `/tmp/vencira-o4-hardening.2ITaJPuI.log`. Todos los datos siguen en PostgreSQL original. **O4 CERRADA; no repetir su script de un solo uso ni el despliegue O3 histórico**. No hace falta ningún otro comando SSH para el cierre. El siguiente desarrollo debe mantener esta política y, cuando haya migraciones 0015+, ejecutarlas solo con preflight+backup/restauración+plan+migrate explícito separado.
- **Límites aún vigentes**: esto fortalece la operación de desarrollo, no habilita producción ni datos personales reales; aún faltan MFA, RGPD/LOPDGDD, backups externos cifrados, control de adjuntos, retención y envíos consentidos.

## O5 — identidad Google interna para Drive y terceros (23/10/2026)

- El usuario declaró disponer de **una cuenta Google exclusiva de VENCIRA**, reservada para **copias externas cifradas en Drive**, administración interna de proveedores y alta/gestión de servicios externos. **NO es un correo público de soporte ni de envíos a clientes**. No registrar secretos ni credenciales en el repositorio.
- **Dirección interna de Google confirmada explícitamente por el usuario: `appvencira@gmail.com` (23/10/2026).** Corrige las grafías anteriores `.col` y `.cm`; no volver a preguntar el correo por esta errata. Identidad administrativa interna, no dirección pública, no sustituye `soporte@vencira.es`. Esta confirmación no demuestra que OAuth/Drive estén conectados ni autoriza a almacenar secretos.
- Documentación de referencia: `docs/INTERNAL_SERVICE_ACCOUNTS.md`, confirmación de `.com` registrada en commit `3f934c4922037c3a7e1d13ae3098f58c30c1eb92`. La cuenta se usará internamente para Drive cifrado, administración de terceros e integraciones, **sin exponerla en interfaz pública**. **Google Drive aún no está conectado; no hay copias remotas ni OAuth/rclone/restic configurados**. O5 pendiente de implementar y probar (cifrado previo, permisos mínimos, MFA de la cuenta, recuperación independiente). Mantener la identidad pública `vencira.es` separada.

## O5 — Preparada arquitectura de copias externas Google Drive; todavía NO conectada (23/10/2026)

- Cuenta interna Google confirmada por usuario `appvencira@gmail.com`, uso técnico exclusivamente (Drive para backups cifrados y administración de servicios externos); NO usar como buzón de soporte público. Cuenta definida en `docs/INTERNAL_SERVICE_ACCOUNTS.md`. Separar `vencira.es` público y no introducir credenciales en chats, GitHub o logs.
- **Herramientas propuestas**: Restic + Rclone con repositorio cifrado `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` sobre Google Drive, OAuth con **cliente propio**, pues identificador compartido de Rclone se retira en 2026. **Acceso Google no autorizado todavía y copias remotas NO existentes.** En Android SSH hay que resolver OAuth headless de forma segura; no compartir código/token; opción oficial SSH túnel 53682 o `rclone authorize` en equipo con navegador, Google Drive API habilitada por usuario. Menor alcance posible `drive.file` condicionado a prueba real de lectura/restauración.
- En GitHub: `docs/OPERATION_O5_DRIVE_BACKUPS.md` documenta dependencias, amenazas, retención provisional, cifrado previo y plan de recuperación; `scripts/o5_preflight_drive.sh` diagnostica estado **sin cambios** (solo identidad/health DB localcheck, esquema 0014, disponibilidad de herramientas, disco, existencia configuración); `scripts/o5_backup_to_drive.sh` prepara copia `pg_dump -Fc` **en streaming** y cifrado Restic antes de Drive, requiere secretos root externos a GitHub y repositorio iniciado; `scripts/o5_restore_drill.sh` prueba desencriptar y restaurar PostgreSQL en Docker efímero **sin red ni disco host**, sin tocar DB viva. **Aún no habilitados ni ejecutados**: NO asignar éxito a O5.
- Próxima acción inequívoca: sincronizar rama en Ubuntu y ejecutar solo `bash -n scripts/o5_preflight_drive.sh && bash -n scripts/o5_backup_to_drive.sh && bash -n scripts/o5_restore_drill.sh && bash scripts/o5_preflight_drive.sh` en subshell, informar `RESULTADO_EJECUCION`, herramientas `rclone/restic`, último esquema y estados healthy. Nada de instalar paquetes, configurar OAuth ni activar servicios por este comando. Luego asistir con OAuth de Google Cloud y Drive; ejecución de copias/restore reales y automatización vendrán tras disponer de credenciales protegidas.
- Mantener O1–O4 aprobadas en DEV; NO tocar `vencira_preview`, no migrar ni restaurar `0014` en stack vivo. Copias actuales `post0014_o4` son locales **sin cifrar y no deben subirse directamente**; siguen pendientes backup externo independiente, MFA, retención, RGPD y controles producción.

## O5 — Preflight Ubuntu validado, faltan Restic y Rclone (23/10/2026)

- Usuario ejecutó `scripts/o5_preflight_drive.sh` tras sincronizar GitHub, checkout `fc42825547b1d6ed1b64aa8f1622eb25ca07851e`, rama `integration/local-e2e-prep`, Git limpio. `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, identidad `vencira_localcheck` OK, última migración `0014_renewal_outcomes`, raíz `/dev/vda1` 232GB total / 211GB libre (10% ocupado).
- `TOOL_rclone=FALTA`, `TOOL_restic=FALTA`; `openssl/curl/python3/flock` presentes. `BACKUP_CONFIG_ROOT=NO_CONFIGURADO`, `BACKUP_CLAVE_ROOT=NO_CONFIGURADA`, `GOOGLE_OAUTH_ESTADO=NO_VERIFICADO_EN_ESTE_DIAGNOSTICO`. `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `SIN_INSTALACION_NI_ACCESO_GOOGLE=1`, `SIN_COPIAS_REMOTAS_NI_CAMBIOS_DB=1`. **O5 NO está operativa**.
- **Instalador GitHub**: `scripts/o5_install_backup_tools.sh`, corrección `e8618a99224f8a163992dbcf3ade2cbbe6b6f2ca`. Guard de Ubuntu 24.04, rama Git, salud/identidad e IDs contenedores; actualiza índices APT e instala **solo** `restic` y `rclone` de repos Ubuntu (sin upgrade/dist-upgrade ni scripts externos). Verifica `restic backup --help` contiene `--stdin-from-command`, `restic dump --help`, `rclone serve restic --help`, versiones y mismos IDs healthy. No escribe secretos ni accede a Google. **Pendiente de ejecutar**.
- Próximo bloque SSH **ÚNICO**: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_install_backup_tools.sh || exit 1; bash scripts/o5_install_backup_tools.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. Analizar salida y documentar: `RCLONE_RESTIC_INSTALADOS_Y_PROBADOS=1`, `RESTIC_STDIN_FROM_COMMAND=OK`, `RCLONE_BACKEND_RESTIC=OK`, `CONTENEDORES_INTACTOS=1`, salud de API/DB/Web, `RESULTADO_GLOBAL=0`. Si falla, no repetir sin diagnóstico.
- Después: configuración OAuth propia en Google Cloud para la cuenta `appvencira@gmail.com`, acceso restringido, restauración real en PostgreSQL temporal y calendario de backups, **con aprobación expresa del usuario para Google OAuth y custodia separada de las claves**. No copiar dumps locales sin cifrar a Drive; no exponer accesos ni secretos en chat.
- Fuente detallada: `docs/OPERATION_O5_DRIVE_BACKUPS.md`. Mantener funcionalidades O1–O4. No modificar el stack hermano `vencira_preview`.

## O5 — Restic 0.16.4 APT no soporta streaming seguro; recuperación preparada (23/10/2026)

- Usuario ejecutó instalador `scripts/o5_install_backup_tools.sh` en Ubuntu 24.04, checkout limpio `8eb4ef1336f76e069673e9bad5da071402a68e48`. `APT_UPDATE=OK`, `APT_INSTALL_RESTIC_RCLONE=OK` (0 paquetes nuevos en segundo intento); `RESTIC_VERSION=restic 0.16.4 compiled with go1.22.2 on linux/amd64`, `RCLONE_VERSION=rclone v1.60.1-DEV`. Gating funcional rechazó esa Restic: `RESULTADO_GLOBAL=5`, `FASE_FALLIDA=VERSIONES`, `RESULTADO_EJECUCION=5`, `RCLONE_RESTIC_INSTALADOS_Y_PROBADOS=0`, `GOOGLE_DRIVE_NO_CONECTADO=1`, `SIN_COPIAS_REMOTE_NI_MIGRACION=1`; log final `/tmp/vencira-o5-tools.xXvCQM2W.log`. **APT se ejecutó bien; el aborto fue correcto porque falta una característica de seguridad**.
- Contrato: `--stdin-from-command` **añadido en Restic 0.17.0**, no disponible en 0.16.4; para VENCIRA evita respaldos silenciosamente incompletos si `pg_dump` falla. Ver [restic changelog 0.17.0](https://restic.net/blog/2024-07-26/restic-0.17.0-released/) y [backup 0.16.4](https://restic.readthedocs.io/en/v0.16.4/040_backup.html). En Ubuntu 24.04 el paquete `restic self-update` está deshabilitado (incidencia restic #4798). **No repetir instalador APT antiguo, no pasar a Restic `--stdin` sin garantías.**
- **Nuevo script** `scripts/o5_install_restic_official.sh`, commit inicial `d368a1c7f716020d11ea5d70959ad528094cf91a`: descarga release estable oficial 0.19.1 de GitHub, verifica integridad con SHA256 **fijada** `f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c`; comprueba soporte `--stdin-from-command`/`dump`/`rclone serve restic`; prueba backup cifrado y restauración local en repositorio efímero, y solo después instala binario verificado en `/usr/local/bin/restic`, **sin borrar paquete apt** `/usr/bin/restic`. Check salud y mismos IDs Docker API/DB/Web. **Aún no ejecutado**; no requiere OAuth, no almacena claves persistentes ni sube copias. No afirmar verificación GPG del publicador: es una comprobación SHA-256 contra huella inmovilizada.
- **Siguiente comando SSH, único:** `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_install_restic_official.sh || exit 1; bash scripts/o5_install_restic_official.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. Esperar `SHA256_PINNED_RELEASE=OK`, `PRUEBA_CIFRADA_Y_RESTAURACION_LOCAL=OK`, `O5_HERRAMIENTAS_COMPATIBLES=OK`, health healthy, `RESULTADO_GLOBAL=0`; si falla no repetir sin diagnóstico.
- Siguiente dependencia (solo después): OAuth Google propio `appvencira@gmail.com`, primera copia cifrada real Drive y restauración PG17 temporal. **O5 no completada**.

## O5 — Instalación Restic 0.19.1 VERIFICADA, siguiente OAuth Google (23/10/2026)

- Salida usuario `COMMIT=5acbc27635dd9d5a2d135d08021b50f16ae613cf`, `SISTEMA=Ubuntu_24.04_x86_64`, `REQUISITO_curl/sha256sum/python3/openssl/restic/rclone/grep/awk/sed=OK`, `DESCOMPRESION_PYTHON_BZ2=DISPONIBLE`, `RESTIC_ANTERIOR=restic 0.16.4`, `RCLONE_VERSION=rclone v1.60.1-DEV`.
- Release Restic 0.19.1 descargado, `SHA256_PINNED_RELEASE=OK` (huella ya comprobada contra release API GitHub), descompresión Python bz2 OK, `RESTIC_STDIN_FROM_COMMAND=OK`, `RCLONE_BACKEND_RESTIC=OK`; **copia cifrada y restauración LOCAL efímera con datos sintéticos OK**: `PRUEBA_CIFRADA_Y_RESTAURACION_LOCAL=OK`. `RESTIC_ACTUAL=restic 0.19.1 compiled with go1.26.4 on linux/amd64`, `RESTIC_APT_ANTERIOR_EN_USR_BIN=CONSERVADO`. API/DB/Web healthy e IDs intactos, `O5_HERRAMIENTAS_COMPATIBLES=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; log `/tmp/vencira-o5-restic-compat.9oygg9cL.log`; Google Drive no conectado, sin migraciones/reinicios.
- **Hito herramientas CERRADO: no ejecutar otra vez `scripts/o5_install_backup_tools.sh` ni `scripts/o5_install_restic_official.sh`**. No se ha configurado Google OAuth ni probado copia/restauración remota real, por lo que **O5 NO completada**. Usuario deberá realizar autorización de Google personalmente, sin pegar secretos en conversación.
- **Siguiente acción en navegador del usuario (no SSH todavía)**: Google Cloud Console de `appvencira@gmail.com`; proyecto `VENCIRA Backups`, Drive API habilitada; OAuth consent Branding/Audience **External** (Gmail personal; Internal requiere Workspace) y permiso **`drive.file`**, cliente OAuth **Desktop** `VENCIRA Backup Rclone`. Tras crearlo, notificar solo **«cliente OAuth creado»** sin identificadores ni secretos. Rclone compartido 2026 retirándose, usar cliente propio. **AVISO crítico**: si OAuth External permanece en Testing, refresh token vence ~7 días; no automatizar hasta comprobar configuración del cliente en estado In Production y permitir acceso de prueba/restauración, sin implicar producción de VENCIRA.
- Luego preparar en servidor un `rclone.conf` root:0600 y secretos de Restic root:0600, OAuth headless con navegador/túnel seguro; primera copia encriptada con el guion `scripts/o5_backup_to_drive.sh`, prueba de recuperación aislada `scripts/o5_restore_drill.sh` y validación, sólo después timer. No subir nunca el dump local en claro a Drive; mantener `vencira_preview` aislado. Detalles en `docs/OPERATION_O5_DRIVE_BACKUPS.md`.

## O5 — Cliente OAuth creado; configuración privada Rclone pendiente (23/10/2026)

- El usuario confirmó **«OAuth creado»** para el cliente Google Cloud (cuenta interna `appvencira@gmail.com`). Es una declaración de creación del cliente, no autorización de Drive en Ubuntu. Por ahora `GOOGLE_DRIVE_NO_CONECTADO=1`: no hay token rclone ni backup externo. No volver a pedir creación del cliente.
- Script nuevo en GitHub `scripts/o5_configure_drive_oauth.sh` con corrección de comprobación de symlink `165181d46cec86a3d4a553bac04b0a6d703531f1`. Verifica rama, Restic 0.19.1, Rclone y salud de los tres contenedores; prepara `/etc/vencira-backup/rclone.conf` exclusivamente root 0600 bajo directorio root 0700 sin sobrescribir remoto existente. Ejecuta `rclone config` interactivo (no logueado), exige remoto `vencira_google`, `type=drive`, `scope=drive.file`, `client_id`/secret/token presentes y acceso real de lectura `rclone lsd vencira_google:` sin exponer rutas. No crea repositorio Restic ni modifica DB/Compose. **AÚN NO EJECUTADO**.
- Dependencia SSH: para autorizar desde Android o PC se necesita acceso al navegador y **túnel local** `127.0.0.1:53682` del dispositivo hacia `127.0.0.1:53682` del servidor; ver `https://rclone.org/remote_setup/`. Con túnel seleccionar `Y` (browser auto-config), abrir URL de Rclone solo en dispositivo propietario del túnel. Sin túnel elegir `N` y `rclone authorize` desde equipo que tenga Rclone y navegador; no abrir puerto público. No dar por hecho el tipo de app SSH del usuario.
- Comando único del siguiente paso: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_configure_drive_oauth.sh || exit 1; bash scripts/o5_configure_drive_oauth.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. **CONFIDENCIALIDAD CRÍTICA**: Rclone puede imprimir Client Secret o token en la configuración interactiva: nunca pedir/copiar la salida completa. Solo solicitar los estados sin secretos `OAUTH_PROPIO_SCOPE_DRIVE_FILE=OK`, `RCLONE_CONF_ROOT_PERMISOS=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_OAUTH_CONFIGURADO=1`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`, o `FASE_FALLIDA`. No subir config/token/secrets a GitHub o ChatGPT.
- Confirmar audience OAuth para evitar tokens caducados a 7 días `External/Testing` antes de programar copias; el estado OAuth *In production* no autoriza aún producto real ni datos personales. Siguiente hito tras conexión: contraseña Restic custodiada fuera del servidor, repo remoto cifrado, backup real de `vencira_localcheck-db-1` y restore aislado, después systemd monitorizado. No usar `rclone copy` de dumps locales.

## O5 — Rclone remoto ya existente, verificar sin sobrescribir (23/10/2026 23:31)

- Resultado aportado por usuario: ejecución de `scripts/o5_configure_drive_oauth.sh` desde `27659dc5eec76a9652cee865385534418d60b7fd` con `RESTIC=0.19.1`, `RCLONE=DISPONIBLE`, `STACK_LOCALCHECK=healthy`. Error intencional `remoto vencira_google existente. No sobrescribir`: `RESULTADO_GLOBAL=3`, `FASE_FALLIDA=PREPARAR_CONFIG_ROOT`, `RESULTADO_EJECUCION=3`; `COPIA_DRIVE_NO_EJECUTADA=1`, `SIN_MIGRACIONES_NI_REINICIOS=1`. El remoto podría estar configurado o incompleto; ninguna afirmación de acceso Drive.
- GitHub: `scripts/o5_probe_existing_drive.sh`, commit `bc8bf28bfe941c3fd5b35ef1e3da4211d565c70e`: verifica Rclone root 700/600 y metadatos en local sin imprimir ID, secreto o token, comprueba `type=drive`, `scope=drive.file` y token OAuth con refresh, consulta solo metadatos de carpetas Drive descartando contenido. **No overwrites ni backup**; posible renovación de token almacenado root 600. Impide mutar la DB/servicios.
- Próxima acción única en Ubuntu: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_probe_existing_drive.sh || exit 1; bash scripts/o5_probe_existing_drive.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. Resultado `RCLONE_GOOGLE_DRIVE_ACCESO=OK` / `RCLONE_EXISTENTE_VALIDADO=1` indica posibilidad de seguir a repo Restic cifrado sin reconfigurar cliente. Si falla, resolver específicamente `FASE_FALLIDA` y nunca pedir la configuración/token/secreto/URLs de OAuth por chat.
- Mantener O1–O4, no datos reales, no subir dump PostgreSQL sin cifrar. Referencia `docs/OPERATION_O5_DRIVE_BACKUPS.md`.

## O5 — Token OAuth no es JSON válido; reconexión controlada preparada (23/10/2026)

- Usuario ejecutó `scripts/o5_probe_existing_drive.sh` en `6e35ffb6e20e8bb7847959ce8ee9efa836b98d33`, los tres `HEALTH_* = healthy`, `CONFIG_PRIVADA_ROOT_0700_0600=OK`, `RCLONE_TIPO_DRIVE=OK`, `RCLONE_SCOPE_DRIVE_FILE=OK`, `RCLONE_CLIENTE_OAUTH_PROPIO=OK`. **`RCLONE_TOKEN_OAUTH=NO_VALIDO`**, `RESULTADO_GLOBAL=5`, `FASE_FALLIDA=METADATOS`, `RESULTADO_EJECUCION=5`, `CONFIG_NO_SOBRESCRITA=1`, `SIN_ARCHIVOS_CREADOS_EN_DRIVE=1`, `SIN_BACKUP_NI_MIGRACIONES=1`. El token no se puede interpretar como JSON; no hay evidencia de conectividad a Drive.
- Script GitHub `scripts/o5_reauthorize_existing_drive.sh`, commit `a4a33e0ad5b0f2807e6ecedcc53960bf624d90f5`. Comprobación de stack, Restic 0.19.1, remoto root:700/600, cliente propio+scope mínimo `drive.file`, TTY; guarda una copia temporal privada de `rclone.conf`; **ejecuta `rclone config reconnect vencira_google:`** en vez de borrar/recrear. En error restaura config anterior, limpia copia; en éxito comprueba estructura de token sin mostrar secreto y `rclone lsd vencira_google:` con stdout/stderr descartados. NO escribe backups ni altera DB. El flujo OAuth puede mostrar datos sensibles: **no solicitar transcripción/capturas**, solo indicadores finales.
- Dependencia real: requiere **túnel SSH local `127.0.0.1:53682`** desde el navegador del dispositivo hacia el servidor, o solución headless por `rclone authorize` siguiendo `https://rclone.org/remote_setup/`. No abrir dicho puerto públicamente; si Android no soporta túneles, resolver antes de ejecutar. Con túnel, usuario abrirá URL de autorización local de Rclone, usará exclusivamente `appvencira@gmail.com`. Si `reconnect` no admite token malformado, la salida `FASE_FALLIDA=RCLONE_RECONNECT` permitirá alternativa sin exponer secretos.
- Siguiente comando SSH: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_reauthorize_existing_drive.sh || exit 1; bash scripts/o5_reauthorize_existing_drive.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. **Todavía no ejecutado**. Si éxito se espera `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0`, sin copia hasta fase posterior. Si falla, no repetir ciegamente.
- Mantener inalterados O1–O4, migración `0014`, `vencira_preview`. No datos reales. Referencia `docs/OPERATION_O5_DRIVE_BACKUPS.md`.

## O5 — Error de puerto 53682 ocupado; diagnóstico seguro pendiente (23/10/2026)

- Salida aportada: en reconexión interactiva de `vencira_google` usuario marcó `y` en `Use auto config?`, Rclone falló al iniciar servidor OAuth local: `listen tcp 127.0.0.1:53682: bind: address already in use`. Script protegió estado anterior: `CONFIG_ORIGINAL_RESTAURADA=1`, `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=RCLONE_RECONNECT`, `O5_GOOGLE_OAUTH_VERIFICADO=0`, `SIN_ARCHIVOS_CREADOS_EN_DRIVE=1`, `SIN_COPIAS_NI_MIGRACIONES=1`, `RESULTADO_EJECUCION=1`. No concluir qué proceso ocupa puerto; ni que OAuth esté autorizado.
- GitHub: `scripts/o5_diagnose_oauth_port.sh` commit `718c12fca1b93de070fdeb188e3f0435555f84e9`. Diagnóstico no destructivo de bind local, `ss -H -lntp` con salida restringida a nombre de proceso, PID, UID e interfaz, preflight Git y Docker healthy. No leer tokens ni argumentos; no matar procesos. Puede ver ocupado/libre; no garantiza persistencia de estado.
- **Siguiente bloque único:** `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_diagnose_oauth_port.sh || exit 1; bash scripts/o5_diagnose_oauth_port.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. Pedir solo indicadores `PUERTO_53682`, `PUERTO_PROCESO`, `PUERTO_PID`, `PUERTO_DIRECCION`, `RESULTADO_GLOBAL`. No tocar Google o DB. Si SSH tunnel `-R` en Ubuntu, corregir como `-L` **desde navegador local**; sin identificar, no cerrar socket a ciegas.
- Estado: conexión Google no verificada y token previo malformado; no copiar dumps a Drive ni declarar O5 operativa. Resumen completo `docs/OPERATION_O5_DRIVE_BACKUPS.md`.

## O5 — Google OAuth 403 por falta de test user (24/10/2026)

- El usuario confirmó que el puerto localhost 53682 de Ubuntu volvió a estar `LIBRE`, ejecutó `scripts/o5_reauthorize_existing_drive.sh` con túnel desde el PC y llegó a la pantalla de autorización Google. Google mostró: app **VENCIRA Internal Backups** todavía en pruebas, acceso permitido solo a testers aprobados, cuenta `appvencira@gmail.com`, **error 403 access_denied**. No hay consentimiento completado ni token OAuth nuevo verificado, no hay backup externo.
- Próxima acción **sin SSH**: en `https://console.cloud.google.com/auth/audience`, seleccionar proyecto existente `VENCIRA Backups`, sección `Test users`, añadir `appvencira@gmail.com` y guardar. Mantener `External / Testing` para terminar la autorización de prueba. En el navegador del PC que mantiene túnel SSH 53682 volver a abrir la URL localhost de OAuth de la sesión activa. Si expirada, Ctrl+C y volver a ejecutar **solo** `scripts/o5_reauthorize_existing_drive.sh` (el script restaura config original al abortar). No pegar secretos/token/enlace OAuth en chat ni usar `rclone config` para reemplazar remoto.
- Google afirma 7 días de vigencia para refresh tokens externos en Testing con alcance Drive: no activar systemd/cron hasta resolver credenciales de larga duración adecuadas y política OAuth. Fuente oficial `https://support.google.com/cloud/answer/15549945` y `https://developers.google.com/identity/protocols/oauth2`.
- Documento O5 actualizado en commit `b52b1777646dad2d98a70310e332c12ca1951271`; no se cambió código. Esperar `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0` antes de proceder a repo Restic cifrado y restauración remota. **No afirmar que O5 terminó.**

## O5 — Consentimiento OAuth navegador exitoso, esperando validación de Rclone (24/10/2026)

- Usuario informa pantalla Google «Success! All done. Please go back to rclone.» tras corregir 403 añadiendo tester. OAuth de navegador culminó; **aún no se ha recibido salida del terminal Ubuntu**, de modo que no se puede afirmar token OAuth persistido ni acceso remoto a Drive ni copia.
- Siguiente paso: volver a la ventana SSH manteniendo túnel, dejar finalizar `scripts/o5_reauthorize_existing_drive.sh` y compartir **únicamente** indicadores sin secretos: `RCLONE_TOKEN_OAUTH_VALIDO`, `RCLONE_GOOGLE_DRIVE_ACCESO`, `O5_OAUTH_CONFIGURADO`, `O5_GOOGLE_OAUTH_VERIFICADO`, `RESULTADO_GLOBAL`, `RESULTADO_EJECUCION`; jamás transcripción interactiva del OAuth, URLs o tokens.
- Documento O5 complementario actualizado, commit `97ed687bc93d00d99d0f4952cb9d6dd7c3cdc9cb`. No se ha modificado el servidor ni código desde esta confirmación. Tras OAuth validado, fase de Restic cifrado y restauración aislada, no habilitar automatización con refresh token Testing que caduca a los 7 días.

## O5 — OAuth validado; siguiente inicialización de repositorio cifrado (24/10/2026)

- El usuario confirmó éxito terminal de OAuth existente: `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_SCOPE_DRIVE_FILE=OK`, `RCLONE_CONF_ROOT_PERMISOS=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_OAUTH_CONFIGURADO=1`, `RESULTADO_GLOBAL=0`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `SIN_ARCHIVOS_CREADOS_EN_DRIVE=1`, `SIN_COPIAS_NI_MIGRACIONES=1`, `RESULTADO_EJECUCION=0`. **No hay backup remoto ni repo Restic remoto todavía**. No repetir OAuth.
- Script nuevo `scripts/o5_init_restic_drive.sh` con revisión final `1b2251b5ab5b9f7a9b36a4e6e3ca962b9e117f9c`: root con TTY, locking, controles de identidad/health, cliente Drive scope mínimo y token actual, acceso remoto; si hay contraseña o config root existente, rechaza sobrescribir. Genera clave criptográfica aleatoria de 256 bits, la muestra **solo en terminal privado** para guardarla FUERA de Drive y Ubuntu, exige reingreso invisible y confirmación `GUARDADA`. Crea `/etc/vencira-backup/restic-password` y `config.env` root:600, inicializa repositorio cifrado Restic remoto, sube y recupera un archivo sintético y hace `restic check`. **No se ha ejecutado**; no copias de PG ni jobs, no migraciones.
- Siguiente comando único SSH: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_init_restic_drive.sh || exit 1; sudo bash scripts/o5_init_restic_drive.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`.
- **PROTEGER CLAVE RESTIC:** la transcripción de esta ejecución contiene la clave privada mostrada una vez en TTY; usuario NO debe enviar captura/transcripción completa a ChatGPT, GitHub ni a terceros. Solicitar solo `GOOGLE_DRIVE_ACCESIBLE`, `RESTIC_REPOSITORIO_REMOTO`, `PRUEBA_CIFRADA_DRIVE_RESTAURACION`, `RESTIC_CHECK`, `REPO_RESTIC_REMOTO_INICIALIZADO`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA`, `RESULTADO_GLOBAL`, `RESULTADO_EJECUCION`; ante fallo, solo `FASE_FALLIDA`. Clave perdida = copias irrecuperables, proteger fuera del host. No reejecutar instalador inicial si falló tras crear clave/repositorio.
- Próxima puerta real tras este resultado: backup PG cifrado y restauración PG17 aislada, sin tocar esquema `0014`; luego automatizar con token OAuth duradero. Mientras OAuth Google External esté en Testing, refresh tokens con Drive caducan a 7 días; **no automatizar todavía** y evaluar cambio a In production y posible reautorización para continuidad. Detalles `docs/OPERATION_O5_DRIVE_BACKUPS.md`.

## O5 — Error TTY al custodiar clave Restic; subsanado en repo (24/10/2026)

- El usuario ejecutó `scripts/o5_init_restic_drive.sh` desde commit `b2d0bf698ff208a2986aab24d9cc99563e3ebad7`, y reportó dos veces la misma salida: `HEALTH_api/db/web_preview=healthy`, `RCLONE_PRIVADO_SCOPE_Y_TOKEN=OK`, `GOOGLE_DRIVE_ACCESIBLE=OK`; error `io.UnsupportedOperation: File or stream is not seekable` en `CUSTODIA_CLAVE`. `RESULTADO_GLOBAL=1`, `RESULTADO_EJECUCION=1`, `CLAVE_PRIVADA_EN_SERVIDOR=0`, `REPO_RESTIC_REMOTO_INICIALIZADO=0`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA=0`, `POSTGRES_NO_RESPALDADO_AUN=1`, `SIN_MIGRACIONES_NI_REINICIOS=1`. **Seguro reintentar solo después del fix**, pues el script falló ANTES de escribir clave o crear repositorio.
- **Causa exacta:** `open('/dev/tty','r+')` se comparte para lectura/escritura bajo buffering; puede intentar `seek()` sobre terminal SSH no seekable. Reemplazado por dos flujos `open('/dev/tty','w')` y `open('/dev/tty','r')`, `getpass.getpass(stream=tty_out)` y lectura exclusiva `tty_in.readline()`. Código cambiado en `scripts/o5_init_restic_drive.sh` commit `48a95556d7cbd4c5cc026824a04cf734eb77508a`. Test aislado de diálogo de clave en pseudoTTY: `TTY_EXIT_CODE=0`, `TTY_TEST_STAGES=2`, `TTY_COMMITMENT_WRITTEN=True`. **Aún no se ha ejecutado la versión corregida en Ubuntu ni inicializado Drive**.
- Guía temática y evidencia completa: `docs/OPERATION_O5_DRIVE_BACKUPS.md` commit `55cbbc7a9ccc486a64f995e4142c9e8f100c4de5`.
- **Siguiente bloque único:** `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/o5_init_restic_drive.sh || exit 1; sudo bash scripts/o5_init_restic_drive.sh ); echo "RESULTADO_EJECUCION=$?"; echo "CONSOLA_ABIERTA"`. Durante la ejecución el script imprimirá una clave secreta **SOLO para custodiarla fuera del servidor y Drive**; no pegar salida entera en ChatGPT. Enviar únicamente `RESULTADO_GLOBAL`, `FASE_FALLIDA` si aplica, `CLAVE_PRIVADA_EN_SERVIDOR`, `REPO_RESTIC_REMOTO_INICIALIZADO`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA`, `RESULTADO_EJECUCION`. Si resulta parcial y hay clave/repo, detenerse y preparar recuperación sin crear otra clave.
- OAuth Drive externo en Testing puede expirar a 7 días. No programar backups automáticos antes de resolver caducidad, restauración PG17 y alertas. No cambiar O1–O4.

## Límites de lanzamiento

- **No apto para datos personales reales ni producción**. Ver `docs/SECURITY_RELEASE_READINESS_2026-10-22.md` y `docs/SECURITY.md`: MFA, backups externos cifrados/restauración, cifrado en reposo, permisos, retención, RGPD/LOPDGDD y control de adjuntos aún pendientes.
- No habilitar upload/download de PDFs e imágenes hasta implementar controles de `docs/ATTACHMENTS_SECURITY_GATE.md`.
- No activar recordatorios reales por el mero hecho de desplegar la nueva ficha.

## En un chat nuevo

Leer primero este archivo desde GitHub y consultar las últimas confirmaciones del usuario sobre resultados del servidor. **No asumir que un PR fusionado equivale a despliegue.** Mantener el esquema `GitHub → pruebas aisladas → backup → migraciones → despliegue localcheck → Android → documentación final`. Evitar requerir al usuario información o verificaciones ya conocidas.

## O5 — Restic remoto cifrado VERIFICADO; primera restauración PostgreSQL pendiente (24/10/2026)

**Resultado real aportado por el usuario** tras corregir el TTY, sin copiar la clave privada:
```text
CLAVE_GUARDADA_FUERA_DEL_SERVIDOR=CONFIRMADA_POR_USUARIO
CLAVE_EN_ARCHIVO_PRIVADO_ROOT_0600=OK
RESTIC_REPOSITORIO_REMOTO=CREADO
PRUEBA_CIFRADA_DRIVE_RESTAURACION=OK
RESTIC_CHECK=OK
CLAVE_PRIVADA_EN_SERVIDOR=1
REPO_RESTIC_REMOTO_INICIALIZADO=1
PRUEBA_CIFRADA_DRIVE_RESTAURADA=1
POSTGRES_NO_RESPALDADO_AUN=1
SIN_MIGRACIONES_NI_REINICIOS=1
RESULTADO_GLOBAL=0
RESULTADO_EJECUCION=0
```

**Hito real confirmado:** acceso Rclone con OAuth propio y alcance `drive.file`, clave Restic protegida por root y declarada bajo custodia externa por el usuario, repositorio `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` inicializado, snapshot sintético subido y leído/descifrado desde Drive y `restic check` correcto. **NO reejecutar `o5_init_restic_drive.sh`, no generar una segunda clave, ni repetir OAuth.** No hay aún copia real de la BD.

**Corrección preventiva del ensayo**: `scripts/o5_restore_drill.sh` deja de usar `restic dump latest vencira-postgres.dump` (podría elegir el snapshot sintético O5 u otro), y utiliza `restic dump --tag vencira-postgresql latest vencira-postgres.dump`. El filtro `--tag` sobre `latest` está documentado por Restic 0.19.1. Se añade confirmación de tablas públicas restauradas. El ensayo mantiene PostgreSQL 17 temporal sin red ni volumen persistente, limpia contenedor al terminar, verifica migración 0014 e identidad Docker original sin alteraciones.

**Siguiente operación, aún NO ejecutada por el usuario:** primera copia PostgreSQL del stack DEV + recuperación remota íntegra en contenedor efímero. Ejecutar como usuario `vencira`, desde SSH, una sola vez:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  echo "COMMIT=$(git rev-parse HEAD)"
  bash -n scripts/o5_backup_to_drive.sh || exit 1
  bash -n scripts/o5_restore_drill.sh || exit 1
  sudo bash scripts/o5_backup_to_drive.sh || exit 1
  sudo bash scripts/o5_restore_drill.sh || exit 1
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

Éxito esperado **solo tras ejecutar**: en copia `DB_LOCALCHECK_HEALTHY=1`, `RESTIC_DRIVE_ACCESIBLE=1`, `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `RESTIC_INTEGRIDAD_METADATA=OK`, `RESULTADO_GLOBAL=0`; en ensayo `DRIVE_SNAPSHOT_ACCESIBLE=1`, `PG17_EFIMERO_SIN_RED=OK`, `RESTAURACION_PG17_DESDE_DRIVE=OK`, `ESQUEMA_O3_RESTAURADO=0014_renewal_outcomes`, `RESTIC_SNAPSHOT_TAG=vencira-postgresql`, `POSTGRES_ORIGINAL_INTACTO=1`, `O5_RESTAURACION_REMOTA_VERIFICADA=1`, `RESULTADO_GLOBAL=0`; al final `RESULTADO_EJECUCION=0`. La copia incluye **solo datos sintéticos del entorno DEV**, no permite subir datos de clientes ni habilitar producción.

Ante cualquier fallo: **no repetir todo el bloque** ni cambiar clave ni recrear repositorio; aportar solo marcadores seguros, `FASE_FALLIDA` y, si procede, errores acotados sin credenciales ni datos de clientes. No ejecutar restauración contra el PostgreSQL en uso.

**No activar backup diario todavía.** Google OAuth External/Testing con `drive.file` puede emitir refresh token caducable a los 7 días: revisar Audience/publishing status y autorización adecuada antes de systemd. Falta política de retención, alerta en fallo y defensa de segunda ubicación independiente ante borrado/ransomware. Estado OAuth `In production` no equivale a producto VENCIRA en producción. Fuente Google: https://developers.google.com/identity/protocols/oauth2 .

## ÚLTIMO ESTADO — O5 copia PostgreSQL remota y restore en PG17 verificados (24/10/2026)

Confirmado por salida del usuario desde Ubuntu en commit `28830104fbbcf579b7ccbf32912c1053137b90d5`:
- `DB_LOCALCHECK_HEALTHY=1`, `RESTIC_DRIVE_ACCESIBLE=1`, `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `RESTIC_INTEGRIDAD_METADATA=OK`, `RESULTADO_GLOBAL=0`.
- Snapshot Restic cifrado de PostgreSQL `7a2f5018`, 70,332 KiB procesados, 16,025 KiB almacenados; backup con `--stdin-from-command`, sin crear dump local.
- Restauración desde Drive en PostgreSQL 17 efímero sin red, `RESTAURACION_PG17_DESDE_DRIVE=OK`, esquema `0014_renewal_outcomes`, `TABLAS_PUBLIC_RESTAURADAS=21`, `POSTGRES_ORIGINAL_INTACTO=1`, `O5_RESTAURACION_REMOTA_VERIFICADA=1`, `RESULTADO_EJECUCION=0`.
- **No repetir** inicialización de Restic, recuperación de clave, reconexión OAuth ni este primer ensayo por defecto. Secretos no expuestos. **Copia manual validada, automatización aún deshabilitada**.
- Detalle operativo, limitaciones de integridad e instrucciones: `docs/OPERATION_O5_DRIVE_BACKUPS.md`, nueva sección final del 24/10.
- **Próximo paso inmediato**: pedir solo el dato `Google Auth Platform → Audience → Publishing status` del proyecto OAuth VENCIRA Backups (`Testing` o `In production`). No puede deducirse desde el token Rclone. `Testing` implica caducidad de refresh token a 7 días con `drive.file` (https://developers.google.com/identity/protocols/oauth2). Si cambia el estado, evaluar reautorización protegida y comprobar acceso sin sobrescribir el repo; no ordenar reconectar ciegamente. Después preparar/probar systemd timer, retención, alerta de fallos y de antigüedad, restauraciones periódicas e independencia ante borrado malicioso. **No activar cron/timer hasta resolver OAuth**.
- No producción ni datos personales reales; no migraciones ni reinicios autorizados.

## 24/10/2026 — Google OAuth sigue en Testing (confirmado); publicación pendiente

**Nueva confirmación del titular:** en Google Auth Platform → Audience, el proyecto **VENCIRA Backups** para `appvencira@gmail.com` figura como **External / Testing**. No inferir `In production` por el éxito actual de OAuth, ni programar tareas automáticas. La autorización del 24/10 con `drive.file` se obtuvo mientras la app seguía en Testing; por la regla de Google su refresh token puede caducar a los siete días y la conexión dejar de funcionar. Referencia oficial: https://support.google.com/cloud/answer/15549945 y https://developers.google.com/identity/protocols/oauth2 .

**Decisión técnica propuesta al titular:** pasar *únicamente la app administrativa OAuth para copias* al estado **In production** (no es publicar VENCIRA ni sus datos, código o API). Antes de pulsar `Publish app`, inspeccionar Google Auth Platform → Data Access y comprobar que **el único scope de Google Drive** es `https://www.googleapis.com/auth/drive.file` (no pedir `drive`, `drive.readonly` ni permisos amplios). Google clasifica `drive.file` como **non-sensitive**, sujeto a requisitos de verificación básica y posibles restricciones concretas del proyecto: https://developers.google.com/workspace/drive/api/guides/api-specific-auth . En `Google Auth Platform → Audience`, pulsar `Publish app` y comprobar estado `In production`. Si la interfaz solicita verificación, bloquea o exige cambios inesperados, **detenerse y evaluar el requisito, sin inventar URLs, permisos ni desactivar controles**.

**Advertencia de alcance:** publicar la app OAuth External permite que cualquier cuenta Google intente autorizar sus propios datos con ese cliente. No habilita el sitio web VENCIRA para clientes, no concede a terceros la clave Restic ni acceso a los archivos privados del titular. Mantener el cliente OAuth de tipo Desktop existente y la cuenta técnica exclusivamente interna. Google puede seguir mostrando avisos de app sin verificar conforme a su política de verificación.

**Una vez el titular confirme `In production` (NO ANTES)**: efectuar reconexión del **remoto existente** con `scripts/o5_reauthorize_existing_drive.sh` desde sesión SSH interactiva con túnel local `127.0.0.1:53682`, para solicitar nueva autorización bajo el estado publicado. El script ya validado realiza copia temporal privada `root:600` de `rclone.conf`, usa `rclone config reconnect vencira_google:`, verifica token y `rclone lsd`, intenta rollback de config en error y no toca Restic ni PostgreSQL. Antes de usarlo, sincronizar rama y revisar contexto/puerto; los códigos/enlaces OAuth son secretos de sesión y no se comparten. **No se ha ejecutado esta reconexión por el cambio de estado**. Una autorización antigua emitida en Testing no se considera duradera sin emisión nueva y prueba.

**Verificación posterior obligatoria**: con config `root:700/600`, comprobar acceso al repositorio Restic existente y al snapshot de PostgreSQL **`7a2f5018`**, sin mostrar ni restaurar los datos en pantalla, ni publicar rutas privadas/token. Debe comprobarse que la autorización nueva permite renovar credenciales posteriormente. No recrear repo, no ejecutar `restic init`, no regenerar clave ni modificar Docker; no cron/timer, retención/poda o migraciones hasta que esa fase sea OK.

**Estado actual:** snapshot cifrado real de PG17 `7a2f5018` y restauración sin red con 21 tablas y migración `0014_renewal_outcomes` ya verificados el 24/10; **OAuth Testing confirmado**, transición y renovación pendientes, política de copia automatizada no habilitada.

## 24/10/2026 — Diagnóstico confirmado del bloqueo «Publicar app» (HTML real Google Cloud)

**Evidencia aportada por el titular:** dos capturas HTML SingleFile de `Google Auth Platform → Público` (16:45:36 CEST) y `Información de la marca` (16:46:10 CEST), proyecto `vencira-backups`. No subir esos HTML completos a GitHub: contienen contenido de consola administrativa y podrían incluir datos de sesión.

**Error literal de la UI (Público):** «Se requieren un nombre de app, un correo electrónico de asistencia, una URL de página principal y una URL de política de privacidad válidos para cambiar la app al modo de producción externo. Debes ingresar la información faltante ... Visita la página de desarrollo de la marca para terminar de configurar tu app». `Publicar app` aparece en Testing, sin completar branding.

**Verificación precisa del formulario Branding por valores de INPUT del HTML (no solo etiquetas):**
- Nombre de aplicación **ya establecido**: `VENCIRA Internal Backups`.
- Correo de asistencia y del desarrollador **ya establecido**: `appvencira@gmail.com`, mantener **interno** y no añadirlo gratuitamente como email público de la web. Google ya lo puede mostrar en la pantalla de consentimiento, en función de sus reglas.
- Dominio autorizado **ya añadido**: `vencira.es`, pero su presencia en consola no demuestra por sí sola dominio verificado en Google Search Console ni sitio público accesible.
- Campos **vacíos**: `Página principal de la aplicación`, `Vínculo a la Política de Privacidad`, `Vínculo a las Condiciones del Servicio`. Los dos primeros son los bloqueantes declarados por Google; términos son opcionales en esta pantalla.
- Logo no aportado, **no necesario** para la corrección; añadirlo puede desencadenar revisión de marca.
- Tipo de usuario `External`; cuenta de pruebas registrada, 1/100. No es un error de límite de testers, Rclone, Restic ni permisos de PostgreSQL.

**Plan de corrección, sin cambios aún en hosting:**
1. Antes de inventar URLs, comprobar si `https://vencira.es/` tiene un sitio funcional y accesible públicamente sin credenciales. La comprobación web desde esta sesión no pudo validar el host; no afirmar que exista/funcione o que el dominio raíz apunte ya al VPS. `dev.vencira.es` es privado/entorno DEV, no usar como página principal OAuth.
2. Proponer rutas a crear en el dominio controlado: `https://vencira.es/oauth-backups/` (explica que se trata de una integración administrativa interna de copias cifradas de VENCIRA a Google Drive vía Restic/Rclone, no un servicio público) y `https://vencira.es/oauth-backups/privacidad/` (política transparente y exacta sobre accesos `drive.file`, tipo de datos, cifrado, custodia, almacenamiento, terceros, retención y contacto responsable; revisar jurídicamente y no inventar identidades o buzones no configurados). Son URLs **futuras propuestas, no publicadas**.
3. Publicar los dos recursos estáticos exclusivamente después de determinar la configuración DNS/web actual y el destino Nginx adecuado; no tocar `vencira_localcheck`, `vencira_preview`, los contenedores ni Docker/postgres. Garantizar HTTPS válido y que ambas páginas son públicas sin autenticación y se enlazan entre sí. Verificar propiedad de `vencira.es` en Google Search Console si Google lo exige.
4. En Google Auth Platform → Branding guardar URL pública de la página principal y de la privacidad (términos opcionales). Luego Audience → `Publish app`; detenerse si hay nueva exigencia de verificación y revisarla. Los cambios en branding no requieren recrear el cliente OAuth Desktop ni ampliar scope.
5. Tras estado `In production` verificado, renovación controlada del **remoto existente** con script ya documentado, y lectura segura del snapshot `7a2f5018` antes de systemd. No iniciar `restic init`, cambiar clave, reautorizar antes de solucionar branding ni activar backups desatendidos.

**Normativa oficial:** https://support.google.com/cloud/answer/15549049 ; https://support.google.com/cloud/answer/13807376 ; https://developers.google.com/identity/protocols/oauth2/policies ; `drive.file` no sensible https://developers.google.com/workspace/drive/api/guides/api-specific-auth .

**Estado al cierre del diagnóstico:** causa del bloqueo **identificada de forma directa en HTML**; sitio público y política **pendientes de crear/publicar**, OAuth sigue Testing y backups automáticos desactivados; backup cifrado manual y restauración aislada válidos.

## 24/10/2026 — Solicitud del titular: retirar contraseña HTTP del acceso web

**Petición explícita del titular:** indica que la web tiene contraseña HTTP y solicita quitarla para dejar acceso libre. **No se ha cambiado ni retirado ninguna protección aún.** Debe distinguirse el host `dev.vencira.es` (la observación histórica es HTTP 401 anónimo y app de desarrollo `vencira_localcheck` protegida) del raíz `vencira.es` (DNS reportado por Ubuntu `213.186.33.5`, `curl https://vencira.es/` HTTP=000 con conexión TLS reiniciada; `www` conexión fallida). Eliminar Basic Auth de DEV **no** resuelve TLS/DNS del apex ni publica automáticamente las páginas OAuth que necesita Google.

**Criterio para ejecutar la petición sin dañar el entorno:** primero diagnosticar de solo lectura el proxy real Caddy/Nginx del VPS, rutas de ficheros de configuración y existencia de la directiva `basic_auth`/`basicauth`/`auth_basic`; **nunca imprimir hashes, credenciales ni el Caddyfile completo**. Si se autoriza retirar la barrera global de `dev.vencira.es`, exigir que la autenticación Django, rutas Admin inaccesibles, CSRF, endpoints sensibles restringidos, y datos exclusivamente sintéticos sigan vigentes; tomar copia privada del archivo de configuración, validar el nuevo proxy y hacer reload con posibilidad de rollback, sin Docker ni BD. Recomendación más restrictiva: dejar DEV tras la barrera y abrir solo estáticos informativos OAuth en host público independiente `vencira.es`, tras resolver DNS/TLS.

**Estado:** en espera de diagnóstico del proxy real, sin cambios en firewall/proxy/Docker/Google OAuth/Restic; programación automática de backups aún bloqueada.

## 24/10/2026 — Preflight real Caddy: diagnóstico recibido; aún sin retirar Basic Auth

Salida confirmada del titular desde el VPS:
```text
caddy=active
nginx=inactive
apache2=inactive
/etc/caddy/Caddyfile
/etc/caddy/Caddyfile.vencira-backup.kNTE0UnB
/etc/caddy/Caddyfile.vencira-backup.EafhDzyW
/etc/caddy/Caddyfile.pre-api-directa.bak
DEV_HTTP=401 TLS=0
DIAGNOSTICO_TERMINADO=1
```
En `/etc/caddy/Caddyfile` vigente hay directiva `basic_auth`/`basicauth`, y también en copias históricas (las copias no se tocan). Caddy es el **único proxy activo** de los tres evaluados. El HTTP 401 anónimo es consistente con la barrera Basic Auth, aunque los resultados no muestran aún el **alcance/sitio** exacto de esa directiva; no está autorizado suprimir indiscriminadamente todos los `basic_auth`. `TLS=0` es validación de certificado satisfactoria. El DNS apex `vencira.es` continúa apuntando a `213.186.33.5`, donde HTTPS falla; la futura página pública de OAuth permanece pendiente y no se resuelve retirando auth de DEV.

**Siguiente paso seguro:** inspección de la **estructura redaccionada** del Caddyfile activo (números de línea, hostnames conocidos, nombres de directiva `basic_auth`, `reverse_proxy`, `handle`, `route`, `import`, y apertura/cierre de llaves) sin imprimir hashes, nombres de usuario, tokens, credenciales, rutas privadas ni el archivo en bruto. Tras ver esa estructura, preparar cambio mínimo solo en sitio `dev.vencira.es`, una copia de reversión privada, `caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`, `systemctl reload caddy`, comprobación anónima de respuesta y rollback automático si falla. No tocar PostgreSQL, Docker, Restic ni otros sitios. Fuentes de Caddy: https://caddyserver.com/docs/caddyfile/directives/basic_auth y https://caddyserver.com/docs/command-line .

**Precaución:** eliminar la autenticación perimetral de DEV expone la fachada Django/Flutter a Internet aunque requiera login de app. Mantener datos sintéticos, CSRF/autenticación de app, endpoint /admin bloqueado y restricciones de API; no habilitar uso real ni producción.

## 24/10/2026 — Cambio DEV Caddy Basic Auth preparado; SIN EJECUTAR

El usuario confirmó: Caddy activo y nginx/apache2 inactivos; /etc/caddy/Caddyfile contiene sitio dev.vencira.es que abre en línea 1, bloque Basic Auth entre líneas 2–4, respond línea 6, tres bloques handle/reverse_proxy en líneas 8–18, cierre del sitio en línea 19. Antes del cambio, GET anónimo / devuelve HTTP 401 con TLS correcto. No se ha mostrado hash, contraseña ni Caddyfile completo.

**Código versionado**: scripts/o5_remove_dev_basic_auth.sh (commit 4fa66ab563aeadfe2bb1f6de3d437adaa9bcf8bd). Cambia exclusivamente el bloque Basic Auth de líneas 2–4 en el Caddyfile ACTIVO, con validaciones estrictas de estructura, copia privada root 0700/0600 fuera de GitHub, preparación y validación del candidato, sustitución atómica, systemctl reload caddy, comprobación HTTPS raíz abierta 200/redirect, GET anónimo /api/v1/me/ denegado 401/403 y /admin/ bloqueado 404; rollback automático desde copia si falla aplicación o comprobaciones. No toca respaldos anteriores del Caddyfile, Docker, PostgreSQL, Restic ni DNS.

**Próxima ejecución autorizada en SSH por titular**, como usuario vencira: entrar en /home/vencira/vencira-localcheck; git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash -n scripts/o5_remove_dev_basic_auth.sh; sudo bash scripts/o5_remove_dev_basic_auth.sh. Verificar RESULTADO_GLOBAL=0, RESULTADO_EJECUCION=0, BASIC_AUTH_DEV_RETIRADA=OK, DEV_ME_ANONIMO_HTTP=401/403 y DEV_ADMIN_ANONIMO_HTTP=404. Ante error: FASE_FALLIDA; no repetir a ciegas; comprobar CADDY_CONFIG_ORIGINAL_RESTAURADA=1 y CADDY_RECARGA_REVERSION=OK.

**Riesgo**: retirar la barrera perimetral expone la interfaz DEV y el formulario login de Django a Internet, aunque la autenticación de aplicación y CSRF permanezcan. Solamente datos sintéticos, no habilitar producción. Esta modificación no resuelve el HTTPS/DNS del dominio raíz vencira.es (actualmente 213.186.33.5), ni desbloquea por sí sola Google OAuth External/Testing o la ausencia de URLs públicas de privacidad y página principal.

## 24/10/2026 — FALLO al retirar Basic Auth DEV: Caddy reload y rollback no confirmado

**Salida real del titular** de scripts/o5_remove_dev_basic_auth.sh (commit del script 4fa66ab563aeadfe2bb1f6de3d437adaa9bcf8bd): `CADDY_ACTIVO=1`, `CONFIG_CADDY_COPIA_PRIVADA=OK`, `BACKUP_PRIVADO_LOCAL=/etc/caddy/.vencira-dev-auth-rollback.ce2ECir6`, `CAMBIO_LIMITADO_A_L2_L4=OK`, `CADDY_CANDIDATO_VALIDADO=OK`, **`ERROR=RECARGA_CADDY`**, `=== REVERSION DE CADDY ===`, **`ATENCION=REVISION_MANUAL_DE_CADDY_NECESARIA`**, `FASE_FALLIDA=APLICAR_Y_RECARGAR`, `NO_DOCKER_NI_POSTGRES_NI_RESTIC_MODIFICADOS=1`, **`RESULTADO_GLOBAL=9`, `RESULTADO_EJECUCION=9`**.

**No declarar éxito ni asumir rollback completado**. Del código revisado: la rama de reversión intenta `install` de original al candidato temporal, `mv` candidato a `/etc/caddy/Caddyfile`, `caddy validate` y `systemctl reload caddy`. Su mensaje genérico de error significa que al menos una de esas operaciones falló; si solo falla la última recarga, el archivo original ya puede estar restaurado en disco aunque la recarga del servicio no haya ocurrido. La configuración en memoria puede ser la antigua o la nueva. Es necesario medir ambas. Posibilidad (no verificada): unidad `caddy.service` sin `ExecReload` (CanReload=no) o error del comando de reload; la validación sintáctica bajo root no prueba que el servicio acepte reload.

**Próximo paso URGENTE de solo lectura, no volver a ejecutar script**:
- `systemctl show caddy --no-pager -p ActiveState -p SubState -p CanReload -p Result` para estado y soporte de recarga.
- `sudo cmp -s /etc/caddy/.vencira-dev-auth-rollback.ce2ECir6/Caddyfile.original /etc/caddy/Caddyfile` reportando solamente `CONFIG_DISCO_ES_ORIGINAL=SI/NO`, sin publicar fichero ni credenciales.
- `sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile` con salida suprimida y código; `curl` HTTPS anónimo para raíz y endpoints sin imprimir cuerpos ni cookies; confirmar si raíz sigue 401 o abre anónima.
- No reiniciar Caddy, Docker/Postgres/Restic, no mover archivos, no modificar Google OAuth, no eliminar respaldo privado. Si hay exposición de DEV, priorizar acceso protegido y plan de recarga/reversión controlados tras diagnosticar unidad y logs redaccionados.

**Estado actual**: configuración en disco y memoria PENDIENTE de comprobar; privacidad y seguridad DEV no certificadas. OAuth Testing; raíz `vencira.es` sin HTTPS verificado; no backup diario automático.

## 24/10/2026 — Caddy Basic Auth: rollback en DISCO confirmado, proteccion externa sigue 401

**Nueva evidencia real del usuario** tras script fallido:
```
COPIA_ORIGINAL_EXISTE=SI
CONFIG_DISCO_ES_ORIGINAL=SI
CADDYFILE_VALIDO=SI
RUTA=/ HTTP=401 TLS=0
RUTA=/api/v1/me/ HTTP=401 TLS=0
RUTA=/admin/ HTTP=401 TLS=0
DIAGNOSTICO_RECUPERACION_TERMINADO=1
```
**Conclusión probada:** copia intacta y Caddyfile activo idéntico al original, válido; credencial perimetral sigue operativa desde Internet para las tres rutas, HTTPS válido. No se acredita que se haya modificado la configuración activa en memoria porque el primer reload falló y el siguiente también; sí que los endpoints siguen protegidos y el archivo quedó restaurado. Los campos de servicio `ActiveState/SubState/CanReload/Result` se solicitaron pero no aparecen en la transcripción recibida; no inventar resultado.

**Punto pendiente:** diagnosticar por qué `systemctl reload caddy` devuelve error mientras Caddy continúa sirviendo HTTPS 401. Según https://caddyserver.com/docs/command-line , `caddy reload` usa API administrativa local y necesita que esté habilitada; según https://caddyserver.com/docs/running , `systemctl reload` precisa `ExecReload` válido en la unidad. Determinar de forma NO modificadora `CanReload` y estado, si hay ExecReload sin imprimir parámetros secretos, si el API local escucha en 127.0.0.1:2019 y si hay indicación clasificada de fallo de reload en registros (no compartir logs sin depurar). No ejecutar script nuevamente, no reiniciar Caddy, no quitar Basic Auth sin un mecanismo de recarga verificado previamente. El script o5_remove_dev_basic_auth.sh de esta etapa NO ha tenido éxito; necesita hardening después de diagnóstico.

## 24/10/2026 — Caddy activo, ExecReload configurado y API local disponible

**Salida reportada:** `Result=success`, `ActiveState=active`, `SubState=running`, `CanReload=yes`, `EXECRELOAD_CADDY=CONFIGURADO`, `ADMIN_LOCAL_HTTP=200`, `DIAGNOSTICO_RECARGA=TERMINADO`. Combinado con la verificación anterior `CONFIG_DISCO_ES_ORIGINAL=SI`, `CADDYFILE_VALIDO=SI`, HTTPS anónimo `/ /api/v1/me/ /admin/` = 401 y certificado correcto. **Continuidad del servicio protegida**.

Estos resultados descartan que falle el reload por ausencia de ExecReload o inexistencia del API administrativo local, **pero NO prueban que systemctl reload pueda leer/provisionar correctamente el fichero**, ni identifican la causa concreta del error de reload previo. Según documentación oficial de Caddy, la unidad oficial usa User=caddy y ExecReload=caddy reload --config /etc/caddy/Caddyfile --force; los permisos de lectura de usuario del servicio importan: https://caddyserver.com/docs/running .

**Próxima operación**: comprobación **estrictamente de lectura** de User= definido por systemd, permisos de lectura del Caddyfile bajo ese usuario y clasificación de mensajes recientes del journal sin volcar contenido sensible. **NO repetir** scripts/o5_remove_dev_basic_auth.sh, **NO ejecutar** reload ni restart con cambios pendientes y no modificar DNS/OAuth/DB. Si los permisos son correctos, comprobar códigos de error de journal redaccionados y causa efectiva antes de editar de nuevo.

La retirada de Basic Auth continúa PENDIENTE; OAuth sigue Testing y el dominio raíz vencira.es no sirve HTTPS.

## 24/10/2026 — Causa raíz de Caddy reload IDENTIFICADA: permisos 600 root:caddy

**Salida real y concluyente del titular:**
```text
USUARIO_CADDY=caddy
CADDYFILE_PERMISOS=600 PROPIETARIO=root GRUPO=caddy
SERVICIO_PUEDE_LEER_CONFIG=NO
ERROR_PERMISOS=1
ERROR_CONEXION_ADMIN=0
ERROR_ENVIO_CONFIG=0
ERROR_CARGA_CONFIG=0
ERROR_ADAPTACION_CONFIG=0
ERROR_RECARGA_SYSTEMD=1
DIAGNOSTICO_COMPLETADO=1
```

**Diagnóstico:** Caddy bajo `User=caddy` no puede leer `/etc/caddy/Caddyfile` `root:caddy 0600`; raíz muy probable/efectiva del fallo de `systemctl reload caddy`. La configuración original ya estaba restaurada y validada, con HTTPS 401 y la API administrativa local HTTP 200, CanReload=yes. Se corrige acceso mínimo con `root:caddy 0640`: propietario lectura/escritura, grupo lectura, otros nada; **no usar 644 ni 777**. Fuente oficial: https://caddyserver.com/docs/running (usuario servicio debe poder leer la configuración).

**Código endurecido:** `scripts/o5_remove_dev_basic_auth.sh` commit `ab76ca3677111adf7c590d89ef2ac0a228e25bc4`: preflight exige que usuario de systemd pueda leer tanto Caddyfile actual como candidato antes de modificarlo. Ya **no** se reproducirá el mismo intento de cambio con 0600; primero se corrigen los permisos.

**Paso inmediato SEGREGADO (todavía NO ejecutado)**: como usuario `vencira`, verificar copia raíz `/etc/caddy/.vencira-dev-auth-rollback.ce2ECir6/Caddyfile.original` idéntica con `cmp -s`, propietario/grupo actuales, servicio Caddy activo; aplicar `sudo chmod 0640 /etc/caddy/Caddyfile`, comprobar `sudo -u caddy test -r /etc/caddy/Caddyfile`, validar `caddy validate` en modo silencioso, `sudo systemctl reload caddy`, verificar HTTP 401 anónimo (la protección original debe mantenerse tras la recarga); **no borrar la copia privada**. Si falla alguna prueba, NO lanzar todavía script de retirar contraseña y diagnosticar solo marcadores. No reiniciar Caddy, Docker, PostgreSQL ni tocar OAuth o Restic.

**Después de confirmar recarga original OK**: sincronizar rama GitHub y ejecutar una sola vez `sudo bash scripts/o5_remove_dev_basic_auth.sh` endurecido para retirar Basic Auth de DEV, con recuperación y pruebas de acceso anon API/admin, documentando salida real. El hecho de hacer DEV pública sigue siendo decisión explícita del titular; no habilita producción/datos reales. El dominio apex `vencira.es` mantiene DNS hacia `213.186.33.5` y HTTPS no operativo, por lo que OAuth continuará bloqueado por su falta de landing page/política.

## 24/10/2026 — Reparación permisos Caddy y recarga ORIGINAL SUPERADA (confirmada)

El titular ejecutó el bloque segregado de corrección mínima y aportó:
```text
CONFIG_ORIGINAL_INTACTA=OK
LECTURA_USUARIO_CADDY=OK
VALIDACION_CADDY=OK
RECARGA_CADDY=OK
DEV_HTTP=401
REPARACION_PERMISOS=OK
RESULTADO_EJECUCION=0
```

**Demostrado en el VPS**: Caddyfile original intacto antes del cambio, se aplicó `chmod 0640 /etc/caddy/Caddyfile` sobre `root:caddy`, el usuario `caddy` puede leerlo y validar la configuración, `systemctl reload caddy` ahora termina con éxito, la web DEV permanece en HTTP 401 para visitantes anónimos. Esta corrección resuelve el fallo de reload por permisos previos `0600`; no equivale a haber retirado Basic Auth.

**Próxima operación separada, NO ejecutada al documentarlo**: sincronizar `integration/local-e2e-prep`, comprobar `bash -n scripts/o5_remove_dev_basic_auth.sh` y ejecutar una única vez como root `sudo bash scripts/o5_remove_dev_basic_auth.sh`. La versión de script desde `ab76ca3677111adf7c590d89ef2ac0a228e25bc4` bloquea si `User=caddy` no puede leer la configuración actual o candidata; guarda respaldo root:600 y retira solo líneas 2–4. Exige `BASIC_AUTH_DEV_RETIRADA=OK`, `INICIO_SESION_APP_Y_ADMIN_PROTEGIDOS=OK`, `DEV_RAIZ_HTTP=200` (o 3xx), `DEV_ME_ANONIMO_HTTP=401/403`, `DEV_ADMIN_ANONIMO_HTTP=404`, `RESULTADO_EJECUCION=0`; si falla, revisar `FASE_FALLIDA` y resultado del rollback, **no volver a ejecutar indiscriminadamente**.

Esta apertura afecta únicamente a `dev.vencira.es` para datos sintéticos; NO proporciona las páginas públicas Google OAuth en el dominio raíz `vencira.es`. Estado OAuth External/Testing y backups diarios deshabilitados permanecen.

## 24/10/2026 — Retirada de Basic Auth de DEV COMPLETADA Y VERIFICADA

**Evidencia reportada del script en Ubuntu por el titular** (última ejecución):
```text
CADDY_SERVICIO_PUEDE_LEER_CONFIG=OK
CADDY_ACTIVO=1
CONFIG_ESTRUCTURA_L1_L19=PREVALIDACION
CONFIG_CADDY_COPIA_PRIVADA=OK
BACKUP_PRIVADO_LOCAL=/etc/caddy/.vencira-dev-auth-rollback.kpXvFpJX
CAMBIO_LIMITADO_A_L2_L4=OK
CADDY_CANDIDATO_VALIDADO=OK
CADDY_RELOAD_INICIAL=OK
DEV_RAIZ_HTTP=200
DEV_ME_ANONIMO_HTTP=403
DEV_ADMIN_ANONIMO_HTTP=404
INICIO_SESION_APP_Y_ADMIN_PROTEGIDOS=OK
BASIC_AUTH_DEV_RETIRADA=OK
CADDY_RECARGADO=OK
NO_DOCKER_NI_POSTGRES_NI_RESTIC_MODIFICADOS=1
RESULTADO_GLOBAL=0
RESULTADO_EJECUCION=0
```

**Estado definitivo probado en VPS**: `dev.vencira.es` se sirve públicamente por HTTPS sin Basic Auth (GET anónimo / devuelve 200). El endpoint de identidad `GET /api/v1/me/` rechaza acceso anónimo (403); `/admin/` permanece oculto (404). Caddy validado y recargado, sin cambios de Docker, PG ni Restic. La protección por sesión Django/CSRF permanece según código y tests anteriores, pero no sustituye a una auditoría de seguridad de producción. El único contenido admisible en DEV continúa siendo sintético. Guardar la copia privada de reversión bajo `/etc/caddy/.vencira-dev-auth-rollback.kpXvFpJX` sin poner hashes en el repositorio. No repetir el script de retirada: el bloque Basic Auth ya no está en la config activa y su guard lo rechazará.

**Siguiente objetivo Google OAuth:** no confundir apertura de `dev.vencira.es` con disponer de página pública de marca/política. El dominio raíz `vencira.es` sigue con el último DNS confirmado `213.186.33.5` y HTTPS no operativo; no se ha publicado `https://vencira.es/oauth-backups/` ni `.../privacidad/`. Resolver sitio público, propiedad de dominio, contenido real y HTTPS antes de rellenar Branding y pasar OAuth External/Testing a In production. Token OAuth actual puede caducar a los siete días, por ello automación de respaldos **deshabilitada**. Tras publicación, reautorizar remoto existente sin cambiar clave Restic ni repo y verificar snapshot remoto PG `7a2f5018`. No usar datos de clientes.

## 24/10/2026 — Publicación OAuth O5: páginas estáticas y despliegue Caddy preparados (NO EJECUTADOS)

**Objetivo:** desbloquear publicación `External / Testing` del cliente OAuth **VENCIRA Internal Backups** (de Restic/Rclone), no desplegar la app comercial VENCIRA. Los HTML de Google Cloud aportados identificaron como bloqueantes la URL pública de homepage y de privacidad; el dominio autorizado `vencira.es` y nombre de app ya existían en Branding.

**Decisión de infraestructura sin interrumpir lo existente:** un **subdominio independiente** `oauth.vencira.es`, NO alterar el registro raíz `vencira.es` que resuelve a `213.186.33.5`, NI `www`, NI `dev.vencira.es`, MX o correo. El nuevo DNS **A** `oauth` debe resolver exclusivamente a IP IPv4 del VPS de VENCIRA `93.93.112.172`. No publicar AAAA hasta disponer de una dirección IPv6 validada. La modificación de DNS en el proveedor es una acción pendiente del titular, no hay acceso a su panel desde GitHub. No afirmar DNS listo ni webs públicas todavía.

**Sitio contenido en GitHub y únicamente informativo (pendiente de despliegue):**
- `public/oauth-backups/index.html`: descripción inequívoca de integración técnica y cuentas administrativas, uso de Restic/Rclone con copias cifradas, alcance `drive.file`, sin acceso a la app VENCIRA comercial; enlace a privacidad.
- `public/oauth-backups/privacidad/index.html`: alcance OAuth, datos de Google, finalidad, retención actualmente manual sin falsos plazos automáticos, seguridad, revocación y contacto referenciado al correo de soporte que Google presenta en pantalla de consentimiento. Evita publicar el correo Gmail administrativo en el sitio; debe verificarse suficiencia jurídica si Google exige identificación adicional del responsable.
- `public/oauth-backups/condiciones/index.html`: condiciones técnicas del servicio interno.
- `public/oauth-backups/assets/site.css` y `robots.txt`; HTML estático sin JS, cookies de analítica, trackers ni credenciales.

**URLs a incorporar en Google Auth Platform → Branding** únicamente cuando HTTPS responda 200 sin credenciales:
- `https://oauth.vencira.es/` — página principal
- `https://oauth.vencira.es/privacidad/` — política de privacidad
- `https://oauth.vencira.es/condiciones/` — condiciones de servicio (opcional en UI)
Dominio autorizado debe seguir siendo `vencira.es` conforme a Google (dominio registrable), no añadir `oauth.vencira.es` como otro dominio autorizado sin que lo solicite la consola. Cuando Google lo requiera, verificar propiedad de `vencira.es` en Search Console, usando cuenta propietaria del proyecto OAuth y un registro TXT indicado por Google; no inventar el TXT.

**Despliegue preparado:** `scripts/o5_publish_oauth_pages.sh` commit `863c22b38871d968064349130e25a25e0d759053`. Requiere DNS correcto, rama `integration/local-e2e-prep`, archivo `/etc/caddy/Caddyfile` original root:caddy 0640 y servicio Caddy activo/legible. Verifica previo DEV 200/403/404, crea respaldo privado root:0700/0600, copia documentos a `/srv/vencira-oauth-site` (estáticos legibles por caddy), añade SOLO sitio independiente `oauth.vencira.es` al Caddyfile, valida candidato con usuario caddy, `systemctl reload caddy`, verifica HTTPS público 200 en las tres páginas y que DEV continúa 200/403/404. Ante fallo después de cambiar Caddyfile intenta rollback del archivo y recarga Caddy. Puede dejar archivos estáticos locales inertes si falla para inspección, sin secretos. No ejecuta restic, DB, Docker ni amplía alcance Google.

**Ejecución UNA VEZ después de configurar DNS**:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_publish_oauth_pages.sh || exit 1
  sudo bash scripts/o5_publish_oauth_pages.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
Si falla `DNS_OAUTH_NO_LISTO=1`, no tocar Caddy; esperar propagación o revisar A/AAAA. Si falla `CADDY_REVERSION=REVISION_MANUAL_NECESARIA`, detenerse y revisar antes de repetir. No usar `caddy restart` ni `docker compose down`. Verificar `SITIO_OAUTH_PUBLICADO=OK`, `HTTPS_OAUTH_PUBLICO=OK`, `DEV_SIN_REGRESIONES=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`.

**Paso posterior:** en `https://console.cloud.google.com/auth/branding?project=vencira-backups` configurar URL de página principal, privacidad y condiciones; guardar. En `https://console.cloud.google.com/auth/audience?project=vencira-backups` publicar app / In production, atender requisitos adicionales reales si aparecen, no inventar aprobación. En Google Search Console verificar dominio si exigido. Solo tras In production reautorizar remoto rclone existente con script ya guardado, leer snapshot cifrado PG real `7a2f5018` y posteriormente diseñar timer diario. No inicializar otro repositorio, regenerar contraseña o dar por terminada publicación OAuth antes del cambio real de estado.

**Fuentes Google actualizadas**: https://support.google.com/cloud/answer/15549049 , https://developers.google.com/identity/verification/authentication-policy-compliance , https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification .

## 24/10/2026 — Resultado real del primer intento de publicar el sitio OAuth: DNS aún no listo

El titular sincronizó HEAD `7934e248c85751a957507deb9f791f26bf89d72d` y ejecutó `scripts/o5_publish_oauth_pages.sh`. Resultado:
```text
COMMIT=7934e248c85751a957507deb9f791f26bf89d72d
CADDY_PRECHECK=OK
DNS_OAUTH_NO_LISTO=1
ACCION=VERIFICAR_REGISTROS_A_Y_AAAA
FASE_FALLIDA=DNS
DOCKER_PG_RESTIC_DEV_NO_MODIFICADOS=1
RESULTADO_GLOBAL=4
RESULTADO_EJECUCION=4
```
**Interpretación:** corte preventivo antes de crear archivos estáticos o modificar Caddy. `oauth.vencira.es` no resuelve en Ubuntu exactamente al conjunto `{93.93.112.172}` según `socket.getaddrinfo`. No diagnosticar sin prueba si falta A, si hay caché, registro wildcard u otro A/AAAA. La apertura previa de `dev.vencira.es` permanece completada, no revertir. No tocar Docker, PostgreSQL, Restic ni OAuth.

**Siguiente acción**: confirmar en panel DNS del dominio que exista `A oauth -> 93.93.112.172`, sin CNAME, A antiguos ni AAAA para ese host salvo IPv6 propia verificada, y sin cambiar registros `@`, `www` o MX. Ejecutar diagnóstico de solo lectura con Python `socket.getaddrinfo` separado AF_INET/AF_INET6 y, si `dig` está disponible, consultar `@1.1.1.1` y `@8.8.8.8` para A/AAAA; sin imprimir más información. Si públicos correctos pero caché local antigua, esperar actualización/reintentar solo tras resolución correcta. Después volver a ejecutar script una sola vez y verificar HTTP 200/TLS en tres páginas y DEV sin regresiones. **No** usar --resolve para esquivar el guard DNS de despliegue.

## 24/10/2026 — DNS OAuth resuelto; publicación pendiente

**Diagnóstico real del VPS del usuario**, posterior al primer bloqueo `DNS_OAUTH_NO_LISTO=1`:
```text
A_IPV4=93.93.112.172
AAAA_IPV6=SIN_RESOLUCION
1.1.1.1 A=93.93.112.172; AAAA=VACIO; CNAME=VACIO
8.8.8.8 A=93.93.112.172; AAAA=VACIO; CNAME=VACIO
DIAGNOSTICO_DNS_COMPLETADO=1
```
**Conclusión validada:** el host `oauth.vencira.es` apunta ya a la IP del VPS `93.93.112.172`, sin AAAA ni CNAME incoherentes según la salida; DNS local y dos resolvedores públicos coinciden. No se requiere otra edición DNS ahora; **evitar tocar registros raíz, www, dev, MX**.

**Próximo paso autorizado, pendiente de ejecución en Ubuntu:**
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  echo "COMMIT=$(git rev-parse HEAD)"
  bash -n scripts/o5_publish_oauth_pages.sh || exit 1
  sudo bash scripts/o5_publish_oauth_pages.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
Se espera `DNS_OAUTH=OK`, `CADDY_CANDIDATO_VALIDADO=OK`, `CADDY_RELOAD=OK`, `OAUTH_HOME_HTTP=200`, `OAUTH_PRIVACIDAD_HTTP=200`, `OAUTH_CONDICIONES_HTTP=200`, `DEV_SIN_REGRESIONES=OK`, `SITIO_OAUTH_PUBLICADO=OK`, `RESULTADO_GLOBAL=0`. **No declarar desplegado ni HTTPS funcionando antes de recibir esa evidencia real**. Si falla, no reintentar a ciegas; comprobar `CADDY_REVERSION`, `FASE_FALLIDA` y marcador.

Tras validación pública, rellenar Branding Google (homepage, privacidad, condiciones) y comprobar si permite publicar External/In production; si exige propiedad Search Console, verificarla con TXT auténtico. Aún no reautorizar Rclone, ni cambiar contraseña Restic o programar backups hasta OAuth In production.

## 24/10/2026 — Sitio HTTPS OAuth PUBLICADO; salida completa de despliegue confirmada

El titular ejecutó `scripts/o5_publish_oauth_pages.sh` después de corregir DNS. **Salida real satisfactoria**:
```text
CADDY_PRECHECK=OK
DNS_OAUTH=OK
DEV_PRECHECK=OK
CADDY_RESPALDO_PRIVADO=OK
COPIA_CADDY_PRIVADA=/etc/caddy/.vencira-oauth-rollback.9FhSoUju/Caddyfile.original
STATIC_SITE=OK
CADDY_CANDIDATO_VALIDADO=OK
CADDY_RELOAD=OK
OAUTH_HOME_HTTP=200
OAUTH_PRIVACIDAD_HTTP=200
OAUTH_CONDICIONES_HTTP=200
DEV_SIN_REGRESIONES=OK
SITIO_OAUTH_PUBLICADO=OK
HTTPS_OAUTH_PUBLICO=OK
DOCKER_PG_RESTIC_DEV_NO_MODIFICADOS=1
RESULTADO_GLOBAL=0
RESULTADO_EJECUCION=0
```

**Estado**: el VPS confirma accesibilidad HTTPS sin autenticación a estas tres direcciones: `https://oauth.vencira.es/`, `https://oauth.vencira.es/privacidad/`, `https://oauth.vencira.es/condiciones/` (todas HTTP 200). Caddy recargado, sitio estático en `/srv/vencira-oauth-site`, rollback Caddy privado en la ruta antes indicada. Protección de Django y estado de DEV sin regresiones. El cambio no toca DB, Docker ni secretos Restic. No repetir script de despliegue: es deliberadamente no idempotente para evitar duplicar host.

**Siguiente operación pendiente del titular en Google Cloud, NO realizada:** en proyecto `vencira-backups`, Google Auth Platform → Branding, configurar/guardar las tres URLs exactas anteriores y revisar nombre `VENCIRA Internal Backups`, correo de soporte y dominio autorizado `vencira.es`. Según documentación actual de Google (https://support.google.com/cloud/answer/15549049), los enlaces son obligatorios para External/Production; el dominio autorizado `vencira.es` ampara subdominios como oauth.vencira.es; puede exigir titularidad verificada en Google Search Console. Branding puede requerir `Verify Branding` y luego `Publish branding` al quedar `Ready to publish`; diferenciarlos de Audience → `Publish app` / estado `In production`. No dar por verificado/publicado hasta capturar estado concreto de consola. Consultar y cumplir requisitos reales si Google pide más. El recurso web propio no pudo ser verificado independientemente por herramienta de navegación en esta sesión, pero los tres HTTP 200 fueron registrados por el VPS del titular. Valorar si Google pide identificación adicional del responsable/contacto en privacidad y ajustar antes de verificación.

**Aún pendiente**: Google OAuth sigue External/Testing según última evidencia, refresh token sujeto a caducidad de Testing, reautorización del remoto Rclone aún no hecha, copia cifrada y restauración aislada previas válidas (snapshot `7a2f5018`), timer automático/retención/segundo destino NO activados. No renovar OAuth ni alterar repositorio Restic o clave hasta estado `In production`.

## 24/10/2026 — Titular confirma Google OAuth `In production`; desarrollo VENCIRA reanudado (O6)

**Declaración explícita del titular:** «done y en produccion, podemos seguir con la app», tras las instrucciones de completar Branding y Audience del cliente `VENCIRA Internal Backups` en el proyecto `vencira-backups`. La interpretamos como confirmación por usuario de **OAuth External/In production**. No hay captura nueva ni inspección independiente de Google Console. **No significa** que el producto VENCIRA, sus usuarios, su plataforma comercial o sus datos estén listos para producción; `dev.vencira.es` sigue siendo exclusivamente DEMO.

**Estado de O5**: Sitio HTTPS público `oauth.vencira.es` ya probado 200 en homepage, privacidad y condiciones y Caddy recargado sin regresiones en DEV. Copia Restic real cifrada + restauración efímera PG17 verificada, snapshot `7a2f5018`. **Pendiente inevitable**: renovar el remoto `vencira_google` usando `scripts/o5_reauthorize_existing_drive.sh` tras publicación, porque el token de renovación fue emitido previamente con OAuth External/Testing y puede expirar a los 7 días. Requiere túnel SSH local 53682/navegador, no compartir OAuth URL ni token ni secretos en chat. Nunca reejecutar `restic init` ni generar nueva clave. Falta verificar repositorio/snapshot con token nuevo y automatizar copias con retención/alertas/independencia; no activar temporizador antes.

**Inicio de desarrollo O6, elegido por ser incremental, centrado en producto y sin migraciones**: añadir pantalla independiente «Archivo y cerrados», navegación desde panel, paginación limitada por workspace y filtro `status=closed` ya existente, diferenciación de desenlaces `won` / `discarded` y cierres legados sin resultado, entrada a la ficha O3 para recuperación, recarga al regresar, idiomas ES/CA, estados sin sesión y pruebas móviles. Código versionado (archivos `clients/flutter/lib/ui/renewal_archive_screen.dart`, `dashboard_screen.dart`, locales ARB, test `archive_test.dart`); documento técnico `docs/OPERATION_O6_ARCHIVE.md`. No crea tablas, migraciones, nuevos endpoint, envíos, datos reales ni cambios de permisos; el aislamiento sigue siendo responsabilidad del API existente. **Sin evidencia de `flutter test` o compilación aún** y **no desplegado** cuando se anota esta nota.

**Siguiente gate O6**: validar y desplegar solo Flutter/Web con `scripts/validate_ui_v3_1.sh` existente, que verifica checkout/identidad Docker, flutter analyze/test completos/build y, únicamente en éxito, recrea `vencira_localcheck-web_preview`; confirma HTTP/health. El nombre V3.1 es histórico, script valida HEAD completo. Ejecutarlo desde Ubuntu una sola vez tras sincronizar `integration/local-e2e-prep`, compartir únicamente marcadores y errores sin secretos. Probar en Android el botón «Archivo», un cierre antiguo y recuperación de `Conseguido`, con referencias ficticias. NO desplegar automáticamente sin ese gate, NO `down -v`, NO tocar `vencira_preview`, DB, Caddy, Restic.

## 24/10/2026 — O6 Archivo: validación Flutter, despliegue y salud completados

**Confirmado por el usuario en Ubuntu:** rama `integration/local-e2e-prep`, commit desplegado `924f8f959fb7206d98535ff6fff47c823d0904d7`; `FLUTTER_V3_1_Y_TESTS=OK`, `WEB_BUILD=OK`, `WEB_DEPLOY=OK`, `WEB_HEALTH=healthy`; endpoints localcheck `/`, `/api/health/`, `/api/ready/`, `/accounts/login/` en HTTP 200; `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`; `DEV_VENCIRA_HTTPS_HTTP=200`; `DESPLIEGUE_WEB_V3_1_LOCALCHECK=OK`, `SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`. Log local privado: `/tmp/vencira-ui-v3-1.Rerg7fJg.log`.

La incidencia previa de análisis O6 quedó corregida en tests de `archive_test.dart` (comas tras grupos de argumentos opcionales en líneas 61/78). El script ejecutó análisis, tests y build completo y solo entonces desplegó Web; **O6 ahora está desplegada y validada técnicamente**. Pantalla `Archivo y cerrados`, separación de `won` / `discarded` / cierres legacy, paginación por organización y ficha O3 con recuperar. No confundir despliegue con aceptación manual ni con producto comercial en producción.

**Próxima aceptación sin terminal**: iniciar sesión de prueba en `https://dev.vencira.es/` desde Android; tocar `Archivo`, verificar cerrados ficticios (Conseguido, Descartado y legacy si existen), abrir ficha y recuperar anotación O3; comprobar que desaparezca del Archivo, vuelva a la lista activa y no se muestren registros de otro workspace. Solo datos ficticios. Reportar cualquier fallo visual o error sin credenciales. Tras confirmación funcional, O6 se cerrará. Google OAuth del cliente de backups figura In production según confirmación del titular, pero el refresh token de Rclone anterior fue emitido cuando estaba Testing: reautorización segura de O5 y control de snapshot pendientes; **no activar aún timer de backups**.

## 24/10/2026 — O6 aceptada por titular; whitepaper y frecuencia O5 aclarados

El titular confirmó literalmente «Todo ok» tras el despliegue O6 previamente validado. Cerrar O6 como ACEPTADA FUNCIONALMENTE en DEV (no producción). Se leyó el White_paper_agenda_vencimientos.pdf original (§2 p.2, §9 p.12, §12 p.15 y §18). El Archivo O6 tiene sentido conforme al flujo Conseguido/Descartar, registros y recuperación de Descartar; se reconoce que O3 permite recuperar también Conseguido aunque el documento no lo ordena expresamente, lo que queda por confirmar con el promotor. Pendiente obligatorio: retención de Archivo de 2 años por defecto, plazo cambiable y avisos 3/1 meses antes, junto a supresión RGPD e historial auditado. Detalles docs/OPERATION_O6_ARCHIVE.md.

En O5 el documento solo establece copias necesarias dentro de la UE y deja frecuencia al desarrollador. ÚNICO backup real constatado: snapshot cifrado Restic 7a2f5018 del 24/10/2026, restaurado en PG17 efímero. Backups recurrentes NO programados. Propuesta escrita en docs/OPERATION_O5_DRIVE_BACKUPS.md: DEV cada 24 h (03:00 Madrid) y futuros datos de producción cada 6 h, más pre-migración; retener 7 días todas, diarios 30 días, semanales 8 semanas, mensuales 12 meses, tras diseño/pruebas de poda. Alertas y recuperación periódica indispensables. Residencia UE de Google Drive actual NO acreditada para uso real; requiere garantías comprobables.

Antes de activar siquiera la copia automática DEV: reautorizar el remoto Rclone existente con el cliente Google OAuth recién publicado In production, obtener nuevo token y comprobar acceso al snapshot antiguo, sin generar nueva clave ni reiniciar repositorio. Configuración de systemd aún NO preparada/activada. No tocar Caddy, API, PostgreSQL ni desplegar nada por esta revisión documental.

## 24/10/2026 — O5 temporizadores diarios preparados y aprobados; no instalados aún

**Consentimiento del titular:** «Ok conseguidas también; ok frecuencia recomendada adelante», y posteriormente «Procede». Se confirma recuperar desde Archivo tanto Conseguidas como Descartadas (ampliación deliberada respecto al whitepaper), anotado en docs/OPERATION_O6_ARCHIVE.md. Se aprueba DEV diaria a las 03:00 Europe/Madrid y la política propuesta para producción futura de copia cada 6 h, pero NO se activa producción ni archivo RGPD por este acuerdo.

Se crearon en GitHub scripts/o5_verify_existing_drive.sh, scripts/o5_scheduled_backup.sh, scripts/o5_backup_health.sh y scripts/o5_install_daily_schedule.sh y cuatro unidades systemd en deploy/o5. Se amplió scripts/o5_reauthorize_existing_drive.sh para verificar mediante Restic el snapshot original 7a2f5018 y registrar de modo privado la autorización nueva posterior a In production. Manual completo en docs/OPERATION_O5_DAILY_SCHEDULE.md.

**NO hay ejecución confirmada en Ubuntu ni timer activo a esta fecha**. Primero ejecutar desde SSH interactiva con túnel OAuth local 53682 el script o5_reauthorize_existing_drive.sh de GitHub tras sincronización de rama. No compartir URL privada del flujo OAuth ni tokens. Gate indispensable O5_POSTPRODUCTION_RECONNECT_REGISTRADO=OK y RESTIC_SNAPSHOT_ORIGINAL=OK, O5_GOOGLE_OAUTH_VERIFICADO=1 y RESULTADO_GLOBAL=0. Luego instalar con sudo bash scripts/o5_install_daily_schedule.sh, que hace una nueva copia cifrada de ensayo, verifica integridad/frescura y SOLO EN ÉXITO habilita timer diario de copia 03:00 Madrid y timer de salud 08:00 Madrid. El script falla seguro/rollback de unidades en error. NUNCA restic init, ni nuevos secretos, ni cambios a Caddy/Django/PostgreSQL. Solo DB DEV ficticia.

**Limitación de alertas**: estado de fallo y antigüedad >36h se registra en systemd/journal y marcador root, pero aún NO se notifican incidencias por mail ni web push; necesitará canal externo antes de producción. Política de retención propuesta documentada, pero no se ejecuta poda automática. Google Drive no acredita residencia EU para datos personales; el trabajo está limitado a DEV sintético. La frecuencia de producción de 6 horas es decisión futura de arquitectura, no un timer para entorno actual.

## 24/10/2026 — Auditoría de instalación preexistente: TIMERS ACTIVOS Y ARCHIVOS IDÉNTICOS

El titular aportó la auditoría de solo lectura scripts/o5_audit_existing_units.sh, con RESULTADO_AUDITORIA=0 y RESULTADO_GLOBAL=0. DIRECTORIO_INSTALADO=EXISTE, DIRECTORIO_ROOT_700=OK, ENTRADAS_NIVEL_1=3. Los tres scripts del directorio /usr/local/libexec/vencira y las cuatro unidades en /etc/systemd/system son IDENTICO_A_GITHUB, cargadas desde RUTA_ESPERADA. BACKUP_TIMER=active/enabled y HEALTH_TIMER=active/enabled; los servicios oneshot BACKUP_SERVICE y HEALTH_SERVICE están inactive (normal fuera de ejecución). DIRECTORIO_ESTADO=ROOT_700, ULTIMO_EXITO=MENOS_DE_36_HORAS y ULTIMO_FALLO=NO_REGISTRADO. No hubo cambios en archivos, timers ni repositorio remoto durante la auditoría.

Conclusión técnica: el gate RESTRICCIONES del instalador fallaba porque el destino y las unidades YA EXISTÍAN y el instalador es de único uso. No reejecutar instalación ni reautorizar OAuth. Los temporizadores están registrados, habilitados y activos; el marcador de éxito es reciente. Sin embargo el log de auditoría no prueba todavía por sí solo la fecha del snapshot remoto ni si el éxito sucedió después de la reautorización; evitar afirmarlo como restauración nueva sin comprobación.

Nuevo script GitHub scripts/o5_verify_active_schedule.sh (SOLO LECTURA): comprueba active/enabled, unidades no failed, marcadores privados, compara último éxito frente a fecha de OAuth postproduction, lee metadata de snapshots PostgreSQL cifrados via Restic y muestra próximos disparos systemd. No imprime secretos, no crea snapshots, no borra ni modifica. Ejecutar después de git fetch/merge --ff-only, con sudo bash scripts/o5_verify_active_schedule.sh; comunicar exclusivamente marcadores. Si COPIA_TRAS_REAUTORIZACION=NO o ULTIMO_SNAPSHOT_MENOS_36H=NO, evaluar un único arranque manual controlado de vencira-o5-backup.service y revalidación antes de dar el gate por cerrado.

Alerta local journal activa, no se ha configurado notificación externa por email/push, ni retención/poda automática; Google Drive no acredita residencia en la UE para datos reales. Persisten los límites DEV sintético.

## 24/10/2026 — O5: copias diarias en DEV activas; nuevo snapshot tras OAuth verificado

**Evidencia directa del titular, última ejecución:** `sudo systemctl start vencira-o5-backup.service` terminó sin error (`COPIA_POST_OAUTH_MANUAL=OK`), seguido de `sudo bash scripts/o5_verify_active_schedule.sh`: `TIMERS_ACTIVOS_Y_HABILITADOS=OK`, `SERVICIOS_SIN_ESTADO_FAILED=OK`, `MARCADOR_EXITO_MENOS_36H=OK`, `COPIA_TRAS_REAUTORIZACION=SI`, `SNAPSHOTS_POSTGRES_EN_RESTIC=OK`, `ULTIMO_SNAPSHOT_ANTIGUEDAD_SEGUNDOS=31`, `ULTIMO_SNAPSHOT_MENOS_36H=SI`, `ACCESO_RESTIC_READ_ONLY=OK`, `AUDITORIA_FINAL_O5=OK`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`. No se reinstaló ni reconfiguró systemd, no se modificó la DB viva.

Calendario confirmado por systemd: respaldo a las **03:00 Europe/Madrid** y control local a las **08:00 Europe/Madrid**, con próxima ejecución domingo 25/10/2026 a las 02:00 UTC y 07:00 UTC respectivamente (cambio de CEST a CET esa noche). Directorio de scripts y cuatro unidades auditados en la etapa previa idénticos a GitHub, ambos timers active+enabled.

**Estado:** alcance básico O5 DEV **OPERATIVO**: copia PostgreSQL DEV cifrada a Restic en Google Drive, autorización Google OAuth renovada tras pasar a In production, snapshot preexistente 7a2f5018 accesible, snapshot nuevo verificado como reciente y posterior a OAuth, restic check por script de backup, temporizadores activos y marca de última copia. La restauración aislada PG17 anterior sigue acreditada; **no se ha realizado un nuevo ensayo de restauración del snapshot posterior a OAuth**, no afirmar eso. No ejecutar scripts de instalación o reconexión de nuevo.

**Pendiente de endurecimiento**, por separado: alerta externa efectiva (solo health/journal local hoy), retención/poda segura (`forget/prune` NO habilitados), ensayo periódico de recuperación, segundo destino independiente, RGPD y residencia UE acreditada para datos reales (Google Drive actual no acreditado), alcance de archivos adjuntos futuros. Producción 6 h aceptada como diseño pero NO activa. DEV exclusivamente datos ficticios. O6 «Archivo» aceptada; posibilidad de recuperar también «Conseguido» aprobada.

## 24/10/2026 — Revisión completa whitepaper, planificación O7–O16 y avance paralelo O7/O8a

El titular solicita acelerar el desarrollo realizando el máximo trabajo compatible. Se revisó íntegramente el original `White_paper_agenda_vencimientos.pdf` (18/10/2026, 23 páginas) y se elaboró `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md` con matriz §1–18, hitos paralelos O7–O16 y decisiones de promotor/desarrollador todavía abiertas. **Fuente de producto prioritaria** frente a notas históricas, con adendas aprobadas después: marca VENCIRA, stack Flutter/Django/PostgreSQL, recuperar también Conseguido, backup DEV 03:00.

**Implementación nueva en GitHub, NO probada aún, NO desplegada**:
- **O7** `backend/reminders/results.py`, ruta `/api/v1/workspaces/{uuid}/results/` solo GET owner y datos agregados por periodos month/quarter/year Europe/Madrid, tests de permisos, límites civiles, seguridad y eventos; `clients/flutter/lib/api/vencira_api.dart`, `ui/results_screen.dart`, acceso en dashboard únicamente web escritorio ancho>=800 owner, traducciones ES/CA y tests Flutter. No migración ni PII en respuesta. Deliberadamente bloqueado el desglose por usuario y acceso miembros por dudas de atribución y §18.
- **O8a** `backend/reminders/legal_deadlines.py` cálculo fecha de un mes civil exacto, separado del preaviso contractual opcional, `default_reminders.py` con fechas 60/45/35 y pregunta en último aviso estrictamente anterior al límite; test suite de ejemplos originales, bisiestos y cambios de mes. **No** habilita `ReminderPolicy`, no crea candidatos ni envía avisos; motivos y casos tarde/Vida pendientes §18.
- Documentos `docs/OPERATION_O7_RESULTS.md` y `docs/OPERATION_O8_DATE_ENGINE.md`, validador **sin despliegue** `scripts/validate_o7_o8_preflight.sh`: pruebas Django completas SQLite y PostgreSQL17 efímero, Flutter ES/CA analyze/tests/build; verifica stack persistente healthy y NO migra DB/ni toca Caddy, Restic u OAuth. No considerar ninguna prueba verde antes de ejecución real en Ubuntu.

**Próximo paso seguro**: sincronizar rama por fast-forward y ejecutar `bash scripts/validate_o7_o8_preflight.sh` desde `/home/vencira/vencira-localcheck`, aportar RESULTADO_GLOBAL y LOG_LOCAL (sin secretos); corregir errores antes de realizar un plan de despliegue API+Flutter aislado con endpoints healthy y pruebas desktop. No hacer `docker compose up` todavía, no tocar base PostgreSQL persistente ni habilitar mensajes reales. Mantener O5 diario funcionando y O6 aceptado. Próximos hitos centrales: O8b reglas por anotación, O9 pregunta de control, O10 respuestas a avisos, O11 agenda HOY inicial, mientras seguridad O14 avanza en paralelo.

## 24/10/2026 — PRE-FLIGHT O7/O8a integral confirmado; despliegue API + Web preparado, NO ejecutado

El usuario aportó resultado real de `scripts/validate_o7_o8_preflight.sh`, sobre checkout integrado con O7 y O8a, con: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.988RWtXC.log`. La salida compartida omite COMMIT pero el último HEAD de fuente preparado para ese gate fue `c86cd8e058262da8998505c80e37ab3cdfa0ca90`; no afirmar verificable vínculo a ese SHA sin nueva comprobación local.

**O7/O8a código funcionalmente testado en aislamiento, aún NO instalado en DEV**. El preflight confirma que no se modificó PostgreSQL persistente ni O5/Caddy/Restic.

Se versionó `scripts/deploy_o7_o8_no_migrations.sh`, despliegue de una sola ejecución para **solo API y Web del proyecto `vencira_localcheck`**, con gate de diff desde commit fuente validado c86cd8e (backend, clients, compose, deploy), identidad healthy y guard de API `migrate --check --noinput`, verificación de respaldo cifrado O5 post-OAuth y snapshot menor de 36 h, comprobación del esquema 0014 y número total de migraciones, etiqueta inmutable y restaurable de imágenes previas API/Web ANTES de construir; si faltan imágenes antiguas aborta sin cambios. Build de API y Web, `migrate --check` sobre nueva imagen, recreación individual `--no-deps --no-build` solo API y solo Web, verificación DB mismo contenedor y migraciones iguales, HTTP 200 y O7/O3 rutas anónimas 401/403, salud API/DB/Web, recibo privado. **No se hace rollback de DB automáticamente**, si falla con servicios ya recreados inspeccionar recibo y tags antes de recuperar; no repetir script a ciegas. Caddy/O5 y `vencira_preview` intactos.

**Siguiente gate:** sincronizar rama `integration/local-e2e-prep`, ejecutar `bash -n scripts/deploy_o7_o8_no_migrations.sh`, luego `bash scripts/deploy_o7_o8_no_migrations.sh` en la consola de Ubuntu. El script abortará antes de desplegar si fallan imágenes recuperables/backup/source check. Si todas las pruebas pasan, aceptación O7 en navegador de ordenador ancho >=800 como owner (Resultados, cambiar periodos, cuenta correcta); confirmar inaccesible empleado y móvil. O8a no tiene UI, son funciones puras. No afirmar despliegue real hasta recibir marcadores `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`.

**Restricción de velocidad:** No incorporar más cambios a `backend/`, `clients/` o `deploy/` hasta que se complete este gate o se repita preflight. Mantener O5 diario activo. Después priorizar O8b/O9 y O11, según plan maestro.

## 24/10/2026 — O7/O8a desplegadas en DEV; pruebas técnicas y seguridad superadas

**Fuente: salida real del titular en Ubuntu.** Checkout/despliegue `b61e357f06b7396d1018cb072ef39b6bc0974777`. `FUENTES_IGUALES_GATE_VALIDADO=OK`, `COMPOSE_IDENTIDAD_Y_MIGRATE_CHECK_ONLY=OK`, `COMPOSE_CONFIG=OK`, `O5_BACKUP_READ_ONLY=OK`, `BACKUP_O5_RECIENTE_Y_CIFRADO=OK`, esquema previo `0014` verificado, imágenes antiguas de API y Web etiquetadas, `BUILD_API_WEB=OK`, `MIGRATIONS_CHECK_ONLY_NEW_IMAGE=OK`, `ESQUEMA_SIN_MIGRACIONES_PENDIENTES=OK`, `DEPLOY_API=OK`, `DEPLOY_WEB=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, cuatro rutas básicas HTTP 200, endpoint O7 anon HTTP 403 y O3 anon HTTP 403, `HEALTH_api/db/web_preview=healthy`, `DEV_VENCIRA_HTTPS_HTTP=200`, `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, sin migraciones, reinicio PostgreSQL, cambios a Caddy, Restic o timers. Versión web `b61e357f06b7396d1018cb072ef39b6bc0974777`.

**Imágenes de recuperación conservadas:** `vencira-o7-pre-api:20261024T214020Z_2326206` y `vencira-o7-pre-web:20261024T214020Z_2326206`. Recibo privado de despliegue: `/tmp/vencira-o7-o8-20261024T214020Z_2326206.bc7EwG0D.receipt`; log privado `/tmp/vencira-o7-o8-deploy.NyAOMxIF.log`. No destruir imágenes ni recibo hasta aceptación manual.

**Estado:** O7 **DESPLEGADA Y VALIDADA TÉCNICAMENTE**; pendiente aceptación visual del administrador en navegador PC ancho >=800: botón «Resumen de resultados», navegación mes/trimestre/año y números correctos sobre registros ficticios. No mostrar resumen en móvil o cuentas member; backend owner-only ya tiene regresiones unitarias y anónimo devuelve 403. O8a cálculo legal y 60/45/35 **DESPLEGADO COMO LÓGICA PURA**, sin notificaciones activas, sin trabajos externos ni ajustes de esquemas. No declarar O7 funcionalmente aceptada sin prueba manual.

Próximo desarrollo acelerado O8b y O9 puede codificarse y probarse en GitHub sobre la misma rama tras este gate sin desplegar automáticamente. Mantener inalterados backups O5 y base `0014`; nuevas migraciones solo con protocolo O4 específico. Nunca ejecutar de nuevo `deploy_o7_o8_no_migrations.sh` si ya salió OK.

## 24/10/2026 — Desarrollo adelantado O8b: vista previa de reglas por anotación (NO desplegado)

Tras confirmación técnica de O7/O8a desplegadas sanas (versión servidor `b61e357f06b7396d1018cb072ef39b6bc0974777`), se inició el siguiente lote del whitepaper sin tocar el servidor. Nuevos módulos `backend/reminders/reminder_planning.py`, `reminder_preview.py`, ruta autenticada read-only `/api/v1/workspaces/{workspace}/renewals/{renewal}/reminder-preview/`, pruebas `test_reminder_planning.py` y `test_reminder_preview.py`. Documento `docs/OPERATION_O8B_REMINDER_PREVIEW.md`. Vista previa de días personalizados (1–12, 0–365 únicos), 60/45/35 por defecto, pregunta en último aviso anterior al mes civil, avisos pasados, límite agotado y falta de aviso de control; no programa ni entrega mensajes. Filtro de tenant/responsable antes de consultar. Archivados devuelven 409. Modalidad Vida marcada con advertencia de revisión jurídica, no plazo exigible supuesto.

**Estado de O8b:** código y pruebas versionados en GitHub, SIN ejecución confirmada de preflight, SIN cambios DB/Compose ni despliegue a DEV. Próximo gate: sincronizar rama `integration/local-e2e-prep` (sin cambios locales rastreados) y ejecutar `bash scripts/validate_o7_o8_preflight.sh` con suites completas SQLite + PG17 efímero y Flutter. No iniciar despliegue de O8b con el antiguo `deploy_o7_o8_no_migrations.sh`: está diseñado para otra fuente validada. Si un nuevo endpoint se desea desplegar, preparar nuevo deploy y freeze de SHA tras pruebas. O7 requiere aceptación visual desde PC (resultados y períodos), no atribuida al resultado técnico del despliegue.

**Decisiones comerciales no resueltas del §18**: motivos por defecto, alta tardía, ningún aviso antes del tope, Vida, recordatorios no atendidos y permisos de miembros. No convertir sugerencias de whitepaper en reglas habilitadas sin decisión. O8c con guardado y motivos requerirá diseño de esquema/migración explícita, backup/restauración previa conforme O4, auditoría y pruebas de concurrencia.

## 24/10/2026 — O7 navegación manual confirmada y handoff permanente nuevo chat

El titular confirma en el navegador de escritorio: «Sí pude cambiar entre mes, trimestre y año». O7 navegación por periodos **ACEPTADA VISUALMENTE**, pero aún no afirmó que comparase los contadores con datos ficticios ni que probara acceso de cuentas member. Se actualizó `docs/OPERATION_O7_RESULTS.md` en consecuencia. O7 sigue desplegada en DEV código `b61e357f06b7396d1018cb072ef39b6bc0974777`, backend PostgreSQL 0014 intacto; O8a lógica pura en DEV; O8b código nuevo solo en GitHub y **sin preflight ni deploy**.

Por solicitud expresa de no perder contexto al abrir otro chat se creó el archivo compacto autocontenido `docs/NEXT_CHAT_HANDOFF.md`, con repositorio, rama, fuente whitepaper, decisiones, estado real de O5/O6/O7/O8a/O8b, indicaciones de seguridad, próximo gate exacto y criterio de no repetir migraciones/instalaciones. Debe actualizarse tras cada hito importante o antes de iniciar una conversación nueva. El asistente **no puede conocer con precisión el límite interno del chat**, por eso ofrece la ficha de continuidad y no promete aviso automático al llenarse. Próxima tarea: validar O8b con `scripts/validate_o7_o8_preflight.sh`; luego seguir O8c, O9–O11 sin confundir planificación con entrega.

## 24/10/2026 — O8b preflight interrumpido por dos supuestos de prueba, corregidos

Usuario ejecutó preflight O8b sobre SHA `2cdcd4a3a36e31f0b1d2c1c84753e2fd3ed4de6a`: identidad DEV saludable, Compose OK, ES/CA OK, imagen Django OK, check/migration dry run OK. La suite SQLite encontró 141 tests con **139 aprobados y 2 fallos**: `test_last_eligible_notice_and_missing_control` y `test_custom_late_controls_and_missing_notice`. El proceso abortó `FASE_FALLIDA=DJANGO_SQLITE_SUITE_COMPLETA`, `RESULTADO_GLOBAL=1`, `RESULTADO_EJECUCION=1`; PG17 y Flutter no se alcanzaron. Log `/tmp/vencira-o7-o8-preflight.8INIV1Av.log`. Sin deploy, migraciones persistentes, cambios OAuth/Restic/Caddy. O7 en DEV intacta.

Diagnóstico: los dos tests asumían erróneamente que avisos a 15 y 30 días de vencer el 15/03/2027 no incluían ningún aviso antes del límite del 15/02/2027. En realidad 30 días antes es **13/02/2027** y sí es elegible. Arreglo SOLO de fixtures a 15/20 días para el caso sin aviso legal; se añadieron asserts positivos que comprueban 30 días elegible/control, sin cambiar código de producción. GitHub commits `3da14efc0c1f32108af04844bd5e76d9f7f1cbeb` y `14544af6d41237f461e24df0f07ebc52fda25659`. Falta RE-EJECUTAR preflight completo y observar SQLite, PG17 temporal y Flutter verdes. Handoff corto actualizado en `docs/NEXT_CHAT_HANDOFF.md`.

## 24/10/2026 — Validación integral O8b superada tras corregir tests

El usuario ejecutó nuevamente `scripts/validate_o7_o8_preflight.sh` tras corrección de los dos fixtures de fechas. Salida real: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log privado `/tmp/vencira-o7-o8-preflight.yBxjinGo.log`; no alteración persistente DB/Restic/OAuth/Caddy. **Esto valida la versión API-only O8b anterior a la nueva UI, NO certifica cambios Flutter posteriores**.

**Para ahorrar una ronda de despliegue:** se añadió una tarjeta ES/CA de simulación de avisos en `clients/flutter/lib/ui/reminder_preview_card.dart`, integrada en el detalle de anotaciones abiertas y no archivadas. Entrada configurable de 1–12 anticipaciones 0..365 únicas, fecha de referencia civil, lista de fechas, pregunta de control prevista y mensajes de caso tardío/Vida/sin control; UI dice expresamente que NO guarda, NO envía ni marca avisos. Cliente tipado `VenciraReminderPreview` y `HttpVenciraApi.fetchReminderPreview` para la ruta read-only protegida; prueba Flutter `clients/flutter/test/reminder_preview_test.dart` para ES/CA, validación sin request para días duplicados, defensa contra resultados falsos `delivered=true` y fechas malformadas. Se corrigió ANTES de pruebas una inserción accidental en `vencira_api.dart` reconstituyéndolo desde SHA base estable `135411a7...`, con extensión limpia y fuente final de 51135 caracteres. **NUEVA UI AÚN SIN EJECUCIÓN DE PREFLIGHT**; NO está desplegada.

**Orquestación protegida añadida** `scripts/validate_and_deploy_o8b.sh`: ejecuta preflight íntegro Django SQLite+PG17 temporal y Flutter analyze/tests/build; **solo si queda verde** lanza `scripts/deploy_o8b_no_migrations.sh` para API+Flutter Web del stack `vencira_localcheck` exclusivamente, bajo gates de fuente validada PIN `291c82d50b5c1f77cc8960bfb0f30e302d45e40d` (todos los cambios backend/clients/compose/deploy de la fase están en ese ancestro), O5 Restic activo/copia fresca tras OAuth, esquema 0014, imágenes anteriores recuperables y salud inicial. Conserva imágenes actuales con etiquetas únicas, construye API y Web, verifica `migrate --check` sin ejecutar migración, recrea solamente API y Web con --no-deps --no-build, verifica el contenedor DB original, HTTP 200, acceso anónimo O7/O3/O8b 401/403, salud de API/DB/Web y acceso HTTPS. Si el gate falla antes del despliegue, **NO toca los servicios**; si falla después de recrear API o Web, no reintentar a ciegas y comprobar el recibo e imágenes guardadas. No restaurar datos de forma automática.

**Próximo paso ahora**: sincronizar rama, ejecutar `bash -n scripts/validate_and_deploy_o8b.sh && bash scripts/validate_and_deploy_o8b.sh`. Se espera `O8B_PREFLIGHT_COMPLETO=OK`, `DESPLIEGUE_O8B_LOCALCHECK=OK`, `O8B_DEPLOY_COMPLETO=OK`, `O8B_VALIDADO_Y_DESPLEGADO=OK`, `RESULTADO_ORQUESTACION=0`; sin pruebas reales no afirmar ninguno. Después aceptación funcional en web DEV: abrir anotación abierta ficticia, ver «Simulador de avisos», cambiar días (ej. 20,15) y comprobar cálculo/advertencia y que los avisos no se guardan. No usar el antiguo script de O7/O8a. Continuar O8c (persistencia, migración explícita conforme O4) y O9–O10; quedan decisiones §18 sin aprobar.

## 25/10/2026 — O8b preflight API y DB verde, Flutter analyze falló; corregido en GitHub, SIN redeploy

**Salida REAL del usuario en Ubuntu sobre checkout `87eae1d1287d8e10a6a53d0ce86329dd9b3202b0`:** suite Django SQLite 141/141 OK y PostgreSQL17 temporal 141/141 OK. En `FLUTTER_ANALYZE_TEST_BUILD` falló con 2 errores: `Expected to find ')'` en `clients/flutter/lib/api/vencira_api.dart:30:66` y `Missing concrete implementation of 'VenciraApi.fetchRenewalHistory'` en `clients/flutter/test/reminder_preview_test.dart:6:7`. Resultado `FASE_FALLIDA_ORQUESTACION=PREFLIGHT_INTEGRAL`, `RESULTADO_ORQUESTACION=1`, `RESULTADO_EJECUCION=1`, `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`; log `/tmp/vencira-o7-o8-preflight.3DlYdz3u.log`. **No se llegó a BUILD_WEB/DEPLOY; DEV permanece en O7/O8a (`b61e357...`)**.

**Correcciones exactas**: (1) eliminar coma fuera del grupo de parámetros nombrados en la interfaz Dart `VenciraApi.fetchReminderPreview` (`ce8bcab59b9e856cb5bd474af3382f3cce0a062c`), (2) añadir implementación ficticia `fetchRenewalHistory` en `FakePreviewApi` del test Flutter (`c8ddfa7af72a6dffb76ecbd1f1b985b0f00dc6f7`); no código backend modificado. Gate de `scripts/deploy_o8b_no_migrations.sh` actualizado para exigir igualdad de fuentes contra commit `c8ddfa7af72a6dffb76ecbd1f1b985b0f00dc6f7` y preservar rollback tags (`026df7594f0aa1053a25cfa1abee49f10b438a68`). **Aún NO se ha ejecutado una nueva validación sobre estas correcciones**.

**Siguiente acción segura del usuario:** `git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash -n scripts/validate_and_deploy_o8b.sh; bash scripts/validate_and_deploy_o8b.sh` desde `/home/vencira/vencira-localcheck`, con subshell para no cerrar SSH y `RESULTADO_EJECUCION=$?`. Wrapper primero ejecuta Django SQLite+PG17 temporal y Flutter analyze/test/build; **solo si todo está verde** arranca `deploy_o8b_no_migrations.sh` con O5 backup y PostgreSQL 0014 inalterados, API+web, HTTP auth, y etiqueta imágenes anteriores. Ante cualquier fallo no repetir a ciegas. Esperar evidencia final `O8B_VALIDADO_Y_DESPLEGADO=OK` y `RESULTADO_EJECUCION=0` antes de afirmar que O8b está operativa en DEV. Después comprobar en detalle de una anotación ficticia abierta el simulador ES/CA con días 60,45,35 y 20,15, advertencias, sin guardar ni enviar avisos.

## 25/10/2026 — O8b segundo intento: backend OK, regresiones de Flutter UI; parche y prueba dirigida pendientes

**Salida usuario:** preflight en Ubuntu alcanzó `FLUTTER_ANALYZE_TEST_BUILD`: Django SQLite 141/141 y PostgreSQL17 efímero 141/141 OK; Flutter analyze superado, pero `flutter test` reportó **6 fallos**: cuatro antiguos (`contact_followup_test.dart` ES/CA, `manual_follow_up_test.dart` ES/CA) y dos nuevos (`reminder_preview_test.dart` ES/CA), con varias excepciones. Se aportó solo la cola del log, no el primer bloque de excepciones; no se ha demostrado una causa única. Log local privado `/tmp/vencira-o7-o8-preflight.ZlG3Vjhy.log`. Orquestador falló `FASE_FALLIDA_ORQUESTACION=PREFLIGHT_INTEGRAL`, `RESULTADO_ORQUESTACION=1`, `RESULTADO_EJECUCION=1`. **NO SE DESPLEGÓ O8b**; DEV sigue en despliegue O7/O8a `b61e357...`, DB y O5 intactos.

**Remediaciones aplicadas SIN EJECUTAR AÚN TESTS:** para no alterar la ubicación de controles de contacto/seguimiento O2, se movió la nueva tarjeta de simulación desde la zona media del detalle a un `ExpansionTile` inicialmente plegado **después de los controles existentes**, para consultar la API solo tras expandirse (`72694b0a0d2e3095a649100f416aaa739d2bea68`). En `clients/flutter/test/reminder_preview_test.dart` se añadieron `AppLocalizations.localizationsDelegates`, ES/CA y viewport conocido 375x900, y `tester.ensureVisible` antes de cada tap (`1986ecfbf35f53c6f8f455cc0799d740ed99aeb7`). Estas medidas son hipótesis fundadas por el tipo de regresiones; si persiste fallo, **consultar primera excepción** del log antes de modificar de nuevo.

Se endureció `scripts/validate_o7_o8_preflight.sh` (`515a4440d196ce747e0fe81a7773a6be161bf122`): ahora corre antes pruebas Flutter dirigidas de nuevo simulador, contacto y seguimiento y extrae el primer bloque de excepción Flutter (hasta 120 líneas) si falla, además del grep y cola. Script de despliegue O8b **repineado** al commit fuente de la UI y pruebas `1986ecfbf35f53c6f8f455cc0799d740ed99aeb7` (`a161f83ee33d690e346cc27ca6e12f113c8847ca`) para impedir desplegar fuentes distintas de las verificadas. No se han tocado otros fuentes, migraciones ni servicio vivo.

**Próximo paso único**: sincronizar branch por `git fetch`+`git merge --ff-only FETCH_HEAD`, ejecutar `bash -n scripts/validate_and_deploy_o8b.sh && bash scripts/validate_and_deploy_o8b.sh` dentro de subshell, finalmente `RESULTADO_EJECUCION`. El orquestador NO despliega salvo SQLite, PG17 efímero, Flutter analyze, las tres pruebas Flutter dirigidas, suite Flutter completa y build web en verde. En éxito, deploy con O5 snapshot reciente, imágenes anteriores etiquetadas, contenedor PG y esquema 0014 sin cambios, HTTP 200/auth, API/WEB saludables. Si falla, usar **PRIMER BLOQUE FLUTTER** emitido, no repetir ni desplegar a ciegas. No declarar verde hasta respuesta del usuario. Continuidad documentada para chat nuevo.

## 25/10/2026 — O8b COMPLETADO: preflight integral y despliegue DEV confirmados

**Salida de la ejecución real del titular** del orquestador `scripts/validate_and_deploy_o8b.sh`: `O8B_DEPLOY_COMPLETO=OK`, `O8B_VALIDADO_Y_DESPLEGADO=OK`, `RESULTADO_ORQUESTACION=0`, `RESULTADO_EJECUCION=0`, `CONSOLA_ABIERTA`. Estos marcadores **solo se emiten si** previamente se ha completado el preflight integral SQLite + PostgreSQL17 efímero + Flutter (análisis, tests dirigidos, suite completa, compilación web) y el despliegue condicionado de API + Flutter Web del proyecto `vencira_localcheck`. La copia O5 reciente, migraciones `0014` sin cambios, imágenes anteriores recuperables y chequeos de autenticación/HTTP son gates del script de despliegue. **No se dispone en este mensaje del recibo ni de los identificadores exactos de las imágenes previas creadas en esta última ejecución**, ni del `COMMIT` que mostró la consola; no inventarlos. La rama tenía HEAD `7e83f8d2cf617a7c8db09ca25cd49ffe878f2b7e` antes del `git fetch`/merge y no hay cambios de código posteriores a ese HEAD previos a los docs siguientes.

**Estado fiable**: O8b **VALIDADO Y DESPLEGADO EN DEV**, solo simulación no persistente (API GET autorizada y tarjeta ES/CA en detalle de anotación, plegada después de los controles de contacto y seguimiento); **todavía no hay aceptación manual de UX en navegador**. O7 resultados navegables mes/trimestre/año aceptados visualmente por el usuario. O5 diaria en uso; no reconfigurar. O8b NO crea ni envía mensajes ni guarda regla.

**Próxima validación manual breve**: abrir `https://dev.vencira.es` en una anotación DEMO abierta; desplegar sección «Simular avisos de vencimiento»; comprobar 60,45,35 y después `20,15`; debe advertir si no hay pregunta previa al mes civil, jamás marcar enviado ni guardar configuración; navegar fuera y volver para verificar default sin guardar. Si algo difiere, registrar captura sin datos reales ni secretos y reparar.

**Siguiente lote O8c:** permitir guardar reglas por anotación, con motivos como dato aún sin decidir; no reutilizar directamente políticas globales workspace `ReminderPolicy` (`enabled=False`) porque su alcance es organización y podría alterar otras pólizas. Crear diseño de tabla independiente y migración 0015 ADITIVA bajo protocolo O4 de copia-restauración PG efímero, roles y auditoría; no activar canales externos. Decisiones §18 pendientes: motivos por defecto, manejo alta tardía y sin aviso legal, Vida, avisos no atendidos, selección de entrega; plantear defaults seguros antes de habilitar. Seguir plan `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`.

## 25/10/2026 — O8b: aceptación funcional COMPLETA por el promotor

Tras el despliegue seguro `O8B_VALIDADO_Y_DESPLEGADO=OK` y orquestación 0, el usuario confirma **«Comprobado, todo sí»** a la lista de aceptación: al abrir anotación DEMO activa se ve la sección desplegable «Simular avisos de vencimiento»; aparecen fechas calculadas para 60/45/35; cambiar a 20/15 actualiza fechas y presenta advertencias adecuadas; al salir y regresar se restauran defaults porque nada se guarda. **O8b TECNICA Y FUNCIONALMENTE ACEPTADA EN DEV**. No se han autorizado envíos, persistencia de avisos ni uso de datos reales.

Se puede avanzar al diseño O8c de guardado **draft** por anotación, sin habilitar notificaciones, bajo controles O4 y decisiones §18. Ver `docs/OPERATION_O8C_PERSISTED_RULES_PLAN.md`. No volver a ejecutar script de despliegue O8b completado.

## 25/10/2026 — O8b aceptada; O8c guardado SOLO BORRADOR implementado en GitHub, NO validado/desplegado

El usuario confirmó **«Comprobado, todo sí»** a los tres escenarios manuales O8b: fechas 60/45/35 correctas, simulación 20/15 y avisos de control, y al volver no se guardan modificaciones. O8b **COMPLETA Y ACEPTADA DEV**, sin notificaciones reales.

**Trabajo nuevo O8c EN GITHUB:** modelo `RenewalReminderDraft` OneToOne por anotación en `backend/reminders/models.py` y migración aditiva `0015_renewal_reminder_drafts.py` (SOLO draft con DB CheckConstraint, JSON días, revisión positiva, actor y timestamps), endpoint autenticado GET/PUT `/api/v1/workspaces/<workspace>/renewals/<renewal>/reminder-config/`, validación JSON estricta 1..12 días únicos 0..365, `revision=0` inicial y concurrencia optimista bajo lock SQL, 409 si stale, permisos según `_visible_renewals`, 409 archived/closed, sin tocar policies/candidates ni enviar nada. Tests backend `test_reminder_draft.py` incluyen tenant, CSRF, concurrencia secuencial, no side effects, validación. Flutter tipado `VenciraReminderDraft` y `VenciraReminderDraftCard` ES/CA con botón «Guardar solo borrador» y UI de conflicto, insertado en simulador plegado, pruebas `reminder_draft_test.dart`. El preflight general se amplió para ejecutar pruebas dirigidas O8c más regresiones O8b/contacto/O2 antes de toda suite Flutter. Documento `docs/OPERATION_O8C_PERSISTED_RULES_PLAN.md` actualizado con contrato exacto y límites.

**CRÍTICO: esta implementación NO cuenta aún con ejecución de test de Ubuntu ni despliegue.** Servidor DEV continúa con código O8b y schema PG17 `reminders.0014_renewal_outcomes`; no realizar `docker compose up` ni arrancar imágenes API de O8c que exigen `0015`. No reutilizar antiguos scripts de despliegue sin migraciones. Se mantiene O5 cifrado diario inalterado. Siguiente acción: el usuario ejecuta *solo* `bash scripts/validate_o7_o8_preflight.sh` después de fast-forward GitHub; se requiere Django SQLite+PG17 temporal y Flutter analyze/tests/build completamente OK. Si falla, corregir código en GitHub y repetir gate; si verde, preparar migración explícita O4 con backup, restauración PG17 efímero y `migrate --plan` antes de cualquier operación en DB persistente. Los motivos y canales de notificación siguen pendiente §18: no habilitar mensajes por un borrador.

## 25/10/2026 — O8c preflight integral VERDE; restauración cifrada y migración 0015 en clon preparadas

Usuario confirma `COMMIT=80a5ac618f476a2d3b256499047dfdd1ada01c12` en Ubuntu y TODOS los gates: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.E7GBeX2E.log`. La migración 0015 está probada exclusivamente sobre bases de test aisladas; PostgreSQL persistente sigue en `reminders.0014_renewal_outcomes`; O8b permanece aceptada en DEV.

**Nuevo script GitHub:** `scripts/rehearse_o8c_0015_from_o5.sh`, solo ensayo previo en clon. Requiere que backend/clients/compose/deploy coincidan con fuentes validadas commit `80a5ac618f476a2d3b256499047dfdd1ada01c12`; verifica DB 0014 y servicios sanos, O5 y clave de recovery root-only; hace copia PostgreSQL NUEVA cifrada Restic a Drive, la restaura con pipe sin dump local en PG17 EFÍMERO conectado a red Docker interna aislada, compara recuentos y migraciones, hace `migrate --plan` y `migrate reminders 0015_renewal_reminder_drafts --noinput` SOLO contra clon, comprueba constraints draft-only, tabla vacía, sin backfill, datos anteriores iguales, y que contenedores originales y DB 0014 permanecen intactos. El clon/red se eliminan al salir. No aplica 0015 ni despliega en DEV. **SCRIPT AÚN SIN EJECUCIÓN REAL**, no declarar recuperación verificada hasta resultado `ENSAYO_O8C_0015_AISLADO=OK`.

**PRÓXIMO PASO PARA NUEVO CHAT O EN ESTA CONVERSACIÓN**: desde usuario `vencira` en Ubuntu un solo bloque: `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; bash -n scripts/rehearse_o8c_0015_from_o5.sh || exit 1; sudo bash scripts/rehearse_o8c_0015_from_o5.sh ); echo RESULTADO_EJECUCION=$?; echo CONSOLA_ABIERTA`. Reportar marcadores, sin credenciales ni dump. Si falla, leer `FASE_FALLIDA` y corregir GitHub; no desplegar. Con ensayo verde, diseñar y ejecutar un NUEVO rollout O8c protegido: backup+recibo íntegro, migración explícita SOLO `0015` del DB vivo, imágenes anteriores etiquetadas y API+Web posteriormente, mantener O5 intacto; no reutilizar `deploy_o8b_no_migrations.sh`. Pendientes decisiones §18 y ninguna notificación activa.

## 25/10/2026 — Ensayo O8c validado; procedimiento de migración DEV terminado, NO EJECUTADO

El usuario confirmó restauración desde O5 cifrado (snapshot `0b838739`) en PG17 temporal y migración `0015` en clon con resultado `ENSAYO_O8C_0015_AISLADO=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Recibo de ensayo en el servidor: `/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt`, creado por root, modo 600. Las tablas previas y la API/Web de DEV permanecieron sin cambios, en esquema `0014`.

**Código NUEVO EN GITHUB, NO EJECUTADO**: `scripts/deploy_o8c_0015_guarded.sh` completo y habilitado tras auditoría de su orden: gate `VALIDATED=80a5ac618f476a2d3b256499047dfdd1ada01c12`, recibo reciente root-only con snapshot y prueba restaurada, API O4 `migrate --check` sin automigración, salud y esquema original `0014`, auditoría O5, etiquetas recuperables para imágenes API/Web O8b, compilación de ambas imágenes, plan `0015` de solo lectura, copia O5 cifrada NUEVA previa al DDL, migración **explícita** `manage.py migrate reminders 0015_renewal_reminder_drafts --noinput`, verificación de tabla vacía/restricciones/revisión, `migrate --check` posterior, recreación SOLO API y Web, HTTP 200, endpoints de resultados O7, preview O8b, config O8c y desenlaces O3 anónimos 401/403, salud final, y recibo privado. Fallo posterior a migración se trata como estado parcial: **NO reintentar ni restaurar automáticamente**. PostgreSQL no se reinicia por este procedimiento, O5 timers y Caddy no se modifican. NO envía avisos ni habilita reglas.

**Nuevo gate estático**: `scripts/check_o8c_deploy_static.sh`: ejecuta `bash -n` y comprueba existencia/orden de las operaciones obligatorias y ausencia de acciones destructivas conocidas. Debe pasar ANTES del despliegue. El asistente aún no ha recibido la ejecución local de este gate ni la del despliegue. El próximo comando del usuario será `(cd /home/vencira/vencira-localcheck; git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash scripts/check_o8c_deploy_static.sh; sudo bash scripts/deploy_o8c_0015_guarded.sh); echo RESULTADO_EJECUCION=$?; echo CONSOLA_ABIERTA`, preservando `|| exit 1` en cada fase de la subshell. **No declarar O8c desplegada hasta `O8C_DESPLIEGUE_0015_LOCALCHECK=OK` y final cero.**

Tras éxito, UAT DEV: abrir anotación sintética activa > Simular avisos > Guardar solo borrador `20,15`, volver y comprobar que persiste únicamente en esa anotación, otras conservan defaults, no notificaciones; conflict/revisión; no datos reales. Mantener documentación actualizada en todo cambio de chat.

## 25/10/2026 — O8c UAT móvil: guardado visible, espacios corregidos EN GITHUB (no desplegados)

Usuario aporta 3 capturas Android de `dev.vencira.es`: se ve `Guardar borrador de avisos` y estado `Borrador guardado` con `20,15`, además de advertencia `Sin aviso anterior al límite informativo`; comunica también `RESULTADO_EJECUCION=0`. **Evidencia visual de borrador guardado**, no necesariamente prueba de aislamiento en otra anotación ni confirma todavía la nueva corrección UI.

Detecta espaciados demasiado estrechos: estado `Borrador guardado` casi toca etiqueta flotante `Días antes`, y advertencia legal pegada a botón de guardar. Se corrigió solo en `clients/flutter/lib/ui/reminder_draft_card.dart`: 20 px bajo estado, 16 px tras campo y 12 px bajo cada aviso. Pruebas `clients/flutter/test/reminder_draft_test.dart`: validación geométrica responsive 320px ES/CA tema claro/oscuro. Fuentes corregidas hasta commit `0f9c17b03fde147d780fdcff5fc2d3e162488a0c`. Documentación detallada `docs/OPERATION_O8C_UI_SPACING.md`.

Preparado script NUEVO `scripts/deploy_o8c_spacing_web_only.sh`, gate a fuentes pin y esquema PostgreSQL persistente **0015**; etiqueta imagen anterior, construye/recrea únicamente `web_preview`, comprueba mismas IDs de contenedor DB+API, migraciones sin cambios, HTTP y protección auth. NO ejecutar de nuevo `deploy_o8c_0015_guarded.sh`, NO hay migraciones adicionales, NO se modifica O5. **ESTE CAMBIO DE ESPACIADO TODAVÍA NO SE HA VALIDADO NI DESPLEGADO EN EL SERVIDOR.**

**Próximo comando de usuario**: `git fetch` + `git merge --ff-only`, `bash -n scripts/deploy_o8c_spacing_web_only.sh`, `bash scripts/validate_o7_o8_preflight.sh` y SOLO si éste sale 0, `bash scripts/deploy_o8c_spacing_web_only.sh`. Usar subshell y resultado al final. Si falla, inspeccionar fase; si Web ya recreada, no repetir automáticamente. Tras éxito, UAT visual con márgenes correctos y aislamiento entre anotaciones.

## 25/10/2026 — O8c móvil: usuario confirma «Done»; O9a creado en GitHub, PENDIENTE tests reales

El usuario contestó `Done; seguimos` después del comando de preflight + despliegue **web-only** de márgenes O8c. No aportó el log ni marcadores del script en esta ocasión: tratar la ejecución como comunicada pero no afirmar de forma independiente `RESULTADO_GLOBAL=0` ni espaciado visual aceptado. No volver a ejecutar la migración `0015`; O8c sigue técnicamente desplegada según el recibo anterior. O9a se creó posteriormente en Github **sin desplegar**, continuando según whitepaper roadmap §7–8/18.

**O9a (solo lectura):** nuevo motor puro `backend/reminders/control_assessment.py`, GET autenticado `.../control-assessment/` (`control_assessment_api.py`, URL), que usa `RenewalReminderDraft` persistido o defaults 60/45/35 y calcula fecha de último control anterior al tope civil. Distingue control futuro, hoy y revisión manual (Vida, sin aviso elegible, fecha límite transcurrida, control calculado pasado). Respuesta con banderas `assessment_only=true,answer_recorded=false,scheduled=false,delivered=false`, sin datos personales, sin guardar respuestas/entregas. Flutter `VenciraControlAssessment` tipado y `VenciraControlAssessmentCard` ES/CA plegada en detalle con botón de actualización al guardar otro borrador. Sin Yes/No ni programación, aún bloqueadas decisiones §18. Tests `backend/reminders/test_control_assessment.py`, `clients/flutter/test/control_assessment_test.dart` (incluye 320px claro/oscuro), preflight general dirigido actualizado.

**IMPORTANTE incidente corregido antes de cualquier validación:** sustitución JS de texto con un patrón que incluía dólar en regexp duplicó un bloque del archivo `clients/flutter/lib/api/vencira_api.dart`; se reconstruyó inmediatamente desde base limpia commit `855b09d4453d7c845b2710d091b09cbffceb1659` más tres inserciones mediante posiciones exactas (no `String.replace` interpolado), comprobando longitud aprox. 58K frente a 55K base, una sola clase HttpVenciraApi. Commit de reparación `0f0825b1622cd04b6370b02a9eb6a8d055ce45ce`. No se desplegó ni probó la fuente duplicada.

Detalle y decisiones O9: `docs/OPERATION_O9_CONTROL_2026-10-25.md`. **Próximo paso único:** sincronizar rama `integration/local-e2e-prep`, ejecutar `bash -n scripts/validate_o7_o8_preflight.sh` + `bash scripts/validate_o7_o8_preflight.sh` en Ubuntu; comparte marcadores `RESULTADO_GLOBAL`. Debe incluir Django SQLite+PG17 temporal y Flutter analyze/tests/build. **NO DESPLEGAR O9a hasta pruebas verdes**, entonces preparar rollout API+Web sin migraciones, estrictamente con PG `0015` y O5 sana; NO reutilizar scripts O8c con versiones fijadas ni volver a migrar PostgreSQL. Estado comercial O9b y notificaciones pendientes.

## 25/10/2026 — O9a preflight integral VERDE; rollout API+Web sin migraciones preparado, NO EJECUTADO

**Salida real del usuario tras sincronizar código O9a:** `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local privado `/tmp/vencira-o7-o8-preflight.jYamaKcr.log`. El checkout de fuentes para esta validación corresponde al commit `37d510e070ff8ccdd7e87b8f3365b913f029ed9f`. La salida no incluye línea `COMMIT` en el fragmento, pero el preflight script valida HEAD y ese fue último HEAD de código antes de la ejecución. **No se ha desplegado ni migrado durante estas pruebas.** DB persistente sigue `0015`; O8c operativa.

**Preparado (aún NO ejecutado) rollout de O9a:** `scripts/deploy_o9a_no_migrations.sh`, especializado para API+Flutter Web de `vencira_localcheck`, fuentes backend/clients/compose/deploy pin al commit verde anterior, comprueba DB `reminders.0015_renewal_reminder_drafts` y tabla drafts existente, API `migrate --check` no automigra, O5 backup sano/reciente y acceso remoto; guarda tags recuperables de imagen API/Web, construye ambas, ejecuta `manage.py migrate --check --noinput` solo lectura y comprueba contenedores originales intactos antes de actualizar API, luego Web. Postchecks DB ID y count migraciones iguales, HTTP local (200), autenticación anónima denegada en O7, O8b, O8c, O9a y desenlaces (401/403), salud API/DB/Web, recibo y etiquetas. O5, Caddy, tokens, PostgreSQL y el esquema 0015 no se reinician o cambian. Ante fallo después de recrear servicios, revisar recibo y evitar repetir a ciegas.

**Control estático nuevo:** `scripts/check_o9a_deploy_static.sh` verifica `bash -n`, secuencia seguridad, ausencia de comandos de migración/destrucción, nombre proyecto correcto. **Próxima orden**: checkout actualizado por `git fetch` y `git merge --ff-only`; `bash scripts/check_o9a_deploy_static.sh` y solo si OK `bash scripts/deploy_o9a_no_migrations.sh`, dentro de subshell, imprimir `RESULTADO_EJECUCION` y `CONSOLA_ABIERTA`. NO volver a ejecutar deploy O8c ni migración 0015. Despliegue solo se considera verificado al recibir `O9A_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Luego UAT de nueva tarjeta O9a en ficha DEMO, refresco tras editar draft.

**O9b sigue pendiente decisiones §18**: qué opciones «Sí», «No», motivos y intervalos/repeticiones; Vida y fecha civil informativa requieren revisión. Ninguna respuesta se almacena en O9a ni se envía aviso. Mantener `docs/NEXT_CHAT_HANDOFF_SHORT.md` actualizado en siguiente turno.

## 25/10/2026 — Recuperación del PDF original y rectificación de O9b (FUENTE PRIMARIA)

El usuario adjuntó `White_paper_agenda_vencimientos.pdf` original (23 páginas, 828405 bytes, 18/10/2026, @Bibroker Mediadores, S.L.U.; SHA-256 `7158c085a0771f1c09c19223284345899ef516394d4ddd77c3b63cdda5598c66`). Se revisaron las tablas impresas (§8 p.11) y §10 p.13 / §18 p.22. **Se añadió en GitHub la transcripción completa buscable** `docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md` y el índice `docs/source/README.md`. El **PDF binario todavía NO está subido a GitHub** por limitación de la conexión de escritura; la transcripción conserva el texto, pero los diagramas y maquetas exigen revisar el PDF original adjunto. No afirmar que el PDF en sí está versionado.

**Rectificación clave**: sí están aprobadas en el PDF §8 la pregunta EXACTA «¿Se ha notificado a la aseguradora su no renovación?»; las tres opciones Sí «Avisada por el cliente», «La aseguradora no renueva», «Notificado por mí» (registrar con fecha/hora/usuario, anotación sigue activa) y No «Avísame dentro de [selector de días]» (crear aviso «Comunicar no renovación de [nombre del cliente]» a fecha <= límite civil; §10 p.13 repetir la pregunta el día elegido). Nunca cerrar automáticamente tras Sí. Selector rojo al alcanzar/superar límite y recomendación de margen. §16 p.20: «Notificado por mí» presupone firma o autorización del cliente. **Persisten pendientes §18**: casos tardíos, sin aviso antes del tope, Vida, motivos por defecto y no atendidos, pero **no** estos textos ni sus efectos básicos.

Contrato `docs/OPERATION_O9B_RESPONSE_CONTRACT.md` y roadmap maestro reconciliados con la fuente, eliminando afirmaciones previas de que las cuatro respuestas eran desconocidas. Documento de continuidad corto reescrito con estado real, links de fuente y plan O9b.

**Estado del servidor sin cambios por esta documentación:** O9a desplegada, PostgreSQL persistente `0015`, backend y Flutter Web saludables según última evidencia del usuario. O9b aún no implementa respuestas ni tiene migración `0016`; no se han programado ni enviado notificaciones. Próximo paso: validador puro O9b-1 con tests, sin BD; después implementar respuesta auditada con protocolo O4/O5 y cambios aditivos tras validación. No pedir nuevamente los textos §8 al usuario.

## 25/10/2026 — AUDITORÍA INTEGRAL DEL WHITEPAPER ORIGINAL (NO SOLO O9)

El usuario solicitó revisar **todo el desarrollo actual** frente a los 23 folios del PDF original. Se completó revisión de árbol completo de rama `integration/local-e2e-prep` (275 entradas), modelos/migraciones `0001`–`0015`, APIs, UI Flutter, seguridad y pruebas, contrastados con §§1–18 del PDF fechado 18/10/2026. **Informe estructurado y evidencia por archivo/folio:** `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`. No hubo despliegue, migración ni pruebas dinámicas nuevas en esta auditoría. Último DEV confirmado: O9a + O8c operativas, PostgreSQL `0015`, notificaciones NO activadas.

**Dictamen: dirección y arquitectura ALINEADAS PARCIALMENTE; v1 NO completa.** Discrepancias en funcionalidades YA desarrolladas: (A-01) Flutter exige «Referencia» extra ajena a obligatoriedad §6 y API permite nuevos registros con entrada/nombre vacíos por compatibilidad; (A-02) «No aceptó» mueve +1 año pero `outcomes._rebuild_candidates()` solo usa políticas `enabled=True`, no reinicializa los avisos predeterminados 60/45/35 en la anotación; (A-03) «Conseguido» cambia solo esa anotación a Cliente, sin sugerir Cliente por defecto al crear posteriores anotaciones de la misma persona; (A-04) textos ES/CA aún escritos directamente en Dart, en contra de §13. Otras brechas de producto: `main.dart` abre Dashboard, no página HOY directa §5; O8c guarda solo días/borrrador sin motivos/programación; §7–10 notificaciones, respuestas auditadas/repeticiones aún no desarrolladas; team lifecycle, adjuntos, Excel, resultados por miembro, borrado automático/avisos de retención, apps móviles offline y MFA/RGPD incompletos. Catálogo DGSFP no precargado/verificado. §18 propuestas abiertas **NO son decisiones aprobadas**. No confundir tests verdes O8c/O9a con cumplimiento completo.

**Prioridad propuesta:** primero corregir cuatro desviaciones en funciones existentes con tests y sin activar envíos, luego O9b según 4 opciones exactas §8 p.11 y control civil, después agenda HOY/avisos, y finalmente componentes esenciales de lanzamiento. Mantener solo datos DEMO en DEV. **Documento de auditoría es fuente de verdad** para no perder desajustes al cambiar de chat: `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`.

## 25/10/2026 — FASE ÚNICA DE ALINEACIÓN DEL WHITEPAPER PREPARADA (SIN DEPLOY)

El usuario aprobó **resolver en una sola fase todas las discrepancias de funcionalidades desarrolladas** encontradas en la auditoría original: A-01 alta (solo 3 obligatorios, referencia opcional/autogenerada), A-02 «No aceptó» restablece 60/45/35 del borrador de la anotación sin envíos, A-03 «Conseguido» propone Clientes en NUEVA anotación al copiar datos desde póliza autorizada que es cliente, A-04 centralización ES/CA en ARB en O8b/O8c/O9a, detalle, desenlaces, alta y agendas; A-05 HOY como primera agenda si un workspace, o tras seleccionar cuando son múltiples. Se añadieron pruebas Django y Flutter; el backend sigue sin nueva migración, PG persistente `0015`, ninguna notificación ni envío activado. **LOS CAMBIOS NO ESTÁN VALIDADOS NI DESPLEGADOS**; no afirmar resultado verde.

Documento completo de alcance/evidencia: `docs/PHASE_WHITEPAPER_ALIGNMENT_2026-10-25.md`. Script orquestador único con fail-closed: `scripts/validate_and_deploy_whitepaper_alignment.sh`, que exige `scripts/check_whitepaper_alignment_static.sh`, `scripts/validate_o7_o8_preflight.sh` TODO VERDE SQLite+Postgres17 temporal+Flutter, y solo entonces `scripts/deploy_whitepaper_alignment_no_migrations.sh`. Nuevo despliegue pin a SHA de fuente probada `c4886728f3a9c53c592911d19096056bc56a0949`, respaldos O5 solo READ-ONLY, imagen API+Web anteriores recuperables, mismo DB ID y conteo de migraciones, solo recreación API+Web, sin modificar schema, CSRF/auth smoke.

**Próximo paso en Ubuntu (un bloque):** subshell `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; echo COMMIT=$(git rev-parse HEAD); bash -n scripts/validate_and_deploy_whitepaper_alignment.sh || exit 1; bash scripts/validate_and_deploy_whitepaper_alignment.sh ); echo RESULTADO_EJECUCION=$?; echo CONSOLA_ABIERTA`. Si falla en STATIC o PREFLIGHT, NO despliega. Si falla en DEPLOY tras cambios, **NO repetir a ciegas**; revisar `FASE_FALLIDA` y recibo. Solo resultado `WP_ALIGNMENT_PHASE_COMPLETE=OK`, `RESULTADO_ORQUESTACION=0`, `RESULTADO_EJECUCION=0` permite afirmar despliegue técnico. Después UAT datos ficticios: creación sin referencia, abre HOY, copiar Cliente, No aceptó con 60/45/35 y traducción CA. No seguir O9b hasta cerrar esta fase.



## Cierre macrofase B y paso a C — 25/10/2026

El usuario confirmó «Done, todo ok» tras gate y publicación de la tarjeta premium `Historial de avisos` de ancho completo y paginación uniforme. Macrofase B **aceptada según comunicación del usuario**; no consta aquí un recibo `RESULTADO_GLOBAL=0` transcrito del último despliegue y no se debe inventar. Script web-only actual: `scripts/deploy_macro_b_premium_ui_web_guarded.sh`, fuente pin `d891c2df6e742698c99d4cf84cbc3573025feefd`. No repetir despliegues B.

Handoff autoritativo al abrir otro chat: `docs/HANDOFF_MACROFASE_C_2026-10-25.md`. Macrofase C propuesta: auditar primero código O9b **ya existente** (Sí/No manual, repetición como aviso interno), contrastar con whitepaper §§7–10/18 y cerrar solo decisiones pendientes antes de nuevos automatismos. Mantener PostgreSQL 0018, O5, OAuth, Caddy y timers hasta nuevo gate/aprobación. Sin emails/push ni entrega real por ahora.


## C1 — Primera decisión aprobada (25/10/2026)

El promotor respondió «Ok, mantenemos actualizados durante los trabajos, seguimos» a la propuesta de motivos. Se registra **aprobación conversacional** de los motivos predeterminados editables: **60 días** «Revisar vencimiento y contactar con el cliente»; **45 días** «Enviar notificación de no renovación»; **35 días** «Comprobar comunicación de no renovación y responder a la pregunta de control». Ello no supone envío real. La pregunta aparece en el último aviso elegible estrictamente anterior al límite del mes civil, que puede no ser el de 35 días. La configuración por cuenta/anotación sigue el §7 y no se alteran borradores existentes sin acción expresa. Esta actualización documental no ejecuta cambios funcionales, gates ni migraciones.

**C1 abierto:** avisos pendientes HOY, alta tardía, ausencia de aviso anterior al corte, Vida, autorización/evidencia de «Notificado por mí», canales y reintentos. Las propuestas §18 no equivalen a decisiones. Antes de C2 cotejar código existente y preparar pruebas; no repetir fases A/B.


## C1 — Regla de avisos no atendidos aprobada (25/10/2026)

El promotor respondió explícitamente «Sí, adelante» a la propuesta: en agenda HOY mostrar arriba los avisos internos vencidos no atendidos como **Pendientes**, por fecha original ascendente (más antiguo primero), sin desaparecer al cambiar de día; conservar acciones **Completada, Mañana, Otro día**; no duplicar al abrir HOY ni inferir una notificación entregada. Prioridad y persistencia son **regla de producto aprobada**, no certificación de que el código ya las satisfaga.

**Inspección estática inicial**: `backend/reminders/operational_api.py` conserva estados internos, CAS y `delivery_status=not_implemented`. `backend/reminders/reminder_planning.py` calcula los días transcurridos y marca altas tardías/no control, pero se abstiene correctamente de decidir §18 automáticamente. Falta verificar implementación concreta de filtrado/orden de HOY con tests; no reimplementar motor A/B. C1 siguientes decisiones abiertas: altas tardías y sin avisos anteriores al mes civil límite, modalidad Vida, evidencia y proveedores. No se ha ejecutado gate ni despliegue con esta aprobación.


## C1 — Altas tardías aprobadas, 25/10/2026

Promotor aprueba: no generar avisos retroactivos ficticios; conservar avisos futuros válidos; si pasó el control, advertir al guardar con acceso a pregunta; si venció el límite civil, advertencia roja y revisión manual; permitir guardar registrando necesidad de revisión. **Sin avisos elegibles antes del límite** es otra decisión §18 aún pendiente. Solo actualización documental, sin gate ni deploy.


## C1 — Sin aviso elegible anterior al límite (aprobado 25/10/2026)

El promotor aprueba **permitir guardar la anotación** aunque no exista ningún aviso configurado estrictamente anterior al límite civil de un mes, pero con **advertencia roja visible y revisión manual obligatoria**. Si todavía existe margen anterior al límite, la interfaz **ofrecerá crear expresamente un aviso de control**, sin crearlo automáticamente y sin superar jamás el tope civil. Si el plazo ya ha transcurrido, no ofrecer agendar retroactivamente ni afirmar que la oposición esté en plazo; advertir y solicitar revisión humana. Registrar la incidencia sin fingir envío/entrega, conservar derechos y permisos de anotación. Esta es decisión funcional C1, **aún no implementada ni validada**: reutilizar cálculo `preview_reminder_plan` y ocurrencias A/B, probar meses cortos, 29/02, límite hoy, cero avisos elegibles, roles y reintentos. Sin migración ni despliegue con esta actualización.


## C1 — Modalidad Vida (aprobada por promotor, 25/10/2026)

Al seleccionar **Vida** mostrar advertencia específica: pueden existir reglas particulares de oposición; no calificar automáticamente el corte general de un mes como plazo legal confirmado para esta modalidad. Mantener avisos configurables y guardado permitido; exigir revisión humana de las condiciones de la póliza, con estado informativo explícito. Permitir el registro manual de respuestas Sí/No conforme al contrato del whitepaper, sin presentarlas como prueba de notificación, autorización o entrega. La implementación C2 deberá revisar el bloqueo conservador actual de `control_response_api.py` y `control_repeat_schedule.py` para ofrecer registro auditado sin automatizar ni certificar un plazo, sujeto a pruebas y revisión jurídica. Decisión documentada; **sin cambios de código ni despliegue** en este registro.


## C1 — «Notificado por mí»: declaración auditada (aprobada 25/10/2026)

El promotor aprueba que, al seleccionar «Sí → Notificado por mí», la interfaz exija **confirmación expresa** del mediador de que dispone de autorización del cliente y de que ha realizado la comunicación. Registrar actor, fecha/hora y alternativa seleccionada, manteniendo la anotación abierta. Es una **declaración del usuario**, no prueba de autorización documental, envío, recepción ni cumplimiento legal. No inventar adjuntos ni certificados; la conservación privada de justificantes queda para la fase de seguridad de archivos, permisos y retención. Debe reutilizarse el modelo/API de respuestas manuales O9b, con pruebas de confirmación, CAS, idempotencia y aislamiento. Esta decisión todavía no está implementada ni probada; no activar entrega ni tocar esquema/DEV con esta actualización.

**C1 restante en la macrofase:** selección, consentimiento, fallos, idempotencia y reintentos de canales reales email/push/local/offline. La entrega requiere diseño y validación independiente; mantener `delivery_status=not_implemented` hasta que exista evidencia fiable.


## C1 — Canales aprobados; cambio expreso de email predeterminado (25/10/2026)

El promotor aprobó móvil (avisos locales incluso sin conexión y app cerrada), navegador con app abierta y permiso, y correo resumen diario; **corrigió expresamente el valor inicial del correo a ACTIVADO por defecto**, modificación posterior y consciente del §7 del whitepaper, que decía desactivado. Adoptar **Resend** como proveedor candidato de VENCIRA, por experiencia con MASBITCOIN (API HTTP con `email_id` y webhooks Svix firmados para delivered/delayed/bounced/complained; originalmente SMTP). Implementación separada con dominio/remitente, credenciales y supresiones propias de VENCIRA; jamás reutilizar claves ni destinatarios de MASBITCOIN. Los permisos legales para comunicaciones, preferencia editable, baja/desactivación sencilla, minimización de datos, contratos de encargo, DNS y validación RGPD/LSSI deben revisarse **antes de activar envíos**. La decisión de default no acredita que sea lícito enviar sin base adecuada: el motor mantendrá entrega deshabilitada hasta gate técnico/jurídico. Reintentos limitados, deduplicación, estados programado/intentado/aceptado/entregado y privacidad lockscreen conforme a propuesta aprobada. Pendiente diseño técnico, implementación, tests y despliegue; sin cambios operativos con esta nota.


## C2 — Correo corporativo y transaccional: arquitectura confirmada (25/10/2026)

El promotor confirma que **vencira.es está contratado en OVHcloud** e incluye una cuenta **Zimbra Starter de 5 GB**. Decisión: usar Zimbra como buzón corporativo para recepción/respuesta y **Resend** exclusivamente para el envío automatizado de resúmenes diarios/notificaciones desde VENCIRA, reutilizando patrones de integración (no credenciales) de MASBITCOIN. Direcciones `contacto@vencira.es` y `avisos@vencira.es` son **ejemplos**, no buzones existentes ni remitentes verificados. Antes de producir envíos: verificar cuenta concreta en OVHcloud, dominio remitente en Resend, SPF/DKIM/DMARC y compatibilidad DNS/MX, subdominio recomendado para aislar reputación transaccional, callbacks/webhooks firmados y supresión de rebotes, límites y consentimiento/base legal. Nunca compartir credenciales, claves ni listas de destinatarios entre proyectos. Correo resumen diario activado inicialmente según decisión del promotor, sujeto a validación de comunicaciones y preferencias. En este hito **solo documentación**: sin accesos a OVH, alteraciones DNS, claves, envíos, migración ni despliegue.


## C2 — Primera entrega de código (25/10/2026)

Implementado en GitHub `backend/reminders/c2_control_policy.py` con pruebas `backend/reminders/test_c2_control_policy.py` (commit de tests `d4d3878b909929021fe1e8a24956da8a58bbb173`). Proyección **pura y sin BD** sobre `preview_reminder_plan`: permitir guardar; evaluar altas tardías, cero aviso pre-corte y corte vencido; ofrecer control explícito solo antes del corte (nunca programarlo por sí misma); Vida exige revisión de términos sin presentar mes civil como límite legal confirmado; conservar únicamente los offsets cuyos avisos no han transcurrido; estados de entrega `not_implemented`. Tests incluyen 29 febrero, meses cortos, límite hoy, tardíos y entradas inválidas. **Pendiente gate real Ubuntu**, integración de endpoints/UI, filtros HOY, evidencias y transportes Resend. No ejecutar migración ni desplegar por este cambio. Usar scripts de pruebas ya existentes, sin repetir B.
