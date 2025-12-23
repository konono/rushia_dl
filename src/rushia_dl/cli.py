from __future__ import unicode_literals

import argparse

from pathlib import Path
from yt_dlp import YoutubeDL


def download_youtube(ydl_opts, video_url):
    """YouTubeから動画/音声をダウンロード"""
    ydl_opts['outtmpl'] = './download' + '/%(title)s-%(id)s.%(ext)s'
    with YoutubeDL(ydl_opts) as ydl:
        ydl.download([f'{video_url}'])


def get_ydl_opts(format: str, cookie_file: str = None) -> dict:
    """yt-dlpのオプションを取得（Web版と共通仕様）"""
    
    # 共通オプション
    common_opts = {
        'noplaylist': True,
        'retries': 10,
        'fragment_retries': 10,
        'extractor_retries': 5,
    }
    
    if cookie_file:
        common_opts['cookiefile'] = cookie_file
    
    if format == 'm4a':
        # M4A: YouTubeのネイティブ形式を直接ダウンロード（変換なし）
        return {
            **common_opts,
            'format': 'bestaudio[ext=m4a]/bestaudio/best',
            # M4A以外の形式がダウンロードされた場合のみ変換
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'm4a',
                'preferredquality': '0',  # 元の品質を維持
                'nopostoverwrites': True,
            }],
        }
    elif format == 'mp4':
        # MP4: 動画+音声
        return {
            **common_opts,
            'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
            'merge_output_format': 'mp4',
        }
    else:
        raise ValueError(f"Unknown format: {format}")


def parser():
    parser = argparse.ArgumentParser(
        description="YouTube動画・音声ダウンロードツール")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-p", "--path", dest="path",
                       help="URLリストが記載されたテキストファイルのパス")
    group.add_argument("-u", "--url", dest="url",
                       help="ダウンロードする動画のURL")
    
    parser.add_argument("-f", "--format", dest="format", required=True, 
                        choices=["m4a", "mp4"],
                        help="出力フォーマット: m4a（音声のみ）または mp4（動画）")
    
    parser.add_argument("-m", "--membership", dest="is_membership", 
                        required=False, action='store_true',
                        help="メンバーシップ限定コンテンツの場合に指定（cookie.txtが必要）")
    
    parser.add_argument("-c", "--cookie", dest="cookie_file",
                        required=False, default="./cookie.txt",
                        help="Cookieファイルのパス（デフォルト: ./cookie.txt）")
    
    args = parser.parse_args()
    return args


def main():
    args = parser()
    
    # Cookieファイルの設定
    cookie_file = None
    if args.is_membership:
        cookie_path = Path(args.cookie_file)
        if not cookie_path.exists():
            print(f'エラー: Cookieファイル "{args.cookie_file}" が見つかりません。')
            print('メンバーシップコンテンツをダウンロードするには、cookie.txtが必要です。')
            exit(1)
        cookie_file = str(cookie_path)
        print(f'Cookieファイルを使用: {cookie_file}')
    
    # yt-dlpオプションを取得
    ydl_opts = get_ydl_opts(args.format, cookie_file)
    
    # ダウンロード実行
    if args.path:
        # ファイルからURLリストを読み込む
        path = Path(args.path)
        if not path.exists():
            print(f'エラー: ファイル "{args.path}" が見つかりません。')
            exit(1)
        
        with open(path) as f:
            urls = [line.strip() for line in f if line.strip()]
        
        print(f'{len(urls)} 件のURLを処理します...')
        for i, video_url in enumerate(urls, 1):
            print(f'\n[{i}/{len(urls)}] ダウンロード中: {video_url}')
            try:
                download_youtube(ydl_opts, video_url)
            except Exception as e:
                print(f'エラー: {e}')
                continue
    else:
        # 単一URLをダウンロード
        video_url = args.url
        print(f'ダウンロード中: {video_url}')
        download_youtube(ydl_opts, video_url)
    
    print('\n完了!')


if __name__ == "__main__":
    main()
