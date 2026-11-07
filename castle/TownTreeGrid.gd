class_name TownTreeGrid
extends Control
## The town tree at the Castle (E22), drawn on the paper of the plans panel: the Castle in
## the middle (a gold star), Logistics going up, Training left and Safety right. Small spaces are dots,
## notables squares and keystones rings, each with a picture. Pointing at a space or moving
## onto it with keys picks it, and the Castle's card shows it. A click on the space picked,
## or Accept, asks to build it.

## Space `id` was pointed at or moved onto.
signal picked(id: String)
## Building space `id` was asked for.
signal chosen(id: String)

const GRID_SIZE := Vector2(640, 318)
const CELL := 33.0
const HUB := Vector2(320, 232)
const HUB_RADIUS := 18.0
const DOT := 7.0
const NOTABLE_HALF := 17.0
const KEYSTONE_RADIUS := 19.0
## Darker than the branch colors of a hero's tree, so they read on paper.
const BRANCH_COLORS: Array[Color] = [Color(0.72, 0.45, 0.16), Color(0.27, 0.45, 0.78), Color(0.3, 0.6, 0.3)]
const EMPTY := Color(0.86, 0.79, 0.64)
const LINE := Color(0.33, 0.23, 0.2, 0.3)
const RING := Color(0.55, 0.45, 0.38)
const OPEN := Color(0.85, 0.55, 0.05)

## Space id -> the control that takes focus and clicks for it.
var spots := {}
## The space the card shows.
var selected := ""

var _built: Array[String] = []
var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = GRID_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	for id in TownTree.ids():
		_add_spot(id)


## Draws the tree with `built` built, and `id` picked.
func show_tree(built: Array[String], id: String) -> void:
	_built = built
	selected = id
	queue_redraw()


static func spot_center(id: String) -> Vector2:
	var cell: Vector2i = TownTree.space(id)["cell"]
	return HUB + Vector2(cell) * CELL


static func reach(size: TownTree.Size) -> float:
	match size:
		TownTree.Size.NOTABLE:
			return NOTABLE_HALF
		TownTree.Size.KEYSTONE:
			return KEYSTONE_RADIUS
	return DOT


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pulse = fmod(_pulse + delta, 1.2)
		queue_redraw()


func _draw() -> void:
	for id: String in spots:
		var from := spot_center(id)
		var color := BRANCH_COLORS[TownTree.branch_of(id)]
		if TownTree.is_root(id):
			var lit := _built.has(id)
			draw_line(HUB, from, color if lit else LINE, 4.0 if lit else 2.0)
		for other: String in TownTree.links(id):
			if other > id:
				var both := _built.has(id) and _built.has(other)
				draw_line(from, spot_center(other), color if both else LINE, 4.0 if both else 2.0)
	draw_circle(HUB, HUB_RADIUS, Kit.INK)
	draw_arc(HUB, HUB_RADIUS, 0.0, TAU, 32, Kit.GOLD, 2.0)
	var hub := Kit.icon("star")
	draw_texture(hub, (HUB - hub.get_size() / 2.0).round())
	for id: String in spots:
		_draw_space(id)


func _draw_space(id: String) -> void:
	var found := TownTree.space(id)
	var center := spot_center(id)
	var size: TownTree.Size = found["size"]
	var color := BRANCH_COLORS[TownTree.branch_of(id)]
	var lit := _built.has(id)
	var open := not lit and TownTree.can_take(_built, id)
	var ring := Kit.INK if lit else (OPEN if open else RING)
	var fill := color if lit else EMPTY
	match size:
		TownTree.Size.SMALL:
			draw_circle(center, DOT, fill)
			draw_arc(center, DOT, 0.0, TAU, 20, ring, 2.0)
		TownTree.Size.NOTABLE:
			var box := Rect2(center - Vector2(NOTABLE_HALF, NOTABLE_HALF), Vector2(NOTABLE_HALF, NOTABLE_HALF) * 2.0)
			draw_rect(box, fill)
			draw_rect(box, ring, false, 2.0)
		TownTree.Size.KEYSTONE:
			draw_circle(center, KEYSTONE_RADIUS, fill)
			draw_arc(center, KEYSTONE_RADIUS, 0.0, TAU, 32, ring, 2.0)
			draw_arc(center, KEYSTONE_RADIUS - 4.0, 0.0, TAU, 32, ring, 1.0)
	if size != TownTree.Size.SMALL:
		var picture := Kit.icon(found["icon"])
		draw_texture(picture, (center - picture.get_size() / 2.0).round(), Color.WHITE if lit or open else Color(1, 1, 1, 0.5))
	var edge := reach(size)
	if open:
		var grow := 3.0 + 2.0 * sin(_pulse / 1.2 * TAU)
		draw_arc(center, edge + grow, 0.0, TAU, 28, Color(OPEN, 0.7), 1.0)
	if id == selected:
		draw_arc(center, edge + 6.0, 0.0, TAU, 32, Kit.INK, 2.0)


func _add_spot(id: String) -> void:
	var half: float = reach(TownTree.space(id)["size"]) + 3.0
	var spot := Control.new()
	spot.name = id
	spot.size = Vector2(half, half) * 2.0
	spot.position = spot_center(id) - Vector2(half, half)
	spot.focus_mode = Control.FOCUS_ALL
	spot.mouse_filter = Control.MOUSE_FILTER_STOP
	spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	spot.draw.connect(Kit.draw_focus.bind(spot))
	spot.focus_entered.connect(func() -> void:
			spot.queue_redraw()
			picked.emit(id))
	spot.focus_exited.connect(spot.queue_redraw)
	spot.mouse_entered.connect(func() -> void: picked.emit(id))
	spot.gui_input.connect(_on_spot_input.bind(id))
	add_child(spot)
	spots[id] = spot


func _on_spot_input(event: InputEvent, id: String) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if clicked and id != selected:
		picked.emit(id)
		accept_event()
	elif clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		chosen.emit(id)
