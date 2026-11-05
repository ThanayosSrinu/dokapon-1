class_name GameController
extends Node2D
## Connects the rules to what is on screen. TurnManager decides which phase the
## game is in, and this script does the work of each phase:
##   TURN_START     Announce the player and move the camera to their token.
##   ACTION         Wait for "Roll Dice".
##   ROLLING        Tumble the die, then show the landing rings.
##   MOVING         The token walks while the camera follows it.
##   CHOOSING_PATH  The paths glow green. Click one, or use its button.
##   SPACE_EVENT    Celebrate the landed space. Sections 5 and 6 add real effects.
## Press C or the Character button to open the active player's sheet.
## Clicking any other space shows its details in the InfoLabel.
##
## Scene layout:
##   Main (Node2D, this script)
##   ├── WorldMap (BoardManager, from res://maps/WorldMap.tscn)
##   ├── Player1 ... Player4 (PlayerMovement, from res://player/Player.tscn)
##   ├── BoardCamera
##   ├── TurnManager
##   └── UI (CanvasLayer)
##       ├── TurnHud
##       ├── InfoPanel (PanelContainer) -> InfoLabel
##       ├── Panel (PanelContainer, the message window)
##       │   └── Row (HBoxContainer)
##       │       ├── StatusLabel (Label)
##       │       └── Side (VBoxContainer)
##       │           ├── RollButton (Button)
##       │           └── ChoiceBox (VBoxContainer)
##       ├── Dice (DiceRoller)
##       ├── TurnBanner
##       ├── SetupMenu
##       └── Fade (ColorRect)

## Where tokens stand when they share a space, by how many there are. Each one
## stays inside the top of the space.
const TOKEN_SLOTS := {
	1: [Vector2.ZERO],
	2: [Vector2(-22, 0), Vector2(22, 0)],
	3: [Vector2(0, -10), Vector2(-22, 10), Vector2(22, 10)],
	4: [Vector2(-22, -10), Vector2(22, -10), Vector2(-22, 10), Vector2(22, 10)],
}
## Characters written per second in the message window.
const TEXT_SPEED := 70.0
## Which of BoardCamera.ZOOM_LEVELS shows the whole island, and which is normal.
const OVERVIEW_ZOOM := 0
const PLAY_ZOOM := 1

## A short line shown under the name of the space the player lands on.
const TYPE_DESCRIPTIONS := {
	BoardNode.NodeType.CASTLE: "Back home at the castle.",
	BoardNode.NodeType.NORMAL: "An ordinary space. Nothing happens.",
	BoardNode.NodeType.SHOP: "A shop! (Shopping is not implemented yet.)",
	BoardNode.NodeType.EVENT: "An event space! (Events are not implemented yet.)",
	BoardNode.NodeType.TOWN: "A town. (Towns are not implemented yet.)",
	BoardNode.NodeType.ITEM: "An item space.",
	BoardNode.NodeType.MAGIC: "A magic space. (Spells are not implemented yet.)",
	BoardNode.NodeType.GOLD: "A gold space.",
	BoardNode.NodeType.BATTLE: "A monster appears! (Real battles arrive in Section 5.)",
	BoardNode.NodeType.TREASURE: "Treasure may be buried here. (Not implemented yet.)",
	BoardNode.NodeType.SHRINE: "A shrine. (Healing is not implemented yet.)",
	BoardNode.NodeType.TRAP: "A trap! (Traps are not implemented yet.)",
}

## Placeholder rewards until Sections 5 and 6 give these spaces real effects.
const GOLD_SPACE_REWARD := 50
const BATTLE_SPACE_EXPERIENCE := 60

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

## Asks each human player for a class. Drag ClassMenu here.
@export var class_menu: ClassMenu

## Shows a player's stats, items and spells. Drag CharacterSheet here.
@export var character_sheet: CharacterSheet

## Opens the character sheet. Drag CharacterButton here.
@export var character_button: Button

## Seconds the landing preview is shown before the token starts moving.
@export var preview_duration := 0.7

## Seconds the landed space stays on screen before the turn ends.
@export var space_event_duration := 0.8

## How many players the computer controls, counted from the last token. Their
## choices are random until Section 9 adds real AI.
@export_range(0, 4) var cpu_players := 0

## The black cover that fades away at the start. Drag Fade here.
@export var fade: ColorRect

## The message window, hidden until the game starts. Drag Panel here.
@export var message_window: Control

