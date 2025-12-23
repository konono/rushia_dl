#!/bin/bash
# Let's Encrypt 証明書を更新する
# 使用方法: ./scripts/renew-cert.sh [--force]

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

readonly FORCE="${1:-}"

cd_project_root

log_step "証明書を更新..."

# 証明書を更新
# --entrypoint でデフォルトのentrypointを上書きして直接certbotを実行
if [[ "$FORCE" == "--force" ]]; then
    log_warn "強制更新モードで実行します"
    podman-compose run --rm --entrypoint "certbot" certbot renew --force-renewal
else
    podman-compose run --rm --entrypoint "certbot" certbot renew
fi

# nginxをリロード
log_step "nginxをリロード..."
if podman-compose exec nginx nginx -s reload 2>/dev/null; then
    log_success "nginxをリロードしました"
else
    log_warn "nginxのリロードに失敗しました（コンテナが起動していない可能性があります）"
fi

log_success "証明書の更新が完了しました"
log_info "証明書の状態を確認: podman-compose run --rm --entrypoint certbot certbot certificates"
