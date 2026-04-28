# デプロイ手順

## 構成

Docker Compose（または Podman Compose）で以下の 3 サービスを運用します:

| サービス | イメージ | 役割 |
|---|---|---|
| `rushia-dl` | ローカルビルド | uvicorn（FastAPI アプリ） |
| `nginx` | `nginx:alpine` | リバースプロキシ / SSL 終端 |
| `certbot` | `certbot/dns-cloudflare` | Let's Encrypt 証明書更新（ユーティリティ、systemd タイマーから実行） |

## ネットワーク

IPv6 対応のブリッジネットワーク `rushia_ipv6` を使用します。

```
外部（80/443）→ nginx → rushia-dl（8000）
```

## ボリューム

| ホスト | コンテナ | 用途 |
|---|---|---|
| `./downloads/` | `/app/downloads` | ダウンロードしたファイル |
| `./cookies/` | `/app/.cookies` | 一時 Cookie ファイル |
| `./nginx/nginx.conf` | `/etc/nginx/nginx.conf` | nginx 設定 |
| `./certbot/conf` | `/etc/letsencrypt` | TLS 証明書 |

## 起動

```bash
# Docker
docker compose up -d

# Podman（本番環境: OCI ARM / AlmaLinux）
podman-compose up -d
```

## ログ確認

```bash
docker compose logs -f rushia-dl
docker compose logs -f nginx
```

## yt-dlp 更新

GitHub Actions が毎日新バージョンを検出し、スモークテスト済みの PR を自動作成します。
PR マージ後、systemd タイマーが毎日4:00に自動デプロイします。

手動更新:
```bash
./scripts/upgrade-and-deploy.sh
```

詳細は [UPDATE_GUIDE.md](./UPDATE_GUIDE.md) を参照。

## ローカル開発

```bash
# ホットリロードで起動
uv run uvicorn rushia_dl.api:app --host 0.0.0.0 --port 8000 --reload
```

詳細は `LOCAL_RUN.md` を参照。

## 本番環境

- **ターゲット**: OCI ARM インスタンス（AlmaLinux）
- **詳細手順**: `DEPLOY_OCI.md` を参照
