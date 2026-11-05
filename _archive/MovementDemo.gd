extends Node2D
## Test driver for PlayerMovement.
##   - Press Space (or Enter) to roll a six-sided die and move.
##   - At a fork, click a highlighted space or press its number key (1, 2, ...).

## The player to control. Drag the Player node here in the Inspector.
@export var player: PlayerMovement

## How close (in pixels) a click must be to a space to pick it.
const PICK_RADIUS := 34.0
const RING_RADIUS := 36.0
const RING_COLOR := Color(1.0, 0.9, 0.2)

# Spaces offered at the current fork. Empty when no choice is pending.
var _choices: Array[BoardNode] = []
# Separate canvas drawn above the board and the player, for the fork rings.
var _highlight := Node2D.new()


func _ready() -> void:
	if player == null:
		push_error("MovementDemo: 'player' is not set in the Inspector.")
		return
	player.path_choice_required.connect(_on_path_choice_required)
	player.movement_finished.connect(_on_movement_finished)

	_highlight.z_index = 10
	_highlight.draw.connect(_draw_highlights)
	add_child(_highlight)

	print("Press Space to roll the die.")


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if not _choices.is_empty():
		_handle_choice_input(event)
	elif event.is_action_pressed("ui_accept") and not player.is_moving:
		var roll := randi_range(1, 6)
		print("Rolled a %d" % roll)
		player.move_steps(roll)


func _handle_choice_input(event: InputEvent) -> void:
	var picked: BoardNode = null

	if event is InputEventKey and event.pressed and not event.echo:
		# KEY_1, KEY_2, ... are consecutive numbers, so this maps 1 -> index 0.
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < _choices.size():
			picked = _choices[index]
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_global_mouse_position()
		for node in _choices:
			if node.global_position.distance_to(mouse) <= PICK_RADIUS:
				picked = node

	if picked != null:
		get_viewport().set_input_as_handled()
		# Clear first: choose_path() resumes the move immediately.
		_choices = []
		_highlight.queue_redraw()
		player.choose_path(picked)


func _on_path_choice_required(available_nodes: Array[BoardNode]) -> void:
	_choices = available_nodes
	_highlight.queue_redraw()
	var ids := []
	for node in available_nodes:
		ids.append(node.node_id)
	print("Fork! Choose a path: %s (click a ring or press 1-%d)" % [ids, ids.size()])


func _on_movement_finished(final_node: BoardNode) -> void:
	print("Stopped on space %d (%s)" % [final_node.node_id,
			BoardNode.NodeType.keys()[final_node.node_type]])


func _draw_highlights() -> void:
	var font := ThemeDB.fallback_font
	for i in _choices.size():
		var center := _highlight.to_local(_choices[i].global_position)
		_highlight.draw_arc(center, RING_RADIUS, 0.0, TAU, 48, RING_COLOR, 4.0, true)
		# Number above the ring, matching the key to press.
		_highlight.draw_string_outline(font, center + Vector2(-6, -RING_RADIUS - 8), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color.BLACK)
		_highlight.draw_string(font, center + Vector2(-6, -RING_RADIUS - 8), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RING_COLOR)
