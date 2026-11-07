class_name TownShop
extends Control
## The town's Shop. The shelves on the left hold what is for sale, or, on the Sell tab, what
## the town owns. The card on the right is who you shop for, with their gear and pack, and
## the item picked, with its moves and one button. The rules are in TownData: this only
## asks and redraws.

const TOWN := "res://town/TownScreen.tscn"
const STAGE := Vector2(1280, 720)
const SHELF_SPOT := Vector2(40, 292)
const COLUMNS := 8
const SHELF_ROWS := 3
const GAP := 8
const CARD_LEFT := 816.0
const CARD_TOP := 92.0
const CARD_WIDTH := 440.0
const TEXT_WIDTH := 400.0
## Speech bubbles stay inside the room's part of the stage.
const ROOM_AREA := Rect2(0, 0, 808, 720)
const BAR_MARGIN := 24.0
const BAR_GAP := 8
const SLOTS := [ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY]
const SLOT_WORDS := {ItemData.Kind.WEAPON: "Weapon", ItemData.Kind.ARMOR: "Armor",
		ItemData.Kind.ACCESSORY: "Accessory"}
const KIND_WORDS := {
	ItemData.Kind.CONSUMABLE: "To use on a trip", ItemData.Kind.WEAPON: "Weapon",
	ItemData.Kind.ARMOR: "Armor", ItemData.Kind.ACCESSORY: "Accessory", ItemData.Kind.TOME: "Tome",
}
const SAY_HELLO := "Welcome, my lord. What does %s need?"
const SAY_NOBODY := "Welcome, my lord. I buy as well as sell."
const SAY_BOUGHT := "A fine choice. %s wears it already."
const SAY_PACKED := "It's in %s's pack."
const SAY_SOLD := "I'll take it. %d gold for you."
const SAY_EMPTY := "Nothing to sell yet. Trips bring things home."
const EMPTY_STOCK := "The town owns nothing to sell. What a trip carries home comes here."
const PICK_SOMETHING := "Pick something on the shelves."

enum Tab { BUY, SELL }

var back: KitBackButton
var buy_tab: KitButton
var sell_tab: KitButton
## The main button of the card: Buy, Sell or Take out.
var action: KitButton
## Gives a stock item to the person shopped for.
var give: KitButton
var prev_person: KitButton
var next_person: KitButton
var gold_chip: KitChip
var date_chip: DateChip
var arrow: KitArrow
var bubble: TavernBubble
## The tiles on the shelves now.
var tiles: Array[ShopTile] = []
## The tiles of what the person shopped for wears.
var slots: Array[BagTile] = []
## The tiles of their pack.
var pack_tiles: Array[BagTile] = []
var tab := Tab.BUY
## Who is shopped for, as a place on the roster.
var person_index := 0
## What the card shows: {"from": "shelf", "id", "material"}, {"from": "pack", "index"},
## {"from": "slot", "kind"}, or {} for nothing.
var picked := {}

var _stage: Node2D
var _grid: GridContainer
var _empty: Label
var _who: Label
var _title: Label
var _kind: Label
var _words: Label
var _moves: VBoxContainer
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	_stage.add_child(ShopRoom.new())
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(_build_shelves())
	layer.add_child(_build_card())
	bubble = TavernBubble.new()
	_stage.add_child(bubble)
	_build_top_bar(town)
	arrow = KitArrow.new(null, KitArrow.Side.ABOVE)
	add_child(arrow)
	_refresh(false)
	if not tiles.is_empty():
		tiles[0].grab_focus()
	else:
		back.grab_focus()
	_say(SAY_HELLO % shopper().person.display_name if shopper() != null else SAY_NOBODY)
	Sound.music("shop")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_stage.position = _stage_corner()


func _stage_corner() -> Vector2:
	return Kit.snap_point(((get_viewport_rect().size - STAGE) / 2.0).max(Vector2.ZERO))


