#!/usr/bin/env bash
# Reconocimiento previo al despliegue macro A. SOLO lectura: no migra ni reinicia.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
echo "=== IDENTIDAD ==="
test "$(git branch --show-current)" = "integration/local-e2e-prep"
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
echo "COMMIT_ACTUAL=$(git rev-parse HEAD)"
echo "=== COMPOSE ==="
sudo docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml config --quiet
echo "COMPOSE=OK"
echo "=== CONTENEDORES ==="
for service in api db web_preview; do
  name="vencira_localcheck-$service-1"
  project="$(sudo docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  image="$(sudo docker inspect "$name" --format '{{.Image}}')"
  echo "$service PROJECT=$project HEALTH=$health IMAGE=$image"
  test "$project" = "vencira_localcheck"
  test "$health" = "healthy"
done
echo "=== MIGRACIONES DEV (SOLO LECTURA) ==="
sudo docker exec vencira_localcheck-api-1 python manage.py showmigrations reminders |
  grep -E '001[5-8]_' || true
echo "=== COPIAS O5 (SIN ACCEDER A CREDENCIALES) ==="
systemctl list-timers --all --no-pager |
  grep -Ei 'vencira|restic|backup' || true
echo "=== FIN ==="
echo "PREDEPLOY_INSPECCION=OK"
echo "SIN_DESPLIEGUE=1"
echo "SIN_MIGRACIONES=1"
echo "NO_CONFIRMA_BACKUP_RESTAURABLE=1"
