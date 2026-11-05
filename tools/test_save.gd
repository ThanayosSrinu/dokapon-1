extends Node
## Tests the main loop and saving, with no window. Run from the project root:
##   godot --headless --path . res://tools/test_save.tscn
## It plays whole CPU games at high speed, and proves a loaded game goes on exactly
## as the saved one did. Prints "TESTS OK" or one FAIL line per problem, and exits
## with 1 on failures. Its saves go in _work/saves_test, not with real ones.

const SPEED := 300.0
const SEED := 11
const WEEKS := 2
## The day to save on, about halfway through.
const SAVE_DAY := 8

var _failures := 0
var _board: BoardManager


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	_erase_saves()
	_board = load("res://maps/WorldMap.tscn").instantiate()
	add_child(_board)
	await get_tree().process_frame
	_test_player_round_trip()
	_test_files()
	_test_problems()
	await _test_replay_after_load()
	await _test_human_turn()
	await _test_pause()
	await _test_real_flow()
	Engine.time_scale = 1.0
	_erase_saves()
	if _failures == 0:
		print("TESTS OK")
	get_tree().quit(1 if _failures > 0 else 0)


# --- Saves without a game on screen -----------------------------------------

func _test_player_round_trip() -> void:
	var player := PlayerData.new("Red", Color.RED, true)
	player.choose_class("warrior")
	player.difficulty = CpuBrain.Level.HARD
	player.space_id = 7
	player.add_gold(123)
	player.add_experience(45)
	player.take_damage(3)
	player.grudges.append("Blue")
	player.roll_bonus = -2
	player.turns_to_skip = 1
	player.quest_progress = 1
	var saved := _through_a_file(player.to_save())
	var copy := PlayerData.from_save(saved)
	_expect(copy.to_save() == player.to_save(), "a player survives a save unchanged")
	_expect(copy.equipment == player.equipment and not copy.equipment.is_empty(), "with their gear in its slots")
	_expect(copy.get_stat("attack") == player.get_stat("attack"), "so their stats match")
	_expect(copy.is_cpu and copy.difficulty == CpuBrain.Level.HARD, "and a CPU stays a CPU of the same level")


func _test_files() -> void:
	var game := _small_game()
	var save := SaveGame.capture(1, false, {"previous_result": "hello"})
	_expect(SaveGame.folder().begins_with("D:"), "saves stay on D: (%s)" % SaveGame.folder())
	_expect(SaveGame.newest() == "", "no saves at first")
	_expect(SaveGame.write("slot1", save), "writing works")
	_expect(SaveGame.write("slot1", save), "and writing over a save works")
	var read := SaveGame.read("slot1")
	read.erase("saved_at")
	_expect(read == save, "a save reads back the same (64-bit rng state included)")
	_expect(save["rng_state"] != 0, "the rng state is really there")
	_expect(SaveGame.read("slot2").is_empty(), "an empty slot reads as nothing")

	_expect(SaveGame.write(SaveGame.AUTO, save), "the autosave writes too")
	_expect(SaveGame.newest() == SaveGame.AUTO, "the newest save is the one for Continue")
	SaveGame.erase(SaveGame.AUTO)

	# What restore() brings back, including who owns a town.
	var town: int = Town.ids()[0]
	Town.claim(town, game[1])
	GameState.crown_left_week = 3
	GameState.shadow_crown = {"wearer": game[0].player_name, "ends_day": 20}
	GameState.quest["winner"] = game[1].player_name
	var fuller := SaveGame.capture(0, true, {})
	_expect(fuller["town_owners"][town] == game[1].player_name, "town owners are saved as names")
	GameState.town_owners.clear()
	GameState.day = 99
	SaveGame.restore(_through_a_file(fuller))
	_expect(GameState.day == fuller["day"], "the day comes back")
	_expect(Town.owner_of(town) == GameState.players[fuller["players"].find_custom(
			func(p: Dictionary) -> bool: return p["name"] == game[1].player_name)], "and the town's owner is a real player")
	_expect(GameState.crown_left_week == 3 and ShadowCrown.wearer() != null, "and the crown")
	_expect(GameState.game_weeks == fuller["game_weeks"], "and the game's length")
	var next_rolls := PackedInt32Array()
	for roll in 8:
		next_rolls.append(GameState.rng.randi())
	SaveGame.restore(fuller)
	var same_rolls := PackedInt32Array()
	for roll in 8:
		same_rolls.append(GameState.rng.randi())
	_expect(next_rolls == same_rolls, "and the dice roll the same after a load")

	var path := SaveGame.folder().path_join("slot2" + SaveGame.EXTENSION)
	var junk := FileAccess.open(path, FileAccess.WRITE)
	junk.store_string("this is not a save file at all")
	junk.close()
	_expect(SaveGame.read("slot2").is_empty(), "a damaged file reads as nothing")
	SaveGame.erase("slot2")


