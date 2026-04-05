#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

$SUDO install -d -m 0755 /opt/minhas-financas/backend
$SUDO install -d -m 0755 /opt/minhas-financas/frontend-dist
$SUDO install -d -m 0755 /opt/minhas-financas/env

if ! command -v docker >/dev/null 2>&1; then
  $SUDO apt-get update -qq
  $SUDO apt-get install --no-install-recommends -y ca-certificates curl gnupg lsb-release

  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -qq
  $SUDO apt-get install --no-install-recommends -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if [[ $# -gt 0 ]]; then
  $SUDO usermod -aG docker "$1"
fi

echo "Bootstrap complete. Create /opt/minhas-financas/env/backend.env before running deploys."
