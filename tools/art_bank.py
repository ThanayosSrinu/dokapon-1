"""The Bank, in assets/custom/town/ (the building) and assets/custom/bank/ (the room and
its counter). tools/make_art.py runs this. Everything is original and made only from
code, in the colors of the Puny tiles. Like the Tavern, the room runs far past a 1280 by
720 window, and bank/BankRoom.gd must agree with the numbers marked for it below."""
from PIL import Image, ImageDraw
from make_art import OUT, hexc, x2
from art_kit import BAYER, outline_outside
from art_tavern import (BEAM, BEAM_DARK, BEAM_LIGHT, COUNTER_H, COUNTER_TOP, COUNTER_W, FLOOR_Y,
                        GOLD, GOLD_LIGHT, INK, ROOM_H, ROOM_W, STONE, STONE_DARK, STONE_LIGHT,
                        WALL_TOP, at, darken_edges, door, glow, lantern, lit_window,
                        paint_ceiling_and_wall, paint_floor, rect)
from art_town import GROUND_SHADOW, TOWN, WINDOW, WINDOW_LIGHT, glow_of

BANK = OUT / "bank"
# bank/BankRoom.gd: VAULT_FEET sits under this, in art pixels from the top of the stage.
VAULT_LEFT = 322
BRASS, BRASS_DARK = hexc("#d9a53a"), hexc("#8a5a24")
MARBLE, MARBLE_DARK, MARBLE_LIGHT = hexc("#d8d3c6"), hexc("#9a958c"), hexc("#f1ecdf")
SLATE, SLATE_DARK = hexc("#46578a"), hexc("#2f3a63")
RUG, RUG_DARK, RUG_LIGHT = hexc("#2f4f8f"), hexc("#23386a"), hexc("#d9a53a")
SACK, SACK_DARK = hexc("#b08c5a"), hexc("#7a5a38")


def column(draw, left, top, bottom):
    draw.rectangle((left, top, left + 7, bottom), fill=MARBLE)
    draw.rectangle((left, top, left + 1, bottom), fill=MARBLE_LIGHT)
    draw.rectangle((left + 6, top, left + 7, bottom), fill=MARBLE_DARK)
    for x in (left + 3, left + 5):
        draw.line((x, top + 2, x, bottom - 2), fill=MARBLE_DARK)
    draw.rectangle((left - 1, top - 2, left + 8, top), fill=MARBLE_LIGHT)
    draw.rectangle((left - 1, bottom, left + 8, bottom + 2), fill=MARBLE_DARK)


