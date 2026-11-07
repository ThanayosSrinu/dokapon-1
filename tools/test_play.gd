extends "res://tools/test_kit.gd"
## Tests playing a trip by hand, with no window: whole trips on keys, controller and mouse,
## each the same as the rules for the same seed and choices, and every choice along the way.
## Run with:
##   godot --headless --path . res://tools/test_play.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const SCREEN := "res://expedition/ExpeditionScreen.tscn"
enum Hand { KEYS, PAD, MOUSE }
## Fast enough to finish a trip in moments.
const TEST_SPEED := 40.0
const MOST_SEEDS := 400
const PADS := {Vector2.LEFT: JOY_BUTTON_DPAD_LEFT, Vector2.RIGHT: JOY_BUTTON_DPAD_RIGHT,
		Vector2.UP: JOY_BUTTON_DPAD_UP, Vector2.DOWN: JOY_BUTTON_DPAD_DOWN}
const KEYS := {Vector2.LEFT: "ui_left", Vector2.RIGHT: "ui_right", Vector2.UP: "ui_up", Vector2.DOWN: "ui_down"}


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	print("RUN _test_bag_panel() ", Time.get_ticks_msec())
	await _test_bag_panel()
	print("RUN _test_no_bot() ", Time.get_ticks_msec())
	await _test_no_bot()
	print("RUN _test_whole_trip(bram, grass, Expedition.Ending.HOME, Hand.KEYS) ", Time.get_ticks_msec())
	await _test_whole_trip(bram, grass, Expedition.Ending.HOME, Hand.KEYS)
	print("RUN _test_whole_trip(bram, grass, Expedition.Ending.HOME, Hand.PAD) ", Time.get_ticks_msec())
	await _test_whole_trip(bram, grass, Expedition.Ending.HOME, Hand.PAD)
	print("RUN _test_whole_trip(bram, grass, Expedition.Ending.HOME, Hand.MOUSE) ", Time.get_ticks_msec())
	await _test_whole_trip(bram, grass, Expedition.Ending.HOME, Hand.MOUSE)
	print("RUN _test_whole_trip(bram, grass, Expedition.Ending.BEATEN, Hand.KEYS) ", Time.get_ticks_msec())
	await _test_whole_trip(bram, grass, Expedition.Ending.BEATEN, Hand.KEYS)
	print("RUN _test_whole_trip(bram, grass, Expedition.Ending.STARVED, Hand.KEYS) ", Time.get_ticks_msec())
	await _test_whole_trip(bram, grass, Expedition.Ending.STARVED, Hand.KEYS)
	print("RUN _test_other_dice() ", Time.get_ticks_msec())
	await _test_other_dice()
	print("RUN _test_roll_and_marks() ", Time.get_ticks_msec())
	await _test_roll_and_marks()
	print("RUN _test_forks() ", Time.get_ticks_msec())
	await _test_forks()
	print("RUN _test_portal_question() ", Time.get_ticks_msec())
	await _test_portal_question()
	print("RUN _test_keys_on_the_strip() ", Time.get_ticks_msec())
	await _test_keys_on_the_strip()
	print("RUN _test_map() ", Time.get_ticks_msec())
	await _test_map()
	print("RUN _test_warnings() ", Time.get_ticks_msec())
	await _test_warnings()
	print("RUN _test_fights_by_hand() ", Time.get_ticks_msec())
	await _test_fights_by_hand()
	print("RUN _test_picking_a_move() ", Time.get_ticks_msec())
	await _test_picking_a_move()
	print("RUN _test_reading_a_tome() ", Time.get_ticks_msec())
	await _test_reading_a_tome()
	print("RUN _test_full_bag() ", Time.get_ticks_msec())
	await _test_full_bag()
	print("RUN _test_leaving() ", Time.get_ticks_msec())
	await _test_leaving()
	print("RUN _test_report_screen() ", Time.get_ticks_msec())
	await _test_report_screen()
	print("RUN _test_two_trips() ", Time.get_ticks_msec())
	await _test_two_trips()
	print("RUN _test_board_and_camp() ", Time.get_ticks_msec())
	await _test_board_and_camp()
	Engine.time_scale = 1.0
	ExpeditionScreen.next_seed = 0
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Setting up -------------------------------------------------------------

func _hire(person: Adventurer) -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	town.hire(person)
	# Bills are test_bank's job.
	town.months_paid = 1000


func _open_trip(seed_value: int, speed := 1.0) -> ExpeditionScreen:
	ExpeditionScreen.next_seed = seed_value
	# Whoever a test sends is fit, whatever the last trip did to them.
	var town := TownData.current()
	town.member(town.roster[0].person).ready_on = 0
	town._pick_going()
	town.fill_food()
	await Screens.go(SCREEN)
	await _wait()
	var screen: ExpeditionScreen = get_tree().current_scene
	Engine.time_scale = speed
	return screen


func _until_roll(screen: ExpeditionScreen) -> void:
	while not screen.roll_button.visible:
		await get_tree().process_frame
	await get_tree().process_frame


func _until_report(screen: ExpeditionScreen) -> void:
	while screen.report == null:
		await get_tree().process_frame
	await _wait()


func _back_to_town() -> void:
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "the report leads back to town")


# --- The same choices with no screen ----------------------------------------

