extends Node
## Tests sound, settings, controller support and the export setup, with no window.
## Run from the project root:
##   godot --headless --path . res://tools/test_polish.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures. Its
## settings go in _work/saves_test, not with real ones.

const SPEED := 300.0
const SOURCE_FOLDERS: Array[String] = ["res://autoload", "res://board", "res://combat", "res://main",
		"res://player", "res://ui", "res://ui/kit", "res://ui/menu", "res://town", "res://portal"]

var _failures := 0


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	_test_sound_files()
	_test_sound_names_in_code()
	_test_buses()
	_test_settings_file()
	await _test_options_menu()
	await _test_buttons_click()
	_test_input_map()
	await _test_controller_play()
	await _test_pace()
	await _test_game_end()
	_test_export_setup()
	DirAccess.remove_absolute(SaveGame.folder().path_join(Settings.FILE_NAME))
	get_tree().paused = false
	Engine.time_scale = 1.0
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Sound ------------------------------------------------------------------

func _test_sound_files() -> void:
	for tune in Sound.TUNES:
		var stream: AudioStreamWAV = load(Sound.FOLDER % tune)
		_expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the %s tune loops" % tune)
		_expect(stream.get_length() > 15.0, "and runs a while")
	for sound in Sound.EFFECTS:
		var stream: AudioStreamWAV = load(Sound.FOLDER % sound)
		_expect(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the %s sound stops by itself" % sound)
		_expect(stream.get_length() < 4.0, "and is short")


## Reads the game's source: a mistyped sound name would otherwise only show up as an
## error on the day that line runs, and an unused sound would never be heard.
func _test_sound_names_in_code() -> void:
	var played := {}
	var tunes := {}
	var pattern := RegEx.create_from_string("Sound\\.(play|music)\\(\"(\\w+)\"")
	var either := RegEx.create_from_string("Sound\\.play\\(\"(\\w+)\" if .* else \"(\\w+)\"\\)")
	var bound := RegEx.create_from_string("play\\.bind\\(\"(\\w+)\"\\)")
	for path in _source_files():
		var text := FileAccess.get_file_as_string(path)
		for found in pattern.search_all(text):
			(played if found.get_string(1) == "play" else tunes)[found.get_string(2)] = path
		for found in either.search_all(text):
			played[found.get_string(1)] = path
			played[found.get_string(2)] = path
		for found in bound.search_all(text):
			played[found.get_string(1)] = path
	played["hover"] = "the buttons"
	for sound: String in played:
		_expect(Sound.EFFECTS.has(sound), "%s plays a real sound, not '%s'" % [played[sound], sound])
	for tune: String in tunes:
		_expect(Sound.TUNES.has(tune), "%s plays a real tune, not '%s'" % [tunes[tune], tune])
	for sound in Sound.EFFECTS:
		_expect(played.has(sound), "the %s sound gets used" % sound)
	for tune in Sound.TUNES:
		_expect(tunes.has(tune), "the %s tune gets used" % tune)


func _test_buses() -> void:
	_expect(AudioServer.get_bus_index("Music") > 0, "there is a Music bus")
	_expect(AudioServer.get_bus_index("Sfx") > 0, "and a Sfx bus")
	Sound.music("battle")
	_expect(Sound.current_tune() == "battle", "music starts")
	Sound.music("")
	_expect(Sound.current_tune() == "", "and stops")


# --- Settings ---------------------------------------------------------------

func _test_settings_file() -> void:
	Settings.music_volume = 30
	Settings.sfx_volume = 0
	Settings.cpu_speed = 4.0
	Settings.screen_shake = false
	Settings.apply()
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Sfx")), "volume 0 mutes")
	_expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "and only that bus")
	Settings.save()
	Settings.music_volume = 90
	Settings.sfx_volume = 90
	Settings.cpu_speed = 1.0
	Settings.screen_shake = true
	Settings.load_file()
	_expect(Settings.music_volume == 30 and Settings.sfx_volume == 0, "volumes survive a restart")
	_expect(Settings.cpu_speed == 4.0 and not Settings.screen_shake, "and so do the rest")

	var path := SaveGame.folder().path_join(Settings.FILE_NAME)
	var junk := FileAccess.open(path, FileAccess.WRITE)
	junk.store_string("[options]\nmusic_volume=9999\nsfx_volume=\"loud\"\ncpu_speed=3.5\nfullscreen=7\n")
	junk.close()
	Settings.load_file()
	_expect(Settings.music_volume == 100 and Settings.sfx_volume == 70, "a bad file gives safe volumes")
	_expect(Settings.cpu_speed == 1.0 and not Settings.fullscreen, "and safe choices")
	Settings.music_volume = 70
	Settings.sfx_volume = 80
	Settings.screen_shake = true
	Settings.apply()


