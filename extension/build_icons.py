#!/usr/bin/env python3
# build_icons.py (macOS / no pip required)
#
# Usage:
#   python3 build_icons.py rushiadl_icon.png
#
# Output:
#   icons/icon16.png
#   icons/icon32.png
#   icons/icon48.png
#   icons/icon128.png

import os
import sys
import subprocess
from pathlib import Path

SIZES = [16, 32, 48, 128]

def run(cmd: list[str]) -> None:
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed:\n{' '.join(cmd)}\n\n{p.stderr.strip()}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 build_icons.py <source.png>")
        return 1

    src = Path(sys.argv[1])
    if not src.exists():
        print(f"Error: file not found: {src}")
        return 1

    out_dir = Path("icons")
    out_dir.mkdir(exist_ok=True)

    # sips が使えるかチェック
    try:
        run(["sips", "--version"])
    except Exception:
        print("Error: sips is not available. (This script is for macOS.)")
        return 1

    for size in SIZES:
        out = out_dir / f"icon{size}.png"

        # 1) 正方形にリサイズ（アスペクト比はそのまま収める）
        #    元画像がすでに正方形ならそのまま綺麗に縮小されます
        run([
            "sips",
            "-s", "format", "png",
            "-z", str(size), str(size),
            str(src),
            "--out", str(out)
        ])

        # 2) 追加の最適化（metadata削除＆再圧縮っぽい効果）
        #    sips は最適化の自由度が低いですが、これでも多少軽くなることがあります
        run(["sips", "-s", "formatOptions", "best", str(out)])

        print(f"wrote: {out}")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
