# ローカルでの実行方法

## 前提条件

1. Python 3.14がインストールされていること
2. `uv sync` が完了していること
3. FFmpegがインストールされていること
4. **Denoランタイムがインストールされていること**（yt-dlpのJavaScriptチャレンジ解決に必要）

### Denoのインストール方法

#### macOS (Homebrew)
```bash
brew install deno
```

#### macOS/Linux (公式インストールスクリプト)
```bash
curl -fsSL https://deno.land/install.sh | sh
```

インストール後、PATHに追加する必要がある場合があります：
```bash
# ~/.zshrc または ~/.bashrc に追加
export PATH="$HOME/.deno/bin:$PATH"
```

インストール確認：
```bash
deno --version
```

## 実行方法

### 方法1: uv run を使用（推奨）

```bash
# プロジェクトルートで実行
cd /Users/kono/gitrepo/rushia_dl
uv run rushia-web
```

### 方法2: uvicorn を直接使用

```bash
# プロジェクトルートで実行
cd /Users/kono/gitrepo/rushia_dl
uv run uvicorn rushia_dl.api:app --host 0.0.0.0 --port 8000 --reload
```

### 方法3: Python モジュールとして実行

```bash
# プロジェクトルートで実行
cd /Users/kono/gitrepo/rushia_dl
uv run python -m rushia_dl.api
```

## アクセス方法

サーバー起動後、以下のURLでアクセスできます：

- **ローカル**: http://localhost:8000
- **ネットワーク経由**: http://0.0.0.0:8000 または http://<あなたのIP>:8000

## 必要なディレクトリ

以下のディレクトリが自動的に作成されます：

- `download/` - ダウンロードしたファイルの保存先
- `.cookies/` - アップロードされたCookieファイルの一時保存先

## 拡張機能の動作確認

1. **拡張機能をインストール**
   - Chrome/Edgeで `chrome://extensions/` を開く
   - 「デベロッパーモード」をON
   - 「パッケージ化されていない拡張機能を読み込む」をクリック
   - `extension` ディレクトリを選択

2. **YouTubeにログイン**
   - 通常モードまたはシークレットモードでYouTubeにログイン

3. **Rushia DLにアクセス**
   - http://localhost:8000 を開く
   - 「Cookieを自動取得」ボタンをクリック
   - 自動的にCookieが取得・アップロードされます

## トラブルシューティング

### ポートが既に使用されている場合

```bash
# 別のポートで起動
uv run uvicorn rushia_dl.api:app --host 0.0.0.0 --port 8001
```

### 拡張機能が認識されない場合

- 拡張機能が有効になっているか確認
- ブラウザを再起動
- 拡張機能を再インストール
- コンソールでエラーを確認（F12 → Console）

### Cookieが取得できない場合

- YouTubeにログインしているか確認
- 拡張機能の権限が正しく設定されているか確認
- ブラウザのCookieが有効になっているか確認

## 開発モード（ホットリロード）

開発中は `--reload` オプションを使用すると、コード変更時に自動的に再起動されます：

```bash
uv run uvicorn rushia_dl.api:app --host 0.0.0.0 --port 8000 --reload
```

## ログの確認

サーバーのログはターミナルに出力されます。エラーが発生した場合は、ターミナルの出力を確認してください。

