# D2-E — Chromium hace clic sobre Flutter Web y verifica persistencia real en PostgreSQL aislado

Fecha: 11/11/2026. **Estado: CÓDIGO PREPARADO; SIN VALIDACIÓN LOCAL.** D1-Z, D2-A, D2-B, D2-C y D2-D siguen cerrados PASS.

## Motivo

D2-C comprobó operaciones de API desde Chromium; D2-D comprobó gestos de widgets Flutter en `flutter test`. Ninguno demostró en una única ejecución que **un clic en Flutter Web compilado** produce una escritura HTTP Django y que persiste en Postgres. D2-E exige exactamente esa cadena.

## Alcance de la primera fase D2-E

- Laboratorio Docker idéntico en aislamiento a D2-C: PostgreSQL 17 `tmpfs`, red Docker `--internal`, imagen Django candidata, Flutter 3.44 Web release, Nginx temporal, Caddy con TLS sintético, sin puertos publicados ni volúmenes/credenciales DEV.
- `scripts/main_d2e_seed_synthetic.py`: usuario, membresía propietario, workspace y un vencimiento ficticio `D2E-EDIT`, notas iniciales `Before D2E` con fecha fija 2027-05-31, exclusivamente en DB efímera.
- `scripts/main_d2e_chromium_gui_smoke.js`: Chromium realiza login real por formulario Django y CSRF, habilita capa de accesibilidad de Flutter Web mediante su control en el navegador si existe, exige `flutter-view` y texto de anotación ficticia en la semántica del DOM; hace **clic real** en editar, introduce notas en el campo accesible, pulsa Guardar y **solo entonces** consulta la API por GET para confirmar persistencia. **No realiza PATCH/POST desde JavaScript** para sustituir la acción GUI. Primer pase escribe `D2E GUI first`; tras recrear Nginx, el segundo pase debe escribir `D2E GUI second`, evitando falso PASS por una mutación previa.
- Repiten pruebas de seguridad TLS/CSRF, aislamiento anónimo de laboratorios anteriores, más respaldo y restauración de un esquema sintético PG17, limpieza y comprobación de identidad de contenedores DEV.

**Alcance limitado:** en la primera versión, el objetivo GUI es **editar notas de una renovación existente desde el dashboard en escritorio**. No se ha automatizado todavía desde Chromium la creación de vencimientos, datepicker, móvil, calendario ni catálogos. **No** se debe marcar un E2E funcional completo de VENCIRA ni release a partir de este único caso.

## Ficheros publicados en main

`scripts/main_d2e_browser_gui_isolated.sh`, `scripts/main_d2e_seed_synthetic.py`, `scripts/main_d2e_flutter_caddy_probe.py`, `scripts/Dockerfile.d2e-playwright` y `scripts/main_d2e_chromium_gui_smoke.js`.

La automatización usa roles/nombres accesibles. En un Flutter CanvasKit, la capa `flt-semantics` puede no exponerse o algunos controles tener otros nombres. **Si falla, es un diagnóstico del gate, no licencia para sustituir clics por fetch de escritura ni modificar el servidor para forzar PASS**. Se ha comprobado sintaxis JavaScript por parser V8; no existe todavía ejecución real del usuario.

