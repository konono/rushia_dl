#!/usr/bin/env bash
set -euo pipefail

# ---- 色付き出力 ----
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' YELLOW='' RED='' BOLD='' RESET=''
fi

info()  { echo -e "${GREEN}==> $*${RESET}"; }
warn()  { echo -e "${YELLOW}==> $*${RESET}"; }
error() { echo -e "${RED}==> ERROR: $*${RESET}" >&2; }
die()   { error "$@"; exit 1; }

# ---- OS / ディストロ検出 ----
detect_os() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$ARCH" in
    x86_64)           ARCH="amd64" ;;
    aarch64|arm64)    ARCH="arm64" ;;
    i386|i686)        ARCH="386" ;;
    *)                die "未対応アーキテクチャ: $ARCH" ;;
  esac

  DISTRO=""
  if [[ "$OS" == "linux" ]] && [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
  fi
}

# ---- パッケージマネージャでインストール ----
install_with_brew()   { info "Homebrew でインストール中...";   brew install direnv; }
install_with_apt()    { info "apt でインストール中...";        sudo apt-get update -qq && sudo apt-get install -y -qq direnv; }
install_with_dnf()    { info "dnf でインストール中...";        sudo dnf install -y -q direnv; }
install_with_pacman() { info "pacman でインストール中...";     sudo pacman -S --noconfirm --needed direnv; }
install_with_apk()    { info "apk でインストール中...";        sudo apk add --quiet direnv; }

# ---- GitHub Releases からバイナリインストール ----
install_from_binary() {
  local url="https://github.com/direnv/direnv/releases/latest/download/direnv.${OS}-${ARCH}"
  local install_dir

  if [[ $EUID -eq 0 ]]; then
    install_dir="/usr/local/bin"
  else
    install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"
  fi

  info "GitHub Releases からバイナリをダウンロード中..."
  echo "  URL: $url"
  echo "  配置先: ${install_dir}/direnv"

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "${install_dir}/direnv"
  elif command -v wget &>/dev/null; then
    wget -q "$url" -O "${install_dir}/direnv"
  else
    die "curl または wget が必要です"
  fi

  chmod +x "${install_dir}/direnv"

  # PATH に含まれていなければ警告
  if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
    warn "${install_dir} が PATH に含まれていません"
    echo "  以下をシェル設定ファイルに追加してください:"
    echo "    export PATH=\"${install_dir}:\$PATH\""
  fi
}

# ---- インストール実行 ----
do_install() {
  case "$OS" in
    darwin)
      if command -v brew &>/dev/null; then
        install_with_brew
      else
        install_from_binary
      fi
      ;;
    linux)
      case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
          install_with_apt ;;
        fedora|rhel|centos|rocky|alma|almalinux)
          install_with_dnf ;;
        arch|manjaro|endeavouros)
          install_with_pacman ;;
        alpine)
          install_with_apk ;;
        *)
          # ID_LIKE でフォールバック判定
          if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
            install_with_apt
          elif [[ "$DISTRO_LIKE" == *"rhel"* ]] || [[ "$DISTRO_LIKE" == *"fedora"* ]]; then
            install_with_dnf
          elif [[ "$DISTRO_LIKE" == *"arch"* ]]; then
            install_with_pacman
          else
            warn "ディストロ '${DISTRO}' のパッケージマネージャが不明です。バイナリを直接ダウンロードします。"
            install_from_binary
          fi
          ;;
      esac
      ;;
    *)
      die "未対応OS: $OS"
      ;;
  esac
}

# ---- シェルフック設定 (冪等) ----
setup_shell_hook() {
  local shell_name rc_file hook_line

  shell_name="$(basename "${SHELL:-/bin/bash}")"

  case "$shell_name" in
    bash)
      rc_file="${HOME}/.bashrc"
      hook_line='eval "$(direnv hook bash)"'
      ;;
    zsh)
      rc_file="${HOME}/.zshrc"
      hook_line='eval "$(direnv hook zsh)"'
      ;;
    fish)
      rc_file="${HOME}/.config/fish/config.fish"
      hook_line='direnv hook fish | source'
      ;;
    *)
      warn "シェル '${shell_name}' のフック自動設定には対応していません"
      echo "  手動で設定してください: https://direnv.net/docs/hook.html"
      return 0
      ;;
  esac

  info "シェルフック設定 (${shell_name})"

  # rcファイルがなければ作成
  if [[ ! -f "$rc_file" ]]; then
    mkdir -p "$(dirname "$rc_file")"
    touch "$rc_file"
  fi

  # 冪等チェック: 既に存在すればスキップ
  if grep -qF "$hook_line" "$rc_file"; then
    echo "  ${rc_file} に既に設定済みです。スキップします。"
  else
    echo "" >> "$rc_file"
    echo "# direnv" >> "$rc_file"
    echo "$hook_line" >> "$rc_file"
    echo "  ${rc_file} に追記しました。"
  fi
}

# ---- メイン ----
main() {
  echo -e "${BOLD}direnv インストーラー${RESET}"
  echo ""

  detect_os
  info "検出: OS=${OS} ARCH=${ARCH} DISTRO=${DISTRO:-N/A}"

  # 既にインストール済みか確認
  if command -v direnv &>/dev/null; then
    local current_version
    current_version="$(direnv version 2>/dev/null || echo "unknown")"
    warn "direnv は既にインストールされています (v${current_version})"
    echo ""
    read -rp "再インストールしますか？ [y/N] " answer
    if [[ "${answer,,}" != "y" ]]; then
      info "インストールをスキップし、シェルフック設定のみ確認します。"
      setup_shell_hook
      echo ""
      info "完了!"
      return 0
    fi
  fi

  echo ""
  do_install

  # インストール確認
  echo ""
  if command -v direnv &>/dev/null; then
    info "direnv $(direnv version) をインストールしました"
  else
    # PATHが通っていない場合のためにフルパスで確認
    if [[ -x "${HOME}/.local/bin/direnv" ]]; then
      info "direnv $("${HOME}/.local/bin/direnv" version) をインストールしました"
    else
      die "インストールに失敗しました"
    fi
  fi

  echo ""
  setup_shell_hook

  echo ""
  info "完了!"
  echo ""
  echo "次のステップ:"
  echo "  1. シェルを再起動: exec \$SHELL"
  echo "  2. プロジェクトで .envrc を作成: echo 'export FOO=bar' > .envrc"
  echo "  3. 許可: direnv allow"
}

main "$@"
