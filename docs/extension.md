# ブラウザ拡張機能ガイド

**Rushia DL Cookie Helper** は Chrome / Edge 向けの拡張機能です。
YouTube にログインしたブラウザから Cookie を取得し、Rushia DL Web アプリに送信します。
メンバーシップ限定コンテンツのダウンロードに使用します。

## 仕組み

```
YouTube (ブラウザ)
    │
    │ chrome.cookies.getAll()
    ▼
拡張機能 (background.js)
    │ Netscape 形式に変換
    │ chrome.runtime.onMessageExternal
    ▼
Rushia DL Web UI
    │ POST /api/upload-cookie
    ▼
Web サーバー (api.py)
```

1. Web UI が拡張機能に `exportCookies` メッセージを送信
2. 拡張機能が `youtube.com` の Cookie を取得し Netscape 形式に変換
3. Web UI が変換済み Cookie を `POST /api/upload-cookie` でサーバーに送信
4. サーバーは Cookie を一時ファイルに保存し、ダウンロード完了後に削除

## インストール

Chrome / Edge の拡張機能管理ページ（`chrome://extensions/`）で開発者モードを有効にし、
`extension/` フォルダを「パッケージ化されていない拡張機能を読み込む」でインストールします。

詳細は `extension/INSTALL.md` を参照してください。

## 接続可能なドメイン（externally_connectable）

拡張機能が応答するドメインは `manifest.json` で制限されています:

| ドメイン | 用途 |
|---|---|
| `http://localhost:*` | ローカル開発 |
| `http://127.0.0.1:*` | ローカル開発 |
| `http://0.0.0.0:*` | ローカル開発 |
| `https://rushiadl.holosco.pe` | 本番環境 |

## メッセージ仕様

Web UI から拡張機能へ `chrome.runtime.sendMessage()` で送信します。

### exportCookies

YouTube Cookie を Netscape 形式で取得する。

**リクエスト:**
```json
{
  "action": "exportCookies",
  "domain": "youtube.com",
  "format": "netscape"
}
```

**レスポンス（成功）:**
```json
{
  "success": true,
  "cookies": "# Netscape HTTP Cookie File\n...",
  "count": 42,
  "domain": "youtube.com"
}
```

**レスポンス（エラー）:**
```json
{
  "error": "エラーメッセージ",
  "message": "詳細"
}
```

### ping

拡張機能がインストールされているか確認する。

**リクエスト:**
```json
{ "action": "ping" }
```

**レスポンス:**
```json
{
  "success": true,
  "message": "Rushia DL Cookie Helper is ready",
  "version": "1.0.0"
}
```

## セキュリティ

- 許可ドメイン以外からのリクエストは拒否
- Cookie はダウンロード完了後にサーバーから自動削除
- 拡張機能に `cookies` パーミッションと `<all_urls>` ホストパーミッションが必要（Cookie 読み取りのため）

## 注意事項

- YouTube にログインした状態のブラウザで使用する必要があります
- メンバーシップ限定コンテンツはメンバーシップに加入したアカウントの Cookie が必要です
