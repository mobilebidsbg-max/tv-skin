"""Make the blurred, darkened copy of a wallpaper that the glass areas draw from.

usage: python3 make_blur.py <in.jpg> <out_blur.jpg> [<out_thumb.jpg>]
The wallpaper never moves, so the launcher crops this pre-blurred copy instead of blurring live.
With a third path it also writes a 240x135 thumbnail for the Settings wallpaper picker.
"""
import sys
from typing import Optional

from PIL import Image, ImageEnhance, ImageFilter

SIZE = (1920, 1080)
RADIUS = 30
BRIGHTNESS = 0.8
QUALITY = 85


THUMB = (240, 135)


def main(src: str, dst: str, thumb: Optional[str] = None) -> None:
    image = Image.open(src).convert("RGB")
    if image.size != SIZE:
        image = image.resize(SIZE, Image.LANCZOS)
    blurred = image.filter(ImageFilter.GaussianBlur(RADIUS))
    ImageEnhance.Brightness(blurred).enhance(BRIGHTNESS).save(dst, "JPEG", quality=QUALITY, optimize=True)
    if thumb:
        image.resize(THUMB, Image.LANCZOS).save(thumb, "JPEG", quality=QUALITY, optimize=True)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    main(*sys.argv[1:])
