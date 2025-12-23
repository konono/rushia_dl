#!/bin/bash
# nginxの起動を待機する
# 使用方法: ./scripts/wait-for-nginx.sh [タイムアウト秒]

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

readonly TIMEOUT="${1:-$NGINX_WAIT_TIMEOUT}"

cd_project_root

log_step "nginxの起動を待機..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    # HTTPで応答を確認（ACME用のパスをチェック）
    if curl -sSf "http://127.0.0.1/.well-known/acme-challenge/" >/dev/null 2>&1 || \
       curl -sSf "http://127.0.0.1/" >/dev/null 2>&1; then
        log_success "nginxが起動しました（${elapsed}秒）"
        exit 0
    fi
    
    sleep "$NGINX_WAIT_INTERVAL"
    elapsed=$((elapsed + NGINX_WAIT_INTERVAL))
    log_info "待機中... (${elapsed}/${TIMEOUT}秒)"
done

log_error "タイムアウト: nginxが${TIMEOUT}秒以内に起動しませんでした"
exit 1

