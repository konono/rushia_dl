from __future__ import unicode_literals

import argparse

from pathlib import Path
from yt_dlp import YoutubeDL

def donwload_youtube(ydl_opts, video_url):
    ydl_opts['outtmpl'] = './download' + '/%(title)s-%(id)s.%(ext)s'
    with YoutubeDL(ydl_opts) as ydl:
        ydl.download([f'{video_url}'])

def parser():
    parser = argparse.ArgumentParser(
        description="This tool that download video and mp3 from youtube.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-p","--path", dest="path",
                        help="""
                        [REQUIRE] Please enter the URL of the video in the path of a text file.
                        """)
    group.add_argument("-u","--url", dest="url",
                        help="""
                        [REQUIRE] Please enter the video URL.
                        """)
    parser.add_argument("-f","--format", dest="format", required=True, choices=["mp3", "mp4"],
                        help="""
                        [REQUIRE] Please input format that mp3 or mp4.
                        """)
    parser.add_argument("-m","--membership", dest="is_membership", required=False, action='store_true',
                        help="""
                        [OPTION] Please use -m option and put cookie.txt to current directory if you to do download file is membership only content.
                        """)
    args = parser.parse_args()
    return args

def main():
    args = parser()
    if args.is_membership:
        if args.format == 'mp3':
            ydl_opts = {
                'format': 'bestaudio/best', # choice of quality
                'extractaudio' : True,      # only keep the audio
                'audioformat' : 'mp3',      # convert to mp3
                'noplaylist' : True,        # only download single song, not playlist
                'cookiefile': './cookie.txt',
                'postprocessors': [{
                  'key': 'FFmpegExtractAudio',
                  'preferredcodec': 'mp3',
                  'preferredquality': '192',
                  }],
                 }
        elif args.format == 'mp4':
            ydl_opts = {
                'cookiefile': './cookie.txt',
                'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
                'download-archive': './download_cache.log',
                'retries': 3,
                }
    else:
        if args.format == 'mp3':
            ydl_opts = {
                'format': 'bestaudio/best', # choice of quality
                'extractaudio' : True,      # only keep the audio
                'audioformat' : 'mp3',      # convert to mp3
                'noplaylist' : True,        # only download single song, not playlist
                'postprocessors': [{
                  'key': 'FFmpegExtractAudio',
                  'preferredcodec': 'mp3',
                  'preferredquality': '192',
                  }],
                 }
        elif args.format == 'mp4':
            ydl_opts = {
                'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
                'download-archive': './download_cache.log',
                'retries': 3,
                }

    if args.path:
        if not Path(args.path).exists():
            print(f'{args.path} does not found.')
            exit(1)
        with open(args.path) as f:
            for video_url in f:
                print(f'Downloading {video_url}')
                donwload_youtube(ydl_opts, video_url)
    else:
        video_url = args.url
        print(f'Downloading {video_url}')
        donwload_youtube(ydl_opts, video_url)
