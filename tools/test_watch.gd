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
## The day most test trips are called home, so that they end.
const RECALL_DAY := 6


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	await _test_same_as_the_rules(bram, grass, Expedition.Ending.HOME, RECALL_DAY)
	await _test_same_as_the_rules(bram, grass, Expedition.Ending.BEATEN, RECALL_DAY)
	await _test_same_as_the_rules(bram, grass, Expedition.Ending.STARVED, 0)
	await _test_other_dice()
	await _test_speed_in_a_fight()
	await _test_keys_and_pad()
	await _test_mouse_speed()
	await _test_leaving()
	await _test_report_screen()
	await _test_two_trips()
	await _test_orders_panel()
	await _test_giving_orders()
	await _test_asking_to_come_home()
	await _test_speech()
	Engine.time_scale = 1.0
	ExpeditionScreen.next_seed = 0
	ExpeditionScreen.next_recall_day = 0
	ExpeditionScreen.chosen_speed = 1.0
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _hire(person: Adventurer) -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	town.hire(person)
	# Bills are test_bank's job. These trips must match the rules, with nobody warning of them.
	town.months_paid = 1000


# A seed that ends as asked after at least one fight, called home on `recall_day`.
func _seed_for(person: Adventurer, stage: Stage, ending: Expedition.Ending, recall_day := RECALL_DAY) -> int:
	for seed_value in range(1, MOST_SEEDS):
		var trip := Expedition.new(person, stage, seed_value)
		trip.recall_day = recall_day
		trip.play_to_end()
		if trip.ending == ending and trip.fights > 0:
			return seed_value
	_expect(false, "no seed ends in %d" % ending)
	return 1


func _open_trip(seed_value: int, speed := 1.0, recall_day := RECALL_DAY) -> ExpeditionScreen:
	ExpeditionScreen.next_seed = seed_value
	ExpeditionScreen.next_recall_day = recall_day
	ExpeditionScreen.chosen_speed = speed
	# Whoever a test sends is fit, whatever the last trip did to them.
	var town := TownData.current()
	town.member(town.roster[0].person).ready_on = 0
	town.rest(0)
	await Screens.go(SCREEN)
	await _wait()
	return get_tree().current_scene


func _until_report(screen: ExpeditionScreen) -> void:
	while screen.report == null:
		await get_tree().process_frame
	await _wait()


func _test_same_as_the_rules(person: Adventurer, stage: Stage, wanted: Expedition.Ending, recall_day: int) -> void:
	var seed_value := _seed_for(person, stage, wanted, recall_day)
	var plain := Expedition.new(person, stage, seed_value)
	plain.recall_day = recall_day
	plain.play_to_end()
	var ending := plain.ending
	var days := plain.day
	var gold := plain.player.gold
	var level := plain.player.level
	var diary := plain.diary.duplicate(true)
	_hire(person)
	var town := TownData.current()
	var town_gold := town.gold
	var screen := await _open_trip(seed_value, TEST_SPEED, recall_day)
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
	_expect(town.member(person) != null, "they still work for the town")
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
	_expect(_focused() == screen.orders_button, "down reaches the orders")
	await _tap("ui_down")
	_expect(_focused() == screen.hud.hp_bar, "down again reaches the strip")
	await _wait()
	await _wait()
	_expect(Tips.showing(), "the bar's tip opens")
	await _tap("ui_right")
	_expect(_focused() == screen.hud.food_bar, "right reaches the food")
	await _tap("ui_up")
	_expect(_focused() == screen.orders_button, "up goes back to the orders")
	await _tap("ui_up")
	_expect(_focused() == screen.speed_buttons[1], "and up again to the row")
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
	var screen: ExpeditionScreen = get_tree().current_scene
	await _tap("ui_cancel")
	await _wait()
	await _tap("ui_down")
	await _tap("ui_accept")
	await _until_report(screen)
	await _back_to_town()


