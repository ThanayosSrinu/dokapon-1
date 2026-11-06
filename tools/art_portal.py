"""The Portal's own place, in assets/custom/portal/: the hilltop at dusk, the great ring,
its flare, and a small picture of each stage for its card. tools/make_art.py runs this.
Everything is original and made only from code.

The site is drawn far larger than the 1280 by 720 window, so that a wider window shows
more of it instead of an edge. Places are given relative to the stage, the part that a
1280 by 720 window shows. portal/PortalSite.gd must agree with the numbers marked below."""
import json
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw
from make_art import OUT, hexc, shade, x2
from art_kit import BAYER, ellipse_tier, lerp_color, outline_outside, tree

PORTAL = OUT / "portal"
SITE_W, SITE_H = 1000, 560
STAGE_X, STAGE_Y = 180, 100
# PortalSite.gd: these, in art pixels on the stage, are half its screen places.
RING_X, RING_FEET_Y = 202, 214
HORIZON_Y = 150
RING_W, RING_H, RING_FRAMES = 120, 176, 8
# board/WorldAmbience.gd: GATE_FRAMES must agree. These are art pixels; the file is 2x.
BOARD_GATE_W, BOARD_GATE_H, BOARD_GATE_FRAMES = 30, 40, 6
CARD_PICTURE_W, CARD_PICTURE_H = 200, 72

SKY = ["#1c1642", "#2c1f63", "#4a2a7f", "#7a3a8c", "#b84f80", "#e87a62", "#f9b268", "#fddf98"]
SWIRL = ["#2d1b7e", "#3f2cc2", "#3c6fe8", "#4cc6f0", "#a6f4f0", "#ffffff"]
STONE, STONE_DARK, STONE_LIGHT = hexc("#b9b4c0"), hexc("#7c7688"), hexc("#e4dfe6")
PAVE, PAVE_LIGHT, WALL = hexc("#b8aec8"), hexc("#d8cfe0"), hexc("#6f6680")
ROAD, ROAD_DARK, ROAD_EDGE = hexc("#d9b98a"), hexc("#c29c6c"), hexc("#8e6e50")
GLOW = hexc("#8ff2f5")


def to_site(x, y):
    """A place on the stage, as a place on the whole site."""
    return x + STAGE_X, y + STAGE_Y


def paint_sky(image):
    px = image.load()
    colors = [hexc(c) for c in SKY]
    bottom = STAGE_Y + HORIZON_Y + 10
    for y in range(bottom):
        for x in range(SITE_W):
            band = y / bottom * (len(colors) - 1) + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.6
            px[x, y] = colors[max(0, min(len(colors) - 1, int(band + 0.5)))]
    rng = random.Random(4)
    for _ in range(420):
        x, y = rng.randrange(SITE_W), rng.randrange(int(bottom * 0.55))
        fade = y / (bottom * 0.55)
        if rng.random() > fade:
            px[x, y] = hexc("#fff4d6") if rng.random() < 0.3 else hexc("#a9a6e0")


def ridge_line(x, seed, parts):
    return sum(math.sin(x * f + seed * (i + 1)) * a for i, (f, a) in enumerate(parts))


def paint_ridges(image):
    """Mountains, then two dark hills, each lit along its top by the last of the sun."""
    px = image.load()
    layers = (
        (HORIZON_Y - 34, 2.0, [(0.013, 22), (0.031, 11), (0.07, 4)], hexc("#5a3a86"), hexc("#a55a8a")),
        (HORIZON_Y - 14, 5.0, [(0.009, 14), (0.024, 7)], hexc("#3b3a75"), hexc("#8a5a84")),
        (HORIZON_Y - 2, 8.0, [(0.011, 8), (0.03, 3)], hexc("#27486b"), hexc("#5f7a78")),
    )
    bottom = STAGE_Y + HORIZON_Y + 30
    for base, seed, parts, body, rim in layers:
        for x in range(SITE_W):
            top = int(STAGE_Y + base + ridge_line(x, seed, parts))
            for y in range(top, bottom):
                px[x, y] = rim if y == top else body


