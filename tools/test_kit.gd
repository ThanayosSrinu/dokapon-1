extends Node
## Tests the UI kit and the main menu with mouse, keyboard and controller, with no
## window. Run from the project root:
##   godot --headless --path . res://tools/test_kit.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures. Its
## settings go in _work/saves_test, not with real ones.

const MENU := "res://ui/menu/MainMenu.tscn"
const TOWN := "res://town/TownScreen.tscn"
const GALLERY := "res://ui/kit/KitGallery.tscn"
const ART_FOLDERS: Array[String] = ["res://assets/custom/kit", "res://assets/custom/menu",
		"res://assets/custom/town", "res://assets/custom/tavern", "res://assets/custom/portal",
		"res://assets/custom/bank"]
const WAIT := 0.15
const WIDE := Vector2i(1280, 720)

var _failures := 0


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	# This test must outlive the scenes it changes between.
	get_tree().current_scene = null
	_test_art_is_2x()
	_test_icons()
	await _test_button_states()
	await _test_blocked_button()
	await _test_bar_and_chip()
	await _test_tips_follow_focus()
	await _test_arrow()
	await _test_menu_with_keys()
	await _test_menu_with_controller()
	await _test_menu_with_mouse()
	await _test_pages()
	await _test_gallery()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Art --------------------------------------------------------------------

## Every picture must be exactly doubled, so that all pixels are the same size.
func _test_art_is_2x() -> void:
	for folder in ART_FOLDERS:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".png"):
				continue
			var path := folder.path_join(file)
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			image.convert(Image.FORMAT_RGBA8)
			var width := image.get_width()
			var height := image.get_height()
			_expect(width % 2 == 0 and height % 2 == 0, "%s has even sides" % file)
			var small := image.duplicate()
			small.resize(width / 2, height / 2, Image.INTERPOLATE_NEAREST)
			small.resize(width, height, Image.INTERPOLATE_NEAREST)
			_expect(small.get_data() == image.get_data(), "%s is exactly 2x" % file)


func _test_icons() -> void:
	_expect(Kit.ICONS.get_width() == Kit.ICON_NAMES.size() * Kit.ICON_SIZE, "there is art for every icon")
	var names := {}
	for icon_name in Kit.ICON_NAMES:
		names[icon_name] = true
	_expect(names.size() == Kit.ICON_NAMES.size(), "no icon name is used twice")


# --- Parts ------------------------------------------------------------------

func _test_button_states() -> void:
	var button := KitButton.new()
	button.text = "Try"
	add_child(button)
	button.size = button.get_combined_minimum_size()
	await _wait()
	_expect(button.shown_offset == 0.0, "a button rests at first")
	_expect(button._chosen_look() == KitButton.Look.REST, "a button looks at rest at first")
	var home := button.position
	button.grab_focus()
	await _wait()
	_expect(button.shown_offset == KitButton.LIFT, "focus lifts a button")
	_expect(button.position == home, "lifting leaves the clickable area alone")
	button._on_held(true)
	await _wait()
	_expect(button.shown_offset == KitButton.DEPTH, "pressing sinks a button")
	button._on_held(false)
	await _wait()
	_expect(button.shown_offset == KitButton.LIFT, "letting go lifts it again")
	button.release_focus()
	await _wait()
	_expect(button.shown_offset == 0.0, "losing focus sets it down")
	_expect(button.shown_offset == Kit.snap(button.shown_offset), "movement stays on the pixel grid")
	var clicks := [0]
	button.pressed.connect(func() -> void: clicks[0] += 1)
	button.grab_focus()
	await _send(_action("ui_accept", true))
	await _send(_action("ui_accept", false))
	_expect(clicks[0] == 1, "Enter presses a focused button once")
	button.queue_free()


func _test_blocked_button() -> void:
	var button := KitButton.new()
	button.text = "Hire"
	add_child(button)
	button.block("You need 120 more gold.")
	var clicks := [0]
	button.pressed.connect(func() -> void: clicks[0] += 1)
	_expect(button.disabled, "a blocked button is off")
	button.grab_focus()
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	_expect(Tips.showing() and Tips.shown_text() == "You need 120 more gold.",
			"focusing a blocked button says why")
	await _send(_action("ui_accept", true))
	await _send(_action("ui_accept", false))
	_expect(clicks[0] == 0, "a blocked button does nothing")
	button.block("")
	_expect(not button.disabled, "an empty reason turns a button back on")
	await _wait()
	_expect(not Tips.showing(), "a button that is back on has no reason to show")
	button.queue_free()


