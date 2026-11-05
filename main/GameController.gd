class_name GameController
extends Node2D
## Runs the game for now. Each player takes one move in order:
##   1. The player clicks "Roll Dice" and the die tumbles.
##   2. Blue rings show every space the roll can end on.
##   3. The token hops that many spaces while the camera follows it.
##   4. At a fork, the possible paths glow green. Click a glowing space, or
##      click one of the path buttons, to continue.
##   5. When the token stops, the landed space is shown and the next player's
##      turn begins.
## Clicking any other space shows its details in the InfoLabel.
##
## A real Turn Manager replaces the simple player rotation here in Section 3.
##
## Scene layout:
##   Main (Node2D, this script)
##   ├── WorldMap (BoardManager, from res://maps/WorldMap.tscn)
##   ├── Player1 ... Player4 (PlayerMovement, from res://player/Player.tscn)
##   ├── BoardCamera
##   └── UI (CanvasLayer)
##       ├── InfoLabel (Label)
##       ├── Dice (DiceRoller)
##       └── Panel (PanelContainer)
##           └── VBox (VBoxContainer)
##               ├── StatusLabel (Label)
##               ├── RollButton (Button)
##               └── ChoiceBox (VBoxContainer)

## Distance between a space's center and the tokens sharing it, in pixels.
const TOKEN_SPREAD := 20.0

## A short line shown under the name of the space the player lands on.
const TYPE_DESCRIPTIONS := {
	BoardNode.NodeType.CASTLE: "Back home at the castle.",
	BoardNode.NodeType.NORMAL: "An ordinary space. Nothing happens.",
	BoardNode.NodeType.SHOP: "A shop! (Shopping is not implemented yet.)",
	BoardNode.NodeType.EVENT: "An event space! (Events are not implemented yet.)",
	BoardNode.NodeType.TOWN: "A town. (Towns are not implemented yet.)",
	BoardNode.NodeType.ITEM: "An item space. (Items are not implemented yet.)",
	BoardNode.NodeType.MAGIC: "A magic space. (Spells are not implemented yet.)",
	BoardNode.NodeType.GOLD: "A gold space. (Gold is not implemented yet.)",
	BoardNode.NodeType.BATTLE: "A monster appears! (Battles are not implemented yet.)",
	BoardNode.NodeType.TREASURE: "Treasure may be buried here. (Not implemented yet.)",
	BoardNode.NodeType.SHRINE: "A shrine. (Healing is not implemented yet.)",
	BoardNode.NodeType.TRAP: "A trap! (Traps are not implemented yet.)",
}

## Every player, in turn order. Remove entries to play with fewer players.
@export var players: Array[PlayerMovement] = []

## The "Roll Dice" button. Drag the RollButton node here in the Inspector.
@export var roll_button: Button

## Shows the dice result and the game status. Drag StatusLabel here.
@export var status_label: Label

## Gets one button per path while the player stands at a fork.
## Drag ChoiceBox here.
@export var choice_box: Container

## The board. Drag the WorldMap node here.
@export var board: BoardManager

## The camera that looks at the board. Drag BoardCamera here.
@export var camera: BoardCamera

## Shows details about the space that was clicked last. Drag InfoLabel here.
@export var info_label: Label

## The die shown at the bottom of the screen. Drag the Dice node here.
@export var dice: DiceRoller

## Seconds the landing preview is shown before the token starts moving.
@export var preview_duration := 0.7

# The round being played, starting at 1. A round is one move by each player.
var _turn := 1
# Index into `players` of the player whose move it is.
var _active_index := 0
# True from pressing "Roll Dice" until the token has stopped.
var _move_in_progress := false
# The result of the last dice roll, kept so every status message can show it.
var _last_roll := 0
# The space clicked last, so its highlight can be removed on the next click.
var _selected_node: BoardNode
# The spaces glowing green at the current fork.
var _path_options: Array[BoardNode] = []
# The spaces with a blue landing ring.
var _landing_nodes: Array[BoardNode] = []


func _ready() -> void:
	if (players.is_empty() or roll_button == null or status_label == null
			or choice_box == null or board == null or camera == null
			or info_label == null or dice == null):
		push_error("GameController: assign 'players', 'roll_button', 'status_label', "
				+ "'choice_box', 'board', 'camera', 'info_label' and 'dice' in the Inspector.")
		return

	# The button's 'pressed' signal is meant to be connected in the editor
	# (Node dock -> Signals). Fall back to connecting it here so the game
	# still works if that step was skipped.
	if not roll_button.pressed.is_connected(_on_roll_button_pressed):
		push_warning("GameController: RollButton.pressed is not connected in the editor. "
				+ "Connecting it from code instead.")
		roll_button.pressed.connect(_on_roll_button_pressed)

	# The players are created from their own scene file, so their signals are
	# connected here in code. Only the active player ever moves, so one set of
	# handlers works for all of them.
	for player in players:
		player.step_finished.connect(_on_step_finished)
		player.movement_finished.connect(_on_movement_finished)
		player.path_choice_required.connect(_on_path_choice_required)

	# Board clicks arrive through the global EventBus autoload.
	EventBus.space_clicked.connect(_on_space_clicked)

	camera.global_position = board.get_bounds().get_center()
	info_label.text = ("Click a space to inspect it.\n"
			+ "WASD / arrows: pan    Wheel: zoom    Right-drag: pan")

	_clear_choices()
	_arrange_tokens()
	_begin_turn()


# --- Signal handlers --------------------------------------------------------