def bank():
    """A small stone hall with columns, a slate roof and a gold coin over the door,
    84 by 80 art pixels."""
    width, height = 84, 80
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    base = height - 4
    draw.ellipse((2, base - 3, width - 3, base + 3), fill=GROUND_SHADOW)
    draw.rectangle((10, 34, width - 11, base - 4), fill=STONE)
    for y in range(36, base - 4, 6):
        draw.line((10, y, width - 11, y), fill=STONE_DARK)
        for x in range(10 + (y // 6 % 2) * 5, width - 11, 10):
            draw.line((x, y, x, y + 5), fill=STONE_DARK)
    draw.rectangle((10, 34, 12, base - 4), fill=STONE_LIGHT)
    # The door, with light behind it.
    draw.rectangle((34, 50, 49, base - 4), fill=BEAM_DARK)
    draw.rectangle((36, 52, 47, base - 4), fill=BEAM)
    draw.line((41, 52, 41, base - 5), fill=BEAM_DARK)
    draw.rectangle((38, 54, 45, 58), fill=WINDOW)
    draw.rectangle((38, 54, 41, 56), fill=WINDOW_LIGHT)
    draw.rectangle((43, 64, 44, 66), fill=GOLD)
    for x in (15, 62):
        draw.rectangle((x, 50, x + 7, 60), fill=INK)
        draw.rectangle((x + 1, 51, x + 6, 59), fill=WINDOW)
        draw.rectangle((x + 1, 51, x + 3, 54), fill=WINDOW_LIGHT)
        draw.line((x + 4, 51, x + 4, 59), fill=INK)
    for x in (6, 25, 52, 71):
        column(draw, x, 38, base - 6)
    # The steps.
    draw.rectangle((3, base - 5, width - 4, base - 3), fill=MARBLE)
    draw.rectangle((3, base - 5, width - 4, base - 5), fill=MARBLE_LIGHT)
    draw.rectangle((1, base - 2, width - 2, base), fill=MARBLE_DARK)
    draw.rectangle((1, base - 2, width - 2, base - 2), fill=MARBLE)
    # The roof, then the front of it with the coin.
    draw.rectangle((3, 30, width - 4, 36), fill=MARBLE)
    draw.line((3, 30, width - 4, 30), fill=MARBLE_LIGHT)
    draw.line((3, 36, width - 4, 36), fill=MARBLE_DARK)
    draw.polygon([(2, 29), (41, 4), (42, 4), (width - 3, 29)], fill=SLATE)
    for y in range(9, 29, 4):
        half = (y - 4) * 39 // 25
        draw.line((41 - half, y, 42 + half, y), fill=SLATE_DARK)
    draw.polygon([(14, 29), (41, 11), (42, 11), (width - 15, 29)], fill=MARBLE)
    draw.line((14, 29, width - 15, 29), fill=MARBLE_DARK)
    draw.ellipse((35, 15, 48, 28), fill=BRASS_DARK)
    draw.ellipse((36, 16, 47, 27), fill=GOLD)
    draw.ellipse((38, 18, 45, 25), fill=GOLD_LIGHT)
    draw.rectangle((41, 19, 42, 24), fill=BRASS_DARK)
    outline_outside(image)
    return image


def stone_wall(image):
    """Cool stone blocks over the Tavern's plaster, because a Bank should feel safe."""
    px = image.load()
    for local_y in range(WALL_TOP, FLOOR_Y - 20):
        row = local_y // 12
        for x in range(ROOM_W):
            ax, ay = at(0, local_y)
            local_x = x - ax
            block = (local_x + row * 13) // 26
            mortar = local_y % 12 == 0 or (local_x + row * 13) % 26 == 0
            value = 0.55 - (local_y - WALL_TOP) / 120 + (BAYER[ay % 4][x % 4] / 16 - 0.5) * 0.3
            color = hexc("#8d8a92") if value > 0.3 else hexc("#77757f")
            if block % 5 == 0:
                color = hexc("#7f7d88")
            px[x, ay] = hexc("#55535e") if mortar else color


def vault(image):
    """A round vault door in the wall, shut. bank/BankRoom.gd: VAULT_SPOT."""
    draw = ImageDraw.Draw(image)
    cx, cy, radius = VAULT_LEFT + 30, 94, 27
    ax, ay = at(cx, cy)
    rect(draw, cx - 34, cy - 31, cx + 34, FLOOR_Y - 1, STONE_DARK)
    rect(draw, cx - 32, cy - 29, cx + 32, FLOOR_Y - 1, STONE)
    draw.ellipse((ax - radius, ay - radius, ax + radius, ay + radius), fill=BRASS_DARK)
    draw.ellipse((ax - radius + 2, ay - radius + 2, ax + radius - 2, ay + radius - 2), fill=BRASS)
    draw.ellipse((ax - radius + 7, ay - radius + 7, ax + radius - 7, ay + radius - 7), fill=BRASS_DARK)
    draw.ellipse((ax - radius + 9, ay - radius + 9, ax + radius - 9, ay + radius - 9), fill=hexc("#b98a30"))
    for dx, dy in ((0, -18), (0, 18), (-18, 0), (18, 0), (-13, -13), (13, -13), (-13, 13), (13, 13)):
        draw.rectangle((ax + dx - 1, ay + dy - 1, ax + dx + 1, ay + dy + 1), fill=GOLD_LIGHT)
    draw.rectangle((ax - 12, ay - 1, ax + 12, ay + 1), fill=INK)
    draw.rectangle((ax - 1, ay - 12, ax + 1, ay + 12), fill=INK)
    draw.ellipse((ax - 4, ay - 4, ax + 4, ay + 4), fill=GOLD_LIGHT)


def sack(image, left, base):
    """A sack of coins on the floor."""
    draw = ImageDraw.Draw(image)
    ax, ay = at(left, base)
    draw.ellipse((ax, ay - 12, ax + 15, ay), fill=SACK_DARK)
    draw.ellipse((ax + 1, ay - 12, ax + 13, ay - 2), fill=SACK)
    draw.rectangle((ax + 5, ay - 15, ax + 10, ay - 12), fill=SACK_DARK)
    draw.rectangle((ax + 6, ay - 8, ax + 9, ay - 5), fill=GOLD)


def rug(image):
    """Where the banker's visitors stand."""
    draw = ImageDraw.Draw(image)
    rect(draw, 72, 176, 332, 244, RUG_DARK)
    rect(draw, 74, 178, 330, 242, RUG)
    rect(draw, 80, 184, 324, 236, RUG_LIGHT)
    rect(draw, 82, 186, 322, 234, RUG)


def room():
    image = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 0, 0, 255))
    paint_ceiling_and_wall(image)
    stone_wall(image)
    paint_floor(image)
    rug(image)
    door(image)
    vault(image)
    lit_window(image, 78, 72)
    lit_window(image, 280, 72)
    sack(image, 300, FLOOR_Y + 12)
    sack(image, 312, FLOOR_Y + 15)
    sack(image, 392, FLOOR_Y + 12)
    for x in (24, 176, 318, 470, 620, -120):
        lantern(image, x, 40)
    for x in (24, 176, 318, 470, 620, -120):
        glow(image, (x, 46), 54, 0.5)
    glow(image, (200, 150), 170, 0.28)
    darken_edges(image)
    return image