## Who is shopped for, or null with nobody on the roster.
func shopper() -> Member:
	var roster := TownData.current().roster
	return null if roster.is_empty() else roster[clampi(person_index, 0, roster.size() - 1)]


## Shows the shelves of `new_tab`.
func show_tab(new_tab: Tab) -> void:
	tab = new_tab
	picked = {}
	_refresh()


## Puts the shelf tile holding `id` in the card, as a click would.
func pick_on_shelf(id: String, material := false) -> void:
	picked = {"from": "shelf", "id": id, "material": material}
	_refresh()


# --- Building the screen -----------------------------------------------------

func _build_shelves() -> Control:
	var panel := KitPanel.new("", true)
	panel.position = SHELF_SPOT
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP)
	panel.body.add_child(tabs)
	buy_tab = _small_button("Buy", show_tab.bind(Tab.BUY))
	tabs.add_child(buy_tab)
	sell_tab = _small_button("Sell", show_tab.bind(Tab.SELL))
	tabs.add_child(sell_tab)
	var view := ScrollContainer.new()
	view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	view.follow_focus = true
	view.custom_minimum_size = Vector2(COLUMNS * BagTile.SIZE + (COLUMNS - 1) * GAP + 12.0,
			SHELF_ROWS * BagTile.SIZE + (SHELF_ROWS - 1) * GAP)
	panel.body.add_child(view)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	view.add_child(_grid)
	_empty = Kit.text(EMPTY_STOCK, COLUMNS * BagTile.SIZE, &"PaperLabel")
	_empty.hide()
	view.add_child(_empty)
	return panel


func _build_card() -> Control:
	var card := KitPanel.new("", true)
	card.custom_minimum_size.x = CARD_WIDTH
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	card.body.add_theme_constant_override("separation", 10)
	var people := HBoxContainer.new()
	people.add_theme_constant_override("separation", GAP)
	card.body.add_child(people)
	prev_person = _small_button("<", _turn_person.bind(-1))
	people.add_child(prev_person)
	_who = Kit.text("", 0.0, &"PaperTitle")
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people.add_child(_who)
	next_person = _small_button(">", _turn_person.bind(1))
	people.add_child(next_person)
	var kit := HBoxContainer.new()
	kit.add_theme_constant_override("separation", GAP)
	card.body.add_child(kit)
	for kind: ItemData.Kind in SLOTS:
		var slot := BagTile.new()
		slot.pressed.connect(_pick.bind({"from": "slot", "kind": kind}))
		kit.add_child(slot)
		slots.append(slot)
	var worn_words := Kit.text("Worn", 0.0, &"PaperLabel")
	worn_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kit.add_child(worn_words)
	var pack := HBoxContainer.new()
	pack.add_theme_constant_override("separation", GAP)
	card.body.add_child(pack)
	var pack_words := Kit.text("Pack", 0.0, &"PaperLabel")
	pack_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pack.add_child(pack_words)
	for index in PlayerData.INVENTORY_SIZE:
		var tile := BagTile.new()
		tile.pressed.connect(_pick.bind({"from": "pack", "index": index}))
		pack.add_child(tile)
		pack_tiles.append(tile)
	card.body.add_child(HSeparator.new())
	_title = Kit.text("", 0.0, &"PaperHeading")
	card.body.add_child(_title)
	_kind = Kit.text("", TEXT_WIDTH, &"PaperTitle")
	card.body.add_child(_kind)
	_words = Kit.text("", TEXT_WIDTH, &"PaperLabel")
	card.body.add_child(_words)
	_moves = VBoxContainer.new()
	_moves.add_theme_constant_override("separation", 4)
	card.body.add_child(_moves)
	_hint = Kit.text("", TEXT_WIDTH, &"PaperLabel")
	_hint.add_theme_color_override("font_color", Kit.BLOOD)
	card.body.add_child(_hint)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", GAP)
	card.body.add_child(buttons)
	action = KitButton.new()
	action.kind = KitButton.Kind.PRIMARY
	action.press_sound = "coin"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.pressed.connect(_on_action)
	buttons.add_child(action)
	give = KitButton.new()
	give.kind = KitButton.Kind.SMALL
	give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	give.pressed.connect(_on_give)
	buttons.add_child(give)
	return card


