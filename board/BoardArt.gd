@tool
class_name BoardArt
extends RefCounted
## Builds the island under the board: sea, beaches, grass, cliffs, forests,
## lakes and rivers, dirt roads, towns and the castle. Everything comes from the
## map file, so a changed map needs no art work: roads, bridges, houses, the size
## of the island and all of its animation follow by themselves.
## BoardManager calls paint() whenever the board changes.
##
## The art is a "corner" tileset: every corner of a tile has one terrain, and a
## tile is picked by the four terrains on its corners (see PunyTiles.WANG). So
## the terrain is planned on the VERTICES of the grid, the points where four
## cells meet. Spaces sit on vertices, so a road runs right through their middle.
## Everything goes into TileMapLayers, which also play the water animation.
##
## Scenery has its own random generator on purpose: it must never touch
## GameState.rng, because that one decides the game.

## Terrain numbers used by PunyTiles.WANG.
const GRASS := 1
const DIRT := 2
const SAND := 3
const CLIFF := 4
const AIR := 5
const TREES := 6
const RIVER := 7
const SEA_LIGHT := 8
const SEA_MEDIUM := 9
const SEA_DEEP := 10
const TREES_DARK := 12

## How far the land reaches past the board, in cells.
const LAND_MARGIN := 11
## How far the sea reaches past the land. The camera stops before this ends.
const SEA_MARGIN := 26
const SAND_WIDTH := 2
const SEA_LIGHT_WIDTH := 4
const SEA_MEDIUM_WIDTH := 7
## Changing this gives a different, but still fixed, island.
const SCENERY_SEED := 20261105
## Seconds each frame of the water stays on screen.
const WATER_FRAME_TIME := 0.22

## The bridge's planks, north to south. They are drawn in a layer of their own,
## because a road is centered on vertices and tiles are centered on cells.
const BRIDGE_TILES := [Vector2i(10, 30), Vector2i(10, 31), Vector2i(10, 32)]

## The castle, as cells relative to the Castle space. It stands north of the
## road, west of the space, with its gate facing the road.
const CASTLE_RECT := Rect2i(-9, -8, 7, 6)
const WALL_TOP_LEFT := Vector2i(18, 26)
const WALL_TOP := Vector2i(19, 26)
const WALL_TOP_RIGHT := Vector2i(20, 26)
const WALL_LEFT := Vector2i(18, 27)
const WALL_RIGHT := Vector2i(20, 27)
const WALL_BOTTOM_LEFT := Vector2i(18, 28)
const WALL_BOTTOM := Vector2i(19, 28)
const WALL_BOTTOM_RIGHT := Vector2i(20, 28)
const WALL_GATE := Vector2i(19, 29)
const KEEP_TOP := Vector2i(12, 26)
const KEEP_BOTTOM := Vector2i(12, 28)

## House tiles per town style; the second number of each pair of styles is how
## far the same house in another roof color is on the sheet.
const HOUSES := [Vector2i(4, 27), Vector2i(5, 27), Vector2i(6, 27), Vector2i(7, 26),
		Vector2i(8, 26), Vector2i(9, 26), Vector2i(7, 27), Vector2i(8, 27), Vector2i(9, 27)]
const STYLE_OFFSETS := [Vector2i.ZERO, Vector2i(0, 7), Vector2i(10, 7)]
const WELL := Vector2i(4, 30)
const HOUSES_PER_TOWN := 7
## Houses with a chimney, which smoke.
const CHIMNEYS := [Vector2i(7, 26), Vector2i(8, 26), Vector2i(9, 26)]

## A single thing standing next to each kind of space.
const SPACE_PROPS := {
	BoardNode.NodeType.SHOP: Vector2i(9, 31),
	BoardNode.NodeType.EVENT: Vector2i(8, 30),
	BoardNode.NodeType.ITEM: Vector2i(8, 31),
	BoardNode.NodeType.MAGIC: Vector2i(5, 26),
	BoardNode.NodeType.GOLD: Vector2i(6, 26),
	BoardNode.NodeType.BATTLE: Vector2i(4, 26),
	BoardNode.NodeType.TREASURE: Vector2i(2, 29),
	BoardNode.NodeType.SHRINE: Vector2i(5, 30),
	BoardNode.NodeType.TRAP: Vector2i(0, 26),
}
const PROP_OFFSETS := [Vector2i(2, -2), Vector2i(-3, -2), Vector2i(2, 1), Vector2i(-3, 1),
		Vector2i(2, -3), Vector2i(-3, -3), Vector2i(3, 2), Vector2i(-4, 2), Vector2i(3, -3)]

