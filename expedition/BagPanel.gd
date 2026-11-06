class_name BagPanel
extends VBoxContainer
## The column at the right of a trip: what is worn, a grid of the bag's places, and a box
## that explains whatever is pointed at, an item or a space on the board. With nothing
## pointed at, it explains the space they stand on. The box holds an item's buttons, so
## it stays on that item while the mouse is in the column, and a pressed item stays
## there even if the mouse crosses other tiles on the way.

const WIDTH := 264.0
const GAP := 8
const PANEL_MARGIN := 14.0
## Tiles in a row of the bag.
const COLUMNS := 4
## Rows shown before the bag scrolls, so that any size of bag stays on screen.
const MOST_ROWS := 4
const DETAIL_HEIGHT := 252.0
const DETAIL_WIDTH := 228.0
const SLOTS := [ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY]
const SLOT_WORDS := {ItemData.Kind.WEAPON: "Weapon", ItemData.Kind.ARMOR: "Armor",
		ItemData.Kind.ACCESSORY: "Accessory"}
const FULL_HINT := "They don't need this yet."
const AUTO_ON_HINT := "Auto is on: they use this when hurt."
const AUTO_OFF_HINT := "Auto is off: only you can use this."
const FIGHT_HINT := "Not during a fight."

## One per entry of SLOTS.
var slots: Array[BagTile] = []
## One per place in the bag.
var tiles: Array[BagTile] = []
var bag_words: Label
var detail_title: Label
var detail_words: Label
var detail_hint: Label
## Uses or wears the item in the box.
var action: KitButton
## Lets the bot use the item in the box by itself.
var auto: KitButton
## True while nothing can be changed, such as in a fight.
var locked := false:
	set(value):
		if value != locked:
			locked = value
			refresh()

var _trip: Expedition
# The bag's grid, and what scrolls it.
var _grid: GridContainer
var _bag_view: ScrollContainer
# The item being pointed at, or "".
var _pointed := ""
# The item pressed, or "", and which place in the bag it is.
var _picked := ""
var _picked_at := -1
var _mouse_inside := false
# The space to explain when no item is pointed at.
var _space := -1


func _init(trip: Expedition) -> void:
	_trip = trip
	add_theme_constant_override("separation", GAP)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gear := KitPanel.new()
	gear.body.add_theme_constant_override("separation", 4)
	add_child(gear)
	_tighten(gear)
	_build_slots(gear.body)
	bag_words = Kit.text("")
	bag_words.modulate = Kit.GOLD
	gear.body.add_child(bag_words)
	_bag_view = ScrollContainer.new()
	_bag_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_view.follow_focus = true
	gear.body.add_child(_bag_view)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_bag_view.add_child(_grid)
	_build_detail()


func _ready() -> void:
	refresh()
	_trip.player.changed.connect(refresh)


func _process(_delta: float) -> void:
	var inside := get_global_rect().has_point(get_global_mouse_position())
	var left := _mouse_inside and not inside
	_mouse_inside = inside
	if inside or _shown() == "":
		return
	var focus := get_viewport().gui_get_focus_owner()
	var focused := focus != null and is_ancestor_of(focus)
	if left and focused:
		focus.release_focus()
		focused = false
	if not focused:
		_let_go()


## Shows the bag as it stands.
func refresh() -> void:
	var player := _trip.player
	for index in SLOTS.size():
		var worn: String = player.equipment.get(SLOTS[index], "")
		slots[index].icon = null if worn == "" else GameArt.item_icon(Database.get_item(worn))
	bag_words.text = "Bag %d/%d" % [player.inventory.size(), player.bag_size]
	_fit_tiles()
	for index in tiles.size():
		var item_id: String = player.inventory[index] if index < player.inventory.size() else ""
		var tile := tiles[index]
		tile.icon = null if item_id == "" else GameArt.item_icon(Database.get_item(item_id))
		tile.disabled = item_id == ""
		tile.focus_mode = Control.FOCUS_NONE if item_id == "" else Control.FOCUS_ALL
	_keep_shown_real()
	_show_detail()


