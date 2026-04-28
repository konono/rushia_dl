# アーキテクチャ概要

## システム全体像

```
┌─────────────────────────────────────────────────────┐
│                   クライアント                        │
│                                                     │
│  ブラウザ (Web UI)    CLI (rushia-dl)               │
│       │                    │                        │
│  ブラウザ拡張機能            │                        │
│  (Cookie Helper)           │                        │
└───────┼────────────────────┼────────────────────────┘
        │ HTTP               │ 直接実行
        ▼                    ▼
┌─────────────────┐   ┌─────────────────┐
│  FastAPI Web    │   │   CLI           │
│  (api.py)       │   │   (cli.py)      │
│  port: 8000     │   │                 │
└────────┬────────┘   └────────┬────────┘
         │                     │
         ▼                     ▼
    ┌─────────┐           ┌─────────┐
    │ yt-dlp  │           │ yt-dlp  │
    └────┬────┘           └────┬────┘
         │                     │
         ▼                     ▼
    ┌─────────┐           ┌─────────┐
    │ ffmpeg  │           │ ffmpeg  │
    └─────────┘           └─────────┘
         │                     │
         ▼                     ▼
   ./download/            ./download/
```

## パッケージ構成

```
src/rushia_dl/
├── api.py           # FastAPI Web サーバー
├── cli.py           # CLI エントリーポイント
├── templates/
│   └── index.html   # シングルページ Web UI
└── static/          # 静的アセット（CSS/JS/画像）

extension/           # Chrome/Edge 拡張機能
├── manifest.json    # 拡張機能定義（Manifest V3）
└── background.js    # Service Worker（Cookie 取得ロジック）
```

## Web サーバー（api.py）

### ダウンロードライフサイクル

```
POST /api/download
    │
    ├── URL バリデーション（YouTube のみ）
    ├── ライブ/配信予定チェック
    ├── 同時実行数チェック（最大 5）
    ├── タスク ID 生成
    └── BackgroundTask として download_video() を起動
            │
            ▼ （非同期）
    pending → downloading → processing → completed / error
            │
            ▼
    GET /api/status/{task_id}  でポーリング
            │
            ▼（completed 時）
    GET /api/download/{filename}?token=TOKEN  でファイル取得
```

### 状態管理

- **`download_tasks`**: タスク ID → 状態情報 のインメモリ辞書
- **`filename_to_token`**: ファイル名 → ダウンロードトークン のインメモリ辞書
- サーバー再起動で消去される（永続化なし）

### 並行処理

- `ThreadPoolExecutor`（最大 5 スレッド）
- yt-dlp はブロッキング処理のため `loop.run_in_executor()` で別スレッドに委譲

### ファイル管理

| 項目 | 設定値 |
|---|---|
| ファイル保持時間 | 3 時間 |
| クリーンアップ間隔 | 5 分ごと |
| ダウンロードトークン有効期限 | 180 分 |
| タスクタイムアウト（pending） | 1 時間 |
| タスクタイムアウト（downloading） | 6 時間 |
| タスクタイムアウト（processing/completed） | 3 時間 |

## フォーマット戦略

### M4A（音声のみ）

| 条件 | 方法 |
|---|---|
| Cookie なし | `bestaudio[ext=m4a]` を直接ダウンロード |
| Cookie あり | format 18（360p 動画+音声）をダウンロード → ffmpeg で音声抽出 |

Cookie あり時に format 18 を使うのは、YouTube の SABR ストリーミング環境では
`web` クライアントで音声のみフォーマットが取得できない制約への対処。

### MP4（動画）

`bestvideo[ext=mp4]+bestaudio[ext=m4a]` を ffmpeg でマージ。

## Cookie 処理

1. Web UI から `POST /api/upload-cookie` で cookie.txt をアップロード
2. UUID を付与して `.cookies/{uuid}.txt` に一時保存
3. ダウンロード完了後に削除（セキュリティのため）
4. Cookie 使用時は `player_client: ['web']` のみ使用（android/iOS は Cookie 非対応）
5. Cookie なし時は `player_client: ['android', 'web']` を使用

## URL 正規化

あらゆる YouTube URL を `https://www.youtube.com/watch?v=VIDEO_ID` に正規化。

対応 URL 形式:
- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://www.youtube.com/shorts/VIDEO_ID`
- `https://www.youtube.com/live/VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`

## 主要依存関係

| パッケージ | 役割 |
|---|---|
| `yt-dlp` | コアダウンローダー |
| `fastapi` | Web フレームワーク |
| `uvicorn` | ASGI サーバー |
| `ffmpeg` | 音声抽出・動画マージ（システム依存） |
| `Deno` | yt-dlp の JS チャレンジ解決（システム依存） |
