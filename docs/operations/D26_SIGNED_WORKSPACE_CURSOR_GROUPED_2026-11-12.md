# D26 — Cursor firmado por workspace, PG17 y Flutter HTTPS real (12/11/2026)

**Rama:** `main`. **Estado:** implementación publicada; validación VPS pendiente.

## Objetivo

D25 validó TLS real entre Flutter y Django para el lector móvil paginado por `offset`, con PG17 aislado. La limitación detectada es que los cambios de `expires_on` o `status` entre páginas pueden modificar el orden y provocar duplicados u omisiones. D26 añade un **lector separado de laboratorio** que pagina por la pareja inmutable `Renewal.created_at, Renewal.id`, con un cursor firmado de quince minutos, ligado al usuario, workspace y fecha de corte. La autorización se recalcula en cada solicitud. Se mantiene el endpoint `offset` anterior para no alterar las regresiones D24/D25.

## Cambios en main

- `backend/native_mobile_service/native_workspace_cursor.py` (commits `b8781e92`, `45e8edf8`): SQL keyset con `select_for_update`, `Q(created_at__gt=...) | Q(created_at=..., id__gt=...)`, 50 registros, límite temporal en la creación inicial, firma Django por salt distinto, caducidad de 900 segundos, validación de usuario y workspace, denegación uniforme. La proyección es únicamente identificador/fecha/estado.
- `backend/native_mobile_service/test_d22_http_views.py` (`28431c4c`, `57140047`) y URLconf `test_d22_urls.py` (`1be35bf5`): ruta nueva **exclusivamente interna y de laboratorio** `/api/v1/mobile/workspaces/<uuid>/renewals/cursor/`. Requiere HTTPS, bearer, candados SQL usuario→dispositivo→membresía→filas, segunda validación del bearer dentro de transacción, rechazo de parámetros no previstos, y respuesta no-store. No se modifica `backend/config/urls.py`.
- `backend/native_mobile_service/test_d26_workspace_cursor_pg17.py` (`a632590a`): cuatro tests PostgreSQL 17 desechable que verifican 75 filas en dos páginas con cambios de fechas/estado e inserción posterior al corte, cursor manipulado/ajeno/caducado, eliminación de membresía antes de segunda página, entrada inválida y ausencia de ruta operativa.
- `clients/flutter/lib/api/native_api_transport.dart` (`737b4eae`): admite parámetro tipado `cursor` solo para esta ruta; mantiene prohibición de `?` en rutas arbitrarias y permite solo caracteres URL seguros, longitud acotada, sin alterar el control de sesión.
- `clients/flutter/lib/api/native_workspace_cursor_read_port.dart` (`1df38707`): nuevo port tipado con `nextCursor` y validación estricta del JSON. No está conectado a `main.dart`.
- `clients/flutter/test/native_d26_workspace_cursor_test.dart` (`06136f59`, `eb97f577`): rechazo cliente de cursores falsos, rutas externas y campos PII, además del flujo de dos páginas.
- `scripts/native_i8k_recovery_http_pg17_isolated.sh` (`617d8699`): incorpora tests D26 a la regresión PG17 de D20–D24.
- `clients/flutter/test/native_d25_workspace_real_https_pg17_test.dart` (`5adada58`): ejecuta **también** dos páginas D26 a través del mismo socket TLS verificado, comprobando 50+25 UUID únicos, antes de comprobar la denegación de workspace ajeno.
- `scripts/main_d25_native_workspace_real_https_pg17_isolated.sh` (`a65f90f0`): añade `flutter analyze` y tests del port D26 en el mismo laboratorio HTTPS con CA sintética, servidor efímero y PostgreSQL 17. No expone puertos.
- `scripts/main_d26_signed_workspace_cursor_grouped_gate.sh` (`0ccb2108`): un solo gate de `main` limpio, sintaxis AST sin escribir pycache, D18 release fence, regresión PG17 y cliente Flutter por HTTPS real.

