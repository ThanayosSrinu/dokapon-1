class_name LearnPrompt
extends CenterContainer
## Asks what to forget when a tome teaches a move and that kind of move is full.
##     var read: bool = await learn_prompt.ask(trip, "tome_mend")
## ask() has already read the tome by the time it returns.

## Emitted by a button, with the move to forget, or "" to keep the tome unread.
signal _choice_made(forgotten: String)

const WIDTH := 420.0

var _heading: Label
var _rows: Container
var _keep: Button


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	_heading = Label.new()
	_heading.add_theme_color_override("font_color", GameArt.GOLD)
	_heading.add_theme_font_size_override("font_size", 22)
	box.add_child(_heading)
	var words := Label.new()
	words.text = "Forget one to make room:"
	box.add_child(words)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_keep = Button.new()
	_keep.pressed.connect(func() -> void: _choice_made.emit(""))
	box.add_child(_keep)
	hide()


## Shows the choice. Returns true if the tome was read.
func ask(trip: Expedition, item_id: String) -> bool:
	var taught := Database.get_move(Database.get_item(item_id).teaches)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_heading.text = "Learn %s?" % taught.display_name
	for move_id in trip.player.learned:
		var row := Button.new()
		row.text = Database.get_move(move_id).display_name
		row.pressed.connect(func() -> void: _choice_made.emit(move_id))
		_rows.add_child(row)
	_keep.text = "Keep what I know"
	show()
	_keep.grab_focus()
	var forgotten: String = await _choice_made
	hide()
	return forgotten != "" and trip.read_by_hand(item_id, forgotten)


## Every button a person could press right now. Tests use this.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = [_keep]
	for row in _rows.get_children():
		found.append(row)
	return found
