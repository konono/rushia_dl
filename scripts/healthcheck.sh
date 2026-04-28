#!/bin/bash
# rushia-dl ヘルスチェック + 異常時 Discord 通知
# 正常時は通知しない。異常→正常に復旧した時は復旧通知を送る。
# Usage: ./scripts/healthcheck.sh [--deep]
#   --deep: yt-dlp の実動作チェック（メタデータ取得）も行う。通常は毎時実行には重いので省略。
# 環境変数: DISCORD_WEBHOOK_URL (必須)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

DEEP=false
[[ "${1:-}" == "--deep" ]] && DEEP=true

cd_project_root

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
if [[ -z "$WEBHOOK_URL" ]] && [[ -f "${PROJECT_ROOT}/.env.webhook" ]]; then
    WEBHOOK_URL=$(grep '^DISCORD_WEBHOOK_URL=' "${PROJECT_ROOT}/.env.webhook" | cut -d= -f2-)
fi

LOCK_FILE="/tmp/rushia-healthcheck.notified"

discord_notify() {
    local message="$1"
    [[ -z "$WEBHOOK_URL" ]] && return 0
    curl -s -o /dev/null -H "Content-Type: application/json" \
        -d "{\"content\": \"$message\"}" \
        "$WEBHOOK_URL" || true
}

ERRORS=()

# 1. コンテナが running か
CONTAINER_STATUS=$(compose ps --format '{{.Status}}' rushia-dl 2>/dev/null || echo "not found")
if ! echo "$CONTAINER_STATUS" | grep -qi "up\|running"; then
    ERRORS+=("Container: $CONTAINER_STATUS")
fi

# 2. API が応答するか
if ! compose exec -T rushia-dl curl -sf http://localhost:8000/api/server-status >/dev/null 2>&1; then
    ERRORS+=("API: unreachable")
fi

# 3. yt-dlp が動作するか
if ! compose exec -T rushia-dl yt-dlp --version >/dev/null 2>&1; then
    ERRORS+=("yt-dlp: not working")
fi

# 4. deep モード: スモークテスト実行
if $DEEP && [[ ${#ERRORS[@]} -eq 0 ]]; then
    if ! compose exec -T rushia-dl bash /app/scripts/smoke-test.sh 2>&1 | tail -1 | grep -q "0 failed"; then
        ERRORS+=("smoke-test: yt-dlp download verification failed")
    fi
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    ERROR_DETAIL=$(printf '\\n- %s' "${ERRORS[@]}")
    log_error "異常検知: ${ERRORS[*]}"

    if [[ ! -f "$LOCK_FILE" ]]; then
        discord_notify "⚠️ **rushia-dl is down**${ERROR_DETAIL}"
        touch "$LOCK_FILE"
    fi
else
    if [[ -f "$LOCK_FILE" ]]; then
        discord_notify "✅ **rushia-dl recovered**\nサービスが復旧しました"
        rm -f "$LOCK_FILE"
    fi
fi
