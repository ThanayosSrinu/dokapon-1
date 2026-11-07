extends "res://tools/test_kit.gd"
## Tests E17: the Town Plans, the King's letters, the Storehouse, the Smithy, the Academy,
## the Portal Beacon, and the town saving itself, with no window. Run with:
##   godot --headless --path . res://tools/test_upgrades.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const CASTLE := "res://castle/CastleScreen.tscn"
const ACADEMY := "res://academy/AcademyScreen.tscn"
const GAME_OVER := "res://town/GameOverScreen.tscn"


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	TownData.delete_save()
	_test_new_town()
	_test_plans()
	_test_letters()
	_test_storehouse()
	_test_smithy()
	_test_academy()
	_test_beacon()
	_test_bot_with_beacon()
	_test_saving()
	await _test_castle_screen()
	await _test_academy_screen()
	await _test_town_shows_levels()
	await _test_menu_continue()
	await _test_game_over_deletes_the_save()
	TownData.delete_save()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _town(gold := 1000) -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 10000
	town.hire(Database.get_adventurer("bram"))
	town.gold = gold
	return town


# A trip by the first on the roster that came home with `found` materials and `food_left`.
func _trip_home(town: TownData, found: Array[String], food_left := 0) -> Expedition:
	var one := town.roster[0]
	var trip := Expedition.new(one.person, town.stage, 11, true, 3, one)
	trip.materials.assign(found)
	trip.food_left = food_left
	trip.day = 4
	trip.ending = Expedition.Ending.HOME
	return trip


func _test_new_town() -> void:
	var town := _town()
	_expect(town.level("castle") == 1 and town.level("tavern") == 1, "the Castle and the old buildings stand")
	for id in ["storehouse", "smithy", "academy"]:
		_expect(town.level(id) == 0 and not town.is_built(id), "the %s is an empty lot" % id)
	_expect(not town.has_beacon(), "there is no Beacon yet")
	_expect(town.letter()["id"] == "first_haul", "the King's first letter is open")
	_expect(town.store_room() == 0, "no food is kept")


func _test_plans() -> void:
	var town := _town(1000)
	_expect(town.plan_problem("storehouse") == "Plans come in a Royal Letter", "a plan waits for its letter")
	_expect(not town.build("storehouse"), "so it can't be built")
	town.opened.append("storehouse")
	_expect(town.plan_problem("storehouse").begins_with("Need 3 more Wood"), "a plan needs its materials")
	town.materials = {"wood": 3}
	town.gold = 100
	_expect(town.plan_problem("storehouse") == "Need 20 more gold", "and its gold")
	town.gold = 1000
	_expect(town.build("storehouse"), "with both, it is built")
	_expect(town.level("storehouse") == 1 and town.gold == 880, "for its gold")
	_expect(not town.materials.has("wood"), "and its materials, all used")
	_expect(town.job_words("storehouse") == TownData.BUILDINGS["storehouse"]["built"], "its sign now says what it does")
	_expect(town.next_plan("storehouse") == TownPlans.plan("storehouse", 1), "level 2 is the next plan")
	_expect(town.plan_problem("storehouse").begins_with("Need"), "and needs more")
	town.materials = {"wood": 9, "ore": 9}
	_expect(town.build("storehouse") and town.level("storehouse") == 2, "a level-2 plan raises it")
	_expect(town.materials == {"wood": 4, "ore": 7}, "using what it costs")
	_expect(town.plan_problem("storehouse") == "Fully built" and not town.plan_ids().has("storehouse"),
			"a building with no plan left leaves the Town Plans")
	for id: String in TownPlans.PLANS:
		for level: int in TownPlans.PLANS[id]:
			var found: Dictionary = TownPlans.PLANS[id][level]
			_expect(found["gold"] > 0 and not found["materials"].is_empty(), "%s %d costs gold and materials" % [id, level])
			for material_id: String in found["materials"]:
				_expect(Database.get_material(material_id) != null, "%s %d uses a real material" % [id, level])
			_expect(ResourceLoader.exists(TownBuilding.FOLDER % TownBuilding.picture_name(id, level)),
					"%s %d has a picture" % [id, level])


