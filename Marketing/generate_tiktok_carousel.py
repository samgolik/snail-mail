#!/usr/bin/env python3
"""Generate a clean 9:16 TikTok carousel from real Snail Mail UI."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Marketing" / "TikTokCarousel"
FONT = "/System/Library/Fonts/Avenir Next.ttc"
SIZE = (1080, 1920)
INK = (55, 70, 59)
TERRACOTTA = (151, 91, 68)
CREAM = (247, 244, 235)

PALETTES = (
    ((238, 242, 232), INK),
    ((225, 236, 235), INK),
    ((235, 229, 214), INK),
    ((226, 236, 228), INK),
    ((233, 239, 240), INK),
    ((68, 101, 76), (255, 252, 244)),
)


SLIDES = (
    ("01-what-if-texting-had-to-travel.png", "01-snailbox.png",
     "what if texting\nhad to travel?", "meet snail mail"),
    ("02-send-now-open-later.png", "02-journey.png",
     "send it now.\nopen it later.", "the letter stays sealed until it arrives"),
    ("03-distance-sets-the-pace.png", "02-journey.png",
     "distance sets\nthe pace.", "farther friends mean a longer little journey"),
    ("04-friends-not-followers.png", "04-friends.png",
     "friends,\nnot followers.", "private letters. no public feed."),
    ("05-keep-the-ones-that-mattered.png", "05-snail-trail.png",
     "keep the ones\nthat mattered.", "opened letters live in your snail trail"),
    ("06-messages-worth-waiting-for.png", "03-write.png",
     "messages worth\nwaiting for.", "search “snail mail: slow messages” on the app store"),
)


def font(size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size=size, index=index)


def phone_image(filename: str) -> Image.Image:
    source = Image.open(ROOT / "AppStoreScreenshots" / filename).convert("RGB")
    phone = source.crop((74, 430, 1132, 2575))
    height = 1040
    width = round(phone.width * height / phone.height)
    return phone.resize((width, height), Image.Resampling.LANCZOS).convert("RGBA")


def draw_trail(draw: ImageDraw.ImageDraw, y: int, color: tuple[int, int, int]) -> None:
    """Draw the same restrained dotted journey language used by the app."""
    points = ((90, y + 70), (205, y + 25), (330, y + 65), (455, y + 18),
              (585, y + 58), (720, y + 14), (860, y + 48), (990, y + 5))
    for x, py in points:
        draw.ellipse((x - 8, py - 8, x + 8, py + 8), fill=color)


def draw_snail_mark(draw: ImageDraw.ImageDraw, x: int, y: int,
                    color: tuple[int, int, int]) -> None:
    """Draw a minimal geometric snail mark from circles and lines."""
    draw.ellipse((x, y + 20, x + 88, y + 108), outline=color, width=10)
    draw.ellipse((x + 24, y + 44, x + 64, y + 84), outline=color, width=8)
    draw.rounded_rectangle((x + 54, y + 82, x + 155, y + 118), 18, fill=color)
    draw.ellipse((x + 124, y + 60, x + 158, y + 96), fill=color)
    draw.line((x + 137, y + 65, x + 130, y + 36), fill=color, width=6)
    draw.line((x + 151, y + 65, x + 158, y + 36), fill=color, width=6)
    draw.ellipse((x + 124, y + 28, x + 136, y + 40), fill=color)
    draw.ellipse((x + 152, y + 28, x + 164, y + 40), fill=color)


def build(index: int, output_name: str, screen_name: str,
          headline: str, subhead: str) -> None:
    header_color, header_ink = PALETTES[index - 1]
    canvas = Image.new("RGBA", SIZE, CREAM + (255,))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((44, 44, 1036, 530), 56, fill=header_color)
    draw.text((105, 104), "SNAIL MAIL", font=font(27),
              fill=TERRACOTTA if index < 6 else (242, 190, 165))
    draw.multiline_text((100, 170), headline, font=font(78), fill=header_ink, spacing=1)
    draw.text((104, 405), subhead, font=font(28), fill=header_ink)
    draw_trail(draw, 505, (176, 190, 177))
    draw_snail_mark(draw, 820, 420, header_ink)

    phone = phone_image(screen_name)
    x = (SIZE[0] - phone.width) // 2
    y = 610
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_mask = Image.new("L", phone.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        (10, 10, phone.width - 10, phone.height - 10), 55, fill=150
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(25))
    shadow.paste((30, 42, 34, 105), (x + 15, y + 24), shadow_mask)
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(phone, (x, y))

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((124, 1690, 956, 1792), 50, fill=(76, 123, 91))
    footer = "swipe to follow the journey" if index < len(SLIDES) else "now on the app store"
    box = draw.textbbox((0, 0), footer, font=font(29))
    footer_width = box[2] - box[0]
    draw.text(((SIZE[0] - footer_width) / 2, 1722), footer, font=font(29), fill=(255, 252, 244))
    draw.text((125, 1830), f"{index} / {len(SLIDES)}", font=font(23), fill=INK)

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT / output_name, "PNG", optimize=True)


if __name__ == "__main__":
    for number, slide in enumerate(SLIDES, start=1):
        build(number, *slide)
    print(f"Created {len(SLIDES)} TikTok carousel slides in {OUT}")