## Things scattered over the grass, on land and on the beach.
const SCATTER_LAND := [Vector2i(0, 27), Vector2i(3, 26), Vector2i(3, 27), Vector2i(2, 26),
		Vector2i(2, 27), Vector2i(0, 29), Vector2i(0, 30), Vector2i(0, 26), Vector2i(1, 26),
		Vector2i(1, 27)]
const SCATTER_FARM := [Vector2i(0, 28), Vector2i(1, 28)]
const SCATTER_BEACH := [Vector2i(3, 28), Vector2i(2, 28), Vector2i(0, 31)]

static var _tile_set: TileSet

var _rng := RandomNumberGenerator.new()
# From the map file: [center vertex, radius in cells] and [first, last vertex].
var _lakes: Array = []
var _rivers: Array = []
# Vertex -> terrain.
var _ground := {}
# Vertex -> true: the vertices of each forest overlay.
var _forest := {}
var _forest_dark := {}
# Vertex -> true: every vertex of a road, even where a bridge replaces the dirt.
var _road := {}
# Vertex -> true: water that is part of a lake or river.
var _water := {}
# Vertex -> how many cells it is from the nearest land. 0 on land.
var _sea_distance := {}
# Vertices covered by the area that is painted, and the land inside it.
var _bounds := Rect2i()
var _land_rect := Rect2i()

## Cell -> true: cells that must stay clear of scenery, like roads and spaces.
var reserved := {}
## Cell -> atlas coordinates of what stands there. A cell only ever holds one
## thing, which is what keeps scenery from overlapping.
var objects := {}
## The same, but half a cell further left, for things centered on a vertex:
## bridge planks, and the keep above the castle's gate.
var centered_objects := {}
## Places in the world where a chimney smokes.
var smoke_points: Array[Vector2] = []
## Places in the world where a flag flies.
var flag_points: Array[Vector2] = []
## Places in the world on open water.
var water_points: Array[Vector2] = []
## The painted part of the world.
var world_rect := Rect2()


## Replaces the island on `canvas` (the BoardManager) and returns the result.
static func paint(canvas: Node2D, nodes: Array[BoardNode], neighbors: Dictionary,
		lakes: Array = [], rivers: Array = []) -> BoardArt:
	for child in canvas.get_children(true):
		if child.has_meta("board_art"):
			canvas.remove_child(child)
			child.queue_free()

	var art := BoardArt.new()
	if nodes.is_empty():
		return art
	art._rng.seed = SCENERY_SEED
	art._lakes = lakes
	art._rivers = rivers
	art._plan(nodes, neighbors)
	art._build_layers(canvas)
	return art


static func vertex_of(node: BoardNode) -> Vector2i:
	return Vector2i((node.position / GameArt.CELL).round())


## Every vertex of the road between two vertices. It walks in steps of one cell,
## never diagonally: diagonal corners have no tiles.
static func road_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var vertex := from
	var path: Array[Vector2i] = [vertex]
	while vertex != to:
		var left := to - vertex
		if absi(left.x) >= absi(left.y):
			vertex.x += signi(left.x)
		else:
			vertex.y += signi(left.y)
		path.append(vertex)
	return path


# --- Planning ---------------------------------------------------------------

func _plan(nodes: Array[BoardNode], neighbors: Dictionary) -> void:
	_lay_roads(nodes, neighbors)
	_reserve_spaces(nodes)
	_shape_island(nodes)
	_lay_water()
	_lay_dirt(nodes)
	_lay_bridges()
	_place_castle(nodes)
	_place_towns(nodes)
	_place_props(nodes)
	_raise_cliffs()
	_grow_forests()
	_scatter()
	_collect_points()


