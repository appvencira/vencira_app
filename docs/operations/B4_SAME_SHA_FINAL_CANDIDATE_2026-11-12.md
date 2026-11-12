# B4 — Candidato único de VENCIRA: backend + Web + APK Android

Fecha: 12/11/2026. Solo `main`. Objetivo: **un único gate automático de cierre B4**, sin repetir D12–D15, I8-P, D27/D28 Android ni D4 histórico.

## Implementación

- `scripts/main_b4_same_sha_grouped_candidate_gate.sh`: comprueba rama `main`, SHA igual a `origin/main`, árbol limpio, scripts íntegros y barreras operativas; corre una sola suite backend PG17 aislada (`native_i8k_recovery_http_pg17_isolated.sh`) y una sola compilación Flutter Android+Web (`main_b4_android_web_same_sha_candidate_gate.sh`).
- Backend: pruebas Django de sesión, autorización y HTTP nativo en PostgreSQL 17 desechable. No se hacen migraciones sobre DEV/prod. El PASS corresponde a la suite del runner I8-K, no a una auditoría completa de todos los recorridos del producto.
- Flutter: `flutter pub get`, `flutter analyze`, **suite completa `flutter test`** y dos compilaciones consecutivas desde **`lib/main.dart` en el mismo contenedor**: APK Android debug y web release estático. Verifica integridad del ZIP APK y archivos web, genera SHA256 independientes.
- Artefactos en `/home/vencira/vencira-b4-candidate/<SHA>/`: `VENCIRA-main-candidate-debug.apk`, `apk.sha256`, carpeta `web/`, `web.sha256`. Carpeta privada y no se sobreescribe un candidato de ese SHA. No se publican ni firman APK de distribución.
- La fase de salida exige `B4_RESULT=0`, `B4_DJANGO_PG17_HTTP_SECURITY=PASS`, `B4_FLUTTER_WEB_ANDROID_BUILD=PASS`, `B4_SAME_SHA_REGRESSION=PASS`, `B4_DEV_CONTAINERS_UNCHANGED=OK`, `B4_SAME_SHA_ANDROID_AND_WEB=PASS`, `B4_APK_ZIP_INTEGRITY=PASS`, `B4_WEB_ARTIFACT_INTEGRITY=PASS` y `B4_WEB_SHA256_RECORDED=PASS`.

**Estado actual: código publicado, gate VPS todavía NO ejecutado.** B4 no queda cerrado por escribir el script.

## Única ejecución de validación

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
bash -n scripts/main_b4_same_sha_grouped_candidate_gate.sh
bash -n scripts/main_b4_android_web_same_sha_candidate_gate.sh
sudo -v
bash scripts/main_b4_same_sha_grouped_candidate_gate.sh
echo "B4_OPERATOR_RESULT=$?"
git status --short
```

**Si falla:** conservar primera fase `B4_FAILED_STAGE` y salida de la prueba que falló. No repetir todo ni eliminar manualmente datos DEV. Es posible que un test Flutter anteriormente omitido requiera adaptación; fallar no equivale a inseguridad de producción, pero tampoco permite marcar B4 PASS.

## Límites de este cierre automático

Una regresión automática limpia sobre el mismo commit **no sustituye** los recorridos visuales, permisos de usuario, contenido de calendarios y notas, comportamiento de adjuntos, notificaciones y la configuración HTTPS de la web publicada. Este runner produce una APK **debug** y una web estática **no desplegada**; no valida firma Android release, distribución, custodia productiva MFA, proxy/IP, DNS, Caddy, backups operativos ni autorización B5.

Después de B4, agrupar en **una única sesión funcional de APK real + web** los casos representativos y preparar un preflight B5 de solo lectura. Separar expresamente piloto DEV (requiere autorización propia) de producción (autorización posterior, no implícita).

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
B4_DEPLOY_EXECUTED=NO
B4_LIVE_MIGRATIONS_EXECUTED=NO
B4_LIVE_RESTORE_EXECUTED=NO
B4_PRODUCTION_RELEASE_AUTHORIZED=NO
```
