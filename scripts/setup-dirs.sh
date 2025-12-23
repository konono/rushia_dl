#!/bin/bash
# 必要なディレクトリを作成する

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

cd_project_root

log_step "ディレクトリを作成..."

ensure_dir "$NGINX_DIR"
ensure_dir "$NGINX_CONF_DIR"
ensure_dir "$CERTBOT_DIR/conf"
ensure_dir "$CERTBOT_DIR/www"
ensure_dir "$DOWNLOADS_DIR"
ensure_dir "$COOKIES_DIR"

log_success "ディレクトリの作成が完了しました"

