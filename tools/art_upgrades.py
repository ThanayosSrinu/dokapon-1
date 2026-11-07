"""What E17 adds to the town, in assets/custom/town/: the Storehouse, the Smithy and the
Academy at each level, the empty lot a building waits on, the Castle's outline, and the
Portal with its Beacon. It also draws the Castle's hall and the Academy's room, in
assets/custom/castle/ and assets/custom/academy/. tools/make_art.py runs this.

Everything is original and made only from code, in the colors of the Puny tiles. Level 1
of a building is <id>.png, and a higher level is <id>_<level>.png. A building not built yet
shows lot.png. castle/CastleRoom.gd and academy/AcademyRoom.gd use the Tavern's room
layout, so the counter and the keeper stand where they do in the Shop."""
import math
from PIL import Image, ImageDraw
from make_art import OUT, hexc, x2
from art_kit import BAYER, outline_outside
from art_tavern import (BEAM, BEAM_DARK, BEAM_LIGHT, COUNTER_H, COUNTER_TOP, COUNTER_W, FLOOR_Y,
                        GOLD, GOLD_LIGHT, INK, ROOM_H, ROOM_W, WALL_TOP, at, darken_edges,
                        door, glow, lantern, lit_window, paint_ceiling_and_wall, paint_floor,
                        rect)
from art_town import (GLOW, GROUND_SHADOW, PLASTER, PLASTER_DARK, PORTAL_FRAMES, STONE,
                      STONE_DARK, STONE_LIGHT, TIMBER, TIMBER_DARK, TOWN, WINDOW, WINDOW_LIGHT,
                      glow_of, portal, post, window)
from art_bank import stone_wall

CASTLE = OUT / "castle"
ACADEMY = OUT / "academy"
PLANK, PLANK_DARK, PLANK_LIGHT = hexc("#9a6a3c"), hexc("#6e452b"), hexc("#c08a52")
SHINGLE, SHINGLE_DARK, SHINGLE_LIGHT = hexc("#7a5238"), hexc("#4f3326"), hexc("#a4713f")
SLATE, SLATE_DARK, SLATE_LIGHT = hexc("#55607a"), hexc("#363e55"), hexc("#7d89a6")
BLUE, BLUE_DARK, BLUE_LIGHT = hexc("#3b5fb8"), hexc("#273f80"), hexc("#6f93e0")
SACK, SACK_DARK = hexc("#d8c08a"), hexc("#a68a58")
FIRE = [hexc("#d8423f"), hexc("#f08a2c"), hexc("#f7c23c"), hexc("#fff0a0")]
EMBER = hexc("#f08a2c")
STEEL, STEEL_DARK, STEEL_LIGHT = hexc("#a8aebf"), hexc("#5f6478"), hexc("#e2e6ee")
BANNER, BANNER_DARK = hexc("#b8483f"), hexc("#7c2f2f")
BOOKS = [hexc("#b8483f"), hexc("#3b5fb8"), hexc("#3f9a5a"), hexc("#d9a53a"), hexc("#8b5fd0")]
BEACON = [hexc("#2f6fd8"), hexc("#4cc6f0"), hexc("#a6f4f0"), hexc("#ffffff")]
# The Castle's walls on the town screen, in art pixels: town/TownArt.gd CASTLE_SIZE.
CASTLE_W, CASTLE_H = 116, 100


def canvas(width, height):
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def finish(image, base, left, right):
    """An ink edge, and a shadow on the ground under it."""
    outline_outside(image)
    under = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(under).rectangle((left, base + 1, right, base + 3), fill=GROUND_SHADOW)
    under.alpha_composite(image)
    return under


def plank_wall(draw, left, top, right, bottom):
    draw.rectangle((left, top, right, bottom), fill=PLANK)
    for x in range(left + 4, right, 5):
        draw.line((x, top, x, bottom), fill=PLANK_DARK)
    for x in range(left + 2, right, 10):
        draw.point((x, top + (x * 7) % max(1, bottom - top)), fill=PLANK_LIGHT)
    draw.rectangle((left, top, left + 1, bottom), fill=PLANK_DARK)


