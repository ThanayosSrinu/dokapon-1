class_name PlayerMovement
extends Node2D
## One player's token: draws it and moves it across the board, one space at a
## time. Main.tscn holds several of these, one per player.
##
## How to use it:
##   1. Drag the BoardManager node into `board_manager` in the Inspector.
##      The player then appears on the Castle space when the game starts.
##   2. Call move_steps() with a dice roll.
##   3. After every step, `step_finished` is emitted.
##   4. At a fork, movement pauses and `path_choice_required` is emitted.
##      Answer it by calling choose_path() with one of the offered spaces.
##   5. `movement_finished` is emitted when the player has stopped.

## Emitted when the player must pick which way to go. Movement stays paused
## until choose_path() is called with one of `available_nodes`.
signal path_choice_required(available_nodes: Array[BoardNode])

## Emitted each time the token arrives on a space during a move.
signal step_finished(node: BoardNode, steps_remaining: int)

## Emitted once every step is used up and the token has stopped sliding.
signal movement_finished(final_node: BoardNode)

# Emitted by choose_path() to wake up a move that is waiting at a fork.
signal _path_chosen

## Width and height of the character in the world.
const SPRITE_SIZE := 48.0
## Radius of the colored ring at the character's feet.
const RING_RADIUS := 22.0
# Drawn above idle tokens while moving (z_index of a normal node is 0).
const MOVING_Z_INDEX := 10

## The board to walk on. Drag the BoardManager node here in the Inspector.
@export var board_manager: BoardManager

## Shown in the UI.
@export var player_name := "Player":
	set(value):
		player_name = value
		queue_redraw()

## The color of this player's token: the ring at the character's feet.
@export var token_color := Color(0.9, 0.3, 0.3):
	set(value):
		token_color = value
		queue_redraw()

## This player's character: a tile of the Tiny Dungeon sheet (GameArt.DUNGEON).
@export var sprite_tile := 97:
	set(value):
		sprite_tile = value
		queue_redraw()

## Seconds the slide from one space to the next takes.
@export var step_duration := 0.35

## Short pause after each step, so single steps are easy to count.
@export var step_pause := 0.05

## How high the token hops on each step, in pixels.
@export var hop_height := 22.0

## When true, a new turn may start in any direction, even back the way the
## player came last turn. When false, the player keeps walking forward.
@export var can_reverse_at_turn_start := true

## The space the player is standing on.
var current_node: BoardNode

## True while move_steps() is running (sliding or waiting at a fork).
var is_moving := false

## Steps still to walk in this move. Drawn above the token while moving.
var steps_left := 0:
	set(value):
		steps_left = value
		queue_redraw()

# The space the player stepped off last. Used to avoid walking straight back.
var _previous_node: BoardNode
# The spaces offered at the current fork. Empty when not waiting.
var _pending_choices: Array[BoardNode] = []
# The space picked through choose_path(), until move_steps() reads it.
var _chosen_node: BoardNode
# Current height of the hop. Only the drawing moves up; the position stays on
# the road, so the camera does not bob up and down.
var _hop_offset := 0.0
# The running set_rest_offset() animation.
var _rest_tween: Tween
# True after walking left. The sprite is mirrored to face that way.
var _facing_left := false


func _ready() -> void:
	if board_manager == null:
		push_error("PlayerMovement: 'board_manager' is not set in the Inspector.")
		return
	# The board builds its spaces in its own _ready(). If that has not run yet
	# (for example, the player is above the board in the Scene tree), wait.
	if not board_manager.is_node_ready():
		await board_manager.board_ready
	spawn_at(board_manager.get_starting_node())


# --- Public API -------------------------------------------------------------

## Places the player on `node` instantly, without animation.
func spawn_at(node: BoardNode) -> void:
	if node == null:
		push_error("PlayerMovement: cannot spawn on an empty space.")
		return
	current_node = node
	_previous_node = null
	global_position = node.global_position


