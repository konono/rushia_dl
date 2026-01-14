"""
FastAPI backend for rushia_dl web interface
"""
from __future__ import unicode_literals

import asyncio
import secrets
import time
import uuid

from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from pathlib import Path
from threading import Lock
from typing import Optional

from pydantic import BaseModel

from fastapi import Query
from fastapi import FastAPI, HTTPException, BackgroundTasks, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from urllib.parse import quote
from yt_dlp import YoutubeDL

# アプリケーションのライフサイクル管理
@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションの起動・終了時の処理"""
    global cleanup_task
    # 起動時: クリーンアップタスクを開始
    cleanup_task = asyncio.create_task(cleanup_old_files())
    print(f"[Startup] File cleanup task started (retention: {FILE_RETENTION_HOURS} hours)")
    
    yield
    
    # 終了時: クリーンアップタスクを停止
    if cleanup_task:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass
    print("[Shutdown] File cleanup task stopped")


# アプリケーション設定
app = FastAPI(
    title="Rushia DL",
    description="YouTube動画・音声ダウンローダー",
    version="0.1.3",
    lifespan=lifespan,
    redirect_slashes=False  # トレーリングスラッシュのリダイレクトを無効化
)

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ダウンロードディレクトリ
DOWNLOAD_DIR = Path(__file__).parent.parent.parent / "download"
DOWNLOAD_DIR.mkdir(exist_ok=True)

# Cookie一時保存ディレクトリ
COOKIE_DIR = Path(__file__).parent.parent.parent / ".cookies"
COOKIE_DIR.mkdir(exist_ok=True)

# 静的ファイルとテンプレートのパス
STATIC_DIR = Path(__file__).parent / "static"
TEMPLATES_DIR = Path(__file__).parent / "templates"

# 静的ファイルをマウント
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# 並行ダウンロード設定
MAX_CONCURRENT_DOWNLOADS = 5  # 同時ダウンロード上限
download_executor = ThreadPoolExecutor(max_workers=MAX_CONCURRENT_DOWNLOADS)
active_downloads = 0
downloads_lock = Lock()

# ファイル保持設定
FILE_RETENTION_HOURS = 3  # ファイル保持時間（時間）
CLEANUP_INTERVAL_SECONDS = 300  # クリーンアップ間隔（5分）
DOWNLOAD_TOKEN_TTL_SECONDS = 10 * 60  # 10分（好みで調整）


# タスクステータスごとのタイムアウト設定（秒）
TASK_TIMEOUT = {
    'pending': 1 * 60 * 60,       # 1時間（待機中）
    'downloading': 6 * 60 * 60,   # 6時間（ダウンロード中）
    'processing': 3 * 60 * 60,    # 3時間（エンコード中）
    'completed': 3 * 60 * 60,     # 3時間（完了）
    'error': 1 * 60 * 60,         # 1時間（エラー）
}

# ダウンロードタスクの状態管理
download_tasks: dict = {}

# クリーンアップタスクの制御
cleanup_task: Optional[asyncio.Task] = None


async def cleanup_old_files():
    """古いダウンロードファイルとタスク情報を定期的に削除"""
    while True:
        try:
            await asyncio.sleep(CLEANUP_INTERVAL_SECONDS)
            current_time = time.time()
            file_retention_seconds = FILE_RETENTION_HOURS * 60 * 60
            deleted_files = 0
            deleted_tasks = 0
            
            # 古いファイルを削除（3時間経過）
            for file_path in DOWNLOAD_DIR.iterdir():
                if file_path.is_file() and file_path.suffix in ['.m4a', '.mp4']:
                    file_age = current_time - file_path.stat().st_mtime
                    if file_age > file_retention_seconds:
                        try:
                            file_path.unlink()
                            deleted_files += 1
                            print(f"[Cleanup] Deleted old file: {file_path.name}")
                        except Exception as e:
                            print(f"[Cleanup] Failed to delete {file_path.name}: {e}")
            
            # 古いタスク情報を削除（ステータスごとのタイムアウト）
            tasks_to_delete = []
            for task_id, task_data in download_tasks.items():
                created_at = task_data.get('created_at', 0)
                status = task_data.get('status', 'pending')
                timeout = TASK_TIMEOUT.get(status, 3 * 60 * 60)  # デフォルト3時間
                task_age = current_time - created_at
                
                if task_age > timeout:
                    tasks_to_delete.append(task_id)
            
            for task_id in tasks_to_delete:
                del download_tasks[task_id]
                deleted_tasks += 1
            
            if deleted_files > 0 or deleted_tasks > 0:
                print(f"[Cleanup] Deleted {deleted_files} file(s), {deleted_tasks} task(s)")
                
        except asyncio.CancelledError:
            print("[Cleanup] Task cancelled")
            break
        except Exception as e:
            print(f"[Cleanup] Error: {e}")




class DownloadRequest(BaseModel):
    url: str
    format: str  # "m4a" or "mp4"
    cookie_id: Optional[str] = None  # アップロードされたCookieのID


class CookieUploadResponse(BaseModel):
    cookie_id: str
    message: str


class DownloadStatus(BaseModel):
    task_id: str
    status: str  # "pending", "downloading", "processing", "completed", "error"
    progress: float
    filename: Optional[str] = None
    error: Optional[str] = None
    title: Optional[str] = None
    # 追加情報
    speed: Optional[float] = None  # bytes/sec
    eta: Optional[int] = None  # 残り秒数
    downloaded_bytes: Optional[int] = None
    total_bytes: Optional[int] = None
    elapsed: Optional[float] = None  # 経過秒数
    download_url: Optional[str] = None


def progress_hook(task_id: str):
    """ダウンロード進捗のコールバック"""
    def hook(d):
        if d['status'] == 'downloading':
            # バイトベースの進捗
            total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
            downloaded = d.get('downloaded_bytes', 0)
            
            # フラグメントベースの進捗（HLS/DASHなど）
            fragment_index = d.get('fragment_index')
            fragment_count = d.get('fragment_count')
            
            # 進捗を計算
            if total > 0 and downloaded > 0:
                progress = (downloaded / total) * 100
            elif fragment_index and fragment_count:
                progress = (fragment_index / fragment_count) * 100
            else:
                progress = download_tasks[task_id].get('progress', 0)
            
            download_tasks[task_id]['progress'] = min(progress, 99)
            download_tasks[task_id]['status'] = 'downloading'
            
            # 追加情報を保存
            download_tasks[task_id]['speed'] = d.get('speed')
            download_tasks[task_id]['eta'] = d.get('eta')
            download_tasks[task_id]['downloaded_bytes'] = downloaded
            download_tasks[task_id]['total_bytes'] = total
            download_tasks[task_id]['elapsed'] = d.get('elapsed')
            
            # フラグメント情報も保存（デバッグ用）
            if fragment_index and fragment_count:
                download_tasks[task_id]['fragment_index'] = fragment_index
                download_tasks[task_id]['fragment_count'] = fragment_count
            
        elif d['status'] == 'finished':
            download_tasks[task_id]['status'] = 'processing'
            download_tasks[task_id]['progress'] = 99
            # ダウンロード完了時の情報をクリア
            download_tasks[task_id]['speed'] = None
            download_tasks[task_id]['eta'] = None
    return hook


def postprocessor_hook(task_id: str):
    """後処理の進捗コールバック"""
    def hook(d):
        if d['status'] == 'finished':
            download_tasks[task_id]['progress'] = 100
        elif d['status'] == 'started':
            # エンコード開始
            download_tasks[task_id]['status'] = 'processing'
    return hook


def format_error_message(error: str) -> str:
    """エラーメッセージをユーザーフレンドリーな形式に変換"""
    error_lower = error.lower()
    
    # レート制限エラー
    if 'rate-limit' in error_lower or 'rate limit' in error_lower:
        return "YouTubeのレート制限に達しました。1時間ほど待ってから再度お試しください。"
    
    # コンテンツ利用不可
    if "this content isn't available" in error_lower:
        return "この動画は現在利用できません。YouTubeのレート制限の可能性があります。しばらく待ってから再度お試しください。"
    
    # 動画が見つからない
    if 'video unavailable' in error_lower or 'not available' in error_lower:
        return "この動画は利用できません。削除されたか、非公開になっている可能性があります。"
    
    # プライベート動画
    if 'private video' in error_lower:
        return "この動画は非公開です。"
    
    # 年齢制限
    if 'age' in error_lower and 'restrict' in error_lower:
        return "この動画は年齢制限があります。cookie.txtを使用してログイン状態でお試しください。"
    
    # メンバーシップ限定
    if 'members-only' in error_lower or 'member' in error_lower:
        return "この動画はメンバーシップ限定です。cookie.txtを使用してメンバーシップオプションを有効にしてください。"
    
    # 地域制限
    if 'geo' in error_lower or 'country' in error_lower:
        return "この動画はお住まいの地域では利用できません。"
    
    # ネットワークエラー
    if 'network' in error_lower or 'connection' in error_lower:
        return "ネットワークエラーが発生しました。インターネット接続を確認して再度お試しください。"
    
    # FFmpegエラー
    if 'ffmpeg' in error_lower:
        return "動画の変換中にエラーが発生しました。FFmpegが正しくインストールされているか確認してください。"
    
    # その他のエラー
    return f"ダウンロード中にエラーが発生しました: {error}"


def get_common_ydl_opts(task_id: str) -> dict:
    """共通のyt-dlpオプションを取得"""
    return {
        'outtmpl': str(DOWNLOAD_DIR / '%(title)s-%(id)s.%(ext)s'),
        'progress_hooks': [progress_hook(task_id)],
        'postprocessor_hooks': [postprocessor_hook(task_id)],
        'noplaylist': True,

        # リトライ設定（レート制限エラー時の自動リトライ）
        'retries': 10,  # リトライ回数
        'fragment_retries': 10,  # フラグメントのリトライ回数
        'extractor_retries': 5,  # 抽出のリトライ回数

        # エラーハンドリング
        'ignoreerrors': False,  # エラーを無視しない
        'no_warnings': False,  # 警告を表示

        # YouTubeのJSチャレンジ解決に必要（Deno + remote components）
        'remote_components': ['ejs:github'],

        # ★追加：IPv6経路で403/不安定になる環境の対策
        'force_ipv4': False,

        # ★追加：YouTube extractor の安定化（SABR強制・URL欠落回避に効くことが多い）
        # android が通りやすい / web は保険
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'web'],
            }
        },

        # ついでにUAを付けておくとブロック回避率が上がることがある
        'http_headers': {
            'User-Agent': (
                'Mozilla/5.0 (X11; Linux x86_64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/120.0.0.0 Safari/537.36'
            ),
            'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
        },

        # 注意: sleep_intervalはダウンロード速度を大幅に低下させるため
        # ダウンロード時には使用しない（情報取得時のみ使用）
    }


async def download_video(task_id: str, url: str, format: str, cookie_id: Optional[str] = None):
    print(f"[Debug] raw url={url}")
    url = clean_youtube_url(url)
    print(f"[Debug] normalized url={url}")

    """バックグラウンドでダウンロードを実行"""
    global active_downloads
    
    # URLをクリーンアップ（プレイリストパラメータを削除）
    url = clean_youtube_url(url)
    
    # Cookieファイルのパスを決定
    cookie_path = None
    if cookie_id:
        cookie_path = COOKIE_DIR / f"{cookie_id}.txt"
        if cookie_path.exists():
            print(f"[Debug] download_video: Using cookie file: {cookie_path}")
        else:
            print(f"[Debug] download_video: Cookie file not found: {cookie_path}")
            cookie_path = None
    else:
        print("[Debug] download_video: No cookie_id provided")
    
    try:
        download_tasks[task_id]['status'] = 'downloading'
        
        # 共通オプションを取得
        ydl_opts = get_common_ydl_opts(task_id)
        
        if format == 'm4a':
            # M4A: YouTubeのネイティブ形式を直接ダウンロード（変換なし）
            ydl_opts.update({
                'format': 'bestaudio[ext=m4a]/bestaudio/best',
                # M4A以外の形式がダウンロードされた場合のみ変換
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'm4a',
                    'preferredquality': '0',  # 元の品質を維持
                    'nopostoverwrites': True,
                }],
            })
        else:  # mp4
            ydl_opts.update({
                'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
                'merge_output_format': 'mp4',
            })
        
        # クッキーファイルが存在する場合は使用
        if cookie_path and cookie_path.exists():
            ydl_opts['cookiefile'] = str(cookie_path)
        
        # ダウンロード実行（専用スレッドプールで実行）
        def run_download():
            with YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                # yt-dlpがサニタイズしたファイル名を取得
                if info:
                    # prepare_filenameで実際のファイル名を取得
                    prepared_filename = ydl.prepare_filename(info)
                    info['_prepared_filename'] = prepared_filename
                return info
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(download_executor, run_download)
        
        # ダウンロードしたファイル名を取得
        if info:
            title = info.get('title', 'Unknown')
            video_id = info.get('id', '')
            ext = 'm4a' if format == 'm4a' else 'mp4'
            
            # 実際のファイルを検索（yt-dlpがサニタイズした名前で）
            actual_filename = None
            
            # 方法1: video_idでファイルを検索
            for file_path in DOWNLOAD_DIR.iterdir():
                if file_path.is_file() and video_id in file_path.name:
                    if file_path.suffix == f'.{ext}':
                        actual_filename = file_path.name
                        break
            
            # 方法2: prepare_filenameから取得
            if not actual_filename and info.get('_prepared_filename'):
                prepared = Path(info['_prepared_filename'])
                # 拡張子を変換後のものに変更
                expected_path = prepared.with_suffix(f'.{ext}')
                if expected_path.exists():
                    actual_filename = expected_path.name
                # 元のパスも確認
                elif prepared.with_suffix(f'.{ext}').name:
                    for file_path in DOWNLOAD_DIR.iterdir():
                        if video_id in file_path.name and file_path.suffix == f'.{ext}':
                            actual_filename = file_path.name
                            break
            
            if actual_filename:
                token = secrets.token_urlsafe(32)
                expires_at = time.time() + DOWNLOAD_TOKEN_TTL_SECONDS
                download_tasks[task_id]['download_token'] = token
                download_tasks[task_id]['download_token_expires_at'] = expires_at


                download_tasks[task_id]['status'] = 'completed'
                download_tasks[task_id]['progress'] = 100
                download_tasks[task_id]['filename'] = actual_filename
                download_tasks[task_id]['title'] = title
            else:
                download_tasks[task_id]['status'] = 'error'
                download_tasks[task_id]['error'] = f"ダウンロードは完了しましたが、ファイルが見つかりません。(video_id: {video_id})"
        else:
            # infoがNoneの場合もエラーとして扱う
            download_tasks[task_id]['status'] = 'error'
            download_tasks[task_id]['error'] = "ダウンロードに失敗しました。動画情報を取得できませんでした。"
        
    except Exception as e:
        download_tasks[task_id]['status'] = 'error'
        # エラーメッセージをユーザーフレンドリーに変換
        download_tasks[task_id]['error'] = format_error_message(str(e))
    
    finally:
        # ダウンロード完了後、カウンターをデクリメント
        with downloads_lock:
            active_downloads -= 1
        
        # Cookieファイルを削除（セキュリティのため）
        if cookie_path and cookie_path.exists():
            try:
                cookie_path.unlink()
                print(f"[Security] Deleted cookie file: {cookie_path.name}")
            except Exception as e:
                print(f"[Security] Failed to delete cookie file: {e}")


@app.get("/", response_class=HTMLResponse)
async def index():
    """メインページ"""
    index_path = TEMPLATES_DIR / "index.html"
    if index_path.exists():
        return HTMLResponse(content=index_path.read_text(encoding='utf-8'))
    return HTMLResponse(content="<h1>Template not found</h1>", status_code=404)


@app.post("/api/upload-cookie", response_model=CookieUploadResponse)
async def upload_cookie(file: UploadFile = File(...)):
    """Cookie.txtファイルをアップロード"""
    # ファイル名の検証
    if not file.filename:
        raise HTTPException(status_code=400, detail="ファイルが選択されていません")
    
    # ファイル内容を読み取り
    content = await file.read()
    
    # 内容の検証（Netscape cookie形式かどうか簡易チェック）
    try:
        text_content = content.decode('utf-8')
        # 空ファイルチェック
        if not text_content.strip():
            raise HTTPException(status_code=400, detail="ファイルが空です")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="無効なファイル形式です")
    
    # 一意のIDを生成
    cookie_id = str(uuid.uuid4())
    
    # ファイルを保存
    cookie_path = COOKIE_DIR / f"{cookie_id}.txt"
    cookie_path.write_text(text_content, encoding='utf-8')
    
    print(f"[Cookie] Uploaded cookie file: {cookie_id}")
    
    return CookieUploadResponse(
        cookie_id=cookie_id,
        message="Cookieファイルがアップロードされました"
    )


@app.delete("/api/cookie/{cookie_id}")
async def delete_cookie(cookie_id: str):
    """アップロードされたCookieファイルを削除"""
    cookie_path = COOKIE_DIR / f"{cookie_id}.txt"
    
    if cookie_path.exists():
        cookie_path.unlink()
        print(f"[Cookie] Deleted cookie file: {cookie_id}")
        return {"message": "Cookieファイルが削除されました"}
    
    raise HTTPException(status_code=404, detail="Cookieファイルが見つかりません")

def extract_youtube_video_id(url: str) -> str:
    """
    Supported:
      - https://www.youtube.com/watch?v=VIDEO_ID&...
      - https://youtu.be/VIDEO_ID?si=...
      - https://www.youtube.com/shorts/VIDEO_ID?...
      - https://www.youtube.com/live/VIDEO_ID?...
      - https://www.youtube.com/embed/VIDEO_ID?...
      - youtu.be/VIDEO_ID (schemeなしも一応)
    """
    from urllib.parse import urlparse, parse_qs

    url = (url or "").strip()
    if not url:
        raise ValueError("Empty URL")

    # scheme無し入力対策（youtu.be/... や youtube.com/...）
    if "://" not in url:
        url = "https://" + url

    p = urlparse(url)
    host = (p.netloc or "").lower()
    path = p.path or ""

    # youtu.be/<id>
    if host in {"youtu.be", "www.youtu.be"}:
        vid = path.lstrip("/").split("/")[0]
        if not vid:
            raise ValueError("Invalid youtu.be URL (missing video id).")
        return vid

    # youtube.com 系
    if host.endswith("youtube.com") or host.endswith("youtube-nocookie.com"):

        # /watch?v=<id>
        if path == "/watch":
            q = parse_qs(p.query)
            vid = (q.get("v") or [None])[0]
            if not vid:
                raise ValueError("Invalid watch URL (missing v=...).")
            return vid

        # /shorts/<id>, /live/<id>, /embed/<id>
        for prefix in ("/shorts/", "/live/", "/embed/"):
            if path.startswith(prefix):
                vid = path[len(prefix):].split("/")[0]
                if vid:
                    return vid

    raise ValueError(f"Unsupported YouTube URL: {url}")


def clean_youtube_url(url: str) -> str:
    """
    どんなYouTube URLでも video_id を抽出して watch URL に正規化する。
    これにより share URL (youtu.be/... ?si=...) も対応できる。
    """
    video_id = extract_youtube_video_id(url)
    print(f"debug: {video_id}")
    return f"https://www.youtube.com/watch?v={video_id}"


def check_if_live(url: str, cookie_id: Optional[str] = None) -> dict:
    """動画がライブ配信中かどうかをチェック"""
    # URLをクリーンアップ（プレイリストパラメータを削除）
    url = clean_youtube_url(url)
    
    # Cookieファイルのパスを決定
    cookie_path = None
    if cookie_id:
        cookie_path = COOKIE_DIR / f"{cookie_id}.txt"
        if cookie_path.exists():
            print(f"[Debug] check_if_live: Using cookie file: {cookie_path}")
        else:
            print(f"[Debug] check_if_live: Cookie file not found: {cookie_path}")
            cookie_path = None
    else:
        print("[Debug] check_if_live: No cookie_id provided")
    
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': False,
        'noplaylist': True,  # プレイリストを無視
        # レート制限対策
        'sleep_interval': 1,
        'extractor_retries': 3,
        # YouTubeのJSチャレンジ解決に必要（Deno + remote components）
        'remote_components': ['ejs:github'],
    }
    
    if cookie_path and cookie_path.exists():
        ydl_opts['cookiefile'] = str(cookie_path)
        print(f"[Debug] check_if_live: cookiefile option set to: {cookie_path}")
    
    with YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return {
            'is_live': info.get('is_live', False),
            'live_status': info.get('live_status'),
            'title': info.get('title', ''),
        }


@app.post("/api/download", response_model=DownloadStatus)
async def start_download(request: DownloadRequest, background_tasks: BackgroundTasks):
    """ダウンロードを開始"""
    global active_downloads
    
    # URLの検証
    if not request.url or 'youtube.com' not in request.url and 'youtu.be' not in request.url:
        raise HTTPException(status_code=400, detail="有効なYouTube URLを入力してください")
    
    # フォーマットの検証
    if request.format not in ['m4a', 'mp4']:
        raise HTTPException(status_code=400, detail="フォーマットはm4aまたはmp4を指定してください")
    
    # 同時ダウンロード数のチェック
    with downloads_lock:
        if active_downloads >= MAX_CONCURRENT_DOWNLOADS:
            raise HTTPException(
                status_code=503,
                detail=f"現在混み合っています（{active_downloads}/{MAX_CONCURRENT_DOWNLOADS}件処理中）。しばらくしてからお試しください。"
            )
        # ダウンロード数をインクリメント
        active_downloads += 1
    
    # ライブ配信チェック（専用スレッドプールで実行）
    try:
        loop = asyncio.get_event_loop()
        video_info = await loop.run_in_executor(
            download_executor,
            lambda: check_if_live(request.url, request.cookie_id)
        )
        
        # ライブ配信中の場合はエラー
        if video_info.get('is_live') or video_info.get('live_status') == 'is_live':
            with downloads_lock:
                active_downloads -= 1
            raise HTTPException(
                status_code=400,
                detail=f"「{video_info.get('title', '動画')}」は現在ライブ配信中です。配信終了後に再度お試しください。"
            )
        
        # 配信予定の場合もエラー
        if video_info.get('live_status') == 'is_upcoming':
            with downloads_lock:
                active_downloads -= 1
            raise HTTPException(
                status_code=400,
                detail=f"「{video_info.get('title', '動画')}」は配信予定です。配信終了後に再度お試しください。"
            )
            
    except HTTPException:
        raise
    except Exception:
        # チェック失敗時はダウンロードを試みる（エラーはダウンロード時に処理）
        pass
    
    # タスクIDを生成
    task_id = str(uuid.uuid4())
    
    # タスク状態を初期化
    download_tasks[task_id] = {
        'status': 'pending',
        'progress': 0,
        'filename': None,
        'error': None,
        'title': None,
        'speed': None,
        'eta': None,
        'downloaded_bytes': None,
        'download_token': None,
        'download_token_expires_at': None,
        'total_bytes': None,
        'elapsed': None,
        'created_at': time.time(),  # タスク作成時刻（クリーンアップ用）
    }
    
    # バックグラウンドでダウンロードを実行
    background_tasks.add_task(download_video, task_id, request.url, request.format, request.cookie_id)
    
    return DownloadStatus(
        task_id=task_id,
        status='pending',
        progress=0
    )


@app.get("/api/status/{task_id}", response_model=DownloadStatus)
async def get_status(task_id: str):
    if task_id not in download_tasks:
        raise HTTPException(status_code=404, detail="タスクが見つかりません")

    task = download_tasks[task_id]

    download_url = None
    if task.get('status') == 'completed' and task.get('filename') and task.get('download_token'):
        # filename はURLに載るのでエンコード
        safe_filename = quote(task['filename'])
        download_url = f"/api/download/{safe_filename}?token={task['download_token']}"

    return DownloadStatus(
        task_id=task_id,
        status=task['status'],
        progress=task['progress'],
        filename=task.get('filename'),
        error=task.get('error'),
        title=task.get('title'),
        speed=task.get('speed'),
        eta=task.get('eta'),
        downloaded_bytes=task.get('downloaded_bytes'),
        total_bytes=task.get('total_bytes'),
        elapsed=task.get('elapsed'),
        download_url=download_url,
    )

@app.get("/api/download/")
async def download_root():
    raise HTTPException(status_code=400, detail="filename が必要です")

@app.get("/api/download/{filename}")
async def download_file(filename: str, token: str = Query(..., min_length=10)):
    """トークン付きでダウンロード（Basic認証を外す前提）"""
    # token -> task を探す（メモリ内なので線形だが件数少ない想定）
    matched_task = None
    now = time.time()

    for task_id, task in download_tasks.items():
        if task.get('filename') == filename and task.get('download_token') == token:
            matched_task = task
            break

    if not matched_task:
        raise HTTPException(status_code=401, detail="無効なトークンです")

    expires_at = matched_task.get('download_token_expires_at') or 0
    if now > expires_at:
        raise HTTPException(status_code=401, detail="トークンの有効期限が切れました。もう一度ダウンロードを実行してください。")

    file_path = DOWNLOAD_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="ファイルが見つかりません")

    media_type = "audio/mp4" if filename.endswith('.m4a') else "video/mp4"

    return FileResponse(
        path=str(file_path),
        filename=filename,
        media_type=media_type
    )


@app.get("/api/server-status")
async def server_status():
    """サーバーの状態を取得"""
    # ダウンロードディレクトリのファイル数をカウント
    file_count = sum(
        1 for f in DOWNLOAD_DIR.iterdir()
        if f.is_file() and f.suffix in ['.m4a', '.mp4']
    )
    
    # アクティブなタスク（実行中のバックグラウンドタスク）を取得
    active_tasks = []
    for task_id, task_data in download_tasks.items():
        status = task_data.get('status', 'unknown')
        # 実行中のタスクのみ（pending, downloading, processing）
        if status in ['pending', 'downloading', 'processing']:
            active_tasks.append({
                'task_id': task_id,
                'status': status,
                'progress': task_data.get('progress', 0),
                'title': task_data.get('title'),
                'created_at': task_data.get('created_at'),
            })
    
    return {
        "active_downloads": active_downloads,
        "max_concurrent_downloads": MAX_CONCURRENT_DOWNLOADS,
        "available_slots": MAX_CONCURRENT_DOWNLOADS - active_downloads,
        "file_retention_hours": FILE_RETENTION_HOURS,
        "task_timeouts": TASK_TIMEOUT,
        "cached_files": file_count,
        "active_tasks": active_tasks,
        "total_tasks_in_memory": len(download_tasks),
    }


def run_server():
    """開発サーバーを起動"""
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    run_server()

