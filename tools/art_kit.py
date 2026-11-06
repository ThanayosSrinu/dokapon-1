"""The UI kit's art, in assets/custom/kit/, and the main menu's scene, in
assets/custom/menu/. tools/make_art.py runs this. Everything is original and made
only from code. Nine-slice art keeps its gradients in the corners and edges and is
tiled, not stretched, so every pixel stays exactly 2x."""
import math
from PIL import Image, ImageDraw
from make_art import (GOLD, GOLD_DARK, GOLD_LIGHT, INK, ITEM_CELL, OUT, hexc, icon_blade,
                      icon_canvas, icon_herb, shade, with_outline, x2)

KIT = OUT / "kit"
MENU = OUT / "menu"
WOOD_DARK, WOOD, WOOD_LIGHT = hexc("#3f2822"), hexc("#6e452b"), hexc("#a4713f")
PAPER, PAPER_DARK = hexc("#f2e2b8"), hexc("#d9bf8a")
ICON_NAMES = ["play", "back", "book", "gear", "door", "coin", "food", "heart", "sword", "boot",
              "wood", "ore", "herb", "die", "bag", "lock", "check", "star", "music", "sound", "cross",
              "spring", "summer", "autumn", "winter", "moon", "shield", "magic"]


def cut_corners(image, amount):
    """Rounds a rectangle off by removing little steps from its corners."""
    px = image.load()
    w, h = image.size
    for y in range(amount):
        for x in range(amount - y):
            for cx, cy in ((x, y), (w - 1 - x, y), (x, h - 1 - y), (w - 1 - x, h - 1 - y)):
                px[cx, cy] = (0, 0, 0, 0)
    return image


def ink_edge(image):
    """Draws an ink line just inside the edge of a shape."""
    px = image.load()
    w, h = image.size
    source = image.copy().load()
    for y in range(h):
        for x in range(w):
            if source[x, y][3] == 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if not (0 <= nx < w and 0 <= ny < h) or source[nx, ny][3] == 0:
                    px[x, y] = INK
                    break
    return image


def outline_outside(image):
    """Draws an ink line just outside everything drawn on `image`."""
    px = image.load()
    w, h = image.size
    source = image.copy().load()
    for y in range(h):
        for x in range(w):
            if source[x, y][3] != 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if 0 <= nx < w and 0 <= ny < h and source[nx, ny][3] != 0:
                    px[x, y] = INK
                    break
    return image


# --- Panels and buttons -----------------------------------------------------

def panel(fill, speck, frame, frame_light, frame_dark, brass=True):
    """32 by 32, with 8 pixel margins. Its middle tiles."""
    size = 32
    image = Image.new("RGBA", (size, size), fill)
    px = image.load()
    for y in range(size):
        for x in range(size):
            if x % 8 == 0 and y % 8 == 0 or x % 8 == 4 and y % 8 == 4:
                px[x, y] = speck
    for i in range(size):
        for depth, color in ((1, frame_light), (2, frame), (3, frame), (4, frame_dark),
                             (5, shade(fill, 0.72))):
            px[i, depth] = color
            px[depth, i] = color
    for i in range(size):
        for depth, color in ((1, frame_dark), (2, frame), (3, frame), (4, frame_dark)):
            px[i, size - 1 - depth] = color
            px[size - 1 - depth, i] = color
    cut_corners(image, 2)
    ink_edge(image)
    if brass:
        for cx, cy, sx, sy in ((1, 1, 1, 1), (size - 2, 1, -1, 1), (1, size - 2, 1, -1),
                               (size - 2, size - 2, -1, -1)):
            for i in range(1, 7):
                for j in range(2):
                    px[cx + i * sx, cy + j * sy] = GOLD_LIGHT if j == 0 else GOLD
                    px[cx + j * sx, cy + i * sy] = GOLD_LIGHT if j == 0 else GOLD
            px[cx + sx * 3, cy + sy * 3] = GOLD_DARK
    return image


def button(top, middle, bottom, lip):
    """32 by 24, with 8 pixel margins. Only the flat middle is ever repeated."""
    w, h = 32, 24
    image = Image.new("RGBA", (w, h), middle)
    px = image.load()
    for y in range(h):
        for x in range(w):
            if y <= 2:
                color = shade(top, 1.18)
            elif y < 8:
                color = top
            elif y < 16:
                color = middle
            elif y < 20:
                color = bottom
            else:
                color = lip
            px[x, y] = color
    # A row of checks softens each step of the gradient.
    for x in range(0, w, 2):
        px[x, 7] = middle
        px[x, 16] = middle
        px[x, 19] = lip
    for y in range(3, 20):
        px[2, y] = shade(px[2, y], 1.12)
        px[w - 3, y] = shade(px[w - 3, y], 0.88)
    cut_corners(image, 3)
    return ink_edge(image)


def focus_ring():
    """16 by 16 with 6 pixel margins. Clear in the middle."""
    image = cut_corners(Image.new("RGBA", (16, 16), INK), 3)
    image.alpha_composite(cut_corners(Image.new("RGBA", (14, 14), hexc("#fff6d2")), 3), (1, 1))
    hole = cut_corners(Image.new("RGBA", (12, 12), (0, 0, 0, 255)), 3).load()
    px = image.load()
    for y in range(12):
        for x in range(12):
            if hole[x, y][3]:
                px[x + 2, y + 2] = (0, 0, 0, 0)
    return image


def bar_trough():
    """16 by 12 with 4 pixel margins."""
    image = Image.new("RGBA", (16, 12), hexc("#1b1626"))
    px = image.load()
    for x in range(16):
        px[x, 1] = hexc("#0f0c17")
        px[x, 10] = WOOD
    cut_corners(image, 1)
    return ink_edge(image)