func _test_bar_and_chip() -> void:
	var bar := KitBar.new(Kit.HEALTH, Kit.icon("heart"))
	add_child(bar)
	bar.set_amount(50.0, 100.0, false)
	_expect(is_equal_approx(bar.shown, 0.5), "a bar can jump to a value")
	bar.set_amount(20.0, 100.0)
	await get_tree().create_timer(KitBar.SLIDE_SECONDS + WAIT).timeout
	_expect(is_equal_approx(bar.shown, 0.2), "a bar slides to a new value")
	_expect(bar.lingering > bar.shown, "what was lost lingers for a moment")
	bar.set_amount(500.0, 100.0, false)
	_expect(is_equal_approx(bar.shown, 1.0), "a bar never overflows")
	bar.set_amount(1.0, 0.0, false)
	_expect(bar.shown == 0.0, "a bar with no maximum stays empty")
	bar.queue_free()

	var chip := KitChip.new("coin", 10)
	add_child(chip)
	chip.set_amount(90)
	await get_tree().create_timer(KitChip.ROLL_SECONDS + WAIT).timeout
	_expect(chip._label.text == "90", "a chip rolls to its new number")
	chip.queue_free()

	var stat := KitStat.new("sword", "AT")
	add_child(stat)
	stat.set_value(16, 16, false)
	_expect(not stat.is_low and stat._number.text == "16", "a stat at its normal value is plain")
	stat.set_value(12, 16)
	await get_tree().create_timer(KitStat.ROLL_SECONDS + WAIT).timeout
	_expect(stat._number.text == "12", "a stat rolls to its new number")
	_expect(stat.is_low and stat._number.modulate == KitStat.LOW, "a lowered stat stays red")
	stat.set_value(16, 16, false)
	_expect(not stat.is_low and stat._number.modulate == Color.WHITE, "a stat back to normal is plain")
	stat.queue_free()


func _test_tips_follow_focus() -> void:
	var first := KitButton.new()
	var second := KitButton.new()
	add_child(first)
	add_child(second)
	first.position = Vector2(400, 300)
	second.position = Vector2(400, 500)
	Tips.attach(first, "One", "The first tip")
	first.grab_focus()
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	_expect(Tips.showing(), "a tip opens on focus")
	second.grab_focus()
	await _wait()
	_expect(not Tips.showing(), "a tip closes when focus moves on")
	first.grab_focus()
	await get_tree().create_timer(Tips.DELAY + WAIT).timeout
	first.free()
	await _wait()
	_expect(not Tips.showing(), "a tip closes when its control goes away")
	second.queue_free()


func _test_arrow() -> void:
	var target := KitButton.new()
	add_child(target)
	target.position = Vector2(300, 300)
	var arrow := KitArrow.new(target, KitArrow.Side.ABOVE)
	add_child(arrow)
	await _wait()
	_expect(arrow.visible and arrow.global_position.y < target.position.y, "the arrow stands above its target")
	target.hide()
	await _wait()
	_expect(not arrow.visible, "the arrow hides with its target")
	target.free()
	await _wait()
	_expect(not arrow.visible, "the arrow survives losing its target")
	arrow.queue_free()


# --- The menu ---------------------------------------------------------------

func _open(path: String) -> Node:
	await Screens.go(path)
	await _wait()
	return get_tree().current_scene


func _test_menu_with_keys() -> void:
	var menu: MainMenu = await _open(MENU)
	_expect(get_viewport().gui_get_focus_owner() == menu.play_button, "Play has focus at the start")
	_expect(menu.play_button.kind == KitButton.Kind.PRIMARY, "Play is the main action")
	_expect(Sound.current_tune() == "title", "the menu has its music")
	for button: KitButton in [menu.play_button, menu.help_button, menu.options_button, menu.quit_button]:
		_expect(button.size.x >= button.get_combined_minimum_size().x, "%s fits" % button.text)
		_expect(button.get_global_rect().end.x <= WIDE.x and button.get_global_rect().end.y <= WIDE.y,
				"%s is on screen" % button.text)
	await _tap("ui_down")
	_expect(_focused() == menu.help_button, "down moves to How to Play")
	await _tap("ui_down")
	await _tap("ui_down")
	_expect(_focused() == menu.quit_button, "down reaches Quit")
	await _tap("ui_down")
	_expect(_focused() == menu.play_button, "down wraps round to Play")
	await _tap("ui_up")
	_expect(_focused() == menu.quit_button, "up wraps round to Quit")
	await _tap("ui_up")
	await _tap("ui_accept")
	await _wait()
	_expect(menu.options_page().visible, "Enter opens Options")
	await _tap("ui_cancel")
	_expect(not menu.options_page().visible, "Esc closes Options")
	_expect(_focused() == menu.options_button, "focus goes back to Options")
	await _tap("ui_cancel")
	_expect(_focused() == menu.quit_button, "Esc on the menu goes to Quit")
	menu.play_button.grab_focus()
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Play leads to the town")
	var town: TownScreen = get_tree().current_scene
	_expect(_focused() == town.building("tavern"), "the town starts on the Tavern")
	_expect(town.back.position == Kit.BACK_POSITION, "Back is in its usual place")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "Esc goes back to the menu")


