#!/bin/bash
# yt-dlpを手動で更新するスクリプト

set -e

echo "🔍 Checking current yt-dlp version..."
CURRENT=$(uv pip list | grep yt-dlp | awk '{print $2}' || echo "unknown")
echo "Current: $CURRENT"

echo ""
echo "🔍 Checking latest yt-dlp version..."
LATEST=$(uv pip index versions yt-dlp 2>/dev/null | grep -oP 'Available versions: \K[^,]+' | awk '{print $1}' || \
         curl -s https://pypi.org/pypi/yt-dlp/json | jq -r '.info.version' || \
         echo "unknown")
echo "Latest: $LATEST"

if [ "$CURRENT" = "$LATEST" ] || [ "$LATEST" = "unknown" ]; then
    echo "✅ yt-dlp is already up to date!"
    exit 0
fi

echo ""
echo "📦 Updating yt-dlp from $CURRENT to $LATEST..."
uv sync --upgrade-package yt-dlp
uv lock

echo ""
echo "✅ Update complete!"
echo ""
echo "Next steps:"
echo "1. Test the application: uv run rushia-web"
echo "2. Commit changes: git add pyproject.toml uv.lock && git commit -m 'chore: update yt-dlp to $LATEST'"
echo "3. Push: git push"