## The box of details about a space, hidden until the game starts. Drag InfoPanel here.
@export var info_panel: Control

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
# The spaces with a gold landing ring.
var _landing_nodes: Array[BoardNode] = []
# The message being written out.
var _text_tween: Tween
# The pulse of the Roll Dice button while it waits.
var _button_tween: Tween


func _ready() -> void:
	if (players.is_empty() or roll_button == null or status_label == null
			or choice_box == null or board == null or camera == null
			or info_label == null or dice == null or turn_manager == null
			or hud == null or banner == null or setup_menu == null or fade == null
			or message_window == null or info_panel == null or class_menu == null
			or character_sheet == null or character_button == null):
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
	character_button.pressed.connect(_open_character_sheet)
	character_sheet.hidden.connect(_on_character_sheet_hidden)

	camera.world_limit = board.get_world_rect()
	camera.global_position = board.get_bounds().get_center()
	camera.zoom = Vector2.ONE * BoardCamera.ZOOM_LEVELS[OVERVIEW_ZOOM]
	camera.set_zoom_index(OVERVIEW_ZOOM, 0.0)
	info_label.text = ("Click a space to inspect it.\n"
			+ "WASD or arrows: pan\nWheel: zoom\nRight-drag: pan")

	message_window.hide()
	info_panel.hide()
	fade.show()
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.8)
	tween.tween_callback(fade.hide)

	roll_button.disabled = true
	_show_status("Choose the number of players.")
	_clear_choices()
	_arrange_tokens()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and character_sheet.visible:
		character_sheet.close_sheet()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if character_sheet.visible:
			character_sheet.close_sheet()
		else:
			_open_character_sheet()


# --- Signal handlers --------------------------------------------------------

## Connected to RollButton's 'pressed' signal in the editor.
func _on_roll_button_pressed() -> void:
	# The phase is the only guard needed: it leaves ACTION right here, so a
	# second press cannot start a second roll.
	if turn_manager.phase != TurnManager.Phase.ACTION:
		return
	turn_manager.go_to(TurnManager.Phase.ROLLING)
	_stop_button_pulse()
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
	# The active token walks from the middle of its space.
	player.set_rest_offset(Vector2.ZERO)
	player.is_active = false
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
	roll_button.hide()
	for node in available_nodes:
		node.is_path_choice = true
		var button := Button.new()
		button.text = "%s: %s" % [_direction_name(_active_player().current_node, node),
				node.get_display_name()]
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
	# A PanelContainer never shrinks by itself when its text gets shorter.
	info_panel.reset_size()


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
	_active_player().is_active = true
	_show_status(_after_previous_result(_turn_title()))
	await banner.play(_turn_title(), player.token_color, player.character_sheet)
	turn_manager.go_to(TurnManager.Phase.ACTION)


func _enter_action() -> void:
	if turn_manager.current_player().is_cpu:
		_on_roll_button_pressed()
		return

	_show_status(_after_previous_result("%s\nPress \"Roll Dice\"." % _turn_title()))
	roll_button.disabled = false
	# Give the button keyboard focus, so Space or Enter also rolls.
	roll_button.grab_focus()
	_start_button_pulse()


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
	var reward := _give_placeholder_reward(space)
	if reward != "":
		_previous_result += " " + reward
	_show_status(_previous_result)
	space.bump(1.6)
	BoardFx.burst(board, space.global_position, BoardNode.TYPE_INFO[space.node_type]["color"])
	if space.node_type == BoardNode.NodeType.BATTLE or space.node_type == BoardNode.NodeType.TRAP:
		camera.shake()
	player.cheer()
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
		data.character_sheet = token.character_sheet
		data.space_id = token.current_node.node_id
		roster.append(data)
		_tokens[data] = token
		# Only the active player ever moves, so one set of handlers works for
		# all of the tokens.
		token.step_finished.connect(_on_step_finished)
		token.movement_finished.connect(_on_movement_finished)
		token.path_choice_required.connect(_on_path_choice_required)

	GameState.start_new_game(roster, game_seed)
	for player in GameState.players:
		if player.is_cpu:
			var ids := Database.sorted_ids(Database.classes)
			player.choose_class(ids[GameState.rng.randi_range(0, ids.size() - 1)])
		else:
			player.choose_class(await class_menu.ask(player))
		print("%s is a %s" % [player.player_name, player.get_class_name_text()])

	hud.setup(GameState.players)
	hud.show()
	_arrange_tokens()
	_slide_in_windows()
	camera.set_zoom_index(PLAY_ZOOM, 0.9)
	turn_manager.start_game()


