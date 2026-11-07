class_name MaterialPrompt
extends CenterContainer
## Asks what to do when a material is found but the materials bag is full.
##     await material_prompt.ask(trip)
## ask() has already changed the bag by the time it returns.

## Emitted by a button, with the material to leave behind, or "" to leave the new one.
signal _choice_made(dropped_id: String)

const WIDTH := 420.0

var _found: Label
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
	heading.text = "Your materials bag is full"
	heading.add_theme_color_override("font_color", GameArt.GOLD)
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)
	_found = Label.new()
	_found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_found)
	var message := Label.new()
	message.text = "Leave one behind to make room:"
	box.add_child(message)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_leave = Button.new()
	_leave.pressed.connect(func() -> void: _choice_made.emit(""))
	box.add_child(_leave)
	hide()


## Shows the choice for the material `trip` found.
func ask(trip: Expedition) -> void:
	var found := Database.get_material(trip.found_material)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_found.text = "Found: %s, worth %d gold to the Shop." % [found.display_name, TownData.material_price(found.id)]
	var counts := {}
	for id in trip.materials:
		counts[id] = counts.get(id, 0) + 1
	for id: String in Database.sorted_ids(counts):
		var material := Database.get_material(id)
		var row := Button.new()
		row.icon = GameArt.material_icon(material)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s (you have %d, worth %d each)" % [material.display_name, counts[id], TownData.material_price(id)]
		row.pressed.connect(func() -> void: _choice_made.emit(id))
		_rows.add_child(row)
	_leave.text = "Leave the %s" % found.display_name
	show()
	_leave.grab_focus()
	trip.keep_material(await _choice_made)
	hide()


## Every button a person could press right now. Tests use this.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = [_leave]
	for row in _rows.get_children():
		found.append(row)
	return found
