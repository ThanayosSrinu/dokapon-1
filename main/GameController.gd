class_name GameController
extends Node2D
## Connects the rules to what is on screen. TurnManager decides which phase the
## game is in, and this script does the work of each phase:
##   TURN_START     Announce the player and move the camera to their token.
##   ACTION         Wait for "Roll Dice".
##   ROLLING        Tumble the die, then show the landing rings.
##   MOVING         The token hops while the camera follows it.
##   CHOOSING_PATH  The paths glow green. Click one, or use its button.
##   SPACE_EVENT    Show the landed space. Sections 5 and 6 add real effects.
## Clicking any other space shows its details in the InfoLabel.
##
## Scene layout:
##   Main (Node2D, this script)
##   ├── WorldMap (BoardManager, from res://maps/WorldMap.tscn)
##   ├── Player1 ... Player4 (PlayerMovement, from res://player/Player.tscn)
##   ├── BoardCamera
##   ├── TurnManager
##   └── UI (CanvasLayer)
##       ├── InfoLabel (Label)
##       ├── TurnHud
##       ├── Dice (DiceRoller)
##       ├── Panel (PanelContainer)
##       │   └── VBox (VBoxContainer)
##       │       ├── StatusLabel (Label)
##       │       ├── RollButton (Button)
##       │       └── ChoiceBox (VBoxContainer)
##       ├── TurnBanner
##       └── SetupMenu

## Distance between a space's center and the tokens sharing it, in pixels.
const TOKEN_SPREAD := 30.0

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

## Every token in the scene. The setup menu decides how many are used, and the
## turn order is drawn at random when the game starts.
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

## The turn state machine. Drag the TurnManager node here.
@export var turn_manager: TurnManager

## Shows the calendar and turn order. Drag TurnHud here.
@export var hud: TurnHud

## Announces each turn. Drag TurnBanner here.
@export var banner: TurnBanner

## Asks how many players will play. Drag SetupMenu here.
@export var setup_menu: SetupMenu

## Seconds the landing preview is shown before the token starts moving.
@export var preview_duration := 0.7

## Seconds the landed space stays on screen before the turn ends.
@export var space_event_duration := 0.8

## How many players the computer controls, counted from the last token. Their
## choices are random until Section 9 adds real AI.
@export_range(0, 4) var cpu_players := 0

## Set above 0 to replay the game with that seed, which is printed to Output at
## the start of every game. 0 uses a new random seed.
@export var game_seed := 0

# PlayerData -> the token (PlayerMovement) on the board.
var _tokens := {}
# What happened on the last turn, shown above the next player's prompt.
var _previous_result := ""
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
			or info_label == null or dice == null or turn_manager == null
			or hud == null or banner == null or setup_menu == null):
		push_error("GameController: fill in every empty slot of Main in the Inspector.")
		return

	# The button's 'pressed' signal is meant to be connected in the editor
	# (Node dock -> Signals). Fall back to connecting it here so the game
	# still works if that step was skipped.
	if not roll_button.pressed.is_connected(_on_roll_button_pressed):
		push_warning("GameController: RollButton.pressed is not connected in the editor. "
				+ "Connecting it from code instead.")
		roll_button.pressed.connect(_on_roll_button_pressed)

	# Board clicks and phase changes arrive through the global EventBus autoload.
	EventBus.space_clicked.connect(_on_space_clicked)
	EventBus.phase_changed.connect(_on_phase_changed)
	setup_menu.player_count_chosen.connect(_start_game)

	camera.global_position = board.get_bounds().get_center()
	info_label.text = ("Click a space to inspect it.\n"
			+ "WASD / arrows: pan    Wheel: zoom    Right-drag: pan")

	roll_button.disabled = true
	_show_status("Choose the number of players.")
	_clear_choices()
	_arrange_tokens()


# --- Signal handlers --------------------------------------------------------

## Connected to RollButton's 'pressed' signal in the editor.
func _on_roll_button_pressed() -> void:
	# The phase is the only guard needed: it leaves ACTION right here, so a
	# second press cannot start a second roll.
	if turn_manager.phase != TurnManager.Phase.ACTION:
		return
	turn_manager.go_to(TurnManager.Phase.ROLLING)
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
	turn_manager.go_to(TurnManager.Phase.MOVING)
	# move_steps() runs over several frames. It returns right away here and
	# reports back later through the signals connected in _ready().
	player.move_steps(_last_roll)


