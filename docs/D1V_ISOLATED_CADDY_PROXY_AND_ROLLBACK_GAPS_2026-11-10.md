# VENCIRA — D1-V: candidato tras Caddy en red interna y rollback sin ejecutar

Fecha: 10/11/2026. Rama única `main`. **Gate publicado, pendiente de validación Termius.**

## Objetivo y alcance

Se cierra la brecha principal de D1-U: allí el certificado era gestionado por un servidor WSGI Python y no por Caddy. En D1-V se crean **solo recursos efímeros**: red Docker `--internal`, base PostgreSQL 17 en tmpfs (sin montajes de DEV), imagen Django candidata construida desde `backend/`, Gunicorn y contenedor **Caddy 2.11.7**. Se genera una CA/certificado sintético localhost-lab limitado a `d1v-proxy`; el cliente Python, también aislado, consulta Caddy por HTTPS y Caddy hace `reverse_proxy` a Gunicorn.

No se expone ningún puerto al host; no se lee el registro de datos DEV ni se monta su volumen PostgreSQL, ni se reinicia Caddy operativo. Los IDs de los tres contenedores DEV se registran antes y se comparan tras limpieza. Ficheros temporales sintéticos bajo directorio 0700, borrados por `trap`.

## Comprobaciones implementadas

`scripts/main_d1v_caddy_candidate_isolated.sh` ejecuta el laboratorio y `scripts/main_d1v_caddy_candidate_probe.py` consulta exclusivamente la instancia Caddy interna. Comprueba: health y ready 200, página de login 200, CSRF GET 200 con cookie `vencira_csrftoken` marcada `Secure`, acceso anónimo a `me` denegado, ruta nativa candidata 404, POST sin CSRF denegado 403 y rechazo de CA desconocida. El probe nunca imprime respuestas, credenciales o cookies; comunica únicamente marcadores.

**Es Caddy real como software pero con un Caddyfile sintético de laboratorio, no la configuración efectiva de `dev.vencira.es`.** Sirve en la ruta raíz una respuesta estática de prueba deliberadamente etiquetada como tal, **NO la compilación Flutter**. Por tanto el gate demuestra la cadena TLS/reverse proxy/API y parte de la política de cookies y CSRF, pero no el frontend real ni la carga del fichero operativo de Caddy.

## Ejecución: una sola validación después de revisar

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d1v_caddy_candidate_isolated.sh
python3 - <<'PY'
import ast
from pathlib import Path
ast.parse(Path("scripts/main_d1v_caddy_candidate_probe.py").read_text())
print("D1V_PROBE_SOURCE_SYNTAX=PASS")
PY
bash scripts/main_d1v_caddy_candidate_isolated.sh
echo "D1V_SHELL_RESULT=$?"
```

No afirmar PASS hasta observar `D1V_PG17_TMPFS=PASS`, `D1V_SYNTHETIC_MIGRATIONS=PASS`, `D1V_NO_HOST_PORTS=PASS`, `D1V_CADDY_HTTPS_PROBE=PASS`, `D1V_CADDY_PROXY_CANDIDATE_LAB=PASS`, `D1V_DEV_CONTAINERS_UNCHANGED=OK`, `D1V_EPHEMERAL_CLEANUP=DONE`, `D1V_RESULT=0` y `D1V_SHELL_RESULT=0`. El primer ensayo puede descubrir bugs de laboratorio; corregirlos sin dar por válidos marcadores que no aparezcan.

Si falla, el ejecutor comunica si el error está en DB, build, migraciones, servicio, proxy o HTTP; ante fallo de probe se imprime la posición y código HTTP, nunca la respuesta.

## Rollback: plan de cierre, no certificado todavía

La base de datos DEV tiene **un volumen Docker persistente**. D1-N ya ejercitó un backup O5 real restaurado en PostgreSQL17 aislado y la marcha atrás del esquema 0019–0027, pero no una conmutación operativa de API, Web y Caddy con escrituras posteriores. D1-V **no ejecuta rollback** y no debe marcarlo PASS.

Antes de autorizar la primera promoción a DEV se exige:

1. Inventario confidencial y custodia de imágenes API/Web **anteriores** y candidatas, digests y manifiestos aplicados (no solo presentes), con verificación de su capacidad de recreación sin imágenes borradas.
2. Ensayo íntegro del artefacto Flutter web servido por Nginx/Caddy y login/CSRF navegador en un entorno aislado.
3. Runbook de parada de escrituras y decisión sobre RPO/RTO; si se requiriera restaurar la BD, especificar cómo evitar o gestionar pérdida de escrituras posteriores. Nunca realizar `down -v` ni tocar el volumen DEV en un ensayo.
4. Evidencias de recuperación aislada de API+Web+BD+proxy y de post-checks de salud antes de pedir autorización expresa.

## Seguridad

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```
