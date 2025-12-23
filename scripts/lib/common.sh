#!/bin/bash
# 共通ライブラリ - 全スクリプトで使用する関数と設定

# 厳格なエラーハンドリング
set -euo pipefail

# ===========================================
# 定数
# ===========================================
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
readonly NGINX_DIR="${PROJECT_ROOT}/nginx"
readonly NGINX_CONF_DIR="${NGINX_DIR}/conf.d"
readonly CERTBOT_DIR="${PROJECT_ROOT}/certbot"
readonly DOWNLOADS_DIR="${PROJECT_ROOT}/downloads"
readonly COOKIES_DIR="${PROJECT_ROOT}/cookies"

readonly NGINX_TEMPLATE="${NGINX_CONF_DIR}/rushia-dl.conf.template"
readonly NGINX_CONF="${NGINX_CONF_DIR}/rushia-dl.conf"
readonly HTPASSWD_FILE="${NGINX_DIR}/.htpasswd"

readonly RSA_KEY_SIZE=4096
readonly NGINX_WAIT_TIMEOUT=30
readonly NGINX_WAIT_INTERVAL=2

# ===========================================
# カラー出力
# ===========================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ===========================================
# ログ関数
# ===========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo ""
    echo -e "${GREEN}>>>${NC} $*"
}

# ===========================================
# ユーティリティ関数
# ===========================================

# プロジェクトルートに移動
cd_project_root() {
    cd "$PROJECT_ROOT"
}

# ディレクトリが存在しなければ作成
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "ディレクトリを作成: $dir"
    fi
}

# ファイルが存在するかチェック
require_file() {
    local file="$1"
    local message="${2:-ファイルが見つかりません: $file}"
    if [[ ! -f "$file" ]]; then
        log_error "$message"
        exit 1
    fi
}

# コマンドが存在するかチェック
require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "コマンドが見つかりません: $cmd"
        exit 1
    fi
}

# Yes/No確認
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -r -p "$message [Y/n]: " response
        [[ -z "$response" || "$response" =~ ^[Yy] ]]
    else
        read -r -p "$message [y/N]: " response
        [[ "$response" =~ ^[Yy] ]]
    fi
}

# 環境変数またはデフォルト値を取得
get_env() {
    local var_name="$1"
    local default="${2:-}"
    echo "${!var_name:-$default}"
}

