# Rushia DL ドキュメント

Rushia DL は [yt-dlp](https://github.com/yt-dlp/yt-dlp) をベースにした YouTube 動画・音声ダウンローダーです。

## ドキュメント一覧

| ファイル | 内容 |
|---|---|
| [architecture.md](./architecture.md) | アーキテクチャ・設計概要 |
| [api.md](./api.md) | Web API リファレンス |
| [cli.md](./cli.md) | CLI 使い方ガイド |
| [extension.md](./extension.md) | ブラウザ拡張機能ガイド |
| [deployment.md](./deployment.md) | デプロイ手順 |
| [UPDATE_GUIDE.md](./UPDATE_GUIDE.md) | yt-dlp 更新ガイド |

## クイックスタート

### 前提条件

- Python 3.10 以上
- [ffmpeg](https://ffmpeg.org/)
- [Deno](https://deno.land/)（yt-dlp の JS チャレンジ解決に必要）

### インストール

```bash
uv sync
```

### Web サーバー起動

```bash
uv run rushia-web
# または
uv run uvicorn rushia_dl.api:app --host 0.0.0.0 --port 8000 --reload
```

ブラウザで `http://localhost:8000` にアクセスしてください。

### CLI 使用例

```bash
# 動画を MP4 でダウンロード
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f mp4

# 音声を M4A でダウンロード
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f m4a

# ファイルから URL リストを一括ダウンロード
uv run rushia-dl -p urls.txt -f m4a

# メンバーシップ限定コンテンツ（cookie.txt が必要）
uv run rushia-dl -u URL -f m4a -m
```
