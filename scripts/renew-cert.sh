#!/bin/bash
# Let's Encrypt 証明書を更新する
# 使用方法: ./scripts/renew-cert.sh [--force]

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

readonly FORCE="${1:-}"

cd_project_root

log_step "証明書を更新..."

if [[ "$FORCE" == "--force" ]]; then
    log_warn "強制更新モードで実行します"
    compose run --rm certbot renew --force-renewal
else
    compose run --rm certbot renew
fi

log_step "nginxをリロード..."
if compose exec nginx nginx -s reload 2>/dev/null; then
    log_success "nginxをリロードしました"
else
    log_warn "nginxのリロードに失敗しました（コンテナが起動していない可能性があります）"
fi

log_success "証明書の更新が完了しました"
log_info "証明書の状態を確認: compose run --rm certbot certificates"
