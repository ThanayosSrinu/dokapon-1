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

## Radius of the colored ring at the character's feet.
const RING_RADIUS := 20.0
## How flat the ring lies on the ground.
const RING_SQUASH := 0.5
const RING_WIDTH := 4.0
## Height of the arrow and the step counter over the character's feet.
const HEAD_HEIGHT := 46.0
## The shadow that falls over whoever wears the Shadow Crown.
const CROWNED_TINT := Color(0.68, 0.55, 0.92)
# Moving tokens are drawn above idle ones, which are above the board.
const IDLE_Z_INDEX := 1
const MOVING_Z_INDEX := 10

## Frames of the character sheet: the columns of each animation.
const IDLE_FRAMES: Array[int] = [0, 1]
const WALK_FRAMES: Array[int] = [2, 0, 3, 1]
## The row of the sheet for each direction, clockwise from south. Index 0 is
## east, because that is angle 0 for Vector2.angle().
const ROW_BY_OCTANT: Array[int] = [2, 1, 0, 7, 6, 5, 4, 3]
const ROW_FACING_VIEWER := 0
const IDLE_FRAME_TIME := 0.45
const WALK_FRAME_TIME := 0.11

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

## This player's character sheet, from res://assets/puny/characters/.
@export var character_sheet: Texture2D

## Seconds the walk from one space to the next takes.
@export var step_duration := 0.62

## How high the character hops when it cheers, in pixels.
@export var hop_height := 26.0

## When true, a new turn may start in any direction, even back the way the
## player came last turn. When false, the player keeps walking forward.
@export var can_reverse_at_turn_start := true

## The space the player is standing on.
var current_node: BoardNode

## True while move_steps() is running (sliding or waiting at a fork).
var is_moving := false

## True while this player wears the Shadow Crown.
var is_crowned := false

## Steps still to walk in this move. Drawn above the token while moving.
var steps_left := 0:
	set(value):
		steps_left = value
		if _overlay != null:
			_overlay.queue_redraw()

## True while it is this player's turn: an arrow bounces over the character.
var is_active := false:
	set(value):
		is_active = value
		if _overlay != null:
			_overlay.queue_redraw()

# The space the player stepped off last. Used to avoid walking straight back.
var _previous_node: BoardNode
# The spaces offered at the current fork. Empty when not waiting.
var _pending_choices: Array[BoardNode] = []
# The space picked through choose_path(), until move_steps() reads it.
var _chosen_node: BoardNode
# The running set_rest_offset() animation.
var _rest_tween: Tween
# The character. It is a child, so it is always drawn above the ring.
var _sprite: Sprite2D
# Draws the arrow and the step counter, above the character.
var _overlay: Node2D
# The row of the character sheet in use.
var _row := ROW_FACING_VIEWER
# Seconds since the animation started, offset so players are not in step.
var _clock := 0.0


func _ready() -> void:
	z_index = IDLE_Z_INDEX
	_clock = randf() * 2.0
	_build_nodes()
	if board_manager == null:
		push_error("PlayerMovement: 'board_manager' is not set in the Inspector.")
		return
	# The board builds its spaces in its own _ready(). If that has not run yet
	# (for example, the player is above the board in the Scene tree), wait.
	if not board_manager.is_node_ready():
		await board_manager.board_ready
	spawn_at(board_manager.get_starting_node())


func _process(delta: float) -> void:
	_clock += delta
	var column: int
	if is_moving and not is_waiting_for_choice():
		column = WALK_FRAMES[int(_clock / WALK_FRAME_TIME) % WALK_FRAMES.size()]
	else:
		column = IDLE_FRAMES[int(_clock / IDLE_FRAME_TIME) % IDLE_FRAMES.size()]
	_sprite.frame_coords = Vector2i(column, _row)
	if is_active:
		_overlay.queue_redraw()


# --- Public API -------------------------------------------------------------

## Shows or hides the Shadow Crown on this token.
func set_crowned(crowned: bool) -> void:
	is_crowned = crowned
	_sprite.modulate = CROWNED_TINT if crowned else Color.WHITE
	_overlay.queue_redraw()


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
	z_index = IDLE_Z_INDEX
	_row = ROW_FACING_VIEWER
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
## `depth` keeps the token further down the screen in front of the others.
func set_rest_offset(offset: Vector2, depth := 0) -> void:
	z_index = IDLE_Z_INDEX + depth
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
	_face(node.global_position - global_position)
	# The same speed all the way, so one step runs smoothly into the next.
	var tween := create_tween()
	tween.tween_property(self, "global_position", node.global_position, step_duration)
	await tween.finished
	node.bump()
	BoardFx.dust(get_parent(), node.global_position)


# Picks the row of the sheet for walking along `direction`.
func _face(direction: Vector2) -> void:
	# Eight directions, so each covers an eighth of a circle around its angle.
	var octant := wrapi(int(round(direction.angle() / (TAU / 8.0))), 0, 8)
	_row = ROW_BY_OCTANT[octant]


## Makes the character jump for joy on the space it landed on.
func cheer() -> void:
	var tween := create_tween()
	for bounce in 2:
		tween.tween_method(_set_hop, 0.0, 1.0, 0.28)
	await tween.finished


# `progress` goes from 0 to 1. sin() turns that into up, then back down.
func _set_hop(progress: float) -> void:
	_sprite.position.y = -round(sin(progress * PI) * hop_height / GameArt.PIXEL) * GameArt.PIXEL


# --- Drawing ----------------------------------------------------------------

func _build_nodes() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = character_sheet
	_sprite.hframes = GameArt.CHARACTER_COLUMNS
	_sprite.vframes = GameArt.CHARACTER_ROWS
	_sprite.centered = false
	# Puts the point between the character's feet exactly on this node's origin,
	# the center of the ring, in every frame.
	_sprite.offset = -GameArt.CHARACTER_FEET
	_sprite.scale = Vector2.ONE * GameArt.PIXEL
	add_child(_sprite)

	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _draw() -> void:
	# The ring lies flat on the ground under the character, so this node draws
	# it, and the character, a child node, covers it.
	var ring_scale := Vector2(1.0, RING_SQUASH)
	draw_set_transform(Vector2.ZERO, 0.0, ring_scale)
	draw_circle(Vector2.ZERO, RING_RADIUS, Color(0.0, 0.0, 0.0, 0.35))
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 40, GameArt.INK, RING_WIDTH + 4.0)
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 40, token_color, RING_WIDTH)
	draw_set_transform(Vector2.ZERO)


func _draw_overlay() -> void:
	if is_crowned:
		var crown_size := GameArt.SHADOW_CROWN.get_size() * GameArt.PIXEL
		_overlay.draw_texture_rect(GameArt.SHADOW_CROWN,
				Rect2(Vector2(-crown_size.x * 0.5, -HEAD_HEIGHT - crown_size.y + 12.0), crown_size), false)
	if steps_left > 0:
		GameArt.draw_plate(_overlay, str(steps_left), Vector2(0, -HEAD_HEIGHT - 16.0), 24)
	elif is_active and not is_moving:
		var bounce: float = round(sin(_clock * 6.0) * 2.0) * GameArt.PIXEL
		var arrow_size := Vector2.ONE * 16.0 * GameArt.PIXEL
		_overlay.draw_texture_rect_region(GameArt.FX,
				Rect2(Vector2(-arrow_size.x * 0.5, -HEAD_HEIGHT - 32.0 + bounce), arrow_size),
				Rect2(0, 48, 16, 16))