func _test_problems() -> void:
	_small_game()
	var ids := []
	for node in _board.get_all_nodes():
		ids.append(node.node_id)
	var names := ["Red", "Blue", "Green", "Purple"]
	var good := SaveGame.capture(0, false, {})
	_expect(SaveGame.problem(good, ids, names) == "", "a good save has no problem")
	_expect(SaveGame.problem({}, ids, names) != "", "an unreadable save is refused")

	var older := good.duplicate(true)
	older["version"] = SaveGame.VERSION - 1
	_expect(SaveGame.problem(older, ids, names).contains("version"), "an older version is refused")
	var short := good.duplicate(true)
	short.erase("quest")
	_expect(SaveGame.problem(short, ids, names).contains("version"), "a save missing a value is refused")
	var lost := good.duplicate(true)
	lost["players"][0]["space_id"] = -12345
	_expect(SaveGame.problem(lost, ids, names).contains("map"), "a save from a changed map is refused")
	var stranger := good.duplicate(true)
	stranger["players"][0]["name"] = "Nobody"
	_expect(SaveGame.problem(stranger, ids, names).contains("player"), "an unknown player is refused")
	var strange_item := good.duplicate(true)
	strange_item["players"][0]["inventory"] = ["no_such_item"]
	_expect(SaveGame.problem(strange_item, ids, names).contains("items"), "an unknown item is refused")
	var bad_turn := good.duplicate(true)
	bad_turn["turn_index"] = 99
	_expect(SaveGame.problem(bad_turn, ids, names) != "", "a turn that doesn't exist is refused")


# --- Whole games -------------------------------------------------------------

## The real proof: a game saved halfway and loaded ends exactly as the one that
## simply carried on, down to the state of the dice.
func _test_replay_after_load() -> void:
	Engine.time_scale = SPEED
	var main := _new_main()
	main.cpu_players = 4
	main.game_seed = SEED
	main.game_weeks = WEEKS
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(4)

	var saved := {}
	while main.turn_manager.phase != TurnManager.Phase.GAME_OVER:
		if saved.is_empty() and GameState.day >= SAVE_DAY:
			saved = main._turn_snapshot.duplicate(true)
		await get_tree().process_frame
	var ending := SaveGame.capture(0, false, {})
	_expect(GameState.day == WEEKS * GameState.DAYS_PER_WEEK, "the game ends on the last day of the last week")
	_expect(not saved.is_empty(), "the game was saved on the way")
	_expect(GameState.get_week() == WEEKS, "the calendar stops at the last week")

	# The game over screen.
	while not main.standings_screen.visible:
		await get_tree().process_frame
	_expect(main.standings_screen._heading.text == "Final Standings", "the final standings appear")
	_expect(not main.menu_button.visible, "the menu is gone")
	_expect(not Town.awards().is_empty(), "with prizes")
	print(main.standings_screen._towns.text, " ", ", ".join(Town.awards()))
	main.queue_free()
	await get_tree().process_frame

	_expect(SaveGame.write("slot3", saved), "the save writes")
	var loaded := SaveGame.read("slot3")
	var replay := _new_main()
	replay.game_seed = 0
	GameState.load_on_start = loaded
	add_child(replay)
	await get_tree().process_frame
	_expect(not replay.title_screen.visible, "a load skips the title")
	while replay.turn_manager.phase != TurnManager.Phase.GAME_OVER:
		await get_tree().process_frame
	var replay_ending := SaveGame.capture(0, false, {})
	_expect(replay_ending == ending, "the loaded game ends exactly the same")
	if replay_ending != ending:
		for key: String in ending:
			if replay_ending[key] != ending[key]:
				print("  differs: %s\n    %s\n    %s" % [key, ending[key], replay_ending[key]])
	await _settle(replay)
	replay.queue_free()
	await get_tree().process_frame


