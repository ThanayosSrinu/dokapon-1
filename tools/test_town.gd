extends "res://tools/test_kit.gd"
## Tests the town with mouse, keyboard and controller, with no window. Run with:
##   godot --headless --path . res://tools/test_town.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_data()
	await _test_opening()
	await _test_scene_plan()
	await _test_only_two_can_be_visited()
	await _test_keys()
	await _test_controller()
	await _test_mouse()
	await _test_press()
	await _test_arrow_follows_the_plan()
	await _test_tavern_door()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _open_town() -> TownScreen:
	TownData.start_new()
	return await _open(TOWN)


func _test_data() -> void:
	TownData.start_new()
	var town := TownData.current()
	_expect(town.gold == TownData.START_GOLD, "a new town has its starting gold")
	_expect(town.buildings.keys() == TownData.BUILDINGS.keys(), "a new town has every building")
	_expect(town.next_step() == "tavern", "a new player goes to the Tavern first")
	town.gold = 1
	_expect(TownData.current().gold == 1, "the town keeps its gold between looks")
	TownData.start_new()
	_expect(TownData.current().gold == TownData.START_GOLD, "a new game starts afresh")


func _test_opening() -> void:
	var town := await _open_town()
	_expect(_focused() == town.building("tavern"), "the Tavern has focus at the start")
	_expect(town.building("tavern").is_lit(), "the Tavern lights up")
	_expect(town.signs["tavern"].is_open(), "its sign says what it does")
	_expect(not town.signs["portal"].is_open(), "the Portal's sign shows only its name")
	_expect(town.arrow.target == town.building("tavern"), "the arrow points at the Tavern")
	_expect(town.arrow.visible, "the arrow shows")
	_expect(Sound.current_tune() == "hometown", "the town has its music")
	_expect(town.gold_chip.amount == TownData.START_GOLD, "the top bar shows the gold")
	_expect(town.back.position == Kit.BACK_POSITION, "Back is in its usual place")
	town.building("portal").grab_focus()
	await _wait()
	var seen: Array[Control] = [town.building("tavern"), town.building("portal"),
			town.signs["tavern"], town.signs["portal"]]
	# With no window the viewport may have another size, so this measures from its middle.
	var middle := town.get_viewport_rect().size / 2.0
	var screen := Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE))
	for part in seen:
		_expect(screen.encloses(part.get_global_rect()), "%s is on screen" % part.name)
	_expect(not town.signs["tavern"].get_global_rect().intersects(town.building("tavern").get_global_rect()),
			"the sign leaves the Tavern in view")
	_expect(not town.back.get_global_rect().intersects(town.gold_chip.get_global_rect()),
			"Back and the gold stay apart")
	_expect(screen.has_point(town.arrow.global_position), "the arrow is on screen")


func _test_scene_plan() -> void:
	var town := await _open_town()
	var art := town.art
	for path: Array in TownArt.FOLK_PATHS:
		for index in range(1, path.size()):
			for vertex in BoardArt.road_between(path[index - 1], path[index]):
				_expect(art.has_road(vertex), "villagers keep to the road at %s" % vertex)
	for id: String in TownArt.BUILDING_LOTS:
		var lot: Rect2i = TownArt.BUILDING_LOTS[id]
		for cell: Vector2i in art.objects:
			_expect(not lot.has_point(cell), "nothing stands on the %s's lot at %s" % [id, cell])
		var box: Rect2 = town.building(id).get_rect()
		var ground := Rect2(Vector2(lot.position) * GameArt.CELL, Vector2(lot.size) * GameArt.CELL)
		_expect(ground.has_point(box.position + Vector2(box.size.x / 2.0, box.size.y - 1.0)),
				"the %s stands on its lot" % id)
	for cell in TownArt.COTTAGES:
		_expect(not art.has_road(cell) and not art.has_road(cell + Vector2i.ONE), "no cottage stands on a road")
	_expect(not art.smoke_points.is_empty(), "chimneys smoke")
	_expect(not art.water_points.is_empty(), "the river glints")
	_expect(not art.flag_points.is_empty(), "the keep flies flags")


## Rule: the Tavern and the Portal are the only buildings that can be clicked.
func _test_only_two_can_be_visited() -> void:
	var town := await _open_town()
	var buttons: Array[BaseButton] = []
	_collect_any_buttons(town, buttons)
	_expect(buttons.size() == 3, "the town has three things to press")
	for button in buttons:
		_expect(button is TownBuilding or button == town.back, "%s belongs here" % button.name)
	var ids: Array = town.buildings.keys()
	ids.sort()
	_expect(ids == ["portal", "tavern"], "the Tavern and the Portal can be visited")


