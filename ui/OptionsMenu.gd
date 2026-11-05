class_name OptionsMenu
extends CenterContainer
## Sound, speed and screen settings, from the title or the pause menu. Each row is one
## button: left and right change it, and pressing it moves to the next value. Changes
## take effect and are saved straight away.

## Emitted when the menu closes.
signal closed

const WIDTH := 400.0
const SHADE := Color(0.03, 0.04, 0.12, 0.6)
const SPEED_NAMES: Array[String] = ["Normal", "Fast", "Very Fast"]

var _rows: Array[Button] = []
var _updaters: Array[Callable] = []
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Options"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", GameArt.GOLD)
	heading.add_theme_font_size_override("font_size", 28)
	box.add_child(heading)

	_add_row(box, func() -> String: return "Music: %d" % Settings.music_volume,
			func(step: int) -> void:
				Settings.music_volume = _next_volume(Settings.music_volume, step))
	_add_row(box, func() -> String: return "Sound: %d" % Settings.sfx_volume,
			func(step: int) -> void:
				Settings.sfx_volume = _next_volume(Settings.sfx_volume, step))
	_add_row(box, func() -> String:
				return "CPU Turns: %s" % SPEED_NAMES[Settings.CPU_SPEEDS.find(Settings.cpu_speed)],
			func(step: int) -> void:
				var count := Settings.CPU_SPEEDS.size()
				var index := Settings.CPU_SPEEDS.find(Settings.cpu_speed)
				Settings.cpu_speed = Settings.CPU_SPEEDS[posmod(index + step, count)])
	_add_row(box, func() -> String: return "Fullscreen: %s" % _on_off(Settings.fullscreen),
			func(_step: int) -> void: Settings.fullscreen = not Settings.fullscreen)
	_add_row(box, func() -> String: return "Screen Shake: %s" % _on_off(Settings.screen_shake),
			func(_step: int) -> void: Settings.screen_shake = not Settings.screen_shake)

	_back = Button.new()
	_back.text = "Back"
	_back.pressed.connect(close)
	box.add_child(_back)
	# Going off either end wraps round, instead of reaching a menu underneath.
	_rows[0].focus_neighbor_top = _rows[0].get_path_to(_back)
	_back.focus_neighbor_bottom = _back.get_path_to(_rows[0])
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		Sound.play("back")
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	show()
	_rows[0].grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _add_row(box: Container, text: Callable, change: Callable) -> void:
	var row := Button.new()
	row.pressed.connect(_change.bind(change, 1))
	row.gui_input.connect(_on_row_input.bind(row, change))
	box.add_child(row)
	_rows.append(row)
	_updaters.append(func() -> void: row.text = text.call())


func _on_row_input(event: InputEvent, row: Button, change: Callable) -> void:
	for action: String in ["ui_left", "ui_right"]:
		if event.is_action_pressed(action, true):
			_change(change, -1 if action == "ui_left" else 1)
			row.accept_event()


func _change(change: Callable, step: int) -> void:
	change.call(step)
	Settings.apply()
	Settings.save()
	_refresh()


func _refresh() -> void:
	for updater in _updaters:
		updater.call()


func _next_volume(volume: int, step: int) -> int:
	return posmod(volume + step * Settings.VOLUME_STEP, 100 + Settings.VOLUME_STEP)


func _on_off(value: bool) -> String:
	return "On" if value else "Off"
