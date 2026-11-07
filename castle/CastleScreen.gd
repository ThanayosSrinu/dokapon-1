class_name CastleScreen
extends Control
## Your home in town. The tiles on the left are the King's letter and the Town Plans, one
## for each building that can still be raised. The card on the right shows the tile picked:
## the letter with its goal and reward, or a plan with what it does, what it costs and one
## button. The rules are in TownData and TownPlans: this only asks and redraws.

const TOWN := "res://town/TownScreen.tscn"
const FOLDER := "res://assets/custom/castle"
const STEWARD: Texture2D = preload("res://assets/puny/characters/Soldier-Yellow.png")
const STAGE := Vector2(1280, 720)
const TILES_SPOT := Vector2(40, 292)
const COLUMNS := 5
const GAP := 8
const CARD_LEFT := 816.0
const CARD_TOP := 92.0
const CARD_WIDTH := 440.0
const TEXT_WIDTH := 400.0
## Speech bubbles stay inside the room's part of the stage.
const ROOM_AREA := Rect2(0, 0, 808, 720)
const BAR_MARGIN := 24.0
const SAY_HELLO := "Welcome home, my lord."
const SAY_LETTER := "A letter from the King, my lord."
const SAY_PLEASED := "The King is pleased with you, my lord!"
const SAY_BUILT := "The builders start at once."
const SAY_RAISED := "It will be the finest in the land."
const NO_LETTER := "No letter for now. The King will write again."

## A building id the Castle opens on, set by the town when a building with no room of its
## own is visited. It is used once.
static var open_on := ""

var back: KitBackButton
## The main button of the card: Build, or Take the reward.
var action: KitButton
var gold_chip: KitChip
var date_chip: DateChip
var arrow: KitArrow
var bubble: TavernBubble
## The tiles now: the letter first, then the plans.
var tiles: Array[PlanTile] = []
## The id of the tile the card shows.
var picked := PlanTile.LETTER_ID

var _stage: Node2D
var _grid: GridContainer
var _bar: HBoxContainer
var _title: Label
var _kind: Label
var _words: Label
var _costs: HBoxContainer
var _goal: Label
var _progress: KitBar
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	_stage.add_child(KeeperRoom.new(FOLDER, STEWARD))
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(_build_tiles())
	layer.add_child(_build_card())
	bubble = TavernBubble.new()
	_stage.add_child(bubble)
	_build_top_bar()
	arrow = KitArrow.new(null, KitArrow.Side.ABOVE)
	add_child(arrow)
	if open_on != "" and town.plan_ids().has(open_on):
		picked = open_on
	open_on = ""
	_refresh(false)
	_tile(picked).grab_focus()
	_say(SAY_LETTER if picked == PlanTile.LETTER_ID and town.letter_done() else SAY_HELLO)
	Sound.music("hometown")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_stage.position = _stage_corner()


func _stage_corner() -> Vector2:
	return Kit.snap_point(((get_viewport_rect().size - STAGE) / 2.0).max(Vector2.ZERO))


## Shows tile `id` in the card, as a click would.
func pick(id: String) -> void:
	picked = id
	_refresh()


## The tile showing `id`, or null.
func tile(id: String) -> PlanTile:
	for one in tiles:
		if one.id == id:
			return one
	return null


## The red line under a plan, saying why it can't be built, or "".
func shown_hint() -> String:
	return _hint.text


func _tile(id: String) -> PlanTile:
	var found := tile(id)
	return found if found != null else tiles[0]


# --- Building the screen -----------------------------------------------------

func _build_tiles() -> Control:
	var panel := KitPanel.new("Town Plans", true)
	panel.position = TILES_SPOT
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	panel.body.add_child(_grid)
	return panel


