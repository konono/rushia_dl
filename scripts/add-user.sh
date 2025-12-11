#!/bin/bash

# Basic認証ユーザー追加スクリプト
# 使用方法: ./scripts/add-user.sh <ユーザー名>

set -e

HTPASSWD_FILE="./nginx/.htpasswd"

if [ -z "$1" ]; then
    echo "使用方法: $0 <ユーザー名>"
    echo "例: $0 friend1"
    exit 1
fi

USERNAME=$1

# htpasswdコマンドがない場合はopensslで代用
if command -v htpasswd &> /dev/null; then
    # htpasswdがある場合
    if [ -f "$HTPASSWD_FILE" ]; then
        htpasswd "$HTPASSWD_FILE" "$USERNAME"
    else
        htpasswd -c "$HTPASSWD_FILE" "$USERNAME"
    fi
else
    # htpasswdがない場合（opensslで代用）
    echo -n "パスワードを入力: "
    read -s PASSWORD
    echo ""
    echo -n "パスワードを再入力: "
    read -s PASSWORD2
    echo ""

    if [ "$PASSWORD" != "$PASSWORD2" ]; then
        echo "エラー: パスワードが一致しません"
        exit 1
    fi

    # パスワードをハッシュ化
    HASH=$(openssl passwd -apr1 "$PASSWORD")
    
    if [ -f "$HTPASSWD_FILE" ]; then
        # 既存ユーザーを削除（存在する場合）
        grep -v "^${USERNAME}:" "$HTPASSWD_FILE" > "${HTPASSWD_FILE}.tmp" 2>/dev/null || true
        mv "${HTPASSWD_FILE}.tmp" "$HTPASSWD_FILE"
    fi
    
    # 新しいユーザーを追加
    echo "${USERNAME}:${HASH}" >> "$HTPASSWD_FILE"
    echo "ユーザー '$USERNAME' を追加しました"
fi

echo ""
echo "=== 登録済みユーザー一覧 ==="
cut -d: -f1 "$HTPASSWD_FILE"
echo ""
echo "変更を反映するには: podman-compose exec nginx nginx -s reload"