func _lay_roads(nodes: Array[BoardNode], neighbors: Dictionary) -> void:
	for node in nodes:
		_road[vertex_of(node)] = true
		for other: BoardNode in neighbors[node]:
			# Every link is stored on both ends; lay it only once.
			if node.node_id < other.node_id:
				for vertex in road_between(vertex_of(node), vertex_of(other)):
					_road[vertex] = true


func _reserve_spaces(nodes: Array[BoardNode]) -> void:
	for vertex: Vector2i in _road:
		_reserve(Rect2i(vertex - Vector2i(2, 2), Vector2i(4, 4)))
	for node in nodes:
		var vertex := vertex_of(node)
		_reserve(Rect2i(vertex - Vector2i(3, 3), Vector2i(6, 6)))
		if node.display_name != "":
			# The name plate under the space.
			_reserve(Rect2i(vertex + Vector2i(-4, 1), Vector2i(8, 2)))


func _reserve(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			reserved[Vector2i(x, y)] = true


func _shape_island(nodes: Array[BoardNode]) -> void:
	var board := Rect2i(_road.keys()[0], Vector2i.ONE)
	for vertex: Vector2i in _road:
		board = board.expand(vertex)
	board = board.expand(board.end)
	_land_rect = board.grow(LAND_MARGIN)
	_bounds = _land_rect.grow(SEA_MARGIN)
	world_rect = Rect2(Vector2(_bounds.position) * GameArt.CELL, Vector2(_bounds.size) * GameArt.CELL)

	var noise := FastNoiseLite.new()
	noise.seed = SCENERY_SEED
	noise.frequency = 0.075
	var core := board.grow(LAND_MARGIN - 3)

	# Land first. Everything else is measured from it.
	var frontier: Array[Vector2i] = []
	for y in range(_bounds.position.y, _bounds.end.y + 1):
		for x in range(_bounds.position.x, _bounds.end.x + 1):
			var vertex := Vector2i(x, y)
			var outside := _distance_to_rect(vertex, core)
			# Inside `core` is always land; the noise only shapes the coast.
			if outside == 0.0 or outside - noise.get_noise_2d(x, y) * 5.0 <= 2.0:
				_ground[vertex] = GRASS
				_sea_distance[vertex] = 0
				frontier.append(vertex)

	# Grow outwards one ring at a time, so the bands of sand and water are never
	# skipped: a tile has no art for grass touching water.
	var distance := 0
	while not frontier.is_empty():
		distance += 1
		var next: Array[Vector2i] = []
		for vertex in frontier:
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					var near := vertex + Vector2i(offset_x, offset_y)
					if _in_bounds(near) and not _sea_distance.has(near):
						_sea_distance[near] = distance
						_ground[near] = _band_at(distance)
						next.append(near)
		frontier = next


func _in_bounds(vertex: Vector2i) -> bool:
	return (vertex.x >= _bounds.position.x and vertex.x <= _bounds.end.x
			and vertex.y >= _bounds.position.y and vertex.y <= _bounds.end.y)


func _distance_to_rect(vertex: Vector2i, rect: Rect2i) -> float:
	var outside_x := maxi(maxi(rect.position.x - vertex.x, vertex.x - rect.end.x), 0)
	var outside_y := maxi(maxi(rect.position.y - vertex.y, vertex.y - rect.end.y), 0)
	return Vector2(outside_x, outside_y).length()


func _band_at(distance: int) -> int:
	if distance <= SAND_WIDTH:
		return SAND
	if distance <= SAND_WIDTH + SEA_LIGHT_WIDTH:
		return SEA_LIGHT
	if distance <= SAND_WIDTH + SEA_LIGHT_WIDTH + SEA_MEDIUM_WIDTH:
		return SEA_MEDIUM
	return SEA_DEEP


func _lay_water() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SCENERY_SEED + 2
	noise.frequency = 0.25
	for lake: Array in _lakes:
		var center: Vector2i = lake[0]
		var radius: Vector2 = lake[1]
		for y in range(center.y - ceili(radius.y) - 1, center.y + ceili(radius.y) + 2):
			for x in range(center.x - ceili(radius.x) - 1, center.x + ceili(radius.x) + 2):
				var vertex := Vector2i(x, y)
				var offset := Vector2(vertex - center) / radius
				if offset.length() + noise.get_noise_2d(x, y) * 0.3 <= 1.0 and not _near_road(vertex, 2):
					_set_water(vertex)
	for row: Array in _rivers:
		var first: Vector2i = row[0]
		var last: Vector2i = row[1]
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				_set_water(Vector2i(x, y))


func _set_water(vertex: Vector2i) -> void:
	if _ground.get(vertex, 0) == GRASS:
		_ground[vertex] = RIVER
		_water[vertex] = true


func _near_road(vertex: Vector2i, reach: int) -> bool:
	for offset_y in range(-reach, reach + 1):
		for offset_x in range(-reach, reach + 1):
			if _road.has(vertex + Vector2i(offset_x, offset_y)):
				return true
	return false


func _near_water(vertex: Vector2i, reach: int) -> bool:
	for offset_y in range(-reach, reach + 1):
		for offset_x in range(-reach, reach + 1):
			if _water.has(vertex + Vector2i(offset_x, offset_y)):
				return true
	return false


func _lay_dirt(nodes: Array[BoardNode]) -> void:
	for vertex: Vector2i in _road:
		# Road ends a cell short of a river: nothing draws dirt touching water.
		if not _near_water(vertex, 1):
			_ground[vertex] = DIRT

	# Squares of bare ground around towns and the castle's gate.
	for node in nodes:
		if node.node_type == BoardNode.NodeType.TOWN or node.node_type == BoardNode.NodeType.CASTLE:
			var center := vertex_of(node)
			for offset_y in range(-2, 3):
				for offset_x in range(-2, 3):
					if absi(offset_x) + absi(offset_y) <= 3:
						_ground[center + Vector2i(offset_x, offset_y)] = DIRT


# A bridge is every run of road vertices that lost its dirt to a river.
func _lay_bridges() -> void:
	var cut := {}
	for vertex: Vector2i in _road:
		if _near_water(vertex, 1):
			cut[vertex] = true
	for vertex: Vector2i in cut:
		if cut.has(vertex + Vector2i.UP):
			continue
		var length := 1
		while cut.has(vertex + Vector2i(0, length)):
			length += 1
		for index in length - 1:
			var plank: Vector2i = BRIDGE_TILES[1]
			if index == 0:
				plank = BRIDGE_TILES[0]
			elif index == length - 2:
				plank = BRIDGE_TILES[2]
			centered_objects[vertex + Vector2i(0, index)] = plank


func _place_castle(nodes: Array[BoardNode]) -> void:
	for node in nodes:
		if node.node_type != BoardNode.NodeType.CASTLE:
			continue
		var rect := CASTLE_RECT
		rect.position += vertex_of(node)
		# Nothing else may grow or be built inside the walls.
		_reserve(rect)
		var last := rect.end - Vector2i.ONE
		_put(rect.position, WALL_TOP_LEFT)
		_put(Vector2i(last.x, rect.position.y), WALL_TOP_RIGHT)
		_put(Vector2i(rect.position.x, last.y), WALL_BOTTOM_LEFT)
		_put(last, WALL_BOTTOM_RIGHT)
		for x in range(rect.position.x + 1, last.x):
			_put(Vector2i(x, rect.position.y), WALL_TOP)
			_put(Vector2i(x, last.y), WALL_BOTTOM)
		for y in range(rect.position.y + 1, last.y):
			_put(Vector2i(rect.position.x, y), WALL_LEFT)
			_put(Vector2i(last.x, y), WALL_RIGHT)

		# The gate in the middle of the south wall, and a path to the road.
		var gate := Vector2i(rect.position.x + rect.size.x / 2, last.y)
		_put(gate, WALL_GATE)
		for vertex_x: int in [gate.x, gate.x + 1]:
			for vertex_y in range(gate.y + 1, vertex_of(node).y):
				_ground[Vector2i(vertex_x, vertex_y)] = DIRT

		# The courtyard, then the keep in it: two tiles wide and four tall.
		for offset_y in range(rect.position.y + 1, last.y + 1):
			for offset_x in range(rect.position.x + 1, last.x + 1):
				_ground[Vector2i(offset_x, offset_y)] = GRASS
		var keep := Vector2i(gate.x, rect.position.y + 1)
		_put_centered_block(keep, KEEP_TOP)
		_put_centered_block(keep + Vector2i(0, 2), KEEP_BOTTOM)
		flag_points.append((Vector2(gate.x, rect.position.y + 1) + Vector2(0.0, 0.1)) * GameArt.CELL)
		flag_points.append((Vector2(rect.position) + Vector2(0.5, 0.1)) * GameArt.CELL)
		flag_points.append((Vector2(last.x, rect.position.y) + Vector2(0.5, 0.1)) * GameArt.CELL)


func _put_centered_block(cell: Vector2i, tile: Vector2i) -> void:
	for offset_y in 2:
		for offset_x in 2:
			var offset := Vector2i(offset_x, offset_y)
			centered_objects[cell + offset] = tile + offset


func _put(cell: Vector2i, tile: Vector2i) -> void:
	objects[cell] = tile


func _is_free(cell: Vector2i, gap := 0) -> bool:
	for offset_y in range(-gap, gap + 1):
		for offset_x in range(-gap, gap + 1):
			var near := cell + Vector2i(offset_x, offset_y)
			if objects.has(near):
				return false
	return not reserved.has(cell) and _ground.get(cell, 0) == GRASS \
			and _ground.get(cell + Vector2i.RIGHT, 0) == GRASS \
			and _ground.get(cell + Vector2i.DOWN, 0) == GRASS \
			and _ground.get(cell + Vector2i.ONE, 0) == GRASS


func _place_towns(nodes: Array[BoardNode]) -> void:
	for node in nodes:
		if node.node_type != BoardNode.NodeType.TOWN:
			continue
		var vertex := vertex_of(node)
		var style: Vector2i = STYLE_OFFSETS[node.node_id % STYLE_OFFSETS.size()]

		# Every free spot near the town, closest first.
		var spots: Array[Vector2i] = []
		for offset_y in range(-8, 9):
			for offset_x in range(-8, 9):
				spots.append(vertex + Vector2i(offset_x, offset_y))
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return Vector2(a - vertex).length_squared() < Vector2(b - vertex).length_squared())

		var placed := 0
		for spot in spots:
			if placed > HOUSES_PER_TOWN or not _is_free(spot, 1):
				continue
			var tile: Vector2i = HOUSES[_rng.randi() % HOUSES.size()]
			if placed == 1:
				_put(spot, WELL + (Vector2i(style.x, 7) if style != Vector2i.ZERO else Vector2i.ZERO))
			else:
				_put(spot, tile + style)
				if CHIMNEYS.has(tile):
					smoke_points.append((Vector2(spot) + Vector2(0.7, 0.1)) * GameArt.CELL)
			placed += 1


