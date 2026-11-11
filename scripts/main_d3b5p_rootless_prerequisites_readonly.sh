#!/usr/bin/env bash
# D3-B5P: read-only rootless Podman prerequisites, never installs packages.
set -Eeuo pipefail
set +x
mark(){ printf "D3B5P_%s=%s\n" "$1" "$2"; }
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
mark INSTALL_EXECUTED NO
mark CONFIG_CHANGE_EXECUTED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark HOST_DOCKER_ACCESSED NO
if [[ "$(id -u)" == 0 ]]; then mark UNPRIVILEGED_OPERATOR FAIL; mark RESULT 2; exit 2; fi
mark UNPRIVILEGED_OPERATOR PASS
for cmd in python3 awk stat df; do
  command -v "$cmd" >/dev/null 2>&1 || { mark TOOL_MISSING "$cmd"; mark RESULT 2; exit 2; }
done
if command -v podman >/dev/null 2>&1; then
  mark PODMAN_INSTALLED YES
else
  mark PODMAN_INSTALLED NO
fi
if command -v apt-cache >/dev/null 2>&1; then
  # Read the entire producer stream: early awk exit can send SIGPIPE (141)
  # to apt-cache when pipefail is enabled. Do not mark an apt failure as absent.
  if candidate="$(apt-cache policy podman 2>/dev/null | awk '/^[[:space:]]*Candidate:/ && !found {print $2; found=1}')"; then
    :
  else
    candidate=""
    mark PODMAN_APT_QUERY ERROR
  fi
  if [[ -n "$candidate" && "$candidate" != "(none)" ]]; then
    mark PODMAN_APT_CANDIDATE AVAILABLE
  else
    mark PODMAN_APT_CANDIDATE NOT_AVAILABLE
  fi
else
  mark PODMAN_APT_CANDIDATE UNKNOWN
fi
for cmd in newuidmap newgidmap fuse-overlayfs slirp4netns pasta; do
  key="$(printf "%s" "$cmd" | tr "[:lower:]-" "[:upper:]_")"
  if command -v "$cmd" >/dev/null 2>&1; then mark "${key}_AVAILABLE" YES; else mark "${key}_AVAILABLE" NO; fi
done
uid="$(id -un)"
if [[ -r /etc/subuid && -r /etc/subgid ]] &&
   awk -F: -v user="$uid" '$1==user && $2~/^[0-9]+$/ && $3~/^[0-9]+$/ && $3>=65536 {found=1} END {exit !found}' /etc/subuid &&
   awk -F: -v user="$uid" '$1==user && $2~/^[0-9]+$/ && $3~/^[0-9]+$/ && $3>=65536 {found=1} END {exit !found}' /etc/subgid; then
  mark SUBUID_SUBGID_RANGE PASS
else
  mark SUBUID_SUBGID_RANGE NOT_VERIFIED
fi
if [[ -r /proc/sys/user/max_user_namespaces ]]; then
  count="$(cat /proc/sys/user/max_user_namespaces)"
  if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then mark USER_NAMESPACES_KERNEL ENABLED;
  else mark USER_NAMESPACES_KERNEL DISABLED; fi
else
  mark USER_NAMESPACES_KERNEL UNKNOWN
fi
if [[ -r /proc/sys/kernel/unprivileged_userns_clone ]]; then
  clone="$(cat /proc/sys/kernel/unprivileged_userns_clone)"
  if [[ "$clone" == 1 ]]; then mark UNPRIVILEGED_USERNS_CLONE ENABLED;
  else mark UNPRIVILEGED_USERNS_CLONE DISABLED; fi
else
  mark UNPRIVILEGED_USERNS_CLONE NOT_EXPOSED
fi
# Do not invoke podman info here: some builds initialize persistent user storage.
mark ROOTLESS_PODMAN_RUNTIME_VERIFIED NO
mark PACKAGE_INSTALL_AUTHORIZED NO
mark D3B5_IMAGE_IMPORT_EXECUTED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark RESULT 0
