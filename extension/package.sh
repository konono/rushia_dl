#!/bin/bash
# Chrome Web Store用のパッケージを作成するスクリプト

set -e

cd "$(dirname "$0")"

# パッケージ名
PACKAGE_NAME="rushia-dl-cookie-helper"

# 一時ディレクトリを作成
TEMP_DIR=$(mktemp -d)
echo "一時ディレクトリ: $TEMP_DIR"

# 必要なファイルをコピー
cp manifest.json "$TEMP_DIR/"
cp background.js "$TEMP_DIR/"
cp -r icons "$TEMP_DIR/"

# ZIPファイルを作成
cd "$TEMP_DIR"
zip -r "$PACKAGE_NAME.zip" . -x "*.DS_Store"

# 元のディレクトリに移動
cd - > /dev/null

# ZIPファイルを現在のディレクトリにコピー
cp "$TEMP_DIR/$PACKAGE_NAME.zip" .

# 一時ディレクトリを削除
rm -rf "$TEMP_DIR"

echo "✅ パッケージ作成完了: $PACKAGE_NAME.zip"
echo ""
echo "次のステップ:"
echo "1. Chrome Web Store Developer Dashboardにアクセス"
echo "2. 新しいアイテムを追加"
echo "3. $PACKAGE_NAME.zip をアップロード"
echo "4. STORE_SUBMISSION.md を参照して情報を入力"

