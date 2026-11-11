# VENCIRA D11 — infraestructura de producción segregada (candidato, NO desplegado)

Fecha: 11/11/2026. Rama única `main`.

## Propósito

Diseñar, sin activarlo, un entorno independiente del Compose `vencira_localcheck`. El proyecto candidato usa el nombre explícito `vencira_prod`; su red `prod_internal` es interna, PostgreSQL guarda datos en el nuevo volumen nombrado `vencira_prod_prod_pgdata` (nombre derivado de Compose: verificar en el VPS), sin publicar 5432; la API escucha por loopback `127.0.0.1:18741` y Web por `127.0.0.1:18742`. Estas direcciones corresponden al candidato Caddy D10. NUNCA apuntar la producción a los upstreams DEV 18731/18732.

Los tres roles exigen referencias de imágenes fijadas por digest y un `env_file` **externo** al repositorio; no se han generado ni recuperado secretos de producción. La imagen API histórica 0018 NO puede cumplir migraciones 0027 y no se debe sustituir por ella la candidata de `main`. El servicio `web` da por supuesto que el artefacto Nginx seleccionado escucha en el puerto 8080 y que conecta con hostname `api` (contrato validado previamente en D4-G, no verificado aún en un despliegue D11).

Archivos:
- `ops/production/compose.production.candidate.yaml`: Compose candidato sin acciones de ejecución ni imágenes predeterminadas.
- `ops/production/production.env.reference.txt`: contrato de variables sin valores operativos.
- `ops/caddy/vencira.es.Caddyfile.candidate`: Caddy separado, D10 PASS.
- `scripts/main_d11_production_compose_dryrun.py`: una única prueba sin efectos operativos.

## D11 — comprobación agrupada

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -B - <<'PY'
import ast
from pathlib import Path
ast.parse(Path("scripts/main_d11_production_compose_dryrun.py").read_text())
print("D11_SYNTAX=PASS")
PY
sudo -v
python3 -B scripts/main_d11_production_compose_dryrun.py
echo "D11_SHELL_RESULT=$?"
systemctl is-active docker
git status --short
```

El script verifica Git limpia, aislamiento textual, proyecto, imágenes exigidas, y ejecuta exclusivamente `docker compose config --format json` con entorno **sintético** en un directorio temporal 0700; analiza el objeto JSON para comprobar servicios, red interna, volumen PG y puertos loopback. No ejecuta `docker compose up`, `pull`, `build`, `run`, `migrate`, Caddy reload o DNS. Mide únicamente si observa listener en los puertos propuestos; una ausencia no significa que estén reservados.

Acreditar PASS solo ante `D11_COMPOSE_PARSE=PASS`, `D11_PRIVATE_NETWORK_ONLY=PASS`, `D11_PG17_NAMED_VOLUME_SEPARATE=PASS`, `D11_HOST_LOOPBACK_PORTS=PASS`, `D11_PRODUCTION_COMPOSE_CANDIDATE=PASS`, `D11_RESULT=0`, `D11_SHELL_RESULT=0`. Un resultado PASS es **gramatical/arquitectónico**, no recuperación ni autorización de producción.

## Riesgos por resolver antes de activar

La red exclusivamente interna puede afectar comunicaciones salientes como SMTP o notificaciones; se debe probar un diseño de egress controlado en laboratorio según las funciones de publicación reales, nunca abrir egress sin análisis. La verificación de puertos es observacional: no garantiza disponibilidad futura. `env_file` de producción debe mantenerse con permisos estrictos, fuera de Git y sin compartir credenciales de DEV. Los digests deben provenir de un build de `main` verificado y una custodia independiente. Comprobar además variables, persistencia de DB, migraciones reversibles, copia off-host de imágenes, recuperación O5 enlazada con ejecutable compatible, Android final, Caddy efectivo, TLS y cookies/CSRF.

**Fuera de alcance:** despliegue, migración de datos reales, levantamiento de contenedores, carga de imágenes, reconfiguración DNS y Caddy, o conmutación del dominio. Mantener:

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Resultado operativo D11 (11/11/2026)

El operador ejecutó la prueba sintética: `D11_MAIN_CLEAN=PASS`, `D11_DEV_ISOLATION=PASS`, `D11_SEPARATE_COMPOSE_PROJECT=PASS`, `D11_COMPOSE_PARSE=PASS`, `D11_PRIVATE_NETWORK_ONLY=PASS`, `D11_PG17_HOST_PORTS=NONE`, `D11_PG17_NAMED_VOLUME_SEPARATE=PASS`, `D11_HOST_LOOPBACK_PORTS=PASS`, `D11_PRODUCTION_COMPOSE_CANDIDATE=PASS`, `D11_PROPOSED_PORT_18741_NO_LISTENER_OBSERVED=YES`, `D11_PROPOSED_PORT_18742_NO_LISTENER_OBSERVED=YES`, `D11_PORTS_RESERVED=NO`, `D11_DEPLOY_AUTHORIZED=NO`, `D11_RESULT=0`, `D11_SHELL_RESULT=0`. Docker `active`; Git `status --short` vacío. Sin creación de secretos, contenedores, modificación Caddy/DNS, acceso a producción o migraciones.

**D11 PASS solo de validación del candidato Compose y aislamiento.** Los puertos no están reservados ni los servicios de producción levantados. Conservar las puertas restantes B1/B2/B3/B4 móvil/B5; no ejecutar `compose up` ni conectarlo a datos DEV.