## Plays a trip by the rules, always landing on the first space offered, with the first
## move and the first defense: what the hands below do on screen. With `goes_home` off, they stay out at the Portal.
func _plain_trip(person: Adventurer, stage: Stage, seed_value: int, goes_home := true) -> Expedition:
	var trip := Expedition.new(person, stage, seed_value, true, stage.most_food(person))
	while not trip.is_over():
		if trip.start_day():
			trip.begin_walk(trip.roll())
			if trip.steps_left > 0:
				for next in trip.path_to(trip.landing_spaces()[0]):
					trip.step_to(next)
			trip.land()
			while trip.fight != null:
				_plain_fight(trip)
			trip.found_item = ""
			if trip.is_over():
				break
			if goes_home and trip.may_go_home():
				trip.go_home()
		trip.end_day()
	return trip


func _plain_fight(trip: Expedition) -> void:
	var fight := trip.fight
	while not fight.is_over():
		var by_hand := fight.attacker.player != null
		var choice := Battle.Choice.new(Battle.Offense.ATTACK) if by_hand else fight.cpu_offense()
		var defense := Battle.Defense.NONE
		if fight.needs_defense(choice):
			defense = fight.cpu_defense() if by_hand else Battle.Defense.GUARD
		fight.resolve(choice, defense)
	trip.finish_fight(fight.conclude())


# A seed that ends as asked after at least one fight.
func _seed_for(person: Adventurer, stage: Stage, ending: Expedition.Ending, goes_home := true) -> int:
	for seed_value in range(1, MOST_SEEDS):
		var trip := _plain_trip(person, stage, seed_value, goes_home)
		if trip.ending == ending and trip.fights > 0:
			return seed_value
	_expect(false, "no seed ends in %d" % ending)
	return 1


# --- The hands --------------------------------------------------------------

## Plays on `screen` with `hand` until the trip is over.
func _play_trip(screen: ExpeditionScreen, hand: Hand, goes_home := true) -> void:
	while screen.report == null and not screen.trip.is_over():
		await _make_a_choice(screen, hand, goes_home)
		await get_tree().process_frame


## Answers whatever the screen is asking now, if anything.
func _make_a_choice(screen: ExpeditionScreen, hand: Hand, goes_home := true) -> void:
	if Engine.get_process_frames() % 600 == 0:
		print("DBG day %d steps %d choices %s sel %d roll %s battle %s portal %s bag %s moving %s focus %s report %s" % [screen.trip.day, screen.trip.steps_left, screen.landing_choices, screen.selected_landing, screen.roll_button.visible, screen.battle_screen.visible, screen.portal_panel.visible, screen.bag_prompt.visible, screen.token.is_moving, _focused(), screen.report])
	var row: Container = screen.battle_screen._choices
	if screen.bag_prompt.visible:
		await _press(screen.bag_prompt._leave, hand)
	elif screen.battle_screen.visible and row.get_child_count() > 0:
		await _press_first_of_row(row, hand)
	elif not screen.landing_choices.is_empty():
		await _pick_space(screen, screen.landing_choices[0], hand)
	elif screen.portal_panel.visible:
		await _press(screen.home_button if goes_home else screen.stay_out_button, hand)
	elif screen.roll_button.visible:
		await _press(screen.roll_button, hand)


func _press_first_of_row(row: Container, hand: Hand) -> void:
	await get_tree().process_frame
	if row.get_child_count() > 0:
		await _press(row.get_child(0), hand)


# Keys and controller press what has focus, so they prove focus went to the right place.
func _press(button: Control, hand: Hand) -> void:
	match hand:
		Hand.KEYS:
			if button != screen_focus():
				button.grab_focus()
			await _tap("ui_accept")
		Hand.PAD:
			if button != screen_focus():
				button.grab_focus()
			await _pad(JOY_BUTTON_A)
		Hand.MOUSE:
			await _click(button)


func screen_focus() -> Control:
	return _focused()


# Picks space `id` out of those a roll can land on. Keys and the pad move the selection
# there first, if it isn't selected already.
func _pick_space(screen: ExpeditionScreen, id: int, hand: Hand) -> void:
	if hand == Hand.MOUSE:
		# The camera moves to show every choice, in real time.
		await get_tree().create_timer(0.7, true, false, true).timeout
		await _click_at(_on_screen(screen, screen.board.get_board_node(id)))
		return
	var tries := 0
	while screen.selected_landing != id and tries < 20:
		var here := screen.board.get_board_node(screen.selected_landing).global_position
		var way := here.direction_to(screen.board.get_board_node(id).global_position)
		var key := Vector2(signf(way.x), 0.0) if absf(way.x) > absf(way.y) else Vector2(0.0, signf(way.y))
		if hand == Hand.PAD:
			await _pad(PADS[key])
		else:
			await _tap(KEYS[key])
		tries += 1
	if hand == Hand.PAD:
		await _pad(JOY_BUTTON_A)
	else:
		await _tap("ui_accept")


func _on_screen(screen: ExpeditionScreen, node: BoardNode) -> Vector2:
	return screen.get_viewport().get_canvas_transform() * node.global_position


# --- Whole trips ------------------------------------------------------------

