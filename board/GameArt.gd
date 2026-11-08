@tool
class_name GameArt
extends RefCounted
## Shared art and drawing helpers. See assets/CREDITS.md for where the art came
## from. Every piece of art is drawn at exactly 2x, so all pixels are the same
## size on screen. Nothing may be drawn at another scale.

const WORLD: Texture2D = preload("res://assets/puny/world/punyworld-overworld-tileset.png")
const SPACES: Texture2D = preload("res://assets/custom/spaces.png")
const ICONS: Texture2D = preload("res://assets/custom/space_icons.png")
## A chest that a monster guards, with fangs and red eyes: drawn by tools/make_art.py.
const GUARDED_CHEST_ICON: Texture2D = preload("res://assets/custom/guarded_chest_icon.png")
## A tough monster's space: a dark red plate in a gold rim, and a horned skull. Drawn by
## tools/make_art.py.
const TOUGH_SPACE: Texture2D = preload("res://assets/custom/tough_space.png")
const TOUGH_ICON: Texture2D = preload("res://assets/custom/tough_icon.png")
## The Portal's gate on the island, one row of frames. Its foot is at the bottom middle.
const PORTAL_GATE: Texture2D = preload("res://assets/custom/portal/board_gate.png")
const DIE: Texture2D = preload("res://assets/custom/die.png")
## Resting faces with the numbers 0 to 10, for a movement die.
const DIE_NUMBERS: Texture2D = preload("res://assets/custom/die_numbers.png")
const FX: Texture2D = preload("res://assets/custom/fx.png")
const CLOUD: Texture2D = preload("res://assets/custom/cloud.png")
const BIRD: Texture2D = preload("res://assets/custom/bird.png")
const FLAG: Texture2D = preload("res://assets/custom/flag.png")
const SHADOW_CROWN: Texture2D = preload("res://assets/custom/shadow_crown.png")
const RIBBON: Texture2D = preload("res://assets/custom/ribbon.png")
const PORTRAIT_FRAME: Texture2D = preload("res://assets/custom/portrait_frame.png")
const BATTLE_BACKDROP: Texture2D = preload("res://assets/custom/battle_backdrop.png")
const SHOP_BACKDROP: Texture2D = preload("res://assets/custom/shop_backdrop.png")
const SHOP_COUNTER: Texture2D = preload("res://assets/custom/shop_counter.png")
const ITEM_ICONS: Texture2D = preload("res://assets/custom/item_icons.png")
const FONT: Font = preload("res://assets/kenney/fonts/KenneyMiniSquare.ttf")

## Pixels of the world per pixel of art.
const PIXEL := 2.0
## Size of a world tile on the sheet.
const TILE_SIZE := 16
## Size of a tile in the world. Spaces are 160 apart, exactly 5 tiles.
const CELL := 32.0
## Width of WORLD in tiles.
const WORLD_COLUMNS := 27

## Size of one frame on a character sheet. There are CHARACTER_COLUMNS frames
## per row and one row per direction, clockwise from facing the viewer.
const CHARACTER_FRAME := 32
const CHARACTER_COLUMNS := 24
const CHARACTER_ROWS := 8
## The point on a frame that touches the ground: between the character's feet.
const CHARACTER_FEET := Vector2(16, 22)

const SPACE_CELL := 40
## The point on a SPACES image at the middle of the space's top face.
const SPACE_CENTER := Vector2(20, 18)
const ICON_CELL := 20
## Size of one picture on ITEM_ICONS. They are already drawn at 2x.
const ITEM_ICON_SIZE := 32

const INK := Color(0.125, 0.086, 0.133)
const GOLD := Color(0.96, 0.82, 0.42)
const PARCHMENT := Color(1.0, 0.95, 0.82)
const NIGHT := Color(0.11, 0.13, 0.27)


## The atlas position of tile number `id` of WORLD.
static func world_coords(id: int) -> Vector2i:
	return Vector2i(id % WORLD_COLUMNS, id / WORLD_COLUMNS)


## A texture holding the head and shoulders of a character.
static func portrait(sheet: Texture2D) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(8, 3, 16, 16)
	return texture


## A texture holding an item's picture.
static func item_icon(item: ItemData) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ITEM_ICONS
	texture.region = Rect2(item.icon * ITEM_ICON_SIZE, 0, ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	return texture


## The picture of a material, from the same sheet as the items.
static func material_icon(material: MaterialData) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ITEM_ICONS
	texture.region = Rect2(material.icon * ITEM_ICON_SIZE, 0, ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	return texture


## A texture holding one frame of a character.
static func character_frame(sheet: Texture2D, column: int, row: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(column * CHARACTER_FRAME, row * CHARACTER_FRAME,
			CHARACTER_FRAME, CHARACTER_FRAME)
	return texture


## Draws text with a dark outline, centered on `center`.
static func draw_centered_text(canvas: CanvasItem, text: String, center: Vector2,
		font_size: int, box_width := 200.0, color := Color.WHITE) -> void:
	if text == "":
		return
	# draw_string() places text by its baseline, so shift down by half the text
	# height to center it vertically.
	var vertical_offset := (FONT.get_ascent(font_size) - FONT.get_descent(font_size)) * 0.5
	var origin := (center + Vector2(-box_width * 0.5, vertical_offset)).round()
	canvas.draw_string_outline(FONT, origin, text, HORIZONTAL_ALIGNMENT_CENTER, box_width,
			font_size, 4, INK)
	canvas.draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_CENTER, box_width,
			font_size, color)


## Draws a small name plate with text in it, centered on `center`.
static func draw_plate(canvas: CanvasItem, text: String, center: Vector2, font_size := 16) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var size := (Vector2(width + 14.0, font_size + 8.0) / 2.0).ceil() * 2.0
	var rect := Rect2((center - size * 0.5).round(), size)
	canvas.draw_rect(rect, INK)
	canvas.draw_rect(rect.grow(-2.0), GOLD)
	canvas.draw_rect(rect.grow(-4.0), NIGHT)
	draw_centered_text(canvas, text, center, font_size, size.x, PARCHMENT)


## Draws an ellipse outline as flat on the ground as the spaces are.
static func draw_ground_ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color,
		width := 4.0, squash := 0.78, from_angle := 0.0, to_angle := TAU) -> void:
	canvas.draw_set_transform(center, 0.0, Vector2(1.0, squash))
	canvas.draw_arc(Vector2.ZERO, radius, from_angle, to_angle, 40, color, width)
	canvas.draw_set_transform(Vector2.ZERO)
