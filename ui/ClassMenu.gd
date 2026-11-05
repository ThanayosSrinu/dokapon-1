class_name ClassMenu
extends CenterContainer
## Asks one player at a time to pick a class. Built entirely from Database, so a
## new class file appears here by itself.

## Emitted when a class button is pressed.
signal class_chosen(class_id: String)

const SHADE := Color(0.03, 0.04, 0.12, 0.5)

var _title: Label
var _buttons: Container
var _details: Label


func _ready() -> void:
	# Keeps clicks from reaching the board behind the menu.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_title = Label.new()
	_title.add_theme_color_override("font_color", GameArt.GOLD)
	_title.add_theme_font_size_override("font_size", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)

	_details = Label.new()
	_details.custom_minimum_size = Vector2(520, 90)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)

	for id in Database.sorted_ids(Database.classes):
		var button := Button.new()
		button.text = Database.get_class_data(id).display_name
		button.pressed.connect(func() -> void: class_chosen.emit(id))
		button.focus_entered.connect(_show_details.bind(id))
		button.mouse_entered.connect(_show_details.bind(id))
		_buttons.add_child(button)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


## Shows the menu and waits for the answer, which is a class id.
func ask(player: PlayerData) -> String:
	_title.text = "%s, choose your class" % player.player_name
	show()
	_buttons.get_child(0).grab_focus()
	var id: String = await class_chosen
	hide()
	return id


func _show_details(id: String) -> void:
	var data := Database.get_class_data(id)
	var stats := PackedStringArray()
	for stat in Database.STATS:
		stats.append("%s %d" % [stat.replace("max_", "").to_upper(), data.base_stats[stat]])
	_details.text = "%s\n%s\nStarts with %d gold." % [data.description,
			"   ".join(stats), data.starting_gold]