func _test_options_menu() -> void:
	var menu := OptionsMenu.new()
	add_child(menu)
	menu.open()
	var music: Button = menu._rows[0]
	_expect(music.has_focus(), "the first row takes focus")
	Settings.music_volume = 50
	menu._on_row_input(_action("ui_left"), music, _row_change(menu, 0))
	_expect(Settings.music_volume == 40 and music.text == "Music: 40", "left turns it down")
	Settings.music_volume = 100
	music.pressed.emit()
	_expect(Settings.music_volume == 0, "pressing past the top wraps round")
	Settings.cpu_speed = 4.0
	menu._rows[2].pressed.emit()
	_expect(Settings.cpu_speed == 1.0, "CPU speed wraps too")
	menu.close()
	menu.queue_free()
	Settings.music_volume = 70
	Settings.cpu_speed = 1.0
	Settings.apply()
	await get_tree().process_frame


func _test_buttons_click() -> void:
	var button := Button.new()
	add_child(button)
	_expect(button.pressed.get_connections().size() == 1, "a new button gets its click")
	remove_child(button)
	add_child(button)
	_expect(button.pressed.get_connections().size() == 1, "only once, even if it comes back")
	button.queue_free()
	await get_tree().process_frame


# --- Controller -------------------------------------------------------------

func _test_input_map() -> void:
	for action: String in ["game_character", "game_standings", "game_field", "game_menu",
			"camera_zoom_in", "camera_zoom_out"]:
		_expect(_has_event(action, "InputEventJoypadButton"), "%s is on the controller" % action)
	_expect(_has_event("ui_accept", "InputEventJoypadButton"), "A presses buttons")
	_expect(_has_event("ui_cancel", "InputEventJoypadButton"), "B goes back")
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		_expect(_has_event(action, "InputEventJoypadButton"), "%s is on the D-pad" % action)
		_expect(_has_event(action, "InputEventJoypadMotion"), "and the left stick")
	for action: String in ["camera_left", "camera_right", "camera_up", "camera_down"]:
		_expect(_has_event(action, "InputEventJoypadMotion"), "%s is on the right stick" % action)
		_expect(_has_event(action, "InputEventKey"), "and the keyboard")


func _test_controller_play() -> void:
	Engine.time_scale = SPEED
	var main := await _human_game()
	Engine.time_scale = 1.0
	_expect(main.roll_button.has_focus(), "the turn starts on Roll Dice")
	main.roll_button.release_focus()
	_expect(PadInput.rescue_focus() and main.roll_button.has_focus(), "with no focus, a controller finds Roll Dice")

	_press(JOY_BUTTON_Y)
	await get_tree().process_frame
	_expect(main.character_sheet.visible, "Y opens the character sheet")
	main.character_sheet.close_sheet()
	_press(JOY_BUTTON_BACK)
	await get_tree().process_frame
	_expect(main.standings_screen.visible, "Back opens the standings")
	_press(JOY_BUTTON_B)
	await get_tree().process_frame
	_expect(not main.standings_screen.visible, "B closes them")
	_press(JOY_BUTTON_START)
	await get_tree().process_frame
	_expect(main.pause_menu.visible and get_tree().paused, "Start pauses")
	_expect(PadInput.top_button(get_tree().root) == main.pause_menu._resume or
			main.pause_menu._resume.has_focus(), "and the menu has the focus")
	main.pause_menu.options_pressed.emit()
	await get_tree().process_frame
	_expect(main.options_menu.visible and main.options_menu._rows[0].has_focus(), "the pause menu opens Options")
	_press(JOY_BUTTON_B)
	await get_tree().process_frame
	_expect(not main.options_menu.visible and main.pause_menu.visible, "B goes back one step only")
	_expect(main.pause_menu._resume.has_focus(), "with focus back on the menu")
	main.pause_menu.help_pressed.emit()
	await get_tree().process_frame
	_expect(main.help_screen.visible, "the pause menu opens How to Play")
	for page in HelpScreen.PAGES.size():
		main.help_screen._next.pressed.emit()
		await get_tree().process_frame
		var height := main.help_screen._text.get_combined_minimum_size().y
		_expect(height <= HelpScreen.SIZE.y, "page %d fits: %d" % [main.help_screen._page, height])
	main.help_screen.close()
	_press(JOY_BUTTON_START)
	await get_tree().process_frame
	_expect(not main.pause_menu.visible and not get_tree().paused, "Start resumes")

	# A fork, from the point where the token reaches one.
	main.turn_manager.phase = TurnManager.Phase.MOVING
	var nodes: Array[BoardNode] = main.board.get_neighbors(main._active_player().current_node)
	main._on_path_choice_required(nodes)
	_expect(main.choice_box.get_child(0).has_focus(), "a fork can be chosen without a mouse")
	main.queue_free()
	await get_tree().process_frame


