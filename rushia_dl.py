from __future__ import unicode_literals

import argparse
import fileinput

from pathlib import Path
from yt_dlp import YoutubeDL

def donwload_youtube(ydl_opts, video_url):
    ydl_opts['outtmpl'] = './download' + '/%(title)s-%(id)s.%(ext)s'
    with YoutubeDL(ydl_opts) as ydl:
        ydl.download([f'{video_url}'])

def main(args):
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
            print('File does not found')
            exit(1)
        with open(args.path) as f:
            for video_url in f:
                print(f'Downloading {video_url}')
                donwload_youtube(ydl_opts, video_url)
    else:
        video_url = args.url
        print(f'Downloading {video_url}')
        donwload_youtube(ydl_opts, video_url)

if __name__ == '__main__':
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
    main(parser.parse_args())
