# Web API リファレンス

ベース URL: `http://localhost:8000`（本番: `https://rushiadl.holosco.pe`）

---

## GET /

Web UI（`index.html`）を返す。

---

## POST /api/upload-cookie

YouTube の Cookie ファイル（Netscape 形式）をアップロードする。

### リクエスト

`multipart/form-data`

| フィールド | 型 | 説明 |
|---|---|---|
| `file` | File | cookie.txt（Netscape 形式） |

### レスポンス 200

```json
{
  "cookie_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Cookieファイルがアップロードされました"
}
```

### エラー

| コード | 説明 |
|---|---|
| 400 | ファイル未選択・空ファイル・無効な形式 |

---

## DELETE /api/cookie/{cookie_id}

アップロード済みの Cookie ファイルを削除する。

### パスパラメータ

| パラメータ | 説明 |
|---|---|
| `cookie_id` | アップロード時に返された UUID |

### レスポンス 200

```json
{
  "message": "Cookieファイルが削除されました"
}
```

### エラー

| コード | 説明 |
|---|---|
| 404 | Cookie ファイルが見つからない |

---

## POST /api/download

ダウンロードを開始する。レスポンスはすぐに返り、実際のダウンロードはバックグラウンドで実行される。

### リクエストボディ（JSON）

```json
{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "format": "m4a",
  "cookie_id": null
}
```

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `url` | string | Yes | YouTube URL（各種形式対応） |
| `format` | string | Yes | `"m4a"` または `"mp4"` |
| `cookie_id` | string | No | アップロード済み Cookie の UUID |

### レスポンス 200

```json
{
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "pending",
  "progress": 0
}
```

### エラー

| コード | 説明 |
|---|---|
| 400 | 無効な URL / 無効なフォーマット / ライブ配信中 / 配信予定 |
| 503 | 同時ダウンロード上限（5 件）に達している |

---

## GET /api/status/{task_id}

ダウンロードの進捗を取得する。完了するまでポーリングして使う。

### パスパラメータ

| パラメータ | 説明 |
|---|---|
| `task_id` | ダウンロード開始時に返された UUID |

### レスポンス 200

```json
{
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "downloading",
  "progress": 45.3,
  "filename": null,
  "error": null,
  "title": "動画タイトル",
  "speed": 1048576,
  "eta": 30,
  "downloaded_bytes": 5242880,
  "total_bytes": 10485760,
  "elapsed": 5.2,
  "download_url": null,
  "token_expires_at": null
}
```

#### `status` の値

| 値 | 説明 |
|---|---|
| `pending` | 待機中（キュー） |
| `downloading` | ダウンロード中 |
| `processing` | ffmpeg で変換・マージ中 |
| `completed` | 完了 |
| `error` | エラー |

#### `completed` 時の追加フィールド

```json
{
  "status": "completed",
  "progress": 100,
  "filename": "動画タイトル-VIDEO_ID.m4a",
  "title": "動画タイトル",
  "download_url": "/api/download/%E5%8B%95%E7%94%BB%E3%82%BF%E3%82%A4%E3%83%88%E3%83%AB-VIDEO_ID.m4a?token=TOKEN",
  "token_expires_at": 1700000000.0
}
```

### エラー

| コード | 説明 |
|---|---|
| 404 | タスクが見つからない |

---

## GET /api/download/{filename}

ダウンロードしたファイルを取得する。

### パスパラメータ

| パラメータ | 説明 |
|---|---|
| `filename` | ファイル名（URL エンコード済み） |

### クエリパラメータ

| パラメータ | 必須 | 説明 |
|---|---|---|
| `token` | Yes | ステータス取得時に返されたトークン |

### レスポンス 200

ファイルのバイナリストリーム。

`Content-Type`:
- `.m4a` → `audio/mp4`
- `.mp4` → `video/mp4`

### エラー

| コード | 説明 |
|---|---|
| 401 | トークンが無効 / 有効期限切れ |
| 404 | ファイルが見つからない |

---

## GET /api/server-status

サーバーの稼働状況を取得する。

### レスポンス 200

```json
{
  "active_downloads": 2,
  "max_concurrent_downloads": 5,
  "available_slots": 3,
  "file_retention_hours": 3,
  "task_timeouts": {
    "pending": 3600,
    "downloading": 21600,
    "processing": 10800,
    "completed": 10800,
    "error": 3600
  },
  "cached_files": 5,
  "active_tasks": [
    {
      "task_id": "...",
      "status": "downloading",
      "progress": 45.3,
      "title": "動画タイトル",
      "created_at": 1700000000.0
    }
  ],
  "total_tasks_in_memory": 10
}
```

---

## 典型的な使用フロー

### 通常ダウンロード

```
1. POST /api/download  →  { task_id }
2. GET  /api/status/{task_id}  （繰り返し）
3. GET  /api/download/{filename}?token=TOKEN  （completed 後）
```

### メンバーシップ限定コンテンツ

```
1. POST /api/upload-cookie  →  { cookie_id }
2. POST /api/download  （cookie_id を含める）  →  { task_id }
3. GET  /api/status/{task_id}  （繰り返し）
4. GET  /api/download/{filename}?token=TOKEN
```
