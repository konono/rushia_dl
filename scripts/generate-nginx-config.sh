#!/bin/bash
# テンプレートからnginx設定ファイルを生成する
# 使用方法: ./scripts/generate-nginx-config.sh <ドメイン名>

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# 引数チェック
if [[ -z "${1:-}" ]]; then
    log_error "使用方法: $0 <ドメイン名>"
    log_error "例: $0 rushia-dl.example.com"
    exit 1
fi

readonly DOMAIN="$1"

cd_project_root

log_step "nginx設定ファイルを生成..."

# テンプレートの存在確認
require_file "$NGINX_TEMPLATE" "テンプレートファイルが見つかりません: $NGINX_TEMPLATE"

# ディレクトリ確保
ensure_dir "$NGINX_CONF_DIR"

# 既存ファイルのバックアップ
if [[ -f "$NGINX_CONF" ]]; then
    backup_file="${NGINX_CONF}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$NGINX_CONF" "$backup_file"
    log_info "既存の設定をバックアップ: $backup_file"
fi

# テンプレートからコピーして置換
cp "$NGINX_TEMPLATE" "$NGINX_CONF"
sed -i.tmp "s/{{DOMAIN}}/$DOMAIN/g" "$NGINX_CONF"
rm -f "${NGINX_CONF}.tmp"

log_success "nginx設定ファイルを生成: $NGINX_CONF"
log_info "ドメイン: $DOMAIN"