func _build_card() -> Control:
	var card := KitPanel.new("", true)
	card.custom_minimum_size.x = CARD_WIDTH
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	card.body.add_theme_constant_override("separation", 10)
	_title = Kit.text("", 0.0, &"PaperHeading")
	card.body.add_child(_title)
	_kind = Kit.text("", TEXT_WIDTH, &"PaperTitle")
	card.body.add_child(_kind)
	_words = Kit.text("", TEXT_WIDTH, &"PaperLabel")
	card.body.add_child(_words)
	_goal = Kit.text("", TEXT_WIDTH, &"PaperTitle")
	card.body.add_child(_goal)
	_progress = KitBar.new(Kit.SUPPLY)
	_progress.custom_minimum_size.x = TEXT_WIDTH
	card.body.add_child(_progress)
	_costs = HBoxContainer.new()
	_costs.add_theme_constant_override("separation", GAP)
	card.body.add_child(_costs)
	_hint = Kit.text("", TEXT_WIDTH, &"PaperLabel")
	_hint.add_theme_color_override("font_color", Kit.BLOOD)
	card.body.add_child(_hint)
	action = KitButton.new()
	action.kind = KitButton.Kind.PRIMARY
	action.press_sound = "coin"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.pressed.connect(_on_action)
	card.body.add_child(action)
	return card


