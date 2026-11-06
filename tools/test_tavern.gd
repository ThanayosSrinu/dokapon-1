extends "res://tools/test_kit.gd"
## Tests the Tavern with mouse, keyboard and controller, with no window. Run with:
##   godot --headless --path . res://tools/test_tavern.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const TAVERN := "res://tavern/TavernScreen.tscn"


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_data()
	_test_hiring_rules()
	await _test_opening()
	await _test_card_stays_put()
	await _test_keys()
	await _test_controller()
	await _test_mouse()
	await _test_cannot_pay()
	await _test_hire_with_keys()
	await _test_tavern_after_hiring()
	await _test_hire_with_mouse()
	await _test_hire_with_controller()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _cheap() -> Adventurer:
	return Database.adventurers_by_fee()[0]


func _costly() -> Adventurer:
	return Database.adventurers_by_fee()[-1]


func _open_tavern() -> TavernScreen:
	TownData.start_new()
	return await _open(TAVERN)


func _test_data() -> void:
	var people := Database.adventurers_by_fee()
	_expect(people.size() == Database.TAVERN_SIZE, "the Tavern has its three candidates")
	for index in range(1, people.size()):
		_expect(people[index - 1].fee <= people[index].fee, "the candidates stand cheapest first")
	var maren := Database.get_adventurer("maren")
	var data := maren.class_data()
	var expected: int = data.base_stats["magic"] + data.growth["magic"] * (maren.level - 1)
	_expect(maren.stat("magic") == expected, "a stat comes from the class and the level")
	_expect(_cheap().fee <= TownData.START_GOLD, "a new player can pay someone")
	_expect(_costly().fee > TownData.START_GOLD, "someone costs more than a new player has")
	for person in people:
		_expect(person.stat("attack") < TavernCard.FULL_STRENGTH, "%s fits the strength bar" % person.id)
		_expect(person.stat("max_hp") < TavernCard.FULL_HEALTH, "%s fits the health bar" % person.id)
		_expect(person.stat("magic") < TavernCard.FULL_MAGIC, "%s fits the magic bar" % person.id)
		_expect(person.die_top < DieRuler.NUMBERS, "%s fits the die ruler" % person.id)


## The test the plan asks for: gold and the hire are recorded correctly.
func _test_hiring_rules() -> void:
	TownData.start_new()
	var town := TownData.current()
	var cheap := _cheap()
	var costly := _costly()
	_expect(town.hired == null, "a new town has nobody")
	_expect(town.hire_problem(cheap) == "", "the cheapest can be hired")
	_expect(town.hire_problem(costly).contains(str(costly.fee - town.gold)), "the problem says how much is missing")
	_expect(not town.hire(costly), "nobody is hired without the gold")
	_expect(town.gold == TownData.START_GOLD and town.hired == null, "a failed hire changes nothing")
	_expect(town.hire(cheap), "someone can be hired")
	_expect(town.gold == TownData.START_GOLD - cheap.fee, "the fee is paid")
	_expect(town.hired == cheap, "the hire is recorded")
	_expect(town.next_step() == "portal", "the next step is the Portal")
	var other := Database.adventurers_by_fee()[1]
	var gold := town.gold
	_expect(not town.hire(other), "one adventurer at a time")
	_expect(town.gold == gold and town.hired == cheap, "a second hire changes nothing")
	town.gold = TownData.START_GOLD
	_expect(town.hire_problem(cheap) != "", "the one you have can't be hired again")
	TownData.start_new()
	town = TownData.current()
	town.gold = cheap.fee
	_expect(town.hire(cheap) and town.gold == 0, "someone can be hired with the very last coin")
	TownData.start_new()


func _test_opening() -> void:
	var tavern := await _open_tavern()
	var first := tavern.guests[0]
	_expect(tavern.guests.size() == Database.TAVERN_SIZE, "everyone stands in the room")
	_expect(_focused() == first, "the first person has focus")
	_expect(tavern.chosen == first and first.chosen, "the first person is chosen")
	_expect(tavern.card.shown_name() == first.adventurer.display_name, "the card shows them")
	_expect(first.adventurer.lines.has(tavern.bubble.shown_words()), "they say a line")
	_expect(tavern.card.hire.kind == KitButton.Kind.PRIMARY, "Hire is the main action")
	_expect(tavern.card.hire.text == "Hire %s" % first.adventurer.display_name, "Hire names who it hires")
	_expect(tavern.arrow.target == tavern.card.hire and tavern.arrow.visible, "the arrow points at Hire")
	_expect(tavern.gold_chip.amount == TownData.START_GOLD, "the top bar shows the gold")
	_expect(tavern.back.position == Kit.BACK_POSITION, "Back is in its usual place")
	_expect(Sound.current_tune() == "shop", "the room has its music")
	var middle := tavern.get_viewport_rect().size / 2.0
	var screen := Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE))
	_expect(screen.encloses(tavern.card.get_global_rect()), "the card fits a 1280 by 720 window")
	var buttons: Array[Control] = [tavern.back, tavern.card.hire]
	for one in tavern.guests:
		buttons.append(one)
		_expect(screen.encloses(one.get_global_rect()), "%s is on screen" % one.text)
		_expect(not one.get_global_rect().intersects(tavern.card.get_global_rect()), "%s stays clear of the card" % one.text)
	_expect(not tavern.heading.get_global_rect().intersects(tavern.back.get_global_rect()),
			"the heading stays clear of Back")