## Termius: una sola ejecución

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d2e_browser_gui_isolated.sh
bash scripts/main_d2e_browser_gui_isolated.sh
echo "D2E_SHELL_RESULT=$?"
```

Marcadores objetivo **no observados**:

```text
D2E_AUTH_FIXTURE=PASS
D2E_BROWSER_SYNTHETIC_LOGIN=PASS
D2E_FLUTTER_SEMANTICS_ENABLED=PASS
D2E_GUI_SYNTHETIC_RENEWAL_VISIBLE=PASS
D2E_GUI_EDIT_CLICK=PASS
D2E_GUI_NOTES_TYPED=PASS
D2E_GUI_SAVE_CLICK=PASS
D2E_GUI_TO_DJANGO_PG17_PERSISTENCE=PASS
D2E_REAL_GUI_END_TO_END_GATE=PASS
D2E_CHROMIUM_RENDER_GATE=PASS
D2E_WEB_RECOVERY_RESTART=PASS
D2E_CHROMIUM_AFTER_WEB_RESTART=PASS
D2E_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS
D2E_DEV_CONTAINERS_UNCHANGED=OK
D2E_EPHEMERAL_CLEANUP=DONE
D2E_RESULT=0
```

Ante fallo recopilar `D2E_GUI_FAILURE_STAGE` y `D2E_GUI_PAGE_ERROR_COUNT`. No se imprime contenido de formularios, IDs, contraseñas, cookies ni URLs privadas; el script tampoco guarda capturas. La comprobación final de persistencia observa notas exclusivamente ficticias de laboratorio.

## Progreso

- **Tramo anterior D1-Z→D2-D: 5/5 PASS (100 % de ese tramo).**
- **Nuevo gate D2-E: 0/1 PASS**, preparado pero no ejecutado.
- **Progreso total del producto VENCIRA: no cuantificable de manera fiable a partir de gates.**

Restricciones permanentes: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2E_RELEASE_AUTHORIZED=NO`, `D2E_DEPLOY_EXECUTED=NO`, `D2E_LIVE_MIGRATIONS_EXECUTED=NO`, `D2E_LIVE_RESTORE_EXECUTED=NO`. No se autoriza producción ni migración DEV.


## Primer ensayo del operador: D2-E FAIL en etapa FLUTTER (11/11/2026)

Registro real aportado: `D2E_RESULT=8`, `D2E_CHROMIUM_RENDER_GATE=FAIL`, `D2E_GUI_FAILURE_STAGE=FLUTTER`, `D2E_GUI_PAGE_ERROR_COUNT=0`. Preflight y entorno PASS: `D2E_DEV_IDENTITY=PASS`, `D2E_INTERNAL_NETWORK=PASS`, `D2E_PG17_TMPFS=PASS`, `D2E_CANDIDATE_IMAGE=PASS`, `D2E_SYNTHETIC_MIGRATIONS=PASS`, `D2E_AUTH_FIXTURE=PASS`, `D2E_FLUTTER_RELEASE_BUILD=PASS`, `D2E_LOCAL_CANVASKIT_BUNDLED=PASS`, `D2E_CADDY_TLS_HTTP_CONTRACT=PASS`, `D2E_CSRF_SECURE_COOKIE=PASS`, `D2E_UNTRUSTED_CA_DENIED=PASS`, `D2E_CHROMIUM_SMOKE_SYNTAX=PASS`, `D2E_BROWSER_SYNTHETIC_LOGIN=PASS`. `D2E_DEV_CONTAINERS_UNCHANGED=OK`, `D2E_EPHEMERAL_CLEANUP=DONE`. Ningún acceso persistente ni deploy.

La etapa anterior `FLUTTER` agrupaba tres procesos: `flutter-view` adjunto, activación de `flt-semantics-placeholder` y árbol semántico. El fallo no permite distinguir ausencia del árbol de accesibilidad de un timeout/clic no efectivo. **No hay prueba de que el motor Flutter haya fallado**, ni de defecto de datos.

**Commit `448d9528`** instrumenta etapas distintas `FLUTTER_VIEW`, `ACCESSIBILITY_DISCOVERY`, `ACCESSIBILITY_ENABLE`, `ACCESSIBILITY_TREE`; registra solo booleanos y contadores estructurales (presencia de `shadowRoot`, `flt-semantics-placeholder`, `flt-semantics`, `flt-semantics-host`), clic real sobre el control cuando existe, y clase de error `TIMEOUT/ASSERTION_OR_RUNTIME/OTHER`. Se admite como requisito de árbol alguno de `flt-semantics` o `flt-semantics-host` (ambos son nodos del motor Flutter), sin saltar controles ni realizar escrituras por API para forzar éxito. Sintaxis V8 verificada. **D2-E sigue FAIL / pendiente de reejecución real; no se ha modificado la aplicación ni relajado la obligación de clic GUI.**

