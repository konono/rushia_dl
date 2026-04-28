# Chrome Web Store 公開ガイド

## 必要な準備

### 1. Chrome Developerアカウント
- [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/developer/dashboard)にアクセス
- Googleアカウントでログイン
- デベロッパー登録（$5の登録料が必要、一度限り）

### 2. 必要なファイル

#### 必須ファイル
- ✅ `manifest.json` - 拡張機能の設定
- ✅ `background.js` - バックグラウンド処理
- ✅ `icons/` - アイコン（16, 32, 48, 128px）
- ✅ `PRIVACY_POLICY.md` - プライバシーポリシー（公開URLが必要）

#### 申請時に必要な情報
- 拡張機能の説明（日本語・英語）
- スクリーンショット（1280x800または640x400、最低1枚）
- カテゴリ選択
- プライバシーポリシーのURL

### 3. パッケージ化

```bash
cd extension
zip -r rushia-dl-cookie-helper.zip . -x "*.md" -x "*.py" -x "*.png" -x ".git*"
```

または、以下のファイルのみを含める：
- manifest.json
- background.js
- icons/（すべてのアイコンファイル）

## 申請時の注意点

### Cookie権限の説明
Chrome Web Storeでは、Cookieを扱う拡張機能に対して厳格な審査があります。以下の点を明確に説明する必要があります：

1. **なぜCookie権限が必要か**
   - YouTubeのメンバーシップ限定コンテンツをダウンロードするために必要
   - ユーザーが明示的に要求した場合のみ使用

2. **データの使用目的**
   - 取得したCookieは、Rushia DL Webアプリにのみ送信
   - 外部への送信なし
   - ローカル保存なし

3. **セキュリティ**
   - オープンソースでソースコードを確認可能
   - 許可されたドメインからのみリクエストを受け付け

### 説明文の例（日本語）

```
Rushia DL Cookie Helper

Rushia DL Webアプリと連携して、YouTubeのCookieを簡単に取得できる拡張機能です。

【主な機能】
- YouTubeのCookieを自動取得
- Rushia DL Webアプリと自動連携
- メンバーシップ限定コンテンツのダウンロードをサポート

【使用方法】
1. YouTubeにログイン
2. Rushia DLのWebページを開く
3. 「Cookieを自動取得」ボタンをクリック

【セキュリティ】
- Cookie情報は外部に送信されません
- 許可されたドメインからのみリクエストを受け付けます
- オープンソースでソースコードを確認できます

【必要な権限】
- cookies: YouTubeのCookieを取得するために必要です
- これらの権限は、ユーザーが明示的に「Cookieを自動取得」ボタンをクリックした場合のみ使用されます
```

### 説明文の例（英語）

```
Rushia DL Cookie Helper

A lightweight browser extension that helps you easily export YouTube cookies for use with Rushia DL web application.

【Features】
- Automatically retrieve YouTube cookies
- Seamless integration with Rushia DL web app
- Support for membership-only content downloads

【How to Use】
1. Log in to YouTube
2. Open Rushia DL web page
3. Click "Cookieを自動取得" (Auto Get Cookie) button

【Security】
- Cookie data is not sent to external servers
- Only accepts requests from authorized domains
- Open source - you can review the source code

【Required Permissions】
- cookies: Required to retrieve YouTube cookies
- These permissions are only used when you explicitly click the "Cookieを自動取得" button
```

## 審査のポイント

### 通過しやすい理由
1. ✅ オープンソース（透明性）
2. ✅ 外部送信なし（プライバシー保護）
3. ✅ 特定のWebアプリとの連携のみ（用途が明確）
4. ✅ ユーザーが明示的に操作した場合のみ動作

### 注意が必要な点
1. ⚠️ Cookie権限は審査が厳しい
2. ⚠️ プライバシーポリシーが必須
3. ⚠️ 権限の必要性を明確に説明する必要がある

## プライバシーポリシーの公開

プライバシーポリシーは、公開されたURLでアクセス可能である必要があります。

推奨方法：
1. GitHubリポジトリの`PRIVACY_POLICY.md`を公開
2. または、Webサイトにプライバシーポリシーページを作成

例：`https://github.com/[username]/rushia_dl/blob/main/extension/PRIVACY_POLICY.md`

## スクリーンショットの準備

最低1枚、推奨3-5枚のスクリーンショットが必要です。

推奨サイズ：
- 1280x800px（推奨）
- または 640x400px

撮影内容：
1. 拡張機能のアイコン
2. Rushia DL Webアプリでの使用例
3. 「Cookieを自動取得」ボタンの画面

## 申請手順

1. [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/developer/dashboard)にログイン
2. 「新しいアイテム」をクリック
3. ZIPファイルをアップロード
4. 必要な情報を入力：
   - 名前: Rushia DL Cookie Helper
   - 説明: 上記の説明文を使用
   - カテゴリ: ユーティリティ
   - スクリーンショット: 準備した画像をアップロード
   - プライバシーポリシーURL: 公開したURLを入力
5. 送信して審査を待つ（通常1-3週間）

## 審査後の対応

- 審査が通過したら、自動的に公開されます
- 拒否された場合、理由を確認して修正・再申請

## トラブルシューティング

### よくある拒否理由
1. **プライバシーポリシーが不十分**
   → より詳細な説明を追加

2. **権限の説明が不十分**
   → なぜその権限が必要かを明確に説明

3. **機能の説明が不十分**
   → より具体的な使用例を追加

## 参考リンク

- [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/developer/dashboard)
- [Chrome拡張機能の公開ガイド](https://developer.chrome.com/docs/webstore/publish/)
- [プライバシーポリシーの要件](https://developer.chrome.com/docs/webstore/user-data/)

