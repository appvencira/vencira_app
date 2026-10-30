#!/usr/bin/env bash
# Read-only preflight for a SEPARATE Ubuntu x86_64 MB1 synthetic recovery host.
set -Eeuo pipefail
phase=START
trap 'echo "MB1_HOST_PREFLIGHT_PHASE=$phase"; echo "MB1_HOST_PREFLIGHT=FAIL"' ERR
phase=OS
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo "REQUIRE_UBUNTU_X86_64"; exit 2; }
[ -r /etc/os-release ] && . /etc/os-release
[ "$ID" = ubuntu ] || { echo "REQUIRE_UBUNTU"; exit 2; }
case "$VERSION_ID" in 22.04|24.04|26.04) ;; *) echo "UBUNTU_VERSION_NOT_PREVALIDATED=$VERSION_ID"; exit 2;; esac
echo "MB1_HOST_UBUNTU_X86_64=OK"
phase=ISOLATION
# Must not run inside the VENCIRA source VPS or its worktree.
if [ -d /home/vencira/vencira-localcheck ] || [ -d /home/vencira/vencira-preview ] ||
   [ -e /etc/vencira-backup/config.env ] || [ -e /etc/caddy/Caddyfile ] && grep -qs 'dev.vencira.es' /etc/caddy/Caddyfile; then
  echo "MB1_HOST_SOURCE_SIGNATURE=REJECTED"; exit 2
fi
echo "MB1_HOST_SOURCE_SIGNATURE=ABSENT"
phase=TOOLS
for cmd in git docker sha256sum python3 realpath df; do
 if ! command -v "$cmd" >/dev/null 2>&1; then
   echo "MB1_HOST_MISSING_TOOL=$cmd"; exit 2
 fi
done
docker info >/dev/null 2>&1 || { echo "MB1_HOST_DOCKER_UNAVAILABLE"; exit 2; }
echo "MB1_HOST_DOCKER=OK"
phase=CAPACITY
# Compare available bytes on /tmp, where PG17 disposable files will be created.
free_kb="$(df -Pk /tmp | awk 'END {print $4}')"
[ "$free_kb" -ge 2097152 ] || { echo "MB1_HOST_FREE_TMP_LT_2G"; exit 2; }
echo "MB1_HOST_TMP_AT_LEAST_2GB=OK"
phase=EXISTING_SERVICES
# Warn, do not touch, stop or replace unrelated local containers.
docker ps --format '{{.Names}}' | sed 's/^/MB1_HOST_EXISTING_CONTAINER=/' 
echo "MB1_HOST_PREFLIGHT=OK"
echo "MB1_HOST_RECOVERY=NOT_RUN"
echo "MB1_RELEASE_AUTHORIZED=NO"