func _place_props(nodes: Array[BoardNode]) -> void:
	for node in nodes:
		if not SPACE_PROPS.has(node.node_type):
			continue
		for offset: Vector2i in PROP_OFFSETS:
			var cell := vertex_of(node) + offset
			if _is_free(cell, 1):
				_put(cell, SPACE_PROPS[node.node_type])
				break


func _raise_cliffs() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SCENERY_SEED + 3
	noise.frequency = 0.07
	var raised := {}
	for vertex: Vector2i in _ground:
		if _ground[vertex] == GRASS and noise.get_noise_2d(vertex.x, vertex.y) > 0.08 \
				and _is_open(vertex, 2):
			raised[vertex] = true

	# Keep blocks of at least 3x3, as a cliff needs room for its edges.
	for pass_index in 2:
		var kept := {}
		for vertex: Vector2i in raised:
			if _in_block(vertex, raised, 3):
				kept[vertex] = true
		raised = kept
	for vertex: Vector2i in raised:
		_ground[vertex] = CLIFF


# True when nothing that matters is within `reach` vertices of `vertex`.
func _is_open(vertex: Vector2i, reach: int) -> bool:
	for offset_y in range(-reach, reach + 1):
		for offset_x in range(-reach, reach + 1):
			var near := vertex + Vector2i(offset_x, offset_y)
			var terrain: int = _ground.get(near, SAND)
			if terrain != GRASS or objects.has(near) or reserved.has(near):
				return false
	return true