func _test_menu_with_controller() -> void:
	var menu: MainMenu = await _open(MENU)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(_focused() == menu.help_button, "the pad moves down")
	await _pad(JOY_BUTTON_A)
	await _wait()
	_expect(menu.help_page().visible, "A opens How to Play")
	await _pad(JOY_BUTTON_B)
	_expect(not menu.help_page().visible, "B closes How to Play")
	menu.play_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "A on Play leads to the town")
	await _pad(JOY_BUTTON_B)
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "B goes back to the menu")


func _test_menu_with_mouse() -> void:
	var menu: MainMenu = await _open(MENU)
	await get_tree().create_timer(1.0).timeout
	menu.options_button._on_mouse_entered()
	await _wait()
	_expect(_focused() == menu.options_button, "hovering takes the focus")
	_expect(menu.options_button.shown_offset == KitButton.LIFT, "hovering lifts")
	await _click(menu.play_button)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "a click on Play leads to the town")
	var town: TownScreen = get_tree().current_scene
	await _click(town.back)
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "a click on Back returns to the menu")


func _test_pages() -> void:
	var menu: MainMenu = await _open(MENU)
	menu.help_button.pressed.emit()
	await _wait()
	var help := menu.help_page()
	_expect(_focused() == help._next, "How to Play starts on Next")
	_expect(help._previous.disabled, "there is nothing before the first page")
	for page in MenuHelp.PAGES.size() - 1:
		await _tap("ui_right")
	_expect(help._page == MenuHelp.PAGES.size() - 1, "right turns the pages")
	_expect(_focused() == help._previous, "focus leaves Next at the last page")
	await _tap("ui_cancel")

	var music := Settings.music_volume
	menu.options_button.pressed.emit()
	await _wait()
	var options := menu.options_page()
	_expect(_focused() == options.row(0), "Options starts on its first row")
	await _tap("ui_left")
	_expect(Settings.music_volume == posmod(music - Settings.VOLUME_STEP, 110), "left lowers the music")
	await _tap("ui_right")
	_expect(Settings.music_volume == music, "right raises it again")
	await _tap("ui_up")
	_expect(_focused() == options.row(3), "up wraps round the rows")
	var shake := Settings.screen_shake
	await _tap("ui_accept")
	_expect(Settings.screen_shake != shake, "Enter flips a switch")
	await _tap("ui_accept")
	await _tap("ui_cancel")
	DirAccess.remove_absolute(SaveGame.folder().path_join(Settings.FILE_NAME))


func _test_gallery() -> void:
	var gallery: KitGallery = await _open(GALLERY)
	_expect(gallery.size.x > 0.0, "the gallery opens")
	var buttons: Array[KitButton] = []
	_collect_buttons(gallery, buttons)
	var looks := {}
	for button in buttons:
		looks[button.forced_look] = true
		var box := button.get_global_rect()
		_expect(box.end.x <= WIDE.x and box.end.y <= WIDE.y, "the %s button is on screen" % button.text)
	_expect(looks.size() == KitButton.Look.size(), "the gallery shows every look of a button")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is MainMenu, "Back leaves the gallery")


func _collect_buttons(node: Node, into: Array[KitButton]) -> void:
	if node is KitButton:
		into.append(node)
	for child in node.get_children():
		_collect_buttons(child, into)


# --- Helpers ----------------------------------------------------------------

func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _wait() -> void:
	# Real time, so that a test can look around while the game's time stands still.
	await get_tree().create_timer(WAIT, true, false, true).timeout


func _until_settled() -> void:
	await get_tree().process_frame
	while Screens.busy:
		await get_tree().process_frame
	await _wait()


func _action(action: String, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _tap(action: String) -> void:
	await _send(_action(action, true))
	await _send(_action(action, false))


func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	await _send(event)
	var release := InputEventJoypadButton.new()
	release.button_index = button
	release.pressed = false
	await _send(release)


func _click(button: Control) -> void:
	await _click_at(button.get_global_rect().get_center())


func _click_at(spot: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = spot
	move.global_position = spot
	await _send(move)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = spot
		event.global_position = spot
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		await _send(event)


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)
