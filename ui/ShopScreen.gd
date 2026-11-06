class_name ShopScreen
extends Control
## A shop's counter. It only asks and redraws: the rules are in Shop.gd.
##     var line: String = await shop_screen.run(player, shelves, "Shop")
## run() returns when the player leaves, with a sentence saying what they did.

## Emitted by the Leave button.
signal _left

## The size of the counter art, twice the size of the image.
const COUNTER_SIZE := Vector2(752, 128)
const KEEPER_POSITION := Vector2(96, 22)
const KEEPER_SIZE := Vector2(64, 64)
const KEEPER_SHEET: Texture2D = preload("res://assets/puny/characters/Human-Worker-Cyan.png")
const FRAME_TIME := 0.45
const SHADE := Color(0.03, 0.04, 0.12, 0.86)
const LIST_WIDTH := 372.0
const DETAIL_WIDTH := 300.0
## Keeps the window the same height whichever tab is open.
const LIST_HEIGHT := 8 * ItemRow.ROW_HEIGHT
const BETTER_COLOR := Color(0.5, 0.95, 0.55)
const WORSE_COLOR := Color(1.0, 0.55, 0.5)
const KIND_NAMES := {
	ItemData.Kind.CONSUMABLE: "Consumable",
	ItemData.Kind.WEAPON: "Weapon",
	ItemData.Kind.ARMOR: "Armor",
	ItemData.Kind.ACCESSORY: "Accessory",
}

var _player: PlayerData
var _shelves: Array[String] = []
var _selling := false
var _selected := ""
var _bought := 0
var _sold := 0

var _title: Label
var _speech: Label
var _purse: Label
var _keeper: AtlasTexture
var _clock := 0.0
var _buy_tab: Button
var _sell_tab: Button
var _rows: VBoxContainer
var _group: ButtonGroup
var _item_icon: TextureRect
var _item_name: Label
var _item_kind: Label
var _item_text: Label
var _item_effect: Label
var _item_changes: VBoxContainer
var _main_button: Button
var _wear_button: Button
var _reason: Label
var _leave: Button


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	center.add_child(layout)
	_build_counter(layout)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	layout.add_child(body)
	_build_list(body)
	_build_details(body)

	_leave = Button.new()
	_leave.text = "Leave"
	_leave.pressed.connect(func() -> void: _left.emit())
	layout.add_child(_leave)
	set_process(false)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		Sound.play("back")
		get_viewport().set_input_as_handled()
		_left.emit()


func _process(delta: float) -> void:
	_clock += delta
	_keeper.region.position.x = (int(_clock / FRAME_TIME) % 2) * GameArt.CHARACTER_FRAME


## Opens the shop for `player` and waits until they leave.
func run(player: PlayerData, shelves: Array[String], shop_name: String) -> String:
	_player = player
	_shelves = shelves
	_bought = 0
	_sold = 0
	_title.text = shop_name
	_speech.text = "Welcome, %s! See anything you like?" % player.player_name
	_show_tab(false)
	show()
	set_process(true)
	await _left
	set_process(false)
	hide()
	return _summary()


## Every button a person could press right now. Tests use this.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = [_buy_tab, _sell_tab, _main_button, _wear_button, _leave]
	for row in _rows.get_children():
		if row is Button:
			found.append(row)
	return found.filter(func(button: Button) -> bool: return button.visible and not button.disabled)


# --- Building the window ----------------------------------------------------

