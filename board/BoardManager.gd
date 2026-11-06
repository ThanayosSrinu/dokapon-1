@tool
class_name BoardManager
extends Node2D
## The game board. Owns every BoardNode child and answers questions about the
## map: where players start, which spaces are neighbors, and which space is
## under the mouse.
##
## The whole map lives in one file (see `map_file`): the spaces, their links,
## lakes and rivers. Spaces are created from it, and BoardArt builds the island
## from them, both in the editor and in the game. A link is two-way, so it only
## has to be written on one of the two spaces.
##
## Checks the map for mistakes and shows them as warnings (the yellow triangle
## next to this node in the Scene dock). `tools/check_map.gd` prints the same
## list without opening the editor.

## Emitted once every space has been read and linked.
signal board_ready

## World distance between two neighboring grid points of the map file.
const GRID := 160
## The longest a link should be, in grid points. A link of 2 is what lets a map have a
## loop of 5 spaces: with every link 1 long, every loop on a grid has an even size.
const LONGEST_LINK := 2

## The map to play. The editor reloads it whenever the file changes.
@export_file("*.json") var map_file := "res://maps/world_map.json"

@export_group("Input")
## When on, left-clicking a space emits EventBus.space_clicked.
@export var clickable := true

@export_group("Debug")
## Print every space and its neighbors to the Output panel on start.
@export var print_on_ready := true

# Every space, in map-file order.
var _nodes: Array[BoardNode] = []
# node_id (int) -> BoardNode
var _nodes_by_id := {}
# BoardNode -> Array[BoardNode]. Links from both ends are merged here, which
# is what makes every link two-way.
var _neighbors := {}
# When the map file last changed. The editor uses this to notice edits.
var _map_time := 0
# Mistakes found while reading the map file.
var _load_problems := PackedStringArray()
# The island under the board.
var _art: BoardArt


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		return
	# The map cannot change while the game runs, so stop polling for changes.
	set_process(false)
	for problem in validate():
		push_warning("BoardManager: " + problem)
	if print_on_ready:
		print_board()
	var ambience := WorldAmbience.new()
	ambience.art = _art
	add_child(ambience, false, INTERNAL_MODE_BACK)
	board_ready.emit()


func _process(_delta: float) -> void:
	# Only runs in the editor (see _ready): keep up with edits to the map file.
	if FileAccess.get_modified_time(map_file) != _map_time:
		rebuild()
		update_configuration_warnings()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not clickable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# make_input_local() converts the click from screen pixels to this node's
		# coordinates, which accounts for camera pan and zoom.
		var node := get_node_at(to_global(make_input_local(event).position))
		if node != null:
			get_viewport().set_input_as_handled()
			EventBus.space_clicked.emit(node)


func _get_configuration_warnings() -> PackedStringArray:
	return validate()


# --- Public API -------------------------------------------------------------

## Reads the map file and builds the spaces and the island from it.
func rebuild() -> void:
	for node in _nodes:
		remove_child(node)
		node.queue_free()
	_nodes.clear()
	_nodes_by_id.clear()
	_neighbors.clear()
	_load_problems.clear()

	var data := _read_map()
	_create_spaces(data.get("spaces", []))
	var lakes := []
	for lake: Dictionary in data.get("lakes", []):
		lakes.append([Vector2i(int(lake.x), int(lake.y)), Vector2(lake.width, lake.height)])
	var rivers := []
	for river: Dictionary in data.get("rivers", []):
		rivers.append([Vector2i(int(river.from[0]), int(river.from[1])),
				Vector2i(int(river.to[0]), int(river.to[1]))])
	_art = BoardArt.paint(self, _nodes, _neighbors, lakes, rivers)


## The painted part of the world. The camera stays inside it.
func get_world_rect() -> Rect2:
	return _art.world_rect


## The island under the board.
func get_art() -> BoardArt:
	return _art


## Returns every space on the board.
func get_all_nodes() -> Array[BoardNode]:
	return _nodes.duplicate()


## Returns the space with the given id, or null if there is none.
func get_board_node(id: int) -> BoardNode:
	return _nodes_by_id.get(id)


## Returns the space where play begins: the Portal, or the Castle on the old map.
func get_starting_node() -> BoardNode:
	for node in _nodes:
		if _is_start(node):
			return node
	push_error("BoardManager: the map has no Portal or Castle space.")
	return null


