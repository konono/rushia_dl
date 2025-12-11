#!/bin/bash

# Basic認証ユーザー一覧表示スクリプト
# 使用方法: ./scripts/list-users.sh

HTPASSWD_FILE="./nginx/.htpasswd"

echo "=== 登録済みユーザー一覧 ==="
if [ -f "$HTPASSWD_FILE" ] && [ -s "$HTPASSWD_FILE" ]; then
    cut -d: -f1 "$HTPASSWD_FILE"
    echo ""
    echo "合計: $(wc -l < "$HTPASSWD_FILE") ユーザー"
else
    echo "(ユーザーなし)"
    echo ""
    echo "ユーザーを追加するには: ./scripts/add-user.sh <ユーザー名>"
fi

