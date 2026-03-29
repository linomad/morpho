#!/usr/bin/env python3
"""Generate Morpho Mac App Icon — Liminal Flux FINAL
Clean S-arc symbol. Vivid glow. Museum quality.
"""

import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SCALE = 2
SZ = 1024 * SCALE
FONT_DIR = "/Users/zhengyuelin/.claude/skills/canvas-design/canvas-fonts"
OUT = "/Users/zhengyuelin/Things/morpho/assets/morpho-app-icon.png"

cx, cy = SZ / 2.0, SZ / 2.0

xs = np.linspace(0, SZ-1, SZ, dtype=np.float32)
ys = np.linspace(0, SZ-1, SZ, dtype=np.float32)
XX, YY = np.meshgrid(xs, ys)
PX, PY = XX - cx, YY - cy

def sm(e0, e1, x):
    t = np.clip((x-e0)/(e1-e0+1e-9), 0, 1)
    return t*t*(3-2*t)

def over(a: Image.Image, b: Image.Image) -> Image.Image:
    return Image.alpha_composite(a, b)

# ── 1. BACKGROUND ─────────────────────────────────────────────────────────────
dn = np.sqrt((PX/cx)**2 + (PY/cy)**2)
tb = np.clip(dn/1.35, 0, 1)**1.6
bg = np.zeros((SZ,SZ,4), np.uint8)
bg[:,:,0] = np.clip( 9 + ( 3- 9)*tb, 0,255)
bg[:,:,1] = np.clip(11 + ( 4-11)*tb, 0,255)
bg[:,:,2] = np.clip(34 + (10-34)*tb, 0,255)
bg[:,:,3] = 255
img = Image.fromarray(bg,'RGBA')

# Deep center warmth
cd = np.sqrt(PX**2+PY**2)
cw = sm(480*SCALE, 0, cd)**1.6
cw_layer = np.zeros((SZ,SZ,4), np.uint8)
cw_layer[:,:,2] = np.clip(cw*30, 0,255).astype(np.uint8)
cw_layer[:,:,3] = np.clip(cw*60, 0,255).astype(np.uint8)
img = over(img, Image.fromarray(cw_layer,'RGBA'))

# ── 2. ARC GEOMETRY ───────────────────────────────────────────────────────────
R      = 298 * SCALE
STROKE = 70  * SCALE
OFF    = 86  * SCALE

A1cx, A1cy = cx-OFF, cy-OFF;  A1s, A1e = 25,  235
A2cx, A2cy = cx+OFF, cy+OFF;  A2s, A2e = 205, 55

def arc_img(acx, acy, r, s, e, sw, col, blur=0):
    L = Image.new('RGBA',(SZ,SZ),(0,0,0,0))
    ImageDraw.Draw(L).arc([acx-r,acy-r,acx+r,acy+r], start=s,end=e, fill=col, width=int(sw))
    return L if blur==0 else L.filter(ImageFilter.GaussianBlur(blur))

def build_arc(acx,acy,r,s,e, col_main, col_glow, col_hot):
    """Four passes: atmospheric glow, dark body, mid bright, additive specular."""
    base = Image.new('RGBA',(SZ,SZ),(0,0,0,0))
    # Atmospheric wide halo
    base = over(base, arc_img(acx,acy,r,s,e, STROKE+110*SCALE, col_glow, 38*SCALE))
    base = over(base, arc_img(acx,acy,r,s,e, STROKE+50*SCALE,  col_glow, 15*SCALE))
    # Main body: vivid blue
    base = over(base, arc_img(acx,acy,r,s,e, STROKE, col_main))
    # Inner bright band (75% width) — strong luminance ridge
    mid_col = tuple(min(255,c+80) if i<3 else 230 for i,c in enumerate(col_main))
    base = over(base, arc_img(acx,acy,r,s,e, int(STROKE*0.5), mid_col, SCALE*2))
    # Hot specular line — additive, very bright
    hot  = arc_img(acx,acy,r,s,e, max(4,int(STROKE*0.20)), col_hot, SCALE*1.2)
    ba   = np.array(base, dtype=np.float32)
    ha   = np.array(hot,  dtype=np.float32)
    w    = ha[:,:,3:4]/255.0 * 1.2  # boost additive strength
    ba[:,:,:3] = np.clip(ba[:,:,:3] + ha[:,:,:3]*w, 0,255)
    return Image.fromarray(ba.astype(np.uint8),'RGBA')

