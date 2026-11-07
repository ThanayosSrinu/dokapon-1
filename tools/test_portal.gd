extends "res://tools/test_kit.gd"
## Tests the Portal, the send-off, the island and the whole path with mouse, keyboard and
## controller, with no window. Run with:
##   godot --headless --path . res://tools/test_portal.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const PORTAL := "res://portal/PortalScreen.tscn"
## How long the adventurer takes to appear, say their line and show the banner.
const APPEARED := 1.6


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_data()
	await _test_nobody_hired()
	await _test_opening()
	await _test_buying_food()
	await _test_sizes()
	await _test_keys()
	await _test_controller()
	await _test_mouse()
	await _test_send_off()
	await _test_arrival()
	await _test_path_with_keys()
	await _test_path_with_controller()
	await _test_path_with_mouse()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _hired_town(id := "bram") -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	town.hire(Database.get_adventurer(id))


func _test_data() -> void:
	var stage := Database.get_stage(TownData.FIRST_STAGE)
	_expect(stage != null, "the first stage exists")
	_expect(FileAccess.file_exists(stage.map_file), "the first stage has its map")
	TownData.start_new()
	var town := TownData.current()
	_expect(town.stage == stage, "a new town's Portal leads to the first stage")
	_expect(town.send_problem() != "", "nobody can be sent before someone is hired")
	town.hire(Database.adventurers_by_fee()[0])
	_expect(town.send_problem() == "", "someone hired can be sent")
	var maren := Database.get_adventurer("maren")
	var bram := Database.get_adventurer("bram")
	_expect(stage.most_food(bram) == bram.max_food, "a small trip carries their Max Food")
	_expect(maren.max_food > bram.max_food, "someone carries more")
	var longest := Database.get_stage("grass_l").most_food(maren)
	_expect(longest * FoodPicker.THINNEST_STEP <= FoodPicker.TRACK, "the most food fits its picture")


func _test_nobody_hired() -> void:
	TownData.start_new()
	var portal: PortalScreen = await _open(PORTAL)
	var enter := portal.card.enter
	_expect(enter.disabled, "the Portal is blocked with nobody hired")
	_expect(enter.text == TownData.current().send_problem(), "the button says why, in plain words")
	_expect(portal.hero == null, "nobody stands on the road")
	_expect(_focused() == portal.back, "the way forward is Back")
	_expect(portal.arrow.target == portal.back and portal.arrow.visible, "the arrow points at Back")
	_expect(portal.card.shown_person() == "Nobody yet", "the card says nobody is going")
	_expect(portal.card.shown_food() == "Food for 0 turns", "with nobody going there is no food")
	_expect(portal.card.shown_food_warning() == "", "and nothing to warn about")
	await _tap("ui_right")
	_expect(_focused() == enter, "the blocked button can still be reached")
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	_expect(Tips.showing() and Tips.shown_text().contains("Tavern"), "its tip says where to go")
	await _tap("ui_accept")
	await _wait()
	_expect(get_tree().current_scene == portal and not portal._leaving, "pressing it sends nobody")
	await _tap("ui_cancel")
	await _until_settled()
	var town: TownScreen = get_tree().current_scene
	_expect(town is TownScreen, "Esc goes back to town")
	_expect(_focused() == town.building("tavern"), "and the Tavern has focus, as the next step")


