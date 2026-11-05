class_name BagPrompt
extends CenterContainer
## Asks what to do when something is found but the bag is full.
##     var kept: bool = await bag_prompt.ask(player, "potion")
## ask() has already changed the bag by the time it returns.

## Emitted by a button, with the item to drop, or "" to leave the new item behind.
signal _choice_made(dropped_id: String)

const WIDTH := 420.0

var _message: Label
var _found: Container
var _rows: Container
var _leave: Button


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

	var heading := Label.new()
	heading.text = "Your bag is full"
	heading.add_theme_color_override("font_color", GameArt.GOLD)
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)
	_found = VBoxContainer.new()
	box.add_child(_found)
	_message = Label.new()
	_message.text = "Drop something to make room:"
	box.add_child(_message)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	box.add_child(_rows)
	_leave = Button.new()
	_leave.pressed.connect(func() -> void: _choice_made.emit(""))
	box.add_child(_leave)
	hide()


## Shows the choice. Returns true if `item_id` ended up in the bag.
func ask(player: PlayerData, item_id: String) -> bool:
	var item := Database.get_item(item_id)
	_clear(_found)
	_clear(_rows)
	var found := ItemRow.new()
	found.setup(item_id, item.effect_text())
	found.focus_mode = Control.FOCUS_NONE
	found.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_found.add_child(found)
	for bag_id in player.inventory:
		var row := ItemRow.new()
		row.setup(bag_id, Database.get_item(bag_id).effect_text())
		row.pressed.connect(func() -> void: _choice_made.emit(bag_id))
		_rows.add_child(row)
	_leave.text = "Leave the %s" % item.display_name
	show()
	_leave.grab_focus()
	var dropped: String = await _choice_made
	hide()
	if dropped == "":
		return false
	player.remove_item(dropped)
	return player.add_item(item_id)


## Every button a person could press right now. Tests use this.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = [_leave]
	for row in _rows.get_children():
		found.append(row)
	return found


# Freed right away: queue_free() would leave old rows in the layout this frame.
func _clear(parent: Container) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