func _test_letters() -> void:
	var town := _town(0)
	town.bring_home(_trip_home(town, ["wood", "ore", "wood"]))
	_expect(town.letter_progress == 3 and not town.letter_done(), "materials brought home count toward the letter")
	town.bring_home(_trip_home(town, ["wild_herbs", "wood"]))
	_expect(town.letter_progress == 4 and town.letter_done(), "until its goal is met")
	_expect(town.next_step() == "castle", "then the arrow points at the Castle")
	var gold := town.gold
	_expect(town.claim_letter(), "the reward can be taken")
	_expect(town.gold == gold + 100, "it pays its gold")
	_expect(town.is_opened("storehouse") and town.is_opened("smithy"), "and opens its plans")
	_expect(not town.is_opened("academy"), "but not the next letter's")
	_expect(town.letter()["id"] == "two_plans" and town.letter_progress == 0, "the next letter opens")
	_expect(not town.claim_letter(), "and can't be claimed yet")
	town.gold = 5000
	town.materials = {"wood": 20, "ore": 20, "wild_herbs": 20}
	town.build("storehouse")
	town.build("smithy")
	_expect(town.letter_done(), "building two plans does the second letter")
	town.claim_letter()
	_expect(town.is_opened("academy"), "which opens the Academy's plans")
	town.bring_home(_trip_home(town, ["wood", "starstone"]))
	_expect(town.letter_done(), "a Starstone brought home does the third")
	town.claim_letter()
	_expect(town.is_opened("portal"), "which opens the Portal Beacon")
	_expect(town.letter().is_empty() and not town.letter_done(), "and then the King has no more to say")
	var lost := _trip_home(town, ["starstone"])
	lost.ending = Expedition.Ending.BEATEN
	town.letter_index = 2
	town.letter_progress = 0
	town.bring_home(lost)
	_expect(town.letter_progress == 0, "materials lost in a defeat don't count")


func _test_storehouse() -> void:
	var town := _town(100)
	town.bring_home(_trip_home(town, [], 6))
	_expect(town.food_store == 0, "with no Storehouse, leftover food is lost")
	town.buildings["storehouse"] = 1
	town.bring_home(_trip_home(town, [], 6))
	_expect(town.food_store == 6, "the Storehouse keeps it")
	town.bring_home(_trip_home(town, [], 6))
	_expect(town.food_store == 10, "up to its room")
	var failed := _trip_home(town, [], 6)
	failed.ending = Expedition.Ending.WARPED
	town.bring_home(failed)
	_expect(town.food_store == 10, "a failed trip brings no food home")
	_expect(town.food_cost(8) == 0, "kept food costs nothing")
	_expect(town.food_cost(14) == 4 * TownData.FOOD_PRICE, "only the rest is bought")
	town.gold = 0
	_expect(town.food_limit(town.going) == mini(10, town.max_food(town.going)),
			"kept food can be taken with no gold")
	town.gold = 100
	town.food = 12
	town.buy_food()
	_expect(town.food_store == 0 and town.gold == 100 - 2 * TownData.FOOD_PRICE, "setting out eats the store first")
	town.buildings["storehouse"] = 2
	town.bring_home(_trip_home(town, [], 25))
	_expect(town.food_store == 25, "a bigger Storehouse keeps more")


func _test_smithy() -> void:
	var town := _town(5000)
	var one := town.roster[0]
	_expect(town.on_sale().has("short_sword") and not town.on_sale().has("iron_sword"), "without a Smithy, only cheap gear is sold")
	_expect(town.on_sale().has("elixir"), "but every thing to use")
	_expect(town.buy_problem("iron_sword", one) == "Not for sale" and not town.buy("iron_sword", one), "dear gear can't be bought")
	town.buildings["smithy"] = 1
	_expect(town.on_sale().has("iron_sword") and not town.on_sale().has("plate_armor"), "a Smithy brings iron")
	town.buildings["smithy"] = 2
	_expect(town.on_sale() == TownData.shop_goods(), "a bigger Smithy brings everything")