func _small_button(words: String, press: Callable) -> KitButton:
	var button := KitButton.new()
	button.kind = KitButton.Kind.SMALL
	button.text = words
	button.pressed.connect(press)
	return button


func _build_top_bar(town: TownData) -> void:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", BAR_GAP)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = BAR_MARGIN
	bar.offset_right = -BAR_MARGIN
	bar.offset_top = BAR_MARGIN
	add_child(bar)
	date_chip = DateChip.new()
	bar.add_child(date_chip)
	gold_chip = KitChip.new("coin", town.gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(gold_chip)
	Tips.attach(gold_chip, "Gold", "Pays for adventurers, bills and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(_leave)
	add_child(back)


# --- Showing what is there ---------------------------------------------------

func _refresh(roll := true) -> void:
	var town := TownData.current()
	gold_chip.set_amount(town.gold, roll)
	date_chip.show_day(town, town.day)
	buy_tab.lit = tab == Tab.BUY
	sell_tab.lit = tab == Tab.SELL
	_fill_shelves(town)
	_show_person()
	_show_picked(town)
	_aim_arrow(town)


func _fill_shelves(town: TownData) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focused_id := ""
	if focused is ShopTile and tiles.has(focused):
		focused_id = (focused as ShopTile).id
	for tile in tiles:
		_grid.remove_child(tile)
		tile.queue_free()
	tiles.clear()
	if tab == Tab.BUY:
		for id in town.on_sale():
			_add_tile(ShopTile.new(id))
	else:
		for id in town.stock_ids():
			_add_tile(ShopTile.new(id, false, town.stock_count(id)))
		for id in Database.sorted_ids(Database.materials):
			if town.materials.get(id, 0) > 0:
				_add_tile(ShopTile.new(id, true, town.materials[id]))
	_empty.visible = tiles.is_empty()
	_grid.visible = not tiles.is_empty()
	# Keeps focus on the shelves, on what is picked, or on the first tile if that sold out.
	if focused_id != "" or (focused != null and not is_instance_valid(focused)):
		var keep: String = picked["id"] if picked.get("from", "") == "shelf" else focused_id
		for tile in tiles:
			if tile.id == keep:
				tile.grab_focus.call_deferred()
				return
		(tiles[0] if not tiles.is_empty() else sell_tab).grab_focus.call_deferred()


func _add_tile(tile: ShopTile) -> void:
	tile.pressed.connect(_pick.bind({"from": "shelf", "id": tile.id, "material": tile.is_material}))
	tile.focus_entered.connect(_pick.bind({"from": "shelf", "id": tile.id, "material": tile.is_material}))
	tile.lit = picked.get("from", "") == "shelf" and picked["id"] == tile.id
	_grid.add_child(tile)
	tiles.append(tile)


func _show_person() -> void:
	var one := shopper()
	var many := TownData.current().roster.size() > 1
	prev_person.visible = many
	next_person.visible = many
	if one == null:
		_who.text = "Nobody on your roster"
	else:
		_who.text = "For %s, level %d" % [one.person.display_name, one.level]
	for index in SLOTS.size():
		var worn: String = "" if one == null else one.equipment.get(SLOTS[index], "")
		slots[index].icon = null if worn == "" else GameArt.item_icon(Database.get_item(worn))
		slots[index].disabled = one == null
		slots[index].lit = picked.get("from", "") == "slot" and picked["kind"] == SLOTS[index]
	for index in pack_tiles.size():
		var item_id := ""
		if one != null and index < one.pack.size():
			item_id = one.pack[index]
		pack_tiles[index].icon = null if item_id == "" else GameArt.item_icon(Database.get_item(item_id))
		pack_tiles[index].disabled = item_id == ""
		pack_tiles[index].focus_mode = Control.FOCUS_NONE if item_id == "" else Control.FOCUS_ALL
		pack_tiles[index].lit = picked.get("from", "") == "pack" and picked["index"] == index


func _show_picked(town: TownData) -> void:
	for child in _moves.get_children():
		_moves.remove_child(child)
		child.queue_free()
	_hint.text = ""
	action.visible = false
	give.visible = false
	var one := shopper()
	match picked.get("from", ""):
		"shelf":
			if picked["material"]:
				_show_material(town, picked["id"])
			else:
				_show_item(town, picked["id"], one)
		"pack":
			if one == null or picked["index"] >= one.pack.size():
				picked = {}
				_show_nothing(town)
				return
			_describe(one.pack[picked["index"]], one)
			action.visible = true
			action.kind = KitButton.Kind.NORMAL
			action.press_sound = "click"
			action.text = "Take out"
			action.block("")
		"slot":
			var worn: String = "" if one == null else one.equipment.get(picked["kind"], "")
			if worn == "":
				_title.text = SLOT_WORDS[picked["kind"]]
				_kind.text = ""
				_words.text = "Nothing worn here."
			else:
				_describe(worn, one)
				_kind.text = "Worn by %s" % one.person.display_name
		_:
			_show_nothing(town)


func _show_nothing(town: TownData) -> void:
	_title.text = ""
	_kind.text = ""
	_words.text = PICK_SOMETHING if tab == Tab.BUY or not town.stock.is_empty() or not town.materials.is_empty() else ""


func _show_item(town: TownData, id: String, one: Member) -> void:
	var item := Database.get_item(id)
	_describe(id, one)
	action.visible = true
	action.kind = KitButton.Kind.PRIMARY
	action.press_sound = "coin"
	if tab == Tab.BUY:
		_kind.text = "%s, %d gold" % [KIND_WORDS[item.kind], item.price]
		var problem := "Hire someone first" if one == null else town.buy_problem(id, one)
		action.text = problem if problem != "" else "Buy for %d gold" % item.price
		action.block(_buy_reason(town, item, one, problem))
		return
	_kind.text = "%s, the town has %d" % [KIND_WORDS[item.kind], town.stock_count(id)]
	action.text = "Sell for %d gold" % TownData.sell_price(id)
	action.block("" if town.stock_count(id) > 0 else "None left.")
	give.visible = one != null
	if one != null:
		var problem := town.give_problem(id, one)
		give.text = problem if problem != "" else ("Wear it" if item.is_gear() else "Pack it")
		give.block("%s's pack is full." % one.person.display_name if problem != "" else "")


func _buy_reason(town: TownData, item: ItemData, one: Member, problem: String) -> String:
	if problem == "":
		return ""
	if one == null:
		return "Gear is bought for someone on your roster."
	if not item.is_gear() and not one.pack_has_room():
		return "%s's pack is full. Take something out first." % one.person.display_name
	return "You have %d gold, and it costs %d." % [town.gold, item.price]


func _show_material(town: TownData, id: String) -> void:
	var material := Database.get_material(id)
	_title.text = material.display_name
	_kind.text = "%s, the town has %d" % ["Rare material" if material.rare else "Material", town.materials.get(id, 0)]
	_words.text = material.description + "\nThe town will build with these."
	action.visible = true
	action.kind = KitButton.Kind.PRIMARY
	action.press_sound = "coin"
	action.text = "Sell for %d gold" % TownData.material_price(id)
	action.block("" if town.materials.get(id, 0) > 0 else "None left.")


# The item's name, what it does, its moves with their icons, and what wearing it would
# change for `one`.
func _describe(id: String, one: Member) -> void:
	var item := Database.get_item(id)
	_title.text = item.display_name
	_kind.text = KIND_WORDS[item.kind]
	var lines := PackedStringArray([item.effect_text(), item.description])
	if item.is_gear() and one != null and one.equipment.get(item.kind, "") != id:
		lines.append_array(_changes(item, one))
	_words.text = "\n".join(lines)
	for move_id in item.moves:
		_moves.add_child(_move_row(Database.get_move(move_id)))


func _move_row(move: MoveData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var label := Kit.text(move.display_name, 0.0, &"PaperTitle")
	row.add_child(label)
	var icons := MoveIcons.for_move(move)
	if icons != null:
		var picture := TextureRect.new()
		picture.texture = icons
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
	Tips.attach(row, move.display_name, MoveIcons.hint_for(move))
	return row


# What wearing `item` would change for `one`, a line for each stat.
func _changes(item: ItemData, one: Member) -> PackedStringArray:
	var sheet := one.sheet()
	var lines := PackedStringArray()
	for stat: String in ItemData.STAT_NAMES:
		var now: int = sheet.get_stat(stat)
		var then: int = sheet.get_stat_with(item.id, stat)
		if then != now:
			lines.append("%s %d to %d" % [ItemData.STAT_NAMES[stat], now, then])
	return lines


# The arrow goes to Sell while the town owns something, until the Sell tab is open.
func _aim_arrow(town: TownData) -> void:
	var owns := not town.stock.is_empty() or not town.materials.is_empty()
	arrow.target = sell_tab if owns and tab == Tab.BUY else null
	arrow.visible = arrow.target != null


func _say(words: String) -> void:
	var area := Rect2(ROOM_AREA.position + _stage.position, ROOM_AREA.size)
	bubble.say(words, ShopRoom.KEEPER_HEAD + _stage.position, area)


# --- Doing things ------------------------------------------------------------

func _pick(what: Dictionary) -> void:
	picked = what
	_show_person()
	for tile in tiles:
		tile.lit = picked.get("from", "") == "shelf" and picked["id"] == tile.id
	_show_picked(TownData.current())


func _turn_person(step: int) -> void:
	var size := TownData.current().roster.size()
	if size == 0:
		return
	person_index = posmod(person_index + step, size)
	if picked.get("from", "") != "shelf":
		picked = {}
	_refresh(false)


func _on_action() -> void:
	var town := TownData.current()
	var one := shopper()
	match picked.get("from", ""):
		"shelf":
			if picked["material"]:
				_sell(town.sell_material(picked["id"]), TownData.material_price(picked["id"]))
			elif tab == Tab.BUY:
				var item := Database.get_item(picked["id"])
				if one == null or not town.buy(picked["id"], one):
					action.deny()
					return
				_say((SAY_BOUGHT if item.is_gear() else SAY_PACKED) % one.person.display_name)
				_refresh()
			else:
				_sell(town.sell(picked["id"]), TownData.sell_price(picked["id"]))
		"pack":
			if one == null or not town.unpack(one, picked["index"]):
				action.deny()
				return
			picked = {}
			_refresh(false)
			back.grab_focus()


func _sell(done: bool, price: int) -> void:
	if not done:
		action.deny()
		return
	var town := TownData.current()
	var id: String = picked["id"]
	var left: int = town.materials.get(id, 0) if picked["material"] else town.stock_count(id)
	if left == 0:
		picked = {}
	_say(SAY_SOLD % price)
	_refresh()
	if left == 0 and town.stock.is_empty() and town.materials.is_empty():
		_say(SAY_EMPTY)
		buy_tab.grab_focus()


func _on_give() -> void:
	var town := TownData.current()
	var one := shopper()
	var id: String = picked.get("id", "")
	if one == null or not town.give(id, one):
		give.deny()
		return
	Sound.play("item")
	if town.stock_count(id) == 0:
		picked = {}
	_say((SAY_BOUGHT if Database.get_item(id).is_gear() else SAY_PACKED) % one.person.display_name)
	_refresh(false)


func _leave() -> void:
	Screens.go(TOWN)