func _build_counter(parent: Container) -> void:
	var counter := Control.new()
	counter.custom_minimum_size = COUNTER_SIZE
	counter.clip_contents = true
	parent.add_child(counter)
	var backdrop := TextureRect.new()
	backdrop.texture = GameArt.SHOP_BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = COUNTER_SIZE
	counter.add_child(backdrop)

	_keeper = GameArt.character_frame(KEEPER_SHEET, 0, 0)
	var keeper := TextureRect.new()
	keeper.texture = _keeper
	keeper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	keeper.position = KEEPER_POSITION
	keeper.size = KEEPER_SIZE
	counter.add_child(keeper)
	# The front of the counter hides the shopkeeper's legs.
	var counter_top := TextureRect.new()
	counter_top.texture = GameArt.SHOP_COUNTER
	counter_top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	counter_top.size = COUNTER_SIZE
	counter.add_child(counter_top)

	var bubble := PanelContainer.new()
	bubble.position = Vector2(196, 10)
	bubble.custom_minimum_size = Vector2(350, 0)
	counter.add_child(bubble)
	var talk := VBoxContainer.new()
	bubble.add_child(talk)
	_title = _add_heading(talk)
	_speech = Label.new()
	_speech.custom_minimum_size = Vector2(316, 40)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk.add_child(_speech)

	var purse_panel := PanelContainer.new()
	purse_panel.position = Vector2(564, 10)
	purse_panel.custom_minimum_size = Vector2(174, 0)
	counter.add_child(purse_panel)
	_purse = Label.new()
	purse_panel.add_child(_purse)


func _build_list(parent: Container) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	_buy_tab = _add_tab(tabs, "Buy", false)
	_sell_tab = _add_tab(tabs, "Sell", true)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_rows.add_theme_constant_override("separation", 0)
	box.add_child(_rows)
	_group = ButtonGroup.new()


func _add_tab(parent: Container, text: String, selling: bool) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.pressed.connect(_show_tab.bind(selling))
	parent.add_child(tab)
	return tab


func _build_details(parent: Container) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(32, 32)
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(_item_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	_item_name = _add_heading(names)
	_item_kind = Label.new()
	_item_kind.add_theme_font_size_override("font_size", 14)
	names.add_child(_item_kind)

	_item_text = Label.new()
	_item_text.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	_item_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_item_text)
	_item_effect = Label.new()
	_item_effect.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	_item_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_effect.add_theme_color_override("font_color", GameArt.GOLD)
	box.add_child(_item_effect)
	_item_changes = VBoxContainer.new()
	_item_changes.add_theme_constant_override("separation", 0)
	box.add_child(_item_changes)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	_reason = Label.new()
	_reason.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.add_theme_color_override("font_color", WORSE_COLOR)
	_reason.add_theme_font_size_override("font_size", 14)
	box.add_child(_reason)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_main_button = Button.new()
	_main_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_button.pressed.connect(_on_main_pressed)
	actions.add_child(_main_button)
	_wear_button = Button.new()
	_wear_button.text = "Buy & Wear"
	_wear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wear_button.pressed.connect(_on_wear_pressed)
	actions.add_child(_wear_button)


func _add_heading(parent: Container) -> Label:
	var heading := Label.new()
	heading.add_theme_color_override("font_color", GameArt.GOLD)
	heading.add_theme_font_size_override("font_size", 22)
	parent.add_child(heading)
	return heading


# --- Showing what is on offer -----------------------------------------------

func _show_tab(selling: bool) -> void:
	_selling = selling
	_buy_tab.disabled = not selling
	_sell_tab.disabled = selling
	_selected = ""
	_redraw()


## Rebuilds the list, keeping the selection if that item is still in it.
func _redraw() -> void:
	_purse.text = "Gold %d\nBag %d / %d" % [_player.gold, _player.inventory.size(), _player.bag_size]
	# Freed right away: queue_free() would leave old rows in the layout this frame.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var ids: Array[String] = _player.inventory if _selling else _shelves
	for id in ids:
		_add_row(id)
	if ids.is_empty():
		var nothing := Label.new()
		nothing.text = "Your bag is empty."
		_rows.add_child(nothing)
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	_select_row()
	_show_item()


func _add_row(id: String) -> void:
	var row := ItemRow.new()
	row.toggle_mode = true
	row.button_group = _group
	row.setup(id, "%d G" % (Shop.sell_price(id) if _selling else Database.get_item(id).price))
	if not _selling and _player.gold < Database.get_item(id).price:
		row.modulate = Color(1, 1, 1, 0.55)
	row.pressed.connect(_on_row_pressed.bind(id, row))
	row.focus_entered.connect(_on_row_pressed.bind(id, row))
	_rows.add_child(row)