func _test_academy() -> void:
	var town := _town(1000)
	var one := town.roster[0]
	_expect(town.teachable().is_empty(), "without an Academy, nothing is taught")
	town.buildings["academy"] = 1
	_expect(town.teachable().has("tome_spark") and not town.teachable().has("tome_renew"), "the Academy teaches cheaper moves")
	_expect(Database.get_item(town.teachable()[0]).price <= Database.get_item(town.teachable()[-1]).price, "cheapest first")
	var known := one.learned.duplicate()
	_expect(known.size() < MoveData.MOST_LEARNED, "Bram has a free slot")
	_expect(town.teach("tome_spark", one), "a move can be taught")
	_expect(one.learned == known + ["spark"] and town.gold == 840, "into the free slot, for the tome's price")
	_expect(town.teach_problem("tome_spark", one) == "Knows it already", "a known move isn't taught twice")
	_expect(town.teach_problem("tome_hex", one) == "Choose a move to forget", "with both slots full, one must go")
	_expect(not town.teach("tome_hex", one, "smite"), "a move they don't know can't be forgotten")
	_expect(town.teach("tome_hex", one, "spark"), "forgetting one makes room")
	_expect(one.learned.has("hex") and not one.learned.has("spark") and one.learned.size() == MoveData.MOST_LEARNED,
			"the new move takes its slot")
	_expect(town.teach_problem("tome_renew", one) == "Not taught here", "dear moves wait for a bigger Academy")
	town.buildings["academy"] = 2
	_expect(town.teachable().has("tome_renew"), "which teaches every move")
	town.gold = 0
	_expect(town.teach_problem("tome_renew", one, "hex").begins_with("Need"), "teaching costs gold")
	var trip := Expedition.new(one.person, town.stage, 3, true, 3, one)
	_expect(trip.player.learned == one.learned, "a trip sets out with what was taught")


# A space next to the Portal, and a roll from it that can walk across the Portal but
# can't end on it.
func _crossing(trip: Expedition) -> Vector2i:
	var map := trip.map
	for id in map.neighbors(map.portal):
		for steps in range(2, 7):
			if not map.landings(id, -1, steps).has(map.portal) and map.landings(id, -1, 1).has(map.portal):
				return Vector2i(id, steps)
	return Vector2i(-1, 0)


func _test_beacon() -> void:
	var town := _town()
	var one := town.roster[0]
	var trip := Expedition.new(one.person, town.stage, 5, true, 3, one)
	var found := _crossing(trip)
	_expect(found.x >= 0, "the small map has a road across the Portal")
	trip.day = 2
	trip.space_id = found.x
	trip.begin_walk(found.y)
	_expect(not trip.landing_spaces().has(trip.map.portal), "without the Beacon, walking past the Portal isn't landing")
	var before := trip.map.landings(found.x, -1, found.y).duplicate()
	trip.beacon = true
	trip.begin_walk(found.y)
	_expect(trip.landing_spaces().has(trip.map.portal), "with it, the Portal is one of the landings")
	_expect(trip.map.landings(found.x, -1, found.y) == before, "and the map's own answers stay as they were")
	var path := trip.choose_landing(trip.map.portal)
	_expect(path.size() == 1 and path[0] == trip.map.portal, "the walk goes the short way to it")
	for next in path:
		trip.step_to(next)
	_expect(trip.steps_left == 0 and trip.space_id == trip.map.portal, "and stops there")
	trip.land()
	_expect(trip.may_go_home(), "which counts as landing on it")
	trip.go_home()
	_expect(trip.ending == Expedition.Ending.HOME, "so they can go home")
	var other := Expedition.new(one.person, town.stage, 5, true, 3, one)
	other.beacon = true
	other.day = 2
	other.space_id = found.x
	other.begin_walk(found.y)
	var elsewhere: int = other.map.landings(found.x, -1, found.y)[0]
	for next in other.choose_landing(elsewhere):
		other.step_to(next)
	_expect(other.space_id == elsewhere and other.steps_left == 0, "a walk aimed elsewhere goes on past the Portal")


