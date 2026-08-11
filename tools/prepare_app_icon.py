"""Derive the app-icon layers used by flutter_launcher_icons.

Takes one square source image (the STFR artwork) and writes three files into
assets/icon/:

  app_icon.png             full-bleed square, used for legacy launcher icons
                           and as the Play Console store listing icon
  app_icon_foreground.png  artwork inset into the adaptive-icon safe zone,
                           on transparency
  app_icon_background.png  gradient sampled from the source, filling the area
                           an adaptive mask crops into

Adaptive icons (Android 8+) render a 108dp canvas but only guarantee the
centre 66dp is visible; launchers crop the rest to a circle, squircle or
rounded square. A full-bleed square source therefore loses its edges — for
this artwork that means the "STFR" band along the bottom. Insetting the
foreground keeps the whole design visible on every launcher shape.

Usage:
    python tools/prepare_app_icon.py path/to/source.png
    python tools/prepare_app_icon.py path/to/source.png --full-bleed
    python tools/prepare_app_icon.py path/to/source.png --safe-fraction 0.68

--full-bleed skips the inset and lets the mask crop the artwork instead.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required:  pip install Pillow")


REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "assets" / "icon"
CANVAS = 1024  # Generate above 512 so every density downscales cleanly.

# Android guarantees only the centre 66/108 of an adaptive icon is visible.
DEFAULT_SAFE_FRACTION = 66 / 108


def _load_square(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.width != image.height:
        side = min(image.width, image.height)
        left = (image.width - side) // 2
        top = (image.height - side) // 2
        image = image.crop((left, top, left + side, top + side))
        print(f"  note: source was {path.name} non-square, centre-cropped to {side}x{side}")
    return image.resize((CANVAS, CANVAS), Image.LANCZOS)


def _sample(image: Image.Image, fx: float, fy: float) -> tuple[int, int, int]:
    """Average a small patch so a single stray pixel cannot skew the colour."""
    size = max(2, CANVAS // 64)
    cx, cy = int(fx * CANVAS), int(fy * CANVAS)
    left = max(0, min(CANVAS - size, cx - size // 2))
    top = max(0, min(CANVAS - size, cy - size // 2))
    patch = image.crop((left, top, left + size, top + size)).convert("RGB")
    # Box-resampling down to one pixel is exactly an average of the patch.
    return patch.resize((1, 1), Image.BOX).getpixel((0, 0))  # type: ignore[return-value]


def _gradient(start: tuple[int, int, int], end: tuple[int, int, int]) -> Image.Image:
    """Diagonal gradient, matching how the source artwork is shaded."""
    background = Image.new("RGB", (CANVAS, CANVAS))
    pixels = background.load()
    denominator = 2 * (CANVAS - 1)
    for y in range(CANVAS):
        for x in range(CANVAS):
            t = (x + y) / denominator
            pixels[x, y] = (
                round(start[0] + (end[0] - start[0]) * t),
                round(start[1] + (end[1] - start[1]) * t),
                round(start[2] + (end[2] - start[2]) * t),
            )
    return background


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="square source PNG")
    parser.add_argument(
        "--full-bleed",
        action="store_true",
        help="do not inset the foreground; let the adaptive mask crop the artwork",
    )
    parser.add_argument(
        "--safe-fraction",
        type=float,
        default=DEFAULT_SAFE_FRACTION,
        help=f"fraction of the canvas the artwork occupies (default {DEFAULT_SAFE_FRACTION:.3f})",
    )
    args = parser.parse_args()

    if not args.source.exists():
        return f"source not found: {args.source}"
    if not 0.2 <= args.safe_fraction <= 1.0:
        return "--safe-fraction must be between 0.2 and 1.0"

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source = _load_square(args.source)

    # 1. Full-bleed square: legacy launcher icons and the Play Console listing.
    #    Flattened onto its own top-left colour so no alpha reaches the store.
    icon = Image.new("RGB", (CANVAS, CANVAS), _sample(source, 0.02, 0.02))
    icon.paste(source, (0, 0), source)
    icon.save(OUT_DIR / "app_icon.png")

    # 2. Adaptive background: gradient sampled from the source's own top corners,
    #    so whatever the mask reveals still matches the artwork.
    start, end = _sample(source, 0.02, 0.02), _sample(source, 0.98, 0.10)
    _gradient(start, end).save(OUT_DIR / "app_icon_background.png")

    # 3. Adaptive foreground.
    foreground = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    if args.full_bleed:
        foreground.paste(source, (0, 0), source)
        treatment = "full-bleed (mask will crop the STFR band)"
    else:
        inner = max(1, round(CANVAS * args.safe_fraction))
        offset = (CANVAS - inner) // 2
        foreground.paste(source.resize((inner, inner), Image.LANCZOS), (offset, offset))
        treatment = f"inset to {args.safe_fraction:.0%} (whole design stays visible)"
    foreground.save(OUT_DIR / "app_icon_foreground.png")

    print(f"Wrote 3 layers to {OUT_DIR.relative_to(REPO_ROOT)}")
    print(f"  gradient   #{start[0]:02X}{start[1]:02X}{start[2]:02X}"
          f" -> #{end[0]:02X}{end[1]:02X}{end[2]:02X}")
    print(f"  foreground {treatment}")
    print("\nNext:  dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    result = main()
    if isinstance(result, str):
        sys.exit(result)
    sys.exit(result)