## Rule: moving between people keeps the card in the same place.
func _test_card_stays_put() -> void:
	var tavern := await _open_tavern()
	var box := tavern.card.get_global_rect()
	var bars := tavern.card.strength_bar.get_global_rect()
	var hire := tavern.card.hire.get_global_rect()
	var room := Rect2(TavernScreen.ROOM_AREA.position + tavern._stage.position, TavernScreen.ROOM_AREA.size)
	for one in tavern.guests:
		one.grab_focus()
		await _wait()
		var name_shown := one.adventurer.display_name
		_expect(tavern.card.shown_name() == name_shown, "the card follows the focus to %s" % name_shown)
		_expect(tavern.card.get_global_rect() == box, "the card stays put for %s" % name_shown)
		_expect(tavern.card.strength_bar.get_global_rect() == bars, "the bars stay put for %s" % name_shown)
		_expect(tavern.card.hire.get_global_rect() == hire, "Hire stays put for %s" % name_shown)
		_expect(tavern.card.hire.size.x >= tavern.card.hire.get_combined_minimum_size().x,
				"Hire's words fit for %s" % name_shown)
		_expect(room.encloses(tavern.bubble.get_global_rect()), "%s's words stay in the room" % name_shown)
		var strength: float = float(one.adventurer.stat("attack")) / TavernCard.FULL_STRENGTH
		await get_tree().create_timer(KitBar.SLIDE_SECONDS).timeout
		_expect(is_equal_approx(tavern.card.strength_bar.shown, strength), "the bar shows %s's strength" % name_shown)
		_expect(tavern.card.die.top == one.adventurer.die_top, "the die shows %s's die" % name_shown)
	var first := tavern.guests[0]
	var said := tavern.bubble.shown_words()
	tavern.guests[1].grab_focus()
	await _wait()
	first.grab_focus()
	await _wait()
	_expect(tavern.bubble.shown_words() != said, "pointing again brings a new line")
	# The longest words a button can hold must fit too, for anyone hired.
	var button := tavern.card.hire
	var room_for_words: float = tavern.card.hire.get_parent_control().size.x
	for person in Database.adventurers_by_fee():
		TownData.start_new()
		TownData.current().hire(person)
		button.text = TownData.current().hire_problem(_cheap())
		_expect(button.get_combined_minimum_size().x <= room_for_words, "'%s' fits on the button" % button.text)
	TownData.start_new()
	button.text = TownData.current().hire_problem(_costly())
	_expect(button.get_combined_minimum_size().x <= room_for_words, "'%s' fits on the button" % button.text)


func _test_keys() -> void:
	var tavern := await _open_tavern()
	var guests := tavern.guests
	await _tap("ui_right")
	_expect(_focused() == guests[1], "right reaches the next person")
	_expect(tavern.chosen == guests[1], "the card moves on with it")
	await _tap("ui_left")
	await _tap("ui_left")
	_expect(_focused() == guests[2], "left wraps round")
	await _tap("ui_right")
	_expect(_focused() == guests[0], "right wraps round")
	await _tap("ui_up")
	_expect(_focused() == tavern.back, "up reaches Back")
	await _tap("ui_down")
	_expect(_focused() == guests[0], "down leaves Back for the people")
	await _tap("ui_right")
	await _tap("ui_down")
	_expect(_focused() == tavern.card.hire, "down reaches Hire")
	_expect(tavern.chosen == guests[1], "Hire keeps the person chosen")
	await _tap("ui_up")
	_expect(_focused() == tavern.card.die, "up from Hire reaches the details")
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	_expect(Tips.showing() and Tips.shown_text().contains(str(guests[1].adventurer.die_top)),
			"focus on a detail opens its tip")
	await _tap("ui_up")
	await _tap("ui_up")
	await _tap("ui_up")
	_expect(_focused() == tavern.card.strength_bar, "up walks through the details")
	await _tap("ui_up")
	_expect(_focused() == guests[1], "and comes back to the person")
	await _tap("ui_accept")
	await _wait()
	_expect(_focused() == tavern.card.hire, "Enter on a person moves to Hire")
	await _tap("ui_left")
	_expect(_focused() == guests[1], "left from Hire goes back to the person")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc goes back to town")


func _test_controller() -> void:
	var tavern := await _open_tavern()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(_focused() == tavern.guests[1], "the pad reaches the next person")
	await _pad(JOY_BUTTON_A)
	await _wait()
	_expect(_focused() == tavern.card.hire, "A on a person moves to Hire")
	await _pad(JOY_BUTTON_B)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "B goes back to town")
	_expect(TownData.current().hired == null, "and leaving hires nobody")


