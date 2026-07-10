#!/usr/bin/env python3
"""Generate App Store Connect assets for CODEYAM COUNTER from brand + real captures."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = "/Users/jaredcosulich/workspace/codeyam/codeyam-counter"
SHOTS = os.path.join(ROOT, ".codeyam/scenarios/screenshots")
OUT = os.path.join(ROOT, ".codeyam/store/appstore")
os.makedirs(os.path.join(OUT, "icon"), exist_ok=True)
os.makedirs(os.path.join(OUT, "screenshots", "6.9-inch"), exist_ok=True)

# ---- Brand tokens (from Sources/AppCore/Theme.swift) ----
BG        = (0x0C, 0x0D, 0x08)
SURFACE   = (0x15, 0x17, 0x0F)
INK       = (0xEA, 0xE8, 0xE0)
INK_MUTED = (0x8D, 0x8F, 0x80)
LINE      = (0x2A, 0x2C, 0x20)
ACCENT    = (0xD5, 0xF5, 0x60)   # lime
ON_ACCENT = (0x0B, 0x0A, 0x08)
DOTS = {
    "lime":   (0xD5, 0xF5, 0x60),
    "coffee": (0xFF, 0x7A, 0x4D),
    "steps":  (0x4D, 0xB5, 0xFF),
    "bugs":   (0xC9, 0x8B, 0xFF),
}

MENLO_BOLD  = "/System/Library/Fonts/Menlo.ttc"   # index 1 = Bold
ARIAL_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"

def font(path, size, index=0):
    return ImageFont.truetype(path, size, index=index)

def vgrad(size, top, bottom):
    w, h = size
    base = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        base.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return base.resize((w, h))

def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m

# ==========================================================================
# ICON
# ==========================================================================
def plus(draw, cx, cy, arm, thick, color, radius=None):
    if radius is None:
        radius = thick // 2
    draw.rounded_rectangle([cx - arm, cy - thick // 2, cx + arm, cy + thick // 2], radius=radius, fill=color)
    draw.rounded_rectangle([cx - thick // 2, cy - arm, cx + thick // 2, cy + arm], radius=radius, fill=color)

def icon_plus(path):
    S = 1024
    img = vgrad((S, S), (0x12, 0x14, 0x0C), BG).convert("RGB")
    # soft lime glow behind the plus
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    plus(ImageDraw.Draw(glow), S // 2, int(S * 0.46), 250, 120, ACCENT + (255,), radius=60)
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    d = ImageDraw.Draw(img)
    plus(d, S // 2, int(S * 0.46), 250, 120, ACCENT, radius=60)
    # signature dot row near the bottom
    order = ["lime", "coffee", "steps", "bugs"]
    r, gap = 42, 150
    total = gap * (len(order) - 1)
    x0 = S // 2 - total // 2
    y = int(S * 0.80)
    for i, k in enumerate(order):
        x = x0 + i * gap
        d.ellipse([x - r, y - r, x + r, y + r], fill=DOTS[k])
    img.convert("RGB").save(path)

def icon_minimal(path):
    """Minimalist icon: flat bg, hard-edged lime plus, four flat signature dots.
    No glow, no gradient, no text — the real app palette, restrained."""
    S = 1024
    img = Image.new("RGB", (S, S), BG)
    d = ImageDraw.Draw(img)
    # dominant, hard-edged (radius=0) lime plus, biased slightly up for the dot row
    plus(d, S // 2, int(S * 0.44), 250, 116, ACCENT, radius=0)
    # one tight row of four flat signature dots (lime, coffee, steps, bugs)
    order = ["lime", "coffee", "steps", "bugs"]
    r, gap = 34, 118
    total = gap * (len(order) - 1)
    x0 = S // 2 - total // 2
    y = int(S * 0.80)
    for i, k in enumerate(order):
        x = x0 + i * gap
        d.ellipse([x - r, y - r, x + r, y + r], fill=DOTS[k])
    img.save(path)

def icon_app_motif(path):
    S = 1024
    img = Image.new("RGB", (S, S), BG)
    d = ImageDraw.Draw(img)
    # dark field with a giant ghost number + dot row
    num_f = font(ARIAL_BLACK, 620)
    d.text((S * 0.52, S * 0.40), "7", font=num_f, fill=(0x20, 0x22, 0x18), anchor="mm")
    # four counter dots, top-left arc, active lime ringed
    order = ["lime", "coffee", "steps", "bugs"]
    r, gap = 46, 130
    x0, y = 150, 210
    for i, k in enumerate(order):
        x = x0 + i * gap
        if k == "lime":
            d.ellipse([x - r - 16, y - r - 16, x + r + 16, y + r + 16], outline=ACCENT, width=12)
        d.ellipse([x - r, y - r, x + r, y + r], fill=DOTS[k])
    # bottom lime increment band with a dark plus
    band_top = int(S * 0.74)
    d.rectangle([0, band_top, S, S], fill=ACCENT)
    plus(d, int(S * 0.80), (band_top + S) // 2, 70, 34, ON_ACCENT, radius=17)
    tf = font(MENLO_BOLD, 60, index=1)
    d.text((90, (band_top + S) // 2), "TAP +", font=tf, fill=ON_ACCENT, anchor="lm")
    img.save(path)

# ==========================================================================
# SCREENSHOTS  (6.9" iPhone: 1290 x 2796)
# ==========================================================================
SW, SH = 1290, 2796

SCREENS = [
    ("counter-large-value--iphone-16.png",
     "COUNT ANYTHING", "one giant, gorgeous number"),
    ("counter-all-counters-list--iphone-16.png",
     "EVERY TALLY,\nONE TAP AWAY", "push-ups · coffee · steps · bugs"),
    ("counter-graph-open--iphone-16.png",
     "WATCH IT\nADD UP", "every count as a graph + event log"),
    ("counter-settings-open-over-number--iphone-16.png",
     "MAKE IT YOURS", "color · count-by · sound · haptics"),
    ("counter-app-settings-sound-and-haptic-on--iphone-16.png",
     "ONE-HANDED\nBY DESIGN", "left or right — your call"),
]

def wrap_lines(text):
    return text.split("\n")

def screenshot(src, headline, sub, out_path):
    canvas = vgrad((SW, SH), (0x14, 0x16, 0x0E), BG).convert("RGB")
    d = ImageDraw.Draw(canvas)

    # --- caption block ---
    head_f = font(ARIAL_BLACK, 92)
    sub_f  = font(MENLO_BOLD, 40, index=1)
    margin = 96
    y = 150
    for line in wrap_lines(headline):
        d.text((margin, y), line, font=head_f, fill=INK)
        y += 104
    # lime accent tick under the headline
    d.rounded_rectangle([margin, y + 6, margin + 132, y + 20], radius=7, fill=ACCENT)
    y += 46
    d.text((margin, y), sub.upper(), font=sub_f, fill=INK_MUTED)

    # --- device screenshot ---
    shot = Image.open(src).convert("RGB")
    target_w = 1010
    scale = target_w / shot.width
    target_h = int(shot.height * scale)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    radius = 96
    mask = rounded_mask((target_w, target_h), radius)

    top_y = 560
    x = (SW - target_w) // 2

    # soft drop shadow
    shadow = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([x, top_y + 26, x + target_w, top_y + target_h + 26],
                         radius=radius, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(48))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")

    canvas.paste(shot, (x, top_y), mask)
    # thin hairline border
    d2 = ImageDraw.Draw(canvas)
    d2.rounded_rectangle([x, top_y, x + target_w - 1, top_y + target_h - 1],
                         radius=radius, outline=(0x3A, 0x3D, 0x30), width=3)
    canvas.save(out_path)

if __name__ == "__main__":
    icon_plus(os.path.join(OUT, "icon", "AppIcon-1024-A-plus.png"))
    icon_app_motif(os.path.join(OUT, "icon", "AppIcon-1024-B-motif.png"))
    icon_minimal(os.path.join(OUT, "icon", "AppIcon-1024-C-minimal.png"))
    for i, (fname, head, sub) in enumerate(SCREENS, 1):
        src = os.path.join(SHOTS, fname)
        out = os.path.join(OUT, "screenshots", "6.9-inch", f"{i:02d}-{fname.replace('--iphone-16','').replace('.png','')}.png")
        screenshot(src, head, sub, out)
    print("done")
