#!/bin/bash
# rushia-dl スモークテスト
# コンテナ内でもローカルでも実行可能。
# 実際のダウンロードは行わず、メタデータ取得とフォーマット確認のみ。
# Usage: ./scripts/smoke-test.sh [--quick] [--output FILE]
#   --quick: バイナリチェックのみ（ネットワークアクセスなし）
#   --output FILE: テスト結果をファイルにも出力（CI の PR body 埋め込み用）

set -uo pipefail

QUICK=false
OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --quick)  QUICK=true; shift ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        *)        shift ;;
    esac
done

TEST_VIDEO="https://www.youtube.com/shorts/TEcRTgN75bQ"
PASSED=0
FAILED=0
WARNED=0
RESULTS=()

pass() {
    PASSED=$((PASSED + 1))
    RESULTS+=("✅ $1")
    echo "✅ $1"
}

warn() {
    WARNED=$((WARNED + 1))
    RESULTS+=("⚠️ $1")
    echo "⚠️ $1"
}

fail() {
    FAILED=$((FAILED + 1))
    RESULTS+=("❌ $1: $2")
    echo "❌ $1: $2" >&2
}

echo "=== rushia-dl smoke test ==="
echo ""

# 1. yt-dlp
echo "--- Binary checks ---"
if YTDLP_VER=$(yt-dlp --version 2>&1); then
    pass "yt-dlp $YTDLP_VER"
else
    fail "yt-dlp" "not found or broken"
fi

# 2. ffmpeg
if FFMPEG_VER=$(ffmpeg -version 2>&1 | head -1 | awk '{print $3}'); then
    pass "ffmpeg $FFMPEG_VER"
else
    fail "ffmpeg" "not found"
fi

# 3. deno
if DENO_VER=$(deno --version 2>&1 | head -1); then
    pass "deno $DENO_VER"
else
    fail "deno" "not found"
fi

# 4. yt-dlp.conf (コンテナ外では warning)
if [[ -f /etc/yt-dlp.conf ]]; then
    if grep -q "force-ipv4" /etc/yt-dlp.conf; then
        pass "yt-dlp.conf --force-ipv4"
    else
        warn "yt-dlp.conf: missing --force-ipv4"
    fi
else
    warn "yt-dlp.conf: /etc/yt-dlp.conf not found (OK if running outside container)"
fi

# 5. API server (コンテナ外では warning)
if curl -sf http://localhost:8000/api/server-status >/dev/null 2>&1; then
    pass "API server responding"
else
    warn "API server: not responding (OK if running outside container)"
fi

if $QUICK; then
    echo ""
    echo "--- Quick mode: skipping network tests ---"
else
    echo ""
    echo "--- Network tests (using $TEST_VIDEO) ---"

    # 6. メタデータ取得 (n challenge 解決の検証)
    echo "  Fetching metadata..."
    DUMP_FILE=$(mktemp)
    DUMP_STDERR=$(mktemp)
    yt-dlp --dump-json --no-download "$TEST_VIDEO" >"$DUMP_FILE" 2>"$DUMP_STDERR"
    DUMP_EXIT=$?

    if [[ $DUMP_EXIT -eq 0 && -s "$DUMP_FILE" ]]; then
        TITLE=$(python3 -c "import sys,json; print(json.load(open('$DUMP_FILE')).get('title',''))" 2>/dev/null || echo "")
        if [[ -n "$TITLE" ]]; then
            pass "metadata fetch: $TITLE"
        else
            FORMATS_COUNT=$(python3 -c "import sys,json; print(len(json.load(open('$DUMP_FILE')).get('formats',[])))" 2>/dev/null || echo "0")
            if [[ "$FORMATS_COUNT" -gt 0 ]]; then
                pass "metadata fetch: $FORMATS_COUNT formats found (no title)"
            else
                fail "metadata fetch" "JSON returned but no title or formats"
            fi
        fi
    else
        STDERR_CONTENT=$(cat "$DUMP_STDERR")
        if echo "$STDERR_CONTENT" | grep -qi "challenge\|only images"; then
            fail "n challenge" "JS challenge solving failed (deno/yt-dlp update needed)"
        else
            fail "metadata fetch" "exit=$DUMP_EXIT"
        fi
    fi
    rm -f "$DUMP_FILE" "$DUMP_STDERR"

    # 7. フォーマット一覧の取得
    echo "  Checking available formats..."
    FORMAT_OUTPUT=$(yt-dlp --list-formats "$TEST_VIDEO" 2>&1)
    FORMAT_EXIT=$?

    if [[ $FORMAT_EXIT -eq 0 ]]; then
        HAS_AUDIO=$(echo "$FORMAT_OUTPUT" | grep -ci "audio only" || true)
        HAS_VIDEO=$(echo "$FORMAT_OUTPUT" | grep -ci "video only\|mp4" || true)

        if [[ $HAS_AUDIO -gt 0 && $HAS_VIDEO -gt 0 ]]; then
            pass "formats available (audio: $HAS_AUDIO, video: $HAS_VIDEO)"
        elif [[ $HAS_AUDIO -gt 0 ]]; then
            pass "audio formats available ($HAS_AUDIO) but no video formats"
        else
            fail "format check" "no audio/video formats found"
        fi
    else
        fail "format check" "list-formats failed (exit=$FORMAT_EXIT)"
    fi
fi

# Summary
echo ""
echo "=== Results: $PASSED passed, $FAILED failed, $WARNED warnings ==="

if [[ -n "$OUTPUT_FILE" ]]; then
    {
        echo "### Smoke Test Results"
        echo ""
        for r in "${RESULTS[@]}"; do
            echo "- $r"
        done
        echo ""
        echo "**$PASSED passed, $FAILED failed, $WARNED warnings**"
    } > "$OUTPUT_FILE"
fi

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for r in "${RESULTS[@]}"; do
        if [[ "$r" == ❌* ]]; then
            echo "  $r"
        fi
    done
    exit 1
fi

exit 0