func _test_whole_trip(person: Adventurer, stage: Stage, wanted: Expedition.Ending, hand: Hand) -> void:
	var goes_home := wanted != Expedition.Ending.STARVED
	var seed_value := _seed_for(person, stage, wanted, goes_home)
	var plain := _plain_trip(person, stage, seed_value, goes_home)
	var ending := plain.ending
	var days := plain.day
	var gold := plain.player.gold
	var level := plain.player.level
	var diary := plain.diary.duplicate(true)
	var gold_home := plain.gold_home()
	_hire(person)
	var town := TownData.current()
	var town_gold := town.gold
	var screen := await _open_trip(seed_value, TEST_SPEED)
	await _play_trip(screen, hand, goes_home)
	await _until_report(screen)
	var trip := screen.trip
	_expect(trip.ending == ending, "the ending is the same on screen, seed %d, hand %d" % [seed_value, hand])
	_expect(trip.day == days, "so are the days, seed %d: %d and %d" % [seed_value, trip.day, days])
	_expect(trip.player.gold == gold, "so is the gold, seed %d" % seed_value)
	_expect(trip.player.level == level, "so is the level, seed %d" % seed_value)
	_expect(trip.diary == diary, "so is the whole diary, seed %d, hand %d" % [seed_value, hand])
	_expect(town.gold == town_gold + gold_home, "the town gets what came home, once")
	_expect(town.member(person) != null, "they still work for the town")
	_expect(Engine.time_scale == 1.0, "the report runs at normal speed")
	await _back_to_town()


func _test_other_dice() -> void:
	for id: String in ["maren", "wren"]:
		var person := Database.get_adventurer(id)
		_hire(person)
		var screen := await _open_trip(3, TEST_SPEED)
		await _play_trip(screen, Hand.KEYS)
		await _until_report(screen)
		_expect(screen.report_card != null, "%s reaches a report" % id)
		await _back_to_town()


# --- The steps of a day -----------------------------------------------------

func _test_no_bot() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	_expect(screen.trip.brain == null and screen.trip.by_hand, "no brain plays a trip in the game")
	_expect(not screen.trip.player.is_cpu, "and the player's fighter is theirs to move")
	for gone: String in ["orders_button", "orders", "zone_overlay", "speed_buttons", "orders_arrow"]:
		_expect(not gone in screen, "%s is gone" % gone)
	_expect(not "auto" in screen.bag_panel, "and so is Auto")
	await _leave()


func _test_roll_and_marks() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	_expect(_focused() == screen.roll_button, "Roll has focus")
	_expect(screen.roll_button.kind == KitButton.Kind.PRIMARY, "and is the main action")
	_expect(screen.roll_arrow != null, "an arrow points at it on the first day")
	var day := screen.trip.day
	await get_tree().create_timer(0.5).timeout
	_expect(screen.trip.day == day and screen.trip.steps_left == 0, "nothing moves until the roll")
	await _tap("ui_accept")
	_expect(not screen.roll_button.visible, "Roll goes once pressed")
	_expect(screen.roll_arrow == null, "and so does the arrow")
	while screen._marked.is_empty() and screen.trip.day == day:
		await get_tree().process_frame
	var marked: Array[int] = []
	for node in screen._marked:
		marked.append(node.node_id)
		_expect(node.is_landing_spot, "a space it can end on is marked")
	var ends := screen.trip.landing_spaces()
	marked.sort()
	ends.sort()
	_expect(marked == ends, "the marks are the spaces this roll can end on")
	_expect(not screen.token.is_moving or screen.landing_choices.is_empty(), "and they show before the walk")
	Engine.time_scale = TEST_SPEED
	while screen.trip.day == day and screen.report == null:
		await _make_a_choice(screen, Hand.KEYS)
		await get_tree().process_frame
	for node in screen.board.get_all_nodes():
		_expect(not node.is_landing_spot, "the marks go when the walk ends")
	Engine.time_scale = 1.0
	await _leave()


# Plays on until a roll offers more than one space to land on, and stops there.
func _until_choice(screen: ExpeditionScreen) -> void:
	Engine.time_scale = TEST_SPEED
	while screen.landing_choices.is_empty() and screen.report == null:
		await _make_a_choice(screen, Hand.KEYS)
		await get_tree().process_frame
	Engine.time_scale = 1.0


# After a roll, every space it can land on is ringed and the player picks one (D18).
func _test_forks() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_choice(screen)
	var trip := screen.trip
	var offered := screen.landing_choices.duplicate()
	var ends := trip.landing_spaces()
	offered.sort()
	ends.sort()
	_expect(offered.size() >= 2 and offered == ends, "every space the roll can end on is offered")
	_expect(screen._news_words.text == ExpeditionScreen.PICK_WORDS, "and it asks where to")
	for id in screen.landing_choices:
		_expect(screen.board.get_board_node(id).is_landing_spot, "each is ringed")
	_expect(screen.board.get_board_node(screen.selected_landing).is_path_choice, "the selected one is lit")
	var steps := trip.steps_left
	var here := trip.space_id
	await get_tree().create_timer(0.3).timeout
	_expect(trip.steps_left == steps and trip.space_id == here, "the walk waits for the player")
	var elsewhere := -1
	for id in trip.map.spaces():
		if not screen.landing_choices.has(id):
			elsewhere = id
	EventBus.space_clicked.emit(screen.board.get_board_node(elsewhere))
	await get_tree().process_frame
	_expect(trip.space_id == here and not screen.landing_choices.is_empty(), "a space not offered does nothing")
	var first := screen.selected_landing
	var moved := false
	for way: Vector2 in KEYS:
		if screen.landing_toward(way) >= 0:
			await _tap(KEYS[way])
			moved = screen.selected_landing != first
			break
	_expect(moved, "an arrow key moves to another space")
	_expect(not screen.board.get_board_node(first).is_path_choice, "and only one is lit")
	var chosen := screen.selected_landing
	await _tap("ui_accept")
	_expect(screen.landing_choices.is_empty(), "Accept takes it, and the question goes")
	for node in screen.board.get_all_nodes():
		_expect(not node.is_path_choice, "and so does the light")
	await _until_token_stops(screen)
	_expect(trip.space_id == chosen and trip.steps_left == 0, "the walk goes all the way there by itself")
	await _leave()

	# Esc while picking asks about the stone, and the choice is still there afterwards.
	_hire(Database.get_adventurer("bram"))
	screen = await _open_trip(5)
	await _until_choice(screen)
	here = screen.trip.space_id
	await _tap("ui_cancel")
	await _wait()
	_expect(screen.leave_panel.visible, "Esc works while picking")
	var still: Array[int] = screen.landing_choices.duplicate()
	await _tap("ui_down")
	_expect(screen.trip.space_id == here, "and the arrows answer the panel instead")
	_expect(_focused() == screen.leave_button, "so they move to its button")
	await _tap("ui_up")
	await _tap("ui_cancel")
	await _wait()
	_expect(screen.landing_choices == still, "the choice is still asked")
	var target: int = still[-1]
	await get_tree().create_timer(0.7, true, false, true).timeout
	await _click_at(_on_screen(screen, screen.board.get_board_node(target)))
	await _until_token_stops(screen)
	_expect(screen.trip.space_id == target, "a click on a ringed space walks there")
	await _leave()


