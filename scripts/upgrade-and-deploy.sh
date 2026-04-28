#!/bin/bash
# rushia-dl のコード取得 + リビルド + 再デプロイ + Discord 通知
# GitHub CI でスモークテスト済みのコードを本番に反映する。
# Usage: ./scripts/upgrade-and-deploy.sh [--dry-run]
# 環境変数: DISCORD_WEBHOOK_URL (必須)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

cd_project_root

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
if [[ -z "$WEBHOOK_URL" ]] && [[ -f "${PROJECT_ROOT}/.env.webhook" ]]; then
    WEBHOOK_URL=$(grep '^DISCORD_WEBHOOK_URL=' "${PROJECT_ROOT}/.env.webhook" | cut -d= -f2-)
fi

discord_notify() {
    local message="$1"
    [[ -z "$WEBHOOK_URL" ]] && return 0
    curl -s -o /dev/null -H "Content-Type: application/json" \
        -d "{\"content\": \"$message\"}" \
        "$WEBHOOK_URL" || true
}

if $DRY_RUN; then
    log_info "=== DRY RUN ==="
    log_info "1. git pull"
    log_info "2. $(detect_compose_cmd) build rushia-dl"
    log_info "3. $(detect_compose_cmd) up -d rushia-dl"
    log_info "4. API起動待機 (最大60秒)"
    log_info "5. Discord 通知"
    exit 0
fi

log_step "git pull"
GIT_RESULT=$(git pull 2>&1) || true
log_info "$GIT_RESULT"

if echo "$GIT_RESULT" | grep -q "Already up to date"; then
    log_info "変更なし — スキップ"
    exit 0
fi

log_step "イメージをリビルド"
BUILD_LOG=$(compose build rushia-dl 2>&1)
if [[ $? -ne 0 ]]; then
    log_error "ビルドに失敗しました"
    discord_notify "❌ **rushia-dl upgrade failed**\nビルドに失敗しました\n\`\`\`$(echo "$BUILD_LOG" | tail -5)\`\`\`"
    exit 1
fi

log_step "コンテナを再起動"
compose up -d rushia-dl

log_step "API起動待機 (最大60秒)"
API_UP=false
for i in $(seq 1 12); do
    sleep 5
    if compose exec -T rushia-dl curl -sf http://localhost:8000/api/server-status >/dev/null 2>&1; then
        API_UP=true
        break
    fi
    log_info "  待機中... (${i}/12)"
done

if ! $API_UP; then
    log_error "APIが起動しませんでした"
    discord_notify "❌ **rushia-dl upgrade failed**\nAPIサーバーが60秒以内に起動しませんでした\n手動確認してください"
    exit 1
fi

YT_DLP_VERSION=$(compose exec -T rushia-dl yt-dlp --version 2>/dev/null || echo "unknown")
DENO_VERSION=$(compose exec -T rushia-dl deno --version 2>/dev/null | head -1 || echo "unknown")

log_success "アップグレード完了"
log_info "yt-dlp: $YT_DLP_VERSION"
log_info "deno: $DENO_VERSION"
discord_notify "✅ **rushia-dl upgrade complete**\nyt-dlp: \`$YT_DLP_VERSION\`\ndeno: \`$DENO_VERSION\`"
