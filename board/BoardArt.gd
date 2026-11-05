@tool
class_name BoardArt
extends RefCounted
## Paints the countryside under the board: grass, dirt roads along every link,
## towns, the castle, forests and small decorations. It is built from the
## spaces and their links, so moving a space in the editor moves its road and
## buildings too. BoardManager calls paint() from its _draw().
##
## The world is divided into cells of GameArt.CELL. A "vertex" is the corner
## where four cells meet. Spaces sit on vertices, and a road is two cells wide,
## with its center line running along the vertices.
##
## All tile numbers refer to GameArt.TOWN.

## How many cells of countryside surround the board on each side.
const MARGIN := 14
## How far a town's or castle's dirt square reaches from its space, in cells.
const PLAZA_RADIUS := 3
## Changing this gives a different, but still fixed, countryside. Scenery has
## its own generator on purpose: it must never touch GameState.rng, because
## that one decides the game.
const SCENERY_SEED := 20261105

const GRASS := 0
const GRASS_TUFTS := 1
const GRASS_FLOWERS := 2
## Dirt tiles, indexed by [row][column]: top/middle/bottom, left/middle/right.
const DIRT := [[12, 13, 14], [24, 25, 26], [36, 37, 38]]
## Dirt with one grassy corner.
const DIRT_CORNER_TOP_LEFT := 39
const DIRT_CORNER_TOP_RIGHT := 40
const DIRT_CORNER_BOTTOM_RIGHT := 41
const DIRT_CORNER_BOTTOM_LEFT := 42
## The top-left tile of the 3x3 block of dense forest, in each season.
const FOREST_GREEN := 6
const FOREST_AUTUMN := 9
## The green forest's treetops match the grass. This darkens that forest, so
## its edge stands out.
const FOREST_TINT := Color(0.78, 0.86, 0.76)
## Single trees and small plants.
const TREES_GREEN := [16, 28]
const TREES_AUTUMN := [3, 15, 27]
const PLANTS := [5, 5, 17, 29]

## Buildings are rows of tiles; -1 leaves a cell empty.
const CASTLE := [
	[-1, 99, -1, -1, 101, -1],
	[-1, 125, 103, 103, 125, -1],
	[96, 126, 121, 121, 126, 98],
	[120, 126, 111, 112, 126, 122],
	[126, 126, 123, 124, 126, 126],
]
const HOUSES := [
	[[52, 53, 54], [64, 67, 66], [88, 90, 79]],
	[[48, 49, 50], [60, 63, 62], [84, 86, 75]],
	[[52, 53, 53, 54], [64, 65, 67, 66], [76, 88, 90, 79]],
	[[48, 49, 49, 50], [60, 61, 63, 62], [72, 84, 86, 75]],
]
## Small things that stand around in towns: beehive, signpost, well, target.
const TOWN_PROPS := [[[94]], [[83]], [[104]], [[95]]]

var _rng := RandomNumberGenerator.new()
# Cell (Vector2i) -> true. Cells that are dirt, because of a road or a plaza.
var _dirt := {}
# Cell -> true. Road and space cells: nothing may be built here.
var _road := {}
# Cell -> true. Cells taken by a building.
var _built := {}
# Cell -> true. Cells covered by dense forest.
var _forest := {}
# Each entry is [rows of tiles, top-left cell].
var _stamps := []


## Paints the whole countryside on `canvas` (the BoardManager).
static func paint(canvas: Node2D, nodes: Array[BoardNode], neighbors: Dictionary) -> void:
	if nodes.is_empty():
		return
	var art := BoardArt.new()
	art._rng.seed = SCENERY_SEED
	art._lay_roads(nodes, neighbors)
	art._lay_buildings(nodes)
	art._draw_all(canvas, art._cell_bounds(nodes))


# --- Layout -----------------------------------------------------------------

func _vertex_of(node: BoardNode) -> Vector2i:
	return Vector2i((node.position / GameArt.CELL).round())


