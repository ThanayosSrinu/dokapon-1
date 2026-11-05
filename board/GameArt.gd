@tool
class_name GameArt
extends RefCounted
## Shared drawing helpers for the Kenney pixel art in res://assets/kenney/.
## A "tile" is one square of a sprite sheet, counted left to right, top to
## bottom, starting at 0. See assets/CREDITS.md for where the art came from.

const TOWN: Texture2D = preload("res://assets/kenney/tiny-town/tilemap_packed.png")
const DUNGEON: Texture2D = preload("res://assets/kenney/tiny-dungeon/tilemap_packed.png")
const UI_LARGE: Texture2D = preload("res://assets/kenney/ui-pack-pixel-adventure/large_tiles.png")
const FONT: Font = preload("res://assets/kenney/fonts/KenneyMiniSquare.ttf")

## Size of a tile in TOWN and DUNGEON, in pixels of the image.
const TILE_SIZE := 16
## Size of a tile in UI_LARGE.
const UI_TILE_SIZE := 32
## Size of a TOWN or DUNGEON tile in the world. 40 fits the map well: spaces
## are 200 apart, so they sit exactly 5 tiles from each other.
const CELL := 40.0


## The part of `sheet` that holds tile number `id`.
static func tile_region(sheet: Texture2D, id: int, tile_size := TILE_SIZE) -> Rect2:
	var columns := sheet.get_width() / tile_size
	return Rect2((id % columns) * tile_size, (id / columns) * tile_size, tile_size, tile_size)


## Draws one tile on `canvas` so it fills `rect`. Call this from _draw().
static func draw_tile(canvas: CanvasItem, sheet: Texture2D, id: int, rect: Rect2,
		tile_size := TILE_SIZE, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(sheet, rect, tile_region(sheet, id, tile_size), tint)


## A texture holding a single tile, for use in Control nodes like TextureRect.
static func tile_texture(sheet: Texture2D, id: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = tile_region(sheet, id)
	return texture


## Draws white text with a dark outline, centered on `center`.
static func draw_centered_text(canvas: CanvasItem, text: String, center: Vector2,
		font_size: int, box_width := 200.0) -> void:
	if text == "":
		return
	# draw_string() places text by its baseline, so shift down by half the text
	# height to center it vertically.
	var vertical_offset := (FONT.get_ascent(font_size) - FONT.get_descent(font_size)) * 0.5
	var origin := center + Vector2(-box_width * 0.5, vertical_offset)
	canvas.draw_string_outline(FONT, origin, text, HORIZONTAL_ALIGNMENT_CENTER, box_width,
			font_size, 6, Color(0.14, 0.09, 0.13))
	canvas.draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_CENTER, box_width,
			font_size, Color.WHITE)
