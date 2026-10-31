import os
import math
from PIL import Image, ImageDraw

def create_app_icon():
    os.makedirs("assets", exist_ok=True)
    size = (256, 256)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base circle background (Deep Charcoal/Black #121212)
    margin = 8
    draw.ellipse(
        [margin, margin, size[0] - margin, size[1] - margin],
        fill=(18, 18, 18, 255),
        outline=(29, 185, 84, 255),
        width=8
    )

    # Inner subtle glow/ring
    draw.ellipse(
        [margin + 12, margin + 12, size[0] - margin - 12, size[1] - margin - 12],
        fill=(24, 24, 24, 255)
    )

    # Draw Spotify-like curved sound waves (Green #1DB954)
    green = (29, 185, 84, 255)
    center_x = 128
    
    # 3 Spotify-like curved sound waves
    # Wave 1 (top, widest)
    draw.arc([55, 60, 201, 160], start=205, end=335, fill=green, width=14)
    # Wave 2 (middle)
    draw.arc([68, 90, 188, 180], start=205, end=335, fill=green, width=13)
    # Wave 3 (bottom, smallest)
    draw.arc([82, 120, 174, 200], start=205, end=335, fill=green, width=12)

    # Downward export arrow overlay at bottom right
    # Arrow container circle
    badge_box = [145, 145, 235, 235]
    draw.ellipse(badge_box, fill=(29, 185, 84, 255), outline=(18, 18, 18, 255), width=6)
    
    # White download/export arrow
    draw.line([190, 165, 190, 205], fill=(0, 0, 0, 255), width=6)
    draw.polygon([(175, 195), (205, 195), (190, 215)], fill=(0, 0, 0, 255))

    # Save PNG
    png_path = "assets/icon.png"
    img.save(png_path, "PNG")

    # Save multi-size ICO
    ico_path = "assets/icon.ico"
    sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    img.save(ico_path, format="ICO", sizes=sizes)
    print(f"Generated {ico_path} and {png_path}")

if __name__ == '__main__':
    create_app_icon()