func _in_block(vertex: Vector2i, mask: Dictionary, size: int) -> bool:
	for corner_y in range(vertex.y - size + 1, vertex.y + 1):
		for corner_x in range(vertex.x - size + 1, vertex.x + 1):
			var whole := true
			for y in range(corner_y, corner_y + size):
				for x in range(corner_x, corner_x + size):
					if not mask.has(Vector2i(x, y)):
						whole = false
			if whole:
				return true
	return false


func _grow_forests() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SCENERY_SEED + 4
	noise.frequency = 0.11
	var shade_noise := FastNoiseLite.new()
	shade_noise.seed = SCENERY_SEED + 5
	shade_noise.frequency = 0.05
	for vertex: Vector2i in _ground:
		if _ground[vertex] != GRASS or not _forest_may_stand(vertex):
			continue
		var edge := clampf(_distance_to_rect(vertex, _land_rect.grow(-LAND_MARGIN)) / LAND_MARGIN, 0.0, 1.0)
		if noise.get_noise_2d(vertex.x, vertex.y) + edge * 0.5 > 0.0:
			if shade_noise.get_noise_2d(vertex.x, vertex.y) > 0.0:
				_forest[vertex] = true
			else:
				_forest_dark[vertex] = true
	_forest = _without_thin_parts(_forest)
	_forest_dark = _without_thin_parts(_forest_dark)