## Every town on the map: space id -> {"name", "steps"}, where `steps` is the
## shortest walk from the castle. Town.gd works out its numbers from this.
func get_town_info() -> Dictionary:
	var steps := {get_starting_node(): 0}
	var queue: Array[BoardNode] = [get_starting_node()]
	while not queue.is_empty():
		var current: BoardNode = queue.pop_front()
		for neighbor in get_neighbors(current):
			if not steps.has(neighbor):
				steps[neighbor] = steps[current] + 1
				queue.append(neighbor)
	var towns := {}
	for node in _nodes:
		if node.node_type == BoardNode.NodeType.TOWN:
			towns[node.node_id] = {"name": node.get_display_name(), "steps": steps.get(node, 0)}
	return towns


## Returns all spaces linked to `node`, from either end.
func get_neighbors(node: BoardNode) -> Array[BoardNode]:
	var result: Array[BoardNode] = []
	result.assign(_neighbors.get(node, []))
	return result


## Returns the spaces a player on `node` can move to next.
## Pass `came_from` to stop a player from walking straight back, unless
## turning back is the only way out (a dead end).
func get_connected_nodes(node: BoardNode, came_from: BoardNode = null) -> Array[BoardNode]:
	var options := get_neighbors(node)
	if came_from != null and options.size() > 1:
		options.erase(came_from)
	return options


## Returns every space a player on `start` can stop on after walking EXACTLY
## `steps` spaces, following the same rules as real movement (see
## get_connected_nodes). This is a breadth-first search done one layer per
## step. It remembers "which space, and where from", not just "which space",
## because where you came from decides where you may go next.
func get_landing_nodes(start: BoardNode, steps: int, came_from: BoardNode = null) -> Array[BoardNode]:
	# Each state is [space, the space stepped off to get there].
	var states := [[start, came_from]]
	for step in steps:
		# Dictionary keys are unique, so paths that meet are only walked once.
		# Without this, the search would grow with every fork it passes.
		var next_states := {}
		for state in states:
			var options := get_connected_nodes(state[0], state[1])
			if options.is_empty():
				# An isolated space: a real move would stop here too.
				next_states[state] = true
			for next in options:
				next_states[[next, state[0]]] = true
		states = next_states.keys()

	var result: Array[BoardNode] = []
	for state in states:
		if not result.has(state[0]):
			result.append(state[0])
	return result


## Returns the space under `world_position`, or null if there is none.
func get_node_at(world_position: Vector2) -> BoardNode:
	var best: BoardNode = null
	var best_distance := INF
	for node in _nodes:
		var distance := node.global_position.distance_to(world_position)
		if distance <= node.get_radius() and distance < best_distance:
			best = node
			best_distance = distance
	return best


## Returns the rectangle (in world coordinates) that contains every space.
## Used to center the camera.
func get_bounds() -> Rect2:
	if _nodes.is_empty():
		return Rect2()
	var rect := Rect2(_nodes[0].global_position, Vector2.ZERO)
	for node in _nodes:
		rect = rect.expand(node.global_position)
	return rect


## Checks the map and returns a readable list of problems (empty = all good).
func validate() -> PackedStringArray:
	var problems := _load_problems.duplicate()
	if _nodes.is_empty():
		problems.append("The map has no spaces yet.")
		return problems

	# Exactly one start.
	var starts := _nodes.filter(_is_start)
	if starts.is_empty():
		problems.append("There is no Portal or Castle space. A trip needs one to start on.")
	elif starts.size() > 1:
		problems.append("There are %d start spaces. Only the first one ('%s') is the start."
				% [starts.size(), starts[0].name])

	for node in _nodes:
		if get_neighbors(node).is_empty():
			problems.append("'%s' is not linked to any other space." % node.name)

	problems.append_array(_find_layout_problems())

	# Every linked space must be reachable from the start.
	if not starts.is_empty():
		var reached := _collect_reachable(starts[0])
		for node in _nodes:
			if not reached.has(node) and not get_neighbors(node).is_empty():
				problems.append("'%s' cannot be reached from the start." % node.name)

	return problems


## Prints every space and its neighbors to the Output panel.
func print_board() -> void:
	print("--- Board: %d spaces ---" % _nodes.size())
	for node in _nodes:
		var neighbor_ids := []
		for neighbor in get_neighbors(node):
			neighbor_ids.append(neighbor.node_id)
		print("#%d %s (%s) -> %s" % [node.node_id, node.name, node.get_type_name(), neighbor_ids])
	var start := get_starting_node()
	if start != null:
		print("Start: %s (id %d)" % [start.name, start.node_id])


# --- Internal helpers -------------------------------------------------------

func _is_start(node: BoardNode) -> bool:
	return node.node_type == BoardNode.NodeType.PORTAL or node.node_type == BoardNode.NodeType.CASTLE


func _add_link(a: BoardNode, b: BoardNode) -> void:
	if not _neighbors[a].has(b):
		_neighbors[a].append(b)
	if not _neighbors[b].has(a):
		_neighbors[b].append(a)


