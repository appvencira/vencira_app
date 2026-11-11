# D2-C — CRUD de vencimientos y agenda en PostgreSQL aislado

Fecha: 2026-11-11. **Estado: PREPARADO; prueba real pendiente de ejecución local.**

## Objetivo y evidencia

Con usuario `owner` y workspace exclusivamente ficticios creados en PostgreSQL 17 `tmpfs`, abrir Chromium, iniciar sesión con el formulario Django y token CSRF y comprobar que Flutter monta `flutter-view`. Desde el mismo navegador autenticado, ejecutar las operaciones sobre la API del candidato:

1. POST `/api/v1/workspaces/{id}/renewals/` con cliente sintético, Entrada `clients`, fecha fija `2026-12-17` y referencia `D2C-TEST`; exigir HTTP 201 y UUID.
2. GET del detalle; exigir HTTP 200 y referencia exacta.
3. GET agenda `?day=2026-12-17`; exigir HTTP 200 y objeto `results[].renewal.id` correspondiente a esa póliza.
4. PATCH `notes` a valor sintético, exigir 200 y nueva lectura GET con persistencia.
5. GET historial de la misma renovación, exigir al menos eventos de creación y modificación.
6. Desde otro contexto Chromium sin cookies, negar listado de workspaces con HTTP 401/403.
7. Repetir el recorrido **después** de recrear únicamente el Nginx efímero y verificar un backup/restore sintético de esquema PG17, cleanup y que los tres contenedores DEV conservan identidad.

No se escriben datos reales. Las credenciales de prueba no se imprimen, no se guardan screenshots, y se usan solo en contenedores efímeros. Se mantienen red Docker `--internal`, cero puertos publicados, TLS de Caddy de laboratorio, rechazo de CA no confiable y CSRF seguro.

**Alcance honesto:** se comprueba el formulario de login mediante clic y el contrato de CRUD/agenda/auditoría mediante `fetch` desde el navegador autorizado. **No** se ha probado el clic completo de botones Flutter para crear/editar, ni agenda con widgets interactivos. No hay pruebas de aseguradoras, modalidades, adjuntos, MFA real, fuentes externas, fidelidad visual ni rollback operativo.

## Código publicado

- `scripts/main_d2c_browser_crud_isolated.sh` — orquestación, entorno, fixture, dos Chromium smoke y recuperación temporal
- `scripts/main_d2c_seed_synthetic.py` — usuario y workspace sintéticos
- `scripts/main_d2c_flutter_caddy_probe.py` — preflight HTTPS/CSRF
- `scripts/Dockerfile.d2c-playwright` — imagen Chromium
- `scripts/main_d2c_chromium_crud_smoke.js` — login real y CRUD/agenda/auditoría mediante navegador

Se inspeccionó el código de `RenewalSerializer`, `views.renewals`, `views.renewal_detail`, `views.agenda_day` y `views.renewal_history`; la respuesta de agenda contiene `results[].renewal` y el test se adaptó a esa forma. Sintaxis JavaScript verificada con V8. **No se ha ejecutado Docker ni validado el gate**.

## Ejecutar en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d2c_browser_crud_isolated.sh
bash scripts/main_d2c_browser_crud_isolated.sh
echo "D2C_SHELL_RESULT=$?"
```

Marcadores de éxito esperados, **no confirmados todavía**:

```text
D2C_AUTH_FIXTURE=PASS
D2C_BROWSER_SYNTHETIC_LOGIN=PASS
D2C_FLUTTER_AUTHENTICATED_VIEW=PASS
D2C_SYNTHETIC_RENEWAL_CREATE_201=PASS
D2C_SYNTHETIC_RENEWAL_DETAIL=PASS
D2C_SYNTHETIC_AGENDA_DAY_VISIBLE=PASS
D2C_SYNTHETIC_RENEWAL_PATCH_PERSISTED=PASS
D2C_SYNTHETIC_AUDIT_EVENTS=PASS
D2C_ANONYMOUS_WORKSPACE_DENIED=PASS
D2C_CHROMIUM_SYNTHETIC_CRUD_GATE=PASS
D2C_CHROMIUM_RENDER_GATE=PASS
D2C_WEB_RECOVERY_RESTART=PASS
D2C_CHROMIUM_AFTER_WEB_RESTART=PASS
D2C_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS
D2C_DEV_CONTAINERS_UNCHANGED=OK
D2C_EPHEMERAL_CLEANUP=DONE
D2C_CHROMIUM_SYNTHETIC_RENEWAL_AGENDA_AND_RECOVERY_GATE=PASS
D2C_RESULT=0
```

## Progreso del tramo de validación

- D1-Z: PASS — HTTPS Flutter Chromium y recuperación efímera.
- D2-A: PASS — píxeles escritorio/móvil y recuperación.
- D2-B: PASS — login Django/Flutter y persistencia de sesión sintética.
- D2-C: **PENDIENTE** — CRUD sintético, agenda y auditoría.

**3/4 gates cerrados = 75 % del tramo de validación D1-Z→D2-C, no 75 % del producto VENCIRA.** D2-C no cuenta como validado por tener scripts publicados.

Se mantienen: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2C_RELEASE_AUTHORIZED=NO`, `D2C_DEPLOY_EXECUTED=NO`, `D2C_LIVE_MIGRATIONS_EXECUTED=NO`, `D2C_LIVE_RESTORE_EXECUTED=NO`.
