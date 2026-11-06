"""The inside of the Tavern, in assets/custom/tavern/: the room, its counter, the fire
and a portrait of each adventurer. tools/make_art.py runs this. Everything is original
and made only from code, in the colors of the Puny tiles.

The room is drawn far larger than the 1280 by 720 window, so that a wider window shows
more room instead of an edge. Places are given relative to STAGE, the corner of the
part that a 1280 by 720 window shows. tavern/TavernRoom.gd must agree with the numbers
marked for it below."""
import random
from PIL import Image, ImageDraw
from make_art import OUT, hexc, x2
from art_kit import BAYER, outline_outside

TAVERN = OUT / "tavern"
ROOM_W, ROOM_H = 1000, 560
STAGE_X, STAGE_Y = 180, 100
# TavernRoom.gd: FLOOR_Y, in art pixels from the top of the stage.
WALL_TOP, FLOOR_Y = 62, 122
PORTRAIT = 56
FIRE_FRAMES = 4
FIRE_W, FIRE_H = 26, 24
COUNTER_W, COUNTER_H = 208, 38
# Room above the bar for what stands on it.
COUNTER_TOP = 10

SOOT, RAFTER_DARK, RAFTER = hexc("#1b1218"), hexc("#2e1d20"), hexc("#46291f")
BEAM_DARK, BEAM, BEAM_LIGHT = hexc("#3f2822"), hexc("#6e452b"), hexc("#a4713f")
PLASTER_DARK, PLASTER, PLASTER_LIGHT = hexc("#8f7350"), hexc("#b4966a"), hexc("#d1b687")
PLANK_DARK, PLANK, PLANK_LIGHT = hexc("#452d28"), hexc("#5a3b2e"), hexc("#664330")
STONE_DARK, STONE, STONE_LIGHT = hexc("#4d4a50"), hexc("#7a7674"), hexc("#a9a397")
RUG_DARK, RUG, RUG_LIGHT = hexc("#6e2230"), hexc("#a13a3a"), hexc("#d8843f")
GOLD, GOLD_LIGHT = hexc("#f2b23e"), hexc("#fff0a0")
INK = hexc("#20161f")
FIRE = [hexc("#d8423f"), hexc("#f08a2c"), hexc("#f7c23c"), hexc("#fff0a0")]
GOODS = [hexc("#d8423f"), hexc("#4c8fe6"), hexc("#f0c23f"), hexc("#46a65c"), hexc("#8b5fd0")]


def at(x, y):
    """A place on the stage, as a place on the whole room."""
    return x + STAGE_X, y + STAGE_Y


def rect(draw, left, top, right, bottom, color):
    """A rectangle placed on the stage."""
    draw.rectangle((*at(left, top), *at(right, bottom)), fill=color)


def paint_ceiling_and_wall(image):
    px = image.load()
    for y in range(STAGE_Y + WALL_TOP):
        for x in range(ROOM_W):
            local = y - (STAGE_Y + WALL_TOP)
            color = SOOT
            if (x + 8) % 64 < 8:
                color = RAFTER_DARK
            if (y + 12) % 40 < 8:
                color = RAFTER if (y + 12) % 40 < 6 else RAFTER_DARK
            if local >= -6:
                color = BEAM if local < -2 else BEAM_DARK
            px[x, y] = color
    for y in range(STAGE_Y + WALL_TOP, STAGE_Y + FLOOR_Y):
        for x in range(ROOM_W):
            depth = (y - STAGE_Y - WALL_TOP) / (FLOOR_Y - WALL_TOP)
            value = 0.86 - depth * 0.8 + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.35
            px[x, y] = PLASTER_LIGHT if value > 0.72 else PLASTER if value > 0.28 else PLASTER_DARK
    draw = ImageDraw.Draw(image)
    top, bottom = STAGE_Y + WALL_TOP, STAGE_Y + FLOOR_Y
    # A timber frame, with panels of wood below the rail.
    rail = bottom - 20
    draw.rectangle((0, rail, ROOM_W, bottom), fill=BEAM)
    for x in range(0, ROOM_W, 9):
        draw.line((x, rail + 3, x, bottom), fill=BEAM_DARK)
    draw.rectangle((0, rail, ROOM_W, rail + 2), fill=BEAM_LIGHT)
    draw.line((0, rail + 3, ROOM_W, rail + 3), fill=BEAM_DARK)
    draw.rectangle((0, bottom - 2, ROOM_W, bottom - 1), fill=BEAM_DARK)
    for x in range(12, ROOM_W, 72):
        draw.rectangle((x, top, x + 6, bottom - 1), fill=BEAM)
        draw.rectangle((x, top, x + 1, bottom - 1), fill=BEAM_LIGHT)
        draw.line((x + 6, top, x + 6, bottom - 1), fill=BEAM_DARK)


