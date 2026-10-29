"""Generate CSMDESK brand assets (icon + wordmark + .ico files).

Deterministic: no external assets, only system fonts. Run from repo root:

    python tools/generate_brand_assets.py

Outputs (overwrites):
    res/icon.png, res/icon.ico, res/logo.svg, res/logo-header.svg
    flutter/assets/icon.png, icon.ico, logo.png, logo_light.png, logo_dark.png
    flutter/windows/runner/resources/app_icon.ico
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"

NAVY_TOP = (10, 24, 40)
NAVY_BOTTOM = (18, 49, 77)
TEAL = (45, 212, 191)
WHITE = (255, 255, 255)
WORD_DARK = (10, 24, 40)
WORD_LIGHT = (255, 255, 255)


def _gradient(size: int) -> Image.Image:
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = tuple(
            round(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3)
        )
    return img.resize((size, size), Image.Resampling.BICUBIC)


def icon(size: int = 1024, pad_ratio: float = 0.0) -> Image.Image:
    """Rounded-square app icon with a 'C' mark and a remote-signal accent."""
    ss = 4  # supersample for smooth edges
    w = size * ss
    canvas = Image.new("RGBA", (w, w), (0, 0, 0, 0))

    pad = int(w * pad_ratio)
    box = (pad, pad, w - pad, w - pad)
    radius = int((box[2] - box[0]) * 0.22)

    mask = Image.new("L", (w, w), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)

    grad = _gradient(w).convert("RGBA")
    canvas.paste(grad, (0, 0), mask)

    draw = ImageDraw.Draw(canvas)
    # subtle inner hairline for depth
    draw.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 28), width=max(2, w // 340))

    # 'C' glyph
    font = ImageFont.truetype(FONT_BOLD, int(w * 0.56))
    text = "C"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    cx, cy = w // 2 - int(w * 0.045), w // 2
    draw.text(
        (cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]),
        text,
        font=font,
        fill=WHITE,
    )

    # remote signal arcs to the right of the C
    arc_cx, arc_cy = int(w * 0.70), int(w * 0.50)
    for i, r in enumerate((0.075, 0.125, 0.175)):
        rr = int(w * r)
        width = max(3, int(w * 0.022))
        draw.arc(
            (arc_cx - rr, arc_cy - rr, arc_cx + rr, arc_cy + rr),
            start=-62,
            end=62,
            fill=TEAL if i == 0 else (45, 212, 191, 200 - i * 45),
            width=width,
        )
    dot = max(4, int(w * 0.028))
    draw.ellipse(
        (arc_cx - dot, arc_cy - dot, arc_cx + dot, arc_cy + dot), fill=TEAL
    )

    out = canvas.resize((size, size), Image.Resampling.LANCZOS)
    return out


def wordmark(height: int = 220, light: bool = False) -> Image.Image:
    """Horizontal lockup: icon + CSMDESK wordmark."""
    icon_size = height
    mark = icon(icon_size)
    font_size = int(height * 0.52)
    font = ImageFont.truetype(FONT_BOLD, font_size)
    text = "CSMDESK"

    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bbox = probe.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    gap = int(height * 0.22)
    width = icon_size + gap + tw + int(height * 0.08)

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(mark, (0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (icon_size + gap - bbox[0], height / 2 - (bbox[3] - bbox[1]) / 2 - bbox[1]),
        text,
        font=font,
        fill=WORD_LIGHT if light else WORD_DARK,
    )
    # teal accent dot after the wordmark
    dot = max(6, int(height * 0.055))
    x = icon_size + gap + tw + dot
    y = height // 2 + int(height * 0.16)
    draw.ellipse((x - dot, y - dot, x + dot, y + dot), fill=TEAL)
    return canvas


ICON_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0a1828"/>
      <stop offset="1" stop-color="#12314d"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="1024" height="1024" rx="225" fill="url(#g)"/>
  <rect x="3" y="3" width="1018" height="1018" rx="222" fill="none" stroke="#ffffff" stroke-opacity="0.11" stroke-width="6"/>
  <text x="455" y="512" font-family="Arial, Helvetica, sans-serif" font-size="573" font-weight="700"
        fill="#ffffff" text-anchor="middle" dominant-baseline="central">C</text>
  <g fill="none" stroke="#2dd4bf" stroke-linecap="round">
    <path d="M700 425 A 85 85 0 0 1 700 599" stroke-width="22"/>
    <path d="M737 380 A 140 140 0 0 1 737 644" stroke-opacity="0.78" stroke-width="22"/>
    <path d="M774 335 A 195 195 0 0 1 774 689" stroke-opacity="0.5" stroke-width="22"/>
  </g>
  <circle cx="700" cy="512" r="28" fill="#2dd4bf"/>
</svg>
"""

LOGO_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1152 256" width="1152" height="256">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0a1828"/>
      <stop offset="1" stop-color="#12314d"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="256" height="256" rx="56" fill="url(#g)"/>
  <text x="114" y="128" font-family="Arial, Helvetica, sans-serif" font-size="143" font-weight="700"
        fill="#ffffff" text-anchor="middle" dominant-baseline="central">C</text>
  <g fill="none" stroke="#2dd4bf" stroke-linecap="round">
    <path d="M175 106 A 21 21 0 0 1 175 150" stroke-width="6"/>
    <path d="M184 95 A 35 35 0 0 1 184 161" stroke-opacity="0.78" stroke-width="6"/>
  </g>
  <circle cx="175" cy="128" r="7" fill="#2dd4bf"/>
  <text x="312" y="128" font-family="Arial, Helvetica, sans-serif" font-size="133" font-weight="700"
        fill="#0a1828" dominant-baseline="central" letter-spacing="2">CSMDESK</text>
  <circle cx="1108" cy="168" r="14" fill="#2dd4bf"/>
</svg>
"""


def main() -> None:
    res = ROOT / "res"
    assets = ROOT / "flutter" / "assets"
    runner = ROOT / "flutter" / "windows" / "runner" / "resources"
    for d in (res, assets, runner):
        d.mkdir(parents=True, exist_ok=True)

    master = icon(1024)
    master.save(res / "icon.png")
    master.save(assets / "icon.png")

    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(res / "icon.ico", sizes=ico_sizes)
    master.save(assets / "icon.ico", sizes=ico_sizes)
    master.save(runner / "app_icon.ico", sizes=ico_sizes)

    wordmark(256).save(assets / "logo.png")
    wordmark(256, light=True).save(assets / "logo_dark.png")
    wordmark(256, light=False).save(assets / "logo_light.png")

    (res / "logo.svg").write_text(ICON_SVG, encoding="utf-8")
    (res / "logo-header.svg").write_text(LOGO_SVG, encoding="utf-8")

    print("brand assets written")


if __name__ == "__main__":
    main()
