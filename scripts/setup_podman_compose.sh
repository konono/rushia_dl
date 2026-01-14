#!/usr/bin/env bash
set -euo pipefail

# ---- settings ----
COMPOSE_INSTALL_PATH="/usr/local/bin/docker-compose"
ARCH="$(uname -m)"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: rootで実行してください（sudo ./setup.sh）"
  exit 1
fi

case "$ARCH" in
  x86_64)  COMPOSE_ASSET="docker-compose-linux-x86_64" ;;
  aarch64) COMPOSE_ASSET="docker-compose-linux-aarch64" ;;
  *) echo "ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
esac

echo "==> Installing Podman tools"
dnf -y install container-tools

echo "==> Installing docker compatibility (podman-docker)"
dnf -y install podman-docker

echo "==> Enabling Podman API socket (system-wide)"
# /run/podman/podman.sock を提供するソケットを起動時から有効化
systemctl enable --now podman.socket

echo "==> Installing docker-compose (Compose v2 standalone binary)"
dnf -y install curl ca-certificates
curl -fsSL "https://github.com/docker/compose/releases/latest/download/${COMPOSE_ASSET}" -o "${COMPOSE_INSTALL_PATH}"
chmod +x "${COMPOSE_INSTALL_PATH}"

echo "==> Verifying"
podman --version
docker --version || true
docker-compose version

# 互換ソケット確認（podman-docker が docker.sock 互換リンクを作る）
if [[ -S /run/podman/podman.sock ]]; then
  echo "OK: /run/podman/podman.sock exists"
fi
if [[ -L /var/run/docker.sock || -S /var/run/docker.sock ]]; then
  echo "OK: /var/run/docker.sock is present (link or socket)"
fi

echo "==> Done."
echo "使い方: docker-compose up -d / docker-compose down など"

