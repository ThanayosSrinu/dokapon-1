"""The Shop, in assets/custom/town/ (the building) and assets/custom/shop/ (the room and
its counter). tools/make_art.py runs this. Everything is original and made only from
code, in the colors of the Puny tiles. Like the Tavern, the room runs far past a 1280 by
720 window, and shop/ShopRoom.gd must agree with the numbers marked for it below."""
from PIL import Image, ImageDraw
from make_art import OUT, hexc, x2
from art_kit import outline_outside
from art_tavern import (BEAM, BEAM_DARK, BEAM_LIGHT, COUNTER_H, COUNTER_TOP, COUNTER_W, FLOOR_Y,
                        GOLD, GOLD_LIGHT, GOODS, INK, PLANK, PLANK_DARK, ROOM_H, ROOM_W, STONE,
                        STONE_DARK, STONE_LIGHT, at, barrel, bottle, darken_edges, door, glow,
                        lantern, lit_window, paint_ceiling_and_wall, paint_floor, rect)
from art_town import (GROUND_SHADOW, PLASTER, PLASTER_DARK, TIMBER, TIMBER_DARK, TOWN, WINDOW,
                      WINDOW_LIGHT, glow_of, post, timber_wall, window)

SHOP = OUT / "shop"
CLOTH, CLOTH_DARK, CLOTH_LIGHT = hexc("#3f9a5a"), hexc("#2a6e45"), hexc("#f1ecdf")
ROOF, ROOF_DARK, ROOF_LIGHT = hexc("#b8483f"), hexc("#7c2f2f"), hexc("#d8705a")
STEEL, STEEL_DARK, STEEL_LIGHT = hexc("#a8aebf"), hexc("#5f6478"), hexc("#e2e6ee")
CRATE, CRATE_DARK = hexc("#b08c5a"), hexc("#7a5a38")


