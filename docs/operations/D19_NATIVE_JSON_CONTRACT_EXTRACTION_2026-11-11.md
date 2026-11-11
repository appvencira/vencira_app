# VENCIRA D19 — Contrato JSON móvil independiente, reutilizable y cerrado

Fecha: 11/11/2026. Rama única `main`. **Código publicado; validación PG17 pendiente.**

## Objetivo y alcance

D18 superó el laboratorio de HTTPS/MFA y recuperación, confirmando que **no existe todavía un issuer nativo operacional autorizado**: `config.urls` no registra endpoints móviles de emisión y `VENCIRA_NATIVE_BEARER_ENABLED=False`. El paso D19 extrae del endpoint experimental la capa de protocolo JSON a un módulo de backend **no test**. Este componente es reutilizable por un futuro issuer revisado, pero **no emite tokens ni autentica sesiones**. El issuer completo permanece bloqueado.

## Implementación en main

- `backend/native_mobile_service/native_http_contract.py` (`7c12dc53`): define el límite máximo de 4096 bytes, lectura UTF-8 estricta, JSON objeto con **claves únicas** (no tolera duplicados), conjunto exacto de campos, valores de tipo `str`, rechazo de constantes no JSON como `NaN`/`Infinity` y respuestas uniformes sin cache/cookies. No contiene permisos, tokens ni rutas.
- `backend/native_mobile_service/test_i8d_http_views.py` (`41dc9e50`): los handlers LAB de password/MFA/refresh/revoke reutilizan esa capa, pero conservan su guardia `VENCIRA_ENV=test`, flag de candidato y URLconf de laboratorio. El contrato se endurece: entradas JSON con clave duplicada anteriormente podían aceptarse por semántica last-key-wins de `json.loads`; ahora se rechazan.
- `backend/native_mobile_service/test_native_http_contract.py` (`9c6a1275`): siete pruebas sin secretos ni datos persistentes, cubriendo JSON exacto, duplicados, tipos, contenido no JSON, tamaño máximo, cabeceras anti-cache y ausencia de cookies.
- `scripts/native_i8k_recovery_http_pg17_isolated.sh` (`e47f1234`): agrega esas pruebas a su gate existente de Django sobre PG17 desechable. El marcador `NATIVE_I8K_NATIVE_JSON_CONTRACT=PASS` solo aparece cuando toda la batería Django concluye sin errores.

**No se ha cambiado `backend/config/urls.py`, `backend/config/settings.py`, el emisor candidato, las tablas, las migraciones, las credenciales reales ni Flutter.** El módulo operativo no se carga en producción: forma parte del paquete candidato que solo se instala en test.

## Ejecutar una vez en VPS (D19)

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh
echo "D19_SYNTAX=$?"
sudo -v
bash scripts/native_i8k_recovery_http_pg17_isolated.sh
echo "D19_SHELL_RESULT=$?"
git status --short
```

Resultados requeridos:
```text
NATIVE_I8K_PG17_READY=OK
NATIVE_I8K_NATIVE_JSON_CONTRACT=PASS
NATIVE_I8K_NO_PUBLIC_ISSUER=PASS
NATIVE_I8K_RECOVERY_ENDPOINTS_ABSENT=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D19_SHELL_RESULT=0
```

Puede ejecutar un Docker build de laboratorio y un PG17 temporal en red interna, no crea una aplicación pública ni modifica la base operativa. No es necesario repetir D18 entero ni reconstruir APK.

## Pendiente de implementación operacional

Este paso **solo extrae el contrato**. Aún faltan, antes de conectar el acceso nativo: servicio de emisión con clave/identidad de confianza desde el servidor, verificación password y TOTP en transacciones PG17 con audit/abuse budget, recuperación atómica de dispositivos, credenciales protegidas con rotación, permisos workspace y DRF bearer restringido a vistas móviles, custodia de claves y migraciones operativas, pruebas negativas de red/almacenamiento y dispositivos Android reales, y habilitación autorizada fuera del entorno de prueba. Prohibido incluir `test_i8d_urls` o `test_i8k_recovery_urls` en `config.urls`.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
`D19_NATIVE_OPERATIONAL_ISSUER_ENABLED=NO`
`D19_RELEASE_AUTHORIZED=NO`
