extends "res://tools/test_kit.gd"
## Tests the hero card and the details page (E19): for every hero, as a stranger and on
## the roster with gear, levels and moves of their own, the card and the page show the
## numbers the trip and the fight use. Run with:
##   godot --headless --path . res://tools/test_heroes.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const TAVERN := "res://tavern/TavernScreen.tscn"


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_traits()
	await _test_strangers()
	await _test_members()
	await _test_page_keys()
	await _test_portal()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_traits() -> void:
	for person in Database.adventurers_by_fee():
		for one: Dictionary in person.traits():
			_expect(one["name"] != "" and one["effect"] != "", "%s's traits have names and effects" % person.id)
	var wren := Database.get_adventurer("wren")
	var words := HeroFacts.trait_lines(wren)
	_expect(words.contains("0-%d" % wren.die_top), "Fast feet names Wren's die")
	_expect(words.contains("%d days" % wren.max_food), "Packs light names Wren's food")
	_expect(HeroFacts.trait_lines(Database.get_adventurer("maren")).contains("level 3"), "Seasoned names Maren's level")


func _test_strangers() -> void:
	TownData.start_new()
	var tavern: TavernScreen = await _open(TAVERN)
	for guest in tavern.guests:
		guest.grab_focus()
		await _wait()
		await _check(tavern, guest.adventurer, null)


# Each hero joins, goes up levels, wears other gear and learns a move, then is checked.
func _test_members() -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 5000
	var gear: Array[String] = ["iron_sword", "chain_mail", "power_ring"]
	var index := 0
	for person in Database.adventurers_by_fee():
		town.hire(person)
		var one := town.member(person)
		one.level += 2 + index
		one.experience = 7
		one.wear(gear[index])
		one.learned = ["mend"]
		one.trips = 3 + index
		one.trips_home = 2
		one.gold_home = 120 + index
		index += 1
	var tavern: TavernScreen = await _open(TAVERN)
	tavern.roster_tab.pressed.emit()
	await _wait()
	for guest in tavern.guests:
		guest.grab_focus()
		await _wait()
		var one := town.member(guest.adventurer)
		_expect(tavern.card.shown_status() == "Ready to go", "%s shows as ready" % guest.adventurer.id)
		await _check(tavern, guest.adventurer, one)


