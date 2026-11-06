class_name KitGallery
extends Control
## Every part of the UI kit in every state, to judge the look in one place. Press F2
## on the main menu, or run this scene. The bottom row's buttons try the moving parts.

const MENU := "res://ui/menu/MainMenu.tscn"
const LOOKS := [["Rest", KitButton.Look.REST], ["Hover", KitButton.Look.HOT],
		["Pressed", KitButton.Look.DOWN], ["Focus", KitButton.Look.FOCUS], ["Off", KitButton.Look.OFF]]
const BACKDROP := Color(0.34, 0.47, 0.42)
const COLUMN := 190.0
const NAME_WIDTH := 96.0
const SPOT := Vector2(24, 80)
const TAKE := 30
const GIVE := 120
const FULL := 100.0

var back: KitBackButton
var arrow: KitArrow

var _gold: KitChip
var _health: KitBar
var _food: KitBar
var _health_now := 80.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.position = SPOT
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(_button_table())
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 16)
	column.add_child(lower)
	lower.add_child(_resources_panel())
	lower.add_child(_bars_panel())
	lower.add_child(_tip_panel())

	var title := Kit.text("UI Kit", 0.0, &"Heading")
	title.position = Vector2(150, 26)
	add_child(title)
	back = KitBackButton.new()
	back.pressed.connect(func() -> void: Screens.go(MENU))
	add_child(back)
	Sound.music("title")
	back.grab_focus()
	if not Screens.busy:
		Screens.reveal()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _button_table() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = LOOKS.size() + 1
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(Control.new())
	for look: Array in LOOKS:
		var label := Kit.text(look[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
	var rows := [["Main", KitButton.Kind.PRIMARY, "Play", "play"],
			["Normal", KitButton.Kind.NORMAL, "Options", "gear"],
			["Small", KitButton.Kind.SMALL, "Next", ""]]
	for row: Array in rows:
		grid.add_child(_row_name(row[0]))
		for look: Array in LOOKS:
			var button := KitButton.new()
			button.text = row[2]
			button.kind = row[1]
			button.icon = Kit.icon(row[3]) if row[3] != "" else null
			button.custom_minimum_size.x = COLUMN - NAME_WIDTH / 2.0
			button.forced_look = look[1]
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(button)
	grid.add_child(_row_name("Back"))
	for look: Array in LOOKS:
		var sample := KitButton.new()
		sample.text = "Back"
		sample.icon = Kit.icon("back")
		sample.kind = KitButton.Kind.SMALL
		sample.forced_look = look[1]
		sample.focus_mode = Control.FOCUS_NONE
		sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sample.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_child(sample)
	return grid


func _row_name(words: String) -> Label:
	var label := Kit.text(words)
	label.custom_minimum_size.x = NAME_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _resources_panel() -> KitPanel:
	var panel := KitPanel.new()
	var chips := GridContainer.new()
	chips.columns = 2
	panel.body.add_child(chips)
	_gold = KitChip.new("coin", 250)
	chips.add_child(_gold)
	for part: Array in [["food", 7], ["wood", 12], ["ore", 3], ["herb", 8], ["bag", 5]]:
		chips.add_child(KitChip.new(part[0], part[1]))
	Tips.attach(_gold, "Gold", "Pays for hiring and for upgrades.")
	_gold.focus_mode = Control.FOCUS_ALL
	var earn := _try_button("Earn gold")
	earn.pressed.connect(func() -> void:
			Sound.play("coin")
			_gold.set_amount(_gold.amount + GIVE))
	panel.body.add_child(earn)
	return panel


func _bars_panel() -> KitPanel:
	var panel := KitPanel.new()
	_health = KitBar.new(Kit.HEALTH, Kit.icon("heart"))
	_health.set_amount(_health_now, FULL, false)
	Tips.attach(_health, "Health", "80 out of 100")
	panel.body.add_child(_health)
	_food = KitBar.new(Kit.SUPPLY, Kit.icon("food"))
	_food.set_amount(5.0, 14.0, false)
	Tips.attach(_food, "Food", "Food for 5 more days")
	_health.focus_mode = Control.FOCUS_ALL
	_food.focus_mode = Control.FOCUS_ALL
	panel.body.add_child(_food)
	var magic := KitBar.new(Kit.MAGIC, Kit.icon("star"))
	magic.set_amount(4.0, 10.0, false)
	panel.body.add_child(magic)
	var low := KitBar.new(Kit.DANGER, Kit.icon("sword"))
	low.set_amount(1.0, 10.0, false)
	panel.body.add_child(low)
	var hurt := _try_button("Take a hit")
	hurt.pressed.connect(_on_hurt)
	panel.body.add_child(hurt)
	return panel


func _tip_panel() -> KitPanel:
	var panel := KitPanel.new()
	panel.body.add_child(Tips.build_card("A tooltip", "Details appear on hover or focus.")[0])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.body.add_child(row)
	var blocked := KitButton.new()
	blocked.text = "Hire"
	blocked.kind = KitButton.Kind.SMALL
	blocked.block("You need 120 more gold.")
	row.add_child(blocked)
	var wipe := _try_button("Try a wipe")
	wipe.pressed.connect(func() -> void: Screens.go("res://ui/kit/KitGallery.tscn"))
	row.add_child(wipe)
	var marked := Control.new()
	marked.custom_minimum_size = Vector2(32, 32)
	row.add_child(marked)
	arrow = KitArrow.new(wipe, KitArrow.Side.RIGHT)
	add_child(arrow)
	return panel


func _try_button(words: String) -> KitButton:
	var button := KitButton.new()
	button.text = words
	button.kind = KitButton.Kind.SMALL
	return button


func _on_hurt() -> void:
	Sound.play("hit")
	_health_now = FULL if _health_now <= 0.0 else maxf(_health_now - TAKE, 0.0)
	_health.set_amount(_health_now, FULL)
	Tips.attach(_health, "Health", "%d out of %d" % [_health_now, FULL])
