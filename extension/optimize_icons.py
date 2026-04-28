#!/usr/bin/env python3
"""
Chrome拡張機能用にアイコンを最適化
小さいサイズでも見やすくするため、線の太さを調整
"""
from PIL import Image, ImageDraw
import os

def optimize_icon(size):
    """指定サイズのアイコンを最適化"""
    # 背景画像を作成（ダークテーマ風の背景）
    img = Image.new('RGBA', (size, size), (10, 10, 15, 255))  # #0a0a0f
    draw = ImageDraw.Draw(img)
    
    # サイズに応じたパディングと線の太さを調整
    padding = size // 6
    # 小さいサイズでは線を太くする
    if size <= 16:
        stroke_width = max(2, size // 8)
    elif size <= 32:
        stroke_width = max(2, size // 12)
    else:
        stroke_width = max(2, size // 16)
    
    # Rushia DLのテーマカラー
    cyan = (0, 240, 255, 255)  # #00f0ff
    purple = (139, 92, 246, 255)  # #8b5cf6
    dark_bg = (10, 10, 15, 255)  # #0a0a0f
    
    # グロー効果のための外側の円（大きいサイズのみ）
    if size >= 48:
        glow_size = size - padding * 2
        glow_x = padding
        glow_y = padding
        
        # グロー効果（外側のぼかし円）
        for i in range(2):
            alpha = 20 - i * 10
            glow_radius = glow_size // 2 + i * 2
            draw.ellipse(
                [glow_x - i, glow_y - i, glow_x + glow_size + i, glow_y + glow_size + i],
                fill=(0, 240, 255, alpha),
                outline=None
            )
    
    # メインの円形背景（グラデーション風、大きいサイズのみ）
    if size >= 32:
        circle_center = size // 2
        circle_radius = (size - padding * 2) // 2
        
        # グラデーション風の背景（複数の円を重ねる）
        steps = max(3, circle_radius // 3)
        for i in range(circle_radius, 0, -max(1, circle_radius // steps)):
            alpha = int(15 * (1 - i / circle_radius))
            color = (
                int(0 + (10 - 0) * (1 - i / circle_radius)),
                int(240 + (10 - 240) * (1 - i / circle_radius)),
                int(255 + (15 - 255) * (1 - i / circle_radius)),
                alpha
            )
            draw.ellipse(
                [circle_center - i, circle_center - i, circle_center + i, circle_center + i],
                fill=color,
                outline=None
            )
    
    # 「R」文字をパスで描画
    letter_width = size * 0.5
    letter_height = size * 0.7
    letter_x = (size - letter_width) // 2
    letter_y = (size - letter_height) // 2
    
    def draw_r_path(x, y, w, h, stroke_w, color, alpha=255):
        """R文字をパスで描画"""
        # Rの左縦線
        draw.line(
            [x, y, x, y + h],
            fill=(color[0], color[1], color[2], alpha),
            width=stroke_w
        )
        
        # Rの上横線
        draw.line(
            [x, y, x + w * 0.6, y],
            fill=(color[0], color[1], color[2], alpha),
            width=stroke_w
        )
        
        # Rの右上の斜め線
        draw.line(
            [x + w * 0.6, y, x + w * 0.6, y + h * 0.5],
            fill=(color[0], color[1], color[2], alpha),
            width=stroke_w
        )
        
        # Rの右上の曲線部分（簡易版：直線で近似）
        draw.line(
            [x + w * 0.6, y + h * 0.5, x + w, y + h * 0.5],
            fill=(color[0], color[1], color[2], alpha),
            width=stroke_w
        )
        
        # Rの右下の斜め線
        draw.line(
            [x + w * 0.6, y + h * 0.5, x + w, y + h],
            fill=(color[0], color[1], color[2], alpha),
            width=stroke_w
        )
        
        # Rの中間の横線（小さいサイズでは省略）
        if h > size * 0.4 and size >= 32:
            draw.line(
                [x, y + h * 0.5, x + w * 0.6, y + h * 0.5],
                fill=(color[0], color[1], color[2], alpha),
                width=stroke_w
            )
    
    # グロー効果付きで「R」を描画（大きいサイズのみ）
    if size >= 48:
        glow_offsets = [3, 2, 1]
        for offset in glow_offsets:
            alpha = 120 - offset * 30
            draw_r_path(
                letter_x - offset, letter_y - offset,
                letter_width, letter_height,
                stroke_width + offset,
                cyan, alpha
            )
    elif size >= 32:
        # 中サイズでは軽いグロー
        draw_r_path(
            letter_x - 1, letter_y - 1,
            letter_width, letter_height,
            stroke_width + 1,
            cyan, 100
        )
    
    # メインの「R」文字（シアン）
    draw_r_path(letter_x, letter_y, letter_width, letter_height, stroke_width, cyan, 255)
    
    # アクセントとして小さなパープルの点を追加（右下、大きいサイズのみ）
    if size >= 32:
        accent_size = max(2, size // 16)
        accent_x = size - padding - accent_size
        accent_y = size - padding - accent_size
        draw.ellipse(
            [accent_x, accent_y, accent_x + accent_size * 2, accent_y + accent_size * 2],
            fill=purple,
            outline=None
        )
    
    return img

def main():
    """メイン処理"""
    # アイコンディレクトリを確認
    icon_dir = os.path.join(os.path.dirname(__file__), 'icons')
    os.makedirs(icon_dir, exist_ok=True)
    
    # 各サイズのアイコンを生成
    sizes = [16, 32, 48, 128]
    
    print("Chrome拡張機能用にアイコンを最適化中...")
    
    for size in sizes:
        icon = optimize_icon(size)
        icon_path = os.path.join(icon_dir, f'icon{size}.png')
        # PNG形式で保存（最適化）
        icon.save(icon_path, 'PNG', optimize=True)
        print(f"✓ {icon_path} を最適化しました ({size}x{size})")
    
    print("\n完了！")

if __name__ == '__main__':
    main()

