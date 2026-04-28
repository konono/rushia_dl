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

# ---- OS / アーキテクチャ検出 ----
detect_platform() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$OS" in
    linux|darwin) ;;
    *) die "未対応OS: $OS" ;;
  esac

  case "$ARCH" in
    x86_64)        ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    i386|i686)     ARCH="386" ;;
    *)             die "未対応アーキテクチャ: $ARCH" ;;
  esac
}

# ---- GitHub Releases からバイナリインストール ----
install_direnv() {
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

  if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
    warn "${install_dir} が PATH に含まれていません"
    echo "  以下をシェル設定ファイルに追加してください:"
    echo "    export PATH=\"${install_dir}:\$PATH\""
  fi
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

  if [[ ! -f "$rc_file" ]]; then
    mkdir -p "$(dirname "$rc_file")"
    touch "$rc_file"
  fi

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

  detect_platform
  info "検出: OS=${OS} ARCH=${ARCH}"

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
  install_direnv

  echo ""
  if command -v direnv &>/dev/null; then
    info "direnv $(direnv version) をインストールしました"
  else
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
