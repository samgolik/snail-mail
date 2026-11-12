#!/usr/bin/env python3
"""Build App Store search-result creative variants from approved app UI."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Marketing" / "AppStoreSearch"
SIZE = (1920, 1280)
FONT = "/System/Library/Fonts/Avenir Next.ttc"


VARIANTS = (
    (
        "01-messages-take-time.png",
        ROOT / "Marketing" / "SourceArt" / "snail-trail-paper.png",
        ROOT / "AppStoreScreenshots" / "01-snailbox.png",
        "send a message.\nlet it take its time.",
        "private letters that travel at a snail’s pace",
        (61, 74, 63),
    ),
    (
        "02-distance-makes-it-sweeter.png",
        ROOT / "Marketing" / "SourceArt" / "snail-journey.png",
        ROOT / "AppStoreScreenshots" / "02-journey.png",
        "distance makes\nthe message sweeter.",
        "watch every letter make its little journey",
        (48, 65, 57),
    ),
    (
        "03-less-instant-more-meaningful.png",
        ROOT / "Marketing" / "SourceArt" / "snail-letter.png",
        ROOT / "AppStoreScreenshots" / "03-write.png",
        "less instant.\nmore meaningful.",
        "write now. they open it when the snail arrives.",
        (61, 74, 63),
    ),
)


def font(size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size=size, index=index)


def fit_phone(screen_path: Path) -> Image.Image:
    screen = Image.open(screen_path).convert("RGB")
    # The source is an approved App Store screenshot. Crop to the real device
    # presentation so the search creative uses actual, readable app UI.
    phone = screen.crop((74, 430, 1132, 2575))
    target_height = 1130
    target_width = round(phone.width * target_height / phone.height)
    return phone.resize((target_width, target_height), Image.Resampling.LANCZOS)


def build(name: str, background_path: Path, screen_path: Path,
          headline: str, subhead: str, ink: tuple[int, int, int]) -> None:
    background = Image.open(background_path).convert("RGB")
    canvas = background.resize(SIZE, Image.Resampling.LANCZOS)

    # Subtle wash behind copy ensures accessibility over textured artwork.
    wash = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    wash_draw = ImageDraw.Draw(wash)
    wash_draw.rounded_rectangle((90, 130, 1165, 1030), 54, fill=(255, 251, 241, 218))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), wash)

    phone = fit_phone(screen_path).convert("RGBA")
    phone_x = 1270
    phone_y = 90
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_mask = Image.new("L", phone.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        (12, 12, phone.width - 12, phone.height - 12), 64, fill=150
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(28))
    shadow.paste((35, 48, 38, 100), (phone_x + 18, phone_y + 24), shadow_mask)
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(phone, (phone_x, phone_y))

    draw = ImageDraw.Draw(canvas)
    draw.text((155, 200), "SNAIL MAIL", font=font(31), fill=(145, 91, 70), spacing=6)
    draw.text((150, 300), headline, font=font(98), fill=ink, spacing=8)
    draw.text((155, 610), subhead, font=font(38), fill=ink + (210,))

    icon = Image.open(ROOT / "SnailMail" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png").convert("RGBA")
    icon = icon.resize((112, 112), Image.Resampling.LANCZOS)
    canvas.alpha_composite(icon, (155, 790))
    draw.text((295, 802), "snail mail", font=font(45), fill=ink)
    draw.text((297, 862), "messages worth waiting for", font=font(27), fill=ink + (180,))

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT / name, "PNG", optimize=True)


if __name__ == "__main__":
    for variant in VARIANTS:
        build(*variant)
    print(f"Created {len(VARIANTS)} assets in {OUT}")
