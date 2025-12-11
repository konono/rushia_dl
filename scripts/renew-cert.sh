#!/bin/bash

# Let's Encrypt 証明書更新スクリプト
# 使用方法: ./scripts/renew-cert.sh

set -e

echo "=== Let's Encrypt 証明書更新 ==="

# Certbotで更新を実行
echo ">>> 証明書を更新..."
podman-compose run --rm certbot renew

# Nginxをリロード
echo ">>> Nginxをリロード..."
podman-compose exec nginx nginx -s reload

echo ""
echo "=== 完了 ==="
echo "証明書の状態を確認: podman-compose run --rm certbot certificates"