## Temporary: lets stats and items change before battles and shops exist.
## Returns a line for the message window, or "" if nothing happened.
func _give_placeholder_reward(space: BoardNode) -> String:
	var player := turn_manager.current_player()
	match space.node_type:
		BoardNode.NodeType.GOLD:
			player.add_gold(GOLD_SPACE_REWARD)
			return "Found %d gold." % GOLD_SPACE_REWARD
		BoardNode.NodeType.BATTLE:
			var levels := player.add_experience(BATTLE_SPACE_EXPERIENCE)
			if levels > 0:
				return "Level up! Now level %d." % player.level
			return "Gained %d EXP." % BATTLE_SPACE_EXPERIENCE
		BoardNode.NodeType.ITEM:
			var ids := Database.sorted_ids(Database.items)
			var item_id := ids[GameState.rng.randi_range(0, ids.size() - 1)]
			var item_name := Database.get_item(item_id).display_name
			if player.add_item(item_id):
				return "Found a %s." % item_name
			return "Found a %s, but the bag is full." % item_name
	return ""


## Only the active human player may change things, and only before rolling.
func _open_character_sheet() -> void:
	# The HUD appears once every player has a class.
	if not hud.visible:
		return
	var player := turn_manager.current_player()
	character_sheet.open(player, not player.is_cpu and turn_manager.phase == TurnManager.Phase.ACTION)


func _on_character_sheet_hidden() -> void:
	if turn_manager.phase == TurnManager.Phase.ACTION and not turn_manager.current_player().is_cpu:
		roll_button.grab_focus()


## Brings the message window up from below and the info box in from the right.
func _slide_in_windows() -> void:
	message_window.show()
	info_panel.show()
	var window_y := message_window.position.y
	var panel_x := info_panel.position.x
	message_window.position.y += message_window.size.y + 24.0
	info_panel.position.x += info_panel.size.x + 24.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_window, "position:y", window_y, 0.5)
	tween.tween_property(info_panel, "position:x", panel_x, 0.5)


func _active_player() -> PlayerMovement:
	return _tokens[turn_manager.current_player()]


## "Red's turn", the first part of most status messages.
func _turn_title() -> String:
	return "%s's turn" % turn_manager.current_player().player_name


## Adds what happened last turn above `text`, once there is a last turn.
func _after_previous_result(text: String) -> String:
	if _previous_result == "":
		return text
	return "%s\n%s" % [_previous_result, text]


func _choose_path(node: BoardNode) -> void:
	# Clear first: choose_path() resumes the move immediately.
	for option in _path_options:
		option.is_path_choice = false
	_path_options = []
	_clear_choices()
	roll_button.show()
	_show_status("%s - Rolled %d\nMoving..." % [_turn_title(), _last_roll])
	turn_manager.go_to(TurnManager.Phase.MOVING)
	_active_player().choose_path(node)


## "North", "South-East" and so on: which way `to` lies from `from`.
func _direction_name(from: BoardNode, to: BoardNode) -> String:
	var direction := (to.global_position - from.global_position).normalized()
	var name_parts := PackedStringArray()
	if absf(direction.y) > 0.38:
		name_parts.append("North" if direction.y < 0.0 else "South")
	if absf(direction.x) > 0.38:
		name_parts.append("West" if direction.x < 0.0 else "East")
	return "-".join(name_parts)


## Replaces the landing rings with rings on `nodes`.
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
		var slots: Array = TOKEN_SLOTS[group.size()]
		for index in group.size():
			var slot: Vector2 = slots[index]
			# The lower slots are nearer to the viewer, so they are drawn in front.
			group[index].set_rest_offset(slot, 1 if slot.y > 0.0 else 0)


## Writes `text` into the message window one letter at a time.
func _show_status(text: String) -> void:
	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()
	status_label.text = text
	status_label.visible_ratio = 0.0
	_text_tween = create_tween()
	_text_tween.tween_property(status_label, "visible_ratio", 1.0, text.length() / TEXT_SPEED)


func _start_button_pulse() -> void:
	_stop_button_pulse()
	_button_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_button_tween.tween_property(roll_button, "modulate", Color(1.35, 1.25, 1.0), 0.5)
	_button_tween.tween_property(roll_button, "modulate", Color.WHITE, 0.5)


func _stop_button_pulse() -> void:
	if _button_tween != null and _button_tween.is_valid():
		_button_tween.kill()
	roll_button.modulate = Color.WHITE


## Removes every path button from the ChoiceBox.
func _clear_choices() -> void:
	for child in choice_box.get_children():
		child.queue_free()