## Saving during a person's decision must not repeat the start of their turn.
func _test_human_turn() -> void:
	Engine.time_scale = SPEED
	var main := _new_main()
	main.cpu_players = 1
	main.game_seed = SEED
	main.game_weeks = 1
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(2)
	await get_tree().process_frame
	main.class_menu.class_chosen.emit("warrior")
	await get_tree().process_frame
	main.class_menu.class_chosen.emit("warrior")
	while not _a_person_is_deciding(main):
		await get_tree().process_frame
	var human := main.turn_manager.current_player()
	human.add_gold(77)
	var gold := human.gold
	var save: Dictionary = main._snapshot_now()
	_expect(save["in_turn"], "a person's decision saves as it is")
	main.queue_free()
	await get_tree().process_frame

	var loaded := _new_main()
	GameState.load_on_start = save
	add_child(loaded)
	await get_tree().process_frame
	while loaded.turn_manager.phase == TurnManager.Phase.IDLE:
		await get_tree().process_frame
	_expect(loaded.turn_manager.phase == TurnManager.Phase.ACTION, "the load goes straight to the decision")
	var again := loaded.turn_manager.current_player()
	_expect(again.gold == gold, "with what they had")
	_expect(not again.is_cpu and not loaded.roll_button.disabled, "and they can roll")
	_expect(loaded._turn_snapshot == save, "and a later save has something to keep")
	loaded.queue_free()
	await get_tree().process_frame


## Nothing moves behind the pause menu.
func _test_pause() -> void:
	Engine.time_scale = SPEED
	var main := _new_main()
	main.cpu_players = 4
	main.game_seed = SEED
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(4)
	while main.turn_manager.phase != TurnManager.Phase.MOVING:
		await get_tree().process_frame
	main._open_pause_menu()
	_expect(get_tree().paused and main.pause_menu.visible, "the menu stops the game")
	var token: PlayerMovement = main._active_player()
	var position := token.global_position
	var day := GameState.day
	var steps := token.steps_left
	for frame in 30:
		await get_tree().process_frame
	_expect(token.global_position == position and token.steps_left == steps and GameState.day == day, "nothing moves")
	var save: Dictionary = main._snapshot_now()
	_expect(not save["in_turn"], "a save in the middle of a turn keeps its start")
	main.pause_menu.close()
	_expect(not get_tree().paused, "closing it lets the game go on")
	for frame in 30:
		await get_tree().process_frame
	_expect(token.global_position != position or token.steps_left != steps, "and it does")
	main.queue_free()
	await get_tree().process_frame


