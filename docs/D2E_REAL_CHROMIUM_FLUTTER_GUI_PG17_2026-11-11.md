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