def paint_grass(image):
    """The hilltop, a bank of grass that gets lighter towards the viewer's feet."""
    px = image.load()
    ramp = [hexc(c) for c in ("#1f5a4a", "#256a4c", "#2f7f4f", "#3f9a50", "#57b253", "#79c858")]
    crest = STAGE_Y + HORIZON_Y
    for x in range(SITE_W):
        top = int(crest + ridge_line(x, 11.0, [(0.008, 5), (0.021, 2)]))
        for y in range(top, SITE_H):
            depth = min((y - top) / 200.0, 1.0)
            band = depth * (len(ramp) - 1) + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.7
            px[x, y] = ramp[max(0, min(len(ramp) - 1, int(band + 0.5)))]
        px[x, top] = hexc("#b9b070")
    draw = ImageDraw.Draw(image)
    rng = random.Random(9)
    for _ in range(900):
        x, y = rng.randrange(SITE_W), rng.randrange(crest + 10, SITE_H - 2)
        lit = (y - crest) / (SITE_H - crest)
        if rng.random() < 0.06:
            draw.point((x, y), fill=[hexc("#fff4d6"), hexc("#ffd957"), hexc("#ff8ad0")][rng.randrange(3)])
            draw.point((x, y + 1), fill=hexc("#215e43"))
        else:
            color = hexc("#a8ea6b") if lit > 0.5 and rng.random() < 0.5 else hexc("#215e43")
            draw.line((x, y, x, y + 2), fill=color)
            draw.point((x + 1, y + 1), fill=color)


