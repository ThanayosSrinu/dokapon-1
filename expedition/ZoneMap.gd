class_name ZoneMap
extends Control
## The whole island small enough to fit in the orders panel, because the larger islands
## do not fit on screen. Each zone wears its color from ZoneOverlay. The gold square is the
## Portal, and the white one is the adventurer. Point at a zone and click to send them.

signal zone_pointed(id: String)
signal zone_clicked(id: String)

const HEIGHT := 132.0
const ROAD := 4.0
const SPACE := 8.0
const MARK := 12.0
const MARK_EDGE := 2.0
## A zone with nothing to say about it is drawn this much darker.
const QUIET := 0.3

## The zone being pointed at, or "".
var lit_zone := "":
	set(value):
		lit_zone = value
		queue_redraw()

var _trip: Expedition
var _overlay: ZoneOverlay
# Space id -> its place on the map's grid, with the top left at (0, 0).
var _points := {}
# Space id -> the id of its zone, or "" for the Portal.
var _zones := {}
# How many grid points wide and tall the island is.
var _extent := Vector2.ONE


func _init(trip: Expedition, overlay: ZoneOverlay) -> void:
	_trip = trip
	_overlay = overlay
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := Rect2()
	for id in trip.map.spaces():
		var point := overlay.spot_of(id) / BoardManager.GRID
		_points[id] = point
		_zones[id] = trip.map.zone_of(id)
		box = Rect2(point, Vector2.ZERO) if box == Rect2() else box.expand(point)
	for id: int in _points:
		_points[id] -= box.position
	_extent = box.size
	mouse_exited.connect(func() -> void: zone_pointed.emit(""))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var zone := _zone_near(event.position)
		if zone != lit_zone:
			zone_pointed.emit(zone)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zone := _zone_near(event.position)
		if zone != "":
			accept_event()
			zone_clicked.emit(zone)


func _draw() -> void:
	for id: int in _points:
		for other in _trip.map.neighbors(id):
			if other > id:
				draw_line(_place(id), _place(other), _color_of(id), ROAD)
	for id: int in _points:
		_square(_place(id), SPACE, _color_of(id))
	_mark(_trip.map.portal, Kit.GOLD)
	_mark(_trip.space_id, Color.WHITE)


# Grid point size on screen, in whole pixels so that rows stay even.
func _cell() -> float:
	return floorf(minf((size.x - MARK) / maxf(_extent.x, 1.0), (size.y - MARK) / maxf(_extent.y, 1.0)))


func _place(id: int) -> Vector2:
	var cell := _cell()
	return (_points[id] * cell + (size - _extent * cell) / 2.0).round()


func _color_of(id: int) -> Color:
	var zone: String = _zones[id]
	if zone == "":
		return Kit.GOLD
	var color := _overlay.color_of(zone)
	return color if zone == lit_zone or zone == _overlay.target_zone else color.darkened(QUIET)


func _square(center: Vector2, width: float, color: Color) -> void:
	draw_rect(Rect2(center, Vector2.ZERO).grow(width / 2.0), color)


func _mark(id: int, color: Color) -> void:
	_square(_place(id), MARK + MARK_EDGE * 2.0, Kit.INK)
	_square(_place(id), MARK, color)


# The zone of the space nearest `point`, if there is one within reach of it.
func _zone_near(point: Vector2) -> String:
	var reach := _cell()
	var found := ""
	for id: int in _points:
		var distance := point.distance_to(_place(id))
		if distance < reach:
			reach = distance
			found = _zones[id]
	return found
