class_name BagRow
extends HBoxContainer
## One place in the bag: the item, and at the right end its Auto switch, or Wear if it is
## gear worth putting on. Press the item to use it or wear it.

signal chosen(item_id: String)
signal auto_changed(item_id: String, on: bool)
signal pointed(item_id: String)

const HEIGHT := 36.0
const SIDE_WIDTH := 56.0
const AUTO_OFF_COLOR := Color(0.6, 0.58, 0.64)
const HOVER_COLOR := Color(1.0, 0.85, 0.42, 0.16)

var item_id := ""
## Uses or wears the item.
var button: Button
## Lets the bot use this item by itself.
var auto: Button
var side_words: Label


func _init() -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size.y = HEIGHT
	button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flatten(button)
	button.pressed.connect(func() -> void: chosen.emit(item_id))
	add_child(button)
	auto = Button.new()
	auto.text = "Auto"
	auto.toggle_mode = true
	auto.custom_minimum_size = Vector2(SIDE_WIDTH, HEIGHT)
	_flatten(auto)
	auto.toggled.connect(_on_auto)
	add_child(auto)
	side_words = Kit.text("Wear")
	side_words.modulate = Kit.GOLD
	side_words.custom_minimum_size.x = SIDE_WIDTH
	side_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(side_words)
	for part: Control in [button, auto]:
		part.mouse_entered.connect(_point)
		part.focus_entered.connect(_point)
		part.mouse_exited.connect(_stop_pointing)
		part.focus_exited.connect(_stop_pointing)


## Shows `new_item`, or an empty place if it is "".
func show_item(new_item: String, player: PlayerData, locked: bool) -> void:
	item_id = new_item
	var empty := item_id == ""
	var item: ItemData = null if empty else Database.get_item(item_id)
	var usable := not empty and item.kind == ItemData.Kind.CONSUMABLE
	button.text = "" if empty else item.display_name
	button.icon = null if empty else GameArt.item_icon(item)
	button.disabled = empty or locked
	button.focus_mode = Control.FOCUS_NONE if empty else Control.FOCUS_ALL
	auto.visible = usable
	if usable:
		auto.set_pressed_no_signal(not player.auto_off.has(item_id))
		_paint_auto()
	side_words.visible = not usable
	side_words.text = "Wear" if not empty and not usable and CpuBrain.is_upgrade(player, item_id) else ""


func _on_auto(on: bool) -> void:
	_paint_auto()
	auto_changed.emit(item_id, on)


func _paint_auto() -> void:
	auto.modulate = Kit.GOLD if auto.button_pressed else AUTO_OFF_COLOR


func _point() -> void:
	if item_id != "":
		pointed.emit(item_id)


func _stop_pointing() -> void:
	pointed.emit("")


func _flatten(part: Button) -> void:
	var empty := StyleBoxEmpty.new()
	var lit := StyleBoxFlat.new()
	lit.bg_color = HOVER_COLOR
	for state: StringName in [&"normal", &"disabled", &"pressed"]:
		part.add_theme_stylebox_override(state, empty)
	for state: StringName in [&"hover", &"hover_pressed", &"focus"]:
		part.add_theme_stylebox_override(state, lit)