Comando de retest:
```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash scripts/main_d2e_browser_gui_isolated.sh
echo "D2E_SHELL_RESULT=$?"
```


## Segundo ensayo: control de accesibilidad presente, clic ordinario agota timeout

El operador confirmó de nuevo `D2E_RESULT=8`, `D2E_GUI_FAILURE_STAGE=ACCESSIBILITY_ENABLE`, `D2E_GUI_FAILURE_TYPE=TIMEOUT`, `D2E_GUI_PAGE_ERROR_COUNT=0`. `D2E_FLUTTER_VIEW_ATTACHED=PASS`, `D2E_FLUTTER_SHADOW_ROOT=NO`, `D2E_FLUTTER_PLACEHOLDER_COUNT=1`, `D2E_FLUTTER_SEMANTICS_COUNT_BEFORE=0`, `D2E_FLUTTER_SEMANTICS_HOST_COUNT=2`, `D2E_FLUTTER_PLACEHOLDER_FOUND=YES`. Todos los controles de laboratorio/backend/TLS/login PASS, contenedores DEV intactos y cleanup DONE. **No se puede afirmar aún que Flutter Web tenga árbol accesible operativo**; solo se localizaron nodos estructurales. No se inició ninguna edición.

El commit `4155896f` añade diagnóstico de geometría/visibilidad del placeholder sin registrar DOM ni datos sensibles. Si el elemento tiene geometría positiva y está dentro de la ventana, utiliza `Playwright locator.click({force:true})`, que sigue emitiendo **un evento de puntero de navegador real** sin inyectar `dispatchEvent`, alterar estilos ni efectuar escrituras por API. Si su geometría impide clic, lo registra como `NOT_POSSIBLE` y mantiene obligatoria la detección posterior de contenido real de semántica de la anotación, por lo que no puede emitir PASS basándose solo en un host vacío. El marker `D2E_FLUTTER_SEMANTICS_CONTAINER_ATTACHED=PASS` distingue la mera existencia estructural del contenedor del éxito end-to-end, que solo llega tras editar desde GUI y verificar persistencia en PG17. Sintaxis V8 PASS; **tercer ensayo pendiente del operador**. Sin cambio del código Flutter ni relajación de requisitos del gate.

