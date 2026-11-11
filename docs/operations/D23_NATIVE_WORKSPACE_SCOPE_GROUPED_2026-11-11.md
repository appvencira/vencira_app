# VENCIRA D23 — alcance nativo de renovaciones por workspace y asignación

**Fecha:** 11/11/2026. **Rama:** main. **Estado:** integrado; pendiente del gate VPS.

## Objetivo funcional

La fase D22 (70 tests PG17 OK) validó emisión, MFA, recuperación y HTTP candidato, pero dejó `D22_WORKSPACE_AUTHORIZATION_GATE=NOT_VERIFIED`. D23 incorpora la autorización que faltaba para la lectura mínima de renovaciones: el servidor comprueba el bearer móvil, la pertenencia actual al workspace, el rol vigente y la asignación vigente de cada anotación **en cada petición**. No confía en scopes guardados al iniciar sesión.

## Código publicado

- `backend/native_mobile_service/native_workspace_reader.py` (commit `626b7cc8`): consulta de solo lectura, máximo 50 filas, selecciona únicamente `id`, `expires_on`, `status`. Usuarios owner ven las anotaciones de su workspace (incluyendo sin asignar); usuarios member ven exclusivamente `assigned_to_id=user.pk`. No devuelve `customer_reference`, nombre, póliza, teléfono, notas, emails ni datos de otros workspaces. Ausencia de miembro/rol extraño/identidad incorrecta se deniega sin información de existencia.
- `backend/native_mobile_service/test_d22_http_views.py` (commit `5dd369ef`): nuevo `workspace_renewals` valida token con `validate_candidate_access` y ejecuta reader, **sin aceptar user_id ni permisos enviados por cliente**. Conserva las guardas del laboratorio D22: `VENCIRA_ENV=test`, app candidata, flag, URLconf aislado y `request.is_secure`, sin cookies/origin/referer. Rechazo uniforme y respuestas no-store.
- `backend/native_mobile_service/test_d22_urls.py` (commit `2b9c4fa5`): incorpora `/api/v1/mobile/workspaces/<uuid:workspace_id>/renewals/` exclusivamente a URLconf de test; `backend/config/urls.py` permanece intacto.
- `backend/native_mobile_service/test_d23_workspace_pg17.py` (commit `59f56974`): cuatro tests sobre PG17 de laboratorio: miembro solo ve asignados y proyección mínima, acceso cruzado/token corrupto/cookie denegados, cambios de asignación y membresía reflejados **sin relogin** con bearer sin cambiar, no registro de ruta en `config.urls`. Los tests crean dos cuentas, dos workspaces y tres anotaciones sintéticas, sin clientes reales.
- `scripts/native_i8k_recovery_http_pg17_isolated.sh` (commit `78fc3148`): ejecuta también suite D23 con regresión D20–D22 y emite `NATIVE_I8K_D23_NATIVE_WORKSPACE_PG17=PASS` tras todos los tests.
- `scripts/main_d23_native_workspace_grouped_gate.sh` (commit `f15d6e12`): **un único gate** de Git limpio, ausencia de rutas operativas, PG17 efímero, seguridad de emisión y alcance de datos, sin deploy ni migraciones live.

## Una sola ejecución en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d23_native_workspace_grouped_gate.sh
echo "D23_SYNTAX=$?"
sudo -v
bash scripts/main_d23_native_workspace_grouped_gate.sh
echo "D23_SHELL_RESULT=$?"
git status --short
```

**Resultado esperado, no confirmado:**
```text
D23_MAIN_CLEAN=PASS
D23_OPERATIONAL_ROUTE_FENCE=PASS
D23_NATIVE_MEMBER_ASSIGNMENT_SCOPE=PASS
D23_NATIVE_CROSS_WORKSPACE_DENIED=PASS
D23_NATIVE_LIVE_MEMBERSHIP_AND_ASSIGNMENT_FENCE=PASS
D23_OPERATIONAL_WORKSPACE_ROUTE_ABSENT=PASS
NATIVE_I8K_D23_NATIVE_WORKSPACE_PG17=PASS
NATIVE_I8K_D22_SERVER_CUSTODY_HTTP_PG17=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D23_WORKSPACE_ASSIGNMENT_PG17=PASS
D23_OPERATIONAL_ISSUER_ENABLED=NO
D23_RESULT=0
D23_SHELL_RESULT=0
```

## Límites comprobables

D23 **no** habilita rutas públicas, no modifica API web ni esquema, no hace deploy, no introduce bearer operacional y no prueba permisos de escritura o adjuntos. El listado está intencionadamente limitado a 50 elementos sin paginación: antes de habilitar un cliente real, exigir paginación/filtros autorizados, pruebas de carreras con revocación concurrente, permisos por objeto en todo el conjunto de endpoints, control de topología reverse proxy y TLS real extremo a extremo contra este endpoint, además de key custody y validación Android.

El mecanismo es dinámico entre peticiones; **no** implica que una lectura en curso pueda deshacerse si cambian permisos exactamente durante la ejecución. Esa carrera necesita un gate de concurrencia posterior.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
`D23_NATIVE_ISSUER_RELEASE_AUTHORIZED=NO`