func _test_bot_with_beacon() -> void:
	var town := _town()
	var person := town.roster[0].person
	var landing_days := [0, 0]
	for seed_value in range(1, 31):
		for index in 2:
			var trip := Expedition.new(person, town.stage, seed_value, false, -1)
			trip.recall_day = 3
			trip.beacon = index == 1
			trip.play_to_end()
			_expect(trip.is_over(), "a bot trip ends, seed %d" % seed_value)
			landing_days[index] += trip.landing_days
	_expect(landing_days[1] < landing_days[0], "the Beacon cuts the days lost landing (%d to %d)" % landing_days)


func _test_saving() -> void:
	var town := _town(777)
	town.hire(Database.get_adventurer("wren"))
	var one := town.roster[0]
	one.level = 3
	one.pack.append("potion")
	one.learned.append("spark")
	one.ready_on = 9
	town.buildings["storehouse"] = 2
	town.opened.append("smithy")
	town.materials = {"wood": 4, "starstone": 1}
	town.add_stock("herb", 2)
	town.food_store = 7
	town.letter_index = 1
	town.letter_progress = 1
	town.day = 33
	town.months_paid = 1
	town.borrow(250)
	town.pick(town.roster[1].person)
	town.stage = Database.get_stage("grass_m")
	var written := town.to_save()
	town.save()
	_expect(TownData.has_save(), "the town saves to a file")
	TownData.start_new()
	_expect(TownData.load_saved(), "and loads from it")
	var back_again := TownData.current()
	_expect(back_again != town and back_again.to_save() == written, "as it was")
	_expect(back_again.going == back_again.roster[1].person, "with the same person going")
	_expect(back_again.roster[0].pack.has("potion") and back_again.roster[0].level == 3, "and what each person had")
	var file := FileAccess.open(TownData.save_path(), FileAccess.WRITE)
	file.store_var({"version": 999})
	file = null
	_expect(not TownData.load_saved(), "a save from another version is refused")
	_expect(TownData.current() == back_again, "and changes nothing")
	back_again.save()
	back_again.day = back_again.loan_due + 1
	back_again.save()
	_expect(not TownData.has_save(), "a lost town is never saved: its file goes")


func _test_castle_screen() -> void:
	var town := _town(1000)
	town.letter_progress = 4
	var castle: CastleScreen = await _open(CASTLE)
	_expect(castle.picked == PlanTile.LETTER_ID, "the Castle opens on the King's letter")
	_expect(castle.tiles.size() == 1 + town.plan_ids().size(), "with a tile for it and each plan")
	_expect(castle.tile("academy").is_locked(), "plans not sent yet are locked")
	castle.pick("academy")
	await _wait()
	_expect(castle.action.text == "Locked" and castle.action.disabled, "and can't be built")
	castle.pick(PlanTile.LETTER_ID)
	await _wait()
	_expect(castle.action.text == "Take the reward" and not castle.action.disabled, "a done letter's reward can be taken")
	_expect(castle.arrow.visible and castle.arrow.target == castle.action, "and the arrow says so")
	castle.action.pressed.emit()
	await _wait()
	_expect(town.letter_index == 1 and town.gold == 1100, "pressing it takes the reward")
	_expect(not castle.tile("storehouse").is_locked(), "and unlocks the plans it opened")
	castle.pick("storehouse")
	await _wait()
	_expect(castle.action.disabled and castle.action.text == "Build it", "a plan without its materials can't be built")
	_expect(castle.shown_hint().begins_with("Need 3 more Wood"), "and says what it lacks")
	town.materials = {"wood": 5}
	castle.pick("storehouse")
	await _wait()
	_expect(not castle.action.disabled and castle.action.text == "Build it", "with them, Build it")
	castle.action.pressed.emit()
	await _wait()
	_expect(town.level("storehouse") == 1 and town.materials == {"wood": 2}, "pressing it builds")
	_expect(castle.picked == "storehouse" and castle.action.text == "Raise to level 2" and castle.action.disabled,
			"and the card shows the next level")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc goes back to town")
	var screen: TownScreen = get_tree().current_scene
	_expect(screen.building("storehouse").level == 1, "where the Storehouse now stands")
	await _click(screen.building("smithy"))
	await _until_settled()
	castle = get_tree().current_scene
	_expect(castle is CastleScreen and castle.picked == "smithy", "the Smithy's lot opens the Castle on its plan")