Nuevo comando: actualizar `origin/main` con `git fetch`, merge `--ff-only`, luego `bash scripts/main_d2e_browser_gui_isolated.sh`. Se mantiene `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Tercer ensayo: control de accesibilidad deliberadamente fuera de pantalla; bootstrap corregido

El tercer ensayo terminó `D2E_RESULT=8`, `D2E_GUI_FAILURE_STAGE=DASHBOARD_LIST`, `D2E_GUI_FAILURE_TYPE=TIMEOUT`, `D2E_GUI_PAGE_ERROR_COUNT=0`, con `D2E_FLUTTER_VIEW_ATTACHED=PASS`, `D2E_FLUTTER_PLACEHOLDER_COUNT=1`, `D2E_FLUTTER_SEMANTICS_HOST_COUNT=2`, `D2E_PLACEHOLDER_GEOMETRY=NONZERO`, `D2E_PLACEHOLDER_IN_VIEWPORT=NO`, `D2E_PLACEHOLDER_DISPLAY_NONE=NO`, `D2E_PLACEHOLDER_VISIBILITY_HIDDEN=NO`, `D2E_PLACEHOLDER_POINTER_EVENTS_NONE=NO`, `D2E_PLACEHOLDER_OPACITY_ZERO=NO`, `D2E_FLUTTER_PLACEHOLDER_POINTER_CLICK=NOT_POSSIBLE`. La mera existencia de `flt-semantics-host` no implica que la accesibilidad esté activa ni que haya contenido accesible. DEV intacto y cleanup DONE.

La documentación oficial Flutter *Web accessibility* confirma que el modo semántico es opt-in mediante un botón invisible `aria-label="Enable accessibility"`. El blog técnico de Flutter documenta expresamente el placeholder `flt-semantics-placeholder` como elemento `1×1` posicionado en `(-1,-1)`, que no es alcanzable mediante un clic físico normal. Referencias: https://docs.flutter.dev/ui/accessibility/web-accessibility ; https://flutter.dev/blog/accessibility-in-flutter-on-the-web . Por tanto, el intento anterior de Playwright no era una comprobación válida de accesibilidad activada.

**Commit `939e3f95`**: solo en el test de laboratorio, cuando el placeholder de Flutter está fuera de la ventana, ejecutar el método nativo `HTMLElement.click()` de **ese botón de activación**, nunca de los controles de negocio. Para un placeholder visible, continuar usando el puntero normal. Después sigue siendo obligatorio encontrar semántica de anotación y completar edición de notas y guardado con **gestos reales Chromium** y verificar el dato persistido en PG17 por GET. Se introduce marcador `D2E_ACCESSIBILITY_HIDDEN_BUTTON_ACTIVATED=PASS` o `D2E_ACCESSIBILITY_POINTER_ACTIVATED=PASS`, además de `D2E_ACCESSIBILITY_BOOTSTRAP_ONLY=YES`, evitando confundir esta activación instrumental con una edición GUI validada.

**Estado: D2-E todavía NO PASS, pendiente de nuevo ensayo real con ese bootstrap.** No se han alterado Flutter, Django ni configuración de producción y se mantienen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Cuarto ensayo — Activación accesibilidad PASS; pantalla inicial no era necesariamente dashboard

El operador confirmó `D2E_ACCESSIBILITY_HIDDEN_BUTTON_ACTIVATED=PASS` y `D2E_FLUTTER_SEMANTICS_CONTAINER_ATTACHED=PASS` tras cargar `flutter-view`, pero `D2E_GUI_FAILURE_STAGE=DASHBOARD_LIST`, `D2E_GUI_FAILURE_TYPE=TIMEOUT`, `D2E_GUI_PAGE_ERROR_COUNT=0`, `D2E_RESULT=8`. La identidad de DEV continuó intacta y la limpieza se completó.

**Causa probable identificada en código:** en `clients/flutter/lib/ui/dashboard_screen.dart`, `_loadWorkspaces` (líneas aprox. 195–202) abre la agenda de **HOY automáticamente** cuando `openTodayOnLoad` está habilitado y se autentica una cuenta con un solo workspace. La fixture de D2-E crea exactamente un workspace. El test anterior asumía erróneamente que el texto del vencimiento ficticio (fecha 2027-05-31) aparecería directamente en el dashboard. El error `DASHBOARD_LIST` es por tanto consistente con estar en la agenda de hoy, pero aún requiere validación de Chromium: no inventar PASS.

Los commits `86566e7e` y `2e6736e8` incorporan reconocimiento de título Agenda o botón real de Volver y, si la agenda está abierta, **clic de Playwright en el botón Flutter de navegación** para volver al dashboard antes de exigir texto del vencimiento. El test comprueba texto DOM o `aria-label` del árbol `flt-semantics` y, si sigue sin encontrarlo, emite solo recuentos no sensibles de nodos accesibles, etiquetas y botones para un diagnóstico posterior, sin registrar datos de clientes. Las escrituras siguen exigiendo mouse/teclado reales sobre Flutter Web y POST/PATCH API directos siguen prohibidos. La activación del botón oculto del framework es la única excepción técnica.

**D2-E sigue FAIL/pending retest** hasta que se demuestre el flujo GUI→Django→PG17 y `D2E_RESULT=0`. Restricciones intactas: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Quinto ensayo (11/11/2026) — Flutter tiene nodos semánticos pero el vencimiento no se localiza

El operador confirma `D2E_RESULT=8`, `D2E_GUI_FAILURE_STAGE=DASHBOARD_LIST`, `D2E_GUI_FAILURE_TYPE=ASSERTION_OR_RUNTIME`, `D2E_GUI_PAGE_ERROR_COUNT=0`. Login real, `flutter-view`, activación del botón oculto y contenedor de semántica PASS; `D2E_INITIAL_AGENDA_TEXT_VISIBLE=NO`, `D2E_INITIAL_BACK_BUTTON_COUNT=0`, `D2E_DASHBOARD_SEMANTICS_COUNT=44`, `D2E_DASHBOARD_LABELED_COUNT=2`, `D2E_DASHBOARD_ROLE_BUTTON_COUNT=20`, `D2E_DASHBOARD_AGENDA_LABEL_PRESENT=NO`. DEV intacto y limpieza DONE.

**Lectura crítica:** no puede atribuirse aún el problema a agenda autoabierta, como se sospechó en la fase anterior: el botón Volver y título Agenda no fueron detectados. Tampoco implica ausencia del vencimiento en la DB. La escasez de atributos `aria-label` obliga a revisar cómo CanvasKit publica los textos, los roles y el árbol de accesibilidad. `getByText(..., exact:true)` puede no ser un selector correcto para este entorno.

Commit `29446299` instrumenta el caso de fallo sin modificar la aplicación ni simular acciones. Dentro del contexto Chromium, una consulta **solo GET** a `workspaces` y `renewals?q=D2E-EDIT` clasifica si la fixture está visible por la API; los contadores DOM identifican coincidencia con texto sintético en `textContent`, `aria-label` y `flt-semantics-label` y existencia de roles; consulta CDP `Accessibility.getFullAXTree` y emite únicamente número de nodos y presencia booleana del nombre de fixture y del botón Volver. No escribe por API, no revela bodies, cookies, URL privadas, datos de clientes ni el árbol AX. La etapa continúa **FAIL** hasta comprobar navegación y escritura con gestos GUI reales. Sintaxis V8 verificada; reejecución local pendiente.

Se mantiene el cierre de los cinco gates anteriores, `D2E_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Sexto ensayo (11/11/2026) — GUI Flutter real completa hasta Guardar, pero sin persistencia