# The card and every tab against a real trip's player and a real fighter.
func _check(tavern: TavernScreen, person: Adventurer, one: Member) -> void:
	var who := person.id + (" on the roster" if one != null else "")
	var trip := Expedition.new(person, TownData.current().stage, 5, true, -1, one)
	var fighter := Fighter.from_player(trip.player)
	var card := tavern.card
	_expect(card.shown_name() == person.display_name, "the card shows %s" % who)
	for stat in HeroFacts.STATS:
		var cell: HeroStat = card.stats[stat]
		_expect(cell.shown_value() == trip.player.get_stat(stat), "%s: card %s matches the trip" % [who, stat])
		_expect(cell.shown_value() == fighter.get_stat(stat), "%s: card %s matches the fight" % [who, stat])
		_expect(cell.shown_growth() == "+%d/lv" % person.class_data().growth[stat], "%s: card %s growth" % [who, stat])
	_expect(card.die.top == person.die_top, "%s: the die matches the trip" % who)
	_expect(card.shown_food().contains(str(trip.food_taken)), "%s: the food matches the trip" % who)
	if not person.traits().is_empty():
		_expect(card.shown_traits() == HeroFacts.trait_names(person), "%s: the card names the traits" % who)
	tavern.open_details()
	await _wait()
	var page := tavern.page
	_expect(page.visible, "%s: Details opens the page" % who)
	page.tabs[HeroPage.Tab.STATS].grab_focus()
	await _wait()
	var words := page.shown_words()
	for stat in HeroFacts.STATS:
		_expect(words.contains("%d +%d/lv" % [trip.player.get_stat(stat), person.class_data().growth[stat]]),
				"%s: the Stats tab shows %s" % [who, stat])
	_expect(words.contains("0-%d" % person.die_top), "%s: the Stats tab shows the die" % who)
	page.tabs[HeroPage.Tab.GEAR].grab_focus()
	await _wait()
	words = page.shown_words()
	for item_id: String in trip.player.equipment.values():
		var item := Database.get_item(item_id)
		_expect(words.contains(item.display_name), "%s: the Gear tab shows the %s worn" % [who, item.display_name])
		for move_id in item.moves:
			_expect(words.contains(Database.get_move(move_id).display_name), "%s: the Gear tab shows %s" % [who, move_id])
	page.tabs[HeroPage.Tab.MOVES].grab_focus()
	await _wait()
	words = page.shown_words()
	for move_id in trip.player.learned:
		_expect(words.contains(Database.get_move(move_id).display_name), "%s: the Moves tab shows %s" % [who, move_id])
	_expect(words.contains("%d of %d" % [MoveData.MOST_LEARNED - trip.player.learned.size(), MoveData.MOST_LEARNED]),
			"%s: the Moves tab counts free slots" % who)
	page.tabs[HeroPage.Tab.TRAITS].grab_focus()
	await _wait()
	words = page.shown_words()
	for one_trait: Dictionary in person.traits():
		_expect(words.contains(one_trait["effect"]), "%s: the Traits tab explains %s" % [who, one_trait["name"]])
	page.tabs[HeroPage.Tab.HISTORY].grab_focus()
	await _wait()
	words = page.shown_words()
	_expect(words.contains("%d / %d" % [trip.player.experience, trip.player.exp_to_next_level()]), "%s: the History tab shows EXP" % who)
	if one != null:
		_expect(words.contains("Trips %d" % one.trips) and words.contains(str(one.gold_home)), "%s: the History tab shows trips and gold" % who)
	for row in page.rows:
		_expect(row.has_meta(Tips.META) and not (row.get_meta(Tips.META) as Array).is_empty(), "%s: every History row has a tip" % who)
	page.tabs[HeroPage.Tab.STATS].grab_focus()
	page.close()
	await _wait()


func _test_page_keys() -> void:
	TownData.start_new()
	var tavern: TavernScreen = await _open(TAVERN)
	await _tap("game_character")
	_expect(tavern.page.visible, "C opens the details page")
	_expect(_focused() == tavern.page.tabs[tavern.page.tab], "the page opens on its tab")
	var first := tavern.page.tab
	await _tap("ui_right")
	_expect(tavern.page.tab == (first + 1) % HeroPage.TAB_NAMES.size(), "right moves to the next tab")
	await _tap("ui_down")
	_expect(_focused() == tavern.page.rows[0], "down reads the rows")
	await _tap("ui_cancel")
	await _wait()
	_expect(not tavern.page.visible and get_tree().current_scene == tavern, "Esc closes the page, not the Tavern")
	_expect(_focused() == tavern.card.more, "closing comes back to Details")
	await _pad(JOY_BUTTON_Y)
	_expect(tavern.page.visible, "the controller's Y opens the page")
	await _tap("game_character")
	_expect(not tavern.page.visible, "C closes it again")
	await _click(tavern.card.more)
	await _wait()
	_expect(tavern.page.visible, "a click on Details opens it")
	await _pad(JOY_BUTTON_B)
	await _wait()
	_expect(not tavern.page.visible, "B closes it")


func _test_portal() -> void:
	TownData.start_new()
	var town := TownData.current()
	town.hire(Database.adventurers_by_fee()[0])
	var portal: PortalScreen = await _open("res://portal/PortalScreen.tscn")
	await _tap("game_character")
	_expect(portal.page.visible, "C opens the details page at the Portal")
	_expect(portal.page.shown_words().contains(str(town.member(town.going).sheet().get_stat("attack"))),
			"it shows whoever is going")
	await _tap("ui_cancel")
	await _wait()
	_expect(not portal.page.visible and get_tree().current_scene == portal, "Esc closes it and stays at the Portal")