## Explains space `id` while no item is pointed at.
func point_at_space(id: int) -> void:
	if id != _space:
		_space = id
		_show_detail()


func _build_slots(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	for kind: ItemData.Kind in SLOTS:
		var slot := BagTile.new()
		slot.mouse_entered.connect(_on_slot_pointed.bind(kind))
		slot.focus_entered.connect(_on_slot_pointed.bind(kind))
		slot.mouse_exited.connect(_on_pointed.bind(""))
		slot.focus_exited.connect(_on_pointed.bind(""))
		row.add_child(slot)
		slots.append(slot)


# Makes one tile for each place in the bag, whatever size it is.
func _fit_tiles() -> void:
	var places := _trip.player.bag_size
	if places == tiles.size():
		return
	while tiles.size() > places:
		var extra: BagTile = tiles.pop_back()
		_grid.remove_child(extra)
		extra.queue_free()
	while tiles.size() < places:
		var tile := BagTile.new()
		var index := tiles.size()
		tile.pressed.connect(_on_tile_pressed.bind(index))
		tile.mouse_entered.connect(_on_tile_pointed.bind(index))
		tile.focus_entered.connect(_on_tile_pointed.bind(index))
		tile.mouse_exited.connect(_on_pointed.bind(""))
		tile.focus_exited.connect(_on_pointed.bind(""))
		_grid.add_child(tile)
		tiles.append(tile)
	var rows := mini(ceili(float(places) / COLUMNS), MOST_ROWS)
	_bag_view.custom_minimum_size.y = rows * BagTile.SIZE + (rows - 1) * GAP


func _build_detail() -> void:
	var detail := KitPanel.new("", true)
	detail.custom_minimum_size.y = DETAIL_HEIGHT
	detail.body.add_theme_constant_override("separation", 6)
	add_child(detail)
	_tighten(detail)
	detail_title = Kit.text("", 0.0, &"PaperTitle")
	detail.body.add_child(detail_title)
	detail_words = Kit.text("", DETAIL_WIDTH, &"PaperLabel")
	detail.body.add_child(detail_words)
	detail_hint = Kit.text("", DETAIL_WIDTH, &"PaperLabel")
	detail_hint.add_theme_color_override("font_color", Kit.BLOOD)
	detail.body.add_child(detail_hint)
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.body.add_child(room)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", GAP)
	detail.body.add_child(buttons)
	action = _detail_button(_on_action)
	buttons.add_child(action)
	auto = _detail_button(_on_auto)
	auto.text = "Auto"
	buttons.add_child(auto)


func _detail_button(press: Callable) -> KitButton:
	var button := KitButton.new()
	button.kind = KitButton.Kind.SMALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.visible = false
	button.pressed.connect(press)
	return button


# The kit's margin is for big windows, and this column has none to spare.
func _tighten(panel: PanelContainer) -> void:
	var style: StyleBox = panel.get_theme_stylebox("panel", panel.theme_type_variation).duplicate()
	style.set_content_margin_all(PANEL_MARGIN)
	panel.add_theme_stylebox_override("panel", style)


# The item in the box, or "" if the box is on a space.
func _shown() -> String:
	return _pointed if _pointed != "" else _picked


func _let_go() -> void:
	_pointed = ""
	_pick_tile(-1)
	_show_detail()


func _pick_tile(index: int) -> void:
	if _picked_at >= 0 and _picked_at < tiles.size():
		tiles[_picked_at].lit = false
	_picked_at = index
	_picked = "" if index < 0 else _trip.player.inventory[index]
	if index >= 0:
		tiles[index].lit = true


# The bot may have used the item in the box, or moved it along the bag.
func _keep_shown_real() -> void:
	var player := _trip.player
	if _pointed != "" and not player.inventory.has(_pointed) and not player.equipment.values().has(_pointed):
		_pointed = ""
	if _picked != "":
		var at_place := _picked_at < player.inventory.size() and player.inventory[_picked_at] == _picked
		_pick_tile(_picked_at if at_place else player.inventory.find(_picked))


func _on_tile_pressed(index: int) -> void:
	if locked or index >= _trip.player.inventory.size():
		return
	_pick_tile(index)
	_pointed = ""
	_show_detail()
	if action.visible and not action.disabled:
		action.grab_focus()


func _on_tile_pointed(index: int) -> void:
	if index < _trip.player.inventory.size():
		_on_pointed(_trip.player.inventory[index])


func _on_action() -> void:
	var item_id := _shown()
	if locked or item_id == "":
		return
	var at := _picked_at if _picked != "" else _trip.player.inventory.find(item_id)
	if Database.get_item(item_id).kind == ItemData.Kind.CONSUMABLE:
		if _trip.use_by_hand(item_id):
			Sound.play("heal")
	elif _trip.wear_by_hand(item_id):
		Sound.play("item")
	_let_go()
	refresh()
	if at >= 0 and at < tiles.size() and not tiles[at].disabled:
		tiles[at].grab_focus()
	else:
		slots[0].grab_focus()


func _on_auto() -> void:
	var item_id := _shown()
	if item_id == "":
		return
	var off := _trip.player.auto_off
	if off.has(item_id):
		off.erase(item_id)
	else:
		off.append(item_id)
	_show_detail()


# Pointing away from an item leaves it in the box, so its buttons can be reached.
func _on_pointed(item_id: String) -> void:
	if item_id != "" or _picked != "":
		_pointed = item_id
	_show_detail()


func _on_slot_pointed(kind: ItemData.Kind) -> void:
	_pointed = _trip.player.equipment.get(kind, "")
	if _pointed == "":
		_show_words(SLOT_WORDS[kind], "Nothing worn here.", "")
	else:
		_show_detail()


func _show_detail() -> void:
	if _shown() != "":
		_show_item(Database.get_item(_shown()))
	elif _space >= 0:
		var space := SpaceNotes.of(_trip, _space)
		_show_words(space["title"], space["text"], "")
	else:
		_show_words("", "", "")


func _show_item(item: ItemData) -> void:
	var player := _trip.player
	var lines := PackedStringArray([item.effect_text(), item.description])
	if not player.inventory.has(item.id) or _worn(item):
		_show_words(item.display_name, "\n".join(lines), "")
		return
	if item.kind != ItemData.Kind.CONSUMABLE:
		lines.append_array(_changes(item))
		_show_words(item.display_name, "\n".join(lines), FIGHT_HINT if locked else "")
		action.text = "Wear"
		action.disabled = false
		action.visible = not locked
		return
	var auto_on := not player.auto_off.has(item.id)
	var can_use := player.can_use_item(item.id)
	var hint: String = AUTO_ON_HINT if auto_on else AUTO_OFF_HINT
	if locked:
		hint = FIGHT_HINT
	elif not can_use:
		hint = "%s %s" % [FULL_HINT, hint]
	_show_words(item.display_name, "\n".join(lines), hint)
	action.text = "Use"
	action.disabled = not can_use
	action.visible = not locked
	auto.lit = auto_on
	auto.visible = true


func _worn(item: ItemData) -> bool:
	return _trip.player.equipment.get(item.kind, "") == item.id


# What wearing `item` would change, a line for each stat.
func _changes(item: ItemData) -> PackedStringArray:
	var player := _trip.player
	var lines := PackedStringArray()
	for stat: String in ItemData.STAT_NAMES:
		var now: int = player.get_stat(stat)
		var then: int = player.get_stat_with(item.id, stat)
		if then != now:
			lines.append("%s %d to %d" % [ItemData.STAT_NAMES[stat], now, then])
	return lines


func _show_words(title: String, words: String, hint: String) -> void:
	detail_title.text = title
	detail_words.text = words
	detail_hint.text = hint
	detail_hint.visible = hint != ""
	action.visible = false
	auto.visible = false