def gable(draw, left, right, top, eave, fill, dark, light):
    """A pitched roof seen from the gable end, with rows of shingles."""
    middle = (left + right) / 2
    draw.polygon([(left, eave), (middle, top), (right, eave)], fill=fill)
    for y in range(top + 3, eave, 3):
        half = (y - top) * (right - left) / 2 / (eave - top)
        draw.line((middle - half, y, middle + half, y), fill=dark)
        for x in range(int(middle - half) + (y // 3 % 2) * 2, int(middle + half), 5):
            draw.point((x, y + 1), fill=light)
    draw.line((left, eave, right, eave), fill=dark)


def sack(draw, left, base):
    draw.ellipse((left, base - 9, left + 9, base), fill=SACK_DARK)
    draw.ellipse((left + 1, base - 9, left + 8, base - 1), fill=SACK)
    draw.rectangle((left + 3, base - 11, left + 6, base - 9), fill=SACK_DARK)


def keg(draw, left, base):
    draw.rectangle((left, base - 9, left + 7, base), fill=TIMBER)
    draw.rectangle((left + 1, base - 10, left + 6, base - 10), fill=PLANK_LIGHT)
    draw.line((left + 5, base - 9, left + 5, base), fill=PLANK_LIGHT)
    draw.line((left, base - 7, left + 7, base - 7), fill=STONE_DARK)
    draw.line((left, base - 2, left + 7, base - 2), fill=STONE_DARK)


def crate(draw, left, base, size=9):
    draw.rectangle((left, base - size, left + size, base), fill=PLANK_LIGHT)
    draw.rectangle((left, base - size, left + size, base - size + 1), fill=PLANK_DARK)
    draw.line((left, base - size, left + size, base), fill=PLANK_DARK)
    draw.rectangle((left, base - size, left + size, base), outline=PLANK_DARK)


def barn_doors(draw, left, top, right, bottom, open_doors=False):
    draw.rectangle((left - 1, top - 1, right + 1, bottom), fill=TIMBER_DARK)
    if open_doors:
        draw.rectangle((left, top, right, bottom), fill=hexc("#2a1c1e"))
        for x in range(left + 2, right - 3, 6):
            sack(draw, x, bottom)
        return
    draw.rectangle((left, top, right, bottom), fill=TIMBER)
    middle = (left + right) // 2
    draw.line((middle, top, middle, bottom), fill=TIMBER_DARK)
    for half in ((left, middle - 1), (middle + 1, right)):
        draw.line((half[0], top, half[1], bottom), fill=TIMBER_DARK)
        draw.line((half[0], bottom, half[1], top), fill=TIMBER_DARK)
    draw.point([(middle - 2, (top + bottom) // 2), (middle + 2, (top + bottom) // 2)], fill=GOLD)


# --- The Storehouse ---------------------------------------------------------------

def storehouse(level):
    """A plank barn under a shingle roof, with sacks and kegs by its doors. Level 2 adds a
    second bay with a loft and a hoist, 84 by 76 art pixels at level 1 and 108 by 84 at 2."""
    wide = level >= 2
    w, h = (108, 84) if wide else (84, 76)
    image, draw = canvas(w, h)
    base = h - 5
    hall_left, hall_right = (6, 66) if wide else (10, 73)
    top = 18 if wide else 14
    if wide:
        # The new bay, set back on the right, with a loft door and a beam to hoist from.
        plank_wall(draw, 66, 34, 101, base - 4)
        gable(draw, 63, 104, 18, 36, SHINGLE, SHINGLE_DARK, SHINGLE_LIGHT)
        draw.rectangle((79, 24, 89, 33), fill=TIMBER_DARK)
        draw.rectangle((80, 25, 88, 33), fill=hexc("#2a1c1e"))
        draw.rectangle((82, 28, 86, 33), fill=SACK)
        draw.rectangle((84, 14, 86, 24), fill=TIMBER_DARK)
        draw.rectangle((84, 14, 98, 15), fill=TIMBER_DARK)
        draw.line((97, 16, 97, 40), fill=INK)
        sack(draw, 93, 49)
        barn_doors(draw, 74, 50, 93, base - 4, open_doors=True)
    eave = top + 22
    plank_wall(draw, hall_left + 3, eave, hall_right - 3, base - 4)
    draw.rectangle((hall_left + 3, base - 5, hall_right - 3, base - 1), fill=STONE)
    draw.line((hall_left + 3, base - 1, hall_right - 3, base - 1), fill=STONE_DARK)
    for x in range(hall_left + 5, hall_right - 3, 7):
        draw.line((x, base - 5, x, base - 1), fill=STONE_DARK)
    gable(draw, hall_left - 2, hall_right + 2, top, eave, SHINGLE, SHINGLE_DARK, SHINGLE_LIGHT)
    middle = (hall_left + hall_right) // 2
    # A round vent in the gable, and a wheat sheaf painted over the doors.
    draw.ellipse((middle - 4, top + 8, middle + 4, top + 16), fill=TIMBER_DARK)
    draw.ellipse((middle - 3, top + 9, middle + 3, top + 15), fill=hexc("#2a1c1e"))
    barn_doors(draw, middle - 11, eave + 12, middle + 11, base - 5)
    for dx in (-2, 0, 2):
        draw.line((middle + dx, eave + 3, middle + dx // 2, eave + 9), fill=GOLD)
    draw.line((middle - 3, eave + 7, middle + 3, eave + 7), fill=SHINGLE_DARK)
    window(draw, hall_left + 8, eave + 6, 7, 6)
    window(draw, hall_right - 15, eave + 6, 7, 6)
    sack(draw, hall_left, base)
    sack(draw, hall_left + 7, base)
    keg(draw, hall_right - 6, base)
    if not wide:
        crate(draw, hall_right - 1, base)
    return finish(image, base, 2, w - 3)


# --- The Smithy ---------------------------------------------------------------------

def anvil(draw, left, base):
    draw.rectangle((left + 3, base - 4, left + 8, base), fill=STEEL_DARK)
    draw.rectangle((left, base - 8, left + 11, base - 5), fill=STEEL)
    draw.polygon([(left + 11, base - 8), (left + 15, base - 8), (left + 11, base - 6)], fill=STEEL)
    draw.line((left, base - 8, left + 11, base - 8), fill=STEEL_LIGHT)


def smithy(level, frame=0):
    """A stone forge under a slate roof, open at the front, with an anvil and a glowing
    hearth. Level 2 has a taller chimney, a weapon rack and a banner, 88 by 84 art pixels."""
    w, h = 88, 84
    image, draw = canvas(w, h)
    base = h - 5
    # The chimney, behind the roof.
    tall = level >= 2
    chimney_top = 4 if tall else 14
    draw.rectangle((60, chimney_top, 70, 40), fill=STONE)
    for y in range(chimney_top + 3, 40, 4):
        draw.line((60, y, 70, y), fill=STONE_DARK)
    draw.rectangle((58, chimney_top - 2, 72, chimney_top), fill=STONE_DARK)
    draw.rectangle((62, chimney_top - 2, 68, chimney_top - 1), fill=EMBER)
    # Stone walls.
    draw.rectangle((8, 36, 79, base - 1), fill=STONE)
    for y in range(38, base - 1, 5):
        draw.line((8, y, 79, y), fill=STONE_DARK)
        for x in range(8 + (y // 5 % 2) * 4, 79, 9):
            draw.line((x, y, x, y + 4), fill=STONE_DARK)
    draw.rectangle((8, 36, 10, base - 1), fill=STONE_LIGHT)
    # The roof, a long slope seen from the front.
    draw.polygon([(2, 38), (14, 18), (74, 18), (86, 38)], fill=SLATE)
    for y in range(21, 38, 3):
        inset = (38 - y) * 12 // 20
        draw.line((2 + inset, y, 86 - inset, y), fill=SLATE_DARK)
        for x in range(4 + inset + (y // 3 % 2) * 3, 84 - inset, 6):
            draw.point((x, y + 1), fill=SLATE_LIGHT)
    draw.line((2, 38, 86, 38), fill=SLATE_DARK)
    # The open front, with the hearth glowing at the back.
    draw.rectangle((16, 46, 56, base - 1), fill=hexc("#2a1c1e"))
    post(draw, 15, 44, base - 1)
    post(draw, 55, 44, base - 1)
    draw.rectangle((14, 43, 58, 45), fill=TIMBER_DARK)
    flicker = (0, 1, 2, 1)[frame % 4]
    draw.rectangle((20, base - 14, 34, base - 1), fill=STONE_DARK)
    draw.rectangle((22, base - 12, 32, base - 6), fill=FIRE[0])
    draw.rectangle((23, base - 11 + flicker, 31, base - 7), fill=FIRE[1])
    draw.rectangle((25, base - 10 + flicker, 29, base - 8), fill=FIRE[2])
    anvil(draw, 38, base - 1)
    # Tools on the wall, and a round window.
    draw.line((44, 50, 44, 58), fill=BEAM_LIGHT)
    draw.rectangle((42, 49, 46, 51), fill=STEEL)
    draw.line((50, 50, 50, 58), fill=BEAM_LIGHT)
    draw.rectangle((49, 49, 51, 53), fill=STEEL_DARK)
    window(draw, 64, 50, 8, 7)
    # A hanging sign with a hammer.
    draw.rectangle((62, 62, 76, 74), fill=TIMBER_DARK)
    draw.rectangle((63, 63, 75, 73), fill=hexc("#a4713f"))
    draw.line((66, 71, 72, 65), fill=BEAM_DARK)
    draw.rectangle((70, 64, 74, 67), fill=STEEL)
    if tall:
        # A rack of finished blades, and a banner on the roof.
        draw.rectangle((80, base - 18, 85, base - 1), fill=TIMBER)
        for x in (81, 83, 85):
            draw.line((x, base - 24, x, base - 4), fill=STEEL_LIGHT)
            draw.point((x, base - 25), fill=STEEL)
        draw.line((10, 6, 10, 26), fill=TIMBER_DARK)
        draw.polygon([(11, 6), (22, 9), (11, 13)], fill=BANNER)
        draw.line((11, 13, 20, 10), fill=BANNER_DARK)
        draw.point((14, 9), fill=GOLD)
    return finish(image, base, 4, w - 5)


# --- The Academy --------------------------------------------------------------------

def academy(level):
    """A tall stone hall with a blue roof, a round window and a door under an arch, with an
    open book over it. Level 2 adds a tower with a domed roof and a telescope, 96 by 104 art
    pixels at either level, so the lot is the same."""
    w, h = 96, 104
    image, draw = canvas(w, h)
    base = h - 5
    if level >= 2:
        # The tower, behind and to the right, with its dome and a telescope.
        draw.rectangle((64, 20, 86, base - 20), fill=STONE)
        for y in range(23, base - 20, 5):
            draw.line((64, y, 86, y), fill=STONE_DARK)
        draw.rectangle((64, 20, 66, base - 20), fill=STONE_LIGHT)
        draw.pieslice((61, 4, 89, 34), 180, 360, fill=BLUE)
        draw.arc((61, 4, 89, 34), 200, 340, fill=BLUE_LIGHT)
        draw.line((61, 19, 89, 19), fill=BLUE_DARK)
        draw.line((75, 6, 84, 0), fill=STEEL_LIGHT)
        draw.line((76, 7, 85, 1), fill=STEEL_DARK)
        draw.rectangle((71, 26, 79, 34), fill=INK)
        draw.rectangle((72, 27, 78, 33), fill=WINDOW)
        draw.point((73, 28), fill=WINDOW_LIGHT)
        for spot in ((58, 6), (92, 12), (54, 16)):
            draw.point(spot, fill=GOLD_LIGHT)
    left, right = 8, 70
    draw.rectangle((left, 40, right, base - 1), fill=PLASTER)
    for y in range(44, base - 1, 6):
        draw.line((left, y, right, y), fill=PLASTER_DARK)
        for x in range(left + (y // 6 % 2) * 6, right, 12):
            draw.line((x, y, x, y + 5), fill=PLASTER_DARK)
    draw.rectangle((left, 40, left + 2, base - 1), fill=hexc("#fff4d4"))
    draw.rectangle((left, base - 5, right, base - 1), fill=STONE)
    draw.line((left, base - 1, right, base - 1), fill=STONE_DARK)
    # A steep blue roof with a gold spike.
    gable(draw, left - 5, right + 5, 8, 42, BLUE, BLUE_DARK, BLUE_LIGHT)
    middle = (left + right) // 2
    draw.line((middle, 1, middle, 9), fill=GOLD)
    draw.point((middle, 0), fill=GOLD_LIGHT)
    draw.ellipse((middle - 7, 20, middle + 7, 34), fill=INK)
    draw.ellipse((middle - 6, 21, middle + 6, 33), fill=WINDOW)
    draw.line((middle, 21, middle, 33), fill=INK)
    draw.line((middle - 6, 27, middle + 6, 27), fill=INK)
    draw.rectangle((middle - 4, 23, middle - 2, 25), fill=WINDOW_LIGHT)
    # The door under an arch, with an open book above.
    draw.pieslice((middle - 10, 62, middle + 10, 82), 180, 360, fill=STONE_DARK)
    draw.rectangle((middle - 10, 72, middle + 10, base - 5), fill=STONE_DARK)
    draw.pieslice((middle - 8, 64, middle + 8, 80), 180, 360, fill=BEAM)
    draw.rectangle((middle - 8, 72, middle + 8, base - 5), fill=BEAM)
    draw.line((middle, 65, middle, base - 5), fill=BEAM_DARK)
    draw.point([(middle - 3, 84), (middle + 3, 84)], fill=GOLD)
    draw.polygon([(middle - 9, 52), (middle, 55), (middle + 9, 52), (middle + 9, 59), (middle, 61),
                  (middle - 9, 59)], fill=hexc("#fff4d4"))
    draw.line((middle, 55, middle, 61), fill=PLASTER_DARK)
    for y in (55, 57):
        draw.line((middle - 7, y, middle - 2, y + 1), fill=PLASTER_DARK)
        draw.line((middle + 2, y + 1, middle + 7, y), fill=PLASTER_DARK)
    for x in (left + 6, right - 15):
        draw.rectangle((x - 1, 48, x + 9, 66), fill=INK)
        draw.pieslice((x - 1, 44, x + 9, 54), 180, 360, fill=INK)
        draw.rectangle((x, 49, x + 8, 65), fill=WINDOW)
        draw.pieslice((x, 45, x + 8, 53), 180, 360, fill=WINDOW)
        draw.rectangle((x, 49, x + 3, 54), fill=WINDOW_LIGHT)
        draw.line((x + 4, 46, x + 4, 65), fill=INK)
    # Books stacked by the door.
    for index, color in enumerate(BOOKS[:3]):
        draw.rectangle((right + 2, base - 3 - index * 3, right + 10, base - 1 - index * 3), fill=color)
    return finish(image, base, 3, w - 4)


# --- An empty lot, the Castle and the Beacon ----------------------------------------------

def lot():
    """Ground staked out with rope, and a pile of planks, 72 by 44 art pixels. A building
    that has not been built yet stands here."""
    w, h = 72, 44
    image, draw = canvas(w, h)
    base = h - 5
    draw.rectangle((6, 18, 65, base - 2), fill=hexc("#b58a52"))
    for y in range(20, base - 2, 3):
        for x in range(8 + (y % 2) * 3, 64, 6):
            draw.point((x, y), fill=hexc("#9a7244"))
    for x, y in ((6, 18), (65, 18), (6, base - 2), (65, base - 2)):
        draw.rectangle((x - 1, y - 8, x + 1, y), fill=TIMBER)
        draw.point((x, y - 9), fill=TIMBER_DARK)
    draw.line((6, 13, 65, 13), fill=SACK)
    draw.line((6, base - 7, 65, base - 7), fill=SACK)
    draw.line((6, 13, 6, base - 7), fill=SACK)
    draw.line((65, 13, 65, base - 7), fill=SACK)
    for index in range(3):
        y = base - 4 - index * 3
        draw.rectangle((40 - index * 2, y - 2, 60 - index, y), fill=PLANK_LIGHT)
        draw.line((40 - index * 2, y, 60 - index, y), fill=PLANK_DARK)
    draw.rectangle((14, base - 14, 16, base - 3), fill=TIMBER_DARK)
    draw.rectangle((10, base - 20, 22, base - 13), fill=TIMBER_DARK)
    draw.rectangle((11, base - 19, 21, base - 14), fill=hexc("#a4713f"))
    draw.line((13, base - 17, 19, base - 17), fill=TIMBER_DARK)
    return finish(image, base, 4, w - 5)


def castle_outline():
    """The Castle is drawn by the town's own tiles, so its picture is empty and only its
    gold outline shows, around the walls."""
    image = Image.new("RGBA", (CASTLE_W, CASTLE_H), (0, 0, 0, 0))
    glow_image = Image.new("RGBA", (CASTLE_W, CASTLE_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow_image)
    draw.rectangle((0, 0, CASTLE_W - 1, CASTLE_H - 1), outline=GLOW, width=2)
    return image, glow_image


def beacon_portal():
    """The Portal with the Beacon: its rune stones become tall lamps with blue flames."""
    sheet = portal()
    w = sheet.width // PORTAL_FRAMES
    for frame in range(PORTAL_FRAMES):
        cell = Image.new("RGBA", (w, sheet.height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(cell)
        for x in (6, 79):
            draw.rectangle((x, 56, x + 10, 86), fill=STONE)
            draw.rectangle((x, 56, x + 2, 86), fill=STONE_LIGHT)
            draw.rectangle((x + 8, 56, x + 10, 86), fill=STONE_DARK)
            for y in (62, 72):
                draw.line((x + 3, y, x + 7, y), fill=BEACON[1])
            draw.rectangle((x - 2, 52, x + 12, 56), fill=STONE_DARK)
            draw.rectangle((x - 1, 51, x + 11, 52), fill=STONE_LIGHT)
            lift = (0, 1, 2, 1, 0, 1, 2, 3)[(frame + x) % PORTAL_FRAMES]
            draw.ellipse((x, 40 + lift, x + 10, 52), fill=BEACON[0])
            draw.ellipse((x + 2, 43 + lift, x + 8, 51), fill=BEACON[1])
            draw.ellipse((x + 3, 46 + lift, x + 7, 51), fill=BEACON[2])
            draw.point((x + 5, 48 + lift), fill=BEACON[3])
        outline_outside(cell)
        sheet.alpha_composite(cell, (frame * w, 0))
    return sheet


# --- The rooms ------------------------------------------------------------------------

def banner(image, left, top, color, dark):
    draw = ImageDraw.Draw(image)
    rect(draw, left - 2, top - 2, left + 17, top - 1, GOLD)
    rect(draw, left, top, left + 15, top + 36, color)
    rect(draw, left + 13, top, left + 15, top + 36, dark)
    for dx in range(0, 16, 4):
        rect(draw, left + dx, top + 37, left + dx + 1, top + 38, color)
    rect(draw, left + 5, top + 10, left + 10, top + 15, GOLD)
    rect(draw, left + 7, top + 8, left + 8, top + 17, GOLD_LIGHT)


def throne(image):
    """A high-backed chair behind the counter, where the steward stands."""
    draw = ImageDraw.Draw(image)
    rect(draw, 178, 58, 222, FLOOR_Y - 1, BEAM_DARK)
    rect(draw, 182, 62, 218, FLOOR_Y - 1, BANNER)
    rect(draw, 186, 66, 214, FLOOR_Y - 1, BANNER_DARK)
    rect(draw, 174, 54, 226, 58, GOLD)
    for x in (174, 196, 222):
        rect(draw, x, 48, x + 4, 54, GOLD)
        rect(draw, x + 1, 46, x + 3, 47, GOLD_LIGHT)


def castle_room():
    image = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 0, 0, 255))
    paint_ceiling_and_wall(image)
    stone_wall(image)
    paint_floor(image)
    draw = ImageDraw.Draw(image)
    rect(draw, 92, 176, 312, 244, BANNER_DARK)
    rect(draw, 94, 178, 310, 242, BANNER)
    rect(draw, 100, 184, 304, 236, GOLD)
    rect(draw, 102, 186, 302, 234, BANNER)
    door(image)
    throne(image)
    for x in (120, 262, 360, -40, 470):
        banner(image, x, 66, BANNER if x % 3 else BLUE, BANNER_DARK if x % 3 else BLUE_DARK)
    lit_window(image, 78, 72)
    lit_window(image, 300, 72)
    for x in (24, 176, 318, 470, 620, -120):
        lantern(image, x, 40)
    for x in (24, 176, 318, 470, 620, -120):
        glow(image, (x, 46), 54, 0.5)
    glow(image, (200, 150), 170, 0.28)
    darken_edges(image)
    return image


def plans_table():
    """The front of a long table spread with plans, to go in front of the steward."""
    image = Image.new("RGBA", (COUNTER_W, COUNTER_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    top = COUNTER_TOP
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 24), fill=BEAM)
    for x in range(10, COUNTER_W, 22):
        draw.rectangle((x, top + 9, x + 2, top + 24), fill=BEAM_DARK)
        draw.line((x + 1, top + 9, x + 1, top + 24), fill=BEAM_LIGHT)
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 11), fill=BEAM_DARK)
    draw.rectangle((0, top, COUNTER_W - 1, top + 6), fill=BANNER)
    draw.line((0, top + 3, COUNTER_W - 1, top + 3), fill=GOLD)
    draw.rectangle((0, top + 7, COUNTER_W - 1, top + 8), fill=BEAM_DARK)
    draw.rectangle((0, top + 25, COUNTER_W - 1, top + 25), fill=INK)
    draw.rectangle((0, top + 26, COUNTER_W - 1, top + 27), fill=hexc("#2a1c1e", 170))
    # Rolled plans, an open one with a building drawn on it, and a sealed letter.
    draw.polygon([(24, top - 1), (60, top - 1), (56, top - 6), (28, top - 6)], fill=hexc("#f1ecdf"))
    draw.rectangle((36, top - 5, 46, top - 3), outline=BLUE_DARK)
    draw.line((36, top - 5, 41, top - 7), fill=BLUE_DARK)
    draw.line((41, top - 7, 46, top - 5), fill=BLUE_DARK)
    for x in (70, 76):
        draw.rectangle((x, top - 4, x + 18, top - 1), fill=hexc("#e2d4ae"))
        draw.ellipse((x - 1, top - 4, x + 2, top - 1), fill=hexc("#c9b48a"))
    draw.rectangle((150, top - 4, 166, top - 1), fill=hexc("#fff4d4"))
    draw.ellipse((156, top - 4, 160, top), fill=BANNER)
    return image


def bookshelf(image, left, top, width, height):
    draw = ImageDraw.Draw(image)
    rect(draw, left - 2, top - 2, left + width + 1, top + height, BEAM_DARK)
    rect(draw, left, top, left + width - 1, top + height - 1, hexc("#3a2620"))
    for shelf_y in range(top + 14, top + height, 16):
        rect(draw, left, shelf_y, left + width - 1, shelf_y + 1, BEAM_LIGHT)
        x = left + 1
        while x < left + width - 4:
            tall = 8 + (x * 7 + shelf_y) % 5
            thick = 2 + (x + shelf_y) % 3
            rect(draw, x, shelf_y - tall, x + thick - 1, shelf_y - 1, BOOKS[(x * 3 + shelf_y) % len(BOOKS)])
            x += thick + (1 if (x + shelf_y) % 7 else 4)


def chalkboard(image, left, top):
    draw = ImageDraw.Draw(image)
    rect(draw, left - 2, top - 2, left + 61, top + 33, BEAM)
    rect(draw, left, top, left + 59, top + 31, hexc("#2f4a3a"))
    chalk = hexc("#d7e6da")
    ax, ay = at(left + 16, top + 16)
    for step in range(48):
        angle = step / 48 * math.tau
        draw.point((ax + round(10 * math.cos(angle)), ay + round(10 * math.sin(angle))), fill=chalk)
    for star in ((left + 16, top + 6), (left + 26, top + 16), (left + 16, top + 26), (left + 6, top + 16)):
        rect(draw, star[0], star[1], star[0], star[1], GOLD_LIGHT)
    for row in range(4):
        rect(draw, left + 34, top + 6 + row * 6, left + 34 + 16 + (row * 5) % 8, top + 6 + row * 6, chalk)


def globe(image, left, base):
    draw = ImageDraw.Draw(image)
    ax, ay = at(left, base)
    draw.rectangle((ax + 6, ay - 4, ax + 8, ay), fill=BEAM_DARK)
    draw.rectangle((ax + 2, ay, ax + 12, ay + 1), fill=BEAM)
    draw.ellipse((ax, ay - 18, ax + 14, ay - 4), fill=BLUE)
    draw.ellipse((ax + 3, ay - 15, ax + 8, ay - 10), fill=hexc("#3f9a5a"))
    draw.ellipse((ax + 8, ay - 9, ax + 11, ay - 6), fill=hexc("#3f9a5a"))
    draw.arc((ax - 2, ay - 20, ax + 16, ay - 2), 100, 300, fill=GOLD)


def academy_room():
    image = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 0, 0, 255))
    paint_ceiling_and_wall(image)
    paint_floor(image)
    draw = ImageDraw.Draw(image)
    rect(draw, 92, 176, 312, 244, BLUE_DARK)
    rect(draw, 94, 178, 310, 242, BLUE)
    rect(draw, 100, 184, 304, 236, GOLD)
    rect(draw, 102, 186, 302, 234, BLUE)
    bookshelf(image, 112, 64, 188, FLOOR_Y - 64)
    door(image)
    chalkboard(image, 330, 68)
    lit_window(image, 418, 72)
    bookshelf(image, 470, 64, 90, FLOOR_Y - 64)
    bookshelf(image, -110, 64, 100, FLOOR_Y - 64)
    globe(image, 300, FLOOR_Y + 12)
    globe(image, 86, FLOOR_Y + 12)
    for x in (24, 176, 318, 470, 620, -120):
        lantern(image, x, 40)
    for x in (24, 176, 318, 470, 620, -120):
        glow(image, (x, 46), 54, 0.5)
    glow(image, (200, 150), 170, 0.28)
    darken_edges(image)
    return image


def lectern():
    """The front of the teacher's desk, piled with books and a candle."""
    image = Image.new("RGBA", (COUNTER_W, COUNTER_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    top = COUNTER_TOP
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 24), fill=BEAM)
    for x in range(10, COUNTER_W, 22):
        draw.rectangle((x, top + 9, x + 2, top + 24), fill=BEAM_DARK)
        draw.line((x + 1, top + 9, x + 1, top + 24), fill=BEAM_LIGHT)
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 11), fill=BEAM_DARK)
    draw.rectangle((0, top, COUNTER_W - 1, top + 6), fill=BLUE)
    draw.line((0, top + 3, COUNTER_W - 1, top + 3), fill=GOLD)
    draw.rectangle((0, top + 7, COUNTER_W - 1, top + 8), fill=BEAM_DARK)
    draw.rectangle((0, top + 25, COUNTER_W - 1, top + 25), fill=INK)
    draw.rectangle((0, top + 26, COUNTER_W - 1, top + 27), fill=hexc("#2a1c1e", 170))
    for index, color in enumerate(BOOKS):
        draw.rectangle((24, top - 3 - index * 3, 44 - index, top - 1 - index * 3), fill=color)
    draw.polygon([(140, top - 1), (152, top - 4), (164, top - 1)], fill=hexc("#fff4d4"))
    draw.line((152, top - 4, 152, top - 1), fill=PLASTER_DARK)
    draw.rectangle((180, top - 6, 182, top - 1), fill=hexc("#f1ecdf"))
    draw.point((181, top - 8), fill=FIRE[2])
    draw.point((181, top - 7), fill=FIRE[1])
    return image


def letter():
    """A folded letter with the King's red seal, 24 by 24 art pixels, for its tile."""
    image, draw = canvas(24, 24)
    draw.rectangle((2, 5, 21, 19), fill=hexc("#f1ecdf"))
    draw.rectangle((2, 5, 21, 6), fill=PLASTER_DARK)
    draw.line((2, 6, 11, 13), fill=PLASTER_DARK)
    draw.line((21, 6, 12, 13), fill=PLASTER_DARK)
    draw.line((2, 19, 21, 19), fill=PLASTER_DARK)
    draw.ellipse((8, 10, 15, 17), fill=BANNER_DARK)
    draw.ellipse((9, 11, 14, 16), fill=BANNER)
    draw.point((11, 12), fill=GOLD)
    draw.rectangle((10, 17, 11, 21), fill=BANNER)
    draw.rectangle((13, 17, 14, 20), fill=BANNER_DARK)
    outline_outside(image)
    return image


def save_building(image, name):
    x2(image).save(TOWN / f"{name}.png")
    x2(glow_of(image)).save(TOWN / f"{name}_glow.png")


def make_upgrades():
    TOWN.mkdir(exist_ok=True)
    CASTLE.mkdir(exist_ok=True)
    ACADEMY.mkdir(exist_ok=True)
    for level in (1, 2):
        suffix = "" if level == 1 else f"_{level}"
        save_building(storehouse(level), "storehouse" + suffix)
        save_building(smithy(level), "smithy" + suffix)
        save_building(academy(level), "academy" + suffix)
    save_building(lot(), "lot")
    picture, outline = castle_outline()
    x2(picture).save(TOWN / "castle.png")
    x2(outline).save(TOWN / "castle_glow.png")
    sheet = beacon_portal()
    x2(sheet).save(TOWN / "portal_2.png")
    frame = sheet.crop((0, 0, sheet.width // PORTAL_FRAMES, sheet.height))
    x2(glow_of(frame)).save(TOWN / "portal_2_glow.png")
    x2(letter()).save(CASTLE / "letter.png")
    x2(castle_room()).save(CASTLE / "room.png")
    x2(plans_table()).save(CASTLE / "counter.png")
    x2(academy_room()).save(ACADEMY / "room.png")
    x2(lectern()).save(ACADEMY / "counter.png")


if __name__ == "__main__":
    make_upgrades()
