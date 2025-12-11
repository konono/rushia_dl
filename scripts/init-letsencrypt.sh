#!/bin/bash

# Let's Encrypt 初期証明書取得スクリプト
# 使用方法: ./scripts/init-letsencrypt.sh your-domain.com your-email@example.com

set -e

# 引数チェック
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "使用方法: $0 <ドメイン名> <メールアドレス>"
    echo "例: $0 rushia-dl.example.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2
RSA_KEY_SIZE=4096
DATA_PATH="./certbot"
NGINX_CONF="./nginx/conf.d/rushia-dl.conf"

echo "=== Let's Encrypt 証明書初期設定 ==="
echo "ドメイン: $DOMAIN"
echo "メール: $EMAIL"
echo ""

# ドメイン名をnginx設定ファイルに反映
echo ">>> nginx設定ファイルのドメインを更新..."
if [ -f "$NGINX_CONF" ]; then
    sed -i.bak "s/your-domain.com/$DOMAIN/g" "$NGINX_CONF"
    rm -f "${NGINX_CONF}.bak"
    echo "    $NGINX_CONF を更新しました"
else
    echo "エラー: $NGINX_CONF が見つかりません"
    exit 1
fi

# ディレクトリ作成
echo ">>> ディレクトリを作成..."
mkdir -p "$DATA_PATH/conf"
mkdir -p "$DATA_PATH/www"
mkdir -p "./downloads"
mkdir -p "./cookies"

# Basic認証用の初期ユーザーを作成
HTPASSWD_FILE="./nginx/.htpasswd"
if [ ! -f "$HTPASSWD_FILE" ]; then
    echo ""
    echo ">>> 🔒 Basic認証の初期ユーザーを作成..."
    echo "管理者ユーザー名を入力してください（例: admin）:"
    read -r ADMIN_USER
    echo "パスワードを入力してください:"
    read -s ADMIN_PASS
    echo ""
    
    # パスワードをハッシュ化して保存
    HASH=$(openssl passwd -apr1 "$ADMIN_PASS")
    echo "${ADMIN_USER}:${HASH}" > "$HTPASSWD_FILE"
    echo "    ユーザー '$ADMIN_USER' を作成しました"
    echo ""
    echo "    追加のユーザーは後から ./scripts/add-user.sh で追加できます"
fi

# 既存の証明書をチェック
if [ -d "$DATA_PATH/conf/live/$DOMAIN" ]; then
    read -p "既存の証明書が見つかりました。上書きしますか？ (y/N): " decision
    if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
        echo "キャンセルしました"
        exit 0
    fi
fi

# ダミー証明書を作成（nginxの初回起動用）
echo ">>> ダミー証明書を作成..."
CERT_PATH="$DATA_PATH/conf/live/$DOMAIN"
mkdir -p "$CERT_PATH"

# OpenSSLでダミー証明書を生成
openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1 \
    -keyout "$CERT_PATH/privkey.pem" \
    -out "$CERT_PATH/fullchain.pem" \
    -subj "/CN=localhost"

echo "    ダミー証明書を作成しました"

# アプリケーションをビルド
echo ">>> アプリケーションをビルド..."
podman-compose build

# Nginxを起動（ダミー証明書で）
echo ">>> Nginxを起動..."
podman-compose up -d nginx

# 少し待つ
echo ">>> Nginxの起動を待機..."
sleep 5

# ダミー証明書を削除
echo ">>> ダミー証明書を削除..."
rm -rf "$CERT_PATH"

# 本番証明書を取得
echo ">>> Let's Encrypt から証明書を取得..."
podman-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"

# Nginxをリロード
echo ">>> Nginxをリロード..."
podman-compose exec nginx nginx -s reload

# 全サービスを起動
echo ">>> 全サービスを起動..."
podman-compose up -d

echo ""
echo "=== 完了 ==="
echo "https://$DOMAIN でアクセスできます"
echo ""
echo "証明書は自動で更新されます（12時間ごとにチェック）"
echo "手動で更新する場合: ./scripts/renew-cert.sh"