def counter():
    """The front of the desk with a brass grille, to go in front of the banker. It has
    the Tavern counter's size, so bank/BankRoom.gd can use the same spots."""
    image = Image.new("RGBA", (COUNTER_W, COUNTER_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    top = COUNTER_TOP
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 24), fill=BEAM)
    for x in range(10, COUNTER_W, 22):
        draw.rectangle((x, top + 9, x + 2, top + 24), fill=BEAM_DARK)
        draw.line((x + 1, top + 9, x + 1, top + 24), fill=BEAM_LIGHT)
    draw.rectangle((0, top + 8, COUNTER_W - 1, top + 11), fill=BEAM_DARK)
    draw.rectangle((0, top, COUNTER_W - 1, top + 6), fill=MARBLE)
    draw.line((0, top + 1, COUNTER_W - 1, top + 1), fill=MARBLE_LIGHT)
    draw.rectangle((0, top + 7, COUNTER_W - 1, top + 8), fill=BEAM_DARK)
    draw.rectangle((0, top + 25, COUNTER_W - 1, top + 25), fill=INK)
    draw.rectangle((0, top + 26, COUNTER_W - 1, top + 27), fill=hexc("#2a1c1e", 170))
    # A stack of coins and a ledger on the desk.
    draw.rectangle((40, top - 4, 47, top - 1), fill=GOLD)
    draw.rectangle((40, top - 3, 47, top - 3), fill=BRASS_DARK)
    draw.rectangle((150, top - 3, 164, top - 1), fill=hexc("#7c2f2f"))
    draw.rectangle((150, top - 3, 164, top - 3), fill=MARBLE_LIGHT)
    return image


def make_bank():
    BANK.mkdir(exist_ok=True)
    hall = bank()
    x2(hall).save(TOWN / "bank.png")
    x2(glow_of(hall)).save(TOWN / "bank_glow.png")
    x2(room()).save(BANK / "room.png")
    x2(counter()).save(BANK / "counter.png")


if __name__ == "__main__":
    make_bank()