# A tree reaches a cell around its vertex, so this looks one vertex further.
func _forest_may_stand(vertex: Vector2i) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var near := vertex + Vector2i(offset_x, offset_y)
			if reserved.has(near) or objects.has(near) or _ground.get(near, SAND) != GRASS:
				return false
	return true


func _without_thin_parts(mask: Dictionary) -> Dictionary:
	var kept := {}
	for vertex: Vector2i in mask:
		if _in_block(vertex, mask, 2):
			kept[vertex] = true
	return kept


func _scatter() -> void:
	for vertex: Vector2i in _ground:
		var cell := vertex
		var roll := _rng.randf()
		if _ground[vertex] == SAND:
			if roll < 0.035 and _whole_cell_is(cell, SAND) and not objects.has(cell):
				_put(cell, SCATTER_BEACH[_rng.randi() % SCATTER_BEACH.size()])
		elif roll < 0.07 and _is_free(cell, 1) and not _forest_touches(cell):
			var list: Array = SCATTER_LAND
			if _near_town_objects(cell):
				list = SCATTER_FARM
			_put(cell, list[_rng.randi() % list.size()])


func _whole_cell_is(cell: Vector2i, terrain: int) -> bool:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		if _ground.get(cell + offset, 0) != terrain:
			return false
	return true


func _forest_touches(cell: Vector2i) -> bool:
	for offset_y in range(-1, 3):
		for offset_x in range(-1, 3):
			var near := cell + Vector2i(offset_x, offset_y)
			if _forest.has(near) or _forest_dark.has(near):
				return true
	return false


func _near_town_objects(cell: Vector2i) -> bool:
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			var tile: Vector2i = objects.get(cell + Vector2i(offset_x, offset_y), Vector2i(-1, -1))
			if tile.x >= 4:
				return true
	return false


func _collect_points() -> void:
	for vertex: Vector2i in _ground:
		var terrain: int = _ground[vertex]
		if terrain == RIVER or terrain == SEA_LIGHT or terrain == SEA_MEDIUM:
			water_points.append(Vector2(vertex) * GameArt.CELL)


# --- Building the layers ----------------------------------------------------

