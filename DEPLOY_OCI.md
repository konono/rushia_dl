# Oracle Cloud Infrastructure (OCI) ARM インスタンスへのデプロイガイド

## 環境
- OCI ARM インスタンス (VM.Standard.A1.Flex)
- **AlmaLinux 10** (aarch64)
- 4 OCPU / 24GB RAM / 150GB Storage

---

## アーキテクチャ

```
[インターネット]
       │
       ▼ (80/443)
   [Nginx] ─── SSL終端 + リバースプロキシ
       │
       ▼ (8000)
  [Rushia-DL] ─── uvicorn
       │
       ▼
 [certbot] ─── 証明書自動更新
```

---

## 1. インスタンスへSSH接続

```bash
ssh -i ~/.ssh/your-key opc@<インスタンスのパブリックIP>
```

---

## 2. システムの更新

```bash
sudo dnf update -y
```

---

## 3. uv のインストール

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

---

## 4. Podman と podman-compose のインストール

```bash
# Podmanをインストール
sudo dnf install -y podman

# uvで仮想環境を作成し、podman-composeをインストール
cd ~
uv venv podman-tools
source ~/podman-tools/bin/activate
uv pip install podman-compose

# シェル起動時に自動有効化
echo 'source ~/podman-tools/bin/activate' >> ~/.bashrc

# 確認
podman --version
podman-compose --version
```

---

## 5. 必要なツールのインストール

```bash
sudo dnf install -y git curl openssl
```

---

## 6. ファイアウォール設定

### firewalld でポート開放
```bash
# HTTP/HTTPS ポートを開放
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# 確認
sudo firewall-cmd --list-all
```

### OCI セキュリティリスト（重要！）

**OCIコンソールで設定：**

1. **Networking** → **Virtual Cloud Networks** → VCNを選択
2. **Subnets** → サブネットを選択 → **Security Lists**
3. **Add Ingress Rules** で以下を追加:

| Source CIDR | Protocol | Dest Port |
|-------------|----------|-----------|
| `0.0.0.0/0` | TCP | 80 |
| `0.0.0.0/0` | TCP | 443 |

---

## 7. ドメインのDNS設定

Let's Encrypt で証明書を取得するには、ドメインがインスタンスのIPを指している必要があります。

```bash
# インスタンスのパブリックIPを確認
curl -s ifconfig.me
```

DNSレコードを設定:
- **タイプ**: A
- **名前**: your-domain.com (または subdomain)
- **値**: <インスタンスのパブリックIP>

---

## 8. アプリケーションのデプロイ

### コードをアップロード
```bash
# ローカルマシンで実行
scp -i ~/.ssh/your-key -r /path/to/rushia_dl opc@<IP>:~/
```

### または Git からクローン
```bash
cd ~
git clone https://github.com/YOUR_USERNAME/rushia_dl.git
cd rushia_dl
```

---

## 9. Let's Encrypt 証明書の初期設定

### 初期化スクリプトを実行
```bash
cd ~/rushia_dl

# 実行権限を付与
chmod +x scripts/*.sh

# 証明書を取得（ドメインとメールアドレスを指定）
./scripts/init-letsencrypt.sh your-domain.com your-email@example.com
```

スクリプトが自動で以下を実行:
1. nginx設定ファイルのドメイン名を更新
2. ダミー証明書を作成してnginxを起動
3. Let's Encrypt から本番証明書を取得
4. 全サービスを起動

---

## 10. 動作確認

```bash
# コンテナの状態確認
podman ps

# ヘルスチェック
curl -k https://localhost/api/server-status

# ブラウザからアクセス
echo "https://your-domain.com"
```

---

## 11. 証明書の自動更新

### 方法1: Certbotコンテナ（デフォルト）
docker-compose.yml の certbot サービスが12時間ごとに自動更新をチェックします。

### 方法2: cronジョブ（追加オプション）
```bash
./scripts/setup-cron.sh
```

### 手動更新
```bash
./scripts/renew-cert.sh
```

### 証明書の状態確認
```bash
podman-compose run --rm certbot certificates
```

---

## 12. 便利なコマンド

