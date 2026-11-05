class_name SaveMenu
extends CenterContainer
## Lists the save slots, for saving or for loading. It only reports which slot was
## picked: GameController does the rest. Saving over a slot takes a second press.

## Emitted with the slot that was picked.
signal slot_chosen(slot: String)
## Emitted when the menu goes away.
signal closed

const WIDTH := 560.0
const SHADE := Color(0.03, 0.04, 0.12, 0.85)
const SLOT_NAMES := {SaveGame.AUTO: "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}

## True when picking a slot saves to it, false when it loads from it.
var saving := false

var _heading: Label
var _rows: Container
var _note: Label
var _back: Button
# The slot that needs one more press before it is saved over.
var _armed := ""


func _ready() -> void:
	# It opens from the pause menu, so it must run while the game is stopped.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_heading = Label.new()
	_heading.add_theme_color_override("font_color", GameArt.GOLD)
	_heading.add_theme_font_size_override("font_size", 22)
	box.add_child(_heading)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	_back = Button.new()
	_back.text = "Back"
	_back.pressed.connect(close)
	box.add_child(_back)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		Sound.play("back")
		close()
		get_viewport().set_input_as_handled()


func open(for_saving: bool) -> void:
	saving = for_saving
	_heading.text = "Save Game" if saving else "Load Game"
	note("")
	show()
	refresh()


func close() -> void:
	hide()
	closed.emit()


## Reads the slots again and rebuilds the list.
func refresh() -> void:
	_armed = ""
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var slots: Array[String] = []
	if not saving:
		slots.append(SaveGame.AUTO)
	slots.append_array(SaveGame.SLOTS)
	for slot in slots:
		var button := Button.new()
		button.text = _row_text(slot)
		button.disabled = not saving and not SaveGame.has_file(slot)
		button.pressed.connect(_on_slot_pressed.bind(slot, button))
		_rows.add_child(button)
	for row: Button in _rows.get_children():
		if not row.disabled:
			row.grab_focus()
			return
	_back.grab_focus()


## Shows a line under the list.
func note(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


func _row_text(slot: String) -> String:
	var title: String = SLOT_NAMES[slot]
	if not SaveGame.has_file(slot):
		return "%s: empty" % title
	var save := SaveGame.read(slot)
	if save.get("version") != SaveGame.VERSION or not save.has_all(SaveGame.KEYS):
		return "%s: cannot be read" % title
	return "%s: %s" % [title, SaveGame.describe(save)]


func _on_slot_pressed(slot: String, button: Button) -> void:
	if saving and SaveGame.has_file(slot) and _armed != slot:
		_armed = slot
		button.text = "%s: press again to save over this" % SLOT_NAMES[slot]
		return
	slot_chosen.emit(slot)