def paint_floor(image):
    px = image.load()
    rng = random.Random(7)
    row_shift = [rng.randrange(0, 44) for _ in range(ROOM_H // 8 + 2)]
    row_tone = [rng.choice((0, 0, 1)) for _ in range(ROOM_H // 8 + 2)]
    for y in range(STAGE_Y + FLOOR_Y, ROOM_H):
        row = (y - STAGE_Y - FLOOR_Y) // 8
        for x in range(ROOM_W):
            local = (x + row_shift[row]) % 44
            board = (x + row_shift[row]) // 44
            color = PLANK if (board + row_tone[row]) % 3 else PLANK_LIGHT
            if y == STAGE_Y + FLOOR_Y + row * 8 + 7 or local == 0:
                color = PLANK_DARK
            elif (x * 7 + y * 13 + board * 5) % 53 == 0:
                color = PLANK_DARK
            px[x, y] = color
    for y in range(STAGE_Y + FLOOR_Y, STAGE_Y + FLOOR_Y + 3):
        for x in range(ROOM_W):
            px[x, y] = PLANK_DARK


def paint_rug(image):
    """The rug the three adventurers stand on, with a fringe at each end."""
    left, top, right, bottom = at(58, 178)[0], at(58, 178)[1], at(330, 238)[0], at(330, 238)[1]
    draw = ImageDraw.Draw(image)
    draw.rectangle((left, bottom + 1, right, bottom + 2), fill=PLANK_DARK)
    draw.rectangle((left, top, right, bottom), fill=RUG)
    draw.rectangle((left + 3, top + 3, right - 3, bottom - 3), fill=RUG_DARK)
    draw.rectangle((left + 5, top + 5, right - 5, bottom - 5), fill=RUG)
    px = image.load()
    for y in range(top + 8, bottom - 7):
        for x in range(left + 8, right - 7):
            if (x - left + (y - top)) % 16 == 0 or (x - left - (y - top)) % 16 == 0:
                px[x, y] = RUG_LIGHT if (x + y) % 2 else RUG_DARK
    for y in range(top, bottom + 1, 2):
        draw.line((left - 3, y, left - 1, y), fill=PLASTER_LIGHT)
        draw.line((right + 1, y, right + 3, y), fill=PLASTER_LIGHT)


def door(image):
    """The way out. Hired adventurers leave by it. TavernRoom.gd: DOOR_FEET."""
    draw = ImageDraw.Draw(image)
    rect(draw, 34, 84, 66, FLOOR_Y - 1, BEAM_DARK)
    rect(draw, 36, 86, 64, FLOOR_Y - 1, BEAM)
    for x in range(36, 64, 7):
        rect(draw, x, 86, x, FLOOR_Y - 1, BEAM_DARK)
    rect(draw, 36, 94, 64, 95, BEAM_DARK)
    rect(draw, 36, 110, 64, 111, BEAM_DARK)
    rect(draw, 58, 102, 60, 104, GOLD)
    rect(draw, 30, 80, 70, 83, BEAM_LIGHT)
    rect(draw, 30, 83, 70, 84, BEAM_DARK)
    rect(draw, 30, FLOOR_Y, 70, FLOOR_Y + 3, STONE)
    rect(draw, 30, FLOOR_Y + 3, 70, FLOOR_Y + 3, STONE_DARK)


def bottle(px, x, base, color):
    for y in range(base - 7, base):
        for dx in range(4):
            px[x + dx, y] = color if y > base - 6 else hexc("#dbe7f0")
    px[x + 1, base - 8] = BEAM_LIGHT
    px[x + 2, base - 8] = BEAM_LIGHT
    px[x, base - 4] = tuple(min(255, c + 70) for c in color[:3]) + (255,)


def mug(px, x, base):
    for y in range(base - 5, base):
        for dx in range(5):
            px[x + dx, y] = BEAM_LIGHT
    for dx in range(5):
        px[x + dx, base - 6] = hexc("#fff6e0")
        px[x + dx, base - 3] = BEAM_DARK
    px[x + 5, base - 4] = BEAM_DARK
    px[x + 5, base - 2] = BEAM_DARK


def shelves(image):
    """The wall behind the counter, in the Shop's way: goods on planks."""
    draw = ImageDraw.Draw(image)
    rect(draw, 112, 66, 300, FLOOR_Y - 1, PLANK)
    for x in range(112, 300, 16):
        rect(draw, x, 66, x, FLOOR_Y - 1, PLANK_DARK)
    rect(draw, 108, 64, 112, FLOOR_Y - 1, BEAM)
    rect(draw, 300, 64, 304, FLOOR_Y - 1, BEAM)
    rect(draw, 108, 62, 304, 65, BEAM_LIGHT)
    px = image.load()
    for shelf_y in (82, 102):
        rect(draw, 112, shelf_y, 300, shelf_y + 1, BEAM_LIGHT)
        rect(draw, 112, shelf_y + 2, 300, shelf_y + 2, BEAM_DARK)
        for x in range(116, 296, 8):
            kind = (x * 3 + shelf_y) % 11
            if x % 40 == 28 or 196 <= x <= 212:
                continue
            spot = at(x, shelf_y)
            if kind < 7:
                bottle(px, spot[0], spot[1], GOODS[kind % len(GOODS)])
            else:
                mug(px, spot[0], spot[1])


def lit_window(image, left, top):
    draw = ImageDraw.Draw(image)
    rect(draw, left - 2, top - 2, left + 23, top + 25, BEAM_DARK)
    rect(draw, left, top, left + 21, top + 23, hexc("#22305e"))
    px = image.load()
    for y in range(top, top + 24):
        for x in range(left, left + 22):
            if (BAYER[y % 4][x % 4] / 16) * 24 > y - top + 8:
                sx, sy = at(x, y)
                px[sx, sy] = hexc("#3b4f94")
    for spot in ((left + 4, top + 5), (left + 16, top + 3), (left + 12, top + 15)):
        rect(draw, spot[0], spot[1], spot[0], spot[1], GOLD_LIGHT)
    rect(draw, left + 10, top, left + 11, top + 23, BEAM_DARK)
    rect(draw, left, top + 11, left + 21, top + 12, BEAM_DARK)
    rect(draw, left - 3, top + 24, left + 24, top + 26, BEAM_LIGHT)


def notice_board(image, left, top):
    draw = ImageDraw.Draw(image)
    rect(draw, left, top, left + 30, top + 20, BEAM_DARK)
    rect(draw, left + 1, top + 1, left + 29, top + 19, hexc("#a4713f"))
    papers = ((3, 3, 9, 10), (13, 2, 10, 8), (5, 12, 8, 6), (17, 11, 9, 7))
    for x, y, w, h in papers:
        rect(draw, left + x, top + y, left + x + w, top + y + h, hexc("#f2e2b8"))
        rect(draw, left + x + 2, top + y + 2, left + x + w - 2, top + y + 2, hexc("#8f7350"))
        rect(draw, left + x + w // 2, top + y, left + x + w // 2, top + y, hexc("#d8423f"))


def fireplace(image):
    """Stone hearth. The flames go on top, from fire.png. TavernRoom.gd: FIRE_SPOT."""
    draw = ImageDraw.Draw(image)
    left, right, top = 324, 382, 72
    rect(draw, left, top, right, FLOOR_Y + 2, STONE_DARK)
    px = image.load()
    for y in range(top, FLOOR_Y + 3):
        row = (y - top) // 6
        for x in range(left, right + 1):
            sx, sy = at(x, y)
            stone = (x + row * 5) % 12
            if (y - top) % 6 == 5 or stone == 0:
                px[sx, sy] = STONE_DARK
            elif (x + y * 3) % 5 == 0:
                px[sx, sy] = STONE_LIGHT
            else:
                px[sx, sy] = STONE
    rect(draw, left - 3, top - 4, right + 3, top - 1, BEAM_LIGHT)
    rect(draw, left - 3, top - 1, right + 3, top, BEAM_DARK)
    rect(draw, left + 13, 90, right - 13, FLOOR_Y + 2, INK)
    rect(draw, left + 15, 92, right - 15, FLOOR_Y + 2, hexc("#3a1a1e"))
    rect(draw, left + 11, 87, right - 11, 89, STONE_LIGHT)
    rect(draw, left + 18, FLOOR_Y - 2, right - 18, FLOOR_Y + 1, BEAM)
    px = image.load()
    bottle(px, *at(334, 68), GOODS[0])
    mug(px, *at(348, 68))
    bottle(px, *at(366, 68), GOODS[3])


def barrel(image, left, base):
    draw = ImageDraw.Draw(image)
    rect(draw, left, base - 19, left + 15, base, BEAM)
    rect(draw, left + 2, base - 21, left + 13, base - 19, BEAM_LIGHT)
    rect(draw, left + 3, base - 20, left + 12, base - 20, BEAM_DARK)
    for x in (left + 4, left + 8, left + 12):
        rect(draw, x, base - 19, x, base, BEAM_DARK)
    for y in (base - 16, base - 5):
        rect(draw, left, y, left + 15, y + 1, STONE_DARK)
    rect(draw, left, base, left + 15, base + 1, BEAM_DARK)


def stool(draw, left, top):
    rect(draw, left, top, left + 11, top + 3, BEAM_LIGHT)
    rect(draw, left, top + 3, left + 11, top + 3, BEAM_DARK)
    rect(draw, left + 1, top + 4, left + 2, top + 9, BEAM_DARK)
    rect(draw, left + 9, top + 4, left + 10, top + 9, BEAM_DARK)


def table(image, left, top, width):
    """A trestle table with mugs and a candle on it."""
    draw = ImageDraw.Draw(image)
    rect(draw, left, top + 19, left + width, top + 20, PLANK_DARK)
    rect(draw, left + 4, top + 12, left + 8, top + 19, BEAM_DARK)
    rect(draw, left + width - 8, top + 12, left + width - 4, top + 19, BEAM_DARK)
    rect(draw, left, top, left + width, top + 8, BEAM_LIGHT)
    for y in (top + 2, top + 5):
        rect(draw, left, y, left + width, y, BEAM)
    rect(draw, left, top + 9, left + width, top + 12, BEAM)
    rect(draw, left, top + 12, left + width, top + 12, BEAM_DARK)
    px = image.load()
    mug(px, *at(left + 6, top + 4))
    mug(px, *at(left + width - 12, top + 7))
    middle = left + width // 2
    rect(draw, middle - 1, top - 2, middle + 1, top + 3, hexc("#fff6e0"))
    rect(draw, middle - 3, top + 3, middle + 3, top + 4, STONE)
    rect(draw, middle, top - 5, middle, top - 3, GOLD)
    rect(draw, middle, top - 4, middle, top - 4, GOLD_LIGHT)


def lantern(image, x, top):
    draw = ImageDraw.Draw(image)
    rect(draw, x, top - 40, x, top, STONE_DARK)
    rect(draw, x - 4, top, x + 4, top + 1, STONE_DARK)
    rect(draw, x - 3, top + 2, x + 3, top + 9, GOLD)
    rect(draw, x - 1, top + 3, x + 1, top + 8, GOLD_LIGHT)
    for offset in (-4, 4):
        rect(draw, x + offset, top + 2, x + offset, top + 9, STONE_DARK)
    rect(draw, x - 4, top + 10, x + 4, top + 11, STONE_DARK)


def glow(image, center, radius, strength=0.5):
    """Warms the picture around `center`, in dithered steps."""
    px = image.load()
    cx, cy = at(*center)
    for y in range(max(0, cy - radius), min(ROOM_H, cy + radius)):
        for x in range(max(0, cx - radius), min(ROOM_W, cx + radius)):
            distance = ((x - cx) ** 2 + ((y - cy) * 1.6) ** 2) ** 0.5 / radius
            if distance >= 1.0:
                continue
            amount = (1.0 - distance) * strength
            if amount < BAYER[y % 4][x % 4] / 16:
                continue
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, r + 26), min(255, g + 15), min(255, b + 2), a)


def darken_edges(image):
    """Dims the room far from the action, so that the eye stays in the middle."""
    px = image.load()
    cx, cy = at(250, 190)
    for y in range(ROOM_H):
        for x in range(ROOM_W):
            distance = (((x - cx) / 420) ** 2 + ((y - cy) / 280) ** 2) ** 0.5
            amount = (distance - 0.7) * 1.1
            if amount <= 0 or amount < BAYER[y % 4][x % 4] / 16:
                continue
            r, g, b, a = px[x, y]
            px[x, y] = (r * 3 // 4, g * 3 // 4, b * 4 // 5, a)


def room():
    image = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 0, 0, 255))
    paint_ceiling_and_wall(image)
    paint_floor(image)
    paint_rug(image)
    shelves(image)
    door(image)
    fireplace(image)
    lit_window(image, 78, 72)
    notice_board(image, -44, 74)
    lit_window(image, 418, 72)
    lit_window(image, 520, 72)
    notice_board(image, 590, 76)
    barrel(image, 306, FLOOR_Y + 6)
    barrel(image, 92, FLOOR_Y + 8)
    barrel(image, 390, FLOOR_Y + 8)
    barrel(image, 407, FLOOR_Y + 10)
    draw = ImageDraw.Draw(image)
    # TavernRoom.gd: PATRONS stand at these stools.
    table(image, 44, 280, 76)
    stool(draw, 22, 288)
    stool(draw, 126, 288)
    table(image, 216, 290, 76)
    stool(draw, 194, 298)
    stool(draw, 298, 298)
    table(image, -130, 200, 76)
    table(image, 470, 200, 76)
    table(image, 560, 300, 76)
    table(image, -110, 310, 76)
    for x in (24, 176, 318, 470, 620, -120):
        lantern(image, x, 40)
    glow(image, (353, 122), 150, 0.75)
    for x in (24, 176, 318, 470, 620, -120):
        glow(image, (x, 46), 54, 0.5)
    glow(image, (194, 215), 190, 0.3)
    glow(image, (82, 278), 60, 0.5)
    glow(image, (254, 288), 60, 0.5)
    darken_edges(image)
    return image


def counter():
    """The front of the bar, to go in front of the barkeeper. TavernRoom.gd: COUNTER_SPOT."""
    image = Image.new("RGBA", (COUNTER_W, COUNTER_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    top = COUNTER_TOP
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 24), fill=BEAM)
    for x in range(10, COUNTER_W, 22):
        draw.rectangle((x, top + 9, x + 2, top + 24), fill=BEAM_DARK)
        draw.line((x + 1, top + 9, x + 1, top + 24), fill=BEAM_LIGHT)
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 11), fill=BEAM_DARK)
    draw.rectangle((0, top, COUNTER_W - 1, top + 6), fill=hexc("#c9965a"))
    draw.line((0, top + 3, COUNTER_W - 1, top + 3), fill=BEAM_LIGHT)
    draw.rectangle((0, top + 7, COUNTER_W - 1, top + 8), fill=BEAM_DARK)
    draw.rectangle((0, top + 25, COUNTER_W - 1, top + 25), fill=INK)
    draw.rectangle((0, top + 26, COUNTER_W - 1, top + 27), fill=hexc("#2a1c1e", 170))
    px = image.load()
    mug(px, 40, top + 2)
    mug(px, 150, top + 2)
    mug(px, 158, top + 2)
    bottle(px, 62, top + 2, GOODS[1])
    return image