```bash
# ログ確認（リアルタイム）
podman-compose logs -f

# 特定サービスのログ
podman-compose logs -f nginx
podman-compose logs -f rushia-dl

# 再起動
podman-compose restart

# 停止
podman-compose down

# コンテナの状態確認
podman ps -a

# リソース使用量
podman stats

# イメージの再ビルド（コード更新時）
podman-compose down
podman-compose build --no-cache
podman-compose up -d

# Nginx設定の再読み込み
podman-compose exec nginx nginx -s reload
```

---

## 13. 自動起動設定（systemd）

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/rushia-dl.service << 'EOF'
[Unit]
Description=Rushia DL Container Stack
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=%h/rushia_dl
Environment="PATH=%h/podman-tools/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=%h/podman-tools/bin/podman-compose up
ExecStop=%h/podman-tools/bin/podman-compose down
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable rushia-dl.service
systemctl --user start rushia-dl.service
sudo loginctl enable-linger $(whoami)
```

---

## 14. アプリケーションの更新

```bash
cd ~/rushia_dl

# コンテナを停止
podman-compose down

# コードを更新
git pull  # または scp

# 再ビルド・起動
podman-compose build --no-cache
podman-compose up -d
```

---

## ディレクトリ構成

```
rushia_dl/
├── docker-compose.yml      # Compose設定
├── Dockerfile              # アプリイメージ
├── nginx/
│   ├── nginx.conf          # Nginx基本設定
│   └── conf.d/
│       └── rushia-dl.conf  # サイト設定（SSL含む）
├── certbot/
│   ├── conf/               # 証明書（自動生成）
│   └── www/                # ACMEチャレンジ用
├── scripts/
│   ├── init-letsencrypt.sh # 初期証明書取得
│   ├── renew-cert.sh       # 証明書更新
│   └── setup-cron.sh       # cron設定
├── downloads/              # ダウンロードファイル
└── cookies/                # Cookieファイル
```

---

## トラブルシューティング

### 証明書取得に失敗する
```bash
# DNSが正しく設定されているか確認
dig +short your-domain.com

# ポート80/443が開いているか確認
curl -I http://your-domain.com/.well-known/acme-challenge/test

# Certbotのログを確認
podman-compose logs certbot
```

### Nginxが起動しない
```bash
# 設定ファイルの構文チェック
podman-compose exec nginx nginx -t

# ログを確認
podman-compose logs nginx
```

### 502 Bad Gateway
```bash
# rushia-dlが起動しているか確認
podman ps | grep rushia-dl

# アプリのログを確認
podman-compose logs rushia-dl
```

### SELinuxの問題
```bash
# 状態確認
getenforce

# 一時的に無効化（テスト用）
sudo setenforce 0
```

---

## セキュリティ推奨事項

1. **HSTS有効化**
   - `nginx/conf.d/rushia-dl.conf` の HSTS 行のコメントを外す

2. **IPアドレス制限**
   - OCIセキュリティリストで特定IPのみ許可

3. **定期更新**
   ```bash
   sudo dnf update -y
   podman-compose build --no-cache
   ```

---

## クイックリファレンス

| 操作 | コマンド |
|------|---------|
| 初期セットアップ | `./scripts/init-letsencrypt.sh DOMAIN EMAIL` |
| 起動 | `podman-compose up -d` |
| 停止 | `podman-compose down` |
| 再起動 | `podman-compose restart` |
| ログ | `podman-compose logs -f` |
| 証明書更新 | `./scripts/renew-cert.sh` |
| 証明書確認 | `podman-compose run --rm certbot certificates` |

---

## 完了チェックリスト

- [ ] SSH接続できる
- [ ] uv, Podman, podman-compose インストール済み
- [ ] ファイアウォール設定完了（80, 443）
- [ ] OCIセキュリティリスト設定完了
- [ ] ドメインのDNS設定完了
- [ ] コードをサーバーにアップロード
- [ ] `./scripts/init-letsencrypt.sh` 成功
- [ ] https://your-domain.com でアクセス確認
- [ ] 自動起動設定完了（オプション）