def awning(draw, left, right, top, depth):
    """Green and cream stripes over a shop front, with a scalloped edge."""
    for x in range(left, right + 1):
        stripe = ((x - left) // 5) % 2
        color = CLOTH if stripe == 0 else CLOTH_LIGHT
        draw.line((x, top, x, top + depth), fill=color)
        draw.point((x, top), fill=CLOTH_DARK if stripe == 0 else PLASTER_DARK)
    for x in range(left, right + 1, 5):
        draw.pieslice((x, top + depth - 2, x + 4, top + depth + 2), 0, 180,
                      fill=CLOTH if ((x - left) // 5) % 2 == 0 else CLOTH_LIGHT)
    draw.line((left, top + depth + 3, right, top + depth + 3), fill=hexc("#1b3320", 90))


def sword_sign(draw, x, y):
    """A board with a sword on it, hung from a wooden arm."""
    draw.rectangle((x - 2, y - 3, x + 13, y - 2), fill=TIMBER_DARK)
    draw.line((x + 1, y - 2, x + 1, y), fill=TIMBER_DARK)
    draw.line((x + 10, y - 2, x + 10, y), fill=TIMBER_DARK)
    draw.rectangle((x - 1, y, x + 12, y + 12), fill=TIMBER_DARK)
    draw.rectangle((x, y + 1, x + 11, y + 11), fill=hexc("#a4713f"))
    draw.line((x + 3, y + 9, x + 9, y + 3), fill=STEEL_LIGHT)
    draw.line((x + 4, y + 9, x + 9, y + 4), fill=STEEL)
    draw.line((x + 2, y + 7, x + 5, y + 10), fill=GOLD)
    draw.point((x + 2, y + 10), fill=TIMBER_DARK)


def shop():
    """A narrow timber shop under a red tiled roof, with a striped awning over a stall of
    goods at the front, 80 by 80 art pixels."""
    w, h = 80, 80
    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    base = 75

    # Walls, on a stone footing.
    timber_wall(draw, 8, 34, 71, base - 5)
    draw.rectangle((8, base - 5, 71, base - 1), fill=STONE)
    for x in range(9, 71, 7):
        draw.line((x + (x % 2) * 2, base - 5, x + (x % 2) * 2, base - 1), fill=STONE_DARK)
    draw.line((8, base - 1, 71, base - 1), fill=STONE_DARK)
    for x in (8, 69):
        post(draw, x, 34, base - 5)
    window(draw, 14, 40, 9, 7)
    window(draw, 57, 40, 9, 7)

    # The roof, with a gable end facing the street.
    top, eave = 8, 33
    draw.polygon([(3, eave), (40, top - 4), (76, eave)], fill=ROOF)
    for y in range(top, eave, 4):
        half = (y - top + 4) * 36 // (eave - top + 4)
        draw.line((40 - half, y, 40 + half, y), fill=ROOF_DARK)
        for x in range(40 - half + (y // 4 % 2) * 3, 40 + half, 6):
            draw.point((x, y + 1), fill=ROOF_LIGHT)
    draw.line((3, eave, 76, eave), fill=ROOF_DARK)
    draw.line((3, eave + 1, 76, eave + 1), fill=TIMBER_DARK)
    # A round window in the gable.
    draw.ellipse((35, 16, 45, 26), fill=TIMBER_DARK)
    draw.ellipse((36, 17, 44, 25), fill=WINDOW)
    draw.rectangle((37, 18, 39, 20), fill=WINDOW_LIGHT)
    draw.line((40, 17, 40, 25), fill=TIMBER_DARK)

    # The door, between the windows.
    draw.rectangle((32, 50, 47, base - 1), fill=TIMBER_DARK)
    draw.rectangle((34, 52, 45, base - 2), fill=TIMBER)
    draw.line((39, 52, 39, base - 2), fill=TIMBER_DARK)
    draw.point([(37, 63), (42, 63)], fill=GOLD)

    # The stall: an awning over a table of goods, on both sides of the door.
    awning(draw, 6, 73, 48, 6)
    for left in (9, 50):
        draw.rectangle((left, 64, left + 20, 66), fill=BEAM_LIGHT)
        draw.rectangle((left, 67, left + 20, 70), fill=BEAM)
        draw.line((left, 70, left + 20, 70), fill=BEAM_DARK)
    px = image.load()
    for x, color in ((11, GOODS[0]), (16, GOODS[1]), (52, GOODS[2])):
        bottle(px, x, 64, color)
    # A helmet and a shield on the right-hand table.
    draw.ellipse((58, 57, 65, 64), fill=STEEL)
    draw.rectangle((58, 61, 65, 64), fill=STEEL)
    draw.line((59, 59, 61, 58), fill=STEEL_LIGHT)
    draw.line((58, 63, 65, 63), fill=STEEL_DARK)
    draw.ellipse((22, 56, 29, 64), fill=hexc("#4c6fc0"))
    draw.ellipse((24, 58, 27, 62), fill=GOLD)

    sword_sign(draw, 64, 22)
    for left in (1, 72):
        draw.rectangle((left, base - 9, left + 6, base), fill=CRATE)
        draw.rectangle((left, base - 9, left + 6, base - 8), fill=CRATE_DARK)
        draw.line((left, base - 9, left + 6, base), fill=CRATE_DARK)

    outline_outside(image)
    under = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(under).rectangle((4, base + 1, 76, base + 3), fill=GROUND_SHADOW)
    under.alpha_composite(image)
    return under


def sword_rack(image, left, top):
    """Blades standing in a rack on the wall."""
    draw = ImageDraw.Draw(image)
    rect(draw, left, top + 30, left + 60, top + 33, BEAM_LIGHT)
    rect(draw, left, top + 34, left + 60, top + 35, BEAM_DARK)
    for index, x in enumerate(range(left + 6, left + 58, 10)):
        blade = STEEL if index % 2 == 0 else STEEL_LIGHT
        length = 24 - (index % 3) * 4
        rect(draw, x, top + 30 - length, x + 1, top + 29, blade)
        rect(draw, x + 2, top + 30 - length, x + 2, top + 29, STEEL_DARK)
        rect(draw, x - 2, top + 26, x + 4, top + 27, GOLD if index % 2 else BEAM_DARK)
        rect(draw, x, top + 28, x + 2, top + 33, BEAM_DARK)


def armor_stand(image, left, base):
    """A suit of mail on a wooden stand."""
    draw = ImageDraw.Draw(image)
    rect(draw, left + 9, base - 6, left + 11, base, BEAM_DARK)
    rect(draw, left + 3, base, left + 17, base + 2, BEAM)
    rect(draw, left + 2, base - 34, left + 18, base - 10, STEEL)
    for y in range(base - 32, base - 10, 2):
        for x in range(left + 3 + (y % 4) // 2, left + 18, 2):
            px = at(x, y)
            ImageDraw.Draw(image).point(px, fill=STEEL_DARK)
    rect(draw, left - 1, base - 34, left + 3, base - 28, STEEL_LIGHT)
    rect(draw, left + 17, base - 34, left + 21, base - 28, STEEL_LIGHT)
    rect(draw, left + 5, base - 46, left + 15, base - 36, STEEL_LIGHT)
    rect(draw, left + 7, base - 42, left + 13, base - 40, INK)
    rect(draw, left + 2, base - 12, left + 18, base - 10, GOLD)


def crate(image, left, base, width=22, height=18):
    draw = ImageDraw.Draw(image)
    rect(draw, left, base - height, left + width, base, CRATE)
    rect(draw, left, base - height, left + width, base - height + 2, CRATE_DARK)
    rect(draw, left, base - 2, left + width, base, CRATE_DARK)
    for x in (left, left + width - 2):
        rect(draw, x, base - height, x + 2, base, CRATE_DARK)
    rect(draw, left + 3, base - height // 2, left + width - 3, base - height // 2, CRATE_DARK)


def shelf_wall(image):
    """The wall behind the counter: shelves of potions and herbs."""
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
        for x in range(116, 296, 9):
            if 190 <= x <= 214:
                continue
            spot = at(x, shelf_y)
            bottle(px, spot[0], spot[1], GOODS[(x // 9 + shelf_y) % len(GOODS)])


def room():
    image = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 0, 0, 255))
    paint_ceiling_and_wall(image)
    paint_floor(image)
    shelf_wall(image)
    door(image)
    lit_window(image, 78, 72)
    lit_window(image, 418, 72)
    sword_rack(image, 330, 70)
    sword_rack(image, 480, 70)
    armor_stand(image, 556, FLOOR_Y + 4)
    armor_stand(image, -60, FLOOR_Y + 4)
    crate(image, 306, FLOOR_Y + 8)
    crate(image, 92, FLOOR_Y + 10, 16, 14)
    barrel(image, 400, FLOOR_Y + 10)
    crate(image, 420, FLOOR_Y + 12)
    for x in (24, 176, 318, 470, 620, -120):
        lantern(image, x, 40)
    for x in (24, 176, 318, 470, 620, -120):
        glow(image, (x, 46), 54, 0.5)
    glow(image, (200, 150), 170, 0.28)
    darken_edges(image)
    return image


def counter():
    """The front of the shop counter, to go in front of the keeper. It has the Tavern
    counter's size, so shop/ShopRoom.gd can use the same spots."""
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
    # A pair of scales and a sword laid on the counter.
    draw.line((36, top - 8, 36, top - 1), fill=GOLD)
    draw.line((30, top - 8, 42, top - 8), fill=GOLD)
    draw.rectangle((28, top - 5, 32, top - 4), fill=GOLD_LIGHT)
    draw.rectangle((40, top - 5, 44, top - 4), fill=GOLD_LIGHT)
    draw.rectangle((33, top - 1, 39, top - 1), fill=STONE_DARK)
    draw.line((140, top - 2, 168, top - 2), fill=STEEL_LIGHT)
    draw.line((140, top - 1, 168, top - 1), fill=STEEL_DARK)
    draw.rectangle((136, top - 4, 137, top), fill=GOLD)
    draw.line((131, top - 2, 135, top - 2), fill=BEAM_DARK)
    return image


def make_shop():
    SHOP.mkdir(exist_ok=True)
    building = shop()
    x2(building).save(TOWN / "shop.png")
    x2(glow_of(building)).save(TOWN / "shop_glow.png")
    x2(room()).save(SHOP / "room.png")
    x2(counter()).save(SHOP / "counter.png")


if __name__ == "__main__":
    make_shop()
