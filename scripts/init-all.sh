#!/bin/bash
# 初期セットアップを実行するオーケストレーター
# 使用方法: ./scripts/init-all.sh <ドメイン名> <メールアドレス> [--staging]
#
# 各ステップは個別に実行することも可能です:
#   1. ./scripts/setup-dirs.sh
#   2. ./scripts/generate-nginx-config.sh <ドメイン>
#   3. ./scripts/manage-user.sh add <ユーザー名>
#   4. ./scripts/create-dummy-cert.sh <ドメイン>
#   5. podman-compose build && podman-compose up -d nginx
#   6. ./scripts/wait-for-nginx.sh
#   7. ./scripts/obtain-cert.sh <ドメイン> <メール>
#   8. podman-compose up -d

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# 引数チェック
if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
    echo "使用方法: $0 <ドメイン名> <メールアドレス> [--staging]"
    echo ""
    echo "例:"
    echo "  $0 rushia-dl.example.com admin@example.com"
    echo "  $0 rushia-dl.example.com admin@example.com --staging  # テスト用"
    echo ""
    echo "各ステップを個別に実行することも可能です:"
    echo "  ./scripts/setup-dirs.sh"
    echo "  ./scripts/generate-nginx-config.sh <ドメイン>"
    echo "  ./scripts/add-user.sh <ユーザー名>"
    echo "  ./scripts/create-dummy-cert.sh <ドメイン>"
    echo "  ./scripts/obtain-cert.sh <ドメイン> <メール>"
    echo "  ./scripts/renew-cert.sh"
    exit 1
fi

readonly DOMAIN="$1"
readonly EMAIL="$2"
readonly STAGING="${3:-}"

cd_project_root

echo "============================================"
echo "  Rushia DL 初期セットアップ"
echo "============================================"
echo ""
log_info "ドメイン: $DOMAIN"
log_info "メール: $EMAIL"
if [[ "$STAGING" == "--staging" ]]; then
    log_warn "ステージング環境（テスト用証明書）"
fi
echo ""

# Step 1: ディレクトリ作成
"$SCRIPTS_DIR/setup-dirs.sh"

# Step 2: nginx設定ファイル生成
"$SCRIPTS_DIR/generate-nginx-config.sh" "$DOMAIN"

# Step 3: Basic認証ユーザー作成（存在しない場合のみ）
if [[ ! -f "$HTPASSWD_FILE" ]]; then
    echo ""
    log_step "🔒 Basic認証の初期ユーザーを作成"
    echo "管理者ユーザー名を入力してください（例: admin）:"
    read -r ADMIN_USER
    
    if [[ -n "$ADMIN_USER" ]]; then
        "$SCRIPTS_DIR/manage-user.sh" add "$ADMIN_USER"
    else
        log_warn "ユーザー作成をスキップしました"
        log_info "後から ./scripts/manage-user.sh add <ユーザー名> で追加できます"
    fi
fi

# Step 4: ダミー証明書作成
"$SCRIPTS_DIR/create-dummy-cert.sh" "$DOMAIN"

# Step 5: アプリケーションをビルド
log_step "アプリケーションをビルド..."
podman-compose build

# Step 6: nginxを起動
log_step "nginxを起動..."
podman-compose up -d nginx

# Step 7: nginx起動待ち
"$SCRIPTS_DIR/wait-for-nginx.sh"

# Step 8: 本番証明書を取得
if [[ "$STAGING" == "--staging" ]]; then
    "$SCRIPTS_DIR/obtain-cert.sh" "$DOMAIN" "$EMAIL" --staging
else
    "$SCRIPTS_DIR/obtain-cert.sh" "$DOMAIN" "$EMAIL"
fi

# Step 9: nginxをリロード
log_step "nginxをリロード..."
podman-compose exec nginx nginx -s reload

# Step 10: 全サービスを起動
log_step "全サービスを起動..."
podman-compose up -d

echo ""
echo "============================================"
log_success "セットアップが完了しました！"
echo "============================================"
echo ""
log_info "アクセスURL: https://$DOMAIN"
echo ""
log_info "証明書は自動で更新されます（12時間ごとにチェック）"
log_info "手動更新: ./scripts/renew-cert.sh"
log_info "ユーザー管理: ./scripts/manage-user.sh help"

