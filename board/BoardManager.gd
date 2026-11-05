@tool
class_name BoardManager
extends Node2D
## The game board. Owns every BoardNode child and answers questions about the
## map: where players start, which spaces are neighbors, and which space is
## under the mouse.
##
## The map is built by hand in the editor (see res://maps/WorldMap.tscn):
## add BoardNode children and link them through their `connected_nodes`.
## Every link is two-way, so each link only has to be set on one of the two
## spaces.
##
## Draws the paths between spaces, both in the editor and in the game.
## Checks the map for mistakes and shows them as warnings (the yellow
## triangle next to this node in the Scene dock).

## Emitted once every space has been read and linked.
signal board_ready

@export_group("Paths")
@export var path_color := Color(0.93, 0.87, 0.72):
	set(value):
		path_color = value
		queue_redraw()
@export var path_outline_color := Color(0.25, 0.18, 0.10):
	set(value):
		path_outline_color = value
		queue_redraw()
@export var path_width := 10.0:
	set(value):
		path_width = maxf(value, 1.0)
		queue_redraw()

@export_group("Input")
## When on, left-clicking a space emits EventBus.space_clicked.
@export var clickable := true

@export_group("Debug")
## Print every space and its neighbors to the Output panel on start.
@export var print_on_ready := true

@export_group("Editor Tools")
## Gives a fresh id to every space whose id is -1 or used twice
## (for example after duplicating a space with Ctrl+D). Existing unique ids
## are never changed, so save files stay valid. Can be undone with Ctrl+Z.
@export_tool_button("Assign Missing IDs") var assign_ids_button := _assign_missing_ids

# Every BoardNode child, in Scene-dock order.
var _nodes: Array[BoardNode] = []
# node_id (int) -> BoardNode
var _nodes_by_id := {}
# BoardNode -> Array[BoardNode]. Links from both ends are merged here, which
# is what makes every link two-way.
var _neighbors := {}
# Snapshot of the map used by the editor to notice changes.
var _last_signature := []


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
	board_ready.emit()


func _process(_delta: float) -> void:
	# Only runs in the editor (see _ready). Rebuild whenever a space was added,
	# removed, moved, retyped or relinked, so drawing and warnings stay current.
	var signature := _make_signature()
	if signature != _last_signature:
		_last_signature = signature
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

## Re-reads every BoardNode child and its links. Call this after adding or
## removing spaces while the game runs (the editor does it automatically).
func rebuild() -> void:
	_nodes.clear()
	_nodes_by_id.clear()
	_neighbors.clear()

	for child in get_children():
		if child is BoardNode:
			_nodes.append(child)
			var neighbor_list: Array[BoardNode] = []
			_neighbors[child] = neighbor_list
			# If two spaces share an id, the first one wins (validate() warns).
			if child.node_id >= 0 and not _nodes_by_id.has(child.node_id):
				_nodes_by_id[child.node_id] = child

	for node in _nodes:
		for other in node.connected_nodes:
			if is_instance_valid(other) and other != node and _neighbors.has(other):
				_add_link(node, other)

	queue_redraw()


## Returns every space on the board.
func get_all_nodes() -> Array[BoardNode]:
	return _nodes.duplicate()


## Returns the space with the given id, or null if there is none.
func get_board_node(id: int) -> BoardNode:
	return _nodes_by_id.get(id)


## Returns the Castle space where every player begins.
func get_starting_node() -> BoardNode:
	for node in _nodes:
		if node.node_type == BoardNode.NodeType.CASTLE:
			return node
	push_error("BoardManager: the map has no Castle space.")
	return null


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
	var problems := PackedStringArray()
	if _nodes.is_empty():
		problems.append("The board has no spaces yet. Add BoardNode children.")
		return problems

	# Every space needs its own id.
	var seen_ids := {}
	for node in _nodes:
		if node.node_id < 0:
			problems.append("'%s' has no id. Press 'Assign Missing IDs'." % node.name)
		elif seen_ids.has(node.node_id):
			problems.append("'%s' and '%s' share id %d. Press 'Assign Missing IDs'."
					% [seen_ids[node.node_id].name, node.name, node.node_id])
		else:
			seen_ids[node.node_id] = node

	# Exactly one Castle (the start).
	var castles := _nodes.filter(func(n: BoardNode) -> bool:
			return n.node_type == BoardNode.NodeType.CASTLE)
	if castles.is_empty():
		problems.append("There is no Castle space. Players need one to start on.")
	elif castles.size() > 1:
		problems.append("There are %d Castles. Only the first one ('%s') is the start."
				% [castles.size(), castles[0].name])

	# Broken links and isolated spaces.
	for node in _nodes:
		for other in node.connected_nodes:
			if not is_instance_valid(other):
				problems.append("'%s' has an empty slot in Connected Nodes." % node.name)
			elif other == node:
				problems.append("'%s' is linked to itself." % node.name)
			elif not _neighbors.has(other):
				problems.append("'%s' links to '%s', which is not on this board."
						% [node.name, other.name])
		if get_neighbors(node).is_empty():
			problems.append("'%s' is not linked to any other space." % node.name)

	# Every linked space must be reachable from the start.
	if not castles.is_empty():
		var reached := _collect_reachable(castles[0])
		for node in _nodes:
			if not reached.has(node) and not get_neighbors(node).is_empty():
				problems.append("'%s' cannot be reached from the Castle." % node.name)

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


## A cheap snapshot of everything that affects drawing and warnings.
## Instance ids are used instead of node references, so deleted nodes are
## never touched.
func _make_signature() -> Array:
	var signature := []
	for child in get_children():
		if child is BoardNode:
			var link_ids := []
			for other in child.connected_nodes:
				link_ids.append(other.get_instance_id() if is_instance_valid(other) else 0)
			signature.append([child.get_instance_id(), child.node_id, child.node_type,
					child.position, link_ids])
	return signature


func _assign_missing_ids() -> void:
	rebuild()
	var used_ids := {}
	var needs_id: Array[BoardNode] = []
	for node in _nodes:
		if node.node_id < 0 or used_ids.has(node.node_id):
			needs_id.append(node)
		else:
			used_ids[node.node_id] = true

	if needs_id.is_empty():
		print("BoardManager: every space already has a unique id.")
		return

	# Go through the editor's undo system, so Ctrl+Z works and the scene is
	# marked as unsaved. EditorInterface is fetched by name because it only
	# exists inside the editor, never in the exported game.
	var undo_redo = Engine.get_singleton("EditorInterface").get_editor_undo_redo()
	undo_redo.create_action("Assign Missing Space IDs")
	var next_id := 0
	for node in needs_id:
		while used_ids.has(next_id):
			next_id += 1
		used_ids[next_id] = true
		undo_redo.add_do_property(node, "node_id", next_id)
		undo_redo.add_undo_property(node, "node_id", node.node_id)
	undo_redo.commit_action()
	print("BoardManager: assigned ids to %d space(s)." % needs_id.size())


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	# Two passes: all dark outlines first, then all light centers on top, so
	# paths that meet at a space look like one clean road.
	for pass_index in 2:
		var color := path_outline_color if pass_index == 0 else path_color
		var width := path_width + 6.0 if pass_index == 0 else path_width
		for node in _nodes:
			for other in _neighbors[node]:
				# Every link is stored on both ends; draw it only once.
				if node.get_instance_id() < other.get_instance_id():
					draw_line(to_local(node.global_position), to_local(other.global_position),
							color, width, true)