func _lay_roads(nodes: Array[BoardNode], neighbors: Dictionary) -> void:
	for node in nodes:
		var vertex := _vertex_of(node)
		for other: BoardNode in neighbors[node]:
			# Every link is stored on both ends; lay it only once.
			if node.get_instance_id() < other.get_instance_id():
				_lay_road(vertex, _vertex_of(other))

		# Keep the space and its name label clear of buildings.
		for offset_y in range(-3, 3):
			for offset_x in range(-3, 3):
				_road[vertex + Vector2i(offset_x, offset_y)] = true

		if node.node_type == BoardNode.NodeType.TOWN or node.node_type == BoardNode.NodeType.CASTLE:
			for offset_y in range(-PLAZA_RADIUS, PLAZA_RADIUS):
				for offset_x in range(-PLAZA_RADIUS, PLAZA_RADIUS):
					_dirt[vertex + Vector2i(offset_x, offset_y)] = true


func _lay_road(from: Vector2i, to: Vector2i) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step in steps + 1:
		var weight := float(step) / maxi(steps, 1)
		var vertex := Vector2i(Vector2(from).lerp(Vector2(to), weight).round())
		# The four cells that touch this vertex.
		for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
			_road[vertex + offset] = true
			_dirt[vertex + offset] = true


func _lay_buildings(nodes: Array[BoardNode]) -> void:
	for node in nodes:
		var vertex := _vertex_of(node)
		match node.node_type:
			BoardNode.NodeType.CASTLE:
				_place_near(CASTLE, vertex)
			BoardNode.NodeType.SHOP:
				_place_near(HOUSES[node.node_id % HOUSES.size()], vertex)
			BoardNode.NodeType.TOWN:
				for index in 3:
					_place_near(HOUSES[(node.node_id + index) % HOUSES.size()], vertex)
				for index in 2:
					_place_near(TOWN_PROPS[(node.node_id + index) % TOWN_PROPS.size()], vertex)


# Puts `rows` on the free spot closest to `vertex`.
func _place_near(rows: Array, vertex: Vector2i) -> void:
	var size := Vector2i(rows[0].size(), rows.size())
	var best := Vector2i.ZERO
	var best_distance := INF
	for offset_y in range(-9, 10):
		for offset_x in range(-9, 10):
			var corner := vertex + Vector2i(offset_x, offset_y)
			var distance := (Vector2(corner) + Vector2(size) * 0.5).distance_to(Vector2(vertex))
			if distance < best_distance and _is_free(corner, size):
				best = corner
				best_distance = distance
	if best_distance == INF:
		return

	_stamps.append([rows, best])
	for offset_y in size.y:
		for offset_x in size.x:
			_built[best + Vector2i(offset_x, offset_y)] = true


func _is_free(corner: Vector2i, size: Vector2i) -> bool:
	for offset_y in size.y:
		for offset_x in size.x:
			var cell := corner + Vector2i(offset_x, offset_y)
			if _road.has(cell) or _built.has(cell):
				return false
	return true


# The rectangle of cells to paint: everything on the board, plus the margin.
func _cell_bounds(nodes: Array[BoardNode]) -> Rect2i:
	var bounds := Rect2i(_vertex_of(nodes[0]), Vector2i.ONE)
	for cell: Vector2i in _road:
		bounds = bounds.expand(cell)
	for cell: Vector2i in _built:
		bounds = bounds.expand(cell)
	return bounds.grow(MARGIN)


func _grow_forest(bounds: Rect2i, noise: FastNoiseLite) -> void:
	# Cells close to anything built stay open.
	var clear := {}
	for cell: Vector2i in _dirt.keys() + _built.keys():
		for offset_y in range(-2, 3):
			for offset_x in range(-2, 3):
				clear[cell + Vector2i(offset_x, offset_y)] = true

	var inner := bounds.grow(-MARGIN)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if clear.has(cell):
				continue
			# 0 inside the board, rising to 1 at the edge of the painted area.
			var outside := maxi(maxi(inner.position.x - x, x - inner.end.x + 1),
					maxi(inner.position.y - y, y - inner.end.y + 1))
			var edge := clampf(float(outside) / MARGIN, 0.0, 1.0)
			if noise.get_noise_2d(x, y) + edge * 1.5 > 0.3:
				_forest[cell] = true

	# The forest tiles need blocks of at least 2x2, so drop thin strips.
	for pass_index in 2:
		var kept := {}
		for cell: Vector2i in _forest:
			if _in_forest_block(cell):
				kept[cell] = true
		_forest = kept


