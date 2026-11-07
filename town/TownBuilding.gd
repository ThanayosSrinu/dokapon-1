class_name TownBuilding
extends KitButton
## A building you can visit. It behaves like any kit button, so it lifts, sinks, sounds
## and takes focus the same way, but its face is its picture. Pointing at it lights
## a gold outline around it. Its picture follows its level: `<id>` at level 1, `<id>_<n>`
## above that, and an empty lot at 0.

const FOLDER := "res://assets/custom/town/%s.png"
const FRAME_SECONDS := 0.1
## Pictures on a building's sheet, for buildings that are animated.
const FRAMES := {"portal": 8}
const LOT := "lot"

var id := ""
var level := 1

var _art: Texture2D
var _glow: Texture2D
var _frames := 1
var _frame := 0
var _clock := 0.0


func _init(building_id := "tavern", building_level := 1) -> void:
	super()
	id = building_id
	level = building_level
	text = TownData.BUILDINGS[id]["name"]
	var picture := picture_name(id, level)
	_art = load(FOLDER % picture)
	_glow = load(FOLDER % (picture + "_glow"))
	_frames = FRAMES.get(id, 1) if level > 0 else 1
	size = _get_minimum_size()
	set_process(_frames > 1)


## The picture of `building_id` at `building_level`, with no folder or ending.
static func picture_name(building_id: String, building_level: int) -> String:
	if building_level <= 0:
		return LOT
	return building_id if building_level == 1 else "%s_%d" % [building_id, building_level]


func _process(delta: float) -> void:
	_clock += delta
	var frame := int(_clock / FRAME_SECONDS) % _frames
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return _glow.get_size()


func _draw() -> void:
	var look := _chosen_look()
	var spot := Vector2(shown_shake, shown_offset)
	if is_lit():
		draw_texture(_glow, spot)
	var picture := Rect2(Vector2(_frame * size.x, 0.0), size)
	draw_texture_rect_region(_art, Rect2(spot, size), picture)
	if look == Look.FOCUS or PadInput.shows_focus(self):
		draw_style_box(Kit.box("focus", 12.0), Rect2(Vector2.ZERO, size).grow(FOCUS_GROWTH))


## True while it is being pointed at.
func is_lit() -> bool:
	return _chosen_look() != Look.REST
