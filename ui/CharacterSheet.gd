class_name CharacterSheet
extends CenterContainer
## Two windows for one player: Status (stats and spells) and Inventory
## (equipment and bag). With `can_act` on, bag items can be used or equipped and worn items taken off.
## Hovering over an item shows what it does.
## Rules stay in PlayerData: this script only calls it and redraws.

const ICON_SIZE := Vector2(32, 32)
const DETAIL_HINT := "Hover over an item to see what it does."
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
var _detail: Label
var _close: Button


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var windows := HBoxContainer.new()
	windows.add_theme_constant_override("separation", 12)
	layout.add_child(windows)

	var status := _add_window(windows, 300)
	_title = _add_heading(status)
	_stats = Label.new()
	status.add_child(_stats)
	_spells = Label.new()
	_spells.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_spells)

	var inventory := _add_window(windows, 380)
	_add_heading(inventory).text = "Inventory"
	_worn = VBoxContainer.new()
	inventory.add_child(_worn)
	_bag = VBoxContainer.new()
	inventory.add_child(_bag)
	_detail = Label.new()
	_detail.custom_minimum_size = Vector2(380, 56)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", GameArt.GOLD)
	_detail.add_theme_font_size_override("font_size", 14)
	inventory.add_child(_detail)

	_close = Button.new()
	_close.text = "Close"
	_close.pressed.connect(close_sheet)
	layout.add_child(_close)
	hide()


## Adds a framed window of its own and returns the box for its contents.
func _add_window(parent: Container, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _add_heading(parent: Container) -> Label:
	var heading := Label.new()
	heading.add_theme_color_override("font_color", GameArt.GOLD)
	heading.add_theme_font_size_override("font_size", 22)
	parent.add_child(heading)
	return heading


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
	_detail.text = DETAIL_HINT
	_clear(_worn)
	_clear(_bag)
	for slot: ItemData.Kind in PlayerData.EQUIPMENT_SLOTS:
		var item_id: String = player.equipment.get(slot, "")
		var text := "%s: %s" % [SLOT_NAMES[slot], _item_name(item_id)]
		_add_row(_worn, text, "Remove" if item_id != "" else "", player.unequip.bind(slot), item_id)

	_add_row(_bag, "Bag (%d / %d)" % [player.inventory.size(), PlayerData.INVENTORY_SIZE], "", Callable())
	for item_id in player.inventory:
		var consumable := Database.get_item(item_id).kind == ItemData.Kind.CONSUMABLE
		var action := player.use_item.bind(item_id) if consumable else player.equip.bind(item_id)
		var usable := not consumable or player.can_use_item(item_id)
		_add_row(_bag, _item_name(item_id), "Use" if consumable else "Equip", action, item_id, usable)

	var names := PackedStringArray()
	for spell_id in player.spells:
		names.append(Database.get_spell(spell_id).display_name)
	_spells.text = "Spells: %s" % (", ".join(names) if not names.is_empty() else "none")


func _add_row(parent: Container, text: String, action_text: String, action: Callable,
		item_id := "", enabled := true) -> void:
	var row := HBoxContainer.new()
	if item_id != "":
		var icon := TextureRect.new()
		icon.texture = GameArt.item_icon(Database.get_item(item_id))
		icon.custom_minimum_size = ICON_SIZE
		row.add_child(icon)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_entered.connect(_show_detail.bind(item_id))
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if _can_act and action_text != "":
		var button := Button.new()
		button.text = action_text
		button.disabled = not enabled
		button.pressed.connect(action)
		row.add_child(button)
	parent.add_child(row)


func _show_detail(item_id: String) -> void:
	var item := Database.get_item(item_id)
	_detail.text = "%s\n%s" % [item.effect_text(), item.description]


func _item_name(item_id: String) -> String:
	if item_id == "":
		return "-"
	return Database.get_item(item_id).display_name


# Freed right away: queue_free() would leave old rows in the layout this frame.
func _clear(parent: Container) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