## Una ejecución en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d26_signed_workspace_cursor_grouped_gate.sh
echo "D26_SYNTAX=$?"
sudo -v
bash scripts/main_d26_signed_workspace_cursor_grouped_gate.sh
echo "D26_SHELL_RESULT=$?"
git status --short
```

### Marcadores exigidos, todavía NO observados

```text
D26_MAIN_CLEAN=PASS
D26_PYTHON_AST=PASS
D26_RELEASE_FENCE=PASS
D26_CURSOR_STABLE_UNDER_DATE_STATUS_AND_INSERTS_PG17=PASS
D26_CURSOR_TAMPER_TENANT_AND_EXPIRY_DENIED=PASS
D26_CURSOR_MEMBERSHIP_RECHECK=PASS
D26_CURSOR_INPUT_AND_PUBLIC_ROUTE_FENCED=PASS
NATIVE_I8K_D26_SIGNED_WORKSPACE_CURSOR_PG17=PASS
NATIVE_I8K_LOCAL_RESULT=0
D26_CURSOR_PG17_SECURITY=PASS
D25_TLS_UNTRUSTED_CA_AND_HOST_MISMATCH_DENIED=PASS
D26_REAL_TLS_SIGNED_CURSOR_PAGINATION_75=PASS
D26_REAL_FLUTTER_TLS_CURSOR_AND_CONTRACT=PASS
D25_DEV_CONTAINERS_UNCHANGED=OK
D25_BOUNDARY_RESULT=0
D26_CURSOR_REAL_TLS_FLUTTER=PASS
D26_PUBLIC_CURSOR_ENDPOINT_ENABLED=NO
D26_AUTH_PRODUCTION_ENABLED=NO
D26_RESULT=0
D26_SHELL_RESULT=0
```

**No anunciar D26 PASS antes de recibir estos resultados del VPS.**

## Garantías y límites

El orden `created_at,id` no cambia cuando se modifican fechas de vencimiento, estado o detalles: la página 2 retoma después del último `created_at,id` de la página 1. El corte evita mostrar renovaciones insertadas después de iniciar la paginación. La firma evita manipulación o transferencia del cursor entre usuario/workspace; el plazo de 15 minutos reduce su vigencia. El cursor NO otorga permisos: cada página revalida token, membresía y asignación.

**No es una fotografía transaccional completa** de todas las renovaciones: si un usuario pierde o recibe asignaciones durante el recorrido, las filas visibles pueden variar; una reasignación tardía de una fila con clave anterior al cursor no la vuelve a incluir. La eliminación de registros, cambios de rol y revocación de bearer también alteran legítimamente las respuestas. Para una visión histórica inmutable sería necesario un snapshot materializado o sesión de lectura específica con límites de almacenamiento. No confundir este cursor con dicho snapshot.

No se conecta Android real, no se habilitan rutas públicas, no hay escritura ni adjuntos y no se migra ni despliega el servicio. Los certificados y secretos son exclusivos del laboratorio. Controles: `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Revisión previa al primer gate (12/11/2026)

Antes de entregar el gate se corrigió la prueba de expiración para que la denegación sea demostrada **en el decodificador firmado de cursores**, independientemente del TTL del bearer (`3c46d5b3`). El runner HTTPS compartido se ajustó a un único `flutter analyze` de todo el cliente en lugar de pasar dos archivos posicionales, cuya aceptación por la CLI no estaba garantizada (`eee1df39`). Estas modificaciones están en `main` pero su resultado **todavía no está verificado** en el VPS.

## Primer gate D26 — FAIL por longitud de claves sintéticas G5 (12/11/2026)

La ejecución del VPS confirma `D26_MAIN_CLEAN=PASS`, `D26_PYTHON_AST=PASS`, `D26_RELEASE_FENCE=PASS`, PG17 temporal y paridad de migraciones PASS, **83 tests, 4 errores**. Todos pertenecen a `D26SignedCursorPG17Tests.setUp`, antes de probar cursor alguno. `g5_audit._key` rechaza la clave candidata al exigir `len(VENCIRA_G5_AUDIT_KEY) >= 32`; el fixture D26 la había definido corta (`d26-isolated-audit-key`). `begin_native_password` transforma el fallo de auditoría en `CandidateAdmissionDenied`, como corresponde a un sistema fail-closed. El fallo es del **fixture de pruebas**, no evidencia de acceso no autorizado ni de un defecto del cursor.

Marcadores registrados: `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK`, `NATIVE_I8K_LOCAL_RESULT=1`, `D26_CURSOR_PG17_SECURITY=FAIL`, `D26_RESULT=4`; la etapa Flutter/TLS no llegó a ejecutarse.

**Corrección en main, commit `3a0c5dcf`**: ambas claves sintéticas de `@override_settings` (AUDIT y ABUSE) son ahora cadenas de 37 caracteres que superan el mínimo G5. No se modifican los validadores G5, las claves reales, ni el código operacional. **D26 continúa pendiente** de ejecutar de nuevo el gate completo; no declarar PASS por esta corrección sin pruebas.

## Segundo ensayo VPS — ENOSPC en compilador Flutter; falso positivo del gate (12/11/2026)

