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

Open a PowerShell or Windows command prompt in administrator mode, enter the command wsl --install, and reboot the machine.
```
wsl --install
```

**After installing Ubuntu with WSL, please follow the For linux procedure.**


### For Linux
```
sudo apt update
sudo apt install ffmpeg
```

## How to install
```
pip3 install rushia-dl
```

## How to use

使い方は簡単です。

オプションは-pと-u、-f,-mの4つです。

```
❯ rye run rushia-dl -h
usage: rushia-dl [-h] (-p PATH | -u URL) -f {mp3,mp4} [-m]

This tool that download video and mp3 from youtube.

options:
  -h, --help            show this help message and exit
  -p PATH, --path PATH  [REQUIRE] Please enter the URL of the video in the path of a text file.
  -u URL, --url URL     [REQUIRE] Please enter the video URL.
  -f {mp3,mp4}, --format {mp3,mp4}
                        [REQUIRE] Please input format that mp3 or mp4.
  -m, --membership      [OPTION] Please use -m option and put cookie.txt to current directory if you to do download file is membership only content.

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

もしもmembership限定の動画であった場合は ```-m オプション```を利用してください。-mオプションを利用する際には**ブラウザからcookieをdumpしてcookie.txtという名前でcurrent directoryに配置してください。**

この先も素敵な推し活を祈っています。