func _test_leaving() -> void:
	_hire(Database.get_adventurer("bram"))
	var town := TownData.current()
	var gold := town.gold
	var screen := await _open_trip(7)
	_expect(screen.back.position == Kit.BACK_POSITION, "the Emergency Warp is where Back always is")
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
	var day := screen.trip.day
	await _click(screen.leave_button)
	await _wait()
	_expect(not screen.back.visible, "the stone can't be used twice")
	await _until_report(screen)
	_expect(screen.trip.ending == Expedition.Ending.WARPED, "the stone ends the trip")
	_expect(screen.trip.day == day, "the stopped day never goes on")
	_expect(screen.report.failed, "and it is a failed trip")
	_expect(screen.report.title.contains("abandoned"), "the report says what happened")
	_expect(screen.report_card.title.has_theme_color_override("font_color"), "in red")
	_expect(screen.back.text == "Back to Town", "and leads home")
	_expect(screen.back.kind != KitButton.Kind.PRIMARY, "with no golden button")
	_expect(screen.arrow == null, "and no arrow")
	await _click(screen.back)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "leaving reaches town")
	_expect(Engine.time_scale == 1.0, "time is normal again in town")
	_expect(town.gold == gold, "a trip given up brings nothing")
	await _test_warp_during_a_fight()


func _test_warp_during_a_fight() -> void:
	var screen := await _open_trip(_seed_for(Database.get_adventurer("bram"),
			Database.get_stage(TownData.FIRST_STAGE), Expedition.Ending.BEATEN), TEST_SPEED)
	while screen.trip.fight == null or not screen.battle_screen.visible:
		await get_tree().process_frame
	await _tap("ui_cancel")
	await _wait()
	await _click(screen.leave_button)
	await _until_report(screen)
	_expect(not screen.battle_screen.visible, "the stone takes them out of a fight")
	_expect(screen.trip.ending == Expedition.Ending.WARPED, "and the trip ends there")
	_expect(Sound.current_tune() == "", "and the music stops")
	_expect(screen.hud.gold.amount == 0, "and the gold is gone")
	await _back_to_town()


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
		_expect(screen.trip.day < 3, "each trip starts afresh")
		_expect(screen.trip.player.gold <= SpaceEffects.GOLD_BASE + SpaceEffects.GOLD_PER_LEVEL * screen.trip.player.level * 2, "and keeps no gold from the last one")
		await _until_report(screen)
		await _back_to_town()


func _test_orders_panel() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5, 1.0, 0)
	var zoom := screen.camera.zoom_index()
	await _click(screen.orders_button)
	await _wait()
	_expect(screen.orders.visible, "a click opens the orders")
	_expect(Engine.time_scale == 1.0, "and the game keeps running")
	_expect(_focused() == screen.orders.home_button, "Return home has focus")
	_expect(screen.orders.roam_button.lit, "the order in force is lit")
	_expect(screen.zone_overlay.open, "the zones show on the island")
	_expect(screen.orders.facts.text.contains("from the Portal"), "the panel says how far home is")
	await _until_view_settled(screen)
	_expect(screen.camera.zoom_index() == 0, "the view pulls back")
	var ids := screen.orders.zone_buttons.keys()
	var first: KitButton = screen.orders.zone_buttons[ids[0]]
	await _tap("ui_down")
	_expect(_focused() == first, "down reaches the zones")
	await _wait()
	_expect(screen.zone_overlay.lit_zone == ids[0], "the zone lights up on the island")
	_expect(screen.orders.island.lit_zone == ids[0], "and on the small map")
	_expect(screen.zone_overlay.strength_of(ids[0]) > screen.zone_overlay.strength_of(ids[1]), "brighter than the others")
	await _tap("ui_up")
	await _tap("ui_up")
	_expect(_focused() == screen.orders.home_button, "focus stays in the panel")
	_expect(screen.zone_overlay.lit_zone == "", "and the zone goes dark")
	await _tap("ui_cancel")
	await _wait()
	_expect(not screen.orders.visible, "Esc closes the orders")
	_expect(not screen.leave_panel.visible, "and does not ask about leaving")
	_expect(_focused() == screen.orders_button, "focus goes back to the button")
	_expect(not screen.zone_overlay.open, "the zones go")
	_expect(screen.camera.zoom_index() == zoom, "the view comes back")
	await _click(screen.speed_buttons[0])
	await _click(screen.orders_button)
	await _wait()
	_expect(screen.orders.visible, "the orders open at x0")
	await _click(screen.orders.home_button)
	await _wait()
	_expect(screen.trip.order == Expedition.Order.HOME, "and an order can be given at x0")
	_expect(Engine.time_scale == 0.0, "which stays at x0")
	await _click(screen.speed_buttons[1])
	await _leave()


