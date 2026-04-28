# 運用ガイド

## 自動アップグレード

yt-dlp と deno は YouTube の仕様変更に追従するため頻繁なアップデートが必要です。
以下の仕組みで自動化しています。

### GitHub Actions (yt-dlp バージョン追跡)

`.github/workflows/update-yt-dlp.yml` が毎日 PyPI をチェックし、yt-dlp の新バージョンがあれば:

1. Docker イメージをビルドしてスモークテストを実行
2. テスト通過後、バージョン固定済みの PR を自動作成

PR をマージすると `uv.lock` と `requirements.txt` が更新されます。

### サーバー側自動デプロイ

毎日 AM4:00 (JST)、systemd タイマー (`rushia-upgrade.timer`) が `scripts/upgrade-and-deploy.sh` を実行します:

1. `git pull` で最新コードを取得
2. `compose build rushia-dl` でリビルド
3. `compose up -d rushia-dl` で再起動
4. API 起動確認
5. Discord に結果を通知

スモークテストは GitHub CI 側で検証済みのため、本番では実行しません。

### セットアップ手順

```bash
# 1. Discord Webhook URL を設定
cat > .env.webhook << 'EOF'
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxxx/yyyy
EOF
chmod 600 .env.webhook

# 2. systemd ユニットをインストール
./scripts/setup-systemd.sh

# 3. 動作確認
systemctl --user list-timers 'rushia-*'
systemctl --user start rushia-healthcheck.service  # 手動テスト
journalctl --user -u rushia-healthcheck.service     # ログ確認
```

### 手動実行

```bash
# アップグレード (dry-run)
./scripts/upgrade-and-deploy.sh --dry-run

# アップグレード (実行)
./scripts/upgrade-and-deploy.sh

# systemd 経由
systemctl --user start rushia-upgrade.service

# ヘルスチェック
./scripts/healthcheck.sh
```

## systemd ユニット一覧

| ユニット | 種別 | スケジュール | 用途 |
|---|---|---|---|
| `rushia-dl.service` | service | 常駐 | compose up/down |
| `rushia-healthcheck.timer` | timer | 毎時 :07 | ヘルスチェック + Discord 通知 |
| `rushia-upgrade.timer` | timer | 毎日 4:00 | git pull + リビルド + 再デプロイ |
| `rushia-certbot.timer` | timer | 1日2回 (3:00/15:00) | 証明書更新チェック |

```bash
# インストール
./scripts/setup-systemd.sh

# アンインストール
./scripts/setup-systemd.sh --uninstall

# ステータス確認
systemctl --user list-timers 'rushia-*'
systemctl --user status rushia-dl.service
```

## ヘルスチェック

1時間ごとに `scripts/healthcheck.sh` が以下を確認します:

- コンテナが running か
- API が応答するか (`/api/server-status`)
- yt-dlp が動作するか

異常時のみ Discord に通知し、復旧時には復旧通知を送ります（連続通知はしません）。

## トラブルシューティング

### yt-dlp の n challenge エラー

```
WARNING: [youtube] [jsc] Error solving n challenge request using "deno" provider
```

→ yt-dlp または deno のアップデートが必要です:

```bash
systemctl --user start rushia-upgrade.service
```

### 403 Forbidden エラー

1. まず yt-dlp を最新にアップデート (上記)
2. IPv4 でアクセスしているか確認: `yt-dlp.conf` に `--force-ipv4` があること
3. IP 制限の可能性がある場合: ルーターで外部 IP を変更 (`renew-ip.sh`)
