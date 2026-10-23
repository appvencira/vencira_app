# VENCIRA — CONTINUIDAD OPERATIVA (leer al comenzar un chat)

Fecha de revisión: 2026-10-23. Fuente de verdad: repositorio privado `appvencira/vencira_app`, rama `integration/local-e2e-prep`. Este documento describe **estado probado en GitHub y pasos pendientes**, no garantiza el estado de un servidor.

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

**Estado vigente 2026-10-23:** V3.1/O1/O2 aceptadas (O2 desplegada `e8d5ccf9`, migración `0013` aplicada y servicios saludables). **O3 cuatro desenlaces ha superado íntegramente el preflight aislado**, confirmación del usuario sobre commit **`4d5270be3ebb7ab32d4bab103208ed34002f0082`**: Django SQLite, PostgreSQL 17 temporal, Flutter analyze/test/build `OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, sin mutaciones persistentes. **O3 NO está desplegada y `0014` NO aplicada**. Siguiente puerta preparada en GitHub: `scripts/prepare_operativa_o3_backup.sh`, copia nueva pre0014 + restauración íntegra aislada; todavía no ejecutada. Solo después de backup/restauración `RESULTADO_GLOBAL=0`, preparar despliegue controlado de API+Web con migración `0014`. No datos reales ni notificaciones reales. Detalle en `docs/OPERATION_O3_OUTCOMES.md`.

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
 
## Límites de lanzamiento

- **No apto para datos personales reales ni producción**. Ver `docs/SECURITY_RELEASE_READINESS_2026-10-22.md` y `docs/SECURITY.md`: MFA, backups externos cifrados/restauración, cifrado en reposo, permisos, retención, RGPD/LOPDGDD y control de adjuntos aún pendientes.
- No habilitar upload/download de PDFs e imágenes hasta implementar controles de `docs/ATTACHMENTS_SECURITY_GATE.md`.
- No activar recordatorios reales por el mero hecho de desplegar la nueva ficha.

## En un chat nuevo

Leer primero este archivo desde GitHub y consultar las últimas confirmaciones del usuario sobre resultados del servidor. **No asumir que un PR fusionado equivale a despliegue.** Mantener el esquema `GitHub → pruebas aisladas → backup → migraciones → despliegue localcheck → Android → documentación final`. Evitar requerir al usuario información o verificaciones ya conocidas.