Operador reporta `D2E_RESULT=8` con `D2E_GUI_RETURN_FROM_AGENDA=PASS`, `D2E_GUI_SYNTHETIC_RENEWAL_VISIBLE=PASS`, `D2E_GUI_EDIT_CLICK=PASS`, `D2E_GUI_NOTES_TYPED=PASS`, `D2E_GUI_SAVE_CLICK=PASS`. La lectura posterior `GET` de la renovación ficticia no confirmó las notas nuevas: `D2E_GUI_FAILURE_STAGE=NOT_PERSISTED`. No hay errores JS (`D2E_GUI_PAGE_ERROR_COUNT=0`), y el laboratorio terminó `D2E_DEV_CONTAINERS_UNCHANGED=OK`, `D2E_EPHEMERAL_CLEANUP=DONE`. No se autoriza a marcar E2E PASS: un clic en Guardar no certifica que Django aceptase el PATCH.

Revisión de Flutter: `dashboard_screen.dart::_editRenewal` llama a `_api.updateRenewal(...)` y atrapa genéricamente cualquier excepción mostrando `saveError`; `vencira_api.dart::_write` obtiene CSRF y realiza HTTP PATCH, exige 200. El fallo puede provenir de petición ausente, respuesta 4xx/5xx, error cliente previo a PATCH o UI en estado no guardado; la causa concreta sigue sin observarse.

**Commit `c7526af7`** añade observación pasiva de **metadatos** de las respuestas PATCH originadas por Flutter dentro de Playwright (método, código HTTP y cuenta), además de contar el control Guardar antes/después del clic, sin almacenar bodies, URLs con UUID, cookies ni credenciales. La prueba permanece estricta y exige actualización real de notas y persistencia en PostgreSQL. Siguiente resultado a recopilar: `D2E_GUI_PATCH_COUNT`, `D2E_GUI_PATCH_STATUS`, `D2E_GUI_EDITOR_STILL_OPEN`, `D2E_GUI_FAILURE_STAGE`, `D2E_RESULT`. Código JS parseado con V8; nuevo ensayo VPS pendiente. Sin modificar código productivo.

Se mantienen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` y cinco gates previos PASS.
