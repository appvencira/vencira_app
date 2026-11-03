# VENCIRA — Handoff G5 en curso, 03/11/2026

**Rama:** `feature/m3-android-local-notifications` · **PR:** #17 (DRAFT). No usar `main` como origen de G5.

## Estado consolidado

> **Validación local confirmada por operador, 03/11/2026, lote `m3-http-contract-20261103T095043Z`:** `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_G4_PG17=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. El runner `--candidate` incluye G5; el sumario proporcionado no muestra por separado `G5_CANDIDATE_PG17_RESULT` ni el SHA exacto del checkout, así que no inventar el marcador aislado ni un recibo CI. Logs retenidos solo localmente en `/home/vencira/vencira-m3-results/m3-http-contract-20261103T095043Z`. Esta evidencia valida el **lote al que apuntaba el checkout del operador**, no commits posteriores. No autoriza release.


G4 anterior: 20/20 PG17 PASS sin deriva de esquema `0001` (evidencia local 03/11); G6 integral PASS **anterior a G4**. Esos resultados **no validan** estos nuevos commits G5. Para contexto base: [handoff G4→G5](HANDOFF_G4_G5_2026-11-03.md).

G5 publicado en GitHub, **con lote integral local satisfactorio comunicado para la revisión ejecutada; CI GitHub Actions sigue sin recibo confirmado**:

1. [Bloque 1](G5_MOBILE_SECURITY_MACROBLOCK_2026-11-03.md): atribución de IP y confianza de proxy de un salto estricto, aislada y sin llamada HTTP.
2. [Bloque 2](G5_MOBILE_THROTTLE_2026-11-03.md): cuotas candidatas compartidas en PG17 por cuenta e IP, HMAC del sujeto, migración 0002 solo test, pruebas de concurrencia, CI y runner efímero.
3. Gate estático N1 actualizado, runner `n1_identity_pg17_ephemeral.sh --candidate` incluye tests G4+G5 y emite `G4_CANDIDATE_PG17_RESULT` y `G5_CANDIDATE_PG17_RESULT`.

**No existe enlace operativo** entre esos mecanismos de G5 y las vistas de login. No hay auditoría completa, rotación de claves ni un emisor confiable. No deducir seguridad de producción.

## Invariantes bloqueados

```
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
GLOBAL_FREEZE=NOT_VERIFIED
```

- No despliegue, no migración de la base persistente, no merge de PR #17.
- `VENCIRA_NATIVE_SERVICE_CANDIDATE` sigue restringido a `VENCIRA_ENV=test`. `VENCIRA_NATIVE_BEARER_ENABLED=False` en settings; URLConfs operativos sin rutas móviles.
- Nunca subir llaves, dumps, credenciales, datos personales ni logs privados al repositorio público.

## Validación local ya comunicada y siguiente comprobación

En `/home/vencira/vencira-m3-localcheck`, comprobar el estado Git antes de fast-forward. Con checkout actualizado y entorno de Docker aislado:

```bash
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 scripts/n1_static_security_gate.py
bash scripts/m3_native_http_contract_batch.sh
```

El batch debe construir una nueva imagen, utilizar PG17 `tmpfs` y no conectar a la DB persistente. **No ejecutar si el script ha sido modificado localmente para apuntar al servidor real.** Recoger solamente indicadores de salida `M3_HTTP_STATIC`, `M3_HTTP_BUILD`, `M3_HTTP_PG17_LAB`, `M3_HTTP_G4_PG17`, `M3_HTTP_FLUTTER`, `M3_HTTP_RESULT`, `G5_CANDIDATE_PG17_RESULT` y código de salida del proceso. El segundo indicador se emite en el runner subordinado y podría no estar propagado al sumario principal.

## Siguientes decisiones de ingeniería

- Proteger frente a bloqueo malicioso por cuenta y denegación de servicio; validar procedencia real Caddy/Nginx e IPv6 y tratamiento de múltiples proxies.
- Establecer limpieza de buckets y retención RGPD.
- Eventos de auditoría mínimos y acceso a soporte, sin contraseñas ni tokens.
- Diseño real de claves HMAC por propósito, versionado, custodia externa y recuperación.
- Emisión password+MFA desde un verificador de confianza y tests de carrera/replay; ninguna vista pública antes de pasar gates.

**No marcar PASS, release o custodia real sin evidencia.** Esta nota es documental y no constituye prueba ejecutada.