func _until_token_stops(screen: ExpeditionScreen) -> void:
	while screen.token.is_moving or screen.trip.steps_left > 0 and screen.landing_choices.is_empty() and not screen.trip.is_over():
		await get_tree().process_frame


func _test_portal_question() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	# Standing on the Portal, the question can be raised for a look at it.
	screen._ask_about_portal()
	await _wait()
	_expect(screen.portal_panel.visible, "the Portal asks")
	_expect(_focused() == screen.home_button, "going home is the easy answer")
	_expect(not screen.back.visible, "and the stone is out of the way")
	_expect(screen.portal_words.text.contains("item"), "and it says what they carry")
	await _tap("ui_up")
	await _tap("ui_left")
	await _tap("ui_right")
	_expect(_focused() == screen.home_button, "focus stays on the panel")
	await _tap("ui_down")
	_expect(_focused() == screen.stay_out_button, "down reaches Stay out")
	await _tap("ui_up")
	await _tap("ui_cancel")
	await _wait()
	_expect(not screen.portal_panel.visible, "Esc answers Stay out")
	_expect(not screen.leave_panel.visible, "and does not ask about the stone")
	_expect(not screen.trip.is_over(), "and the trip goes on")
	_expect(screen.back.visible, "and the stone is back")
	screen.roll_button.grab_focus()
	await _leave()

	# Stayed out, the same trip plays on to a later landing.
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	var seed_value := _seed_for(bram, grass, Expedition.Ending.STARVED, false)
	_hire(bram)
	screen = await _open_trip(seed_value, TEST_SPEED)
	var asked := [0]
	screen.portal_panel.visibility_changed.connect(func() -> void:
			if screen.portal_panel.visible:
				asked[0] += 1)
	await _play_trip(screen, Hand.KEYS, false)
	await _until_report(screen)
	_expect(screen.trip.ending == Expedition.Ending.STARVED, "staying out means not going home")
	var landed: int = screen.trip.visits.get(screen.trip.map.portal, 0)
	_expect(asked[0] == landed, "every landing on the Portal asks: %d and %d" % [asked[0], landed])
	await _back_to_town()


func _test_keys_on_the_strip() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	await _tap("ui_down")
	_expect(_focused() == screen.hud.hp_bar, "down reaches the strip")
	await _wait()
	await _wait()
	_expect(Tips.showing(), "the bar's tip opens")
	await _tap("ui_down")
	_expect(_focused() == screen.hud.food_bar, "down reaches the food")
	await _tap("ui_up")
	await _tap("ui_up")
	_expect(_focused() == screen.roll_button, "up goes back to Roll")
	await _tap("ui_right")
	_expect(_focused() == screen.bag_panel.slots[0], "right reaches the bag")
	await _tap("ui_up")
	_expect(_focused() == screen.map_button, "up reaches the Map")
	await _tap("ui_left")
	_expect(_focused() == screen.back, "left reaches the stone")
	await _tap("ui_down")
	_expect(_focused() == screen.roll_button, "and down comes back to Roll")
	get_viewport().gui_release_focus()
	await _wait()
	await _tap("ui_accept")
	_expect(not screen.roll_button.visible, "with nothing focused, Enter still rolls")
	await _leave()


func _test_map() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	var zoom := screen.camera.zoom_index()
	await _click(screen.map_button)
	await _wait()
	_expect(screen.map_panel.visible, "a click opens the map")
	_expect(not screen.bag_panel.visible, "in the bag's place")
	_expect(screen.map_panel.facts.text.contains("from the Portal"), "it says how far home is")
	_expect(screen.camera.arrows_pan, "the arrows look around")
	while not is_equal_approx(screen.camera.zoom.x, BoardCamera.ZOOM_LEVELS[0]):
		await get_tree().process_frame
	_expect(_focused() == screen.map_button, "focus waits on the button")
	await _tap("ui_left")
	await _tap("ui_down")
	_expect(_focused() == screen.map_button, "while the arrows are looking around")
	var island := screen.map_panel.island
	var far: int = island._points.keys()[-1]
	var spot := island.get_global_transform() * Vector2(island._place(far))
	await _click_at(spot)
	await get_tree().create_timer(ExpeditionScreen.MAP_VIEW_SECONDS + 0.1).timeout
	var wanted := screen.board.get_board_node(far).global_position + ExpeditionScreen.MAP_VIEW_SHIFT
	_expect(screen.camera.global_position.distance_to(wanted) < 200.0 or screen.camera.global_position != screen.token.global_position,
			"clicking the small map looks there")
	await _tap("ui_cancel")
	await _wait()
	_expect(not screen.map_panel.visible, "Esc closes the map")
	_expect(not screen.leave_panel.visible, "and does not ask about leaving")
	_expect(screen.bag_panel.visible, "the bag comes back")
	_expect(_focused() == screen.roll_button, "focus goes back to Roll")
	_expect(screen.camera.zoom_index() == zoom, "the view comes back")
	_expect(not screen.camera.arrows_pan, "and the arrows are the buttons' again")
	await _click(screen.map_button)
	await _wait()
	await _click(screen.roll_button)
	_expect(not screen.map_panel.visible, "rolling closes the map")
	await _leave()