# --- Speed ------------------------------------------------------------------

func _test_pace() -> void:
	Engine.time_scale = SPEED
	var main := await _human_game()
	Engine.time_scale = 1.0
	# _set_pace() only acts for the running scene, which sits directly under the root.
	var tree := get_tree()
	var running := tree.current_scene
	remove_child(main)
	tree.root.add_child(main)
	tree.current_scene = main
	Settings.cpu_speed = 4.0
	main._set_pace()
	_expect(Engine.time_scale == 1.0, "a person's turn runs at normal speed")
	main.turn_manager._turn_index = GameState.players.find(_a_cpu())
	main._set_pace()
	_expect(Engine.time_scale == 4.0, "a CPU's turn runs at the chosen speed")
	var duel := Battle.new(Fighter.from_player(_a_cpu()), Fighter.from_player(_a_person()))
	_expect(main._has_human(duel), "a person in a fight is noticed")
	var both_cpu := Battle.new(Fighter.from_player(_a_cpu()), Fighter.from_player(_a_cpu()))
	_expect(not main._has_human(both_cpu), "and two CPUs are not")
	Settings.cpu_speed = 1.0
	tree.current_scene = running
	Engine.time_scale = 1.0
	main.queue_free()
	await get_tree().process_frame


func _test_game_end() -> void:
	Engine.time_scale = SPEED
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 11
	main.game_weeks = 1
	main.cpu_players = 2
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(2)
	while not main.standings_screen.visible:
		await get_tree().process_frame
	await get_tree().process_frame
	var found := false
	for child in main.standings_screen.get_parent().get_children():
		found = found or child is Confetti
	_expect(found, "the winner gets confetti")
	Engine.time_scale = 1.0
	main.queue_free()
	await get_tree().process_frame


# --- Export -----------------------------------------------------------------

func _test_export_setup() -> void:
	var presets := ConfigFile.new()
	_expect(presets.load("res://export_presets.cfg") == OK, "there is an export preset")
	_expect(str(presets.get_value("preset.0", "platform", "")) == "Windows Desktop", "for Windows")
	_expect(str(presets.get_value("preset.0", "include_filter", "")).contains("*.json"),
			"and it carries the map")
	_expect(ProjectSettings.get_setting("application/config/name") == TitleScreen.GAME_TITLE,
			"the window has the game's own name")


# --- Helpers ----------------------------------------------------------------

## A game with one person and one CPU, stopped where the person decides.
func _human_game() -> GameController:
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.cpu_players = 1
	main.game_seed = 11
	main.game_weeks = 1
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(2)
	await get_tree().process_frame
	main.class_menu.class_chosen.emit("warrior")
	while not (main.turn_manager.phase == TurnManager.Phase.ACTION
			and not main.turn_manager.current_player().is_cpu and not main.roll_button.disabled):
		await get_tree().process_frame
	return main


func _a_cpu() -> PlayerData:
	for player in GameState.players:
		if player.is_cpu:
			return player
	return null


func _a_person() -> PlayerData:
	for player in GameState.players:
		if not player.is_cpu:
			return player
	return null


func _row_change(menu: OptionsMenu, _row: int) -> Callable:
	return func(step: int) -> void:
		Settings.music_volume = menu._next_volume(Settings.music_volume, step)


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## A controller button going down, sent the way a real one arrives.
func _press(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventJoypadButton.new()
	release.button_index = button
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _has_event(action: String, type: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event.get_class() == type:
			return true
	return false


func _source_files() -> Array[String]:
	var files: Array[String] = []
	for folder in SOURCE_FOLDERS:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				files.append(folder.path_join(file))
	return files


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)
