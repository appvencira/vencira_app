# VENCIRA — CONTINUIDAD OPERATIVA (leer al comenzar un chat)

Fecha de revisión: 2026-10-22. Fuente de verdad: repositorio privado `appvencira/vencira_app`, rama `integration/local-e2e-prep`. Este documento describe **estado probado en GitHub y pasos pendientes**, no garantiza el estado de un servidor.

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

**Estado vigente 2026-10-22:** `vencira_localcheck` desplegado, migraciones `0010`–`0012` aplicadas, API/DB/Web saludables, rutas locales/proxy HTTP 200, pruebas específicas PostgreSQL resultado 0, y Android HTTPS `dev.vencira.es` aceptado por usuario. Una mejora de espaciado Flutter está **implementada en GitHub** (commit `dd9ba521714df2d58acec9a9fcfcd236766d12f4`) **pero no probada ni desplegada** al cierre de esta revisión. Próximo paso: validación agrupada + despliegue seguro de esa corrección.

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

## Límites de lanzamiento

- **No apto para datos personales reales ni producción**. Ver `docs/SECURITY_RELEASE_READINESS_2026-10-22.md` y `docs/SECURITY.md`: MFA, backups externos cifrados/restauración, cifrado en reposo, permisos, retención, RGPD/LOPDGDD y control de adjuntos aún pendientes.
- No habilitar upload/download de PDFs e imágenes hasta implementar controles de `docs/ATTACHMENTS_SECURITY_GATE.md`.
- No activar recordatorios reales por el mero hecho de desplegar la nueva ficha.

## En un chat nuevo

Leer primero este archivo desde GitHub y consultar las últimas confirmaciones del usuario sobre resultados del servidor. **No asumir que un PR fusionado equivale a despliegue.** Mantener el esquema `GitHub → pruebas aisladas → backup → migraciones → despliegue localcheck → Android → documentación final`. Evitar requerir al usuario información o verificaciones ya conocidas.