arc1 = build_arc(A1cx,A1cy,R,A1s,A1e,
    col_main =(55, 168,255,248),
    col_glow =(28,  95,210, 95),
    col_hot  =(228,250,255,245))

arc2 = build_arc(A2cx,A2cy,R,A2s,A2e,
    col_main =(46, 155,252,248),
    col_glow =(22,  82,198, 95),
    col_hot  =(218,244,255,245))

img = over(img, arc1)
img = over(img, arc2)

# ── 3. CENTER STAR ────────────────────────────────────────────────────────────
ia = np.array(img, dtype=np.float32)
halo = sm(110*SCALE, 5*SCALE, cd)**2.8
ia[:,:,0] = np.clip(ia[:,:,0]+halo*20,   0,255)
ia[:,:,1] = np.clip(ia[:,:,1]+halo*32,   0,255)
ia[:,:,2] = np.clip(ia[:,:,2]+halo*88,   0,255)
core = sm(17*SCALE, 1*SCALE, cd)
ia[:,:,:3] = np.clip(ia[:,:,:3]+core[:,:,None]*255, 0,255)
img = Image.fromarray(ia.astype(np.uint8),'RGBA')

# ── 4. DOTS ───────────────────────────────────────────────────────────────────
ex = A1cx + R*math.cos(math.radians(A1e))
ey = A1cy + R*math.sin(math.radians(A1e))
ta = math.radians(132)
ts = 56*SCALE

dl = Image.new('RGBA',(SZ,SZ),(0,0,0,0))
dd = ImageDraw.Draw(dl)
specs=[(1.0,22*SCALE,235),(2.0,14*SCALE,182),(3.0,8*SCALE,122)]
for dist,dr,al in specs:
    dx=int(ex+dist*ts*math.cos(ta)); dy=int(ey+dist*ts*math.sin(ta)); dr=int(dr)
    for i in range(5,0,-1):
        gr=dr+i*int(6*SCALE); ga=int(al*0.09*(1-i/5))
        if ga>0: dd.ellipse([dx-gr,dy-gr,dx+gr,dy+gr],fill=(50,152,255,ga))
    dd.ellipse([dx-dr,dy-dr,dx+dr,dy+dr],fill=(92,192,255,al))
    sdr=max(int(3*SCALE),dr//3); sx,sy=dx-dr//3,dy-dr//3
    dd.ellipse([sx-sdr,sy-sdr,sx+sdr,sy+sdr],fill=(238,252,255,int(al*0.62)))
dl = dl.filter(ImageFilter.GaussianBlur(SCALE*0.5))
img = over(img, dl)

# ── 5. DOWNSAMPLE + MASK ──────────────────────────────────────────────────────
img = img.resize((1024,1024), Image.LANCZOS)
cr = int(1024*0.2237)
mask = Image.new('L',(1024,1024),0)
ImageDraw.Draw(mask).rounded_rectangle([0,0,1023,1023],radius=cr,fill=255)
img.putalpha(mask)

# ── 6. TYPE ───────────────────────────────────────────────────────────────────
try:
    font = ImageFont.truetype(os.path.join(FONT_DIR,"BricolageGrotesque-Regular.ttf"),37)
    tl=Image.new('RGBA',(1024,1024),(0,0,0,0))
    td=ImageDraw.Draw(tl)
    txt="morpho"; bb=td.textbbox((0,0),txt,font=font)
    td.text(((1024-(bb[2]-bb[0]))//2, 1024-104), txt, font=font, fill=(82,140,225,58))
    tl=tl.filter(ImageFilter.GaussianBlur(0.4))
    img=Image.alpha_composite(img,tl); img.putalpha(mask)
    print("Type done.")
except Exception as e: print(f"Font: {e}")

# ── 7. SAVE ───────────────────────────────────────────────────────────────────
img.save(OUT,'PNG'); print(f"Saved {OUT}")
img.resize((512,512),Image.LANCZOS).save(OUT.replace('.png','-512.png'))
print("Done.")
