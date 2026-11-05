"""Generates the original art in assets/custom/ and the tile table in
board/PunyTiles.gd. Run from the project root:  python tools/make_art.py
Needs Pillow. Everything it draws is original and made only from code."""
import math
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image

OUT = Path("assets/custom")
INK = (32, 22, 34, 255)


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def shade(color, amount):
    return tuple(max(0, min(255, int(c * amount))) for c in color[:3]) + (color[3],)


def x2(image):
    return image.resize((image.width * 2, image.height * 2), Image.NEAREST)


# --- Board spaces -----------------------------------------------------------

SPACE_CELL = 40
SPACE_COLORS = ["#e8b33a", "#b9a98c", "#46a65c", "#8b5fd0", "#e08a3e", "#4c8fe6",
                "#dd5fa3", "#f0cf4f", "#d8423f", "#2fb3ad", "#a9dcf2", "#6b4a63"]


def space_disc(color, rim_light, rim_dark):
    image = Image.new("RGBA", (SPACE_CELL, SPACE_CELL), (0, 0, 0, 0))
    px = image.load()
    cx, cy, rx, ry, depth = 19.5, 17.5, 17.5, 14.0, 4
    for y in range(SPACE_CELL):
        for x in range(SPACE_CELL):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            top = dx * dx + dy * dy
            side = dx * dx + ((y - cy - depth) / ry) ** 2
            if top <= 1.0:
                d = math.sqrt(top)
                light = (-dx - dy * 1.3) * 0.5
                if d > 0.93:
                    px[x, y] = shade(rim_light, 1.15) if light > 0 else rim_light
                elif d > 0.74:
                    seam = math.atan2(dy, dx) / (math.pi / 6)
                    if abs(seam - round(seam)) < 0.07:
                        px[x, y] = shade(rim_dark, 0.8)
                    else:
                        px[x, y] = rim_light if light > 0.05 else rim_dark
                elif d > 0.68:
                    px[x, y] = shade(color, 0.5)
                else:
                    level = 1.0 + light * 0.5
                    if (x + y) % 2 == 0:
                        level += 0.04
                    level = round(level * 7) / 7
                    px[x, y] = shade(color, level)
            elif side <= 1.0 or (abs(dx) <= 1.0 and cy <= y <= cy + depth):
                px[x, y] = shade(rim_dark, 0.62 if (x // 3) % 2 else 0.54)
    # A one pixel outline.
    outline = image.copy()
    opx = outline.load()
    for y in range(SPACE_CELL):
        for x in range(SPACE_CELL):
            if px[x, y][3] == 0:
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + ox, y + oy
                    if 0 <= nx < SPACE_CELL and 0 <= ny < SPACE_CELL and px[nx, ny][3] > 0:
                        opx[x, y] = INK
                        break
    return outline


def make_spaces():
    sheet = Image.new("RGBA", (SPACE_CELL * len(SPACE_COLORS), SPACE_CELL), (0, 0, 0, 0))
    stone_light, stone_dark = hexc("#cfc4ab"), hexc("#94866f")
    gold_light, gold_dark = hexc("#f6dc86"), hexc("#b57f2c")
    for index, color in enumerate(SPACE_COLORS):
        special = index in (0, 4)
        disc = space_disc(hexc(color), gold_light if special else stone_light,
                          gold_dark if special else stone_dark)
        sheet.alpha_composite(disc, (index * SPACE_CELL, 0))
    sheet.save(OUT / "spaces.png")


# --- Icons ------------------------------------------------------------------

PALETTE = {
    "g": "#f2c23e", "y": "#fff0a0", "o": "#c67c22", "w": "#ffffff", "s": "#d7dce8",
    "d": "#7c8298", "r": "#e23d3d", "R": "#8e1f2d", "b": "#4aa3f0", "B": "#235fb0",
    "c": "#9df0f0", "p": "#ff8ad0", "P": "#b13fa8", "n": "#a8682f", "N": "#6e3f21",
    "G": "#57c05f", "T": "#2f8f6b", "m": "#ffe9c8",
}
ICONS = [
    # Castle: a crown.
    ["...y.....y....", "..yoy.y.yoy.y.", "...g..g..g..g.", "...gg.g.gg.gg.", "...gggggggggg.",
     "...ggrgggbggg.", "...gggggggggg.", "...oooooooooo."],
    # Normal: nothing.
    [],
    # Shop: a money pouch.
    ["....NnnN....", ".....nn.....", "....gggg....", "...nnnnnn...", "..nnnnnnnn..",
     ".nnnyggynnn.", ".nnnggggnnn.", ".nnnyggynnn.", ".nnnnnnnnnN.", "..NnnnnnNN.."],
    # Event: a question mark.
    ["...wwwwww...", "..wwyyyyww..", "..ww....ww..", "........ww..", ".......www..",
     ".....wwww...", ".....ww.....", "............", ".....ww.....", ".....ww....."],
    # Town: a house.
    [".....rr.....", "....rRRr....", "...rRRRRr...", "..rRRRRRRr..", ".rRRRRRRRRr.",
     "..mmmmmmmm..", "..mNNmmbbm..", "..mNNmmbbm..", "..mNNmmmmm.."],
    # Item: a potion.
    ["....NNNN....", ".....ss.....", ".....ss.....", "....ssss....", "...s.bbbs...",
     "..sbbbbbbs..", "..sbcbbbbs..", "..sbbbbbBs..", "...sBBBBs..."],
    # Magic: a four pointed star.
    [".....p......", ".....p......", "....ppp...w.", "....pwp.....", ".ppppwwpppp.",
     "..pppwwppp..", "....pwp.....", "..w.ppp.....", ".....p......", ".....p......"],
    # Gold: a stack of coins.
    ["....oooo....", "...gyyyyg...", "...gggggg...", "...oooooo...", ".oooo.gggg..",
     "gyyyyggggggg", "ggggggoooooo", "ooooooyyyygg", "ggggggggggoo", "oooooooooo.."],
    # Battle: crossed swords.
    ["s........s..", "ws......sw..", ".ws....sw...", "..ws..sw....", "...wssw.....",
     "....ww......", "...swsw.....", "n.sw..ws.n..", "ogn....ngo..", ".n......n..."],
    # Treasure: a chest.
    ["..nnnnnnnn..", ".nnNNNNNNnn.", ".nNnnnnnnNn.", ".gggggggggg.", ".nnnngynnnn.",
     ".nnnnggnnnn.", ".NnnnnnnnnN.", ".NNNNNNNNNN."],
    # Shrine: a heart.
    ["..ww...ww...", ".wrrw.wrrw..", "wrrrrwrrrrw.", "wrwrrrrrrrw.", "wrrrrrrrrrw.",
     ".wrrrrrrrw..", "..wrrrrrw...", "...wrrrw....", "....wrw.....", ".....w......"],
    # Trap: a skull.
    ["...ssssss...", "..ssssssss..", ".ssssssssss.", ".sNNssssNNs.", ".sNNssssNNs.",
     ".ssssNNssss.", "..ssssssss..", "...sNsNsN...", "...ssssss..."],
]
ICON_CELL = 20


def make_icons():
    sheet = Image.new("RGBA", (ICON_CELL * len(ICONS), ICON_CELL), (0, 0, 0, 0))
    for index, rows in enumerate(ICONS):
        if not rows:
            continue
        width, height = max(len(r) for r in rows), len(rows)
        left = index * ICON_CELL + (ICON_CELL - width) // 2
        top = (ICON_CELL - height) // 2
        filled = {}
        for y, row in enumerate(rows):
            for x, char in enumerate(row):
                if char != ".":
                    filled[(x, y)] = hexc(PALETTE[char])
        for (x, y) in filled:
            for ox in (-1, 0, 1):
                for oy in (-1, 0, 1):
                    if (x + ox, y + oy) not in filled:
                        sheet.putpixel((left + x + ox, top + y + oy), INK)
        for (x, y), color in filled.items():
            sheet.putpixel((left + x, top + y), color)
    sheet.save(OUT / "space_icons.png")


# --- The die ----------------------------------------------------------------

DIE_CELL = 72
PIPS = {
    1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
}
# Normal of each face, and the two axes lying on it. Opposite faces add up to 7.
FACES = {
    1: ((0, 0, 1), (1, 0, 0), (0, 1, 0)), 6: ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
    2: ((1, 0, 0), (0, 0, -1), (0, 1, 0)), 5: ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    3: ((0, -1, 0), (1, 0, 0), (0, 0, 1)), 4: ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
}


def matmul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def apply(m, v):
    return tuple(sum(m[r][c] * v[c] for c in range(3)) for r in range(3))


def render_die(rotation):
    image = Image.new("RGBA", (DIE_CELL, DIE_CELL), (0, 0, 0, 0))
    size = 21.0
    center = DIE_CELL / 2 - 0.5
    inverse = [[rotation[c][r] for c in range(3)] for r in range(3)]
    light = (-0.45, -0.65, 0.62)
    for py in range(DIE_CELL):
        for px in range(DIE_CELL):
            sx, sy = (px - center) / size, (py - center) / size
            best_z, best = -99.0, None
            for value, (normal, axis_u, axis_v) in FACES.items():
                world_normal = apply(rotation, normal)
                if world_normal[2] <= 0.02:
                    continue
                z = (1 - world_normal[0] * sx - world_normal[1] * sy) / world_normal[2]
                point = apply(inverse, (sx, sy, z))
                u = sum(point[i] * axis_u[i] for i in range(3))
                v = sum(point[i] * axis_v[i] for i in range(3))
                if abs(u) <= 1.0 and abs(v) <= 1.0 and z > best_z:
                    best_z, best = z, (value, u, v, world_normal)
            if best is None:
                continue
            value, u, v, normal = best
            amount = max(0.0, sum(normal[i] * light[i] for i in range(3)))
            level = round((0.72 + amount * 0.34) * 5) / 5
            color = shade(hexc("#f7ecd2"), level)
            if max(abs(u), abs(v)) > 0.9:
                color = shade(color, 0.86)
            for gu, gv in PIPS[value]:
                if math.hypot(u - gu * 0.5, v - gv * 0.5) < 0.2:
                    color = hexc("#c9302f") if value == 1 else hexc("#2c2030")
            image.putpixel((px, py), color)
    edge = image.copy()
    source = image.load()
    for py in range(1, DIE_CELL - 1):
        for px in range(1, DIE_CELL - 1):
            if source[px, py][3] == 0:
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if source[px + ox, py + oy][3] > 0:
                        edge.putpixel((px, py), INK)
                        break
    return edge


def make_die():
    tumble = 24
    sheet = Image.new("RGBA", (DIE_CELL * tumble, DIE_CELL * 2), (0, 0, 0, 0))
    for frame in range(tumble):
        t = frame / tumble * math.tau
        rotation = matmul(rot_x(t * 2 + 0.4), matmul(rot_y(t * 3 + 1.0), rot_z(t + 0.3)))
        sheet.alpha_composite(render_die(rotation), (frame * DIE_CELL, 0))
    # The resting faces: the wanted face looks at the viewer, tilted a little.
    tilt = matmul(rot_x(0.42), rot_y(-0.48))
    turn_to_front = {
        1: rot_x(0), 6: rot_y(math.pi), 2: rot_y(-math.pi / 2), 5: rot_y(math.pi / 2),
        3: rot_x(-math.pi / 2), 4: rot_x(math.pi / 2),
    }
    for value in range(1, 7):
        sheet.alpha_composite(render_die(matmul(tilt, turn_to_front[value])),
                              ((value - 1) * DIE_CELL, DIE_CELL))
    sheet.save(OUT / "die.png")


# --- Small effects ----------------------------------------------------------

def blob(image, cx, cy, radius, color):
    for y in range(image.height):
        for x in range(image.width):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                image.putpixel((x, y), color)


def make_fx():
    # Row 0: dust. Row 1: smoke. Row 2: sparkle. Row 3: the chevron.
    sheet = Image.new("RGBA", (16 * 4, 16 * 4), (0, 0, 0, 0))
    for frame in range(4):
        cell = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        radius = 2 + frame * 1.3
        alpha = 230 - frame * 45
        blob(cell, 7.5, 9, radius, hexc("#e7cf9b", alpha))
        blob(cell, 6.5, 8, max(radius - 1.5, 0.5), hexc("#fff2cf", alpha))
        sheet.alpha_composite(cell, (frame * 16, 0))
        cell = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        blob(cell, 7.5, 8, 1.5 + frame, hexc("#e8e6e2", 215 - frame * 55))
        blob(cell, 6.5, 7, 0.6 + frame * 0.7, hexc("#ffffff", 215 - frame * 55))
        sheet.alpha_composite(cell, (frame * 16, 16))
        cell = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        reach = [1, 3, 5, 2][frame]
        for i in range(-reach, reach + 1):
            cell.putpixel((7 + i, 7), (255, 255, 255, 255))
            cell.putpixel((7, 7 + i), (255, 255, 255, 255))
        sheet.alpha_composite(cell, (frame * 16, 32))
    arrow = ["ddddddddddd", "dyyyyyyyyyd", "dgggggggood", ".dgggggood.",
             "..dgggood..", "...dgood...", "....dod....", ".....d....."]
    colors = {"d": INK, "y": hexc("#fff0a0"), "g": hexc("#f2c23e"), "o": hexc("#c67c22")}
    for y, row in enumerate(arrow):
        for x, char in enumerate(row):
            if char != ".":
                sheet.putpixel((2 + x, 52 + y), colors[char])
    sheet.save(OUT / "fx.png")

    # Cloud shadows, soft and dithered.
    cloud = Image.new("RGBA", (120, 56), (0, 0, 0, 0))
    lobes = [(30, 30, 18), (52, 24, 22), (76, 28, 19), (94, 32, 13), (44, 36, 16), (66, 38, 14)]
    for y in range(cloud.height):
        for x in range(cloud.width):
            value = max(1 - math.hypot(x - a, y - b) / r for a, b, r in lobes)
            if value > 0.0 and (value > 0.22 or (x + y) % 2 == 0):
                cloud.putpixel((x, y), (20, 30, 60, 70))
    cloud.save(OUT / "cloud.png")

    # A bird in three wing positions.
    bird = Image.new("RGBA", (27, 9), (0, 0, 0, 0))
    wings = [["#.......#", ".#.....#.", "..#.#.#..", "...###..."],
             [".........", "##.....##", "..##.##..", "...###..."],
             [".........", ".........", "..#####..", ".#.###.#.", "#.......#"]]
    for frame, rows in enumerate(wings):
        for y, row in enumerate(rows):
            for x, char in enumerate(row):
                if char == "#":
                    bird.putpixel((frame * 9 + x, y + 2), hexc("#f4f4f0"))
    bird.save(OUT / "bird.png")

    # A castle banner, waving over four frames.
    flag = Image.new("RGBA", (12 * 4, 14), (0, 0, 0, 0))
    for frame in range(4):
        for y in range(14):
            flag.putpixel((frame * 12 + 1, y), hexc("#5b4632"))
        for x in range(2, 11):
            wave = round(math.sin(x * 0.9 - frame * math.pi / 2))
            for y in range(1, 7):
                color = hexc("#d8423f") if y != 3 else hexc("#f2c23e")
                if x % 2 and frame % 2:
                    color = shade(color, 0.86)
                flag.putpixel((frame * 12 + x, y + wave + 1), color)
    flag.save(OUT / "flag.png")


# --- Interface --------------------------------------------------------------

GOLD, GOLD_LIGHT, GOLD_DARK = hexc("#d9a441"), hexc("#f6dc86"), hexc("#8a5a1f")


def framed(width, height, top, bottom, frame=GOLD, light=GOLD_LIGHT, dark=GOLD_DARK, studs=True):
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y in range(height):
        t = y / max(height - 1, 1)
        for x in range(width):
            mix = t + (0.04 if (x + y) % 2 == 0 else -0.04)
            mix = max(0.0, min(1.0, round(mix * 6) / 6))
            color = tuple(int(top[i] + (bottom[i] - top[i]) * mix) for i in range(3)) + (255,)
            image.putpixel((x, y), color)
    for i in range(width):
        for y, c in ((0, INK), (1, light), (2, frame), (3, dark),
                     (height - 1, INK), (height - 2, dark), (height - 3, frame), (height - 4, dark)):
            image.putpixel((i, y), c)
    for i in range(height):
        for x, c in ((0, INK), (1, light), (2, frame), (3, dark),
                     (width - 1, INK), (width - 2, dark), (width - 3, frame), (width - 4, dark)):
            image.putpixel((x, i), c)
    if studs:
        for cx in (0, width - 6):
            for cy in (0, height - 6):
                for y in range(6):
                    for x in range(6):
                        image.putpixel((cx + x, cy + y), GOLD if 0 < x < 5 and 0 < y < 5 else INK)
                image.putpixel((cx + 2, cy + 2), GOLD_LIGHT)
                image.putpixel((cx + 3, cy + 3), GOLD_DARK)
    # Round off the outer corners.
    for cx, cy in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        image.putpixel((cx, cy), (0, 0, 0, 0))
    return image


def button(top, bottom, offset=0):
    image = framed(32, 16, top, bottom, studs=False)
    if offset:
        shifted = Image.new("RGBA", image.size, (0, 0, 0, 0))
        shifted.paste(image.crop((0, 0, 32, 15)), (0, 1))
        return shifted
    return image


def make_ui():
    x2(framed(32, 32, hexc("#2a3163"), hexc("#141734"))).save(OUT / "panel.png")
    x2(button(hexc("#b23a35"), hexc("#7b1f28"))).save(OUT / "button.png")
    x2(button(hexc("#dc5a48"), hexc("#a02c30"))).save(OUT / "button_hover.png")
    x2(button(hexc("#7b1f28"), hexc("#5b1720"), 1)).save(OUT / "button_pressed.png")
    x2(framed(32, 16, hexc("#5b5a6a"), hexc("#3d3c4a"), hexc("#85838e"), hexc("#a5a3ad"),
              hexc("#55535e"), studs=False)).save(OUT / "button_disabled.png")

    # A ribbon, grey so that code can tint it with the player's color.
    ribbon = Image.new("RGBA", (96, 28), (0, 0, 0, 0))
    for y in range(4, 26):
        for x in range(96):
            level = 235 if y < 7 else 205 if y < 22 else 165
            if x < 10 or x >= 86:
                level = int(level * 0.72)
                if abs(y - 15) < (10 - x if x < 10 else x - 85):
                    continue
            ribbon.putpixel((x, y), (level, level, level, 255))
    pixels = ribbon.copy().load()
    for x in range(96):
        for y in range(28):
            if pixels[x, y][3] == 0:
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + ox, y + oy
                    if 0 <= nx < 96 and 0 <= ny < 28 and pixels[nx, ny][3] == 255:
                        ribbon.putpixel((x, y), INK)
                        break
    x2(ribbon).save(OUT / "ribbon.png")

    # The frame around a portrait: its middle is left clear.
    portrait = framed(24, 24, hexc("#000000"), hexc("#000000"), studs=False)
    px = portrait.load()
    for y in range(4, 20):
        for x in range(4, 20):
            px[x, y] = (0, 0, 0, 0)
    x2(portrait).save(OUT / "portrait_frame.png")


# --- Tile table -------------------------------------------------------------

def make_tile_table():
    root = ET.parse("assets/puny/world/punyworld-overworld-tiles.tsx").getroot()
    animated = {}
    for tile in root.findall("tile"):
        animation = tile.find("animation")
        if animation is not None:
            frames = [int(f.get("tileid")) for f in animation]
            animated[int(tile.get("id"))] = frames
    frame_ids = {f for frames in animated.values() for f in frames[1:]}
    table = {}
    for wang in root.find("wangsets")[0].findall("wangtile"):
        ids = [int(v) for v in wang.get("wangid").split(",")]
        key = ids[7] * 2197 + ids[1] * 169 + ids[3] * 13 + ids[5]
        tile = int(wang.get("tileid"))
        if tile not in frame_ids:
            table.setdefault(key, []).append(tile)
    # Tile id -> how many rows down the sheet its next frame is.
    regular = {i: (f[1] - f[0]) // 27 for i, f in sorted(animated.items())
               if len(f) == 4 and f[1] - f[0] >= 27}
    lines = [
        "class_name PunyTiles", "extends RefCounted",
        "## Generated by tools/make_art.py from the Puny World tileset. Do not edit.",
        "## WANG maps the terrains on a tile's corners to the tiles that fit them. The",
        "## key is top_left * 2197 + top_right * 169 + bottom_right * 13 + bottom_left.",
        "## ANIMATED maps a tile with 4 frames to the rows between its frames.",
        "", "const WANG := {",
    ]
    lines += [f"\t{key}: {value}," for key, value in sorted(table.items())]
    lines += ["}", "", f"const ANIMATED := {regular}", ""]
    Path("board/PunyTiles.gd").write_text("\n".join(lines), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    make_spaces()
    make_icons()
    make_die()
    make_fx()
    make_ui()
    make_tile_table()