func _test_warnings() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	var hud := screen.hud
	var trip := screen.trip
	_expect(not hud.warning.visible, "a good day shows no warning")
	var height := hud.size.y
	var bottom := hud.get_global_rect().end.y
	trip.day = 3
	trip.food_left = 1
	hud.refresh()
	await _wait()
	_expect(hud.warning.visible and hud.warning.text == TripHud.WARN_FOOD, "low food says so")
	_expect(hud.food_words.modulate == Kit.GOLD, "and the food turns gold")
	_expect(is_equal_approx(hud.get_global_rect().end.y, bottom), "the strip stays on the bottom of the screen")
	trip.player.inventory.clear()
	trip.player.hp = 1
	hud.refresh()
	_expect(hud.warning.text.contains(TripHud.WARN_HURT), "so does a bad wound")
	trip.player.add_item("herb")
	hud.refresh()
	_expect(not hud.warning.text.contains(TripHud.WARN_HURT), "not with something to heal it")
	trip.food_left = 99
	var town := TownData.current()
	town.months_paid = 0
	town.day = town.next_due() - 3 - trip.day
	screen._warn_of_debts()
	_expect(hud.warning.text.contains("The bill is due in 3 days."), "a bill says so")
	town.day += 3
	screen._warn_of_debts()
	_expect(hud.warning.text.contains("due today"), "and on its last day")
	town.day += 1
	screen._warn_of_debts()
	_expect(hud.warning.text.contains("was not paid"), "and once it is too late")
	town.months_paid = 1000
	screen._warn_of_debts()
	trip.player.hp = trip.player.get_stat("max_hp")
	hud.refresh()
	await _wait()
	_expect(not hud.warning.visible, "the words go when all is well")
	_expect(is_equal_approx(hud.size.y, height), "and the strip shrinks back")
	_expect(is_equal_approx(hud.get_global_rect().end.y, bottom), "onto the bottom of the screen")
	await _leave()


# ATK lists every move with its icons, Esc steps back, and DEF lists the armor's moves.
func _test_picking_a_move() -> void:
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	_hire(bram)
	var screen := await _open_trip(_seed_for(bram, grass, Expedition.Ending.BEATEN), TEST_SPEED)
	var wide: ItemData = Database.get_item("iron_sword").duplicate()
	wide.id = "test_wide"
	wide.moves = ["slash", "stab"]
	Database.items["test_wide"] = wide
	screen.trip.player.equipment[ItemData.Kind.WEAPON] = "test_wide"
	screen.trip.player.equipment.erase(ItemData.Kind.ARMOR)
	screen.trip.player.learned.assign(["rally"])
	screen.trip.player.hp = 400
	while not screen.battle_screen.visible:
		await _make_a_choice(screen, Hand.KEYS)
		await get_tree().process_frame
	var battle := screen.battle_screen
	var row: Container = battle._choices
	# Wait for the player's own turn, answering with DEF if the monster goes first.
	while row.get_child_count() == 0 or row.get_child(0).text != "ATK":
		if row.get_child_count() > 0:
			_expect(_texts(row) == ["Brace"], "with no armor, DEF holds only Brace")
			row.get_child(0).pressed.emit()
		await get_tree().process_frame
	await get_tree().process_frame
	_expect(_texts(row) == ["ATK", "Item", "Flee"], "the row is ATK, Item and Flee")
	row.get_child(0).pressed.emit()
	await get_tree().process_frame
	_expect(_texts(row) == ["Slash", "Stab", "Rally", "Back"], "ATK lists every move")
	_expect((row.get_child(0) as Button).icon == null, "a plain move shows no icon")
	_expect((row.get_child(2) as Button).icon != null, "a move with a keyword shows its icon")
	await _tap("ui_cancel")
	await get_tree().process_frame
	_expect(row.get_child(0).text == "ATK", "Esc steps back to ATK")
	_expect(not screen.leave_panel.visible, "and doesn't open the way out")
	row.get_child(0).pressed.emit()
	await get_tree().process_frame
	row.get_child(1).pressed.emit()
	await get_tree().process_frame
	_expect(row.get_child_count() == 0, "a move picked asks nothing more")
	await _leave()
	Database.items.erase("test_wide")


func _texts(row: Container) -> Array:
	var words := []
	for child in row.get_children():
		if child is Button:
			words.append(child.text)
	return words


