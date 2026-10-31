import os
import io
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from svgpath2mpl import parse_path
from PIL import Image

def generate_icons():
    os.makedirs("assets", exist_ok=True)
    
    # Official Spotify Wave Path (exact SVG bezier data)
    path_d = "M118.9 121.5c-1.5 2.5-4.7 3.3-7.2 1.8-19.8-12.1-44.8-14.9-74.1-8.2-2.8.6-5.7-1.1-6.3-3.9-.6-2.8 1.1-5.7 3.9-6.3 32.1-7.3 59.8-4.2 81.9 9.3 2.5 1.5 3.3 4.8 1.8 7.3zm10.6-23.7c-1.9 3.1-6 4.1-9.1 2.2-22.7-13.9-57.3-18-84.1-9.8-3.5 1.1-7.2-.9-8.3-4.4-1.1-3.5.9-7.2 4.4-8.3 30.6-9.3 68.8-4.8 94.9 11.2 3.1 1.9 4.1 6 2.2 9.1zm1.1-24.8C103.4 56.9 58.7 55.4 33 63.2c-4.1 1.2-8.5-1.1-9.7-5.2-1.2-4.1 1.1-8.5 5.2-9.7 29.6-9 79-7.3 109.2 10.6 3.7 2.2 4.9 7 2.7 10.7-2.2 3.8-7 4.9-10.8 2.6z"
    wave_path = parse_path(path_d)

    # Render figure at 1024x1024 with transparent background
    fig = plt.figure(figsize=(10.24, 10.24), dpi=100)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 167.5)
    ax.set_ylim(167.5, 0) # Invert Y for SVG coordinates
    ax.axis("off")

    # Vibrant Spotify Green Circle (#1DB954)
    # Notice: Spotify Green is #1DB954 or #1ED760. #1DB954 with #000000 waves is the iconic look!
    circle = patches.Circle((83.75, 83.75), 83.75, facecolor="#1DB954", edgecolor=None)
    ax.add_patch(circle)

    # Black wave paths (#121212)
    patch = patches.PathPatch(wave_path, facecolor="#121212", edgecolor=None)
    ax.add_patch(patch)

    buf = io.BytesIO()
    plt.savefig(buf, format="png", transparent=True, dpi=100)
    plt.close(fig)
    buf.seek(0)

    master_img = Image.open(buf).convert("RGBA")
    master_img = master_img.resize((1024, 1024), Image.Resampling.LANCZOS)

    # Save high-res PNG for in-app display and assets
    png_path = "assets/icon.png"
    master_img.resize((256, 256), Image.Resampling.LANCZOS).save(png_path, "PNG")

    # Generate multi-resolution ICO with all Windows standard sizes
    # Windows taskbar uses 32x32, 40x40, 48x48 (at 100%, 125%, 150% scaling)
    # Windows titlebar uses 16x16, 20x20, 24x24
    # Explorer uses 256x256, 128x128, 64x64, 48x48, 32x32, 16x16
    sizes = [256, 128, 64, 48, 32, 24, 16]
    images = []
    for s in sizes:
        img_s = master_img.resize((s, s), Image.Resampling.LANCZOS)
        images.append(img_s)

    ico_path = "assets/icon.ico"
    # In PIL, save the first image and append the rest as sizes
    images[0].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[1:]
    )

    print(f"Successfully generated {ico_path} and {png_path} with sizes: {sizes}")

if __name__ == '__main__':
    generate_icons()
