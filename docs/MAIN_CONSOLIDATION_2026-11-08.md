# VENCIRA — consolidación progresiva de main (08/11/2026)

## Estado verificado y alcance

Fuente de verdad: GitHub `appvencira/vencira_app`, rama `main`. Comparación `main...feature/m3-android-local-notifications` realizada el 08/11/2026: `diverged`, 3946 commits en el histórico candidato no incorporados por genealogía y 21 exclusivos de `main` en el momento de la consulta. Los recuentos de commits no equivalen a número de módulos ausentes.

No se ha hecho merge masivo, cambio de ref ni force-push. Ningún despliegue o migración persistente ha sido ordenado durante este lote.

## Integración directa de lote I8-L / seguridad

Se verificó contenido preexistente de `main` antes de cada modificación:

- `clients/flutter/lib/api/native_http_auth_port.dart`: la ruta `recoverPassword` podía transformar un JSON `authenticated` en `NativePasswordGranted` sin TOTP. Corregido en `main`, commit `15ea182d72d4180f08cac94ec70f15fa968b6676`. Ahora solamente puede devolver `NativePasswordMfaRequired` y rechaza la respuesta con tokens en esa ruta.
- `clients/flutter/lib/api/native_recovery_login_gateway.dart`: el gateway podía confirmar credenciales devueltas directamente por `recoverPassword`. Corregido en `main`, commit `a9bd1d88565d98642f4d2e7922ffd4eb75a8cf3d`. Solo la ruta `recoverMfa` puede llegar al método de confirmación de tokens. El cambio no altera `main.dart` ni `backend/config/urls.py`.
- `clients/flutter/test/native_i8l_http_recovery_integration_test.dart`: incorporado el fichero de seis pruebas históricas, commit `31c1617bea0a6fa78321537cf120fe64a058c05e`. Se verificó en `main` la existencia de módulos importados por ese fichero y de `http` y `flutter_test` en `pubspec.yaml`. No se ha ejecutado todavía el test en `main`.
- `README.md` actualizado para eliminar la descripción obsoleta de fase de arranque y distinguir laboratorios, GitHub y despliegue, commit `3b6ac5c066ecc8a4cc08e51ff8d8d5d782a1d6c4`.

En `main` falta `backend/native_mobile_service/candidate_recovery_issuer.py`. No deben conectarse endpoints de recovery ni declararse I8-K o I8-M integrados sobre esa base.

## Validación pendiente en la propia main

En un entorno de desarrollo de confianza con Flutter/Dart instalado:

```bash
git fetch origin main
git switch main
git pull --ff-only origin main
git status --short
cd clients/flutter
flutter pub get
flutter analyze
flutter test test/native_i8l_http_recovery_integration_test.dart
```

El operador debe confirmar que el árbol está limpio antes de ejecutar `git pull --ff-only`. El comando `flutter pub get` puede alterar el lockfile local; examinarlo, no sobreescribir ni descartarlo ciegamente. A continuación ejecutar la suite Flutter de regresión completa si el primer lote pasa. Registrar SHA exacto, resultado real, entorno y cualquier dependencia ausente.

En este chat no hay Flutter/Dart instalado para ejecutar los tests. La API GitHub no proporcionó estados ni ejecuciones Actions asociadas al commit del README. **No declarar PASS de tests, I8-M, Android o publicación**.

## Próximo lote

Reconciliar dependencias de `backend/native_mobile_service` con el código actual de `main` en incrementos autocontenidos. Revalidar cada bloque en PG17 desechable, sin usar DEV persistente. Tras cerrar la consolidación necesaria, abordar I8-M Flutter HTTPS (CA y hostname verificados) y recuperación física Android (Keystore, Termius). Los gates históricos I8-H–I8-L no sustituyen esos ensayos.

