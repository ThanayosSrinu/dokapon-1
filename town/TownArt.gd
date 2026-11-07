class_name TownArt
extends BoardArt
## Plans the town: its roads, river, keep, cottages, fields and the forest around it.
## It paints with everything BoardArt has, so it looks like the island and works with
## WorldAmbience. Only the plan differs, because a town has no board spaces under it.
## Positions are in vertices, 32 px apart, with the middle of the screen at (0, 0).
## At 1280x720, the screen shows x from -20 to 20 and y from -11 to 11.

## Wider than any screen, so that a wide window shows more town, never an edge.
const AREA := Rect2i(-40, -26, 80, 52)

## Where each building stands: the middle of its bottom edge, in pixels.
const BUILDING_FEET := {"tavern": Vector2(-368, 86), "bank": Vector2(-112, 60), "portal": Vector2(400, 172),
		"shop": Vector2(208, 86)}
## The room each building takes up on the ground, in vertices.
const BUILDING_LOTS := {"tavern": Rect2i(-15, -3, 7, 6), "bank": Rect2i(-7, -3, 6, 5),
		"portal": Rect2i(9, -1, 8, 7), "shop": Rect2i(4, -3, 5, 6)}
## Where smoke leaves the Tavern's chimney, relative to its feet.
const TAVERN_SMOKE := Vector2(52, -158)

## The castle's space, as BoardArt's castle wants it. Its gate opens at x = 0.
const KEEP_SPOT := Vector2i(6, -2)
const STREET_Y := 3
const STREET_WEST := -22
const STREET_EAST := 11
const AVENUE_X := 0
const AVENUE_NORTH := -4
const AVENUE_SOUTH := 26
const SQUARE_SIZE := 3
## Each is [first, last] corner of a stretch of river, west to east.
const RIVER_PARTS := [[Vector2i(-41, 8), Vector2i(-14, 9)], [Vector2i(-14, 8), Vector2i(-13, 10)],
		[Vector2i(-13, 9), Vector2i(12, 10)], [Vector2i(12, 8), Vector2i(13, 10)],
		[Vector2i(13, 8), Vector2i(41, 9)]]

const WELL_CELL := Vector2i(3, 0)
const COTTAGES: Array[Vector2i] = [Vector2i(-13, 6), Vector2i(-11, 6), Vector2i(-9, 6), Vector2i(-7, 6), Vector2i(-5, 6),
		Vector2i(4, 6), Vector2i(6, 6)]
const STALLS: Array[Vector2i] = [Vector2i(-3, 5), Vector2i(-2, 5), Vector2i(3, 5)]
const STALL_TILES: Array[Vector2i] = [Vector2i(7, 31), Vector2i(8, 31), Vector2i(9, 31)]
const FIELDS: Array[Rect2i] = [Rect2i(-13, -8, 6, 3), Rect2i(8, -8, 6, 3)]

## How far from the middle the forest may begin.
const FOREST_X := 18
const FOREST_NORTH := 10
const FOREST_SOUTH := 12
const FOREST_FADE := 5.0

## The roads villagers walk, as vertices. Each stays on a road, and goes there and back.
const FOLK_PATHS := [
	[Vector2i(-21, 3), Vector2i(9, 3)],
	[Vector2i(0, -4), Vector2i(0, 13)],
	[Vector2i(-11, 3), Vector2i(0, 3), Vector2i(0, -3)],
	[Vector2i(8, 3), Vector2i(0, 3), Vector2i(0, 12)],
]


## Replaces the town on `canvas` and returns the result.
static func paint_town(canvas: Node2D) -> TownArt:
	var art := TownArt.new()
	art._rng.seed = SCENERY_SEED
	art._plan_town()
	art._build_layers(canvas)
	return art


## True if the vertex is on a road. Villagers keep to these.
func has_road(vertex: Vector2i) -> bool:
	return _road.has(vertex)


## Where a road runs in pixels, for vertex `vertex`. A road is two vertices wide, so
## its middle is half a cell away from them.
static func road_point(vertex: Vector2i) -> Vector2:
	return (Vector2(vertex) + Vector2(0.5, 0.5)) * GameArt.CELL


