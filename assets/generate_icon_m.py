#!/usr/bin/env python3
"""
Morpho Mac App Icon — Typographic M
Clean brand typeface M on deep dark background.
Uses Gloock serif for elegant, authoritative brand identity.
"""

import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SCALE = 4
SZ    = 1024 * SCALE
OUT   = "/Users/zhengyuelin/Things/morpho/assets/morpho-app-icon.png"

FONTS_DIR = "/Users/zhengyuelin/.claude/skills/canvas-design/canvas-fonts"

# Apple macOS Sequoia production template:
# The app icon plate in a 1024 canvas is 824x824 with 100px margins.
PLATE_SIZE_1X = 824
PLATE_MARGIN_1X = 100
PLATE_SCALE = PLATE_SIZE_1X / 1024.0
PLATE_SIZE = int(SZ * PLATE_SCALE)

FONT_DIR_CANDIDATES = [
    os.environ.get("MORPHO_ICON_FONTS_DIR", ""),
    "/Users/zhengyuelin/.claude/plugins/cache/anthropic-agent-skills/document-skills/69c0b1a06741/skills/canvas-design/canvas-fonts",
    FONTS_DIR,
]

def resolve_fonts_dir():
    for path in FONT_DIR_CANDIDATES:
        if path and os.path.isdir(path):
            return path
    raise FileNotFoundError(
        "Cannot locate icon font directory. Set MORPHO_ICON_FONTS_DIR to a folder containing Gloock-Regular.ttf."
    )

FONTS_DIR = resolve_fonts_dir()

cx, cy = SZ / 2.0, SZ / 2.0

xs = np.linspace(0, SZ-1, SZ, dtype=np.float32)
ys = np.linspace(0, SZ-1, SZ, dtype=np.float32)
XX, YY = np.meshgrid(xs, ys)
PX, PY = XX - cx, YY - cy

def sm(e0, e1, x):
    t = np.clip((x-e0)/(e1-e0+1e-9), 0, 1)
    return t*t*(3-2*t)

# ── 1. BACKGROUND ─────────────────────────────────────────────────────────────
# Deep cool-charcoal. Very subtle center warmth — like moonlight on dark stone.
dn  = np.sqrt((PX/cx)**2 + (PY/cy)**2)
tb  = np.clip(dn / 1.4, 0, 1) ** 2.2

bg = np.zeros((SZ, SZ, 4), np.uint8)
bg[:,:,0] = np.clip(14 + (5  - 14)*tb, 0, 255).astype(np.uint8)
bg[:,:,1] = np.clip(14 + (5  - 14)*tb, 0, 255).astype(np.uint8)
bg[:,:,2] = np.clip(26 + (10 - 26)*tb, 0, 255).astype(np.uint8)
bg[:,:,3] = 255
img = Image.fromarray(bg, 'RGBA')

# ── 2. TYPOGRAPHIC M ──────────────────────────────────────────────────────────
# Use Gloock — elegant classical serif with strong brand presence.
# Optically centered with subtle vertical nudge upward for visual balance.

M_COLOR = (240, 236, 225, 255)   # warm cream

font_path = os.path.join(FONTS_DIR, "Gloock-Regular.ttf")

# Find the right font size so M fills ~62% of the icon plate width
target_width_ratio = 0.62
target_width = PLATE_SIZE * target_width_ratio

font_size = int(SZ * 0.75)
font = ImageFont.truetype(font_path, font_size)

# Measure using getbbox on a temp draw
tmp = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
tmp_draw = ImageDraw.Draw(tmp)
bbox = tmp_draw.textbbox((0, 0), "M", font=font)
text_w = bbox[2] - bbox[0]
text_h = bbox[3] - bbox[1]

# Scale font size to hit target width
font_size = int(font_size * (target_width / text_w))
font = ImageFont.truetype(font_path, font_size)

# Re-measure
bbox = tmp_draw.textbbox((0, 0), "M", font=font)
text_w = bbox[2] - bbox[0]
text_h = bbox[3] - bbox[1]

# Center the glyph — compensate for bbox offsets
x = cx - (bbox[0] + text_w / 2)
y = cy - (bbox[1] + text_h / 2) - SZ * 0.005  # tiny optical lift

# Render M onto a separate layer
m_layer = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
m_draw = ImageDraw.Draw(m_layer)
m_draw.text((x, y), "M", font=font, fill=M_COLOR)

# Subtle luminosity: top of M slightly brighter, bottom slightly darker
# — as if soft natural light falls from above. Very gentle, almost imperceptible.
m_arr = np.array(m_layer, dtype=np.float32)
m_mask = m_arr[:,:,3] / 255.0

text_top = cy + y - SZ * 0.3
text_bot = cy + y + text_h + SZ * 0.05
vert_t = np.clip((YY - text_top) / (text_bot - text_top + 1e-6), 0, 1)
lum_shift = (1.0 - vert_t) * 6.0 - 3.0   # +3 at top, -3 at bottom

for ch in range(3):
    m_arr[:,:,ch] = np.clip(m_arr[:,:,ch] + lum_shift * m_mask, 0, 255)

m_layer = Image.fromarray(m_arr.astype(np.uint8), 'RGBA')
img = Image.alpha_composite(img, m_layer)

# ── 3. MASK + DOWNSAMPLE ──────────────────────────────────────────────────────
img_1024 = img.resize((1024, 1024), Image.LANCZOS)
cr   = int(PLATE_SIZE_1X * 0.2237)
mask = Image.new('L', (1024, 1024), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    [
        PLATE_MARGIN_1X,
        PLATE_MARGIN_1X,
        PLATE_MARGIN_1X + PLATE_SIZE_1X - 1,
        PLATE_MARGIN_1X + PLATE_SIZE_1X - 1,
    ],
    radius=cr,
    fill=255,
)
img_1024.putalpha(mask)

img_1024.save(OUT, 'PNG')
print(f"Saved: {OUT}")
img_1024.resize((512, 512), Image.LANCZOS).save(OUT.replace('.png', '-512.png'))
print("Done.")
