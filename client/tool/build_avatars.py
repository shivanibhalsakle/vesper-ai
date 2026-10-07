"""Builds the app's avatar images from the illustrated originals.

    python client/tool/build_avatars.py

Reads the artwork in <repo>/avatars/<group>/ (large PNGs, some on a white
square) and writes small, perfectly circular WebP files with a transparent
outside to client/assets/avatars/<group>/<id>.webp.

For each image it:
  1. finds the artwork (from the existing transparency, or by separating it
     from the near-white background),
  2. crops to the artwork's bounding box,
  3. resizes to SIZE x SIZE (which also rounds off any artwork that was a
     slightly squashed circle),
  4. applies an anti-aliased circular mask a hair inside the edge (so no
     white fringe survives), leaving everything outside fully transparent.

It prints how circular each source was and exits non-zero if the output is
not a clean circle. The originals are never modified. Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 384  # px; shown at up to ~130 dp, so 3x density is covered
INSET = 1.5  # px inside the detected edge, removing any white fringe
SUPERSAMPLE = 4
WEBP_QUALITY = 88

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "avatars"
OUTPUT = ROOT / "client" / "assets" / "avatars"

# (id, accessible label), in display order. Source files are matched by their
# sorted filename within each group, so the order here must follow that sort.
GROUPS = {
    "wanderlust": [
        ("wanderlust_01", "Smiling traveller in sunglasses"),
        ("wanderlust_02", "Photographer with a camera"),
        ("wanderlust_03", "Hiker in a beanie"),
        ("wanderlust_04", "Dreamer resting her chin on her hand"),
        ("wanderlust_05", "Curly-haired adventurer"),
        ("wanderlust_06", "Winking explorer in a cap"),
        ("wanderlust_07", "Thoughtful wanderer in a sun hat"),
        ("wanderlust_08", "Bearded mountaineer"),
    ],
    "wilderness": [
        ("wilderness_snake", "Explorer snake in a hat"),
        ("wilderness_monkey", "Monkey with a golden compass"),
        ("wilderness_retriever", "Golden retriever at sunset"),
        ("wilderness_wolf", "Howling wolf"),
        ("wilderness_panda", "Panda on a lakeside bench"),
        ("wilderness_tiger", "Tiger on the savanna"),
        ("wilderness_beaver", "Beaver by the lake"),
        ("wilderness_cat", "Content cat in a red scarf"),
        ("wilderness_dolphin", "Dolphin on the reef"),
        ("wilderness_horse", "Galloping horse"),
    ],
    "moods": [
        ("moods_pastel", "Pastel mood"),
        ("moods_magenta", "Magenta mood"),
        ("moods_ocean", "Ocean mood"),
        ("moods_peach", "Peach mood"),
        ("moods_mint", "Mint mood"),
        ("moods_vanilla", "Vanilla mood"),
    ],
}


def artwork_mask(image: Image.Image) -> Image.Image:
    """A '1' mask that is on where the artwork is, off where it is empty."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if alpha.getextrema()[0] < 250:  # already has real transparency
        return alpha.point(lambda v: 255 if v > 127 else 0, mode="1")

    # Opaque image on a near-white background: anything that differs from the
    # corner colour by more than a few levels is artwork.
    rgb = rgba.convert("RGB")
    corners = [rgb.getpixel(p) for p in [(0, 0), (rgb.width - 1, 0), (0, rgb.height - 1),
                                         (rgb.width - 1, rgb.height - 1)]]
    background = tuple(sorted(c[i] for c in corners)[len(corners) // 2] for i in range(3))
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, background)).convert("L")
    return diff.point(lambda v: 255 if v > 6 else 0, mode="1")


def fit_circle(mask: Image.Image) -> tuple[tuple[int, int, int, int], float, float]:
    """The artwork's bounding box, how much wider than tall it is, and how
    well the artwork fills an ellipse inscribed in that box (1.0 = perfectly)."""
    left, top, right, bottom = mask.getbbox()
    ideal = Image.new("1", mask.size, 0)
    ImageDraw.Draw(ideal).ellipse((left, top, right, bottom), fill=1)
    inter = ImageChops.logical_and(mask, ideal).histogram()[255]
    union = ImageChops.logical_or(mask, ideal).histogram()[255]
    stretch = (right - left) / (bottom - top)
    return (left, top, right, bottom), stretch, inter / union


def circular_webp(source: Path) -> tuple[Image.Image, float, float]:
    image = Image.open(source)
    box, stretch, fit = fit_circle(artwork_mask(image))

    # Crop to the artwork's own box and resize to a square. If the original
    # was a slightly squashed circle (an ellipse), this restores it to a true
    # circle; for the already-round ones the change is imperceptible.
    square = image.convert("RGB").crop(box).resize((SIZE, SIZE), Image.LANCZOS)

    big = SIZE * SUPERSAMPLE
    mask = Image.new("L", (big, big), 0)
    edge = INSET * SUPERSAMPLE
    ImageDraw.Draw(mask).ellipse((edge, edge, big - edge, big - edge), fill=255)
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)

    out = square.convert("RGBA")
    out.putalpha(mask)
    return out, stretch, fit


def verify(path: Path) -> list[str]:
    """Problems with a written file (empty list = a clean circle)."""
    problems = []
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    if image.size != (SIZE, SIZE):
        problems.append(f"size {image.size}")
    for corner in [(0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1)]:
        if alpha.getpixel(corner) != 0:
            problems.append(f"corner {corner} not transparent")
    if alpha.getpixel((SIZE // 2, SIZE // 2)) != 255:
        problems.append("centre not opaque")
    covered = sum(alpha.histogram()[128:]) / (SIZE * SIZE)
    # A circle inset by INSET px from the frame: pi/4 of the square, shrunk.
    expected = (3.14159265 / 4) * ((SIZE / 2 - INSET) / (SIZE / 2)) ** 2
    if abs(covered - expected) > 0.003:
        problems.append(f"covers {covered:.3f} of the square, a circle covers {expected:.3f}")
    left, top, right, bottom = alpha.point(lambda v: 255 if v > 127 else 0).getbbox()
    if min(left, top) > 3 or max(SIZE - right, SIZE - bottom) > 3:
        problems.append(f"circle does not fill the frame: {(left, top, right, bottom)}")
    return problems


def main() -> int:
    failed = False
    for group, avatars in GROUPS.items():
        sources = sorted((SOURCE / group).glob("*.png"))
        if len(sources) != len(avatars):
            print(f"{group}: found {len(sources)} images but expected {len(avatars)}")
            return 1
        target = OUTPUT / group
        target.mkdir(parents=True, exist_ok=True)

        for source, (avatar_id, label) in zip(sources, avatars):
            result, stretch, fit = circular_webp(source)
            path = target / f"{avatar_id}.webp"
            result.save(path, "WEBP", quality=WEBP_QUALITY, method=6)
            problems = verify(path)
            status = "ok" if not problems else "PROBLEM: " + "; ".join(problems)
            if abs(stretch - 1) > 0.01:
                off = abs(stretch - 1) * 100
                squash = f"{off:.1f}% {'wider' if stretch > 1 else 'taller'} than round, fixed"
            else:
                squash = "round"
            print(f"{group:11} {avatar_id:22} source {squash:30} fit {fit:.3f}  "
                  f"{path.stat().st_size // 1024:3d} KB  {status}  <- {source.name}")
            failed = failed or bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