func _select_row() -> void:
	for row in _rows.get_children():
		if row is ItemRow and row.item_id == _selected:
			row.set_pressed_no_signal(true)
			row.grab_focus.call_deferred()
			return
	_leave.grab_focus.call_deferred()


## Selects `id`. The bag can hold two of an item, so `chosen` says which row it was.
func _on_row_pressed(id: String, chosen: ItemRow = null) -> void:
	_selected = id
	var marked := false
	for row in _rows.get_children():
		if row is ItemRow:
			var is_chosen: bool = row == chosen or (chosen == null and row.item_id == id and not marked)
			row.set_pressed_no_signal(is_chosen)
			marked = marked or is_chosen
	_show_item()


func _show_item() -> void:
	for child in _item_changes.get_children():
		_item_changes.remove_child(child)
		child.queue_free()
	var has_item := _selected != ""
	_item_icon.texture = GameArt.item_icon(Database.get_item(_selected)) if has_item else null
	_main_button.visible = has_item
	_wear_button.visible = false
	if not has_item:
		_item_name.text = ""
		_item_kind.text = ""
		_item_text.text = ""
		_item_effect.text = ""
		_reason.text = ""
		return

	var item := Database.get_item(_selected)
	_item_name.text = item.display_name
	_item_kind.text = KIND_NAMES[item.kind]
	_item_text.text = item.description
	_item_effect.text = item.effect_text()
	_show_changes(item)
	if _selling:
		_main_button.text = "Sell for %d" % Shop.sell_price(_selected)
		_main_button.disabled = false
		_reason.text = ""
		return
	var problem := Shop.why_not_buy(_player, _selected)
	_reason.text = problem
	_main_button.text = "Buy"
	_main_button.disabled = problem != ""
	_wear_button.visible = item.kind != ItemData.Kind.CONSUMABLE
	_wear_button.disabled = problem != ""


## Lists what wearing the item would do to the player's stats.
func _show_changes(item: ItemData) -> void:
	if item.kind == ItemData.Kind.CONSUMABLE:
		return
	var worn: String = _player.equipment.get(item.kind, "")
	if worn == item.id:
		_add_change("You are wearing one.", Color.WHITE)
		return
	if worn != "":
		_add_change("Replaces %s" % Database.get_item(worn).display_name, Color.WHITE)
	for stat in Database.STATS:
		var now := _player.get_stat(stat)
		var then := _player.get_stat_with(item.id, stat)
		if then != now:
			_add_change("%s %d -> %d" % [ItemData.STAT_NAMES[stat], now, then],
					BETTER_COLOR if then > now else WORSE_COLOR)


func _add_change(text: String, color: Color) -> void:
	var line := Label.new()
	line.text = text
	line.add_theme_color_override("font_color", color)
	_item_changes.add_child(line)


# --- Buying and selling -----------------------------------------------------

func _on_main_pressed() -> void:
	var item := Database.get_item(_selected)
	if _selling:
		if Shop.sell(_player, _selected):
			Sound.play("coin")
			_sold += 1
			_speech.text = "%d gold for the %s. A fair price!" % [Shop.sell_price(item.id), item.display_name]
	elif Shop.buy(_player, _selected):
		Sound.play("coin")
		_bought += 1
		_speech.text = "One %s. Thank you!" % item.display_name
	_redraw()


func _on_wear_pressed() -> void:
	var item := Database.get_item(_selected)
	if Shop.buy(_player, _selected):
		Sound.play("coin")
		_player.equip(_selected)
		_bought += 1
		_speech.text = "That %s suits you!" % item.display_name
	_redraw()


func _summary() -> String:
	var name := _player.player_name
	if _bought > 0 and _sold > 0:
		return "%s bought %d and sold %d." % [name, _bought, _sold]
	if _bought > 0:
		return "%s bought %d." % [name, _bought]
	if _sold > 0:
		return "%s sold %d." % [name, _sold]
	return "%s only looked around." % name