func _test_opening() -> void:
	_hired_town()
	var town := TownData.current()
	var portal: PortalScreen = await _open(PORTAL)
	var enter := portal.card.enter
	_expect(enter.kind == KitButton.Kind.PRIMARY, "Enter is the main action")
	_expect(not enter.disabled and enter.text == "Enter the Portal", "someone hired can go")
	_expect(_focused() == enter, "Enter has focus")
	_expect(portal.arrow.target == enter, "the arrow points at Enter")
	_expect(portal.back.position == Kit.BACK_POSITION, "Back is in its usual place")
	_expect(portal.hero != null and portal.hero.texture == town.going.sheet, "the adventurer stands on the road")
	_expect(portal.card.shown_person() == town.going.display_name, "the card shows who is going")
	_expect(portal.heading.text.contains(town.going.display_name), "the heading names them")
	var middle := portal.get_viewport_rect().size / 2.0
	var screen := Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE))
	_expect(screen.encloses(portal.card.get_global_rect()), "the card fits a 1280 by 720 window")
	_expect(enter.size.x >= enter.get_combined_minimum_size().x, "Enter's words fit")
	_expect(not portal.heading.get_global_rect().intersects(portal.back.get_global_rect()),
			"the heading stays clear of Back")
	_expect(not portal.heading.get_global_rect().intersects(portal.card.get_global_rect()),
			"the heading stays clear of the card")
	var site := Rect2(PortalScreen.SITE_AREA.position + portal._stage.position, PortalScreen.SITE_AREA.size)
	_expect(site.has_point(portal.hero.global_position), "the adventurer stands on the hilltop")


func _test_buying_food() -> void:
	_hired_town("maren")
	var town := TownData.current()
	town.gold = 1000
	var portal: PortalScreen = await _open(PORTAL)
	var card := portal.card
	var most := town.stage.most_food(town.going)
	_expect(town.food == most, "the pack starts full")
	_expect(card.shown_food() == "Food for %s" % Expedition.turns_words(most), "the food is counted in turns")
	_expect(card.food.amount == most and card.food.carry == most, "the picture shows it")
	_expect(card.shown_food_cost() == "%d of your 1000 gold" % (most * TownData.FOOD_PRICE), "and the card shows the price")
	card.food.grab_focus()
	await _tap("ui_left")
	_expect(town.food == most - 1, "left takes a day of food off")
	_expect(_focused() == card.food, "and focus stays on the food")
	await _tap("ui_right")
	await _tap("ui_right")
	_expect(town.food == most, "right adds it back, up to what they can carry")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	_expect(town.food == most - 1, "the pad slides the food too")
	var left := Kit.ICON_SIZE + FoodPicker.ICON_GAP
	_click_food(card.food, left + card.food._step() * 2.5)
	_expect(town.food == 3, "a click picks a mark")
	_drag_food(card.food, left + card.food._step() * 4.5)
	_expect(town.food == 5, "and dragging slides")
	_click_food(card.food, 0.0)
	_expect(town.food == 0, "a click on the icon buys none")
	_expect(card.shown_food_warning() == PortalScreen.NO_FOOD, "no food gets a plain warning")
	await get_tree().process_frame
	_expect(card.size.x == PortalCard.WIDTH, "and the card stays its width")
	_expect(not card.enter.disabled, "and the trip is still allowed")
	card.food.grab_focus()
	await _tap("ui_right")
	_expect(card.shown_food_warning() == PortalScreen.LOW_FOOD, "too little for the walk home says so")
	for count in most:
		await _tap("ui_right")
	_expect(card.shown_food_warning() == "", "enough food has no warning")

	# Only what the town can pay for can be bought.
	town.gold = TownData.FOOD_PRICE * 2 + 1
	portal = await _open(PORTAL)
	card = portal.card
	_expect(town.food == 2, "the pack starts as full as the gold allows")
	card.food.grab_focus()
	await _tap("ui_right")
	_expect(town.food == 2, "and no more can be bought")
	_expect(town.forecast(town.stage, town.going, 2)["whole"] >= town.day + 2, "the forecast counts what was bought")
	_expect(town.forecast(town.stage, town.going, 0)["whole"] == town.forecast(town.stage, town.going, 0)["home"],
			"with no food, the forecast is the soonest they can be home")
	town.buy_food()
	_expect(town.gold == 1, "buying costs 5 gold a day")

	town.gold = 0
	portal = await _open(PORTAL)
	_expect(town.food == 0 and not portal.card.enter.disabled, "with no gold a trip can still go, with no food")

	# Changing who goes or where fills the pack for that trip.
	town.gold = 1000
	town.fill_food()
	town.choose_food(99)
	_expect(town.food == most, "nobody buys more than they can carry")
	town.choose_food(-5)
	_expect(town.food == 0, "or less than none")
	portal = await _open(PORTAL)
	var large := Database.get_stage("grass_l")
	portal._choose_size(large)
	_expect(town.food == large.most_food(town.going), "a bigger trip fills a bigger pack")
	_expect(portal.card.food.carry == large.most_food(town.going), "and its picture is longer")
	var picked: Stage = Database.get_stage("grass_s")
	portal._choose_size(picked)
	portal._choose_food(1)
	var gold := town.gold
	portal._depart(town)
	_expect(town.gold == gold - TownData.FOOD_PRICE, "leaving pays for the food")
	await _until_on_island()
	var screen: ExpeditionScreen = get_tree().current_scene
	_expect(screen.trip.food_left == 1, "and the trip carries the food bought")


