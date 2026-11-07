"""Puts the island pictures from tools/island_sheet.gd together in one picture.
  python tools/island_sheet.py <folder> <stage id> <first seed> <count> <out.png> [columns]"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

folder, stage, first, count, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
columns = int(sys.argv[6]) if len(sys.argv) > 6 else 4
pictures = [Image.open(Path(folder) / f"{stage}_{seed}.png") for seed in range(first, first + count)]
width, height = pictures[0].size
scale = 0.5
cell = (int(width * scale), int(height * scale))
rows = (len(pictures) + columns - 1) // columns
sheet = Image.new("RGB", (cell[0] * columns, cell[1] * rows), "black")
draw = ImageDraw.Draw(sheet)
for index, picture in enumerate(pictures):
    x, y = index % columns * cell[0], index // columns * cell[1]
    sheet.paste(picture.convert("RGB").resize(cell, Image.LANCZOS), (x, y))
    draw.rectangle([x + 4, y + 4, x + 62, y + 22], fill="black")
    draw.text((x + 8, y + 8), f"seed {first + index}", fill="white")
sheet.save(out)
