class_name ZoneOverlay
extends Node2D
## The zones of an island, painted over it while the lord gives orders, each with its
## name. Point at a zone to light it, and click it to send them there. With the orders
## closed, only the zone they were sent to stays faintly marked.
##
## Each zone is a CanvasGroup, so its squares blend as one flat shape and overlaps never
## show darker.

## The mouse moved onto a zone. "" means off them all.
signal zone_pointed(id: String)
signal zone_clicked(id: String)

## One for each zone, in map order. Six is the most a map has today, and more repeat.
const COLORS: Array[Color] = [Color("e8b84a"), Color("5fb7e0"), Color("e0735f"),
		Color("8fd16a"), Color("c58be0"), Color("f0efe2")]
## How wide a zone is painted around its spaces and roads.
const WIDTH := 124.0
const SEEN := 0.3
const LIT := 0.55
const FAINT := 0.2
## The target breathes this far either side of LIT, to stand out from the rest.
const PULSE := 0.14
const PULSE_SPEED := 4.0
const MOVE_SECONDS := 0.15
## World pixels per screen pixel with the whole island in view, so the name stays sharp.
const NAME_SCALE := 2.0
const NAME_OUTLINE := 6

## True while the orders are open.
var open := false:
	set(value):
		open = value
		if not open:
			lit_zone = ""
		_aim()
## The zone being pointed at, or "".
var lit_zone := "":
	set(value):
		lit_zone = value
		_aim()
## The zone they were sent to, or "".
var target_zone := "":
	set(value):
		target_zone = value
		_aim()

# Zone id -> its CanvasGroup.
var _groups := {}
# Zone id -> the squares that make up its shape.
var _shapes := {}
# Zone id -> the label with its name.
var _names := {}
# Zone id -> the color it is painted.
var _colors := {}
# Zone id -> how strongly it should show.
var _aims := {}
# Zone id -> where its name sits.
var _middles := {}
var _board: BoardManager


## One flat piece of a zone.
class ZoneShape:
	extends Node2D
	var rects: Array[Rect2] = []
	var color := Color.WHITE

	func _draw() -> void:
		for rect in rects:
			draw_rect(rect, color)


## Paints the zones of `map` over the spaces of `board`.
func _init(map: IslandMap, board: BoardManager) -> void:
	_board = board
	for index in map.zones.size():
		var zone := map.zones[index]
		var id: String = zone["id"]
		_colors[id] = COLORS[index % COLORS.size()]
		_shapes[id] = _rects_of(zone, map, board)
		_aims[id] = 0.0
		_add_group(id)
		_add_name(zone, board)


func color_of(id: String) -> Color:
	return _colors[id]


## Where space `id` is on the island.
func spot_of(id: int) -> Vector2:
	return _board.get_board_node(id).global_position


## Where zone `id` is on the island.
func middle_of(id: String) -> Vector2:
	return _middles[id]


## How strongly zone `id` is meant to show, from 0 to 1.
func strength_of(id: String) -> float:
	return _aims[id]


func _process(_delta: float) -> void:
	if target_zone == "" or not open:
		return
	# Real time, so it still breathes at x0.
	var clock := Time.get_ticks_msec() / 1000.0
	_groups[target_zone].self_modulate.a = LIT + sin(clock * PULSE_SPEED) * PULSE


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event is InputEventMouseMotion:
		var zone := _zone_at(get_global_mouse_position())
		if zone != lit_zone:
			zone_pointed.emit(zone)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zone := _zone_at(get_global_mouse_position())
		if zone != "":
			get_viewport().set_input_as_handled()
			zone_clicked.emit(zone)


func _zone_at(point: Vector2) -> String:
	for id: String in _shapes:
		for rect: Rect2 in _shapes[id]:
			if rect.has_point(point):
				return id
	return ""


func _rects_of(zone: Dictionary, map: IslandMap, board: BoardManager) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half := WIDTH / 2.0
	var ids: Array[int] = zone["spaces"]
	for id in ids:
		var spot := board.get_board_node(id).global_position
		rects.append(Rect2(spot, Vector2.ZERO).grow(half))
		for other in map.neighbors(id):
			if ids.has(other):
				var far_end := board.get_board_node(other).global_position
				rects.append(Rect2(spot, Vector2.ZERO).expand(far_end).grow(half))
	return rects


func _add_group(id: String) -> void:
	var group := CanvasGroup.new()
	group.self_modulate.a = 0.0
	var shape := ZoneShape.new()
	shape.rects = _shapes[id]
	shape.color = _colors[id]
	group.add_child(shape)
	add_child(group)
	_groups[id] = group


func _add_name(zone: Dictionary, board: BoardManager) -> void:
	var label := Kit.text(zone["name"], 0.0, &"Heading")
	label.scale = Vector2.ONE * NAME_SCALE
	label.hide()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Kit.INK)
	label.add_theme_constant_override("outline_size", NAME_OUTLINE)
	label.z_index = 1
	add_child(label)
	label.reset_size()
	_middles[zone["id"]] = _middle_of(zone, board)
	label.position = (_middles[zone["id"]] - label.get_combined_minimum_size() * NAME_SCALE / 2.0).round()
	_names[zone["id"]] = label


# The space nearest the middle of the zone, because the middle itself may be sea.
func _middle_of(zone: Dictionary, board: BoardManager) -> Vector2:
	var total := Vector2.ZERO
	var ids: Array[int] = zone["spaces"]
	for id in ids:
		total += board.get_board_node(id).global_position
	var middle := total / ids.size()
	var best := board.get_board_node(ids[0]).global_position
	for id in ids:
		var spot := board.get_board_node(id).global_position
		if spot.distance_squared_to(middle) < best.distance_squared_to(middle):
			best = spot
	return best


func _aim() -> void:
	if not is_inside_tree():
		return
	for id: String in _groups:
		var strength := SEEN if open else 0.0
		if open and id == lit_zone:
			strength = LIT
		elif id == target_zone:
			strength = LIT if open else FAINT
		_aims[id] = strength
		_names[id].visible = open
		var tween := create_tween().set_ignore_time_scale(true)
		tween.tween_property(_groups[id], "self_modulate:a", strength, MOVE_SECONDS)