func _click_food(picker: FoodPicker, x: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(x, 8.0)
	picker._gui_input(event)


func _drag_food(picker: FoodPicker, x: float) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = Vector2(x, 8.0)
	picker._gui_input(event)


func _test_sizes() -> void:
	_hired_town()
	var town := TownData.current()
	var sizes := Database.sizes_of(town.stage.place)
	_expect(sizes.size() == 3, "grass comes in three sizes")
	_expect(sizes[0].food_scale < sizes[1].food_scale and sizes[1].food_scale < sizes[2].food_scale,
			"a bigger trip carries more food")
	town.gold = 1000
	var portal: PortalScreen = await _open(PORTAL)
	var card := portal.card
	_expect(card.sizes.size() == 3, "the card offers each size")
	_expect(card.sizes[0].lit and not card.sizes[1].lit, "the size in use is lit")
	_expect(card.sizes[1].get_global_rect().size.y > 0.0 and card.sizes[1].size.x >= card.sizes[1].get_combined_minimum_size().x,
			"the sizes' words fit")
	card.sizes[0].grab_focus()
	await _tap("ui_right")
	_expect(_focused() == card.sizes[1], "right walks along the sizes")
	_expect(town.stage == sizes[0], "walking along them changes nothing")
	await _tap("ui_accept")
	_expect(town.stage == sizes[1], "pressing one chooses it")
	_expect(card.sizes[1].lit and not card.sizes[0].lit, "and it is lit")
	var carried := sizes[1].most_food(town.going)
	_expect(card.shown_food() == "Food for %s" % Expedition.turns_words(carried), "the food follows the size")
	_expect(card.food.carry == carried, "and so does its picture")
	_expect(card._picture.texture == sizes[1].picture, "and so does the island")
	await _tap("ui_right")
	await _tap("ui_accept")
	_expect(town.stage == sizes[2], "the largest can be chosen")
	await _tap("ui_right")
	_expect(_focused() == card.sizes[2], "the sizes end at the last one")
	await _tap("ui_down")
	await _tap("ui_up")
	_expect(_focused() == card.sizes[2], "up from the food comes back to the size in use")
	var middle := portal.get_viewport_rect().size / 2.0
	var screen := Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE))
	_expect(screen.encloses(card.get_global_rect()), "the card with its sizes fits the window")
	portal = await _open(PORTAL)
	_expect(portal.card.sizes[2].lit, "the Portal remembers the size")
	var trip := Expedition.new(town.going, town.stage, 1)
	_expect(trip.food_left == sizes[2].most_food(town.going), "and the trip carries its food")
	_expect(trip.map == IslandMap.open(sizes[2].map_file), "on its island")


func _test_keys() -> void:
	_hired_town()
	var portal: PortalScreen = await _open(PORTAL)
	var enter := portal.card.enter
	await _tap("ui_up")
	_expect(_focused() == portal.card.food, "up from Enter reaches the food")
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	_expect(Tips.showing() and Tips.shown_text().contains("one turn"), "the food's tip explains turns")
	await _tap("ui_up")
	_expect(_focused() == portal.card.sizes[0], "up again reaches the size in use")
	await _tap("ui_left")
	_expect(_focused() == portal.back, "left of the first size is Back")
	await _tap("ui_down")
	_expect(_focused() == enter, "down leaves Back for Enter")
	await _tap("ui_down")
	await _tap("ui_right")
	_expect(_focused() == enter, "the arrows stay on the card")
	await _tap("ui_left")
	_expect(_focused() == portal.back, "left reaches Back")
	await _tap("ui_cancel")
	await _until_settled()
	var town: TownScreen = get_tree().current_scene
	_expect(town is TownScreen, "Esc goes back to town")
	_expect(TownData.current().going != null, "and nobody is lost")
	_expect(_focused() == town.building("portal"), "and the Portal has focus")


