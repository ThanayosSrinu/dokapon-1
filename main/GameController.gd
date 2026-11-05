class_name GameController
extends Node2D
## Connects the rules to what is on screen. TurnManager decides which phase the
## game is in, and this script does the work of each phase:
##   TURN_START     Announce the player and move the camera to their token.
##   ACTION         Wait for "Roll Dice".
##   ROLLING        Tumble the die, then show the landing rings.
##   MOVING         The token walks while the camera follows it.
##   CHOOSING_PATH  The paths glow green. Click one, or use its button.
##   SPACE_EVENT    Offer to fight anyone on the space. If nobody is challenged,
##                  the space takes effect. SpaceEffects, Events, Shop and Town hold
##                  the rules.
##   BATTLE         BattleScreen plays the fight. Rivalry settles a duel afterwards.
## During ACTION a player may also cast one field spell (FieldMagic.gd).
## CPU players take every turn the same way, and CpuBrain.gd makes their choices.
## Each new week pays the owners of towns, posts a royal quest (Quest.gd) and checks
## on the Shadow Crown (ShadowCrown.gd).
## Press C or the Character button to open the active player's sheet, and R or
## the Standings button to see who is ahead.
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
##       ├── BattleScreen
##       ├── ShopScreen
##       ├── BagPrompt
##       ├── StandingsScreen
##       └── Fade (ColorRect)

## Emitted by the buttons from _ask(), with the value of the one pressed.
signal _choice_made(value: Variant)

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
	BoardNode.NodeType.SHOP: "A shop, with new stock every week.",
	BoardNode.NodeType.EVENT: "The wind changes. Anything could happen here.",
	BoardNode.NodeType.TOWN: "One of the towns of the realm.",
	BoardNode.NodeType.ITEM: "Something glints on the ground.",
	BoardNode.NodeType.MAGIC: "The air hums with old magic.",
	BoardNode.NodeType.GOLD: "Coins shine in the dirt.",
	BoardNode.NodeType.BATTLE: "Something stirs nearby...",
	BoardNode.NodeType.TREASURE: "A chest sits here, and something may guard it.",
	BoardNode.NodeType.SHRINE: "A shrine that restores HP and MP.",
	BoardNode.NodeType.TRAP: "Something is wrong with this ground...",
}

const GOLD_TEXT_COLOR := Color(0.96, 0.82, 0.42)
const LOSS_TEXT_COLOR := Color(1.0, 0.55, 0.5)
const EVENT_COLOR := Color(0.62, 0.42, 0.90)

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

## Plays fights. Drag BattleScreen here.
@export var battle_screen: BattleScreen

## Buying and selling. Drag ShopScreen here.
@export var shop_screen: ShopScreen

## Asks what to drop when the bag is full. Drag BagPrompt here.
@export var bag_prompt: BagPrompt

## Shows who is ahead. Drag StandingsScreen here.
@export var standings_screen: StandingsScreen

## Opens the standings. Drag StandingsButton here.
@export var standings_button: Button

## Casts field magic. Drag FieldButton here.
@export var field_button: Button

## Seconds the landing preview is shown before the token starts moving.
@export var preview_duration := 0.7

## Seconds the landed space stays on screen before the turn ends.
@export var space_event_duration := 0.8

## How many players the computer controls, counted from the last token. The setup
## menu overwrites this. CpuBrain makes their choices.
@export_range(0, 4) var cpu_players := 0

## How well they play. The setup menu overwrites this too.
@export var cpu_level := CpuBrain.Level.NORMAL

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
# True if the space just played hurt the active player, so nobody cheers.
var _landing_went_badly := false
# A quest won on the way, to add to the landing message.
var _quest_news := ""
# True once the active player has cast field magic this turn.
var _field_cast := false
# What the Shadow Crown just did, for a banner before the next turn.
var _crown_news := ""
# The portrait for that banner.
var _crown_face: Texture2D


