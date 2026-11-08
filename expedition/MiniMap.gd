class_name MiniMap
extends Control
## The whole island small enough to fit in a panel, because the larger islands do not fit
## on screen. Each space wears the color of what is on it now. The gold square is the Portal, the
## white one is the adventurer, and a large dark red one is a tough monster. Click a space to look at it on the board.

signal space_clicked(id: int)

const HEIGHT := 184.0
const ROAD := 4.0
const SPACE := 8.0
const MARK := 12.0
const MARK_EDGE := 2.0

var _trip: Expedition
# Space id -> where it stands on the map's grid, with the top left at (0, 0).
var _points := {}
# How many grid points wide and tall the island is.
var _extent := Vector2.ONE


func _init(trip: Expedition, board: BoardManager) -> void:
	_trip = trip
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := Rect2()
	for id in trip.map.spaces():
		var point := board.get_board_node(id).global_position / BoardManager.GRID
		_points[id] = point
		box = Rect2(point, Vector2.ZERO) if box == Rect2() else box.expand(point)
	for id: int in _points:
		_points[id] -= box.position
	_extent = box.size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		space_clicked.emit(_space_near(event.position))


func _draw() -> void:
	for id: int in _points:
		for other in _trip.map.neighbors(id):
			if other > id:
				draw_line(_place(id), _place(other), GameArt.PARCHMENT, ROAD)
	for id: int in _points:
		if _trip.is_tough(id):
			_mark(id, BoardNode.TOUGH_COLOR)
		else:
			_square(_place(id), SPACE, BoardNode.TYPE_INFO[_trip.type_at(id)]["color"])
	_mark(_trip.map.portal, Kit.GOLD)
	_mark(_trip.space_id, Color.WHITE)


# Grid point size on screen, in whole pixels so that rows stay even.
func _cell() -> float:
	return floorf(minf((size.x - MARK) / maxf(_extent.x, 1.0), (size.y - MARK) / maxf(_extent.y, 1.0)))


func _place(id: int) -> Vector2:
	var cell := _cell()
	return (_points[id] * cell + (size - _extent * cell) / 2.0).round()


func _square(center: Vector2, width: float, color: Color) -> void:
	draw_rect(Rect2(center, Vector2.ZERO).grow(width / 2.0), color)


func _mark(id: int, color: Color) -> void:
	_square(_place(id), MARK + MARK_EDGE * 2.0, Kit.INK)
	_square(_place(id), MARK, color)


func _space_near(point: Vector2) -> int:
	var best: int = _trip.space_id
	var reach := INF
	for id: int in _points:
		var distance := point.distance_to(_place(id))
		if distance < reach:
			reach = distance
			best = id
	return best
