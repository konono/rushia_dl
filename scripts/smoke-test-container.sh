#!/bin/bash
# コンテナ内でスモークテストを実行するラッパー
# ローカルに ffmpeg/deno をインストールせずにテスト可能。
# Usage: ./scripts/smoke-test-container.sh [--image TAG] [--build] [--quick] [--ci] [--output FILE]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ===========================================
# コンテナエンジン検出
# ===========================================
detect_engine() {
    if [[ -n "${CONTAINER_CMD:-}" ]]; then
        echo "$CONTAINER_CMD"
        return 0
    fi
    if command -v podman &>/dev/null; then
        echo "podman"
        return 0
    fi
    if command -v docker &>/dev/null; then
        echo "docker"
        return 0
    fi
    log_error "コンテナエンジンが見つかりません（podman / docker）"
    exit 1
}

ENGINE="$(detect_engine)"
log_info "コンテナエンジン: $ENGINE"

# ===========================================
# 引数解析
# ===========================================
IMAGE_TAG=""
FORCE_BUILD=false
OUTPUT_FILE=""
INNER_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            IMAGE_TAG="$2"; shift 2 ;;
        --build)
            FORCE_BUILD=true; shift ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2 ;;
        --quick|--ci)
            INNER_ARGS+=("$1"); shift ;;
        *)
            shift ;;
    esac
done

DEFAULT_TAG="rushia-dl:smoke-test"
if [[ -z "$IMAGE_TAG" ]]; then
    IMAGE_TAG="$DEFAULT_TAG"
fi

# ===========================================
# イメージのビルド（必要な場合）
# ===========================================
image_exists() {
    $ENGINE image inspect "$1" &>/dev/null
}

if [[ "$IMAGE_TAG" != "$DEFAULT_TAG" ]]; then
    # --image で明示指定 → ビルドしない
    if ! image_exists "$IMAGE_TAG"; then
        log_error "イメージが見つかりません: $IMAGE_TAG"
        exit 1
    fi
    log_info "既存イメージを使用: $IMAGE_TAG"
elif $FORCE_BUILD || ! image_exists "$IMAGE_TAG"; then
    log_step "イメージをビルド: $IMAGE_TAG"
    $ENGINE build -t "$IMAGE_TAG" "$PROJECT_ROOT"
else
    log_info "既存イメージを使用: $IMAGE_TAG"
fi

# ===========================================
# ボリュームマウントの準備
# ===========================================
VOLUMES=(
    -v "$SCRIPTS_DIR/smoke-test.sh:/app/scripts/smoke-test.sh:ro"
)

if [[ -f "$PROJECT_ROOT/yt-dlp.conf" ]]; then
    VOLUMES+=(-v "$PROJECT_ROOT/yt-dlp.conf:/etc/yt-dlp.conf:ro")
fi

TMPDIR_HOST=""
if [[ -n "$OUTPUT_FILE" ]]; then
    TMPDIR_HOST="$(mktemp -d)"
    VOLUMES+=(-v "$TMPDIR_HOST:/tmp/smoke-output:z")
    INNER_ARGS+=(--output /tmp/smoke-output/results.md)
fi

# ===========================================
# コンテナ内でスモークテスト実行
# ===========================================
log_step "スモークテスト実行"

set +e
$ENGINE run --rm \
    --entrypoint bash \
    "${VOLUMES[@]}" \
    "$IMAGE_TAG" \
    /app/scripts/smoke-test.sh "${INNER_ARGS[@]}"
EXIT_CODE=$?
set -e

# ===========================================
# 出力ファイルの抽出
# ===========================================
if [[ -n "$TMPDIR_HOST" ]]; then
    if [[ -f "$TMPDIR_HOST/results.md" ]]; then
        cp "$TMPDIR_HOST/results.md" "$OUTPUT_FILE"
        log_info "結果を出力: $OUTPUT_FILE"
    else
        log_warn "結果ファイルが見つかりません"
    fi
    rm -rf "$TMPDIR_HOST"
fi

exit "$EXIT_CODE"