## Connected to RollButton's 'pressed' signal in the editor.
func _on_roll_button_pressed() -> void:
	if _move_in_progress:
		return

	# Set these first, so nothing can start a second roll mid-move.
	_move_in_progress = true
	roll_button.disabled = true

	var player := _active_player()
	camera.follow(player)
	_show_status("%s\nRolling..." % _turn_title())
	_last_roll = await dice.roll()

	_show_status("%s\nRolled a %d!" % [_turn_title(), _last_roll])
	_set_landing_nodes(player.get_landing_preview(_last_roll))
	await get_tree().create_timer(preview_duration).timeout

	# The tokens left behind move back to the center of their space.
	_arrange_tokens(player)
	# move_steps() runs over several frames. It returns right away here and
	# reports back later through the signals connected in _ready().
	player.move_steps(_last_roll)


func _on_step_finished(_node: BoardNode, steps_remaining: int) -> void:
	# Every step, and every choice at a fork, narrows down where the move ends.
	var player := _active_player()
	_set_landing_nodes(player.get_landing_preview(steps_remaining))
	_show_status("%s - Rolled %d\n%d step(s) left" % [_turn_title(), _last_roll, steps_remaining])


func _on_path_choice_required(available_nodes: Array[BoardNode]) -> void:
	_show_status("%s - Rolled %d\nFork! Click a glowing space:" % [_turn_title(), _last_roll])
	_path_options = available_nodes
	for node in available_nodes:
		node.is_path_choice = true
		var button := Button.new()
		button.text = "#%d %s" % [node.node_id, node.get_display_name()]
		# bind() remembers which space this button stands for.
		button.pressed.connect(_choose_path.bind(node))
		choice_box.add_child(button)


func _on_space_clicked(node: BoardNode) -> void:
	# At a fork, clicking a glowing space picks that path.
	if _path_options.has(node):
		_choose_path(node)
		return

	if _selected_node != null:
		_selected_node.highlighted = false
	_selected_node = node
	node.highlighted = true
	# During a move, the camera stays with the token.
	if not _move_in_progress:
		camera.focus_on(node.global_position)

	var neighbor_texts := PackedStringArray()
	for neighbor in board.get_neighbors(node):
		neighbor_texts.append("#%d %s" % [neighbor.node_id, neighbor.get_display_name()])
	info_label.text = "Space #%d: %s\nType: %s\nNeighbors: %s" % [
		node.node_id,
		node.get_display_name(),
		node.get_type_name(),
		", ".join(neighbor_texts),
	]


func _on_movement_finished(final_node: BoardNode) -> void:
	var player := _active_player()
	print("%s: rolled %d, landed on space %d (%s)" % [
		player.player_name, _last_roll, final_node.node_id, final_node.get_type_name()])
	var no_nodes: Array[BoardNode] = []
	_set_landing_nodes(no_nodes)
	_arrange_tokens()

	var landed_text := "%s landed on #%d %s.\n%s" % [
		player.player_name,
		final_node.node_id,
		final_node.get_display_name(),
		TYPE_DESCRIPTIONS.get(final_node.node_type, ""),
	]

	# Move on to the next player. After the last one, wrap around to the first.
	_active_index = (_active_index + 1) % players.size()
	if _active_index == 0:
		_turn += 1
	_move_in_progress = false
	_begin_turn(landed_text)


# --- Internal helpers -------------------------------------------------------

func _active_player() -> PlayerMovement:
	return players[_active_index]


## "Turn 3 - Red", the first part of most status messages.
func _turn_title() -> String:
	return "Turn %d - %s" % [_turn, _active_player().player_name]


func _begin_turn(previous_result := "") -> void:
	var status := "%s\nPress \"Roll Dice\"." % _turn_title()
	if previous_result != "":
		status = previous_result + "\n\n" + status
	_show_status(status)
	camera.follow(_active_player())
	roll_button.disabled = false
	# Give the button keyboard focus, so Space or Enter also rolls.
	roll_button.grab_focus()


func _choose_path(node: BoardNode) -> void:
	# Clear first: choose_path() resumes the move immediately.
	for option in _path_options:
		option.is_path_choice = false
	_path_options = []
	_clear_choices()
	_show_status("%s - Rolled %d\nMoving..." % [_turn_title(), _last_roll])
	_active_player().choose_path(node)


## Replaces the blue landing rings with rings on `nodes`.
func _set_landing_nodes(nodes: Array[BoardNode]) -> void:
	for node in _landing_nodes:
		node.is_landing_spot = false
	_landing_nodes = nodes
	for node in nodes:
		node.is_landing_spot = true


## Spreads out tokens that share a space, so all of them stay visible.
## `moving_player` is left alone, because it is about to walk away.
func _arrange_tokens(moving_player: PlayerMovement = null) -> void:
	# Group the tokens by space: BoardNode -> Array of players.
	var groups := {}
	for player in players:
		if player != moving_player:
			if not groups.has(player.current_node):
				groups[player.current_node] = []
			groups[player.current_node].append(player)

	for group in groups.values():
		for index in group.size():
			var offset := Vector2.ZERO
			if group.size() > 1:
				# Share a full circle (TAU) equally between the tokens.
				offset = Vector2.RIGHT.rotated(TAU * index / group.size()) * TOKEN_SPREAD
			group[index].set_rest_offset(offset)


func _show_status(text: String) -> void:
	status_label.text = text


## Removes every path button from the ChoiceBox.
func _clear_choices() -> void:
	for child in choice_box.get_children():
		child.queue_free()
