class_name TownBuilding
extends KitButton
## A building you can visit. It behaves like any kit button, so it lifts, sinks, sounds
## and takes focus the same way, but its face is its picture. Pointing at it lights
## a gold outline around it.

const FOLDER := "res://assets/custom/town/%s.png"
const FRAME_SECONDS := 0.1
## Pictures on a building's sheet, for buildings that are animated.
const FRAMES := {"portal": 8}

var id := ""

var _art: Texture2D
var _glow: Texture2D
var _frames := 1
var _frame := 0
var _clock := 0.0


func _init(building_id := "tavern") -> void:
	super()
	id = building_id
	text = TownData.BUILDINGS[id]["name"]
	_art = load(FOLDER % id)
	_glow = load(FOLDER % (id + "_glow"))
	_frames = FRAMES.get(id, 1)
	size = _get_minimum_size()
	set_process(_frames > 1)


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
	if look == Look.FOCUS or has_focus():
		draw_style_box(Kit.box("focus", 12.0), Rect2(Vector2.ZERO, size).grow(FOCUS_GROWTH))


## True while it is being pointed at.
func is_lit() -> bool:
	return _chosen_look() != Look.REST
