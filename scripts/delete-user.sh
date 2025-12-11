#!/bin/bash

# Basic認証ユーザー削除スクリプト
# 使用方法: ./scripts/delete-user.sh <ユーザー名>

set -e

HTPASSWD_FILE="./nginx/.htpasswd"

if [ -z "$1" ]; then
    echo "使用方法: $0 <ユーザー名>"
    echo ""
    echo "=== 登録済みユーザー一覧 ==="
    if [ -f "$HTPASSWD_FILE" ]; then
        cut -d: -f1 "$HTPASSWD_FILE"
    else
        echo "(ユーザーなし)"
    fi
    exit 1
fi

USERNAME=$1

if [ ! -f "$HTPASSWD_FILE" ]; then
    echo "エラー: .htpasswdファイルが存在しません"
    exit 1
fi

# ユーザーが存在するか確認
if ! grep -q "^${USERNAME}:" "$HTPASSWD_FILE"; then
    echo "エラー: ユーザー '$USERNAME' は存在しません"
    exit 1
fi

# ユーザーを削除
grep -v "^${USERNAME}:" "$HTPASSWD_FILE" > "${HTPASSWD_FILE}.tmp"
mv "${HTPASSWD_FILE}.tmp" "$HTPASSWD_FILE"

echo "ユーザー '$USERNAME' を削除しました"
echo ""
echo "=== 登録済みユーザー一覧 ==="
if [ -s "$HTPASSWD_FILE" ]; then
    cut -d: -f1 "$HTPASSWD_FILE"
else
    echo "(ユーザーなし)"
fi
echo ""
echo "変更を反映するには: podman-compose exec nginx nginx -s reload"

