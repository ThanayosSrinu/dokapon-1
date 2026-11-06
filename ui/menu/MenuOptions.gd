class_name MenuOptions
extends KitPage
## Sound and screen settings. Each row is one button: left and right change it, and
## pressing it moves to the next value. Changes take effect and save straight away.

const WIDTH := 460.0
const VOLUME_BAR := 180.0
const BAR_EDGE := 22.0

var _rows: Array[KitButton] = []
var _updaters: Array[Callable] = []


func _init() -> void:
	super("Options")
	_add_volume("Music", "music", func() -> int: return Settings.music_volume,
			func(value: int) -> void: Settings.music_volume = value)
	_add_volume("Sound", "sound", func() -> int: return Settings.sfx_volume,
			func(value: int) -> void: Settings.sfx_volume = value)
	_add_switch("Fullscreen", func() -> bool: return Settings.fullscreen,
			func(value: bool) -> void: Settings.fullscreen = value)
	_add_switch("Screen Shake", func() -> bool: return Settings.screen_shake,
			func(value: bool) -> void: Settings.screen_shake = value)


func _ready() -> void:
	super()
	# Going off either end wraps round.
	_rows[0].focus_neighbor_top = _rows[0].get_path_to(_rows[-1])
	_rows[-1].focus_neighbor_bottom = _rows[-1].get_path_to(_rows[0])


func open() -> void:
	_refresh()
	super()


func first_focus() -> Control:
	return _rows[0]


func row(index: int) -> KitButton:
	return _rows[index]


func _add_row(words: String, picture: Texture2D, change: Callable) -> KitButton:
	var line := KitButton.new()
	line.text = words
	line.icon = picture
	line.left_aligned = true
	line.custom_minimum_size.x = WIDTH
	line.pressed.connect(_change.bind(change, 1))
	line.gui_input.connect(_on_row_input.bind(line, change))
	panel.body.add_child(line)
	_rows.append(line)
	return line


func _add_volume(words: String, icon_name: String, read: Callable, write: Callable) -> void:
	var change := func(step: int) -> void:
		var top := 100 + Settings.VOLUME_STEP
		write.call(posmod(int(read.call()) + step * Settings.VOLUME_STEP, top))
	var line := _add_row(words, Kit.icon(icon_name), change)
	var bar := KitBar.new(Kit.GOLD)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.width = VOLUME_BAR
	bar.position = Vector2(WIDTH - VOLUME_BAR - BAR_EDGE, 16.0)
	bar.size = Vector2(VOLUME_BAR, KitBar.BAR_HEIGHT)
	line.add_child(bar)
	_updaters.append(func() -> void: bar.set_amount(float(read.call()), 100.0, visible))


func _add_switch(words: String, read: Callable, write: Callable) -> void:
	var line := _add_row(words, null, func(_step: int) -> void: write.call(not read.call()))
	_updaters.append(func() -> void:
			var on: bool = read.call()
			line.icon = Kit.icon("check" if on else "cross")
			Tips.attach(line, words, "On" if on else "Off"))


func _on_row_input(event: InputEvent, line: KitButton, change: Callable) -> void:
	for action: String in ["ui_left", "ui_right"]:
		if event.is_action_pressed(action, true):
			Sound.play("click")
			_change(change, -1 if action == "ui_left" else 1)
			line.accept_event()


func _change(change: Callable, step: int) -> void:
	change.call(step)
	Settings.apply()
	Settings.save()
	_refresh()


func _refresh() -> void:
	for updater in _updaters:
		updater.call()
