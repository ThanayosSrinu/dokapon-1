class_name PauseMenu
extends CenterContainer
## Stops the game while it is open. Everything else in the scene waits, and this
## keeps running because of its process_mode. GameController does what the buttons
## ask for.

signal save_pressed
signal load_pressed
signal title_pressed
## Emitted when the game carries on.
signal closed

const WIDTH := 340.0
const SHADE := Color(0.03, 0.04, 0.12, 0.6)

var _resume: Button
var _note: Label


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
	heading.text = "Paused"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", GameArt.GOLD)
	heading.add_theme_font_size_override("font_size", 28)
	box.add_child(heading)
	_resume = _add_button(box, "Resume", close)
	_add_button(box, "Save Game", save_pressed.emit)
	_add_button(box, "Load Game", load_pressed.emit)
	_add_button(box, "Back to Title", title_pressed.emit)
	_add_button(box, "Quit", func() -> void: get_tree().quit())
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Stops the game. `note` says what saving would keep.
func open(note: String) -> void:
	_note.text = note
	get_tree().paused = true
	show()
	take_focus()


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func take_focus() -> void:
	_resume.grab_focus()


func _add_button(box: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
	return button
