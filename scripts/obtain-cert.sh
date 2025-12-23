#!/bin/bash
# Let's Encrypt から証明書を取得する
# 使用方法: ./scripts/obtain-cert.sh <ドメイン名> <メールアドレス> [--staging]

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# 引数チェック
if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
    log_error "使用方法: $0 <ドメイン名> <メールアドレス> [--staging]"
    log_error "例: $0 rushia-dl.example.com admin@example.com"
    log_error "    $0 rushia-dl.example.com admin@example.com --staging  # テスト用"
    exit 1
fi

readonly DOMAIN="$1"
readonly EMAIL="$2"
readonly STAGING="${3:-}"

cd_project_root

log_step "Let's Encrypt から証明書を取得..."

# 既存の証明書をチェック
CERT_PATH="${CERTBOT_DIR}/conf/live/${DOMAIN}"
if [[ -d "$CERT_PATH" ]]; then
    log_warn "既存の証明書ディレクトリが見つかりました: $CERT_PATH"
    
    # 証明書が有効かどうか確認
    if [[ -f "${CERT_PATH}/fullchain.pem" ]]; then
        if openssl x509 -in "${CERT_PATH}/fullchain.pem" -noout -checkend 86400 2>/dev/null; then
            log_info "有効な証明書が既に存在します"
            if ! confirm "証明書を再取得しますか？（既存の証明書は削除されます）"; then
                log_info "キャンセルしました"
                exit 0
            fi
        else
            log_info "証明書の有効期限が切れている、またはダミー証明書です"
        fi
    fi
    
    # 既存の証明書を削除
    log_info "既存の証明書を削除..."
    rm -rf "$CERT_PATH"
    
    # renewal設定も削除
    RENEWAL_CONF="${CERTBOT_DIR}/conf/renewal/${DOMAIN}.conf"
    if [[ -f "$RENEWAL_CONF" ]]; then
        rm -f "$RENEWAL_CONF"
        log_info "renewal設定を削除しました"
    fi
fi

log_info "ドメイン: $DOMAIN"
log_info "メール: $EMAIL"

# certbotコマンドを構築
CERTBOT_CMD="certonly --webroot --webroot-path=/var/www/certbot --email ${EMAIL} --agree-tos --no-eff-email -d ${DOMAIN}"

# ステージング環境（テスト用）
if [[ "$STAGING" == "--staging" ]]; then
    CERTBOT_CMD="${CERTBOT_CMD} --staging"
    log_warn "ステージング環境で実行します（テスト用証明書）"
fi

# デバッグ出力
log_info "実行コマンド: certbot $CERTBOT_CMD"

# 証明書を取得
# --entrypoint でデフォルトのentrypointを上書きして直接certbotを実行
# shellcheck disable=SC2086
uvx podman-compose run --rm --entrypoint "certbot" certbot $CERTBOT_CMD

# 結果を確認
if [[ -f "${CERT_PATH}/fullchain.pem" ]]; then
    log_success "証明書の取得が完了しました"
    log_info "証明書パス: $CERT_PATH"
    
    # 証明書情報を表示
    log_info "証明書の有効期限:"
    openssl x509 -in "${CERT_PATH}/fullchain.pem" -noout -dates 2>/dev/null || true
else
    log_error "証明書の取得に失敗しました"
    log_error "ログを確認してください: podman-compose logs certbot"
    exit 1
fi
