#!/bin/bash

# 証明書自動更新用のcronジョブを設定するスクリプト
# 使用方法: ./scripts/setup-cron.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RENEW_SCRIPT="$PROJECT_DIR/scripts/renew-cert.sh"

echo "=== 証明書自動更新のcronジョブ設定 ==="

# cronジョブの内容（毎日午前3時に実行）
CRON_JOB="0 3 * * * cd $PROJECT_DIR && $RENEW_SCRIPT >> /var/log/certbot-renew.log 2>&1"

# 既存のcronジョブをチェック
if crontab -l 2>/dev/null | grep -q "renew-cert.sh"; then
    echo "既存のcronジョブが見つかりました。更新します..."
    # 既存のジョブを削除して追加
    (crontab -l 2>/dev/null | grep -v "renew-cert.sh"; echo "$CRON_JOB") | crontab -
else
    echo "新しいcronジョブを追加します..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi

echo ""
echo "=== 完了 ==="
echo "設定されたcronジョブ:"
crontab -l | grep "renew-cert.sh"
echo ""
echo "ログファイル: /var/log/certbot-renew.log"
echo ""
echo "※ certbotコンテナも12時間ごとに自動更新をチェックします"