func _test_mouse() -> void:
	var tavern := await _open_tavern()
	await get_tree().create_timer(Screens.WIPE_SECONDS).timeout
	var one := tavern.guests[2]
	one._on_mouse_entered()
	await _wait()
	_expect(_focused() == one and tavern.chosen == one, "pointing chooses a person")
	_expect(one.shown_offset == KitButton.LIFT, "pointing lifts them")
	_expect(tavern.bubble.visible, "pointing makes them talk")
	one._on_mouse_exited()
	var other := tavern.guests[1]
	await _click(other)
	await _wait()
	_expect(tavern.chosen == other and _focused() == tavern.card.hire, "a click moves to Hire")
	await _click(tavern.back)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "a click on Back leaves the Tavern")


func _test_cannot_pay() -> void:
	var tavern := await _open_tavern()
	var costly := tavern.guest(_costly().id)
	costly.grab_focus()
	await _wait()
	var hire := tavern.card.hire
	var missing := _costly().fee - TownData.START_GOLD
	_expect(hire.disabled, "Hire is off without the gold")
	_expect(hire.text.contains(str(missing)), "the button says what is missing")
	_expect(tavern.arrow.target == null, "the arrow does not point at a closed button")
	await _tap("ui_down")
	_expect(_focused() == hire, "the closed button can still be reached")
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	_expect(Tips.showing() and Tips.shown_text().contains(str(_costly().fee)), "its tip gives the numbers")
	await _tap("ui_accept")
	await _wait()
	_expect(TownData.current().gold == TownData.START_GOLD, "no gold moves")
	_expect(TownData.current().hired == null, "nobody is hired")
	_expect(get_tree().current_scene == tavern, "and the player stays here")
	await _tap("ui_left")
	await _tap("ui_right")
	_expect(not hire.disabled and hire.text.begins_with("Hire"), "Hire opens again for someone you can pay")
	_expect(tavern.arrow.target == hire, "and the arrow comes back")


## Waits for the walk to the door and the wipe to town.
func _until_in_town() -> void:
	while not (get_tree().current_scene is TownScreen):
		await get_tree().process_frame
	await _until_settled()


func _test_hire_with_keys() -> void:
	var tavern := await _open_tavern()
	var person := tavern.guests[0].adventurer
	await _tap("ui_down")
	_expect(_focused() == tavern.card.hire, "Hire can be reached")
	await _tap("ui_accept")
	await _wait()
	_expect(TownData.current().hired == person, "Enter on Hire takes them on")
	_expect(TownData.current().gold == TownData.START_GOLD - person.fee, "and pays them")
	await get_tree().create_timer(KitChip.ROLL_SECONDS).timeout
	_expect(tavern.gold_chip.amount == TownData.current().gold, "the top bar shows the new gold")
	_expect(tavern.bubble.shown_words() == person.hired_line, "they answer")
	_expect(tavern.card.hire.text == "Hired!", "the button says it is done")
	_expect(tavern.heading.text.contains("Portal"), "the heading says what comes next")
	await _tap("ui_cancel")
	_expect(get_tree().current_scene == tavern, "nobody can leave half way through")
	await _until_in_town()
	var town: TownScreen = get_tree().current_scene
	_expect(town.arrow.target == town.building("portal"), "the arrow moves to the Portal")
	_expect(_focused() == town.building("portal"), "and so does the focus")
	_expect(town.gold_chip.amount == TownData.current().gold, "the town shows the new gold")
	_expect(town.waiting != null and town.waiting.texture == person.sheet, "they wait by the Portal")


## Runs straight after _test_hire_with_keys, with the same town.
func _test_tavern_after_hiring() -> void:
	var hired := TownData.current().hired
	var gold := TownData.current().gold
	var tavern: TavernScreen = await _open(TAVERN)
	_expect(tavern.guest(hired.id) == null, "the one hired has left the room")
	_expect(tavern.guests.size() == Database.TAVERN_SIZE - 1, "the others are still here")
	_expect(tavern.guests[0].position.x > TavernScreen.GUEST_X[0], "the others keep their places")
	_expect(tavern.card.hire.disabled, "Hire is off")
	_expect(tavern.card.hire.text.contains(hired.display_name), "the button says who has the job")
	_expect(tavern.arrow.target == tavern.back, "the arrow points the way out")
	await _tap("ui_down")
	await _tap("ui_accept")
	await _wait()
	_expect(TownData.current().hired == hired and TownData.current().gold == gold, "a second hire changes nothing")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc goes back to town")


func _test_hire_with_mouse() -> void:
	var tavern := await _open_tavern()
	await get_tree().create_timer(Screens.WIPE_SECONDS).timeout
	var one := tavern.guests[1]
	await _click(one)
	await _wait()
	await _click(tavern.card.hire)
	await _wait()
	_expect(TownData.current().hired == one.adventurer, "a click on Hire takes them on")
	await _until_in_town()


func _test_hire_with_controller() -> void:
	var tavern := await _open_tavern()
	var person := tavern.guests[0].adventurer
	await _pad(JOY_BUTTON_A)
	await _wait()
	await _pad(JOY_BUTTON_A)
	await _wait()
	_expect(TownData.current().hired == person, "A twice hires the person in focus")
	await _until_in_town()
	TownData.start_new()
