#!/usr/bin/env bash
# Orbinum testnet validator: Docker + official node-deploy + firewall + start.
# Usage: sudo bash install.sh <validator-name>
set -euo pipefail
NAME=${1:?usage: install.sh <validator-name>}
DIR=/root/node-deploy/testnet/validator

[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }

# 1) Docker from Docker's own apt repo (no third-party install scripts)
if ! command -v docker >/dev/null; then
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
fi
command -v jq >/dev/null || apt-get install -y -qq jq python3
docker --version && docker compose version

# 2) Official compose files + chain spec
[ -d /root/node-deploy ] || git clone -q https://github.com/orbinum/node-deploy.git /root/node-deploy
cd "$DIR"
if [ ! -f .env ]; then
  cp .env.example .env
  sed -i "s|^VALIDATOR_NAME=.*|VALIDATOR_NAME=${NAME}|" .env
  sed -i "s|^VALIDATOR_NODE_KEY=.*|VALIDATOR_NODE_KEY=$(openssl rand -hex 32)|" .env
  # warp sync: minutes instead of hours on a fresh volume
  sed -i "s|^SYNC_MODE=.*|SYNC_MODE=--sync warp|" .env
  chmod 600 .env
  echo ".env created (node key generated, kept in .env only)"
else
  echo ".env already exists, left untouched"
fi

# 3) Firewall: only P2P is public. 9944 (unsafe RPC) must NEVER be opened.
if command -v ufw >/dev/null; then
  ufw allow 22/tcp >/dev/null
  ufw allow 30333/tcp comment 'orbinum p2p' >/dev/null
  ufw --force enable >/dev/null
fi

# 4) Swap guard: state import peaks at ~5-6 GB RAM
if ! swapon --show | grep -q . && [ "$(free -g | awk '/Mem:/{print $2}')" -lt 16 ]; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-swap.conf && sysctl -q -p /etc/sysctl.d/99-swap.conf
  echo "4 GB swap added"
fi

# 5) Start
docker compose pull -q
docker compose up -d
echo
echo "Started. Follow the sync with:"
echo "  cd $DIR && docker compose logs -f orbinum-validator"
