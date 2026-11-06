class_name BagPanel
extends VBoxContainer
## The column at the right of a trip: what is worn, what is in the bag, and a box that
## explains whatever is pointed at, an item or a space on the board. With nothing pointed
## at, it explains the space they stand on.

const WIDTH := 264.0
const GAP := 8
const PANEL_MARGIN := 14.0
const SLOT_SIZE := 48.0
const DETAIL_HEIGHT := 252.0
const DETAIL_WIDTH := 228.0
const SLOTS := [ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY]
const SLOT_WORDS := {ItemData.Kind.WEAPON: "Weapon", ItemData.Kind.ARMOR: "Armor",
		ItemData.Kind.ACCESSORY: "Accessory"}
const USE_HINT := "Press to use."
const FULL_HINT := "They don't need this yet."
const WEAR_HINT := "Press to wear it."
const AUTO_ON_HINT := "Auto is on: they use this when hurt."
const AUTO_OFF_HINT := "Auto is off: only you can use this."
const FIGHT_HINT := "Not during a fight."

## One per entry of SLOTS.
var slots: Array[Button] = []
## One per place in the bag.
var rows: Array[BagRow] = []
var bag_words: Label
var detail_title: Label
var detail_words: Label
var detail_hint: Label
## True while nothing can be changed, such as in a fight.
var locked := false:
	set(value):
		if value != locked:
			locked = value
			refresh()

var _trip: Expedition
# The item being pointed at, or "".
var _pointed := ""
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
	var places := VBoxContainer.new()
	places.add_theme_constant_override("separation", 0)
	gear.body.add_child(places)
	for index in PlayerData.INVENTORY_SIZE:
		var row := BagRow.new()
		row.chosen.connect(_on_chosen)
		row.auto_changed.connect(_on_auto)
		row.pointed.connect(_on_pointed)
		places.add_child(row)
		rows.append(row)
	_build_detail()


func _ready() -> void:
	refresh()
	_trip.player.changed.connect(refresh)


## Shows the bag as it stands.
func refresh() -> void:
	var player := _trip.player
	for index in SLOTS.size():
		var worn: String = player.equipment.get(SLOTS[index], "")
		slots[index].icon = null if worn == "" else GameArt.item_icon(Database.get_item(worn))
	bag_words.text = "Bag %d/%d" % [player.inventory.size(), PlayerData.INVENTORY_SIZE]
	for index in rows.size():
		var has_item := index < player.inventory.size()
		rows[index].show_item(player.inventory[index] if has_item else "", player, locked)
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
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			slot.add_theme_stylebox_override(state, Kit.box("chip", 8.0))
		slot.mouse_entered.connect(_on_slot_pointed.bind(kind))
		slot.focus_entered.connect(_on_slot_pointed.bind(kind))
		slot.mouse_exited.connect(_on_pointed.bind(""))
		slot.focus_exited.connect(_on_pointed.bind(""))
		row.add_child(slot)
		slots.append(slot)


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


# The kit's margin is for big windows, and this column has none to spare.
func _tighten(panel: PanelContainer) -> void:
	var style: StyleBox = panel.get_theme_stylebox("panel", panel.theme_type_variation).duplicate()
	style.set_content_margin_all(PANEL_MARGIN)
	panel.add_theme_stylebox_override("panel", style)


func _on_chosen(item_id: String) -> void:
	if locked or item_id == "":
		return
	var item := Database.get_item(item_id)
	if item.kind == ItemData.Kind.CONSUMABLE:
		if _trip.use_by_hand(item_id):
			Sound.play("heal")
	elif _trip.wear_by_hand(item_id):
		Sound.play("item")
	_pointed = ""
	refresh()


func _on_auto(item_id: String, on: bool) -> void:
	var off := _trip.player.auto_off
	if on:
		off.erase(item_id)
	elif not off.has(item_id):
		off.append(item_id)
	_show_detail()


func _on_pointed(item_id: String) -> void:
	_pointed = item_id
	_show_detail()


func _on_slot_pointed(kind: ItemData.Kind) -> void:
	_on_pointed(_trip.player.equipment.get(kind, ""))
	if _pointed == "":
		_show_words(SLOT_WORDS[kind], "Nothing worn here.", "")


func _show_detail() -> void:
	if _pointed != "":
		_show_item(Database.get_item(_pointed))
	elif _space >= 0:
		var space := SpaceNotes.of(_trip, _space)
		_show_words(space["title"], space["text"], "")


func _show_item(item: ItemData) -> void:
	var player := _trip.player
	var lines := PackedStringArray([item.effect_text(), item.description])
	if _worn(item):
		_show_words(item.display_name, "\n".join(lines), "")
		return
	if item.kind != ItemData.Kind.CONSUMABLE:
		lines.append_array(_changes(item))
		_show_words(item.display_name, "\n".join(lines), FIGHT_HINT if locked else WEAR_HINT)
		return
	var hint := AUTO_OFF_HINT if player.auto_off.has(item.id) else AUTO_ON_HINT
	if locked:
		hint = FIGHT_HINT
	else:
		hint = "%s %s" % [USE_HINT if player.can_use_item(item.id) else FULL_HINT, hint]
	_show_words(item.display_name, "\n".join(lines), hint)


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