func _collect_any_buttons(node: Node, into: Array[BaseButton]) -> void:
	if node is BaseButton:
		into.append(node)
	for child in node.get_children():
		_collect_any_buttons(child, into)


func _test_keys() -> void:
	var town := await _open_town()
	var tavern := town.building("tavern")
	var portal := town.building("portal")
	await _tap("ui_right")
	_expect(_focused() == portal, "right reaches the Portal")
	_expect(town.signs["portal"].is_open() and not town.signs["tavern"].is_open(), "the signs follow the focus")
	await _tap("ui_right")
	_expect(_focused() == tavern, "right wraps round to the Tavern")
	await _tap("ui_left")
	_expect(_focused() == portal, "left wraps round to the Portal")
	await _tap("ui_up")
	_expect(_focused() == town.back, "up reaches Back")
	await _tap("ui_down")
	_expect(_focused() == tavern, "down leaves Back for the buildings")
	await _tap("ui_right")
	await _tap("ui_accept")
	await _wait()
	_expect(town.page() != null and town.page().visible, "Enter visits the Portal")
	_expect(_focused() == town.page().back, "the visit starts on its Back")
	await _tap("ui_left")
	await _tap("ui_right")
	await _tap("ui_down")
	_expect(_focused() == town.page().back, "the arrows stay in the window")
	await _tap("ui_cancel")
	await _wait()
	_expect(town.page() == null, "Esc closes the window")
	_expect(get_tree().current_scene == town, "and stays in town")
	_expect(_focused() == portal, "focus goes back to the Portal")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "Esc in town goes back to the menu")


func _test_controller() -> void:
	var town := await _open_town()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(_focused() == town.building("portal"), "the pad reaches the Portal")
	await _pad(JOY_BUTTON_A)
	await _wait()
	_expect(town.page() != null, "A visits the Portal")
	await _pad(JOY_BUTTON_B)
	await _wait()
	_expect(town.page() == null, "B closes the window")
	_expect(_focused() == town.building("portal"), "focus goes back to the Portal")
	await _pad(JOY_BUTTON_DPAD_UP)
	_expect(_focused() == town.back, "the pad reaches Back")
	await _pad(JOY_BUTTON_B)
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "B in town goes back to the menu")


func _test_mouse() -> void:
	var town := await _open_town()
	var portal := town.building("portal")
	await get_tree().create_timer(Screens.WIPE_SECONDS).timeout
	portal._on_mouse_entered()
	await _wait()
	_expect(_focused() == portal, "hovering takes the focus")
	_expect(portal.is_lit() and portal.shown_offset == KitButton.LIFT, "hovering lifts and lights")
	_expect(town.signs["portal"].is_open(), "hovering opens the sign")
	portal._on_mouse_exited()
	await _click(portal)
	await _wait()
	_expect(town.page() != null, "a click visits the Portal")
	await _click(town.page().back)
	await _wait()
	_expect(town.page() == null, "a click on Back closes the window")
	await _click(town.back)
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "a click on Back leaves the town")


func _test_press() -> void:
	var town := await _open_town()
	var tavern := town.building("tavern")
	await _wait()
	tavern._on_held(true)
	await _wait()
	_expect(tavern.shown_offset == KitButton.DEPTH, "pressing sinks a building")
	tavern._on_held(false)
	await _wait()
	_expect(tavern.shown_offset == KitButton.LIFT, "letting go lifts it again")


func _test_arrow_follows_the_plan() -> void:
	TownData.start_new()
	TownData.current().hire(Database.adventurers_by_fee()[0])
	var town: TownScreen = await _open(TOWN)
	_expect(town.arrow.target == town.building("portal"), "with someone hired, the arrow moves to the Portal")
	_expect(_focused() == town.building("portal"), "and so does the focus")
	_expect(town.waiting != null, "the hired adventurer waits in town")
	TownData.start_new()


func _test_tavern_door() -> void:
	await _open_town()
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is TavernScreen, "Enter on the Tavern goes inside")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc in the Tavern goes back to town")
	var town: TownScreen = get_tree().current_scene
	_expect(_focused() == town.building("tavern"), "and the Tavern has focus again")