func _in_forest_block(cell: Vector2i) -> bool:
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		var corner := cell + offset
		if (_forest.has(corner) and _forest.has(corner + Vector2i.RIGHT)
				and _forest.has(corner + Vector2i.DOWN) and _forest.has(corner + Vector2i.ONE)):
			return true
	return false


# --- Drawing ----------------------------------------------------------------

func _draw_all(canvas: Node2D, bounds: Rect2i) -> void:
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = SCENERY_SEED
	forest_noise.frequency = 0.09
	var season_noise := FastNoiseLite.new()
	season_noise.seed = SCENERY_SEED + 1
	season_noise.frequency = 0.05
	_grow_forest(bounds, forest_noise)

	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			_draw_town_tile(canvas, _dirt_tile(cell) if _dirt.has(cell) else _grass_tile(), cell)

	# A second pass, because trees are transparent and need the ground under
	# them. Top to bottom, so nearer trees overlap those behind them.
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var autumn := season_noise.get_noise_2d(x, y) > 0.15
			if _forest.has(cell):
				_draw_town_tile(canvas, _forest_tile(cell, autumn), cell,
						Color.WHITE if autumn else FOREST_TINT)
			elif not _dirt.has(cell) and not _built.has(cell):
				var plant := _plant_tile(cell, autumn)
				if plant >= 0:
					_draw_town_tile(canvas, plant, cell)

	for stamp: Array in _stamps:
		var rows: Array = stamp[0]
		for row in rows.size():
			for column in rows[row].size():
				if rows[row][column] >= 0:
					_draw_town_tile(canvas, rows[row][column], stamp[1] + Vector2i(column, row))


func _draw_town_tile(canvas: Node2D, tile: int, cell: Vector2i, tint := Color.WHITE) -> void:
	var rect := Rect2(Vector2(cell) * GameArt.CELL, Vector2.ONE * GameArt.CELL)
	GameArt.draw_tile(canvas, GameArt.TOWN, tile, rect, GameArt.TILE_SIZE, tint)


func _grass_tile() -> int:
	var roll := _rng.randf()
	if roll < 0.04:
		return GRASS_FLOWERS
	return GRASS_TUFTS if roll < 0.22 else GRASS


# Which row (0-2) and column (0-2) of a 3x3 tile block fits `cell`, given the
# cells of the same kind in `mask`. An edge cell uses the edge of the block.
func _block_position(cell: Vector2i, mask: Dictionary) -> Vector2i:
	var row := 1
	if not mask.has(cell + Vector2i.UP):
		row = 0
	elif not mask.has(cell + Vector2i.DOWN):
		row = 2
	var column := 1
	if not mask.has(cell + Vector2i.LEFT):
		column = 0
	elif not mask.has(cell + Vector2i.RIGHT):
		column = 2
	return Vector2i(column, row)


func _dirt_tile(cell: Vector2i) -> int:
	var block := _block_position(cell, _dirt)
	if block != Vector2i.ONE:
		return DIRT[block.y][block.x]

	# Dirt on all four sides: only a corner can still be grass.
	if not _dirt.has(cell + Vector2i(-1, -1)):
		return DIRT_CORNER_TOP_LEFT
	if not _dirt.has(cell + Vector2i(1, -1)):
		return DIRT_CORNER_TOP_RIGHT
	if not _dirt.has(cell + Vector2i(1, 1)):
		return DIRT_CORNER_BOTTOM_RIGHT
	if not _dirt.has(cell + Vector2i(-1, 1)):
		return DIRT_CORNER_BOTTOM_LEFT
	return DIRT[1][1]


func _forest_tile(cell: Vector2i, autumn: bool) -> int:
	var block := _block_position(cell, _forest)
	return (FOREST_AUTUMN if autumn else FOREST_GREEN) + block.x + block.y * 12


# Returns a tile for a lone tree or plant, or -1 for bare grass.
func _plant_tile(cell: Vector2i, autumn: bool) -> int:
	# Keep the roadside and the space around buildings open.
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var near := cell + Vector2i(offset_x, offset_y)
			if _dirt.has(near) or _built.has(near):
				return -1

	var roll := _rng.randf()
	if roll < 0.10:
		var trees: Array = TREES_AUTUMN if autumn else TREES_GREEN
		return trees[_rng.randi() % trees.size()]
	if roll < 0.14:
		return PLANTS[_rng.randi() % PLANTS.size()]
	return -1
