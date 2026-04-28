# CLI 使い方ガイド

`rushia-dl` コマンドは YouTube 動画・音声をコマンドラインからダウンロードするツールです。
ダウンロード先は実行ディレクトリの `./download/` フォルダです。

## 基本構文

```bash
uv run rushia-dl [オプション]
```

## オプション一覧

| オプション | 必須 | 説明 |
|---|---|---|
| `-u URL`, `--url URL` | `-u` か `-p` どちらか必須 | ダウンロードする YouTube URL |
| `-p PATH`, `--path PATH` | `-u` か `-p` どちらか必須 | URL リストファイルのパス |
| `-f FORMAT`, `--format FORMAT` | Yes | 出力フォーマット: `m4a`（音声）または `mp4`（動画） |
| `-m`, `--membership` | No | メンバーシップ限定コンテンツを指定 |
| `-c FILE`, `--cookie FILE` | No | Cookie ファイルのパス（デフォルト: `./cookie.txt`） |

> `-u` と `-p` は排他オプションです。同時に指定できません。

## 使用例

### 動画を MP4 でダウンロード

```bash
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f mp4
```

### 音声を M4A でダウンロード

```bash
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f m4a
```

### URL リストから一括ダウンロード

`urls.txt` の各行に YouTube URL を1つずつ記載する:

```
https://www.youtube.com/watch?v=VIDEO_ID_1
https://www.youtube.com/watch?v=VIDEO_ID_2
https://www.youtube.com/watch?v=VIDEO_ID_3
```

```bash
uv run rushia-dl -p urls.txt -f m4a
```

### メンバーシップ限定コンテンツ

```bash
# デフォルトの ./cookie.txt を使用
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f m4a -m

# Cookie ファイルのパスを指定
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f m4a -m -c /path/to/cookie.txt
```

## Cookie ファイルの取得方法

メンバーシップ限定コンテンツには YouTube にログインした状態の Cookie が必要です。

### 方法 1: ブラウザ拡張機能（推奨）

「Rushia DL Cookie Helper」拡張機能を使うと、Web UI 上で YouTube Cookie を自動取得できます。
詳細は [extension.md](./extension.md) を参照。

### 方法 2: get-cookies.txt 拡張機能

Chrome/Edge 拡張機能「get-cookies.txt LOCALLY」などで Netscape 形式の Cookie ファイルをエクスポートし、
`cookie.txt` として保存する。

## フォーマット詳細

### M4A（音声のみ）

- `bestaudio[ext=m4a]` を優先ダウンロード
- M4A 以外の形式の場合は ffmpeg で変換

### MP4（動画）

- `bestvideo[ext=mp4]+bestaudio[ext=m4a]` を ffmpeg でマージ
- 最高品質の組み合わせを選択

## 注意事項

- ダウンロードしたファイルは `./download/` に保存されます（自動作成）
- yt-dlp は頻繁に更新されます。問題が発生した場合は `./scripts/update-yt-dlp.sh` で更新してください
- ffmpeg と Deno がシステムにインストールされている必要があります