## The way a person goes through it: Main.tscn as the running scene, with its buttons.
func _test_real_flow() -> void:
	Engine.time_scale = 1.0
	_erase_saves()
	# This test leaves the scene tree's current scene, so it survives reloads.
	var tree := get_tree()
	tree.current_scene = null
	tree.change_scene_to_file("res://main/Main.tscn")
	await _next_scene(null)
	var main: GameController = tree.current_scene
	_expect(main.title_screen.visible, "the game opens on the title")
	_expect(not main.title_screen._continue.visible, "with no Continue before any save")
	_expect(not main.setup_menu.visible, "and no setup menu yet")

	main.title_screen._new_game.pressed.emit()
	_expect(main.setup_menu.visible and not main.title_screen.visible, "New Game opens the setup")
	main.setup_menu.button_row.get_child(main.setup_menu.button_row.get_child_count() - 1).pressed.emit()
	_expect(main.title_screen.visible, "Back returns to the title")

	# Choose: 2 players, 2 CPUs, Hard, Quick.
	main.title_screen._new_game.pressed.emit()
	main.setup_menu.button_row.get_child(0).pressed.emit()
	main.setup_menu.button_row.get_child(2).pressed.emit()
	main.setup_menu.button_row.get_child(2).pressed.emit()
	main.setup_menu.button_row.get_child(0).pressed.emit()
	await get_tree().process_frame
	_expect(GameState.game_weeks == 4 and main.hud.calendar_label.text.contains("of 4"), "the length shows on the calendar")
	_expect(SaveGame.has_file(SaveGame.AUTO), "the first turn autosaves")
	_expect(main.menu_button.visible, "the Menu button is there")

	main.menu_button.pressed.emit()
	main.pause_menu.save_pressed.emit()
	_expect(main.save_menu.visible and main.save_menu.saving, "Save Game lists the slots")
	var first_row: Button = main.save_menu._rows.get_child(0)
	first_row.pressed.emit()
	await get_tree().process_frame
	_expect(SaveGame.has_file("slot1"), "pressing a slot saves")
	first_row = main.save_menu._rows.get_child(0)
	_expect(first_row.text.contains("Week 1 of 4"), "and the slot says what it holds (%s)" % first_row.text)
	first_row.pressed.emit()
	_expect(main.save_menu._rows.get_child(0).text.contains("again"), "saving over a slot asks first")
	var day_saved := GameState.day
	main.save_menu.close()
	_expect(main.pause_menu.visible and tree.paused, "Back returns to the pause menu")

	# Back to the title, then Continue.
	var old_main := main
	main.pause_menu.title_pressed.emit()
	await _next_scene(old_main)
	main = tree.current_scene
	_expect(not tree.paused, "leaving the game unpauses it")
	_expect(main.title_screen.visible, "Back to Title reaches the title")
	_expect(main.title_screen._continue.visible, "and Continue is on offer")
	old_main = main
	main.title_screen._continue.pressed.emit()
	await _next_scene(old_main)
	main = tree.current_scene
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not main.title_screen.visible and main.hud.visible, "Continue goes straight into the game")
	_expect(GameState.day == day_saved and GameState.game_weeks == 4, "on the saved day")
	_expect(main.turn_manager.phase != TurnManager.Phase.IDLE, "and it runs")
	main.queue_free()
	tree.current_scene = null
	await get_tree().process_frame


# --- Helpers -----------------------------------------------------------------

func _erase_saves() -> void:
	for slot: String in [SaveGame.AUTO, "slot1", "slot2", "slot3"]:
		SaveGame.erase(slot)


func _new_main() -> GameController:
	return load("res://main/Main.tscn").instantiate()


## Waits for the running scene to be replaced.
func _next_scene(old_scene: Node) -> void:
	while get_tree().current_scene == null or get_tree().current_scene == old_scene \
			or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	await get_tree().process_frame


## Lets a finished game's last banner run out before it is freed.
func _settle(main: GameController) -> void:
	while not main.standings_screen.visible:
		await get_tree().process_frame


func _a_person_is_deciding(main: GameController) -> bool:
	return main.turn_manager.phase == TurnManager.Phase.ACTION and main._can_save_this_moment()


## Four players in a fresh game, with quest and towns set up. Returns them.
func _small_game() -> Array[PlayerData]:
	var roster: Array[PlayerData] = []
	for player_name: String in ["Red", "Blue", "Green", "Purple"]:
		var data := PlayerData.new(player_name)
		data.space_id = _board.get_starting_node().node_id
		roster.append(data)
	GameState.start_new_game(roster, SEED, 12)
	Town.setup(_board.get_town_info())
	GameState.castle_id = _board.get_starting_node().node_id
	for player in GameState.players:
		player.choose_class("mage")
	Quest.new_week()
	return roster


## What store_var() and get_var() make of a value.
func _through_a_file(value: Dictionary) -> Dictionary:
	var path := SaveGame.folder().path_join("round_trip.tmp")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(value)
	file.close()
	file = FileAccess.open(path, FileAccess.READ)
	var back: Dictionary = file.get_var()
	file.close()
	DirAccess.remove_absolute(path)
	return back


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)
