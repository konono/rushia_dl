# Rushia DL - Dockerfile
# ARM64 (aarch64) 対応
FROM python:3.11-slim

# ビルド引数（ARM/AMD自動検出）
ARG TARGETARCH

# 必要なシステムパッケージをインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Denoをインストール（yt-dlpのJSチャレンジ解決用）
# ARM64とAMD64の両方に対応
RUN curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh
ENV PATH="/usr/local/bin:$PATH"

# 作業ディレクトリを設定
WORKDIR /app

# 依存関係ファイルをコピー
COPY pyproject.toml ./

# ryeは使わず、pipで直接インストール
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn[standard] \
    yt-dlp \
    python-multipart

# アプリケーションコードをコピー
COPY src/ ./src/

# ダウンロードディレクトリを作成
RUN mkdir -p /app/downloads /app/.cookies

# ポートを公開
EXPOSE 8000

# 環境変数
ENV PYTHONPATH=/app/src
ENV PYTHONUNBUFFERED=1

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/server-status || exit 1

# アプリケーションを起動
CMD ["uvicorn", "rushia_dl.api:app", "--host", "0.0.0.0", "--port", "8000"]