func _test_giving_orders() -> void:
	var bram := Database.get_adventurer("bram")
	_hire(bram)
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	var screen := await _open_trip(_seed_for(bram, grass, Expedition.Ending.HOME), TEST_SPEED, 0)
	Engine.time_scale = 1.0
	_expect(screen.orders_button.text == "Orders: Explore", "the button shows the order in force")
	var zone: Dictionary = screen.trip.map.zones[0]
	await _click(screen.orders_button)
	await _wait()
	await _click(screen.orders.zone_buttons[zone["id"]])
	await _wait()
	_expect(screen.trip.order == Expedition.Order.ZONE, "a zone's button sends them there")
	_expect(not screen.orders.visible, "and closes the panel")
	_expect(screen.orders_button.text == "Orders: %s" % zone["name"], "the button names the zone")
	_expect(screen.zone_overlay.target_zone == zone["id"], "the target stays marked")
	_expect(screen.zone_overlay.strength_of(zone["id"]) > 0.0, "and shows on the island")
	await _click(screen.orders_button)
	await _wait()
	var dot := screen.orders.island
	var other: Dictionary = screen.trip.map.zones[1]
	var spot := dot.get_global_transform() * dot._place(other["spaces"][0])
	await _click_at(spot)
	await _wait()
	_expect(screen.trip.order_zone.get("id", "") == other["id"], "clicking the small map sends them there")
	await _click(screen.orders_button)
	await _wait()
	await _click(screen.orders.home_button)
	_expect(screen.orders_button.text == "Orders: Return home", "the button says they are coming home")
	_expect(screen.zone_overlay.target_zone == "", "and no zone is marked")
	Engine.time_scale = TEST_SPEED
	await _until_report(screen)
	_expect(screen.trip.ending == Expedition.Ending.HOME or screen.trip.ending == Expedition.Ending.BEATEN or screen.trip.ending == Expedition.Ending.STARVED, "the trip ends")
	_expect(not screen.orders_button.visible, "the orders go with the trip")
	await _back_to_town()


func _test_asking_to_come_home() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5, TEST_SPEED, 0)
	while not screen.trip.asked_home:
		await get_tree().process_frame
	Engine.time_scale = 0.0
	await _wait()
	_expect(screen.orders_arrow != null, "an arrow points at the orders when they ask")
	await _click(screen.orders_button)
	await _wait()
	_expect(screen.orders_arrow == null, "it goes while the orders are open")
	await _click(screen.orders.home_button)
	await _wait()
	_expect(screen.orders_arrow == null, "and stays gone once called")
	Engine.time_scale = TEST_SPEED
	await _until_report(screen)
	await _back_to_town()


func _test_speech() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5, 1.0, 0)
	while not screen.token.visible:
		await get_tree().process_frame
	while screen.die.visible:
		await get_tree().process_frame
	screen.trip.say("One")
	screen.trip.say("Two")
	await _wait()
	_expect(screen.bubble.shown_words() == "One", "the first line shows")
	_expect(not screen.news.visible or not screen._news_words.text.contains("One"), "and not in the news as well")
	await get_tree().create_timer(ExpeditionScreen.SPEECH_MS / 1000.0 + 0.2).timeout
	while screen.bubble.shown_words() == "One" or screen.die.visible:
		await get_tree().process_frame
	await _wait()
	_expect(screen.bubble.shown_words() == "Two", "then the next")
	await _leave()


func _until_view_settled(screen: ExpeditionScreen) -> void:
	while not is_equal_approx(screen.camera.zoom.x, BoardCamera.ZOOM_LEVELS[0]):
		await get_tree().process_frame
