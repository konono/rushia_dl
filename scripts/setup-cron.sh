#!/bin/bash
# 証明書自動更新用のcronジョブを設定する
# 使用方法: ./scripts/setup-cron.sh [--remove]

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

readonly REMOVE="${1:-}"

cd_project_root

readonly RENEW_SCRIPT="${SCRIPTS_DIR}/renew-cert.sh"
readonly LOG_FILE="/var/log/rushia-dl-certbot.log"
readonly CRON_COMMENT="# Rushia DL - Let's Encrypt certificate renewal"
readonly CRON_JOB="0 3 * * * cd ${PROJECT_ROOT} && ${RENEW_SCRIPT} >> ${LOG_FILE} 2>&1"

# 削除モード
if [[ "$REMOVE" == "--remove" ]]; then
    log_step "cronジョブを削除..."
    if crontab -l 2>/dev/null | grep -q "renew-cert.sh"; then
        crontab -l 2>/dev/null | grep -v "renew-cert.sh" | grep -v "Rushia DL" | crontab -
        log_success "cronジョブを削除しました"
    else
        log_info "cronジョブは設定されていません"
    fi
    exit 0
fi

log_step "証明書自動更新のcronジョブを設定..."

# 既存のcronジョブをチェック
if crontab -l 2>/dev/null | grep -q "renew-cert.sh"; then
    log_warn "既存のcronジョブが見つかりました"
    if ! confirm "上書きしますか？"; then
        log_info "キャンセルしました"
        exit 0
    fi
    # 既存のジョブを削除
    crontab -l 2>/dev/null | grep -v "renew-cert.sh" | grep -v "Rushia DL" | crontab -
fi

# 新しいジョブを追加
(crontab -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$CRON_JOB") | crontab -

log_success "cronジョブを設定しました"
echo ""
log_info "設定内容: 毎日午前3時に証明書更新をチェック"
log_info "ログファイル: $LOG_FILE"
echo ""
log_info "現在のcron設定:"
crontab -l | grep -A1 "Rushia DL" || true
echo ""
log_info "削除するには: $0 --remove"
log_info ""
log_info "※ certbotコンテナも12時間ごとに自動更新をチェックします"