func _test_controller() -> void:
	_hired_town()
	var portal: PortalScreen = await _open(PORTAL)
	await _pad(JOY_BUTTON_DPAD_UP)
	_expect(_focused() == portal.card.food, "the pad reaches the food")
	await _pad(JOY_BUTTON_B)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "B goes back to town")


func _test_mouse() -> void:
	_hired_town()
	var portal: PortalScreen = await _open(PORTAL)
	await get_tree().create_timer(Screens.WIPE_SECONDS).timeout
	await _click(portal.back)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "a click on Back goes to town")


## Waits for the send-off to reach the island.
func _until_on_island() -> void:
	while not (get_tree().current_scene is ExpeditionScreen):
		await get_tree().process_frame
	await _until_settled()


func _test_send_off() -> void:
	_hired_town()
	var town := TownData.current()
	var gold := town.gold
	var portal: PortalScreen = await _open(PORTAL)
	var start := portal.hero.position
	await _tap("ui_accept")
	await _wait()
	_expect(portal._leaving, "Enter starts the send-off")
	_expect(not portal.back.visible and portal.arrow.target == null, "there is nothing to press now")
	_expect(portal.bubble.shown_words() == town.going.send_line, "the adventurer says their line")
	await _tap("ui_cancel")
	await _tap("ui_accept")
	await _wait()
	_expect(get_tree().current_scene == portal, "nobody can leave half way through")
	await get_tree().create_timer(PortalScreen.LINE_SECONDS).timeout
	_expect(portal.hero.position.y < start.y, "the adventurer walks towards the Portal")
	_expect(portal.site.charge > 0.0, "the Portal wakes up")
	_expect(Sound.current_tune() == "", "the music holds its breath")
	while not Screens.busy:
		await get_tree().process_frame
	_expect(portal.site.charge > 0.9, "the Portal is fully awake by the flash")
	_expect(portal.hero.position == PortalScreen.HERO_GOAL, "the adventurer reached the Portal")
	await _until_on_island()
	_expect(get_tree().current_scene is ExpeditionScreen, "the send-off reaches the island")
	_expect(town.gold == gold - town.food * TownData.FOOD_PRICE, "the trip only costs its food so far")
	_expect(town.going != null, "and they are still on the books")


## Runs straight after _test_send_off, on the island it reached.
func _test_arrival() -> void:
	var island: ExpeditionScreen = get_tree().current_scene
	var town := TownData.current()
	await get_tree().create_timer(APPEARED).timeout
	var start := island.board.get_starting_node().global_position
	_expect(island.board.map_file == town.stage.map_file, "the island is the stage's own map")
	_expect(island.hero.visible and island.hero.global_position == start, "the adventurer stands on the first space")
	_expect(island.hero.material == null, "and has fully appeared")
	_expect(island.bubble.shown_words() == town.going.arrive_line, "they say their line")
	_expect(island.back.position == Kit.BACK_POSITION, "Back is in its usual place")
	_expect(Sound.current_tune() == "board", "the island has its music")
	_expect(island.camera.is_current(), "the island's camera is in use")
	await _leave_with_keys()
	var back_home: TownScreen = get_tree().current_scene
	_expect(back_home is TownScreen, "leaving goes back to town")
	var town_now := TownData.current()
	var one := town_now.member(town_now.roster[0].person)
	_expect(one.days_out(town_now.day) == 0, "the Warp Stone costs them no days of work")
	_expect(town_now.send_problem() == "", "so they can be sent again")
	_expect(back_home.arrow.target == back_home.building("portal"), "and the arrow points at the Portal")
	_expect(back_home.waiting != null, "where the adventurer waits")


