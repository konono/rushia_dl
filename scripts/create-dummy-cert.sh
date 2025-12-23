#!/bin/bash
# ダミー証明書を作成する（nginx初回起動用）
# 使用方法: ./scripts/create-dummy-cert.sh <ドメイン名>

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# 引数チェック
if [[ -z "${1:-}" ]]; then
    log_error "使用方法: $0 <ドメイン名>"
    log_error "例: $0 rushia-dl.example.com"
    exit 1
fi

readonly DOMAIN="$1"
readonly CERT_PATH="${CERTBOT_DIR}/conf/live/${DOMAIN}"

cd_project_root

log_step "ダミー証明書を作成..."

# 必要なコマンド
require_command openssl

# 既存の証明書をチェック
if [[ -d "$CERT_PATH" ]]; then
    if ! confirm "既存の証明書が見つかりました。上書きしますか？"; then
        log_info "キャンセルしました"
        exit 0
    fi
    rm -rf "$CERT_PATH"
fi

# ディレクトリ作成
ensure_dir "$CERT_PATH"

# OpenSSLでダミー証明書を生成
openssl req -x509 -nodes -newkey "rsa:${RSA_KEY_SIZE}" -days 1 \
    -keyout "${CERT_PATH}/privkey.pem" \
    -out "${CERT_PATH}/fullchain.pem" \
    -subj "/CN=localhost" \
    2>/dev/null

log_success "ダミー証明書を作成: $CERT_PATH"

