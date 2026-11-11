#!/usr/bin/env bash
# D3-C: read-only local Caddy configuration + public DEV HTTPS preflight.
# Never reload/restart Caddy, never export configs/secrets, never deploy.
set -Eeuo pipefail
set +x
mark(){ printf 'D3C_%s=%s\n' "$1" "$2"; }
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
mark CONFIG_CHANGE_EXECUTED NO
mark RELOAD_EXECUTED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
for utility in curl caddy systemctl; do
  if ! command -v "$utility" >/dev/null 2>&1; then
    mark "MISSING_$(echo "$utility" | tr '[:lower:]' '[:upper:]')" YES
    mark REAL_CADDY_CONFIG_VERIFIED NO
    mark RESULT 2
    exit 2
  fi
done
if [[ "$(id -u)" == 0 ]]; then
  privileged(){ "$@"; }
else
  sudo -v
  privileged(){ sudo "$@"; }
fi
if [[ ! -f /etc/caddy/Caddyfile ]] && ! privileged test -f /etc/caddy/Caddyfile; then
  mark CADDYFILE_PRESENT NO
  mark REAL_CADDY_CONFIG_VERIFIED NO
  mark RESULT 2
  exit 2
fi
mark CADDYFILE_PRESENT YES
# No configuration contents or secret material are printed.
if ! privileged caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile \
     >/dev/null 2>&1; then
  mark CONFIG_SYNTAX FAIL
  mark REAL_CADDY_CONFIG_VERIFIED NO
  mark RESULT 3
  exit 3
fi
mark CONFIG_SYNTAX PASS
if systemctl is-active --quiet caddy; then
  mark SERVICE_ACTIVE PASS
else
  mark SERVICE_ACTIVE FAIL
  mark REAL_CADDY_CONFIG_VERIFIED NO
  mark RESULT 4
  exit 4
fi
# Validate the public TLS certificate and HTTP reachability without cookies,
# credentials, output bodies or a proxy-insecure -k flag.
status="$(curl --proto '=https' --tlsv1.2 --silent --show-error \
  --connect-timeout 8 --max-time 20 --output /dev/null \
  --write-out '%{http_code}' https://dev.vencira.es/ 2>/dev/null)" || {
  mark DEV_HTTPS_CERT_AND_CONNECT FAIL
  mark REAL_CADDY_CONFIG_VERIFIED NO
  mark RESULT 5
  exit 5
}
case "$status" in
  200|301|302|303|307|308) mark DEV_HTTPS_CERT_AND_CONNECT PASS;;
  *) mark DEV_HTTPS_HTTP_STATUS "$status"; mark DEV_HTTPS_CERT_AND_CONNECT FAIL; mark RESULT 5; exit 5;;
esac
mark REAL_CADDY_SYNTAX_AND_SERVICE_VERIFIED PASS
# Strictly limited to config validity, service status and HTTPS handshake:
# no prod-domain routing audit, backend authorization or rollout approval.
mark PRODUCTION_DOMAIN_ROUTING_VERIFIED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark RESULT 0