# A tome is read from the bag, and with no room the player says what to forget.
func _test_reading_a_tome() -> void:
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	_hire(bram)
	var screen := await _open_trip(_seed_for(bram, grass, Expedition.Ending.BEATEN), TEST_SPEED)
	while not screen.roll_button.visible:
		await get_tree().process_frame
	var player := screen.trip.player
	var bag := screen.bag_panel
	player.inventory.clear()
	player.add_item("tome_spark")
	player.add_item("tome_mend")
	player.learned.assign(["rally"])
	await get_tree().process_frame
	bag._on_tile_pressed(0)
	_expect(bag.action.visible and bag.action.text == "Read", "a tome offers Read")
	bag._on_action()
	_expect(player.learned.has("spark") and player.inventory == ["tome_mend"], "a free slot learns it at once")
	await get_tree().process_frame
	bag._on_tile_pressed(0)
	bag._on_action()
	await get_tree().process_frame
	_expect(screen.learn_prompt.visible, "full slots ask what to forget")
	_expect(bag.locked, "and the bag waits")
	var buttons := screen.learn_prompt.get_buttons()
	_expect(buttons.size() == 3, "both moves, and a way to keep them")
	buttons[0].pressed.emit()
	await get_tree().process_frame
	_expect(not screen.learn_prompt.visible and player.inventory == ["tome_mend"], "keeping them keeps the tome")
	_expect(screen.roll_button.has_focus(), "and focus goes back to the day")
	bag._on_tile_pressed(0)
	bag._on_action()
	await get_tree().process_frame
	screen.learn_prompt.get_buttons()[1].pressed.emit()
	await get_tree().process_frame
	_expect(player.learned.has("mend") and not player.learned.has("rally"), "a move forgotten makes room")
	_expect(player.inventory.is_empty(), "and the tome is gone")
	await _leave()


func _test_fights_by_hand() -> void:
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	_hire(bram)
	var screen := await _open_trip(_seed_for(bram, grass, Expedition.Ending.BEATEN), TEST_SPEED)
	# With bare hands the fight lasts a few rounds.
	screen.trip.player.equipment.erase(ItemData.Kind.WEAPON)
	while not screen.battle_screen.visible:
		await _make_a_choice(screen, Hand.KEYS)
		await get_tree().process_frame
	var battle := screen.battle_screen
	var row: Container = battle._choices
	# If the monster is quicker, its first blow is answered before the hero's turn.
	while not _texts(row).has("ATK"):
		await get_tree().process_frame
		var defense := row.get_children().filter(func(child: Node) -> bool: return child is Button)
		if not defense.is_empty() and not _texts(row).has("ATK"):
			defense[0].pressed.emit()
	await get_tree().process_frame
	_expect(not screen.map_button.visible, "the Map stays out of a fight")
	_expect(screen.bag_panel.locked, "and the bag stays shut")
	var first: Button = row.get_child(0)
	_expect(_focused() == first, "ATK has focus")
	await _tap("ui_up")
	await _tap("ui_down")
	await _tap("ui_left")
	_expect(_focused() == first, "and focus stays on the row")
	var options := []
	for button in row.get_children():
		if button is Button:
			options.append(button.text)
	_expect(options == ["ATK", "Item", "Flee"], "the row is ATK, Item and Flee, and nothing else")
	first.pressed.emit()
	await get_tree().process_frame
	_expect(_texts(row)[0] == "Punch", "with bare hands, ATK starts with Punch")
	while screen.battle_screen.visible:
		if row.get_child_count() > 0:
			await get_tree().process_frame
			if row.get_child_count() > 0:
				row.get_child(0).pressed.emit()
		await get_tree().process_frame
	await _leave_if_going(screen)


func _leave_if_going(screen: ExpeditionScreen) -> void:
	if screen.report != null or screen.trip.is_over():
		await _until_report(screen)
		await _back_to_town()
		return
	await _until_roll(screen)
	await _leave()


func _test_full_bag() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	var trip := screen.trip
	var player := trip.player
	player.inventory.clear()
	while player.add_item("herb"):
		pass
	var found := _an_item(func(item: ItemData) -> bool: return item.id != "herb" and item.kind == ItemData.Kind.CONSUMABLE)
	trip._give(found)
	_expect(trip.found_item == found, "a full bag leaves the choice to the player")
	_expect(not player.inventory.has(found), "and nothing is dropped for them")
	screen._settle_found_item()
	await _wait()
	_expect(screen.bag_prompt.visible, "the screen asks")
	_expect(_focused() == screen.bag_prompt._leave, "leaving it is the easy answer")
	screen.bag_prompt.get_buttons()[1].pressed.emit()
	await _wait()
	_expect(player.inventory.has(found) and trip.found_item == "", "dropping something keeps the find")
	screen.roll_button.grab_focus()
	await _leave()


# --- Leaving ----------------------------------------------------------------

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
	await _until_roll(screen)
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
	_expect(not screen.leave_panel.visible, "Esc again keeps going")
	_expect(Engine.time_scale == 1.0, "and time runs again")
	_expect(_focused() == screen.roll_button, "and focus goes back to Roll")
	await _click(screen.back)
	await _wait()
	var day := screen.trip.day
	await _click(screen.leave_button)
	await _wait()
	_expect(not screen.back.visible, "the stone can't be used twice")
	_expect(not screen.roll_button.visible, "and Roll goes with it")
	await _until_report(screen)
	_expect(screen.trip.ending == Expedition.Ending.WARPED, "the stone ends the trip")
	_expect(screen.trip.day == day, "the stopped day never goes on")
	_expect(screen.report.failed, "and it is a failed trip")
	_expect(screen.report.title.contains("abandoned"), "the report says what happened")
	_expect(not screen.report_card.title.has_theme_color_override("font_color"), "not in red, because nobody died")
	_expect(screen.back.text == "Back to Town", "and leads home")
	_expect(screen.back.kind != KitButton.Kind.PRIMARY, "with no golden button")
	_expect(screen.arrow == null, "and no arrow")
	await _click(screen.back)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "leaving reaches town")
	_expect(Engine.time_scale == 1.0, "time is normal again in town")
	_expect(town.gold == gold, "a trip given up brings nothing")
	print("RUN _test_warp_during_a_fight() ", Time.get_ticks_msec())
	await _test_warp_during_a_fight()
	print("RUN _test_warp_at_a_fork() ", Time.get_ticks_msec())
	await _test_warp_at_a_fork()