func _build_layers(canvas: Node2D) -> void:
	var ground := _new_layer(canvas, "ArtGround")
	var forest := _new_layer(canvas, "ArtForest")
	var forest_dark := _new_layer(canvas, "ArtForestDark")
	var scenery := _new_layer(canvas, "ArtObjects")
	var centered := _new_layer(canvas, "ArtCentered")
	centered.position = Vector2(-GameArt.CELL * 0.5, 0.0)

	for y in range(_bounds.position.y, _bounds.end.y):
		for x in range(_bounds.position.x, _bounds.end.x):
			var cell := Vector2i(x, y)
			_set_tile(ground, cell, _tile_for(_corners(cell, _ground)))
			_set_overlay(forest, cell, _forest, TREES)
			_set_overlay(forest_dark, cell, _forest_dark, TREES_DARK)
	for cell: Vector2i in objects:
		_set_atlas(scenery, cell, objects[cell])
	for cell: Vector2i in centered_objects:
		_set_atlas(centered, cell, centered_objects[cell])


func _new_layer(canvas: Node2D, layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = _get_tile_set()
	layer.scale = Vector2.ONE * GameArt.PIXEL
	layer.set_meta("board_art", true)
	# Internal children never show in the Scene dock and are never saved.
	canvas.add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


func _corners(cell: Vector2i, terrain: Dictionary) -> Array[int]:
	var corners: Array[int] = []
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
		corners.append(terrain.get(cell + offset, SEA_DEEP))
	return corners


func _key(corners: Array[int]) -> int:
	return corners[0] * 2197 + corners[1] * 169 + corners[2] * 13 + corners[3]


# Returns a tile for these corners. A tile only has art for two terrains, so a
# rarer third terrain is painted over with the most common one.
func _tile_for(corners: Array[int]) -> int:
	var key := _key(corners)
	while not PunyTiles.WANG.has(key):
		var counts := {}
		for terrain in corners:
			counts[terrain] = counts.get(terrain, 0) + 1
		var rarest: int = corners[0]
		var commonest: int = corners[0]
		for terrain: int in counts:
			if counts[terrain] <= counts[rarest]:
				rarest = terrain
			if counts[terrain] >= counts[commonest]:
				commonest = terrain
		if rarest == commonest:
			return PunyTiles.WANG[_key([GRASS, GRASS, GRASS, GRASS] as Array[int])][0]
		for index in corners.size():
			if corners[index] == rarest:
				corners[index] = commonest
		key = _key(corners)
	var tiles: Array = PunyTiles.WANG[key]
	return tiles[_rng.randi() % tiles.size()]


func _set_overlay(layer: TileMapLayer, cell: Vector2i, mask: Dictionary, terrain: int) -> void:
	var corners: Array[int] = []
	var any := false
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
		var filled := mask.has(cell + offset)
		any = any or filled
		corners.append(terrain if filled else AIR)
	if any:
		_set_tile(layer, cell, PunyTiles.WANG[_key(corners)][0])


func _set_tile(layer: TileMapLayer, cell: Vector2i, tile: int) -> void:
	_set_atlas(layer, cell, GameArt.world_coords(tile))


func _set_atlas(layer: TileMapLayer, cell: Vector2i, coords: Vector2i) -> void:
	var source := layer.tile_set.get_source(0) as TileSetAtlasSource
	if not source.has_tile(coords):
		source.create_tile(coords)
	layer.set_cell(cell, 0, coords)


static func _get_tile_set() -> TileSet:
	if _tile_set != null:
		return _tile_set
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i.ONE * GameArt.TILE_SIZE
	var source := TileSetAtlasSource.new()
	source.texture = GameArt.WORLD
	source.texture_region_size = Vector2i.ONE * GameArt.TILE_SIZE
	_tile_set.add_source(source, 0)
	for tile: int in PunyTiles.ANIMATED:
		var coords := GameArt.world_coords(tile)
		source.create_tile(coords)
		source.set_tile_animation_columns(coords, 1)
		source.set_tile_animation_separation(coords, Vector2i(0, PunyTiles.ANIMATED[tile] - 1))
		source.set_tile_animation_frames_count(coords, 4)
		for frame in 4:
			source.set_tile_animation_frame_duration(coords, frame, WATER_FRAME_TIME)
	return _tile_set