func _ready() -> void:
	if (players.is_empty() or roll_button == null or status_label == null
			or choice_box == null or board == null or camera == null
			or info_label == null or dice == null or turn_manager == null
			or hud == null or banner == null or setup_menu == null or fade == null
			or message_window == null or info_panel == null or class_menu == null
			or character_sheet == null or character_button == null or battle_screen == null
			or shop_screen == null or bag_prompt == null or standings_screen == null
			or standings_button == null or field_button == null):
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
	EventBus.day_started.connect(_on_day_started)
	setup_menu.cpus_chosen.connect(_on_cpus_chosen)
	setup_menu.player_count_chosen.connect(_start_game)
	character_button.pressed.connect(_open_character_sheet)
	character_sheet.hidden.connect(_on_character_sheet_hidden)
	standings_button.pressed.connect(_open_standings)
	field_button.pressed.connect(_open_field_magic)
	standings_screen.hidden.connect(_on_character_sheet_hidden)

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
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if standings_screen.visible:
			standings_screen.hide()
		else:
			_open_standings()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_open_field_magic()


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

	field_button.hide()

	var player := _active_player()
	var data := turn_manager.current_player()
	camera.follow(player)
	_show_status("%s\nRolling..." % _turn_title())
	var rolled: int = await dice.roll()
	var bonus := data.take_roll_bonus() + ShadowCrown.roll_bonus(data)
	_last_roll = maxi(rolled + bonus, 1)

	if bonus == 0:
		_show_status("%s\nRolled a %d!" % [_turn_title(), _last_roll])
	else:
		_show_status("%s\nRolled a %d, %+d: %d step(s)!" % [_turn_title(), rolled, bonus, _last_roll])
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


func _on_step_finished(node: BoardNode, steps_remaining: int) -> void:
	# Every step, and every choice at a fork, narrows down where the move ends.
	var player := _active_player()
	_set_landing_nodes(player.get_landing_preview(steps_remaining))
	if node.node_type == BoardNode.NodeType.TOWN:
		_quest_news += _advance_quest(turn_manager.current_player(), Quest.Kind.VISIT, node.node_id)
	_show_status("%s - Rolled %d\n%d step(s) left" % [_turn_title(), _last_roll, steps_remaining])


