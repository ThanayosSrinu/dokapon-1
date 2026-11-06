class_name Kit
extends RefCounted
## What every part of the UI kit shares: its text sizes, colors, icons and framed art.
## The font's pixels are 2 screen pixels at size 16, so only sizes 16 and 32 keep the
## game's exact 2x look. See assets/CREDITS.md for where the art comes from.

const SMALL_TEXT := 16
const BIG_TEXT := 32
## The size of one art pixel on screen. Anything that moves, moves in these.
const STEP := 2.0
const ICON_SIZE := 32.0
## Every screen's way back sits here (rule U5).
const BACK_POSITION := Vector2(24, 24)

const CREAM := Color(1.0, 0.95, 0.82)
const GOLD := Color(1.0, 0.85, 0.42)
const INK := Color(0.125, 0.086, 0.133)
const SOFT_INK := Color(0.33, 0.23, 0.2)
const MUTED := Color(0.78, 0.76, 0.8)
const DIM := Color(0.06, 0.05, 0.12, 0.62)
const HEALTH := Color(0.36, 0.82, 0.38)
const DANGER := Color(0.91, 0.27, 0.25)
const SUPPLY := Color(0.95, 0.68, 0.24)
const MAGIC := Color(0.3, 0.64, 0.95)

const ICONS: Texture2D = preload("res://assets/custom/kit/icons.png")
## In the order they sit on ICONS. tools/art_kit.py draws them.
const ICON_NAMES: Array[String] = ["play", "back", "book", "gear", "door", "coin", "food", "heart",
		"sword", "boot", "wood", "ore", "herb", "die", "bag", "lock", "check", "star", "music", "sound", "cross"]
const FOLDER := "res://assets/custom/kit/%s.png"

static var _icons := {}
static var _boxes := {}


## The picture called `icon_name`.
static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var index := ICON_NAMES.find(icon_name)
		if index < 0:
			push_error("Kit: no icon called '%s'." % icon_name)
			index = 0
		var atlas := AtlasTexture.new()
		atlas.atlas = ICONS
		atlas.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
		_icons[icon_name] = atlas
	return _icons[icon_name]


## The framed art in file `art`. Its edges are `margin` screen pixels wide, and they
## tile instead of stretching, so that every pixel stays the same size.
static func box(art: String, margin: float) -> StyleBoxTexture:
	if not _boxes.has(art):
		var style := StyleBoxTexture.new()
		style.texture = load(FOLDER % art)
		style.set_texture_margin_all(margin)
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		_boxes[art] = style
	return _boxes[art]


## `value` moved onto the art's pixel grid.
static func snap(value: float) -> float:
	return snappedf(value, STEP)


static func snap_point(point: Vector2) -> Vector2:
	return Vector2(snap(point.x), snap(point.y))


## Draws the focus ring around `control`, if it has focus (rule U9).
static func draw_focus(control: Control) -> void:
	if control.has_focus():
		control.draw_style_box(box("focus", 12.0), Rect2(Vector2.ZERO, control.size).grow(4.0))


## Lets go of the shared art, so that nothing is left over when the game closes.
static func forget() -> void:
	_icons.clear()
	_boxes.clear()


## An image holding icon `icon_name`, at its exact size.
static func picture(icon_name: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = icon(icon_name)
	image.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


## A label that wraps at `width`. Pass a theme variation for another style of text.
static func text(words: String, width := 0.0, style := &"") -> Label:
	var label := Label.new()
	label.text = words
	label.theme_type_variation = style
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width
	return label
