class_name PlayerMovement
extends Node2D
## Moves a player token across the board, one space at a time.
##
## How to use it:
##   1. Drag the BoardManager node into `board_manager` in the Inspector.
##      The player then appears on the Castle space when the game starts.
##   2. Call move_steps() with a dice roll.
##   3. At a fork, movement pauses and `path_choice_required` is emitted.
##      Answer it by calling choose_path() with one of the offered spaces.
##   4. `movement_finished` is emitted when the player has stopped.

## Emitted when the player must pick which way to go. Movement stays paused
## until choose_path() is called with one of `available_nodes`.
signal path_choice_required(available_nodes: Array[BoardNode])

## Emitted once every step is used up and the token has stopped sliding.
signal movement_finished(final_node: BoardNode)

# Emitted by choose_path() to wake up a move that is waiting at a fork.
signal _path_chosen

## The board to walk on. Drag the BoardManager node here in the Inspector.
@export var board_manager: BoardManager

## Seconds the slide from one space to the next takes.
@export var step_duration := 0.35

## Short pause after each step, so single steps are easy to count.
@export var step_pause := 0.05

## When true, a new turn may start in any direction, even back the way the
## player came last turn. When false, the player keeps walking forward.
@export var can_reverse_at_turn_start := true

## The space the player is standing on.
var current_node: BoardNode

## True while move_steps() is running (sliding or waiting at a fork).
var is_moving := false

# The space the player stepped off last. Used to avoid walking straight back.
var _previous_node: BoardNode
# The spaces offered at the current fork. Empty when not waiting.
var _pending_choices: Array[BoardNode] = []
# The space picked through choose_path(), until move_steps() reads it.
var _chosen_node: BoardNode


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
	if can_reverse_at_turn_start:
		_previous_node = null

	var steps_left := steps
	while steps_left > 0:
		var options := board_manager.get_connected_nodes(current_node, _previous_node)
		if options.is_empty():
			# An isolated space: nowhere to go, so the move ends early.
			push_warning("PlayerMovement: space %d has no exits." % current_node.node_id)
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

	is_moving = false
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
	var tween := create_tween()
	# Sine easing starts and stops gently instead of moving at a fixed speed.
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", node.global_position, step_duration)
	if step_pause > 0.0:
		tween.tween_interval(step_pause)
	await tween.finished
