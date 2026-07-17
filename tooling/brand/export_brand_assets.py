#!/usr/bin/env python3
"""Rasterize DS Video Player brand SVGs to Android mipmaps and previews."""

from __future__ import annotations

import io
import os
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets" / "brand"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"

PRIMARY = "#6C5CE7"
DARK = "#0F1117"
WHITE = "#FFFFFF"

MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

NOTIFICATION_SIZES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}


def svg_to_png(svg_path: Path, size: int) -> Image.Image:
    png_bytes = cairosvg.svg2png(
        url=str(svg_path),
        output_width=size,
        output_height=size,
    )
    return Image.open(io.BytesIO(png_bytes)).convert("RGBA")


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG", optimize=True)


def export_launcher_icons() -> None:
    mark = BRAND / "logo_mark.svg"
    for folder, size in MIPMAP_SIZES.items():
        save_png(svg_to_png(mark, size), ANDROID_RES / folder / "ic_launcher.png")


def export_notification_icons() -> None:
    icon = BRAND / "notification_icon.svg"
    for folder, size in NOTIFICATION_SIZES.items():
        save_png(svg_to_png(icon, size), ANDROID_RES / folder / "ic_notification.png")


def export_flutter_assets() -> None:
    splash = BRAND / "logo_splash.svg"
    save_png(svg_to_png(splash, 256), ROOT / "assets" / "icons" / "app_icon.png")
    save_png(svg_to_png(splash, 512), ROOT / "assets" / "icons" / "app_icon_512.png")
    save_png(svg_to_png(BRAND / "favicon.svg", 32), ROOT / "assets" / "icons" / "favicon.png")

    previews = BRAND / "previews"
    previews.mkdir(parents=True, exist_ok=True)

    icon_192 = svg_to_png(splash, 192)
    for name, bg in [("icon_preview_light.png", WHITE), ("icon_preview_dark.png", DARK)]:
        canvas = Image.new("RGBA", (512, 512), bg)
        offset = (160, 120)
        canvas.paste(icon_192, offset, icon_192)
        draw = ImageDraw.Draw(canvas)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
        except OSError:
            font = ImageFont.load_default()
        draw.text((160, 340), "DS Video Player", fill=PRIMARY if bg == WHITE else WHITE, font=font)
        save_png(canvas, previews / name)

    concept_files = [
        "concept_01_d_play.svg",
        "concept_02_ds_monogram.svg",
        "concept_03_rounded_play_frame.svg",
        "concept_04_media_glyph.svg",
        "concept_05_lens_aperture.svg",
    ]
    for i, filename in enumerate(concept_files, start=1):
        concept = BRAND / "concepts" / filename
        save_png(svg_to_png(concept, 256), previews / f"concept_{i:02d}_preview.png")


def main() -> None:
    export_launcher_icons()
    export_notification_icons()
    export_flutter_assets()
    print("Brand assets exported successfully.")


if __name__ == "__main__":
    main()