func _build_top_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.alignment = BoxContainer.ALIGNMENT_END
	_bar.add_theme_constant_override("separation", GAP)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = BAR_MARGIN
	_bar.offset_right = -BAR_MARGIN
	_bar.offset_top = BAR_MARGIN
	add_child(_bar)
	date_chip = DateChip.new()
	gold_chip = KitChip.new("coin", TownData.current().gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	Tips.attach(gold_chip, "Gold", "Pays for adventurers, bills and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(_leave)
	add_child(back)


# Material chips change as plans use them up, so the bar is made again each time.
func _fill_top_bar(town: TownData, roll: bool) -> void:
	for child in _bar.get_children():
		_bar.remove_child(child)
		if child != date_chip and child != gold_chip:
			child.queue_free()
	for id in Database.sorted_ids(town.materials):
		if town.materials[id] > 0:
			var chip := KitChip.new("coin", town.materials[id])
			chip.set_picture(GameArt.material_icon(Database.get_material(id)))
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			Tips.attach(chip, Database.get_material(id).display_name, "Brought home by trips. Plans are built with it.")
			_bar.add_child(chip)
	_bar.add_child(date_chip)
	_bar.add_child(gold_chip)
	gold_chip.set_amount(town.gold, roll)
	date_chip.show_day(town, town.day)


# --- Showing what is there ---------------------------------------------------

func _refresh(roll := true) -> void:
	var town := TownData.current()
	_fill_top_bar(town, roll)
	_fill_tiles(town)
	_show_picked(town)
	_aim_arrow(town)


func _fill_tiles(town: TownData) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focused_id := (focused as PlanTile).id if focused is PlanTile and tiles.has(focused) else ""
	for one in tiles:
		_grid.remove_child(one)
		one.queue_free()
	tiles.clear()
	_add_tile(PlanTile.new())
	for id in town.plan_ids():
		var locked := not town.is_opened(id)
		_add_tile(PlanTile.new(id, town.level(id) + 1, locked, town.plan_problem(id) == ""))
	if not town.plan_ids().has(picked):
		picked = PlanTile.LETTER_ID
	# The tiles were made again, so the focus goes back to the one picked.
	if focused_id != "":
		_tile(picked).grab_focus.call_deferred()


func _add_tile(one: PlanTile) -> void:
	one.pressed.connect(pick.bind(one.id))
	one.focus_entered.connect(_pick_quietly.bind(one.id))
	one.lit = one.id == picked
	_grid.add_child(one)
	tiles.append(one)


func _show_picked(town: TownData) -> void:
	for child in _costs.get_children():
		_costs.remove_child(child)
		child.queue_free()
	_hint.text = ""
	_goal.visible = false
	_progress.visible = false
	if picked == PlanTile.LETTER_ID:
		_show_letter(town)
	else:
		_show_plan(town, picked)


func _show_letter(town: TownData) -> void:
	var found := town.letter()
	if found.is_empty():
		_title.text = "Royal Letter"
		_kind.text = ""
		_words.text = NO_LETTER
		action.visible = false
		return
	_title.text = found["title"]
	_kind.text = "A letter from the King"
	var opens := PackedStringArray()
	for id: String in found["opens"]:
		opens.append(TownData.BUILDINGS[id]["name"] if id != "portal" else "Portal Beacon")
	_words.text = "%s\n\nReward: %d gold, and the plans for the %s." % [
			TownPlans.letter_text(found), found["gold"], " and the ".join(opens)]
	_goal.visible = true
	_goal.text = "%s: %d of %d" % [TownPlans.goal_words(found), town.letter_progress, found["count"]]
	_progress.visible = true
	_progress.set_amount(town.letter_progress, found["count"], false)
	var done := town.letter_done()
	action.visible = true
	action.press_sound = "coin"
	action.text = "Take the reward" if done else "Not done yet"
	action.block("" if done else "Trips count toward it as they come home.")


func _show_plan(town: TownData, id: String) -> void:
	var found := town.next_plan(id)
	var name: String = TownData.BUILDINGS[id]["name"]
	var level := town.level(id)
	_title.text = "Portal Beacon" if id == "portal" else name
	if level == 0:
		_kind.text = "Build the %s" % name
	else:
		_kind.text = "%s, level %d to %d" % [name, level, level + 1]
	_words.text = found["does"]
	_costs.add_child(_cost_chip(Kit.icon("coin"), found["gold"], town.gold, "Gold"))
	for material_id: String in found["materials"]:
		var material := Database.get_material(material_id)
		_costs.add_child(_cost_chip(GameArt.material_icon(material), found["materials"][material_id],
				town.materials.get(material_id, 0), material.display_name))
	var problem := town.plan_problem(id)
	action.visible = true
	action.press_sound = "coin"
	action.text = "Build it" if level == 0 else "Raise to level %d" % (level + 1)
	if not town.is_opened(id):
		action.text = "Locked"
		_hint.text = "The King has not sent these plans yet. His letters open them."
	elif problem != "":
		_hint.text = "%s. Trips bring home materials, and gold." % problem
	action.block(_hint.text)


# A cost, with what the town has: red while it has too few.
func _cost_chip(picture: Texture2D, need: int, have: int, what: String) -> Control:
	var chip := KitChip.new("coin", need)
	chip.set_picture(picture)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	if have < need:
		chip.modulate = Kit.DANGER_STAIN
	Tips.attach(chip, what, "Needs %d. The town has %d." % [need, have])
	return chip


# The arrow points at the letter while its reward waits, and at a plan that can be built.
func _aim_arrow(town: TownData) -> void:
	var target: Control = null
	if town.letter_done() and picked != PlanTile.LETTER_ID:
		target = tile(PlanTile.LETTER_ID)
	elif picked == PlanTile.LETTER_ID and town.letter_done():
		target = action
	arrow.target = target
	arrow.visible = target != null


func _say(words: String) -> void:
	var area := Rect2(ROOM_AREA.position + _stage.position, ROOM_AREA.size)
	bubble.say(words, KeeperRoom.KEEPER_HEAD + _stage.position, area)


# --- Doing things ------------------------------------------------------------

# Pointing at a tile shows it, without moving the focus.
func _pick_quietly(id: String) -> void:
	if picked != id:
		picked = id
		for one in tiles:
			one.lit = one.id == picked
		var town := TownData.current()
		_show_picked(town)
		_aim_arrow(town)


func _on_action() -> void:
	var town := TownData.current()
	if picked == PlanTile.LETTER_ID:
		if not town.claim_letter():
			action.deny()
			return
		_say(SAY_PLEASED)
		Sound.play("fanfare")
		_refresh()
		_tile(PlanTile.LETTER_ID).grab_focus()
		return
	var level := town.level(picked)
	if not town.build(picked):
		action.deny()
		return
	_say(SAY_BUILT if level == 0 else SAY_RAISED)
	_refresh()
	_tile(picked).grab_focus()


func _leave() -> void:
	Screens.go(TOWN)