def chip():
    """24 by 16 with 7 pixel margins."""
    image = Image.new("RGBA", (24, 16), hexc("#2c1e22"))
    px = image.load()
    for x in range(24):
        px[x, 1] = WOOD_LIGHT
        px[x, 2] = WOOD
        px[x, 13] = WOOD
        px[x, 14] = WOOD_DARK
    for y in range(2, 14):
        px[1, y] = WOOD
        px[22, y] = WOOD_DARK
    cut_corners(image, 2)
    return ink_edge(image)


def arrow():
    """The next-step arrow, pointing down."""
    rows = ["....gggggggg....", "....gyyyyoog....", "....gyyyyoog....", "....gyyyyoog....",
            "....gyyyyoog....", "....gyyyyoog....", ".gggggyyoogggg..", "..gyyyyyyoooog..",
            "...gyyyyyooog...", "....gyyyyoog....", ".....gyyyog.....", "......gyog......",
            ".......gg.......", "................", "................", "................"]
    colors = {"g": GOLD, "y": hexc("#ffe680"), "o": hexc("#f0a830")}
    image = Image.new("RGBA", (ITEM_CELL, ITEM_CELL), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key in colors:
                image.putpixel((x, y), colors[key])
    return with_outline(image)


# --- Icons ------------------------------------------------------------------

def ki_play():
    image, draw = icon_canvas()
    draw.polygon([(4, 2), (4, 13), (13, 8), (13, 7)], fill=hexc("#4a2b12"))
    draw.polygon([(5, 5), (5, 10), (9, 8), (9, 7)], fill=hexc("#7a4a20"))
    return image


def ki_back():
    image, draw = icon_canvas()
    cream, edge = hexc("#fff0c8"), hexc("#c9a66b")
    draw.polygon([(1, 7), (6, 2), (7, 2), (7, 5), (14, 5), (14, 10), (7, 10), (7, 13), (6, 13),
                  (1, 8)], fill=cream)
    draw.line((3, 9, 6, 12), fill=edge)
    draw.line((7, 10, 14, 10), fill=edge)
    return with_outline(image)


def ki_book():
    image, draw = icon_canvas()
    cover, dark, page = hexc("#4c8fe6"), hexc("#235fb0"), hexc("#fff4d6")
    draw.rectangle((2, 2, 13, 13), fill=cover)
    draw.rectangle((2, 2, 3, 13), fill=dark)
    draw.rectangle((4, 12, 13, 13), fill=page)
    draw.rectangle((6, 4, 11, 8), fill=hexc("#f2c23e"))
    draw.rectangle((7, 5, 10, 7), fill=dark)
    return with_outline(image)


def ki_gear():
    image, _ = icon_canvas()
    px = image.load()
    steel, dark, light = hexc("#c6cbd9"), hexc("#7c8298"), hexc("#f0f3fa")
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            r, a = math.hypot(dx, dy), math.atan2(dy, dx)
            if 2.3 < r <= (6.9 if math.cos(a * 8) > 0.2 else 5.2):
                px[x, y] = light if dx + dy < -4 else dark if dx + dy > 3 else steel
    return with_outline(image)


def ki_door():
    image, draw = icon_canvas()
    draw.rectangle((3, 3, 12, 14), fill=hexc("#a9a4a8"))
    draw.rectangle((4, 2, 11, 2), fill=hexc("#a9a4a8"))
    draw.rectangle((5, 4, 10, 14), fill=hexc("#a8682f"))
    draw.line((7, 4, 7, 14), fill=hexc("#6e3f21"))
    draw.point((9, 9), fill=hexc("#f2c23e"))
    return with_outline(image)


def ki_coin():
    image, draw = icon_canvas()
    draw.ellipse((2, 2, 13, 13), fill=hexc("#f2c23e"))
    draw.ellipse((4, 4, 11, 11), fill=hexc("#ffd968"))
    draw.arc((2, 2, 13, 13), 20, 110, fill=hexc("#c67c22"))
    draw.arc((2, 2, 13, 13), 200, 290, fill=hexc("#fff0a0"))
    draw.rectangle((7, 5, 8, 10), fill=hexc("#c67c22"))
    return with_outline(image)


def ki_food():
    image, draw = icon_canvas()
    crust, light, dark = hexc("#c98a3f"), hexc("#efc06e"), hexc("#8a5526")
    draw.ellipse((1, 4, 14, 12), fill=crust)
    draw.rectangle((2, 10, 13, 12), fill=dark)
    draw.ellipse((3, 5, 11, 9), fill=light)
    for x in (5, 8, 11):
        draw.line((x, 5, x - 1, 8), fill=dark)
    return with_outline(image)


def ki_heart():
    rows = ["..rrr...rrr..", ".rwwrr.rrrrr.", "rwwrrrrrrrRRr", "rwrrrrrrrrrRr", "rrrrrrrrrrRRr",
            ".rrrrrrrrRRr.", "..rrrrrrRRr..", "...rrrrRRr...", "....rrRRr....", ".....rRr.....",
            "......r......"]
    image, _ = icon_canvas()
    colors = {"r": hexc("#e23d3d"), "R": hexc("#8e1f2d"), "w": hexc("#ff9d9d")}
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key in colors:
                image.putpixel((x + 1, y + 3), colors[key])
    return with_outline(image)


def ki_boot():
    image, draw = icon_canvas()
    leather, dark = hexc("#a8682f"), hexc("#6e3f21")
    draw.rectangle((4, 2, 9, 10), fill=leather)
    draw.rectangle((4, 9, 13, 11), fill=leather)
    draw.rectangle((3, 12, 13, 13), fill=dark)
    draw.rectangle((4, 2, 9, 3), fill=hexc("#d7a36a"))
    return with_outline(image)


def ki_wood():
    image, draw = icon_canvas()
    bark, dark, cut = hexc("#a8682f"), hexc("#6e3f21"), hexc("#ecc98a")
    for y, x in ((3, 3), (8, 0), (8, 6)):
        draw.rectangle((x, y, x + 6, y + 4), fill=bark)
        draw.line((x, y + 4, x + 6, y + 4), fill=dark)
        draw.ellipse((x + 5, y, x + 8, y + 4), fill=cut)
        draw.point((x + 6, y + 2), fill=dark)
    return with_outline(image)


def ki_ore():
    image, draw = icon_canvas()
    rock, dark, gem = hexc("#8f94a8"), hexc("#5a5f75"), hexc("#7fe3f0")
    draw.polygon([(2, 12), (3, 7), (6, 3), (10, 3), (13, 7), (14, 12)], fill=rock)
    draw.polygon([(7, 12), (10, 6), (14, 12)], fill=dark)
    draw.rectangle((5, 6, 6, 7), fill=gem)
    draw.rectangle((8, 9, 9, 10), fill=gem)
    draw.point((11, 5), fill=gem)
    return with_outline(image)


def ki_die():
    image, draw = icon_canvas()
    edge = hexc("#c9a66b")
    draw.rectangle((2, 2, 13, 13), fill=hexc("#fff4d6"))
    draw.line((2, 13, 13, 13), fill=edge)
    draw.line((13, 2, 13, 13), fill=edge)
    for x, y in ((4, 4), (7, 7), (10, 10), (10, 4), (4, 10)):
        draw.rectangle((x, y, x + 1, y + 1), fill=hexc("#8e1f2d"))
    return with_outline(image)


def ki_bag():
    image, draw = icon_canvas()
    cloth, dark = hexc("#c9a06a"), hexc("#8a6237")
    draw.rectangle((6, 2, 9, 4), fill=cloth)
    draw.ellipse((2, 4, 13, 14), fill=cloth)
    draw.line((5, 5, 10, 5), fill=hexc("#d8423f"))
    draw.arc((2, 4, 13, 14), 0, 130, fill=dark)
    return with_outline(image)


def ki_lock():
    image, draw = icon_canvas()
    draw.arc((4, 1, 11, 9), 180, 360, fill=hexc("#c6cbd9"))
    draw.line((4, 5, 4, 7), fill=hexc("#c6cbd9"))
    draw.line((11, 5, 11, 7), fill=hexc("#7c8298"))
    draw.rectangle((3, 7, 12, 14), fill=hexc("#f2c23e"))
    draw.line((3, 14, 12, 14), fill=hexc("#c67c22"))
    draw.rectangle((7, 9, 8, 12), fill=INK)
    return with_outline(image)


def ki_check():
    image, draw = icon_canvas()
    draw.line((2, 8, 6, 12), fill=hexc("#57c05f"), width=3)
    draw.line((6, 12, 13, 3), fill=hexc("#8bea8f"), width=3)
    return with_outline(image)


def ki_star():
    image, draw = icon_canvas()
    points = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        radius = 7.0 if i % 2 == 0 else 3.0
        points.append((7.5 + radius * math.cos(angle), 7.5 + radius * math.sin(angle)))
    draw.polygon(points, fill=hexc("#f2c23e"))
    draw.polygon([(7, 3), (8, 3), (8, 8), (5, 8)], fill=hexc("#fff0a0"))
    return with_outline(image)


def ki_music():
    image, draw = icon_canvas()
    note = hexc("#ff8ad0")
    draw.rectangle((5, 3, 6, 11), fill=note)
    draw.rectangle((11, 2, 12, 10), fill=note)
    draw.rectangle((5, 2, 12, 4), fill=note)
    draw.ellipse((2, 10, 6, 13), fill=note)
    draw.ellipse((8, 9, 12, 12), fill=note)
    return with_outline(image)


def ki_sound():
    image, draw = icon_canvas()
    cream, wave = hexc("#fff0c8"), hexc("#4aa3f0")
    draw.rectangle((1, 6, 4, 9), fill=cream)
    draw.polygon([(4, 6), (8, 2), (8, 13), (4, 9)], fill=cream)
    draw.line((10, 6, 10, 9), fill=wave)
    draw.line((12, 4, 12, 11), fill=wave)
    draw.line((14, 3, 14, 12), fill=wave)
    return with_outline(image)


def ki_cross():
    image, draw = icon_canvas()
    draw.line((3, 3, 12, 12), fill=hexc("#e23d3d"), width=3)
    draw.line((3, 12, 12, 3), fill=hexc("#ff7a6e"), width=3)
    return with_outline(image)


def ki_spring():
    """A pink blossom."""
    image, draw = icon_canvas()
    for x, y in ((6, 1), (2, 5), (10, 5), (3, 10), (9, 10)):
        draw.ellipse((x, y, x + 5, y + 5), fill=hexc("#f39ac0"))
    draw.point([(7, 3), (4, 7), (12, 7), (5, 12), (11, 12)], fill=hexc("#ffd6e6"))
    draw.ellipse((6, 6, 10, 10), fill=hexc("#f2c23e"))
    return with_outline(image)


def ki_summer():
    """A round sun."""
    image, draw = icon_canvas()
    for a, b, c, d in ((7, 0, 8, 2), (7, 13, 8, 15), (0, 7, 2, 8), (13, 7, 15, 8)):
        draw.rectangle((a, b, c, d), fill=hexc("#f7a838"))
    for x, y in ((2, 2), (12, 2), (2, 12), (12, 12)):
        draw.rectangle((x, y, x + 1, y + 1), fill=hexc("#f7a838"))
    draw.ellipse((3, 3, 12, 12), fill=hexc("#f7c23c"))
    draw.ellipse((5, 4, 9, 8), fill=hexc("#fff0a0"))
    return with_outline(image)


def ki_autumn():
    """A red-gold fallen leaf."""
    image, draw = icon_canvas()
    draw.polygon([(7, 1), (10, 3), (13, 3), (12, 7), (14, 9), (10, 10), (8, 13), (5, 10),
                  (2, 9), (4, 7), (3, 3), (5, 3)], fill=hexc("#d8602c"))
    draw.polygon([(7, 3), (10, 5), (10, 8), (7, 10)], fill=hexc("#f0a03c"))
    draw.line((8, 3, 8, 15), fill=hexc("#7a3a1e"))
    return with_outline(image)


def ki_winter():
    """A white snowflake."""
    image, draw = icon_canvas()
    white, blue = hexc("#f4f8ff"), hexc("#a9d0f0")
    draw.line((7, 1, 7, 14), fill=white)
    draw.line((1, 7, 14, 7), fill=white)
    draw.line((3, 3, 12, 12), fill=blue)
    draw.line((12, 3, 3, 12), fill=blue)
    for x, y in ((5, 2), (9, 2), (5, 13), (9, 13), (2, 5), (2, 9), (13, 5), (13, 9)):
        draw.point((x, y), fill=white)
    return with_outline(image)


def ki_shield():
    rows = ["..hhhhhhhhh..", ".hllllsdddddh", ".hllllsdddddh", ".hllllsdddddh", ".hllllsdddddh",
            ".hllllsdddddh", "..hlllsdddh..", "..hlllsdddh..", "...hllsdh....", "....hlsdh....",
            ".....hsh.....", "......h......"]
    image, _ = icon_canvas()
    colors = {"h": hexc("#f2c23e"), "l": hexc("#8fb4e8"), "s": hexc("#d7dce8"), "d": hexc("#4f74b8")}
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key in colors:
                image.putpixel((x + 1, y + 2), colors[key])
    return with_outline(image)


def ki_magic():
    rows = [".......w.....", "......wlw....", ".....wlmlw...", "....wlmmdlw..", "...wlmmmddlw.",
            "...lmmmmddd..", "....lmmddd...", ".....lmdd....", "......ld.....", "...y.....y...",
            "..yWy...yWy..", "...y.....y..."]
    image, _ = icon_canvas()
    colors = {"w": hexc("#ffffff"), "l": hexc("#bcdcff"), "m": hexc("#4da3f2"), "d": hexc("#2a5fc4"),
              "y": hexc("#f2c23e"), "W": hexc("#fff3b0")}
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key in colors:
                image.putpixel((x + 1, y + 2), colors[key])
    return with_outline(image)


def ki_moon():
    image, draw = icon_canvas()
    draw.ellipse((2, 2, 13, 13), fill=hexc("#f2c23e"))
    draw.ellipse((5, 1, 15, 11), fill=(0, 0, 0, 0))
    draw.point([(4, 6), (5, 10), (8, 12)], fill=hexc("#fff0a0"))
    return with_outline(image)


def make_kit():
    KIT.mkdir(exist_ok=True)
    x2(panel(hexc("#232447"), hexc("#2a2b54"), WOOD, WOOD_LIGHT, WOOD_DARK)).save(KIT / "panel.png")
    x2(panel(PAPER, hexc("#ecd9aa"), PAPER_DARK, hexc("#fbf0d0"), hexc("#b08f5c"), False)).save(KIT / "paper.png")
    looks = {
        "primary": ("#ffd257", "#f6b63a", "#dc8f25", "#a85f1b"),
        "primary_hot": ("#ffe88a", "#ffcc55", "#efa331", "#b96d20"),
        "primary_down": ("#d98d27", "#d98d27", "#c97f22", "#c97f22"),
        "wood": ("#a9743f", "#8c5a33", "#74482b", "#4f3024"),
        "wood_hot": ("#c98f53", "#a9743f", "#8c5a33", "#5f3a29"),
        "wood_down": ("#603a29", "#603a29", "#573426", "#573426"),
        "stone": ("#7d7a86", "#6a6773", "#5b5864", "#44424c"),
    }
    for name, colors in looks.items():
        x2(button(*[hexc(color) for color in colors])).save(KIT / f"button_{name}.png")
    x2(cut_corners(Image.new("RGBA", (32, 24), hexc("#1a1120", 150)), 3)).save(KIT / "button_shadow.png")
    x2(focus_ring()).save(KIT / "focus.png")
    x2(bar_trough()).save(KIT / "bar.png")
    x2(chip()).save(KIT / "chip.png")
    x2(arrow()).save(KIT / "arrow.png")

    makers = {"play": ki_play, "back": ki_back, "book": ki_book, "gear": ki_gear, "door": ki_door,
              "coin": ki_coin, "food": ki_food, "heart": ki_heart, "boot": ki_boot, "wood": ki_wood,
              "ore": ki_ore, "herb": icon_herb, "die": ki_die, "bag": ki_bag, "lock": ki_lock,
              "check": ki_check, "cross": ki_cross, "star": ki_star, "music": ki_music, "sound": ki_sound,
              "spring": ki_spring, "summer": ki_summer, "autumn": ki_autumn, "winter": ki_winter,
              "moon": ki_moon, "shield": ki_shield, "magic": ki_magic,
              "sword": lambda: icon_blade(10, 2, hexc("#d7dce8"), hexc("#f2c23e"), hexc("#a8682f"))}
    sheet = Image.new("RGBA", (ITEM_CELL * len(ICON_NAMES), ITEM_CELL), (0, 0, 0, 0))
    for index, name in enumerate(ICON_NAMES):
        sheet.alpha_composite(makers[name](), (index * ITEM_CELL, 0))
    x2(sheet).save(KIT / "icons.png")


# --- Main menu scene --------------------------------------------------------
# Art pixels: 800 by 450, so any window shape up to 1600 by 900 stays covered. The
# part a 1280 by 720 window shows starts at (MENU_X, MENU_Y).

MENU_W, MENU_H = 800, 450
MENU_X, MENU_Y = 80, 45
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def ramp_color(colors, t, x, y):
    """A colour from a list of bands, with a checkered edge between bands."""
    position = t * (len(colors) - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.9
    return colors[max(0, min(len(colors) - 1, int(round(position))))]


def waves(x, seed, parts):
    return sum(math.sin(x * f + seed * (i + 1)) * a for i, (f, a) in enumerate(parts))


def fill_below(image, top_of, ramp, depth, rim=None):
    """Fills everything below the curve top_of(x), banded by depth."""
    px = image.load()
    for x in range(MENU_W):
        top = int(top_of(x))
        for y in range(max(0, top), MENU_H):
            px[x, y] = ramp_color(ramp, min(1.0, (y - top) / depth), x, y)
        if rim is not None and 0 <= top < MENU_H:
            px[x, top] = rim


def menu_sky():
    image = Image.new("RGBA", (MENU_W, MENU_H))
    px = image.load()
    stops = ["#2f6fc4", "#3f8fd8", "#5cabe2", "#83c6e8", "#b2dbe2", "#e6e3bd", "#fbd893", "#fdbd76"]
    bands = [lerp_color(hexc(stops[i]), hexc(stops[i + 1]), j / 3)
             for i in range(len(stops) - 1) for j in range(3)]
    sun_x, sun_y = MENU_X + 400, MENU_Y + 62
    for y in range(MENU_H):
        t = min(1.0, y / (MENU_Y + 250))
        for x in range(MENU_W):
            color = ramp_color(bands, t, x, y)
            distance = math.hypot(x - sun_x, y - sun_y)
            jitter = BAYER[y % 4][x % 4] * 2.2
            if distance + jitter < 90:
                color = lerp_color(color, hexc("#fff0b8"), 0.16)
            if distance + jitter < 58:
                color = lerp_color(color, hexc("#fff4c4"), 0.26)
            if distance < 24:
                color = hexc("#fffbe0")
            elif distance < 26:
                color = hexc("#ffeeb0")
            px[x, y] = color
    return image


def menu_mountains():
    image = Image.new("RGBA", (MENU_W, MENU_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    base = MENU_Y + 300
    light, dark, snow, snow_dark = hexc("#a7c3e0"), hexc("#86a7cf"), hexc("#f5f6f2"), hexc("#c5d6ea")
    for cx, top, half in ((80, 205, 120), (190, 165, 130), (300, 200, 110), (390, 150, 140),
                          (510, 190, 120), (600, 165, 120), (700, 140, 150), (790, 190, 120)):
        top += MENU_Y - 50
        draw.polygon([(cx - half, base), (cx, top), (cx + half, base)], fill=dark)
        draw.polygon([(cx, top), (cx + half, base), (cx + 8, base)], fill=light)
        drop = 26
        reach = drop * half // (base - top)
        left, right = cx - reach, cx + reach
        y = top + drop
        draw.polygon([(left, y), (cx, top), (right, y), (cx + 8, y - 7), (cx + 3, y + 5), (cx - 3, y - 5),
                      (cx - 9, y + 4)], fill=snow_dark)
        draw.polygon([(cx, top), (right, y), (cx + 8, y - 7), (cx + 3, y + 5)], fill=snow)
    return image


def tree(image, cx, base, radius, light, middle, dark, trunk=True):
    """A round tree, or a bush with trunk=False, lit from the upper right."""
    if trunk:
        ImageDraw.Draw(image).rectangle((cx - 1, base - radius, cx + 1, base), fill=hexc("#5b3a2a"))
    cy = base - radius * 2 if trunk else base - radius
    px = image.load()
    for ox, oy, size in ((0, 0, 1.0), (-0.7, 0.3, 0.7), (0.7, 0.3, 0.7), (-0.3, -0.5, 0.65), (0.4, -0.45, 0.6)):
        lx, ly, r = cx + ox * radius, cy + oy * radius, radius * size
        for y in range(int(ly - r), int(ly + r) + 1):
            for x in range(int(lx - r), int(lx + r) + 1):
                if 0 <= x < MENU_W and 0 <= y < MENU_H and math.hypot(x - lx, y - ly) <= r:
                    glow = ((x - lx) * 0.6 - (y - ly)) / r + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.5
                    px[x, y] = light if glow > 0.55 else middle if glow > -0.25 else dark


def tower(draw, cx, base, width, height, roof, roof_dark):
    half = width // 2
    top = base - height
    draw.rectangle((cx - half, top, cx + half, base), fill=hexc("#b5a68f"))
    draw.rectangle((cx - half + width // 3, top, cx + half, base), fill=hexc("#e8dcc0"))
    draw.line((cx - half - 1, top, cx + half + 1, top), fill=hexc("#8c7c6c"))
    tall = width + 7
    draw.polygon([(cx - half - 2, top - 1), (cx, top - tall), (cx, top - 1)], fill=roof_dark)
    draw.polygon([(cx, top - tall), (cx + half + 2, top - 1), (cx, top - 1)], fill=roof)
    draw.rectangle((cx - 1, top + 6, cx, top + 9), fill=hexc("#3b3550"))


def town_wall(draw, left, right, base, height):
    light, dark = hexc("#d9ccb0"), hexc("#a69781")
    draw.rectangle((left, base - height, right, base), fill=light)
    draw.line((left, base - 1, right, base - 1), fill=dark)
    for x in range(left, right + 1, 6):
        draw.rectangle((x, base - height - 3, x + 2, base - height), fill=light)
    for x in range(left + 4, right, 9):
        draw.point((x, base - height + 4 + x % 3), fill=dark)


def house(draw, cx, base, width, height, roof, roof_dark):
    half = width // 2
    top = base - height
    draw.rectangle((cx - half, top, cx + half, base), fill=hexc("#f3e6c8"))
    draw.rectangle((cx - half, top, cx - half + 1, base), fill=hexc("#c9b693"))
    draw.polygon([(cx - half - 2, top), (cx, top - half - 2), (cx, top)], fill=roof_dark)
    draw.polygon([(cx, top - half - 2), (cx + half + 2, top), (cx, top)], fill=roof)
    draw.rectangle((cx - 1, base - 4, cx + 1, base), fill=hexc("#6e3f21"))
    draw.point((cx + half - 2, top + 3), fill=hexc("#ffd968"))


def menu_town_hill():
    image = Image.new("RGBA", (MENU_W, MENU_H), (0, 0, 0, 0))

    def line(x):
        return (MENU_Y + 262 + waves(x, 2.0, [(0.009, 22), (0.021, 7)])
                - 34 * math.exp(-((x - MENU_X - 470) / 130) ** 2))

    # A far line of trees sits behind the hill's crest.
    for x in range(0, MENU_W, 9):
        tree(image, x, int(line(x)) + 3, 7 + (x * 7) % 5, hexc("#9cc884"), hexc("#7fb57a"), hexc("#68a173"), False)
    draw = ImageDraw.Draw(image)
    hx = MENU_X + 470
    ground = int(line(hx)) + 6
    red, red_dark = hexc("#e2573f"), hexc("#a93a35")
    blue, blue_dark = hexc("#4c8fe6"), hexc("#2e62b0")
    orange, orange_dark = hexc("#ef9a3f"), hexc("#bb6a2a")
    tower(draw, hx - 6, ground - 8, 20, 66, blue, blue_dark)
    tower(draw, hx + 18, ground - 8, 12, 80, red, red_dark)
    tower(draw, hx - 26, ground - 8, 10, 52, red, red_dark)
    town_wall(draw, hx - 66, hx + 66, ground, 20)
    tower(draw, hx - 68, ground, 14, 34, red, red_dark)
    tower(draw, hx + 68, ground, 14, 34, red, red_dark)
    draw.rectangle((hx - 6, ground - 13, hx + 6, ground), fill=hexc("#4a3226"))
    draw.polygon([(hx - 6, ground - 13), (hx, ground - 18), (hx + 6, ground - 13)], fill=hexc("#4a3226"))
    fill_below(image, line, [hexc(c) for c in ("#a6d07a", "#86c06a", "#6db064", "#5ca35f")], 90, hexc("#cfe89a"))
    draw = ImageDraw.Draw(image)
    for cx, sink, width, height, is_red in ((hx - 100, 4, 12, 7, False), (hx - 84, 8, 14, 8, True),
                                            (hx + 92, 7, 14, 8, False), (hx + 110, 3, 12, 7, True),
                                            (hx - 42, 8, 12, 7, False), (hx + 44, 8, 12, 7, True)):
        roof = (red, red_dark) if is_red else (orange, orange_dark)
        house(draw, cx, int(line(cx)) + sink, width, height, *roof)
    for x, sink, radius in ((MENU_X + 225, 12, 7), (MENU_X + 247, 20, 9), (MENU_X + 270, 14, 6),
                            (MENU_X + 180, 16, 8), (MENU_X + 205, 24, 6)):
        tree(image, x, int(line(x)) + sink, radius, hexc("#8ccf6f"), hexc("#5cab62"), hexc("#3f8c5c"))
    return image


PORTAL_X = 390
ROAD_END_X = 440
DAIS_RISE = 14


def menu_road_y(x):
    """Where the road on the near hill runs, in art pixels. MenuScenery.gd walks a
    character along this same curve."""
    return MENU_Y + 322 + 16 * math.sin((x - MENU_X) * 0.0105 - 0.5)


def ellipse_tier(image, cx, cy, rx, ry, depth, top, side):
    """A round stone step: its side, then its paved top, then an ink edge."""
    px = image.load()
    for y in range(cy - ry - 1, cy + ry + depth + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            on_top = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0
            below = ((x - cx) / rx) ** 2 + ((y - cy - depth) / ry) ** 2 <= 1.0
            wall = abs(x - cx) <= rx and cy <= y <= cy + depth
            if on_top:
                row = (y - cy + ry) // 5
                seam = (y - cy + ry) % 5 == 0 or (x + row * 6) % 13 == 0
                tile = ((x + row * 6) // 13 * 7 + row * 3) % 3
                px[x, y] = shade(top, 0.8) if seam else shade(top, (1.0, 0.95, 1.05)[tile])
            elif below or wall:
                px[x, y] = shade(side, 0.82) if (x // 9) % 2 else side
    source = image.copy().load()
    for y in range(cy - ry - 1, cy + ry + depth + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            inside = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 or \
                ((x - cx) / rx) ** 2 + ((y - cy - depth) / ry) ** 2 <= 1.0 or \
                abs(x - cx) <= rx and cy <= y <= cy + depth
            if inside and (((x - cx - 1) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1.0 and
                           ((x - cx + 1) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1.0 and y < cy):
                px[x, y] = shade(source[x, y], 0.7)


def standing_stone(image, x, base):
    """A carved stone with a glowing crystal, one on each side of the Portal."""
    draw = ImageDraw.Draw(image)
    draw.polygon([(x - 4, base), (x - 3, base - 25), (x, base - 29), (x + 3, base - 25), (x + 4, base)],
                 fill=hexc("#b9b4c0"))
    draw.polygon([(x, base - 29), (x + 3, base - 25), (x + 4, base), (x, base)], fill=hexc("#8d8798"))
    draw.rectangle((x - 1, base - 22, x + 1, base - 17), fill=hexc("#7fe9f2"))
    draw.point((x, base - 20), fill=hexc("#ffffff"))
    for y in (base - 12, base - 7):
        draw.line((x - 2, y, x + 2, y), fill=hexc("#6d6778"))
    px = image.load()
    source = image.copy().load()
    for yy in range(base - 31, base + 1):
        for xx in range(x - 6, x + 7):
            if source[xx, yy][:3] not in ((185, 180, 192), (141, 135, 152), (127, 233, 242),
                                          (255, 255, 255), (109, 103, 120)):
                for ox, oy in ((1, 0), (-1, 0), (0, -1)):
                    if source[xx + ox, yy + oy][:3] in ((185, 180, 192), (141, 135, 152)):
                        px[xx, yy] = INK
                        break


def portal_site(image):
    """The paved clearing where the road ends: two round steps, and stairs up the
    middle to the Portal, which MenuScenery.gd stands on the top step."""
    cy = int(menu_road_y(PORTAL_X))
    pave, wall = hexc("#d8cfbc"), hexc("#8f8778")
    px = image.load()
    # A soft shadow on the grass.
    for y in range(cy - 10, cy + 30):
        for x in range(PORTAL_X - 92, PORTAL_X + 93):
            d = ((x - PORTAL_X) / 90) ** 2 + ((y - cy - 8) / 22) ** 2
            if d <= 1.0 and (x + y) % 2 == 0:
                px[x, y] = shade(px[x, y], 0.82)
    ellipse_tier(image, PORTAL_X, cy + 1, 84, 19, 3, pave, wall)
    # The road joins the paving instead of stopping at it.
    for x in range(PORTAL_X + 70, ROAD_END_X + 16):
        middle = int(menu_road_y(x))
        for y in range(middle - 3, middle + 8):
            px[x, y] = hexc("#ecd19a") if y < middle + 3 else hexc("#dcbc80")
    ellipse_tier(image, PORTAL_X, cy - DAIS_RISE + 2, 56, 12, 6, hexc("#e6dfce"), wall)
    # The stairs, wider toward the bottom.
    draw = ImageDraw.Draw(image)
    top = cy - DAIS_RISE + 10
    for step in range(4):
        half = 13 + step
        y = top + step * 3
        draw.rectangle((PORTAL_X - half, y, PORTAL_X + half, y + 1), fill=hexc("#efe8d8"))
        draw.rectangle((PORTAL_X - half, y + 2, PORTAL_X + half, y + 2), fill=hexc("#a39a89"))
        px[PORTAL_X - half - 1, y + 1] = INK
        px[PORTAL_X + half + 1, y + 1] = INK
    # Light from the Portal spills over the top step.
    for y in range(cy - DAIS_RISE - 7, cy - DAIS_RISE + 12):
        for x in range(PORTAL_X - 34, PORTAL_X + 35):
            d = ((x - PORTAL_X) / 34) ** 2 + ((y - cy + DAIS_RISE - 3) / 9) ** 2
            if d <= 1.0 and BAYER[y % 4][x % 4] < (1.0 - d) * 14:
                px[x, y] = lerp_color(px[x, y], hexc("#8ff2f5"), 0.5)
    standing_stone(image, PORTAL_X - 46, cy - DAIS_RISE + 3)
    standing_stone(image, PORTAL_X + 46, cy - DAIS_RISE + 3)


def menu_near_hill():
    image = Image.new("RGBA", (MENU_W, MENU_H), (0, 0, 0, 0))

    def line(x):
        return MENU_Y + 286 + waves(x, 4.0, [(0.0075, 16), (0.018, 5)])

    ramp = [hexc(c) for c in ("#9be05f", "#7ccf55", "#5fbb4e", "#4aa449", "#3c8d46", "#317a44")]
    fill_below(image, line, ramp, 170, hexc("#d4f58a"))
    px = image.load()
    for x in range(ROAD_END_X, MENU_W):
        middle = int(menu_road_y(x))
        for y in range(middle - 4, middle + 9):
            edge = y <= middle - 3 or y >= middle + 7
            color = hexc("#b98e55") if edge else hexc("#ecd19a") if y < middle + 3 else hexc("#dcbc80")
            if not edge and BAYER[y % 4][x % 4] == 3 and (x // 4) % 3 == 0:
                color = hexc("#c9a66b")
            px[x, y] = color
        px[x, middle + 9] = hexc("#3f9147")
    # Tufts and flowers, placed by a fixed pattern.
    draw = ImageDraw.Draw(image)
    for i in range(240):
        x = (i * 137) % MENU_W
        y = int(line(x)) + 8 + (i * 61) % 150
        if abs(y - menu_road_y(x) - 2) < 13 or y >= MENU_H - 2:
            continue
        if i % 5 == 0:
            draw.point((x, y), fill=[hexc("#fff4d6"), hexc("#ffd957"), hexc("#ff8ad0")][i % 3])
            draw.point((x, y + 1), fill=hexc("#2f7a3f"))
        else:
            color = hexc("#a8ea6b") if i % 2 else hexc("#317a44")
            draw.line((x, y, x, y + 2), fill=color)
            draw.point((x + 1, y + 1), fill=color)
    portal_site(image)
    return image


def menu_front():
    """Bushes that frame the bottom of the picture, in front of everything."""
    image = Image.new("RGBA", (MENU_W, MENU_H), (0, 0, 0, 0))
    light, middle, dark = hexc("#4fae55"), hexc("#2f8a4d"), hexc("#206a48")
    for x, radius in ((750, 62), (690, 40), (640, 26), (250, 24), (120, 32), (70, 44), (190, 20),
                      (560, 16), (810, 50)):
        tree(image, x, MENU_Y + 372 + radius // 3, radius, light, middle, dark, False)
    return image


def menu_cloud(seed, width):
    image = Image.new("RGBA", (width, 34), (0, 0, 0, 0))
    px = image.load()
    lumps = [(width * (0.16 + 0.17 * i), 20 - (seed * (i + 2)) % 7, 7 + (seed * (i + 3)) % 8) for i in range(5)]
    for y in range(28):
        for x in range(width):
            for lx, ly, r in lumps:
                if math.hypot(x - lx, (y - ly) * 1.2) <= r:
                    under = (y - ly) / r + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.4
                    px[x, y] = hexc("#ffffff") if under < 0.05 else hexc("#ffe8cf") if under < 0.5 else hexc("#f7c6b0")
                    break
    return image


def menu_portal():
    """Eight frames of a stone ring with a swirl inside, 56 by 80 art pixels each."""
    w, h, frames = 56, 80, 8
    sheet = Image.new("RGBA", (w * frames, h), (0, 0, 0, 0))
    cx, cy, rx, ry = 27.5, 39.5, 19.0, 28.0
    stone, stone_dark, stone_light = hexc("#b9b4c0"), hexc("#7c7688"), hexc("#e4dfe6")
    swirl = [hexc(c) for c in ("#2d1b7e", "#3f2cc2", "#3c6fe8", "#4cc6f0", "#a6f4f0", "#ffffff")]
    px = sheet.load()
    draw = ImageDraw.Draw(sheet)
    for frame in range(frames):
        phase = frame / frames * math.tau
        for y in range(70):
            for x in range(w):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                r, a = math.hypot(dx, dy), math.atan2(dy, dx)
                sx = x + frame * w
                if r < 1.0:
                    value = 0.5 + 0.5 * math.sin(a * 3 + r * 9 - phase)
                    value = value * 0.75 + (1 - r) * 0.45 + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.18
                    px[sx, y] = swirl[max(0, min(5, int(value * 6)))]
                elif r < 1.3:
                    turn = (a + math.pi) / math.tau * 16
                    block = int(turn)
                    seam = turn - block < 0.08
                    lit = dx - dy * 0.4 > 0
                    color = stone_dark if seam or not lit else stone_light if r < 1.1 else stone
                    # Runes on every other block, pulsing round the ring.
                    if block % 2 == 0 and 1.1 < r < 1.2 and not seam:
                        color = hexc("#a6f4f0") if math.sin(block * 0.8 - phase) > 0 else hexc("#4cc6f0")
                    px[sx, y] = color
        left = frame * w
        draw.rectangle((left + 13, 70, left + 42, 74), fill=stone)
        draw.rectangle((left + 10, 75, left + 45, 78), fill=stone_dark)
        draw.line((left + 13, 70, left + 42, 70), fill=stone_light)
    return outline_outside(sheet)


LOGO_BLOCK = 5
LOGO_LETTERS = {
    "A": [".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
    "C": [".####.", "##..##", "##....", "##....", "##....", "##..##", ".####."],
    "D": ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "#####."],
    "N": ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##"],
    "O": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "R": ["#####.", "##..##", "##..##", "#####.", "##.##.", "##..##", "##..##"],
    "W": ["##...##", "##...##", "##...##", "##.#.##", "#######", "###.###", "##...##"],
}


def menu_logo(text):
    """The game's name. The letters are placed by hand, so a new name needs its letters
    added above. Fine shading at art size keeps the big blocks on the 2x grid."""
    w, h = 340, 56
    mask = Image.new("1", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    cursor = 3
    for letter in text.upper():
        rows = LOGO_LETTERS[letter]
        for row, line in enumerate(rows):
            for column, key in enumerate(line):
                if key == "#":
                    x, y = cursor + column * LOGO_BLOCK, 3 + row * LOGO_BLOCK
                    draw.rectangle((x, y, x + LOGO_BLOCK - 1, y + LOGO_BLOCK - 1), fill=1)
        cursor += (len(rows[0]) + 1) * LOGO_BLOCK
    left, top, right, bottom = mask.getbbox()
    bits = mask.load()

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and bits[x, y]

    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = image.load()
    ramp = [hexc(c) for c in ("#fff6c4", "#ffe680", "#ffd14f", "#f6b23a", "#e08a28")]
    # A deep block under the letters, then the letters, then an ink outline.
    for y in range(h):
        for x in range(w):
            if any(solid(x, y - depth) for depth in range(1, 7)):
                px[x, y] = hexc("#9c4a24") if (x + y) % 2 else hexc("#7a3620")
    for y in range(h):
        for x in range(w):
            if solid(x, y):
                color = ramp_color(ramp, (y - top) / max(bottom - top - 1, 1), x, y)
                if not solid(x, y - 1):
                    color = hexc("#fffbe6")
                elif not solid(x + 1, y):
                    color = shade(color, 0.86)
                px[x, y] = color
    outline_outside(image)
    return image.crop(image.getbbox())


def make_menu():
    MENU.mkdir(exist_ok=True)
    x2(menu_sky()).save(MENU / "sky.png")
    x2(menu_mountains()).save(MENU / "mountains.png")
    x2(menu_town_hill()).save(MENU / "town_hill.png")
    x2(menu_near_hill()).save(MENU / "near_hill.png")
    x2(menu_front()).save(MENU / "front.png")
    clouds = Image.new("RGBA", (120, 34 * 3), (0, 0, 0, 0))
    for row, (seed, width) in enumerate(((3, 120), (5, 96), (7, 76))):
        clouds.alpha_composite(menu_cloud(seed, width), (0, row * 34))
    x2(clouds).save(MENU / "clouds.png")
    x2(menu_portal()).save(MENU / "portal.png")
    x2(menu_logo("Crownroad")).save(MENU / "logo.png")
