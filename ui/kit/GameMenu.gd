extends CanvasLayer
## The game menu: Esc, or the controller's Start button, opens it on any screen after
## the title. The game stops while it is open. Registered as the "GameMenu" autoload.
## A screen that has something of its own to close on Esc catches it first.

const TITLE := "Paused"
const WIDTH := 360.0
## Where the game runs its own pause menu, or has its own way out.
const OWN_MENU: Array[String] = ["MainMenu", "GameController"]
const TRIP_LOST := "Quitting now loses this trip."

var panel: KitPanel
var resume_button: KitButton
var options_button: KitButton
var quit_button: KitButton
var options: MenuOptions

var _holder: Control
var _trip_note: Label
var _focus_before: Control


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_holder = ColorRect.new()
	(_holder as ColorRect).color = Kit.DIM
	_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(center)
	panel = KitPanel.new(TITLE, true)
	panel.custom_minimum_size.x = WIDTH
	center.add_child(panel)
	resume_button = _add_button("Resume", "play", KitButton.Kind.PRIMARY, close)
	options_button = _add_button("Options", "gear", KitButton.Kind.NORMAL, _open_options)
	quit_button = _add_button("Quit Game", "door", KitButton.Kind.NORMAL, _quit)
	_trip_note = Kit.text(TRIP_LOST, WIDTH - 40.0, &"PaperLabel")
	_trip_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trip_note.add_theme_color_override("font_color", Kit.BLOOD)
	panel.body.add_child(_trip_note)
	var buttons: Array[KitButton] = [resume_button, options_button, quit_button]
	for index in buttons.size():
		var button := buttons[index]
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
		button.focus_neighbor_top = button.get_path_to(buttons[index - 1])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % buttons.size()])
	_holder.hide()
	options = MenuOptions.new()
	options.closed.connect(_on_options_closed)
	add_child(options)


## True for the Esc key, which opens this menu, as opposed to the controller's B button.
static func is_esc(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE


func is_open() -> bool:
	return _holder.visible or options.visible


func _unhandled_input(event: InputEvent) -> void:
	if Screens.busy:
		return
	var asked := is_esc(event) and event.is_pressed() and not event.is_echo()
	asked = asked or event.is_action_pressed("game_menu")
	if _holder.visible and not options.visible:
		if asked or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			Sound.play("back")
			close()
	elif not options.visible and asked and _can_open():
		get_viewport().set_input_as_handled()
		open()


## Stops the game and shows the menu.
func open() -> void:
	_focus_before = get_viewport().gui_get_focus_owner()
	Tips.close()
	get_tree().paused = true
	_trip_note.visible = _on_a_trip()
	_holder.show()
	resume_button.grab_focus()
	panel.play_open()


## Lets the game go on.
func close() -> void:
	_holder.hide()
	options.hide()
	panel.show()
	get_tree().paused = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _can_open() -> bool:
	var scene := get_tree().current_scene
	if scene == null or get_tree().paused:
		return false
	if not scene.find_children("*", "GameController", true, false).is_empty():
		return false
	for owner_name in OWN_MENU:
		var script := scene.get_script() as Script
		if script != null and script.get_global_name() == owner_name:
			return false
	return true


func _on_a_trip() -> bool:
	var scene := get_tree().current_scene
	return scene is ExpeditionScreen and (scene as ExpeditionScreen).report == null


# The menu's shade stays, so the screen's own buttons fade well under Options.
func _open_options() -> void:
	panel.hide()
	options.open()


func _on_options_closed() -> void:
	panel.show()
	options_button.grab_focus()


func _quit() -> void:
	get_tree().paused = false
	Screens.quit()


func _add_button(words: String, icon_name: String, kind: KitButton.Kind, action: Callable) -> KitButton:
	var button := KitButton.new()
	button.text = words
	button.icon = Kit.icon(icon_name)
	button.kind = kind
	button.pressed.connect(action)
	panel.body.add_child(button)
	return button
