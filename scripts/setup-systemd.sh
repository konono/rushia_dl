#!/bin/bash
# systemd ユニットファイルをインストール・有効化する
# 使用方法: ./scripts/setup-systemd.sh [--uninstall]
#
# テンプレート内の @@PROJECT_ROOT@@ と @@COMPOSE_CMD@@ を
# 実際のパスに置換してユーザーレベル systemd にインストールします。

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

readonly UNINSTALL="${1:-}"
readonly SYSTEMD_DIR="${HOME}/.config/systemd/user"

readonly UNIT_NAMES=(
    rushia-dl.service
    rushia-healthcheck.service
    rushia-healthcheck.timer
    rushia-upgrade.service
    rushia-upgrade.timer
    rushia-certbot.service
    rushia-certbot.timer
)

readonly TIMER_NAMES=(
    rushia-healthcheck.timer
    rushia-upgrade.timer
    rushia-certbot.timer
)

resolve_compose_cmd() {
    local cmd
    cmd="$(detect_compose_cmd)"

    if [[ "$cmd" == "docker compose" ]]; then
        local docker_path
        docker_path="$(command -v docker)"
        echo "${docker_path} compose"
    else
        command -v "$cmd"
    fi
}

# --- アンインストール ---
if [[ "$UNINSTALL" == "--uninstall" ]]; then
    log_step "systemd ユニットをアンインストール..."

    for timer in "${TIMER_NAMES[@]}"; do
        systemctl --user stop "$timer" 2>/dev/null || true
        systemctl --user disable "$timer" 2>/dev/null || true
    done

    systemctl --user stop rushia-dl.service 2>/dev/null || true
    systemctl --user disable rushia-dl.service 2>/dev/null || true

    for unit in "${UNIT_NAMES[@]}"; do
        rm -f "${SYSTEMD_DIR}/${unit}"
    done

    systemctl --user daemon-reload
    log_success "全ユニットを停止・無効化・削除しました"
    exit 0
fi

# --- インストール ---
cd_project_root

log_step "systemd ユニットをインストール..."

COMPOSE_CMD_PATH="$(resolve_compose_cmd)"
if [[ -z "$COMPOSE_CMD_PATH" ]]; then
    log_error "compose コマンドが見つかりません"
    exit 1
fi
log_info "compose コマンド: $COMPOSE_CMD_PATH"
log_info "プロジェクトルート: $PROJECT_ROOT"

mkdir -p "$SYSTEMD_DIR"

for unit in "${UNIT_NAMES[@]}"; do
    local_file="${PROJECT_ROOT}/systemd/${unit}"
    if [[ ! -f "$local_file" ]]; then
        log_warn "テンプレートが見つかりません: $local_file (スキップ)"
        continue
    fi

    sed \
        -e "s|@@PROJECT_ROOT@@|${PROJECT_ROOT}|g" \
        -e "s|@@COMPOSE_CMD@@|${COMPOSE_CMD_PATH}|g" \
        "$local_file" > "${SYSTEMD_DIR}/${unit}"

    log_info "  配置: ${unit}"
done

if grep -rq '@@' "${SYSTEMD_DIR}"/rushia-* 2>/dev/null; then
    log_error "プレースホルダーが残っています:"
    grep -rn '@@' "${SYSTEMD_DIR}"/rushia-*
    exit 1
fi

log_step "daemon-reload & ユニット有効化..."
systemctl --user daemon-reload

systemctl --user enable rushia-dl.service
log_info "  enabled: rushia-dl.service"

for timer in "${TIMER_NAMES[@]}"; do
    systemctl --user enable --now "$timer"
    log_info "  enabled+started: $timer"
done

loginctl enable-linger "$(whoami)" 2>/dev/null || true

# 既存の cron ジョブがあれば削除
if crontab -l 2>/dev/null | grep -q "renew-cert.sh"; then
    log_step "既存の certbot cron ジョブを削除..."
    "${SCRIPTS_DIR}/setup-cron.sh" --remove
fi

log_success "systemd セットアップ完了"
echo ""
log_info "ステータス確認:"
log_info "  systemctl --user status rushia-dl.service"
log_info "  systemctl --user list-timers 'rushia-*'"
echo ""
log_info "手動起動:"
log_info "  systemctl --user start rushia-dl.service"
echo ""
log_info "アンインストール:"
log_info "  $0 --uninstall"