func _test_warp_during_a_fight() -> void:
	var bram := Database.get_adventurer("bram")
	var screen := await _open_trip(_seed_for(bram, Database.get_stage(TownData.FIRST_STAGE), Expedition.Ending.BEATEN), TEST_SPEED)
	while screen.trip.fight == null or not screen.battle_screen.visible:
		await _make_a_choice(screen, Hand.KEYS)
		await get_tree().process_frame
	var row: Container = screen.battle_screen._choices
	while row.get_child_count() == 0:
		await get_tree().process_frame
	await get_tree().process_frame
	var move: Control = _focused()
	await _tap("ui_cancel")
	await _wait()
	await _tap("ui_cancel")
	await _wait()
	_expect(_focused() == move, "closing the panel in a fight goes back to the moves")
	await _tap("ui_cancel")
	await _wait()
	await _click(screen.leave_button)
	await _until_report(screen)
	_expect(not screen.battle_screen.visible, "the stone takes them out of a fight")
	_expect(screen.trip.ending == Expedition.Ending.WARPED, "and the trip ends there")
	_expect(Sound.current_tune() == "", "and the music stops")
	_expect(screen.hud.gold.amount == 0, "and the gold is gone")
	_expect(not screen.report.died, "nobody died")
	_expect(screen._dim.color == ExpeditionScreen.DIM, "so the screen doesn't turn red")
	_expect(not screen.hero.visible and screen.hero.material == null, "and they left whole, not in sparks")
	_expect(TownData.current().member(screen.trip.person).is_ready(TownData.current().day), "and they can work at once")
	await _back_to_town()


func _test_warp_at_a_fork() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_choice(screen)
	await _leave()
	_expect(get_tree().current_scene is TownScreen, "the stone works while picking a space")


func _test_report_screen() -> void:
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	_hire(bram)
	var screen := await _open_trip(_seed_for(bram, grass, Expedition.Ending.HOME), TEST_SPEED)
	await _play_trip(screen, Hand.KEYS)
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
		await _play_trip(screen, Hand.KEYS)
		await _until_report(screen)
		await _back_to_town()


# --- The bag ----------------------------------------------------------------

# What the board and Camp look like on screen. The rules are in test_expedition.
func _test_board_and_camp() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	var trip := screen.trip
	for id in trip.map.spaces():
		_expect(screen.board.get_board_node(id).node_type == trip.type_at(id), "the board shows this trip's spaces")
	var monster := -1
	for id in trip.map.spaces():
		if trip.type_at(id) == BoardNode.NodeType.BATTLE:
			monster = id
	_expect(SpaceNotes.of(trip, monster)["text"].contains("exactly"), "the detail box tells of the monster")
	trip._clear_space(monster)
	_expect(screen.board.get_board_node(monster).node_type == BoardNode.NodeType.NORMAL, "a used space turns empty on the board")
	_expect(SpaceNotes.of(trip, monster)["title"] == "Normal", "and in the detail box")

	_expect(screen.camp_button.visible and screen.camp_button.disabled, "Camp is offered, and rested people can't use it")
	await _tap("ui_up")
	_expect(_focused() == screen.camp_button, "up from Roll reaches Camp")
	await _tap("ui_down")
	_expect(_focused() == screen.roll_button, "and down comes back")
	await _leave_and_reopen_hurt()


func _leave_and_reopen_hurt() -> void:
	await _leave()
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(5)
	await _until_roll(screen)
	# Hurt them, and let the next morning offer Camp.
	var trip := screen.trip
	var player := trip.player
	await _tap("ui_accept")
	while not (screen.roll_button.visible and trip.day >= 2):
		await _make_a_choice_but_not_roll(screen)
		await get_tree().process_frame
	await _hurt_and_camp(screen)
	await _leave_if_going(screen)
	_expect(player != null, "the trip ended cleanly")


func _make_a_choice_but_not_roll(screen: ExpeditionScreen) -> void:
	if not screen.roll_button.visible:
		await _make_a_choice(screen, Hand.KEYS, false)


# Rests by every hand, one day each.
func _hurt_and_camp(screen: ExpeditionScreen) -> void:
	var trip := screen.trip
	var player := trip.player
	for hand in [Hand.KEYS, Hand.PAD, Hand.MOUSE]:
		player.hp = 1
		screen._offer_camp()
		_expect(not screen.camp_button.disabled, "someone hurt can camp")
		var food := trip.food_left
		var day := trip.day
		var spot := trip.space_id
		await _press(screen.camp_button, hand)
		while trip.day == day or not screen.roll_button.visible:
			await get_tree().process_frame
		_expect(player.hp > 1, "Camp heals, hand %d" % hand)
		_expect(trip.space_id == spot, "and they stay put")
		_expect(trip.food_left == food - 1, "and a day of food is gone")
		var said := trip.diary.filter(func(line: Dictionary) -> bool: return line["kind"] == "camp")
		_expect(not said.is_empty(), "and the trip says so")
	trip.food_left = 0
	trip._fed_today = false
	screen._offer_camp()
	_expect(screen.camp_button.disabled, "with no food there is no Camp")


