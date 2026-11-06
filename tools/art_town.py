"""The town's own buildings, in assets/custom/town/: the Tavern and the Portal, each
with a gold outline that shows when it is pointed at. tools/make_art.py runs this.
Everything is original and made only from code, in the colors of the Puny World tiles."""
from PIL import Image, ImageDraw
from make_art import OUT, hexc, x2
from art_kit import BAYER, ellipse_tier, menu_portal, outline_outside

TOWN = OUT / "town"
PORTAL_FRAMES = 8
GLOW = hexc("#ffe27a")

THATCH_DARK, THATCH, THATCH_LIGHT = hexc("#a35a26"), hexc("#d98a35"), hexc("#f2b65c")
TIMBER, TIMBER_DARK = hexc("#6e452b"), hexc("#3f2822")
PLASTER, PLASTER_DARK = hexc("#efe0b6"), hexc("#c9b48a")
STONE, STONE_DARK, STONE_LIGHT = hexc("#a9a397"), hexc("#6f6a66"), hexc("#d3cec0")
WINDOW, WINDOW_LIGHT = hexc("#f7b53c"), hexc("#fff0a0")
GROUND_SHADOW = hexc("#1b3320", 110)


def thatch(image, left, top, right, bottom, shape=None):
    """Fills a box with rows of straw, darker towards the eaves. `shape(x, y)` trims it."""
    px = image.load()
    for y in range(top, bottom + 1):
        depth = (y - top) / max(1, bottom - top)
        for x in range(left, right + 1):
            if shape is not None and not shape(x, y):
                continue
            row = (y - top) // 5
            stripe = (x + row * 3 + (y - top) % 5 // 3) % 6
            edge = (y - top) % 5 == 4
            value = 0.62 - depth * 0.3 + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.2
            color = THATCH_LIGHT if value > 0.5 else THATCH if value > 0.22 else THATCH_DARK
            if edge or stripe == 0:
                color = THATCH_DARK if color != THATCH_DARK else hexc("#7c4220")
            px[x, y] = color


def timber_wall(draw, left, top, right, bottom):
    draw.rectangle((left, top, right, bottom), fill=PLASTER)
    draw.rectangle((left, top, left + 1, bottom), fill=PLASTER_DARK)


def post(draw, x, top, bottom):
    draw.rectangle((x, top, x + 2, bottom), fill=TIMBER)
    draw.line((x + 2, top, x + 2, bottom), fill=TIMBER_DARK)


def window(draw, left, top, width, height):
    draw.rectangle((left - 1, top - 1, left + width, top + height), fill=TIMBER_DARK)
    draw.rectangle((left, top, left + width - 1, top + height - 1), fill=WINDOW)
    draw.rectangle((left, top, left + width // 2 - 1, top + height // 2 - 1), fill=WINDOW_LIGHT)
    draw.line((left + width // 2, top, left + width // 2, top + height - 1), fill=TIMBER_DARK)
    draw.line((left, top + height // 2, left + width - 1, top + height // 2), fill=TIMBER_DARK)
    draw.rectangle((left - 2, top + height, left + width + 1, top + height + 1), fill=TIMBER)


def barrel(draw, left, base):
    draw.rectangle((left, base - 9, left + 7, base), fill=TIMBER)
    draw.rectangle((left + 1, base - 10, left + 6, base - 10), fill=hexc("#a4713f"))
    draw.line((left + 5, base - 9, left + 5, base), fill=hexc("#a4713f"))
    draw.line((left, base - 7, left + 7, base - 7), fill=STONE_DARK)
    draw.line((left, base - 2, left + 7, base - 2), fill=STONE_DARK)


def hanging_sign(draw, x, y):
    """A board with a foaming mug on it, hung from a wooden arm."""
    draw.rectangle((x - 2, y - 3, x + 13, y - 2), fill=TIMBER_DARK)
    draw.line((x + 1, y - 2, x + 1, y), fill=TIMBER_DARK)
    draw.line((x + 10, y - 2, x + 10, y), fill=TIMBER_DARK)
    draw.rectangle((x - 1, y, x + 12, y + 12), fill=TIMBER_DARK)
    draw.rectangle((x, y + 1, x + 11, y + 11), fill=hexc("#a4713f"))
    draw.rectangle((x + 3, y + 5, x + 7, y + 10), fill=hexc("#f2b23e"))
    draw.rectangle((x + 3, y + 3, x + 7, y + 4), fill=hexc("#fff6e0"))
    draw.line((x + 8, y + 6, x + 9, y + 6), fill=TIMBER_DARK)
    draw.line((x + 9, y + 6, x + 9, y + 8), fill=TIMBER_DARK)
    draw.line((x + 8, y + 8, x + 9, y + 8), fill=TIMBER_DARK)


def tavern():
    """A long timber hall under a heavy thatch roof, with lit windows, 96 by 88 art pixels."""
    w, h = 96, 88
    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    base = 83

    # The chimney stands behind the roof.
    draw.rectangle((68, 8, 76, 30), fill=STONE)
    draw.rectangle((68, 8, 70, 30), fill=STONE_DARK)
    draw.rectangle((67, 6, 77, 9), fill=STONE_LIGHT)
    for y in range(12, 30, 5):
        draw.line((71, y, 76, y), fill=STONE_DARK)

    # Walls, on a stone footing.
    timber_wall(draw, 9, 50, 86, base - 6)
    draw.rectangle((9, base - 6, 86, base - 1), fill=STONE)
    for x in range(10, 86, 7):
        draw.line((x + (x % 2) * 2, base - 6, x + (x % 2) * 2, base - 1), fill=STONE_DARK)
    draw.line((9, base - 1, 86, base - 1), fill=STONE_DARK)
    draw.rectangle((9, 60, 86, 61), fill=TIMBER)
    draw.line((9, 61, 86, 61), fill=TIMBER_DARK)
    for x in (9, 30, 63, 84):
        post(draw, x, 50, base - 6)
    window(draw, 15, 65, 11, 8)
    window(draw, 69, 65, 11, 8)

    # The door, up one step.
    draw.rectangle((39, 60, 56, base - 1), fill=TIMBER_DARK)
    draw.rectangle((41, 63, 54, base - 2), fill=TIMBER)
    draw.line((47, 63, 47, base - 2), fill=TIMBER_DARK)
    draw.line((48, 63, 48, base - 2), fill=TIMBER_DARK)
    draw.point([(45, 73), (50, 73)], fill=hexc("#f2b23e"))
    draw.rectangle((37, base - 1, 58, base + 1), fill=STONE_LIGHT)
    draw.line((37, base + 1, 58, base + 1), fill=STONE_DARK)

    # The roof: wide at the eaves, narrow at the ridge.
    top, eave = 16, 52

    def main_roof(x, y):
        inset = (eave - y) * 12 // (eave - top)
        return 3 + inset <= x <= 92 - inset

    thatch(image, 3, top, 92, eave, main_roof)
    draw.line((15, top, 80, top), fill=THATCH_LIGHT)
    draw.line((3, eave + 1, 92, eave + 1), fill=hexc("#7c4220"))
    draw.line((3, eave + 2, 92, eave + 2), fill=TIMBER_DARK)

    # A gable over the door, with a room above it.
    timber_wall(draw, 37, 40, 58, 52)
    post(draw, 37, 40, 52)
    post(draw, 56, 40, 52)
    window(draw, 43, 42, 9, 7)

    def gable(x, y):
        return abs(x - 47.5) <= (y - 21) * 0.92 + 1

    thatch(image, 30, 22, 65, 41, gable)
    draw.line((29, 41, 66, 41), fill=hexc("#7c4220"))
    draw.line((29, 42, 66, 42), fill=TIMBER_DARK)

    hanging_sign(draw, 12, 38)
    barrel(draw, 86, base)
    barrel(draw, 3, base)

    outline_outside(image)
    under = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(under).rectangle((6, base + 1, 90, base + 3), fill=GROUND_SHADOW)
    under.alpha_composite(image)
    return under


def rune_stone(image, x, base):
    draw = ImageDraw.Draw(image)
    draw.rectangle((x, base - 15, x + 5, base), fill=STONE)
    draw.rectangle((x, base - 15, x + 1, base), fill=STONE_DARK)
    draw.line((x + 1, base - 16, x + 4, base - 16), fill=STONE_LIGHT)
    draw.line((x + 3, base - 12, x + 3, base - 7), fill=hexc("#4cc6f0"))
    draw.point((x + 3, base - 4), fill=hexc("#a6f4f0"))


def portal():
    """The menu's swirling ring on a round stone yard, 96 by 104 art pixels each frame."""
    w, h = 96, 104
    ring = menu_portal()
    sheet = Image.new("RGBA", (w * PORTAL_FRAMES, h), (0, 0, 0, 0))
    for frame in range(PORTAL_FRAMES):
        cell = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ellipse_tier(cell, 48, 86, 42, 13, 3, STONE, STONE_DARK)
        ellipse_tier(cell, 48, 83, 30, 9, 2, STONE_LIGHT, STONE)
        rune_stone(cell, 9, 84)
        rune_stone(cell, 80, 84)
        one = ring.crop((frame * 56, 0, (frame + 1) * 56, 80))
        cell.alpha_composite(one, (20, 7))
        outline_outside(cell)
        sheet.alpha_composite(cell, (frame * w, 0))
    return sheet


def glow_of(image):
    """Just the outline of a picture, two art pixels thick, in gold."""
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source = image.load()
    px = result.load()
    w, h = image.size
    reach = ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2),
             (1, 1), (-1, 1), (1, -1), (-1, -1))
    for y in range(h):
        for x in range(w):
            if source[x, y][3] > 200:
                continue
            for ox, oy in reach:
                nx, ny = x + ox, y + oy
                if 0 <= nx < w and 0 <= ny < h and source[nx, ny][3] > 200:
                    px[x, y] = GLOW
                    break
    return result


def make_town():
    TOWN.mkdir(exist_ok=True)
    hall = tavern()
    x2(hall).save(TOWN / "tavern.png")
    x2(glow_of(hall)).save(TOWN / "tavern_glow.png")
    sheet = portal()
    x2(sheet).save(TOWN / "portal.png")
    frame = sheet.crop((0, 0, sheet.width // PORTAL_FRAMES, sheet.height))
    x2(glow_of(frame)).save(TOWN / "portal_glow.png")