def paint_trees(image):
    light, middle, dark = hexc("#3f8a5a"), hexc("#28684f"), hexc("#1c4a45")
    for x, base, radius in ((-120, 164, 26), (-74, 170, 34), (-30, 160, 20), (20, 156, 16),
                            (392, 158, 18), (446, 164, 30), (510, 170, 38), (580, 162, 26),
                            (640, 172, 34), (-170, 172, 30), (700, 166, 28)):
        # tree() only reaches the width of the menu's art, so each gets its own sheet.
        sheet = Image.new("RGBA", (radius * 3, SITE_H), (0, 0, 0, 0))
        tree(sheet, radius + radius // 2, to_site(0, base)[1], radius, light, middle, dark)
        image.alpha_composite(sheet, (max(to_site(x, 0)[0] - radius - radius // 2, 0), 0))


def paint_road(image):
    """The road up to the steps, from the bottom of the picture."""
    px = image.load()
    cx, _ = to_site(RING_X, 0)
    for y in range(STAGE_Y + 262, SITE_H):
        progress = (y - STAGE_Y - 262) / 100.0
        half = int(26 + progress * 16)
        for x in range(cx - half, cx + half + 1):
            edge = abs(x - cx) >= half - 1
            color = ROAD_EDGE if edge else ROAD
            if not edge and BAYER[y % 4][x % 4] == 3 and (x // 4) % 3 == 0:
                color = ROAD_DARK
            px[x, y] = color


def paint_steps(image):
    """Two round steps with stairs up the middle. The ring stands on the top one."""
    px = image.load()
    cx, feet = to_site(RING_X, RING_FEET_Y)
    for y in range(feet - 26, feet + 72):
        for x in range(cx - 160, cx + 161):
            d = ((x - cx) / 156) ** 2 + ((y - feet - 24) / 46) ** 2
            if d <= 1.0 and (x + y) % 2 == 0:
                px[x, y] = shade(px[x, y], 0.8)
    ellipse_tier(image, cx, feet + 18, 138, 32, 5, PAVE, WALL)
    ellipse_tier(image, cx, feet + 2, 96, 22, 7, PAVE_LIGHT, WALL)
    draw = ImageDraw.Draw(image)
    top = feet + 18
    for step in range(9):
        half = 24 + step
        y = top + step * 4
        draw.rectangle((cx - half, y, cx + half, y + 2), fill=hexc("#efe8e0"))
        draw.rectangle((cx - half, y + 3, cx + half, y + 3), fill=hexc("#8d84a0"))
        px[cx - half - 1, y + 1] = hexc("#20161f")
        px[cx + half + 1, y + 1] = hexc("#20161f")


def paint_light(image):
    """The Portal's light, spilling down the steps."""
    px = image.load()
    cx, feet = to_site(RING_X, RING_FEET_Y)
    for y in range(feet - 30, feet + 96):
        for x in range(cx - 130, cx + 131):
            d = ((x - cx) / 128) ** 2 + ((y - feet - 16) / 76) ** 2
            if d <= 1.0 and BAYER[y % 4][x % 4] < (1.0 - d) * 11:
                px[x, y] = lerp_color(px[x, y], GLOW, 0.34)


def standing_stone(image, x, base, height):
    draw = ImageDraw.Draw(image)
    light, dark = hexc("#a9a4b8"), hexc("#6d6780")
    draw.polygon([(x - 7, base), (x - 5, base - height + 8), (x, base - height),
                  (x + 5, base - height + 8), (x + 7, base)], fill=light)
    draw.polygon([(x, base - height), (x + 5, base - height + 8), (x + 7, base), (x, base)], fill=dark)
    middle = base - height + 18
    draw.rectangle((x - 2, middle, x + 2, middle + 10), fill=hexc("#7fe9f2"))
    draw.rectangle((x - 1, middle + 2, x + 1, middle + 5), fill=hexc("#ffffff"))
    for y in (middle + 18, middle + 26):
        draw.line((x - 3, y, x + 3, y), fill=hexc("#514a62"))


def site():
    image = Image.new("RGBA", (SITE_W, SITE_H), (0, 0, 0, 255))
    paint_sky(image)
    paint_ridges(image)
    paint_grass(image)
    paint_trees(image)
    paint_road(image)
    paint_steps(image)
    cx, feet = to_site(RING_X, RING_FEET_Y)
    stones = Image.new("RGBA", (SITE_W, SITE_H), (0, 0, 0, 0))
    for offset, base, height in ((-118, 18, 62), (118, 18, 62), (-76, 4, 46), (76, 4, 46)):
        standing_stone(stones, cx + offset, feet + base, height)
    outline_outside(stones)
    image.alpha_composite(stones)
    paint_light(image)
    return image


def ring():
    """Eight frames of the great ring: the menu's Portal, drawn larger."""
    sheet = Image.new("RGBA", (RING_W * RING_FRAMES, RING_H), (0, 0, 0, 0))
    cx, cy, rx, ry = RING_W / 2 - 0.5, 84.0, 40.0, 62.0
    colors = [hexc(c) for c in SWIRL]
    px = sheet.load()
    draw = ImageDraw.Draw(sheet)
    for frame in range(RING_FRAMES):
        phase = frame / RING_FRAMES * math.tau
        for y in range(160):
            for x in range(RING_W):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                r, a = math.hypot(dx, dy), math.atan2(dy, dx)
                sx = x + frame * RING_W
                if r < 1.0:
                    value = 0.5 + 0.5 * math.sin(a * 3 + r * 9 - phase)
                    value = value * 0.75 + (1 - r) * 0.45 + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.14
                    px[sx, y] = colors[max(0, min(5, int(value * 6)))]
                elif r < 1.26:
                    turn = (a + math.pi) / math.tau * 20
                    block = int(turn)
                    seam = turn - block < 0.07
                    lit = dx - dy * 0.4 > 0
                    color = STONE_DARK if seam or not lit else STONE_LIGHT if r < 1.09 else STONE
                    if block % 2 == 0 and 1.1 < r < 1.19 and not seam:
                        color = hexc("#a6f4f0") if math.sin(block * 0.8 - phase) > 0 else hexc("#4cc6f0")
                    px[sx, y] = color
        left = frame * RING_W
        draw.rectangle((left + 28, 158, left + 91, 166), fill=STONE)
        draw.line((left + 28, 158, left + 91, 158), fill=STONE_LIGHT)
        draw.rectangle((left + 22, 167, left + 97, 173), fill=STONE_DARK)
    return outline_outside(sheet)


def flare():
    """White light that fills the ring. PortalSite.gd fades it in."""
    image = Image.new("RGBA", (RING_W, RING_H), (0, 0, 0, 0))
    px = image.load()
    cx, cy, rx, ry = RING_W / 2 - 0.5, 84.0, 41.0, 63.0
    for y in range(RING_H):
        for x in range(RING_W):
            r = math.hypot((x - cx) / rx, (y - cy) / ry)
            if r < 1.0 and BAYER[y % 4][x % 4] < (1.0 - r) * 40:
                px[x, y] = hexc("#ffffff") if r < 0.6 else hexc("#c9fbf6")
    return image


def stage_picture(map_file):
    """A small view of a stage, drawn from its real map file, so it shows the real island."""
    spaces = json.loads(Path(map_file).read_text(encoding="utf-8"))["spaces"]
    w, h = CARD_PICTURE_W, CARD_PICTURE_H
    # The same for every map, so a small trip looks small.
    scale = 3.0
    xs = [s["x"] for s in spaces]
    ys = [s["y"] for s in spaces]
    left = w / 2 - (min(xs) + max(xs)) / 2 * scale
    top = h / 2 - (min(ys) + max(ys)) / 2 * scale
    points = [(left + s["x"] * scale, top + s["y"] * scale) for s in spaces]
    image = Image.new("RGBA", (w, h), hexc("#3f8fd8"))
    px = image.load()

    def nearest(x, y):
        return min(math.hypot(x - a, y - b) for a, b in points)

    for y in range(h):
        for x in range(w):
            wave = BAYER[y % 4][(x + y // 4) % 4]
            color = hexc("#2f7ac4") if (y // 3) % 2 and wave < 4 else hexc("#3f8fd8")
            d = nearest(x, y)
            shore = d + math.sin(x * 0.7) * 0.8 + math.cos(y * 0.9) * 0.8
            if shore < 5.0:
                color = hexc("#6fc05c") if (x + y) % 3 else hexc("#4fa557")
            elif shore < 6.4:
                color = hexc("#f1dc9c")
            elif shore < 8.0:
                color = hexc("#7fcbea")
            px[x, y] = color
    draw = ImageDraw.Draw(image)
    by_id = {s["id"]: s for s in spaces}
    for space in spaces:
        for other in space.get("to", []):
            a, b = space, by_id[other]
            draw.line((left + a["x"] * scale, top + a["y"] * scale,
                       left + b["x"] * scale, top + b["y"] * scale), fill=hexc("#e8cf96"))
    rng = random.Random(6)
    for _ in range(90):
        x, y = rng.randrange(w), rng.randrange(h)
        if 1.5 < nearest(x, y) < 3.8 and px[x, y][:3] != (232, 207, 150):
            draw.rectangle((x, y, x + 1, y + 1), fill=hexc("#2f7a4f"))
            draw.point((x, y), fill=hexc("#4fae55"))
    portal = next(s for s in spaces if s["type"] == "PORTAL")
    cx, cy = int(left + portal["x"] * scale), int(top + portal["y"] * scale)
    draw.ellipse((cx - 3, cy - 7, cx + 3, cy), fill=hexc("#4cc6f0"), outline=hexc("#e4dfe6"))
    draw.rectangle((0, 0, w - 1, h - 1), outline=hexc("#20161f"))
    return image


def board_gate():
    """The Portal on the island, small enough to stand behind a space. One row of frames."""
    w, h = BOARD_GATE_W, BOARD_GATE_H
    sheet = Image.new("RGBA", (w * BOARD_GATE_FRAMES, h), (0, 0, 0, 0))
    cx, cy = (w - 1) / 2, 19.0
    rx, ry = 11.0, 15.0
    for frame in range(BOARD_GATE_FRAMES):
        image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = image.load()
        for y in range(h - 4):
            for x in range(w):
                u, v = (x - cx) / rx, (y - cy) / ry
                d = math.hypot(u, v)
                if d <= 0.74:
                    turn = math.atan2(v, u) * 2 + d * 7 - frame * math.tau / BOARD_GATE_FRAMES
                    band = (math.sin(turn) + 1) / 2 * (1 - d * 0.7)
                    px[x, y] = hexc(SWIRL[min(int(band * len(SWIRL)) + 1, len(SWIRL) - 1)])
                elif d <= 1.0:
                    shine = u * -0.5 + v * -0.8
                    px[x, y] = STONE_LIGHT if shine > 0.42 else STONE_DARK if shine < -0.38 else STONE
        draw = ImageDraw.Draw(image)
        draw.rectangle((5, h - 7, w - 6, h - 5), fill=STONE)
        draw.line((5, h - 7, w - 6, h - 7), fill=STONE_LIGHT)
        draw.rectangle((2, h - 4, w - 3, h - 2), fill=STONE_DARK)
        draw.line((2, h - 4, w - 3, h - 4), fill=STONE)
        outline_outside(image)
        sheet.alpha_composite(image, (frame * w, 0))
    return sheet


def make_portal():
    PORTAL.mkdir(exist_ok=True)
    x2(site()).save(PORTAL / "site.png")
    x2(ring()).save(PORTAL / "ring.png")
    x2(flare()).save(PORTAL / "flare.png")
    x2(board_gate()).save(PORTAL / "board_gate.png")
    for stage in ("grass_s", "grass_m", "grass_l"):
        x2(stage_picture(f"maps/{stage}_1.json")).save(PORTAL / f"stage_{stage}.png")