## Breadth-first search: returns {node: true} for every space reachable from
## `start` by walking along links.
func _collect_reachable(start: BoardNode) -> Dictionary:
	var reached := {start: true}
	var queue: Array[BoardNode] = [start]
	while not queue.is_empty():
		var current: BoardNode = queue.pop_front()
		for next in get_neighbors(current):
			if not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached


func _read_map() -> Dictionary:
	_map_time = FileAccess.get_modified_time(map_file)
	var text := FileAccess.get_file_as_string(map_file)
	if text == "":
		_load_problems.append("The map file '%s' is missing or empty." % map_file)
		return {}
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		_load_problems.append("The map file '%s' is not valid JSON." % map_file)
		return {}
	return data


func _create_spaces(rows: Array) -> void:
	for row: Dictionary in rows:
		var id := int(row.get("id", -1))
		if id < 0 or _nodes_by_id.has(id):
			_load_problems.append("Space id %d is missing or used twice." % id)
			continue
		var type_name: String = row.get("type", "NORMAL")
		if not BoardNode.NodeType.has(type_name):
			_load_problems.append("Space %d has an unknown type '%s'." % [id, type_name])
		var node := BoardNode.new()
		node.name = "S%02d" % id
		node.node_id = id
		node.node_type = BoardNode.NodeType.get(type_name, BoardNode.NodeType.NORMAL)
		node.display_name = row.get("name", "")
		node.position = Vector2(row.get("x", 0), row.get("y", 0)) * GRID
		# Not owned by the scene, so a space is never saved into it.
		add_child(node)
		_nodes.append(node)
		_nodes_by_id[id] = node
		var neighbor_list: Array[BoardNode] = []
		_neighbors[node] = neighbor_list

	for row: Dictionary in rows:
		var node: BoardNode = _nodes_by_id.get(int(row.get("id", -1)))
		if node == null:
			continue
		for link in row.get("to", []):
			var other: BoardNode = _nodes_by_id.get(int(link))
			if other == null:
				_load_problems.append("'%s' links to %d, which is not on this map." % [node.name, link])
			elif other == node:
				_load_problems.append("'%s' is linked to itself." % node.name)
			else:
				_add_link(node, other)


## Finds roads that draw badly: through a third space, stepped on a diagonal, or
## longer than a link may be. The map still works, but the road on screen is not
## the way the token walks, or doesn't look like one step.
func get_layout_notes() -> PackedStringArray:
	var notes := PackedStringArray()
	var spaces := {}
	for node in _nodes:
		spaces[BoardArt.vertex_of(node)] = node
	for node in _nodes:
		for other in get_neighbors(node):
			if node.node_id > other.node_id:
				continue
			var gap := (other.position - node.position).abs() / GRID
			if gap.x > 0.0 and gap.y > 0.0:
				notes.append("The road %s-%s is diagonal." % [node.name, other.name])
			elif maxf(gap.x, gap.y) > LONGEST_LINK:
				notes.append("The road %s-%s is longer than %d grid points." % [node.name, other.name, LONGEST_LINK])
			for vertex in BoardArt.road_between(BoardArt.vertex_of(node), BoardArt.vertex_of(other)):
				var met: BoardNode = spaces.get(vertex)
				if met != null and met != node and met != other:
					notes.append("The road %s-%s runs through '%s'." % [node.name, other.name, met.name])
	return notes


## Finds places where the map cannot draw properly: spaces on top of each other,
## or a road inside the castle walls or the Portal's gate.
func _find_layout_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	var spaces := {}
	for node in _nodes:
		var vertex := BoardArt.vertex_of(node)
		if spaces.has(vertex):
			problems.append("'%s' and '%s' are on the same spot." % [spaces[vertex].name, node.name])
		spaces[vertex] = node

	# Rect -> what stands there.
	var buildings := {}
	for node in _nodes:
		var spot := BoardArt.vertex_of(node)
		if node.node_type == BoardNode.NodeType.CASTLE:
			buildings[Rect2i(BoardArt.CASTLE_RECT.position + spot, BoardArt.CASTLE_RECT.size)] = "castle walls"
		elif node.node_type == BoardNode.NodeType.PORTAL:
			buildings[Rect2i(BoardArt.GATE_RECT.position + spot, BoardArt.GATE_RECT.size)] = "Portal's gate"

	for node in _nodes:
		for other in get_neighbors(node):
			if node.node_id > other.node_id:
				continue
			for vertex in BoardArt.road_between(BoardArt.vertex_of(node), BoardArt.vertex_of(other)):
				for rect: Rect2i in buildings:
					if rect.has_point(vertex):
						problems.append("The road %s-%s runs through the %s." % [node.name, other.name, buildings[rect]])
						break
	return problems