## Prohibiciones

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
DEPLOY_EXECUTED=NO
LIVE_MIGRATIONS_EXECUTED=NO
```

Las dos últimas líneas describen las acciones de **esta sesión**, no constituyen una medición independiente del estado del VPS.

## Evidencia del operador: gate I8-L sobre main — 08/11/2026

El operador verificó en el worktree independiente `~/vencira-main-check-20261108` el commit `d2015389`, con `git status --short` vacío antes de la ejecución. La prueba usó Docker `ghcr.io/cirruslabs/flutter:3.44.0` con copia temporal del cliente Flutter, `flutter pub get` en esa copia y test independiente; no se ejecutó contra backend ni dispositivo real.

Salida aportada por el operador:

```text
MAIN_I8L_PUB_GET=PASS
No issues found! (ran in 16.2s)
MAIN_I8L_ANALYZE_RESULT=0
00:00 +6: All tests passed!
MAIN_I8L_TEST_RESULT=0
MAIN_I8L_GATE=PASS
```

Las seis pruebas abarcan credencial huérfana, rechazo password-only hostil, respuesta MFA ambigua, fallo en escritura protegida, marcador de inicio corrupto y bloqueo después de reinicio. **I8-L Flutter en main = PASS en este alcance**, resultado reportado por el operador. No sustituye `flutter test` de toda la suite, gate backend PG17, I8-M HTTPS Flutter real ni recuperación en Android físico. No se verificó un segundo `git status` posterior al gate; el montaje del código fuente fue de solo lectura y el test utilizó una copia temporal.

No hubo autorización de release, despliegue ni migración persistente. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Lote de integración backend I8-B / I8-C / I8-J / I8-K (8 de noviembre de 2026)

Auditoría específica de `main`: el paquete `backend/native_mobile_service` ya contenía modelos y persistencia de sesiones candidatos, `g14_admission`, `g5_audit`, controles de abuso y migraciones `0001`–`0004`. No se sustituyeron esos archivos ni se hizo un merge de todo el árbol. La política existente en `backend/config/settings.py` solo registra el paquete con `VENCIRA_ENV=test` y `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`; no se modificó `backend/config/urls.py` ni `clients/flutter/lib/main.dart`.

Archivos agregados a `main` en lotes:

- `candidate_challenge_wire.py` y `test_candidate_challenge_wire.py`: formato canónico `lc1` y prueba unitaria de rechazo seguro.
- `models.py`: **únicamente se añadió** `MobilePendingChallenge`; se verificó que el modelo histórico era una extensión exacta del contenido anterior de main. Migración `0005_mobilependingchallenge.py` agregada, **no aplicada**.
- `candidate_challenge_store.py`, `candidate_two_step_issuer.py`, `candidate_recovery_issuer.py`: flujo candidato desafío, contraseña/TOTP y recuperación MFA atómica; solo laboratorio, sin endpoints operativos.
- Tests `test_i8b_pending_challenge_pg17.py`, `test_i8c_two_stage_pg17.py`, `test_i8i_non_mfa_recovery_policy_pg17.py`, `test_i8j_recovery_pg17.py`, `test_i8k_recovery_http_pg17.py`, `test_i8k_recovery_urls.py`, `test_i8k_recovery_views.py`, `test_i8d_http_views.py`, `test_i8d_urls.py`, `test_i8d_http_pg17.py`.
- `scripts/native_i8k_https_server.py`: servidor WSGI TLS destinado a red de laboratorio, con comprobaciones explícitas de entorno; **no ejecutado**.

**Importante:** la incorporación de `scripts/native_i8k_https_probe.py` fue bloqueada por una restricción de seguridad de la herramienta. Por tanto, el runner `scripts/native_i8k_real_https_pg17_isolated.sh` **no se publicó**, y no se debe intentar ejecutar un gate I8-K completo desde main hasta resolver documentalmente y revisar su implementación segura. No intentar eludir el bloqueo.

Estado: **código integrado en main, gates de backend sobre main pendientes**. Los PASS históricos de la rama de referencia siguen sin trasladarse automáticamente. No se han ejecutado migraciones ni despliegues durante las publicaciones GitHub. La disponibilidad de `sudo docker` en el VPS y un `main` worktree independiente permiten realizar pruebas aisladas una vez preparado un procedimiento verificable.

Próximo gate recomendado (solo en PostgreSQL17 desechable, sin servicios DEV conectados): primero comprobación de migraciones `--check --dry-run`, luego tests I8-B/C/I/J y contract HTTP JSON I8-K. Para HTTPS real I8-K e I8-M, revisar y completar un runner de laboratorio independiente, sin exponer puertos del host ni tocar BD persistente.