func _on_step_finished(_node: BoardNode, steps_remaining: int) -> void:
	# Every step, and every choice at a fork, narrows down where the move ends.
	var player := _active_player()
	_set_landing_nodes(player.get_landing_preview(steps_remaining))
	_show_status("%s - Rolled %d\n%d step(s) left" % [_turn_title(), _last_roll, steps_remaining])


func _on_path_choice_required(available_nodes: Array[BoardNode]) -> void:
	turn_manager.go_to(TurnManager.Phase.CHOOSING_PATH)

	if turn_manager.current_player().is_cpu:
		_choose_path(available_nodes[GameState.rng.randi_range(0, available_nodes.size() - 1)])
		return

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
	if turn_manager.phase == TurnManager.Phase.CHOOSING_PATH and _path_options.has(node):
		_choose_path(node)
		return

	if _selected_node != null:
		_selected_node.highlighted = false
	_selected_node = node
	node.highlighted = true
	# During the rest of a turn, the camera stays with the token.
	if turn_manager.phase == TurnManager.Phase.ACTION:
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
	turn_manager.current_player().space_id = final_node.node_id
	var no_nodes: Array[BoardNode] = []
	_set_landing_nodes(no_nodes)
	_arrange_tokens()
	turn_manager.go_to(TurnManager.Phase.SPACE_EVENT)


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	match phase:
		TurnManager.Phase.TURN_START:
			_enter_turn_start()
		TurnManager.Phase.ACTION:
			_enter_action()
		TurnManager.Phase.SPACE_EVENT:
			_enter_space_event()


# --- Phases -----------------------------------------------------------------

func _enter_turn_start() -> void:
	var player := turn_manager.current_player()
	camera.follow(_active_player())
	_show_status(_after_previous_result(_turn_title()))
	await banner.play(_turn_title(), player.token_color)
	turn_manager.go_to(TurnManager.Phase.ACTION)


func _enter_action() -> void:
	if turn_manager.current_player().is_cpu:
		_on_roll_button_pressed()
		return

	_show_status(_after_previous_result("%s\nPress \"Roll Dice\"." % _turn_title()))
	roll_button.disabled = false
	# Give the button keyboard focus, so Space or Enter also rolls.
	roll_button.grab_focus()


func _enter_space_event() -> void:
	var player := _active_player()
	var space := player.current_node
	print("Week %d Day %d, %s: rolled %d, landed on space %d (%s)" % [
		GameState.get_week(), GameState.get_day_of_week(),
		player.player_name, _last_roll, space.node_id, space.get_type_name()])
	_previous_result = "%s landed on #%d %s.\n%s" % [
		player.player_name,
		space.node_id,
		space.get_display_name(),
		TYPE_DESCRIPTIONS.get(space.node_type, ""),
	]
	_show_status(_previous_result)
	await get_tree().create_timer(space_event_duration).timeout
	turn_manager.end_turn()


# --- Internal helpers -------------------------------------------------------

## Uses the first `player_count` tokens, removes the rest and starts day 1.
func _start_game(player_count: int) -> void:
	for unused_token in players.slice(player_count):
		unused_token.queue_free()
	players = players.slice(0, player_count)

	var roster: Array[PlayerData] = []
	for index in players.size():
		var token := players[index]
		var data := PlayerData.new(token.player_name, token.token_color,
				index >= player_count - cpu_players)
		data.sprite_tile = token.sprite_tile
		data.space_id = token.current_node.node_id
		roster.append(data)
		_tokens[data] = token
		# Only the active player ever moves, so one set of handlers works for
		# all of the tokens.
		token.step_finished.connect(_on_step_finished)
		token.movement_finished.connect(_on_movement_finished)
		token.path_choice_required.connect(_on_path_choice_required)

	GameState.start_new_game(roster, game_seed)
	hud.setup(GameState.players)
	hud.show()
	_arrange_tokens()
	turn_manager.start_game()


func _active_player() -> PlayerMovement:
	return _tokens[turn_manager.current_player()]


## "Red's turn", the first part of most status messages.
func _turn_title() -> String:
	return "%s's turn" % turn_manager.current_player().player_name


## Adds what happened last turn above `text`, once there is a last turn.
func _after_previous_result(text: String) -> String:
	if _previous_result == "":
		return text
	return "%s\n\n%s" % [_previous_result, text]


func _choose_path(node: BoardNode) -> void:
	# Clear first: choose_path() resumes the move immediately.
	for option in _path_options:
		option.is_path_choice = false
	_path_options = []
	_clear_choices()
	_show_status("%s - Rolled %d\nMoving..." % [_turn_title(), _last_roll])
	turn_manager.go_to(TurnManager.Phase.MOVING)
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
