#!/usr/bin/env python3
"""Generate App Store Connect AND Google Play assets for CODEYAM COUNTER.

One generator drives both stores so their icons cannot drift: the Play 512x512
icon is rendered from the SAME geometry as the shipped Android adaptive icon
(`android/app/src/main/res/drawable/ic_launcher_{foreground,background}.xml`),
which in turn matches the iOS minimal icon.
"""
import os
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Repo root, derived from this script's location (store/appstore/gen_assets.py)
# so the generator is portable and carries no hardcoded laptop path.
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHOTS = os.path.join(ROOT, ".codeyam/scenarios/screenshots")
OUT = os.path.join(ROOT, "store/appstore")
OUT_PLAY = os.path.join(ROOT, "store/playstore")
os.makedirs(os.path.join(OUT, "icon"), exist_ok=True)
os.makedirs(os.path.join(OUT, "screenshots", "6.9-inch"), exist_ok=True)
os.makedirs(os.path.join(OUT_PLAY, "icon"), exist_ok=True)
os.makedirs(os.path.join(OUT_PLAY, "screenshots", "phone"), exist_ok=True)

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

def render_icon_minimal(S=1024):
    """Minimalist icon: flat bg, hard-edged lime plus, four flat signature dots.
    No glow, no gradient, no text — the real app palette, restrained.

    Every dimension is a fraction of `S` so the identical artwork can be emitted
    at any size — 1024 for App Store Connect, 512 for the Play Store listing —
    without the two drifting into different designs.
    """
    img = Image.new("RGB", (S, S), BG)
    d = ImageDraw.Draw(img)
    # dominant, hard-edged (radius=0) lime plus, biased slightly up for the dot row
    plus(d, S // 2, int(S * 0.44), int(S * 0.2441), int(S * 0.1133), ACCENT, radius=0)
    # one tight row of four flat signature dots (lime, coffee, steps, bugs)
    order = ["lime", "coffee", "steps", "bugs"]
    r, gap = int(S * 0.0332), int(S * 0.1152)
    total = gap * (len(order) - 1)
    x0 = S // 2 - total // 2
    y = int(S * 0.80)
    for i, k in enumerate(order):
        x = x0 + i * gap
        d.ellipse([x - r, y - r, x + r, y + r], fill=DOTS[k])
    return img


def icon_minimal(path):
    render_icon_minimal(1024).save(path)

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
# GOOGLE PLAY
# ==========================================================================
def play_icon_512(path):
    """512x512 32-bit PNG Play Store icon — the SAME artwork as the iOS icon.

    Deliberately rendered from `render_icon_minimal`, i.e. the shipped App Store
    icon (plus mark AND the four signature counter dots), not from the Android
    adaptive launcher icon.

    Those two are not the same drawing, and the difference is a real constraint
    rather than an oversight. An adaptive launcher icon only guarantees the
    centred 66dp of its 108dp foreground is visible — every launcher mask crops
    the rest — so the dot row, which sits at 80% of the icon's height, would be
    sliced off under a circular mask. The launcher icon is therefore plus-only.
    A Play Store listing icon has no such mask (Play applies a gentle rounded
    square), so it can and should carry the full brand mark and match iOS.
    """
    render_icon_minimal(512).save(path)


def feature_graphic(path):
    """1024x500 Play feature graphic — required by Play, no App Store equivalent.

    Rendered at 4x and downsampled. PIL antialiases text but NOT geometry, so
    drawing the plus and the dots straight at 1024x500 leaves visibly stepped
    edges on exactly the shapes the brand is built from; supersampling is what
    makes it read as artwork rather than a screenshot of a diagram.

    Composition follows Play's constraints: the graphic is cropped at the edges
    on some surfaces and can carry a centred play-button chip, so the wordmark
    holds the left third well inside the margins and the icon mark anchors the
    right, with the centre kept quiet.
    """
    SS = 4                      # supersampling factor
    W, H = 1024, 500
    w, h = W * SS, H * SS

    img = vgrad((w, h), (0x18, 0x1B, 0x11), (0x09, 0x0A, 0x06)).convert("RGBA")

    # Soft lime glow anchoring the right-hand mark — gives the flat palette some
    # depth without introducing a second colour.
    # Kept tight and low-alpha on purpose: a wide, strong lime glow washes the
    # whole right half olive, which reads as muddy rather than premium. This
    # should be felt as a halo behind the mark, not seen as a colour field.
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gx, gy, gr = int(w * 0.78), h // 2, int(h * 0.34)
    gd.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=ACCENT + (26,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(int(70 * SS))))

    d = ImageDraw.Draw(img)

    # --- right: the icon mark itself (plus + signature dots), scaled to sit in
    # the banner. Reusing the icon artwork is what makes the listing read as one
    # identity across the tile, the graphic and the installed app.
    mark = int(h * 0.78)
    icon = render_icon_minimal(mark).convert("RGBA")
    # Drop the icon's own dark field so it sits on the gradient, keeping only the
    # lime plus and the coloured dots.
    px = icon.load()
    for yy in range(mark):
        for xx in range(mark):
            r0, g0, b0, _ = px[xx, yy]
            if abs(r0 - BG[0]) <= 12 and abs(g0 - BG[1]) <= 12 and abs(b0 - BG[2]) <= 12:
                px[xx, yy] = (0, 0, 0, 0)
    img.alpha_composite(icon, (int(w * 0.78) - mark // 2, (h - mark) // 2))

    # --- left: wordmark, rule, tagline
    margin = int(72 * SS)
    d.text((margin, int(150 * SS)), "CODEYAM", font=font(ARIAL_BLACK, 78 * SS), fill=INK)
    d.text((margin, int(232 * SS)), "COUNTER", font=font(ARIAL_BLACK, 78 * SS), fill=ACCENT)
    d.rounded_rectangle(
        [margin, int(348 * SS), margin + int(132 * SS), int(360 * SS)],
        radius=6 * SS, fill=ACCENT,
    )
    d.text(
        (margin, int(388 * SS)), "COUNT ANYTHING, BEAUTIFULLY",
        font=font(MENLO_BOLD, 29 * SS, index=1), fill=INK_MUTED,
    )

    img.convert("RGB").resize((W, H), Image.LANCZOS).save(path)


# Play phone screenshots. The Android scenario captures are already 1080x2400 —
# exactly Play's phone spec — so these are copied verbatim, NOT matted onto a
# marketing canvas the way the iOS 6.9" frames are. Play renders listing
# screenshots small, so uncaptioned real captures read better than captioned
# ones; the choice is applied consistently across all five.
PLAY_SCREENS = [
    ("android-counter-large-value", "count-anything"),
    ("android-counter-all-counters-list", "every-tally-one-tap-away"),
    ("android-counter-graph-open", "watch-it-add-up"),
    ("android-counter-counter-settings-open", "make-it-yours"),
    ("android-counter-app-settings-sound-and-haptic-on", "one-handed-by-design"),
]


def play_screenshots():
    out_dir = os.path.join(OUT_PLAY, "screenshots", "phone")
    for i, (slug, label) in enumerate(PLAY_SCREENS, 1):
        src = os.path.join(SHOTS, f"{slug}--phone-portrait.png")
        if not os.path.exists(src):
            raise SystemExit(f"missing Play screenshot source: {src}")
        with Image.open(src) as im:
            if im.size != (1080, 2400):
                raise SystemExit(f"{src} is {im.size}, expected (1080, 2400)")
        shutil.copyfile(src, os.path.join(out_dir, f"{i:02d}-{label}.png"))


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

    # --- Google Play ---
    play_icon_512(os.path.join(OUT_PLAY, "icon", "PlayIcon-512.png"))
    feature_graphic(os.path.join(OUT_PLAY, "feature-graphic-1024x500.png"))
    play_screenshots()
    print("done")