## Moves the player `steps` spaces, sliding from space to space.
## Pauses at forks until choose_path() is called.
## Emits `movement_finished` when done.
func move_steps(steps: int) -> void:
	if is_moving:
		push_warning("PlayerMovement: already moving, ignoring move_steps(%d)." % steps)
		return
	if current_node == null:
		push_error("PlayerMovement: the player has not been placed on the board yet.")
		return

	is_moving = true
	z_index = MOVING_Z_INDEX
	if can_reverse_at_turn_start:
		_previous_node = null

	steps_left = steps
	while steps_left > 0:
		var options := board_manager.get_connected_nodes(current_node, _previous_node)
		if options.is_empty():
			# An isolated space: nowhere to go, so the move ends early.
			push_warning("PlayerMovement: space %d has no exits." % current_node.node_id)
			steps_left = 0
			break

		var next_node: BoardNode
		if options.size() == 1:
			next_node = options[0]
		else:
			next_node = await _ask_for_path(options)

		await _slide_to(next_node)
		_previous_node = current_node
		current_node = next_node
		steps_left -= 1
		step_finished.emit(current_node, steps_left)

	is_moving = false
	z_index = 0
	movement_finished.emit(current_node)


## Picks the path to take at a fork. `node` must be one of the spaces sent
## with `path_choice_required`; anything else is ignored.
func choose_path(node: BoardNode) -> void:
	if _chosen_node != null or not _pending_choices.has(node):
		push_warning("PlayerMovement: that space is not one of the offered paths.")
		return
	_chosen_node = node
	_path_chosen.emit()


## Returns true while movement is paused at a fork.
func is_waiting_for_choice() -> bool:
	return not _pending_choices.is_empty()


## Returns every space this player could stop on after `steps` more steps.
func get_landing_preview(steps: int) -> Array[BoardNode]:
	# Before a move starts, the player may be free to turn around. In the
	# middle of a move, they never are.
	var came_from := _previous_node
	if can_reverse_at_turn_start and not is_moving:
		came_from = null
	return board_manager.get_landing_nodes(current_node, steps, came_from)


## Slides the idle token slightly off the center of its space, so several
## tokens on one space stay visible. Vector2.ZERO puts it back in the center.
func set_rest_offset(offset: Vector2) -> void:
	if _rest_tween != null and _rest_tween.is_valid():
		_rest_tween.kill()
	_rest_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rest_tween.tween_property(self, "global_position",
			current_node.global_position + offset, 0.2)


# --- Internal helpers -------------------------------------------------------

func _ask_for_path(options: Array[BoardNode]) -> BoardNode:
	_chosen_node = null
	_pending_choices = options
	# Send a copy, so listeners cannot change the list being checked.
	path_choice_required.emit(options.duplicate())

	# A listener (an AI player, for example) may answer right away, during
	# emit(). Only wait if no choice has been made yet.
	if _chosen_node == null:
		await _path_chosen

	var chosen := _chosen_node
	_chosen_node = null
	_pending_choices = []
	return chosen


func _slide_to(node: BoardNode) -> void:
	if not is_equal_approx(node.global_position.x, global_position.x):
		_facing_left = node.global_position.x < global_position.x
	var tween := create_tween()
	# Sine easing starts and stops gently instead of moving at a fixed speed.
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# set_parallel() runs the slide and the hop at the same time.
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", node.global_position, step_duration)
	tween.tween_method(_set_hop, 0.0, 1.0, step_duration)
	if step_pause > 0.0:
		# chain() goes back to one-after-another for this last part.
		tween.chain().tween_interval(step_pause)
	await tween.finished


# `progress` goes from 0 to 1. sin() turns that into up, then back down.
func _set_hop(progress: float) -> void:
	_hop_offset = sin(progress * PI) * hop_height
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	# A flat ellipse under the character: a circle drawn with a squashed
	# transform. It stays on the ground during a hop, which is what makes the
	# hop readable.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RING_RADIUS + 3.0, Color(0.14, 0.09, 0.13, 0.85))
	draw_circle(Vector2.ZERO, RING_RADIUS, token_color)
	draw_set_transform(Vector2.ZERO)

	var top := -SPRITE_SIZE - 2.0 - _hop_offset
	var rect := Rect2(-SPRITE_SIZE * 0.5, top, SPRITE_SIZE, SPRITE_SIZE)
	if _facing_left:
		# A rectangle with a negative width draws the image mirrored.
		rect = Rect2(SPRITE_SIZE * 0.5, top, -SPRITE_SIZE, SPRITE_SIZE)
	GameArt.draw_tile(self, GameArt.DUNGEON, sprite_tile, rect)

	if steps_left > 0:
		GameArt.draw_centered_text(self, str(steps_left), Vector2(0, top - 16.0), 24)