func _test_academy_screen() -> void:
	var town := _town(1000)
	town.buildings["academy"] = 1
	var one := town.roster[0]
	var academy: AcademyScreen = await _open(ACADEMY)
	_expect(academy.tiles.size() == town.teachable().size(), "the Academy shows each move it teaches")
	_expect(academy.picked == academy.tile_ids[0], "and opens on the first")
	academy.pick("tome_spark")
	await _wait()
	_expect(not academy.action.disabled and academy.action.text.begins_with("Teach"), "a move can be taught")
	academy.action.pressed.emit()
	await _wait()
	_expect(one.learned.has("spark"), "pressing Teach teaches it")
	academy.pick("tome_hex")
	await _wait()
	_expect(not academy.action.visible and academy.swaps[0].visible and academy.swaps[1].visible,
			"with both slots full, there is a button to forget each")
	var forgotten: String = one.learned[0]
	academy.swaps[0].pressed.emit()
	await _wait()
	_expect(one.learned.has("hex") and not one.learned.has(forgotten), "pressing one swaps the moves")
	TownData.start_new()
	town = TownData.current()
	town.buildings["academy"] = 1
	academy = await _open(ACADEMY)
	_expect(academy.action.disabled, "with nobody on the roster, nothing is taught")
	TownData.start_new()
	var screen: TownScreen = await _open(TOWN)
	await _click(screen.building("academy"))
	await _until_settled()
	_expect(get_tree().current_scene is CastleScreen, "an Academy not yet built opens the Castle")


func _test_town_shows_levels() -> void:
	var town := _town()
	town.buildings["smithy"] = 2
	town.buildings["portal"] = 2
	var screen: TownScreen = await _open(TOWN)
	_expect(screen.building("smithy").level == 2 and screen.building("storehouse").level == 0, "each building shows its level")
	_expect(screen.signs["storehouse"].get_child(0).get_child(1).text == TownData.BUILDINGS["storehouse"]["job"],
			"an empty lot's sign says how to build it")
	_expect(TownData.has_save(), "showing the town saves it")
	town.letter_progress = 4
	screen = await _open(TOWN)
	_expect(screen.arrow.target == screen.building("castle"), "a done letter sends the arrow to the Castle")
	_expect(screen.signs["castle"].shown_mark() == TownScreen.CASTLE_MARK, "and marks its sign")


func _test_menu_continue() -> void:
	TownData.delete_save()
	var menu: MainMenu = await _open(MENU)
	_expect(menu.continue_button == null and menu.play_button.text == "Play", "with no save, there is only Play")
	var town := _town(4321)
	town.save()
	TownData.start_new()
	menu = await _open(MENU)
	_expect(menu.continue_button != null and _focused() == menu.continue_button, "with a save, Continue comes first")
	_expect(menu.play_button.text == "New Town", "and Play becomes New Town")
	menu.continue_button.pressed.emit()
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen and TownData.current().gold == 4321, "Continue brings the saved town back")
	menu = await _open(MENU)
	menu.play_button.pressed.emit()
	await _wait()
	_expect(menu.confirm_panel.visible and _focused() == menu.keep_button, "New Town asks first, keeping the town by default")
	await _tap("ui_cancel")
	_expect(not menu.confirm_panel.visible and TownData.has_save(), "Esc keeps the town")
	menu.play_button.pressed.emit()
	await _wait()
	menu.confirm_button.pressed.emit()
	await _until_settled()
	_expect(TownData.current().gold == TownData.START_GOLD, "Start a new town starts afresh")


func _test_game_over_deletes_the_save() -> void:
	var town := _town()
	town.save()
	town.day = town.bill_due() + 1
	await _open(GAME_OVER)
	_expect(not TownData.has_save(), "a lost town's save is deleted")
