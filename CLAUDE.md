# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rushia DL is a YouTube video/audio downloader built on [yt-dlp](https://github.com/yt-dlp/yt-dlp). It has two interfaces:
- **CLI** (`rushia-dl`): command-line tool for batch/single downloads
- **Web** (`rushia-web`): FastAPI web server with a browser-based UI

## Development Commands

**Prerequisites:** Python 3.10+, ffmpeg, Deno (for yt-dlp JS challenge solving)

```bash
# Install dependencies
uv sync

# Run web server (recommended, hot-reload)
uv run uvicorn rushia_dl.api:app --host 0.0.0.0 --port 8000 --reload

# Or use the entrypoint
uv run rushia-web

# Run CLI
uv run rushia-dl -u "https://www.youtube.com/watch?v=VIDEO_ID" -f mp4
uv run rushia-dl -p urls.txt -f m4a
uv run rushia-dl -u URL -f m4a -m  # membership content (requires cookie.txt)

# Update yt-dlp
./scripts/update-yt-dlp.sh

# Smoke test (container内実行 — ローカルにffmpeg/deno不要)
./scripts/smoke-test-container.sh
./scripts/smoke-test-container.sh --quick                       # バイナリチェックのみ
./scripts/smoke-test-container.sh --image rushia-dl:latest --ci  # 既存イメージ使用
```

## Architecture

### Package structure (`src/rushia_dl/`)
- `cli.py` — CLI entrypoint. Parses args, builds yt-dlp options, downloads to `./download/`
- `api.py` — FastAPI app. Async download pipeline with task state management
- `templates/index.html` — Single-page web UI (served at `/`)
- `static/` — Static assets for the web UI

### Web API key design points (`api.py`)

**Download lifecycle:**
1. `POST /api/download` — validates URL (YouTube only), checks if live/upcoming, creates a task ID, starts `download_video()` as a `BackgroundTask`, returns task ID immediately
2. `GET /api/status/{task_id}` — poll for progress (`pending` → `downloading` → `processing` → `completed`/`error`)
3. `GET /api/download/{filename}?token=TOKEN` — serve file with time-limited token (180 min TTL)

**State management:** In-memory dicts (`download_tasks`, `filename_to_token`). Not persistent across restarts.

**Concurrency:** Max 5 simultaneous downloads via `ThreadPoolExecutor`. yt-dlp runs in threads (blocking), dispatched via `loop.run_in_executor()`.

**Cookie handling:** Cookies uploaded via `POST /api/upload-cookie` get a UUID, stored in `.cookies/`. Deleted after use for security. When cookies are present, only the `web` player client is used (android/ios don't support cookies). Without cookies, android+web clients are used.

**Format strategy:**
- `mp4`: `bestvideo[ext=mp4]+bestaudio[ext=m4a]` merged with ffmpeg
- `m4a` without cookie: direct audio-only format download
- `m4a` with cookie: download format 18 (360p video+audio), then extract audio via ffmpeg — works around YouTube SABR streaming restrictions

**File retention:** 3-hour auto-cleanup runs every 5 minutes (`cleanup_old_files()`).

**URL normalization:** All YouTube URLs (youtu.be, /shorts/, /live/, etc.) are normalized to `https://www.youtube.com/watch?v=VIDEO_ID` before processing.

### Browser Extension (`extension/`)
Chrome/Edge extension (Manifest V3) that extracts YouTube cookies and sends them to the Rushia DL web app. Connects to localhost or the production domain via `externally_connectable` in `manifest.json`.

### Deployment
- **Docker/Podman:** `docker-compose.yml` runs three services: `rushia-dl` (uvicorn), `nginx` (reverse proxy + SSL termination), `certbot` (Let's Encrypt auto-renewal)
- **Production target:** OCI ARM instance (AlmaLinux), using `podman-compose` — see `DEPLOY_OCI.md`
- Downloads are volume-mounted to `./downloads/`, cookies to `./cookies/`

## Key Dependencies
- `yt-dlp` — core downloader (update frequently with `./scripts/update-yt-dlp.sh`)
- `fastapi` + `uvicorn` — web server
- `Deno` — required at runtime for yt-dlp's JavaScript challenge solving (`remote_components: ['ejs:github']`)
- `ffmpeg` — required for audio extraction and video merging
