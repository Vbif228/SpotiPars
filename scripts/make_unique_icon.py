"""
Generates an original, distinctive high-resolution icon for SpotiPars.
Not a 1-to-1 copy of Spotify, but a custom vinyl record + stylized 'S' equalizer & download glyph.
Outputs multi-size assets/icon.ico and assets/icon.png.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter


def create_unique_icon():
    os.makedirs("assets", exist_ok=True)
    # Master resolution 1024x1024 for supersampling
    W = 1024
    H = 1024
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = W / 2, H / 2
    r_outer = 480

    # 1. Base Vinyl Disc (Deep Charcoal #161616)
    draw.ellipse(
        [cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer],
        fill=(20, 20, 20, 255),
        outline=(29, 185, 84, 255),
        width=20
    )

    # 2. Concentric Vinyl Grooves
    groove_color = (32, 32, 32, 255)
    for r in [430, 390, 350, 310, 270]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=groove_color, width=4)

    # 3. Center Label (Dark Emerald Accent #12281B)
    r_center = 240
    draw.ellipse(
        [cx - r_center, cy - r_center, cx + r_center, cy + r_center],
        fill=(15, 30, 20, 255),
        outline=(29, 185, 84, 255),
        width=12
    )

    # 4. Stylized 'S' Audio Wave + Download Arrow Glyph (Neon Emerald #1DB954 / #1ED760)
    # Draw vibrant green equalizer bars in an 'S' wave formation
    green_primary = (29, 185, 84, 255)
    green_light = (30, 215, 96, 255)

    # Equalizer bars forming dynamic musical shape:
    # 5 vertical sound bars with rounded caps
    bar_specs = [
        # (center_x_offset, center_y_offset, width, height)
        (-140, -10, 36, 170),
        (-70, -35, 36, 250),
        (0, -50, 40, 310),      # Center peak bar
        (70, -35, 36, 250),
        (140, -10, 36, 170),
    ]

    for dx, dy, bw, bh in bar_specs:
        bx = cx + dx
        by = cy + dy
        r_cap = bw / 2
        # Draw bar with rounded caps
        draw.rounded_rectangle(
            [bx - bw / 2, by - bh / 2, bx + bw / 2, by + bh / 2],
            radius=r_cap,
            fill=green_primary
        )

    # 5. Integrated Distinctive Download / Export Arrow Badge
    # A sleek download arrowhead at the bottom center to symbolize exporter
    arrow_y = cy + 120
    arrow_w = 110
    arrow_h = 70
    draw.polygon(
        [
            (cx - arrow_w / 2, arrow_y),
            (cx + arrow_w / 2, arrow_y),
            (cx, arrow_y + arrow_h)
        ],
        fill=green_light
    )

    # Save 256x256 PNG
    png_path = "assets/icon.png"
    img_256 = img.resize((256, 256), Image.Resampling.LANCZOS)
    img_256.save(png_path, "PNG")

    # Save multi-resolution ICO (256, 128, 64, 48, 32, 24, 16)
    sizes = [256, 128, 64, 48, 32, 24, 16]
    ico_images = [img.resize((s, s), Image.Resampling.LANCZOS) for s in sizes]
    ico_path = "assets/icon.ico"
    ico_images[0].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=ico_images[1:]
    )

    print(f"Generated original icon: {ico_path} and {png_path} with sizes {sizes}")


if __name__ == "__main__":
    create_unique_icon()