func _on_path_choice_required(available_nodes: Array[BoardNode]) -> void:
	turn_manager.go_to(TurnManager.Phase.CHOOSING_PATH)

	if turn_manager.current_player().is_cpu:
		var token := _active_player()
		_choose_path(CpuBrain.choose_path(turn_manager.current_player(), board, available_nodes,
				token.current_node, token.steps_left))
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
	var about: String = TYPE_DESCRIPTIONS.get(node.node_type, "")
	if GameState.towns.has(node.node_id):
		about = _town_text(node.node_id)
	info_label.text = "Space #%d: %s\nType: %s\n%s\nNeighbors: %s" % [
		node.node_id,
		node.get_display_name(),
		node.get_type_name(),
		about,
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


func _on_cpus_chosen(count: int, level: CpuBrain.Level) -> void:
	cpu_players = count
	cpu_level = level


## Each week begins by paying the town owners, posting a new quest and checking on
## the Shadow Crown.
func _on_day_started(_day: int) -> void:
	if GameState.get_day_of_week() != 1:
		return
	var payments := PackedStringArray()
	var paid := Town.collect_income()
	for player: PlayerData in paid:
		payments.append("%s %d G" % [player.player_name, paid[player]])
		BoardFx.pop_text(board, _tokens[player].global_position, "+%d G" % paid[player], GOLD_TEXT_COLOR)
	Quest.new_week()
	hud.refresh()
	_previous_result = "Week %d. Royal quest: %s, for %d G." % [GameState.get_week(),
			Quest.task_text(), GameState.quest["reward"]]
	if not payments.is_empty():
		_previous_result += "\nTown income: %s." % ", ".join(payments)
	_update_crown(ShadowCrown.weekly_check())


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	field_button.hide()
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
	_field_cast = false
	_show_status(_after_previous_result(_turn_title()))
	if _crown_news != "":
		var news := _crown_news
		_crown_news = ""
		await banner.play(news, ShadowCrown.COLOR, _crown_face)
	if player.turns_to_skip > 0:
		player.turns_to_skip -= 1
		await banner.play("%s rests" % player.player_name, player.token_color, player.character_sheet)
		_previous_result = "%s sat out a turn." % player.player_name
		_active_player().is_active = false
		turn_manager.end_turn()
		return
	await banner.play(_turn_title(), player.token_color, player.character_sheet)
	if ShadowCrown.is_worn_by(player):
		BoardFx.pop_text(board, _active_player().global_position,
				"-%d HP" % ShadowCrown.drain(player), LOSS_TEXT_COLOR)
	turn_manager.go_to(TurnManager.Phase.ACTION)


func _enter_action() -> void:
	var data := turn_manager.current_player()
	if data.is_cpu:
		var used := CpuBrain.tidy(data)
		if not used.is_empty():
			_previous_result = "%s used %s." % [data.player_name, ", ".join(used)]
			_show_status(_previous_result)
		var plan := CpuBrain.field_plan(data, board, _active_player().get_came_from())
		if not plan.is_empty():
			await _cast_field_spell(data, plan["spell"], plan["target"])
		_on_roll_button_pressed()
		return
	_wait_for_roll()


## Shows the prompt and lets the human player act.
func _wait_for_roll() -> void:
	var data := turn_manager.current_player()
	var coming := data.roll_bonus + ShadowCrown.roll_bonus(data)
	var note := "" if coming == 0 else " Your roll gets %+d." % coming
	_show_status(_after_previous_result("%s\nPress \"Roll Dice\".%s" % [_turn_title(), note]))
	roll_button.disabled = false
	field_button.visible = not _field_cast and not FieldMagic.known(data).is_empty()
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
	_previous_result += _quest_news
	_quest_news = ""
	_show_status(_previous_result)
	space.bump(1.6)
	BoardFx.burst(board, space.global_position, BoardNode.TYPE_INFO[space.node_type]["color"])

	# A rival comes first, and challenging one gives up the space's effect.
	_landing_went_badly = false
	var data := turn_manager.current_player()
	var rival := await _ask_about_rivals(space)
	if rival != null:
		await _play_battle(Battle.new(Fighter.from_player(data), Fighter.from_player(rival)))
	else:
		await _play_space(space)
	if not _landing_went_badly:
		player.cheer()
	await get_tree().create_timer(space_event_duration).timeout
	turn_manager.end_turn()


## Does what the active player's space does.
func _play_space(space: BoardNode) -> void:
	var data := turn_manager.current_player()
	match space.node_type:
		BoardNode.NodeType.GOLD:
			await _apply_result(SpaceEffects.gold_space(data))
		BoardNode.NodeType.ITEM:
			await _apply_result(SpaceEffects.item_space(data))
		BoardNode.NodeType.MAGIC:
			await _apply_result(SpaceEffects.magic_space(data))
		BoardNode.NodeType.SHRINE:
			await _apply_result(SpaceEffects.shrine_space(data))
		BoardNode.NodeType.TRAP:
			await _apply_result(SpaceEffects.trap_space(data))
		BoardNode.NodeType.EVENT:
			await _play_event()
		BoardNode.NodeType.SHOP:
			await _visit_shop(space)
		BoardNode.NodeType.TREASURE:
			await _visit_chest(space)
		BoardNode.NodeType.TOWN:
			await _visit_town(space)
		BoardNode.NodeType.BATTLE:
			await _play_battle(Battle.new(Fighter.from_player(data), Fighter.from_monster(_pick_monster(data))))


## Draws an event, shows its banner, and fights if it is an ambush.
func _play_event() -> void:
	var data := turn_manager.current_player()
	var spaces: Array[int] = []
	for node in board.get_all_nodes():
		spaces.append(node.node_id)
	var result := Events.draw(data, spaces)
	await banner.play(result.title, EVENT_COLOR, data.character_sheet)
	await _apply_result(result)
	if result.guardian != null:
		await _play_battle(Battle.new(Fighter.from_player(data), Fighter.from_monster(result.guardian)))


## Pays out a Result and shows it in the message window.
func _apply_result(result: SpaceEffects.Result) -> void:
	var data := turn_manager.current_player()
	var token := _active_player()
	_previous_result += " " + result.text
	_show_status(_previous_result)
	if result.harmful:
		_landing_went_badly = true
		camera.shake()
	if result.gold != 0:
		data.add_gold(result.gold)
		BoardFx.pop_text(board, token.global_position, "%+d G" % result.gold,
				GOLD_TEXT_COLOR if result.gold > 0 else LOSS_TEXT_COLOR)
	if result.item_id != "":
		await _give_item(data, result.item_id)
	for player: PlayerData in result.gold_changes:
		var change: int = result.gold_changes[player]
		player.add_gold(change)
		BoardFx.pop_text(board, _tokens[player].global_position, "%+d G" % change,
				GOLD_TEXT_COLOR if change > 0 else LOSS_TEXT_COLOR)
	if result.town_id >= 0:
		_show_town(board.get_board_node(result.town_id))
	if result.warp_to >= 0:
		_warp(data, board.get_board_node(result.warp_to))
	if result.to_castle:
		_send_to_castle(data)


## Puts an item in the bag, asking what to drop if the bag is full.
func _give_item(data: PlayerData, item_id: String) -> void:
	var item_name := Database.get_item(item_id).display_name
	if data.add_item(item_id):
		BoardFx.pop_text(board, _active_player().global_position, item_name, Color.WHITE)
		return
	var kept := false
	if data.is_cpu:
		var dropped := SpaceEffects.cpu_make_room(data, item_id)
		kept = dropped != "" and data.add_item(item_id)
	else:
		kept = await bag_prompt.ask(data, item_id)
	if kept:
		_previous_result += " It went in the bag."
	else:
		_previous_result += " It was left behind."
	_show_status(_previous_result)


## People browse the ShopScreen. CPU players buy what they need straight away.
func _visit_shop(space: BoardNode) -> void:
	var data := turn_manager.current_player()
	if ShadowCrown.is_worn_by(data):
		_say("The shopkeeper sees the Shadow Crown and bars the door.")
		return
	var shelves := Shop.stock(space.node_id, GameState.get_week())
	var line := ""
	if data.is_cpu:
		var bought := CpuBrain.shop(data, shelves)
		line = "%s bought %s." % [data.player_name, ", ".join(bought)] if not bought.is_empty() \
				else "%s found nothing to buy." % data.player_name
	else:
		line = await shop_screen.run(data, shelves, space.get_display_name())
	_previous_result += " " + line
	_show_status(_previous_result)


## Offers the chest, fights its guardian if it has one, then pays out.
func _visit_chest(space: BoardNode) -> void:
	var data := turn_manager.current_player()
	if not SpaceEffects.chest_is_full(space.node_id):
		var days := SpaceEffects.chest_days_left(space.node_id)
		_previous_result += " It is empty. It fills again in %d day(s)." % days
		_show_status(_previous_result)
		return
	var opened: Variant = CpuBrain.will_open_chest(data)
	if not data.is_cpu:
		opened = await _ask("%s\nOpen the chest?" % _previous_result,
				[["Open it", true], ["Leave it", false]])
	if not opened:
		return
	var chest := SpaceEffects.roll_chest(data)
	if chest.guardian != null:
		_show_status("%s\nThe %s guards it!" % [_previous_result, chest.guardian.display_name])
		var battle := Battle.new(Fighter.from_player(data), Fighter.from_monster(chest.guardian))
		await _play_battle(battle)
		if not _won(battle, data):
			return
	SpaceEffects.empty_chest(space.node_id)
	await _apply_result(chest)


## Does what a town does for whoever stopped there.
func _visit_town(space: BoardNode) -> void:
	var town_owner := Town.owner_of(space.node_id)
	if town_owner == null:
		await _free_town(space)
	elif town_owner == turn_manager.current_player():
		await _manage_town(space)
	else:
		await _enter_rival_town(space, town_owner)


## Offers a fight with the monster holding the town. The winner owns it.
func _free_town(space: BoardNode) -> void:
	var data := turn_manager.current_player()
	var id := space.node_id
	var guard := Town.guard(id)
	var line := "%s (level %d) holds %s." % [guard.display_name, guard.level, space.get_display_name()]
	var fight: Variant = CpuBrain.will_fight_guard(data, id)
	if not data.is_cpu:
		fight = await _ask("%s\n%s Free it, and it pays %d G a week." % [_previous_result, line, Town.income(id)],
				[["Fight", true], ["Leave it", false]])
	if not fight:
		_say("%s %s kept away." % [line, data.player_name])
		return
	var battle := Battle.new(Fighter.from_player(data), Fighter.from_monster(guard))
	await _play_battle(battle)
	if not _won(battle, data):
		return
	Town.claim(id, data)
	_show_town(space)
	BoardFx.burst(board, space.global_position, data.token_color)
	_say("%s is free, and it is %s's town now!" % [space.get_display_name(), data.player_name])
	_say(_advance_quest(data, Quest.Kind.FREE))


## Offers to raise the player's own town.
func _manage_town(space: BoardNode) -> void:
	var data := turn_manager.current_player()
	var id := space.node_id
	if Town.level(id) >= Town.MAX_LEVEL:
		_say("%s is as grand as a town can be." % space.get_display_name())
		return
	var cost := Town.invest_cost(id)
	var problem := Town.why_not_invest(data, id)
	if problem != "":
		_say("Growing %s costs %d G. %s" % [space.get_display_name(), cost, problem])
		return
	var invest: Variant = CpuBrain.will_invest(data, id)
	if not data.is_cpu:
		invest = await _ask("%s\nGrow %s to level %d? It would pay %d G a week instead of %d G."
				% [_previous_result, space.get_display_name(), Town.level(id) + 1,
				Town.income(id, Town.level(id) + 1), Town.income(id)],
				[["Invest %d G" % cost, true], ["Not now", false]])
	if not invest:
		return
	Town.invest(data, id)
	_show_town(space)
	BoardFx.pop_text(board, space.global_position, "-%d G" % cost, LOSS_TEXT_COLOR)
	_say("%s grew to level %d!" % [space.get_display_name(), Town.level(id)])


## Someone else's town: pay the toll, or fight its guard to take it. Running from
## the guard, or fighting it to a draw, still costs the toll.
func _enter_rival_town(space: BoardNode, town_owner: PlayerData) -> void:
	var data := turn_manager.current_player()
	var id := space.node_id
	var guard := Town.guard(id)
	var storm: Variant = CpuBrain.will_storm(data, id)
	if not data.is_cpu:
		storm = await _ask("%s\n%s owns this town. %s (level %d) guards it." % [_previous_result,
				town_owner.player_name, guard.display_name, guard.level],
				[["Pay %d G" % Town.toll(id), false], ["Storm it", true]])
	if storm:
		var battle := Battle.new(Fighter.from_player(data), Fighter.from_monster(guard))
		await _play_battle(battle)
		if _won(battle, data):
			Town.seize(id, data)
			_show_town(space)
			_say("%s takes %s from %s!" % [data.player_name, space.get_display_name(), town_owner.player_name])
			return
		if battle.loser != null:
			return
	var paid := Town.pay_toll(data, id)
	_landing_went_badly = true
	_say("%s pays %s a toll of %d G." % [data.player_name, town_owner.player_name, paid])
	if paid > 0:
		BoardFx.pop_text(board, _tokens[data].global_position, "-%d G" % paid, LOSS_TEXT_COLOR)
		BoardFx.pop_text(board, _tokens[town_owner].global_position, "+%d G" % paid, GOLD_TEXT_COLOR)


## True if `player` won `battle` by a knockout.
func _won(battle: Battle, player: PlayerData) -> bool:
	return battle.winner != null and battle.winner.player == player


## Plays `battle`, then sends the loser home.
func _play_battle(battle: Battle) -> void:
	turn_manager.go_to(TurnManager.Phase.BATTLE)
	camera.shake()
	await get_tree().create_timer(space_event_duration * 0.5).timeout
	var lines: PackedStringArray = await battle_screen.run(battle)
	_previous_result = " ".join(lines)
	_show_status(_previous_result)
	if battle.loser != null and battle.loser.player != null:
		_send_to_castle(battle.loser.player)
		_landing_went_badly = true
	if battle.winner != null and battle.winner.player != null:
		if battle.loser.player != null:
			await _settle_duel(battle)
		var kind := Quest.Kind.HUNT if battle.loser.monster != null else Quest.Kind.DUEL
		_say(_advance_quest(battle.winner.player, kind))


## After a duel: the wearer of the Shadow Crown pays with the crown, and anyone else
## with a spoil of the winner's choice.
func _settle_duel(battle: Battle) -> void:
	var winner := battle.winner.player
	var loser := battle.loser.player
	if ShadowCrown.is_worn_by(loser):
		var bounty := ShadowCrown.shatter(winner)
		_crown_face = loser.character_sheet
		_update_crown({"shattered": loser.player_name})
		BoardFx.pop_text(board, _tokens[winner].global_position, "+%d G" % bounty, GOLD_TEXT_COLOR)
		_say("The Shadow Crown shatters! %s earns a bounty of %d G." % [winner.player_name, bounty])
	else:
		await _take_spoil(winner, loser)
	_say(Rivalry.after_duel(winner, loser, battle.winner == battle.challenger))


## Asks the winner what to take from the loser.
func _take_spoil(winner: PlayerData, loser: PlayerData) -> void:
	var options := Rivalry.spoils(winner, loser)
	if options.is_empty():
		_say("%s has nothing worth taking." % loser.player_name)
		return
	var spoil := CpuBrain.pick_spoil(winner, options)
	if not winner.is_cpu:
		var buttons := []
		for option in options:
			buttons.append([option["text"], option])
		spoil = await _ask("%s\n%s, choose your spoils." % [_previous_result, winner.player_name], buttons)
	_say(Rivalry.take(winner, loser, spoil))
	if spoil["kind"] == Rivalry.Spoil.TOWN:
		_show_town(board.get_board_node(spoil["town"]))


## Spends the MP, works the spell and shows it. `target` is null for a spell on the
## caster.
func _cast_field_spell(caster: PlayerData, spell_id: String, target: PlayerData) -> void:
	_field_cast = true
	var spell := Database.get_spell(spell_id)
	_previous_result = "%s casts %s." % [caster.player_name, spell.display_name]
	var aimed_at: PlayerData = target if target != null else caster
	BoardFx.burst(board, _tokens[aimed_at].global_position, EVENT_COLOR)
	await _apply_result(FieldMagic.cast(caster, spell_id, target))


## Lets the active human player pick a field spell and a target. They can back out.
func _open_field_magic() -> void:
	if not field_button.visible or _a_window_is_open():
		return
	var data := turn_manager.current_player()
	field_button.hide()
	_stop_button_pulse()
	var lines := PackedStringArray(["MP %d/%d. Cast one spell before you roll." % [data.mp, data.get_stat("max_mp")]])
	var options := []
	for id in FieldMagic.known(data):
		var spell := Database.get_spell(id)
		var problem := FieldMagic.why_not(data, id)
		lines.append("%s, %d MP: %s %s" % [spell.display_name, spell.mp_cost, spell.description, problem])
		if problem == "":
			options.append([spell.display_name, id])
	options.append(["Back", ""])
	var spell_id: String = await _ask("\n".join(lines), options)
	var target: PlayerData = null
	if spell_id != "" and FieldMagic.targets_rival(spell_id):
		var rivals := []
		for rival in FieldMagic.valid_targets(data, spell_id):
			rivals.append([rival.player_name, rival])
		rivals.append(["Back", null])
		target = await _ask("Cast %s at whom?" % Database.get_spell(spell_id).display_name, rivals)
		if target == null:
			spell_id = ""
	if spell_id != "":
		await _cast_field_spell(data, spell_id, target)
	_wait_for_roll()


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
		data.difficulty = cpu_level
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
	Town.setup(board.get_town_info())
	GameState.castle_id = board.get_starting_node().node_id
	for id in Town.ids():
		_show_town(board.get_board_node(id))
	for player in GameState.players:
		if player.is_cpu:
			var ids := Database.sorted_ids(Database.classes)
			player.choose_class(ids[GameState.rng.randi_range(0, ids.size() - 1)])
		else:
			player.choose_class(await class_menu.ask(player))
		var mind: String = " (CPU, %s)" % CpuBrain.LEVEL_NAMES[player.difficulty] if player.is_cpu else ""
		print("%s is a %s%s" % [player.player_name, player.get_class_name_text(), mind])

	hud.setup(GameState.players)
	hud.show()
	_arrange_tokens()
	_slide_in_windows()
	camera.set_zoom_index(PLAY_ZOOM, 0.9)
	turn_manager.start_game()


## Asks the active player whether to fight someone sharing `space`. Returns the
## rival, or null. Nobody fights at the castle: it is the safe place to wake up.
func _ask_about_rivals(space: BoardNode) -> PlayerData:
	if space.node_type == BoardNode.NodeType.CASTLE:
		return null
	var rivals: Array[PlayerData] = []
	for other in GameState.players:
		if other != turn_manager.current_player() and other.space_id == space.node_id:
			rivals.append(other)
	if rivals.is_empty():
		return null

	if turn_manager.current_player().is_cpu:
		return CpuBrain.pick_rival(turn_manager.current_player(), rivals, space)

	var options := []
	var question := "%s\nChallenge someone here?" % _previous_result
	for rival in rivals:
		options.append(["Challenge %s" % rival.player_name, rival])
		var warning := Rivalry.warning(turn_manager.current_player(), rival)
		if warning != "":
			question += " " + warning
	options.append(["Leave them be", null])
	return await _ask(question, options)


## Counts a deed toward the royal quest, and pays out if that finished it. Returns
## a sentence about it, or "".
func _advance_quest(player: PlayerData, kind: Quest.Kind, target := -1) -> String:
	var reward := Quest.record(player, kind, target)
	hud.refresh()
	if reward == 0:
		return ""
	player.add_gold(reward)
	BoardFx.pop_text(board, _tokens[player].global_position, "Quest! +%d G" % reward, GOLD_TEXT_COLOR)
	return " Royal quest done! %s earns %d G." % [player.player_name, reward]


## Draws the crown on the right token, and queues a banner about `news`, which comes
## from ShadowCrown.weekly_check() or _settle_duel().
func _update_crown(news: Dictionary) -> void:
	for player: PlayerData in _tokens:
		_tokens[player].set_crowned(ShadowCrown.is_worn_by(player))
	hud.refresh()
	if news.has("shattered"):
		_crown_news = "Crown Shattered"
	if news.has("lifted"):
		for player: PlayerData in _tokens:
			if player.player_name == news["lifted"]:
				_crown_face = player.character_sheet
		_crown_news = "The Crown Lifts"
		_previous_result += "\nThe Shadow Crown lifts from %s." % news["lifted"]
	if news.has("fell"):
		var wearer := ShadowCrown.wearer()
		_crown_face = wearer.character_sheet
		_crown_news = "The Crown Falls"
		_previous_result += ("\nThe Shadow Crown falls on %s! Stronger and faster, but no town "
				+ "income, no shops, and it feeds on HP.") % wearer.player_name


## Adds a sentence to the message window. An empty one changes nothing.
func _say(line: String) -> void:
	if line == "":
		return
	_previous_result += " " + line.strip_edges()
	_show_status(_previous_result)


## Draws who holds a town on its space.
func _show_town(space: BoardNode) -> void:
	var town_owner := Town.owner_of(space.node_id)
	if town_owner == null:
		space.show_town(Color.TRANSPARENT, 0, Town.guard(space.node_id).sheet)
	else:
		space.show_town(town_owner.token_color, Town.level(space.node_id), null)


## What the info box says about a town.
func _town_text(id: int) -> String:
	var town_owner := Town.owner_of(id)
	var guard := Town.guard(id)
	if town_owner == null:
		return "Held by %s, level %d. Free it for %d G a week." % [guard.display_name, guard.level, Town.income(id)]
	return "%s's town, level %d of %d. Pays %d G a week. Toll %d G. Guard: %s, level %d." % [
			town_owner.player_name, Town.level(id), Town.MAX_LEVEL, Town.income(id), Town.toll(id),
			guard.display_name, guard.level]


## Shows `question` with one button per option, each a [text, value] pair.
## Returns the value of the one pressed.
func _ask(question: String, options: Array) -> Variant:
	_show_status(question)
	roll_button.hide()
	for option: Array in options:
		var button := Button.new()
		button.text = option[0]
		button.pressed.connect(func() -> void: _choice_made.emit(option[1]))
		choice_box.add_child(button)
	choice_box.get_child(0).grab_focus()
	var chosen: Variant = await _choice_made
	_clear_choices()
	roll_button.show()
	return chosen


## Picks a monster for a player of this level.
func _pick_monster(player: PlayerData) -> MonsterData:
	var ids := Database.monster_ids_for_level(player.level)
	return Database.get_monster(ids[GameState.rng.randi_range(0, ids.size() - 1)])


## Moves a knocked out player's token back to the castle.
func _send_to_castle(player: PlayerData) -> void:
	var token: PlayerMovement = _tokens[player]
	BoardFx.play(board, token.global_position, BoardFx.Kind.SMOKE, 0.5)
	token.spawn_at(board.get_starting_node())
	player.space_id = token.current_node.node_id
	_arrange_tokens()


## Pulls a player's token straight to `space`, which does nothing to them.
func _warp(player: PlayerData, space: BoardNode) -> void:
	var token: PlayerMovement = _tokens[player]
	BoardFx.play(board, token.global_position, BoardFx.Kind.SMOKE, 0.5)
	token.spawn_at(space)
	player.space_id = space.node_id
	_arrange_tokens()
	BoardFx.play(board, token.global_position, BoardFx.Kind.SMOKE, 0.5)


## Only the active human player may change things, and only before rolling.
func _open_character_sheet() -> void:
	# The HUD appears once every player has a class.
	if not hud.visible or _a_window_is_open():
		return
	var player := turn_manager.current_player()
	character_sheet.open(player, not player.is_cpu and turn_manager.phase == TurnManager.Phase.ACTION)


func _open_standings() -> void:
	if hud.visible and not _a_window_is_open():
		standings_screen.open(turn_manager.current_player())


## These fill the screen.
func _a_window_is_open() -> bool:
	return (battle_screen.visible or shop_screen.visible or bag_prompt.visible
			or character_sheet.visible or standings_screen.visible)


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
		# Removed now, because the next question may open before the frame ends.
		choice_box.remove_child(child)
		child.queue_free()
