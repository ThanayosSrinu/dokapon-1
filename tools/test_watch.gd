extends "res://tools/test_kit.gd"
## Tests watching a trip: the same trip as the rules, the speeds, the report and the way
## home, with no window. Run with:
##   godot --headless --path . res://tools/test_watch.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const SCREEN := "res://expedition/ExpeditionScreen.tscn"
## Fast enough to finish a trip in moments.
const TEST_SPEED := 40.0
const LOOK_SECONDS := 0.3
const MOST_SEEDS := 400


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	await _test_same_as_the_rules(bram, grass, _seed_for(bram, grass, Expedition.Ending.HOME))
	await _test_same_as_the_rules(bram, grass, _seed_for(bram, grass, Expedition.Ending.BEATEN))
	await _test_same_as_the_rules(bram, grass, _seed_for(bram, grass, Expedition.Ending.STARVED))
	await _test_other_dice()
	await _test_speed_in_a_fight()
	await _test_keys_and_pad()
	await _test_mouse_speed()
	await _test_leaving()
	await _test_report_screen()
	await _test_two_trips()
	Engine.time_scale = 1.0
	ExpeditionScreen.next_seed = 0
	ExpeditionScreen.chosen_speed = 1.0
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _hire(person: Adventurer) -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	town.hire(person)


func _seed_for(person: Adventurer, stage: Stage, ending: Expedition.Ending) -> int:
	for seed_value in range(1, MOST_SEEDS):
		var trip := Expedition.new(person, stage, seed_value)
		trip.play_to_end()
		if trip.ending == ending:
			return seed_value
	_expect(false, "no seed ends in %d" % ending)
	return 1


func _open_trip(seed_value: int, speed := 1.0) -> ExpeditionScreen:
	ExpeditionScreen.next_seed = seed_value
	ExpeditionScreen.chosen_speed = speed
	await Screens.go(SCREEN)
	await _wait()
	return get_tree().current_scene


func _until_report(screen: ExpeditionScreen) -> void:
	while screen.report == null:
		await get_tree().process_frame
	await _wait()


func _test_same_as_the_rules(person: Adventurer, stage: Stage, seed_value: int) -> void:
	var plain := Expedition.new(person, stage, seed_value)
	plain.play_to_end()
	var ending := plain.ending
	var days := plain.day
	var gold := plain.player.gold
	var level := plain.player.level
	var diary := plain.diary.duplicate(true)
	_hire(person)
	var town := TownData.current()
	var town_gold := town.gold
	var screen := await _open_trip(seed_value, TEST_SPEED)
	_expect(Engine.time_scale == TEST_SPEED, "the trip runs at the chosen speed")
	var token_agreed := [true]
	screen.token.movement_finished.connect(func(node: BoardNode) -> void:
			token_agreed[0] = token_agreed[0] and node.node_id == screen.trip.space_id)
	await _until_report(screen)
	var trip := screen.trip
	_expect(token_agreed[0], "the token stops where the rules say, seed %d" % seed_value)
	_expect(trip.ending == ending, "the ending is the same on screen, seed %d" % seed_value)
	_expect(trip.day == days, "so are the days, seed %d: %d and %d" % [seed_value, trip.day, days])
	_expect(trip.player.gold == gold, "so is the gold, seed %d" % seed_value)
	_expect(trip.player.level == level, "so is the level, seed %d" % seed_value)
	_expect(trip.diary == diary, "so is the whole diary, seed %d" % seed_value)
	_expect(town.gold == town_gold + plain.gold_home(), "the town gets what came home, once")
	_expect(town.hired == person, "they still work for the town")
	_expect(Engine.time_scale == 1.0, "the report runs at normal speed")
	await _back_to_town()


func _back_to_town() -> void:
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "the report leads back to town")


func _test_other_dice() -> void:
	for id: String in ["maren", "wren"]:
		var person := Database.get_adventurer(id)
		_hire(person)
		var screen := await _open_trip(3, TEST_SPEED)
		await _until_report(screen)
		_expect(screen.report_card != null, "%s reaches a report" % id)
		await _back_to_town()


func _test_speed_in_a_fight() -> void:
	var bram := Database.get_adventurer("bram")
	_hire(bram)
	var screen := await _open_trip(_seed_for(bram, Database.get_stage(TownData.FIRST_STAGE), Expedition.Ending.HOME), TEST_SPEED)
	while not screen.battle_screen.visible:
		await get_tree().process_frame
	await _click(screen.speed_buttons[0])
	_expect(Engine.time_scale == 0.0, "x0 stops the fight")
	_expect(screen.speed_buttons[0].lit, "x0 is lit")
	var battle: Battle = screen.battle_screen._battle
	var round_then := battle.round_number
	var hp_then: int = battle.opponent.hp
	await get_tree().create_timer(LOOK_SECONDS, true, false, true).timeout
	_expect(battle.round_number == round_then and battle.opponent.hp == hp_then, "nothing moves at x0")
	await _click(screen.speed_buttons[2])
	_expect(Engine.time_scale == 3.0, "x3 restarts it, at three times the speed")
	_expect(screen.speed_buttons[2].lit and not screen.speed_buttons[0].lit, "x3 is lit instead")
	_expect(ExpeditionScreen.chosen_speed == 3.0, "and is kept for the next trip")
	Engine.time_scale = TEST_SPEED
	await _until_report(screen)
	await _back_to_town()


