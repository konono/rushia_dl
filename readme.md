# Rushia DL

某Vtuberがいなくなる時に作ったyoutubeの動画をダウンロードでするためのpython製ツールです。

**Vtuberに限らず推しはいついなくなるかわかりません、推せる時に推しましょう。**

作りとしては単純で[yt-dlp](https://github.com/yt-dlp/yt-dlp)をラップしているだけです、mp3とmp4をそれぞれのフォーマットで出力するときのオプションを覚えるのがめんどくさかったのでpythonでラッパーを書きました。

## How to pre-install

まずは依存しているffmpegをインストールしてPATHを通してください。

### for mac
```
brew postinstall libtasn1
brew install ffmpeg
```

### For windows
Download from https://ffmpeg.org/download.html#build-windows
Then install ffpmeg and configure the path in the environment variables.

### For Linux
```
sudo apt install ffmpeg
```
## How to install
```
pip3 install rushia-dl
```

## How to use

使い方はかんたんです。

オプションは-pと-u、-fの３つです。

```
❯ rushia-dl --help
usage: rushia-dl [-h] (-p PATH | -u URL) -f {mp3,mp4}

This tool that download video and mp3 from youtube.

options:
  -h, --help            show this help message and exit
  -p PATH, --path PATH  [REQUIRE] Please enter the URL of the video in the path of a text file.
  -u URL, --url URL     [REQUIRE] Please enter the video URL.
  -f {mp3,mp4}, --format {mp3,mp4}
                        [REQUIRE] Please input format that mp3 or mp4.

```

-fではフォーマットを指定します、mp3(音声のみ)もしくはmp4(動画)を選択します。

-pを選んだ場合は動画のURLが１行ずつ記載されたtext fileのpathを指定してください。

e.g. 
```
cat test.txt
https://www.youtube.com/watch?v=aaaaaaa
https://www.youtube.com/watch?v=bbbbbbb
```

```
❯ rusia-dl.py -p ./test.txt -f mp4
```

-uではURLを指定してください。

```
❯ rusia-dl.py -u "https://www.youtube.com/watch?v=DHqLfnIoKWc" -f mp4
```

この先も素敵な推し活を祈っています。
