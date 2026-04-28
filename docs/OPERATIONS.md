# 運用ガイド

## 自動アップグレード

yt-dlp と deno は YouTube の仕様変更に追従するため頻繁なアップデートが必要です。
以下の仕組みで自動化しています。

### GitHub Actions (yt-dlp バージョン追跡)

`.github/workflows/update-yt-dlp.yml` が毎日 PyPI をチェックし、yt-dlp の新バージョンがあれば PR を自動作成します。PR をマージすると `uv.lock` が更新されます。

### サーバー側定期リビルド

週1回(日曜 AM4:00 JST)、`scripts/upgrade-and-deploy.sh` が以下を実行します:

1. `git pull` で最新コードを取得
2. `podman-compose build --no-cache rushia-dl` でリビルド
3. `podman-compose up -d rushia-dl` で再起動
4. ヘルスチェック
5. Discord に結果を通知

### セットアップ手順

```bash
# 1. Discord Webhook URL を設定
cat > /root/gitrepo/rushia_dl/.env.webhook << 'EOF'
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxxx/yyyy
EOF
chmod 600 /root/gitrepo/rushia_dl/.env.webhook

# 2. systemd unit をインストール
sudo cp /root/gitrepo/rushia_dl/systemd/*.service /etc/systemd/system/
sudo cp /root/gitrepo/rushia_dl/systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload

# 3. timer を有効化
sudo systemctl enable --now rushia-upgrade.timer
sudo systemctl enable --now rushia-healthcheck.timer

# 4. 動作確認
sudo systemctl list-timers rushia-*
sudo systemctl start rushia-healthcheck.service  # 手動テスト
sudo journalctl -u rushia-healthcheck.service     # ログ確認
```

### 手動実行

```bash
# アップグレード (dry-run)
./scripts/upgrade-and-deploy.sh --dry-run

# アップグレード (実行)
DISCORD_WEBHOOK_URL=https://... ./scripts/upgrade-and-deploy.sh

# ヘルスチェック
./scripts/healthcheck.sh
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
./scripts/upgrade-and-deploy.sh
```

### 403 Forbidden エラー

1. まず yt-dlp を最新にアップデート (上記)
2. IPv4 でアクセスしているか確認: `yt-dlp.conf` に `--force-ipv4` があること
3. IP 制限の可能性がある場合: ルーターで外部 IP を変更 (`renew-ip.sh`)