func _test_keys_and_pad() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	_expect(_focused() == screen.speed_buttons[1], "x1 has focus")
	await _tap("ui_left")
	_expect(_focused() == screen.speed_buttons[0], "left reaches x0")
	await _tap("ui_accept")
	_expect(Engine.time_scale == 0.0, "Enter picks x0")
	await _tap("ui_right")
	await _tap("ui_right")
	_expect(_focused() == screen.speed_buttons[2], "the row can be walked at x0")
	await _pad(JOY_BUTTON_A)
	_expect(Engine.time_scale == 3.0, "the controller picks a speed")
	await _tap("ui_down")
	_expect(_focused() == screen.hud.hp_bar, "down reaches the strip")
	await _wait()
	await _wait()
	_expect(Tips.showing(), "the bar's tip opens")
	await _tap("ui_right")
	_expect(_focused() == screen.hud.food_bar, "right reaches the food")
	await _tap("ui_up")
	_expect(_focused() == screen.speed_buttons[1], "up goes back to the row")
	await _leave()


func _test_mouse_speed() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _click(screen.speed_buttons[2])
	_expect(Engine.time_scale == 3.0, "a click sets the speed")
	await _click(screen.speed_buttons[0])
	var offset: float = screen.speed_buttons[1].shown_offset
	var move := InputEventMouseMotion.new()
	move.position = screen.speed_buttons[1].get_global_rect().get_center()
	move.global_position = move.position
	Input.parse_input_event(move)
	await _wait()
	await _wait()
	_expect(screen.speed_buttons[1].shown_offset != offset, "a button still lifts at x0")
	await _leave()


func _leave() -> void:
	await _tap("ui_cancel")
	await _wait()
	await _tap("ui_down")
	await _tap("ui_accept")
	await _until_settled()


func _test_leaving() -> void:
	_hire(Database.get_adventurer("bram"))
	var town := TownData.current()
	var gold := town.gold
	var screen := await _open_trip(7)
	_expect(screen.back.position == Kit.BACK_POSITION, "Leave is where Back always is")
	await _tap("ui_cancel")
	await _wait()
	_expect(screen.leave_panel.visible, "Esc asks before leaving")
	_expect(Engine.time_scale == 0.0, "time waits for the answer")
	_expect(_focused() == screen.stay_button, "staying is the easy answer")
	await _tap("ui_up")
	await _tap("ui_left")
	await _tap("ui_right")
	_expect(_focused() == screen.stay_button, "focus stays on the panel")
	await _tap("ui_cancel")
	await _wait()
	_expect(not screen.leave_panel.visible, "Esc again keeps watching")
	_expect(Engine.time_scale == 1.0, "and time runs again")
	_expect(_focused() == screen.speed_buttons[1], "and focus goes back to the speed")
	await _tap("ui_left")
	await _tap("ui_accept")
	_expect(Engine.time_scale == 0.0, "x0 is chosen")
	await _tap("ui_cancel")
	await _wait()
	await _tap("ui_cancel")
	await _wait()
	_expect(Engine.time_scale == 0.0, "closing the panel keeps x0")
	await _click(screen.back)
	await _wait()
	await _click(screen.leave_button)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "leaving reaches town")
	_expect(Engine.time_scale == 1.0, "time is normal again in town")
	_expect(town.gold == gold, "a trip given up brings nothing")


func _test_report_screen() -> void:
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	_hire(bram)
	var screen := await _open_trip(_seed_for(bram, grass, Expedition.Ending.HOME), TEST_SPEED)
	await _until_report(screen)
	_expect(not screen.hud.visible, "the strip gives way to the report")
	_expect(screen.report_card.visible, "the report shows")
	_expect(screen.back.text == "Back to Town", "Back says where it goes")
	_expect(screen.back.kind == KitButton.Kind.PRIMARY, "and is the main action")
	_expect(screen.back.visible and _focused() == screen.back, "and has focus")
	_expect(screen.arrow.target == screen.back, "the arrow points at it")
	_expect(screen.town_gold.amount == TownData.current().gold, "the town's gold shows")
	await _tap("ui_up")
	await _tap("ui_left")
	_expect(_focused() == screen.back, "Back stays put")
	await _tap("ui_down")
	_expect(_focused() == screen.report_card.stats[0], "down reaches the numbers")
	await _tap("ui_up")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc goes back to town")


func _test_two_trips() -> void:
	var bram := Database.get_adventurer("bram")
	_hire(bram)
	for seed_value: int in [11, 12]:
		var screen := await _open_trip(seed_value, TEST_SPEED)
		_expect(screen.trip.day < 3 and screen.trip.player.gold == 0, "each trip starts afresh")
		await _until_report(screen)
		await _back_to_town()