func _test_bag_panel() -> void:
	_hire(Database.get_adventurer("bram"))
	var screen := await _open_trip(4)
	await _until_roll(screen)
	var player := screen.trip.player
	var panel := screen.bag_panel
	_expect(not panel.get_global_rect().intersects(screen.hud.get_global_rect()), "the bag clears the strip")
	_expect(panel.get_global_rect().end.y <= 720.0, "the bag fits on screen")
	_expect(screen.hud.food_words.text.ends_with("turns"), "the strip counts food in turns")

	player.inventory.clear()
	var cure := _an_item(func(item: ItemData) -> bool: return item.heal_hp > 0)
	var blade := _an_item(func(item: ItemData) -> bool:
		return item.kind == ItemData.Kind.WEAPON and CpuBrain.is_upgrade(player, item.id))
	player.add_item(cure)
	player.add_item(blade)
	panel.refresh()
	_expect(panel.tiles.size() == player.bag_size, "every place in the bag has a tile")
	_expect(panel.tiles[0].size.x == panel.slots[0].size.x, "tiles match the worn slots")
	_expect(panel.tiles[2].disabled and panel.tiles[2].icon == null, "an empty place does nothing")
	panel.tiles[1].pressed.emit()
	_expect(panel.action.visible and panel.action.text == "Wear", "better gear can be worn")
	_expect(panel.detail_title.text == Database.get_item(blade).display_name, "the box names the item")

	panel.tiles[0].pressed.emit()
	_expect(panel.tiles[0].lit and not panel.tiles[1].lit, "only the pressed tile is lit")
	_expect(panel.action.text == "Use", "something to use has Use")
	player.hp = 1
	panel.refresh()
	panel.action.pressed.emit()
	_expect(not player.inventory.has(cure) and player.hp > 1, "pressing Use uses it")
	player.add_item(cure)

	panel.refresh()
	panel.tiles[0].pressed.emit()
	panel.action.pressed.emit()
	_expect(player.equipment.get(ItemData.Kind.WEAPON) == blade, "pressing Wear wears it")
	_expect(panel.slots[0].icon != null, "worn gear shows in its slot")

	# The swap the other way: what comes back is worse, and must still be wearable.
	var old_blade: String = player.inventory[1] if player.inventory[0] == cure else player.inventory[0]
	var old_at: int = player.inventory.find(old_blade)
	_expect(not CpuBrain.is_upgrade(player, old_blade), "the old gear is no upgrade")
	panel.tiles[old_at].pressed.emit()
	_expect(panel.action.visible and panel.action.text == "Wear", "gear back in the bag can be worn again")
	panel.action.pressed.emit()
	_expect(player.equipment.get(ItemData.Kind.WEAPON) == old_blade, "and swapped back")
	get_viewport().gui_release_focus()
	await get_tree().process_frame
	await get_tree().process_frame

	panel.point_at_space(screen.trip.map.portal)
	_expect(panel.detail_title.text == "Portal", "the box explains a space")
	player.inventory.clear()
	player.add_item(cure)
	panel.refresh()
	panel.tiles[0].mouse_entered.emit()
	_expect(panel.detail_title.text == Database.get_item(cure).display_name, "the box explains an item")
	_expect(panel.action.visible, "and pointing shows its buttons")
	panel.tiles[0].mouse_exited.emit()
	_expect(panel.action.visible, "which stay to be reached")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(panel.detail_title.text == "Portal", "until the mouse leaves the column")
	panel.locked = true
	panel.tiles[0].pressed.emit()
	panel.action.pressed.emit()
	_expect(player.inventory.has(cure), "nothing changes during a fight")
	panel.tiles[0].mouse_entered.emit()
	_expect(not panel.action.visible, "and the box offers nothing")
	panel._let_go()
	panel.locked = false

	# No item's words may push the box off the screen.
	for id in Database.sorted_ids(Database.items):
		player.inventory.clear()
		player.add_item(id)
		panel.refresh()
		panel.tiles[0].mouse_entered.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(panel.get_global_rect().end.y <= 720.0, "%s fits on screen" % id)
		panel._let_go()

	# Every size of bag stays inside its frame and on screen.
	for places: int in [1, 4, 6, 7, 8, 12, 16, 17, 20, 40]:
		player.bag_size = places
		player.inventory.clear()
		while player.add_item(cure):
			pass
		_expect(player.inventory.size() == places, "a bag of %d fills up" % places)
		panel.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(panel.tiles.size() == places, "a bag of %d has its tiles" % places)
		_expect(panel.bag_words.text == "Bag %d/%d" % [places, places], "and counts them")
		_expect(panel.get_global_rect().end.y <= 720.0, "a bag of %d fits on screen" % places)
		_expect(panel.size.x == BagPanel.WIDTH, "a bag of %d keeps the column's width" % places)
		var frame: Control = panel.bag_words.get_parent()
		_expect(frame.get_global_rect().encloses(panel._bag_view.get_global_rect()), "a bag of %d stays in its frame" % places)
	player.bag_size = PlayerData.INVENTORY_SIZE
	player.inventory.clear()
	panel.refresh()
	screen.roll_button.grab_focus()
	await _leave()


func _an_item(wanted: Callable) -> String:
	for id in Database.sorted_ids(Database.items):
		if wanted.call(Database.get_item(id)):
			return id
	_expect(false, "no such item")
	return ""
