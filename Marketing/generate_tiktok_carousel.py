#!/usr/bin/env python3
"""Generate a ready-to-post 9:16 TikTok carousel from real Snail Mail UI."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Marketing" / "TikTokCarousel"
BACKGROUND = ROOT / "Marketing" / "SourceArt" / "tiktok-paper-trail.png"
FONT = "/System/Library/Fonts/Avenir Next.ttc"
SIZE = (1080, 1920)
INK = (55, 70, 59)
TERRACOTTA = (151, 91, 68)


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


def build(index: int, output_name: str, screen_name: str,
          headline: str, subhead: str) -> None:
    background = Image.open(BACKGROUND).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
    canvas = background.convert("RGBA")

    # Quiet paper panels preserve contrast while retaining the illustrated edge.
    panel = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel)
    panel_draw.rounded_rectangle((80, 125, 1000, 520), 52, fill=(255, 251, 241, 230))
    canvas = Image.alpha_composite(canvas, panel)

    draw = ImageDraw.Draw(canvas)
    draw.text((125, 168), "SNAIL MAIL", font=font(27), fill=TERRACOTTA)
    draw.multiline_text((120, 226), headline, font=font(76), fill=INK, spacing=2)
    draw.text((124, 430), subhead, font=font(28), fill=INK)

    phone = phone_image(screen_name)
    x = (SIZE[0] - phone.width) // 2
    y = 570
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
    draw.rounded_rectangle((124, 1670, 956, 1772), 50, fill=(76, 123, 91))
    footer = "swipe to follow the journey" if index < len(SLIDES) else "now on the app store"
    box = draw.textbbox((0, 0), footer, font=font(29))
    footer_width = box[2] - box[0]
    draw.text(((SIZE[0] - footer_width) / 2, 1702), footer, font=font(29), fill=(255, 252, 244))
    draw.text((125, 1810), f"{index} / {len(SLIDES)}", font=font(23), fill=INK)

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT / output_name, "PNG", optimize=True)


if __name__ == "__main__":
    for number, slide in enumerate(SLIDES, start=1):
        build(number, *slide)
    print(f"Created {len(SLIDES)} TikTok carousel slides in {OUT}")
