class_name CharacterSheet
extends CenterContainer
## A window showing one player's stats, equipment, bag and spells. With
## `can_act` on, bag items can be used or equipped and worn items taken off.
## Rules stay in PlayerData: this script only calls it and redraws.

const SLOT_NAMES := {
	ItemData.Kind.WEAPON: "Weapon",
	ItemData.Kind.ARMOR: "Armor",
	ItemData.Kind.ACCESSORY: "Accessory",
}

var _player: PlayerData
var _can_act := false
var _title: Label
var _stats: Label
var _worn: Container
var _bag: Container
var _spells: Label
var _close: Button


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = Label.new()
	_title.add_theme_color_override("font_color", GameArt.GOLD)
	_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)

	_stats = Label.new()
	_stats.custom_minimum_size = Vector2(190, 0)
	columns.add_child(_stats)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_worn = VBoxContainer.new()
	right.add_child(_worn)
	_bag = VBoxContainer.new()
	right.add_child(_bag)

	_spells = Label.new()
	_spells.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_spells)

	_close = Button.new()
	_close.text = "Close"
	_close.pressed.connect(close_sheet)
	box.add_child(_close)
	hide()


func open(player: PlayerData, can_act: bool) -> void:
	_player = player
	_can_act = can_act
	if not player.changed.is_connected(_redraw):
		player.changed.connect(_redraw)
	_redraw()
	show()
	# Takes focus from Roll Dice, so Space cannot roll behind the window.
	_close.grab_focus()


func close_sheet() -> void:
	if _player != null and _player.changed.is_connected(_redraw):
		_player.changed.disconnect(_redraw)
	hide()


func _redraw() -> void:
	var player := _player
	_title.text = "%s - %s, Level %d" % [player.player_name, player.get_class_name_text(), player.level]
	_stats.text = "HP %d / %d\nMP %d / %d\nAttack %d\nDefense %d\nMagic %d\nSpeed %d\nGold %d\nEXP %d / %d" % [
		player.hp, player.get_stat("max_hp"), player.mp, player.get_stat("max_mp"),
		player.get_stat("attack"), player.get_stat("defense"), player.get_stat("magic"),
		player.get_stat("speed"), player.gold, player.experience, player.exp_to_next_level(),
	]
	_clear(_worn)
	_clear(_bag)
	for slot: ItemData.Kind in PlayerData.EQUIPMENT_SLOTS:
		var item_id: String = player.equipment.get(slot, "")
		var text := "%s: %s" % [SLOT_NAMES[slot], _item_name(item_id)]
		_add_row(_worn, text, "Remove" if item_id != "" else "", player.unequip.bind(slot))

	_add_row(_bag, "Bag (%d / %d)" % [player.inventory.size(), PlayerData.INVENTORY_SIZE], "", Callable())
	for item_id in player.inventory:
		var consumable := Database.get_item(item_id).kind == ItemData.Kind.CONSUMABLE
		var action := player.use_item.bind(item_id) if consumable else player.equip.bind(item_id)
		_add_row(_bag, _item_name(item_id), "Use" if consumable else "Equip", action)

	var names := PackedStringArray()
	for spell_id in player.spells:
		names.append(Database.get_spell(spell_id).display_name)
	_spells.text = "Spells: %s" % (", ".join(names) if not names.is_empty() else "none")


func _add_row(parent: Container, text: String, action_text: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if _can_act and action_text != "":
		var button := Button.new()
		button.text = action_text
		button.pressed.connect(action)
		row.add_child(button)
	parent.add_child(row)


func _item_name(item_id: String) -> String:
	if item_id == "":
		return "-"
	return Database.get_item(item_id).display_name


# Freed right away: queue_free() would leave old rows in the layout this frame.
func _clear(parent: Container) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
