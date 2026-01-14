# Rushia DL Cookie Helper

Rushia DL専用の軽量Cookie取得拡張機能です。

## 機能

- YouTubeのCookieを自動取得
- Netscape形式でエクスポート
- Rushia DL Webアプリと自動連携

## インストール方法

### Chrome / Edge

1. このディレクトリをダウンロードまたはクローン
2. Chrome/Edgeで `chrome://extensions/` を開く
3. 「デベロッパーモード」を有効化
4. 「パッケージ化されていない拡張機能を読み込む」をクリック
5. この `extension` ディレクトリを選択

### Firefox

1. このディレクトリをダウンロードまたはクローン
2. Firefoxで `about:debugging` を開く
3. 「このFirefox」タブを選択
4. 「一時的なアドオンを読み込む」をクリック
5. `extension/manifest.json` を選択

## 使用方法

1. YouTubeにログイン
2. Rushia DLのWebページを開く
3. 「Cookieを自動取得」ボタンをクリック
4. 自動的にCookieが取得・アップロードされます

## セキュリティ

- 許可されたドメインからのみリクエストを受け付けます
- Cookie情報は外部に送信されません
- オープンソースでソースコードを確認できます

## 開発

### ファイル構成

```
extension/
├── manifest.json      # 拡張機能の設定
├── background.js      # バックグラウンド処理（Cookie取得）
├── icons/            # アイコン
└── README.md         # このファイル
```

### パッケージ化

Chrome Web Storeに公開する場合：

1. `manifest.json` の `version` を更新
2. アイコンを準備（16, 32, 48, 128px）
3. ZIPファイルに圧縮
4. Chrome Web Store Developer Dashboardでアップロード

## ライセンス

MIT License

