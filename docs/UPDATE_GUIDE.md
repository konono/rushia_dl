# yt-dlp 自動更新ガイド

yt-dlpは頻繁に更新されるため、自動更新の仕組みを用意しています。

## 自動更新の方法

### 1. GitHub Actions（推奨）

毎日自動的にyt-dlpの最新バージョンをチェックし、更新がある場合はPull Requestを作成します。

- **スケジュール**: 毎日午前3時（UTC）、日本時間では12時
- **動作**: 最新バージョンを検出 → PR作成 → マージ後に自動反映

#### 手動実行
GitHubのActionsタブから「Update yt-dlp」ワークフローを手動実行できます。

### 2. Dependabot

GitHubのDependabotがyt-dlpの更新を検出してPRを作成します。

- **スケジュール**: 毎日午前3時（UTC）
- **設定**: `.github/dependabot.yml`

### 3. 手動更新スクリプト

ローカルで手動更新する場合：

```bash
./scripts/update-yt-dlp.sh
```

このスクリプトは：
1. 現在のバージョンを確認
2. 最新バージョンを取得
3. 更新があれば`uv sync`で更新
4. `uv.lock`を更新

## 更新後の確認事項

### 1. 依存関係の確認

```bash
uv sync
```

### 2. 動作確認

```bash
# サーバーを起動
uv run rushia-web

# テストダウンロードを実行
# ブラウザで http://localhost:8000 にアクセスしてテスト
```

### 3. Dockerイメージの更新

Dockerfileでもyt-dlpをインストールしている場合、Dockerイメージも更新が必要です：

```bash
docker build -t rushia-dl .
```

## トラブルシューティング

### 依存関係の競合

更新後に依存関係の競合が発生した場合：

```bash
# 依存関係を再解決
uv sync --upgrade-all
uv lock
```

### 動作不良

yt-dlpの更新で動作不良が発生した場合：

1. 問題を報告（GitHub Issues）
2. 一時的に前のバージョンに戻す：

```bash
# pyproject.tomlでバージョンを固定
# "yt-dlp==2025.12.08" のように指定
uv sync
uv lock
```

## 更新頻度の調整

### GitHub Actionsのスケジュール変更

`.github/workflows/update-yt-dlp.yml`の`cron`設定を変更：

```yaml
schedule:
  - cron: '0 3 * * *'  # 毎日午前3時（UTC）
  # 例: '0 */6 * * *'  # 6時間ごと
  # 例: '0 0 * * 1'    # 毎週月曜日
```

### Dependabotのスケジュール変更

`.github/dependabot.yml`の`schedule`セクションを変更：

```yaml
schedule:
  interval: "daily"  # daily, weekly, monthly
  time: "03:00"
```

## ベストプラクティス

1. **PRをマージする前にテスト**
   - 自動生成されたPRをマージする前に、必ずテストを実行

2. **メジャーバージョンアップに注意**
   - 破壊的変更の可能性があるため、慎重に確認

3. **更新ログの確認**
   - yt-dlpのリリースノートを確認して、重要な変更を把握

4. **定期的な確認**
   - 週に1回程度、更新状況を確認

## 参考リンク

- [yt-dlp GitHub](https://github.com/yt-dlp/yt-dlp)
- [yt-dlp PyPI](https://pypi.org/project/yt-dlp/)
- [uv Documentation](https://github.com/astral-sh/uv)