def fire():
    """A sheet of flames, drawn again for each frame with a fixed pattern of tongues."""
    sheet = Image.new("RGBA", (FIRE_W * FIRE_FRAMES, FIRE_H), (0, 0, 0, 0))
    px = sheet.load()
    heights = [
        [5, 9, 14, 10, 17, 21, 15, 12, 18, 13, 16, 9, 6],
        [4, 11, 12, 15, 13, 18, 22, 14, 11, 19, 12, 11, 4],
        [6, 8, 16, 12, 19, 15, 18, 20, 13, 14, 17, 8, 5],
        [4, 10, 13, 17, 11, 20, 14, 19, 16, 11, 14, 10, 6],
    ]
    for frame in range(FIRE_FRAMES):
        for column in range(FIRE_W):
            height = heights[frame][column // 2]
            for rise in range(height):
                left = height - rise
                tone = 0 if left <= 2 else 1 if left <= 6 else 2 if left <= 11 else 3
                if (column in (0, 25)) and rise > 5:
                    continue
                px[frame * FIRE_W + column, FIRE_H - 1 - rise] = FIRE[tone]
    return sheet


# --- Portraits --------------------------------------------------------------

SKIN = hexc("#f0b98a"), hexc("#cf8a5e"), hexc("#a65f45")


def portrait_canvas(back_light, back_dark):
    image = Image.new("RGBA", (PORTRAIT, PORTRAIT), back_dark)
    px = image.load()
    for y in range(PORTRAIT):
        for x in range(PORTRAIT):
            distance = ((x - 28) ** 2 + (y - 24) ** 2) ** 0.5 / 34
            if 1.0 - distance > BAYER[y % 4][x % 4] / 16:
                px[x, y] = back_light
    return image


def face(image, left=17, top=21, width=22, height=22, skin=SKIN, eye=hexc("#3a5fb0")):
    """A head with big, friendly eyes, like the characters on the board. Returns its draw."""
    draw = ImageDraw.Draw(image)
    light, mid, dark = skin
    right, bottom = left + width - 1, top + height - 1
    draw.rectangle((left + 7, bottom - 1, right - 7, bottom + 4), fill=mid)
    draw.rectangle((left, top + 2, right, bottom - 4), fill=light)
    draw.rectangle((left + 2, top, right - 2, bottom - 1), fill=light)
    draw.rectangle((left + 1, top + 1, right - 1, bottom - 2), fill=light)
    draw.rectangle((left + 4, bottom - 1, right - 4, bottom), fill=light)
    px = image.load()
    for y in range(top + 1, bottom):
        for x in range(right - 4, right + 1):
            if px[x, y] == light and (x - (right - 4)) * 4 > BAYER[y % 4][x % 4] + 4:
                px[x, y] = mid
    draw.rectangle((left - 1, top + 9, left, top + 13), fill=mid)
    draw.rectangle((right, top + 9, right + 1, top + 13), fill=dark)
    eye_y = top + 9
    for eye_x in (left + 5, right - 7):
        draw.rectangle((eye_x, eye_y, eye_x + 2, eye_y + 4), fill=(255, 255, 255, 255))
        draw.rectangle((eye_x + 1, eye_y + 1, eye_x + 2, eye_y + 4), fill=eye)
        draw.rectangle((eye_x + 2, eye_y + 2, eye_x + 2, eye_y + 3), fill=INK)
        draw.point((eye_x + 1, eye_y + 1), fill=(255, 255, 255, 255))
        draw.line((eye_x - 1, eye_y - 1, eye_x + 3, eye_y - 1), fill=INK)
    draw.line((left + 10, top + 14, left + 11, top + 14), fill=dark)
    return draw


def shoulders(draw, color, dark, trim, width=40):
    left = 28 - width // 2
    draw.rectangle((left + 3, 44, left + width - 4, 55), fill=color)
    draw.rectangle((left, 47, left + width - 1, 55), fill=color)
    draw.rectangle((left + 1, 45, left + width - 2, 47), fill=color)
    draw.rectangle((left + width - 7, 47, left + width - 1, 55), fill=dark)
    draw.rectangle((22, 44, 33, 46), fill=trim)
    draw.rectangle((26, 47, 29, 55), fill=trim)


def bram():
    """A cheerful warrior with a horned helmet and a red beard."""
    image = portrait_canvas(hexc("#c98a4a"), hexc("#a4713f"))
    steel, steel_dark, steel_light = hexc("#a9b0ba"), hexc("#5d6470"), hexc("#dfe4ea")
    red, red_dark = hexc("#d8423f"), hexc("#8e2433")
    draw = ImageDraw.Draw(image)
    shoulders(draw, hexc("#8a5a3a"), hexc("#5e3a2a"), steel_dark, 44)
    for x, y in ((6, 46), (40, 46)):
        draw.rectangle((x, y, x + 9, y + 9), fill=steel)
        draw.rectangle((x, y, x + 9, y + 1), fill=steel_light)
        draw.rectangle((x + 7, y + 2, x + 9, y + 9), fill=steel_dark)
    draw = face(image, 17, 22, 22, 22)
    # The beard hides the chin, and the mouth smiles out of it.
    beard = [(19, 36, 36, 41), (20, 42, 35, 45), (23, 46, 32, 47)]
    for box in beard:
        draw.rectangle(box, fill=hexc("#c85a2c"))
    px = image.load()
    for y in range(36, 48):
        for x in range(19, 37):
            if px[x, y] == hexc("#c85a2c") and (x + y) % 5 == 0:
                px[x, y] = hexc("#8e3a22")
    draw.line((24, 39, 31, 39), fill=INK)
    draw.line((25, 40, 30, 40), fill=hexc("#fff6e0"))
    # The helmet.
    draw.rectangle((16, 16, 39, 29), fill=steel)
    draw.rectangle((18, 12, 37, 16), fill=steel)
    draw.rectangle((21, 10, 34, 12), fill=steel)
    draw.rectangle((16, 28, 39, 29), fill=steel_dark)
    draw.rectangle((21, 11, 25, 13), fill=steel_light)
    draw.rectangle((18, 14, 20, 24), fill=steel_light)
    draw.rectangle((35, 14, 39, 27), fill=steel_dark)
    draw.rectangle((26, 11, 29, 27), fill=steel_dark)
    draw.rectangle((27, 11, 28, 27), fill=steel_light)
    for x in (19, 34):
        draw.rectangle((x, 26, x + 1, 27), fill=steel_light)
    # Its red horns.
    for side in (1, -1):
        for step in range(10):
            out = min(step, 5) - max(0, step - 7)
            thick = 4 if step < 4 else 3 if step < 7 else 2
            x = 13 - out if side == 1 else 42 + out
            left, right = (x - thick + 1, x) if side == 1 else (x, x + thick - 1)
            y = 25 - step * 2
            draw.rectangle((left, y, right, y + 2), fill=red if step < 7 else red_dark)
            draw.rectangle((left, y + 2, right, y + 2), fill=red_dark)
    return image


def wren():
    """A sharp-eyed scout in a green feathered hood."""
    image = portrait_canvas(hexc("#7fa650"), hexc("#5a8240"))
    green, green_dark, green_light = hexc("#7d9a2e"), hexc("#4e6a22"), hexc("#a8c44a")
    draw = ImageDraw.Draw(image)
    shoulders(draw, green, green_dark, hexc("#c9965a"), 40)
    draw.rectangle((26, 47, 29, 55), fill=green_dark)
    draw.rectangle((18, 48, 21, 55), fill=hexc("#6e452b"))
    # Hair falls behind the face.
    draw.rectangle((14, 26, 18, 44), fill=hexc("#7a4a24"))
    draw.rectangle((37, 26, 41, 40), fill=hexc("#5e3a1e"))
    draw = face(image, 17, 22, 22, 21, eye=hexc("#3f8a4a"))
    draw.line((25, 39, 30, 39), fill=INK)
    draw.point((31, 38), fill=INK)
    draw.point((21, 36), fill=hexc("#cf8a5e"))
    draw.point((23, 37), fill=hexc("#cf8a5e"))
    draw.point((33, 36), fill=hexc("#cf8a5e"))
    # The hood.
    draw.rectangle((15, 18, 40, 27), fill=green)
    draw.rectangle((17, 13, 38, 18), fill=green)
    draw.rectangle((21, 9, 34, 13), fill=green)
    draw.rectangle((13, 22, 16, 34), fill=green)
    draw.rectangle((39, 22, 42, 34), fill=green_dark)
    draw.rectangle((34, 13, 40, 27), fill=green_dark)
    draw.rectangle((18, 14, 22, 20), fill=green_light)
    draw.rectangle((22, 10, 27, 12), fill=green_light)
    draw.rectangle((15, 26, 40, 27), fill=green_dark)
    # The brooch and the feather.
    draw.rectangle((25, 20, 30, 25), fill=hexc("#c9965a"))
    draw.rectangle((26, 21, 29, 24), fill=hexc("#fff0a0"))
    for step in range(12):
        draw.rectangle((36 + step // 2 + step // 4, 12 - step, 39 + step // 2 + step // 4, 13 - step),
                       fill=hexc("#e8e4dc"))
    draw.line((36, 13, 44, 2), fill=hexc("#a9a397"))
    return image


def maren():
    """A calm, costly mage under a wide teal hat."""
    image = portrait_canvas(hexc("#5a5fa8"), hexc("#3f3f86"))
    teal, teal_dark, teal_light = hexc("#2a9d8f"), hexc("#176b68"), hexc("#5fd0b8")
    draw = ImageDraw.Draw(image)
    shoulders(draw, teal, teal_dark, GOLD, 40)
    # Long silver hair.
    draw.rectangle((13, 26, 18, 50), fill=hexc("#dfe4ea"))
    draw.rectangle((37, 26, 42, 50), fill=hexc("#a9b0ba"))
    draw = face(image, 17, 23, 22, 21, eye=hexc("#8b5fd0"))
    draw.line((25, 39, 30, 39), fill=INK)
    draw.line((26, 40, 29, 40), fill=hexc("#cf8a5e"))
    # A fringe, then the hat's brim and crown.
    draw.rectangle((18, 24, 37, 27), fill=hexc("#dfe4ea"))
    draw.rectangle((21, 28, 23, 29), fill=hexc("#dfe4ea"))
    draw.rectangle((33, 28, 35, 28), fill=hexc("#a9b0ba"))
    draw.rectangle((5, 21, 50, 24), fill=teal)
    draw.rectangle((8, 19, 47, 21), fill=teal)
    draw.rectangle((5, 24, 50, 24), fill=teal_dark)
    draw.rectangle((38, 19, 50, 23), fill=teal_dark)
    draw.rectangle((16, 13, 39, 19), fill=teal)
    draw.rectangle((19, 7, 36, 13), fill=teal)
    draw.rectangle((23, 2, 32, 7), fill=teal)
    draw.rectangle((33, 7, 39, 18), fill=teal_dark)
    draw.rectangle((20, 8, 23, 15), fill=teal_light)
    draw.rectangle((24, 3, 26, 6), fill=teal_light)
    draw.rectangle((16, 16, 39, 18), fill=GOLD)
    draw.rectangle((25, 13, 30, 19), fill=GOLD)
    draw.rectangle((26, 14, 29, 18), fill=hexc("#a13a3a"))
    draw.rectangle((27, 15, 28, 16), fill=hexc("#ff9d8a"))
    return image


PORTRAITS = {"bram": bram, "wren": wren, "maren": maren}


def finish_portrait(image):
    """Rounds the corners and draws the frame's ink."""
    px = image.load()
    for corner in ((0, 0), (1, 0), (0, 1), (PORTRAIT - 1, 0), (PORTRAIT - 2, 0), (PORTRAIT - 1, 1),
                   (0, PORTRAIT - 1), (0, PORTRAIT - 2), (1, PORTRAIT - 1), (PORTRAIT - 1, PORTRAIT - 1),
                   (PORTRAIT - 2, PORTRAIT - 1), (PORTRAIT - 1, PORTRAIT - 2)):
        px[corner] = (0, 0, 0, 0)
    for index in range(2, PORTRAIT - 2):
        for spot in ((index, 0), (index, PORTRAIT - 1), (0, index), (PORTRAIT - 1, index)):
            px[spot] = INK
    for spot in ((1, 1), (PORTRAIT - 2, 1), (1, PORTRAIT - 2), (PORTRAIT - 2, PORTRAIT - 2)):
        px[spot] = INK
    return image


def make_tavern():
    TAVERN.mkdir(exist_ok=True)
    x2(room()).save(TAVERN / "room.png")
    x2(counter()).save(TAVERN / "counter.png")
    x2(fire()).save(TAVERN / "fire.png")
    for name, draw_one in PORTRAITS.items():
        x2(finish_portrait(draw_one())).save(TAVERN / f"portrait_{name}.png")


if __name__ == "__main__":
    make_tavern()
