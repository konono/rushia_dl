#!/bin/bash
# Basic認証ユーザー管理スクリプト
# 使用方法:
#   ./scripts/manage-user.sh add <ユーザー名>    - ユーザー追加
#   ./scripts/manage-user.sh delete <ユーザー名> - ユーザー削除
#   ./scripts/manage-user.sh list                - ユーザー一覧
#   ./scripts/manage-user.sh help                - ヘルプ表示

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# ===========================================
# ヘルプ表示
# ===========================================
show_help() {
    cat << EOF
Basic認証ユーザー管理スクリプト

使用方法:
  $0 <コマンド> [引数]

コマンド:
  add <ユーザー名>     ユーザーを追加（パスワード入力あり）
  delete <ユーザー名>  ユーザーを削除
  list                 登録済みユーザー一覧を表示
  help                 このヘルプを表示

例:
  $0 add admin         # adminユーザーを追加
  $0 delete guest      # guestユーザーを削除
  $0 list              # ユーザー一覧を表示

注意:
  変更を反映するには以下を実行してください:
  podman-compose exec nginx nginx -s reload
EOF
}

# ===========================================
# ユーザー追加
# ===========================================
cmd_add() {
    local username="${1:-}"
    
    if [[ -z "$username" ]]; then
        log_error "ユーザー名を指定してください"
        log_error "使用方法: $0 add <ユーザー名>"
        exit 1
    fi
    
    # ディレクトリ確保
    ensure_dir "$NGINX_DIR"
    
    log_step "ユーザー '$username' を追加..."
    
    # htpasswdコマンドがある場合はそれを使用
    if command -v htpasswd &> /dev/null; then
        if [[ -f "$HTPASSWD_FILE" ]]; then
            htpasswd "$HTPASSWD_FILE" "$username"
        else
            htpasswd -c "$HTPASSWD_FILE" "$username"
        fi
    else
        # htpasswdがない場合はopensslで代用
        require_command openssl
        
        echo -n "パスワードを入力: "
        read -rs password
        echo ""
        echo -n "パスワードを再入力: "
        read -rs password2
        echo ""

        if [[ "$password" != "$password2" ]]; then
            log_error "パスワードが一致しません"
            exit 1
        fi

        if [[ -z "$password" ]]; then
            log_error "パスワードが空です"
            exit 1
        fi

        # パスワードをハッシュ化
        local hash
        hash=$(openssl passwd -apr1 "$password")
        
        # 既存ユーザーを削除（存在する場合）
        if [[ -f "$HTPASSWD_FILE" ]]; then
            grep -v "^${username}:" "$HTPASSWD_FILE" > "${HTPASSWD_FILE}.tmp" 2>/dev/null || true
            mv "${HTPASSWD_FILE}.tmp" "$HTPASSWD_FILE"
        fi
        
        # 新しいユーザーを追加
        echo "${username}:${hash}" >> "$HTPASSWD_FILE"
    fi
    
    log_success "ユーザー '$username' を追加しました"
    echo ""
    show_users
    show_reload_hint
}

# ===========================================
# ユーザー削除
# ===========================================
cmd_delete() {
    local username="${1:-}"
    
    if [[ -z "$username" ]]; then
        log_error "ユーザー名を指定してください"
        log_error "使用方法: $0 delete <ユーザー名>"
        echo ""
        show_users
        exit 1
    fi
    
    # ファイル存在チェック
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
        log_error ".htpasswdファイルが存在しません"
        exit 1
    fi
    
    # ユーザー存在チェック
    if ! grep -q "^${username}:" "$HTPASSWD_FILE"; then
        log_error "ユーザー '$username' は存在しません"
        exit 1
    fi
    
    log_step "ユーザー '$username' を削除..."
    
    # ユーザーを削除
    grep -v "^${username}:" "$HTPASSWD_FILE" > "${HTPASSWD_FILE}.tmp"
    mv "${HTPASSWD_FILE}.tmp" "$HTPASSWD_FILE"
    
    log_success "ユーザー '$username' を削除しました"
    echo ""
    show_users
    show_reload_hint
}

# ===========================================
# ユーザー一覧表示
# ===========================================
cmd_list() {
    show_users
}

# ===========================================
# ヘルパー関数
# ===========================================
show_users() {
    echo "=== 登録済みユーザー一覧 ==="
    if [[ -f "$HTPASSWD_FILE" ]] && [[ -s "$HTPASSWD_FILE" ]]; then
        cut -d: -f1 "$HTPASSWD_FILE"
        echo ""
        echo "合計: $(wc -l < "$HTPASSWD_FILE" | tr -d ' ') ユーザー"
    else
        echo "(ユーザーなし)"
    fi
}

show_reload_hint() {
    echo ""
    log_info "変更を反映するには: podman-compose exec nginx nginx -s reload"
}

# ===========================================
# メイン
# ===========================================
cd_project_root

command="${1:-}"
shift || true

case "$command" in
    add)
        cmd_add "$@"
        ;;
    delete|del|remove|rm)
        cmd_delete "$@"
        ;;
    list|ls)
        cmd_list
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        log_error "不明なコマンド: $command"
        echo ""
        show_help
        exit 1
        ;;
esac