## Uses the Warp Stone with Esc, Down and Enter, then leaves the report.
func _leave_with_keys() -> void:
	var island: ExpeditionScreen = get_tree().current_scene
	await _tap("ui_cancel")
	await _wait()
	await _tap("ui_down")
	await _tap("ui_accept")
	await _until_report(island)
	await _tap("ui_accept")
	await _until_town()


func _test_path_with_keys() -> void:
	TownData.start_new()
	await _open_fresh_menu()
	await _tap("ui_accept")
	await _until_settled()
	var town: TownScreen = get_tree().current_scene
	_expect(town is TownScreen, "keys: the menu opens the town")
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is TavernScreen, "keys: the town opens the Tavern")
	await _tap("ui_down")
	await _tap("ui_accept")
	await _until_town()
	for trip in 2:
		await _tap("ui_accept")
		await _until_settled()
		_expect(get_tree().current_scene is PortalScreen, "keys: the town opens the Portal, trip %d" % trip)
		await _tap("ui_accept")
		await _until_on_island()
		await _leave_with_keys()
		_expect(get_tree().current_scene is TownScreen, "keys: the island leads home, trip %d" % trip)


func _test_path_with_controller() -> void:
	TownData.start_new()
	await _open_fresh_menu()
	await _pad(JOY_BUTTON_A)
	await _until_settled()
	await _pad(JOY_BUTTON_A)
	await _until_settled()
	await _pad(JOY_BUTTON_A)
	await _wait()
	await _pad(JOY_BUTTON_A)
	await _until_town()
	_expect(TownData.current().going != null, "pad: someone is hired")
	for trip in 2:
		await _pad(JOY_BUTTON_A)
		await _until_settled()
		await _pad(JOY_BUTTON_A)
		await _until_on_island()
		_expect(get_tree().current_scene is ExpeditionScreen, "pad: the Portal leads to the island, trip %d" % trip)
		var island: ExpeditionScreen = get_tree().current_scene
		await _pad(JOY_BUTTON_B)
		await _wait()
		await _pad(JOY_BUTTON_DPAD_DOWN)
		await _pad(JOY_BUTTON_A)
		await _until_report(island)
		await _pad(JOY_BUTTON_A)
		await _until_town()
		_expect(get_tree().current_scene is TownScreen, "pad: the island leads home, trip %d" % trip)


func _test_path_with_mouse() -> void:
	TownData.start_new()
	var menu: MainMenu = await _open_fresh_menu()
	await _click(menu.play_button)
	await _until_settled()
	var town: TownScreen = get_tree().current_scene
	await _click(town.building("tavern"))
	await _until_settled()
	var tavern: TavernScreen = get_tree().current_scene
	await _click(tavern.guests[0])
	await _wait()
	await _click(tavern.card.hire)
	await _until_town()
	_expect(TownData.current().going != null, "mouse: someone is hired")
	for trip in 2:
		town = get_tree().current_scene
		await _click(town.building("portal"))
		await _until_settled()
		var portal: PortalScreen = get_tree().current_scene
		_expect(portal is PortalScreen, "mouse: the town opens the Portal, trip %d" % trip)
		await _click(portal.card.enter)
		await _until_on_island()
		var island: ExpeditionScreen = get_tree().current_scene
		await _click(island.back)
		await _wait()
		await _click(island.leave_button)
		await _until_report(island)
		await _click(island.back)
		await _until_town()
		_expect(get_tree().current_scene is TownScreen, "mouse: the island leads home, trip %d" % trip)
		await get_tree().create_timer(Screens.WIPE_SECONDS).timeout
	TownData.start_new()


## Waits for the Warp Stone to finish and the report to open.
func _until_report(island: ExpeditionScreen) -> void:
	while island.report == null:
		await get_tree().process_frame
	await _until_settled()


## Waits for the walk to the Tavern's door and the wipe to town.
func _until_town() -> void:
	while not (get_tree().current_scene is TownScreen):
		await get_tree().process_frame
	await _until_settled()