func _plan_town() -> void:
	_lay_land()
	_lay_town_roads()
	_rivers = RIVER_PARTS
	_lay_water()
	_lay_dirt([])
	_lay_bridges()
	_build_castle(KEEP_SPOT)
	_clear_lots()
	_build_cottages()
	_grow_forests()
	_scatter()
	_collect_points()


func _lay_land() -> void:
	_bounds = AREA
	_land_rect = AREA
	world_rect = Rect2(Vector2(AREA.position) * GameArt.CELL, Vector2(AREA.size) * GameArt.CELL)
	var edge := AREA.grow(2)
	for y in range(edge.position.y, edge.end.y):
		for x in range(edge.position.x, edge.end.x):
			_ground[Vector2i(x, y)] = GRASS


func _lay_town_roads() -> void:
	_lay_road(Vector2i(STREET_WEST, STREET_Y), Vector2i(STREET_EAST, STREET_Y + 1))
	_lay_road(Vector2i(AVENUE_X, AVENUE_NORTH), Vector2i(AVENUE_X + 1, AVENUE_SOUTH))
	var middle := Vector2i(AVENUE_X, STREET_Y)
	for offset_y in range(-SQUARE_SIZE, SQUARE_SIZE + 2):
		for offset_x in range(-SQUARE_SIZE, SQUARE_SIZE + 2):
			var from_middle := Vector2(offset_x - 0.5, offset_y - 0.5)
			if absf(from_middle.x) + absf(from_middle.y) <= SQUARE_SIZE + 1.0:
				_road[middle + Vector2i(offset_x, offset_y)] = true
	for vertex: Vector2i in _road:
		_reserve(Rect2i(vertex - Vector2i(1, 1), Vector2i(2, 2)))


func _lay_road(first: Vector2i, last: Vector2i) -> void:
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			_road[Vector2i(x, y)] = true


## Nothing grows on a building's lot, and it stands on bare ground.
func _clear_lots() -> void:
	for id: String in BUILDING_LOTS:
		var lot: Rect2i = BUILDING_LOTS[id]
		_reserve(lot)
	smoke_points.append(BUILDING_FEET["tavern"] + TAVERN_SMOKE)
	var yard: Rect2i = BUILDING_LOTS["portal"]
	for y in range(yard.position.y + 2, yard.end.y):
		for x in range(yard.position.x, yard.end.x - 1):
			_ground[Vector2i(x, y)] = DIRT


func _build_cottages() -> void:
	var count := 0
	for cell in COTTAGES:
		var tile: Vector2i = HOUSES[count * 4 % HOUSES.size()]
		tile += STYLE_OFFSETS[(count * count + count / 2) % STYLE_OFFSETS.size()]
		_put(cell, tile)
		_reserve(Rect2i(cell, Vector2i.ONE))
		for chimney: Vector2i in CHIMNEYS:
			if tile.x % 10 == chimney.x % 10 and tile.y in [26, 33]:
				smoke_points.append((Vector2(cell) + Vector2(0.7, 0.1)) * GameArt.CELL)
		count += 1
	_put(WELL_CELL, WELL)
	_reserve(Rect2i(WELL_CELL, Vector2i.ONE))
	for index in STALLS.size():
		_put(STALLS[index], STALL_TILES[index])
		_reserve(Rect2i(STALLS[index], Vector2i.ONE))
	for field in FIELDS:
		_reserve(field)
		for y in range(field.position.y, field.end.y):
			for x in range(field.position.x, field.end.x):
				_put(Vector2i(x, y), SCATTER_FARM[(x + y) % 2])


## The town keeps a clearing, and the forest thickens beyond it.
func _forest_edge(vertex: Vector2i) -> float:
	var past_sides := absi(vertex.x) - FOREST_X
	var past_north := -vertex.y - FOREST_NORTH
	var past_south := vertex.y - FOREST_SOUTH
	return clampf(maxi(past_sides, maxi(past_north, past_south)) / FOREST_FADE, -2.0, 1.0)