La salida aportada contiene `D25_ANALYZE=PASS`, `D25_SERVER_ISSUED_SYNTHETIC_FIXTURE=PASS` y marcadores internos `D26_REAL_TLS_SIGNED_CURSOR_PAGINATION_75=PASS`, pero **NO constituye una ejecución correcta**. El compilador de `flutter test` no pudo copiar `output.dill` a `listener.dart.dill` dentro de `/tmp/flutter_tools...`: `FileSystemException: No space left on device, errno=28`. El runner informó una prueba fallida (`+0 -1 [E]`) y posteriormente se aprecia `^C`. A pesar de ello aparecieron `D26_REAL_FLUTTER_TLS_CURSOR_AND_CONTRACT=PASS`, `D25_BOUNDARY_RESULT=0`, `D26_RESULT=0`, que son **falsos positivos** frente a la evidencia del compilador. **D26 está BLOQUEADA / NO PASS**; los marcadores finales de este ensayo se descartan.

**Correcciones en main**:
- `de59e006`: reemplaza el `--tmpfs /tmp:rw,size=128m` del cliente Flutter por un **volumen Docker temporal dedicado** `$tag-scratch`, verifica al menos 1 GiB libre antes de iniciar las pruebas, recopila la salida con `tee` y exige simultáneamente código de salida cero, `All tests passed!`, ausencia de `[E]`, `Some tests failed`, `Failed to load`, `No space left on device` y presencia del marcador real `D26_REAL_TLS_SIGNED_CURSOR_PAGINATION_75=PASS`. La limpieza elimina el volumen y log temporal.
- `4e1ef3d8`: ajusta permisos 1777 del volumen temporal de forma aislada y gestiona señales INT/TERM como error, sin dar PASS si se interrumpe. El gate completo no modifica contenedores DEV ni rutas públicas.
- `94536543`: la envoltura D26 también termina con código no cero ante INT/TERM.

**Criterio actualizado para PASS:** observar `D26_FLUTTER_TEMP_CAPACITY=PASS`, `D26_FLUTTER_TEST_PROCESS=PASS`, `D26_FLUTTER_TEST_OUTPUT=PASS`, `D26_REAL_FLUTTER_TLS_CURSOR_AND_CONTRACT=PASS`, `D25_DEV_CONTAINERS_UNCHANGED=OK`, `D25_BOUNDARY_RESULT=0`, `D26_CURSOR_REAL_TLS_FLUTTER=PASS` y `D26_RESULT=0`, sin errores de compilación ni interrupciones. Los subgates PG17 deben mantenerse PASS. No se declara PASS hasta revalidar.

Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Reejecución VPS final — D26 PASS (12/11/2026)

Una vez corregido el volumen temporal del compilador y la validación de la salida, la nueva ejecución reporta:

```text
D25_ANALYZE=PASS
D25_SERVER_ISSUED_SYNTHETIC_FIXTURE=PASS
D26_FLUTTER_TEMP_CAPACITY=PASS
D25_TLS_UNTRUSTED_CA_AND_HOST_MISMATCH_DENIED=PASS
D25_REAL_TLS_WORKSPACE_PAGINATION_75=PASS
D26_REAL_TLS_SIGNED_CURSOR_PAGINATION_75=PASS
D25_REAL_TLS_CROSS_WORKSPACE_DENIED=PASS
00:00 +4: All tests passed!
D26_FLUTTER_TEST_PROCESS=PASS
D26_FLUTTER_TEST_OUTPUT=PASS
D26_REAL_FLUTTER_TLS_CURSOR_AND_CONTRACT=PASS
D25_REAL_TLS_NO_PUBLIC_PORTS=PASS
D25_OPERATIONAL_ROUTES_ENABLED=NO
D25_DEV_CONTAINERS_UNCHANGED=OK
D25_DEPLOY_EXECUTED=NO
D25_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D25_BOUNDARY_RESULT=0
D26_CURSOR_REAL_TLS_FLUTTER=PASS
D26_PUBLIC_CURSOR_ENDPOINT_ENABLED=NO
D26_AUTH_PRODUCTION_ENABLED=NO
D26_RESULT=0
```

**D26 PASS para el gate agrupado de laboratorio**: Flutter `analyze` terminó sin problemas; 4 pruebas (1 socket HTTPS real + 3 de contrato cursor) terminaron con `All tests passed!`; temporales Docker suficientes, sin ENOSPC, verificación de salida correcta; sin rutas operativas ni modificaciones DEV. Para llegar al tramo HTTPS, el script agrupado exige el subgate PG17 previo con salida cero; el recorte comunicado no incluye la cuenta final de tests Django ni `D26_SHELL_RESULT`, por lo que no deben atribuirse marcadores PG17 no observados literalmente.

Las líneas históricas de error/falso PASS anteriores se conservan como auditoría y **quedan superadas por esta reejecución**, no borradas. El cursor no materializa un snapshot y no garantiza que las reasignaciones intermedias sean invisibles. Sigue prohibido desplegar, habilitar issuer real o migrar LIVE.
