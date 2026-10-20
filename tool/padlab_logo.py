#!/usr/bin/env python3
"""Génère la marque PadLab et toutes ses déclinaisons Android.

Le logo n'est pas une image déposée à la main : il est dessiné ici, donc
reproductible. Un seul signe — un P dont le bol est un anneau avec un point
d'acier, la lettre et le stick analogique étant la même forme.

    python3 tool/padlab_logo.py

Sorties :
  apps/mobile/android/app/src/main/res/mipmap-*/ic_launcher.png
  apps/mobile/android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
  apps/mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  apps/mobile/android/app/src/main/res/drawable-*/splash_logo.png
  apps/mobile/assets/logo/padlab_mark.png, padlab_lockup.png
  /home/user/apercu_05/*.png (planches de contrôle)
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "apps/mobile/android/app/src/main/res")
ASSETS = os.path.join(ROOT, "apps/mobile/assets/logo")
PREVIEW = "/home/user/apercu_05"
FONT_BOLD = os.path.join(ROOT, "packages/pad_ui/assets/fonts/InterDisplay-Bold.ttf")
FONT_MED = os.path.join(ROOT, "packages/pad_ui/assets/fonts/Inter-Medium.ttf")

BG_TOP = (0x1B, 0x1D, 0x22)
BG_BOTTOM = (0x0E, 0x0F, 0x12)
INK = (0xED, 0xEE, 0xF0)
STEEL = (0x8F, 0xAA, 0xC9)
STEEL_DARK = (0x6C, 0x7C, 0x8E)
CANVAS = (0x0B, 0x0C, 0x0E)

SS = 4  # facteur de suréchantillonnage


def _rgba(color, alpha=255):
    return (color[0], color[1], color[2], alpha)


def _vgradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        img.putpixel(
            (0, y),
            (
                round(top[0] + (bottom[0] - top[0]) * t),
                round(top[1] + (bottom[1] - top[1]) * t),
                round(top[2] + (bottom[2] - top[2]) * t),
            ),
        )
    return img.resize((w, h), Image.BILINEAR).convert("RGBA")


def draw_mark(size: int, *, tile: bool = True, pad: float = 0.0) -> Image.Image:
    """Dessine la marque PadLab carrée.

    `tile` : fond graphite arrondi. Sans tuile, l'image est transparente et ne
    contient que le monogramme (icône adaptative).
    `pad` : marge relative autour du monogramme (zone de sécurité Android).
    """
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    radius = round(s * 0.225)
    if tile:
        base = _vgradient((s, s), BG_TOP, BG_BOTTOM)
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, s - 1, s - 1), radius=radius, fill=255
        )
        img.paste(base, (0, 0), mask)
        # Liseré acier : donne du relief sans briller.
        edge = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(edge).rounded_rectangle(
            (0, 0, s - 1, s - 1),
            radius=radius,
            outline=_rgba(STEEL, 46),
            width=max(1, round(s * 0.006)),
        )
        img = Image.alpha_composite(img, edge)

    d = ImageDraw.Draw(img)
    k = (1.0 - 2.0 * pad)  # échelle utile du monogramme
    off = pad

    def X(v):
        return round(s * (off + v * k))

    def Y(v):
        return round(s * (off + v * k))

    def U(v):
        return round(s * v * k)

    # --- monogramme -------------------------------------------------------
    stem_l, stem_r = 0.315, 0.435
    stem_t, stem_b = 0.225, 0.775
    bowl_cx, bowl_cy = 0.525, 0.382
    bowl_outer, bowl_inner = 0.215, 0.098

    # Jambage : trait épais à bouts ronds.
    d.rounded_rectangle(
        (X(stem_l), Y(stem_t), X(stem_r), Y(stem_b)),
        radius=U((stem_r - stem_l) / 2),
        fill=_rgba(INK),
    )
    # Bol : anneau plein, évidé du centre.
    d.ellipse(
        (
            X(bowl_cx - bowl_outer),
            Y(bowl_cy - bowl_outer),
            X(bowl_cx + bowl_outer),
            Y(bowl_cy + bowl_outer),
        ),
        fill=_rgba(INK),
    )
    d.ellipse(
        (
            X(bowl_cx - bowl_inner),
            Y(bowl_cy - bowl_inner),
            X(bowl_cx + bowl_inner),
            Y(bowl_cy + bowl_inner),
        ),
        fill=(0, 0, 0, 0),
    )
    # Point d'acier : le stick, au centre du bol.
    dot = 0.050
    d.ellipse(
        (
            X(bowl_cx - dot),
            Y(bowl_cy - dot),
            X(bowl_cx + dot),
            Y(bowl_cy + dot),
        ),
        fill=_rgba(STEEL),
    )

    return img.resize((size, size), Image.LANCZOS)


def draw_lockup(width: int = 1400, *, dark: bool = True) -> Image.Image:
    """Marque + wordmark + signature. Pour l'onboarding et les planches."""
    scale = width / 1400
    h = round(760 * scale)
    bg = CANVAS if dark else (0xF2, 0xF2, 0xEF)
    img = Image.new("RGBA", (width, h), _rgba(bg))

    mark_size = round(320 * scale)
    mark = draw_mark(mark_size)
    # Halo discret derrière la marque.
    glow = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        (
            width // 2 - mark_size,
            round(70 * scale),
            width // 2 + mark_size,
            round(70 * scale) + mark_size * 2,
        ),
        fill=_rgba((0x5A, 0x6B, 0x7D), 34 if dark else 18),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(round(60 * scale)))
    img = Image.alpha_composite(img, glow)
    img.paste(mark, (width // 2 - mark_size // 2, round(96 * scale)), mark)

    d = ImageDraw.Draw(img)
    ink = INK if dark else (0x16, 0x18, 0x1B)
    muted = (0x8D, 0x91, 0x99) if dark else (0x6C, 0x72, 0x7C)

    font = ImageFont.truetype(FONT_BOLD, round(150 * scale))
    text = "PadLab"
    box = d.textbbox((0, 0), text, font=font)
    tw = box[2] - box[0]
    d.text((width // 2 - tw // 2 - box[0], round(470 * scale)), text, font=font, fill=_rgba(ink))

    tag = "TEST  ·  DIAGNOSTIC  ·  REMAPPING"
    f2 = ImageFont.truetype(FONT_MED, round(34 * scale))
    box2 = d.textbbox((0, 0), tag, font=f2)
    tw2 = box2[2] - box2[0]
    d.text(
        (width // 2 - tw2 // 2 - box2[0], round(650 * scale)),
        tag,
        font=f2,
        fill=_rgba(muted),
    )
    return img


def _save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print(f"  {os.path.relpath(path, ROOT)}  {img.size[0]}×{img.size[1]}")


def main() -> None:
    os.makedirs(PREVIEW, exist_ok=True)
    print("Icônes d'application (tuile arrondie)")
    for density, px in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        _save(draw_mark(px), f"{RES}/mipmap-{density}/ic_launcher.png")

    print("Icône adaptative (avant-plan détouré, zone de sécurité respectée)")
    for density, px in {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }.items():
        # 0.10 : zone de sécurité Android (les 2/3 centraux restent visibles
        # quel que soit le masque). À 0,20 le monogramme paraissait perdu.
        _save(
            draw_mark(px, tile=False, pad=0.10),
            f"{RES}/mipmap-{density}/ic_launcher_foreground.png",
        )

    print("Écran de lancement")
    for density, px in {
        "mdpi": 120,
        "hdpi": 180,
        "xhdpi": 240,
        "xxhdpi": 360,
        "xxxhdpi": 480,
    }.items():
        _save(draw_mark(px), f"{RES}/drawable-{density}/splash_logo.png")

    print("Ressources embarquées")
    _save(draw_mark(512), f"{ASSETS}/padlab_mark.png")
    _save(draw_lockup(1200), f"{ASSETS}/padlab_lockup.png")

    print("Planches de contrôle")
    _save(draw_lockup(1200), f"{PREVIEW}/lockup_sombre.png")
    _save(draw_lockup(1200, dark=False), f"{PREVIEW}/lockup_clair.png")

    # Planche : la marque à toutes les tailles réelles d'icône.
    sheet = Image.new("RGBA", (760, 300), _rgba(CANVAS))
    x = 40
    for px in (192, 144, 96, 72, 48, 32):
        m = draw_mark(px)
        sheet.paste(m, (x, 150 - px // 2), m)
        x += px + 36
    _save(sheet, f"{PREVIEW}/tailles.png")


if __name__ == "__main__":
    main()
