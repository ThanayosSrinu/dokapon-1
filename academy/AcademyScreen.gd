class_name AcademyScreen
extends Control
## The Academy teaches Magic and Special moves for gold. The buttons on the left are the moves
## it teaches, by name and price. The card on the right is who
## learns, with the moves they know, and the move picked, with one button. With both of
## their slots full, a learner must forget one move to take another. The rules are in
## TownData: this only asks and redraws.

const TOWN := "res://town/TownScreen.tscn"
const FOLDER := "res://assets/custom/academy"
const TEACHER: Texture2D = preload("res://assets/puny/characters/Mage-Cyan.png")
const STAGE := Vector2(1280, 720)
const TILES_SPOT := Vector2(40, 292)
const COLUMNS := 2
const MOVE_WIDTH := 300.0
const GAP := 8
const CARD_LEFT := 816.0
const CARD_TOP := 92.0
const CARD_WIDTH := 440.0
const TEXT_WIDTH := 400.0
## Speech bubbles stay inside the room's part of the stage.
const ROOM_AREA := Rect2(0, 0, 808, 720)
const BAR_MARGIN := 24.0
const CATEGORY_WORDS := {MoveData.Category.MAGIC: "Magic", MoveData.Category.SPECIAL: "Special"}
const SAY_HELLO := "Welcome, my lord. Who will study today?"
const SAY_NOBODY := "Welcome, my lord. Send me a student from the Tavern."
const SAY_TAUGHT := "%s has it. Practice makes perfect!"
const SAY_RESET := "%s can choose again. Choose wisely!"
## What the tile that takes back a skill tree stands for, in place of a tome id.
const RESET := "reset_tree"
const MORE_LATER := "A bigger Academy teaches more. Raise it from the Town Plans at the Castle."

var back: KitBackButton
## Teaches the move picked, while a slot is free.
var action: KitButton
## With both slots full: one button for each move known, to forget it for the new one.
var swaps: Array[KitButton] = []
var prev_person: KitButton
var next_person: KitButton
var gold_chip: KitChip
var date_chip: DateChip
var bubble: TavernBubble
## A button for each move taught, in the order of `tile_ids`.
var tiles: Array[KitButton] = []
## The tome id each button stands for.
var tile_ids: Array[String] = []
## Who learns, as a place on the roster.
var person_index := 0
## The tome id of the move picked, or "".
var picked := ""

var _stage: Node2D
var _grid: GridContainer
var _who: Label
var _known: VBoxContainer
var _title: Label
var _kind: Label
var _words: Label
var _icons: TextureRect
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	_stage.add_child(KeeperRoom.new(FOLDER, TEACHER))
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(_build_tiles(town))
	layer.add_child(_build_card())
	bubble = TavernBubble.new()
	_stage.add_child(bubble)
	_build_top_bar(town)
	if not tiles.is_empty():
		picked = tile_ids[0]
	_refresh(false)
	(tiles[0] if not tiles.is_empty() else back).grab_focus()
	_say(SAY_HELLO if learner() != null else SAY_NOBODY)
	Sound.music("shop")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_stage.position = _stage_corner()


func _stage_corner() -> Vector2:
	return Kit.snap_point(((get_viewport_rect().size - STAGE) / 2.0).max(Vector2.ZERO))


## Who learns, or null with nobody on the roster.
func learner() -> Member:
	var roster := TownData.current().roster
	return null if roster.is_empty() else roster[clampi(person_index, 0, roster.size() - 1)]


## Shows the move taught by `tome_id` in the card, as a click would.
func pick(tome_id: String) -> void:
	picked = tome_id
	_refresh()


# --- Building the screen -----------------------------------------------------

func _build_tiles(town: TownData) -> Control:
	var panel := KitPanel.new("Moves taught", true)
	panel.position = TILES_SPOT
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	panel.body.add_child(_grid)
	for id in town.teachable():
		var tome := Database.get_item(id)
		var one := KitButton.new()
		one.kind = KitButton.Kind.SMALL
		one.left_aligned = true
		one.custom_minimum_size.x = MOVE_WIDTH
		one.text = "%s, %d" % [Database.get_move(tome.teaches).display_name, tome.price]
		one.pressed.connect(pick.bind(id))
		one.focus_entered.connect(_pick_quietly.bind(id))
		_grid.add_child(one)
		tiles.append(one)
		tile_ids.append(id)
	var reset := KitButton.new()
	reset.kind = KitButton.Kind.SMALL
	reset.left_aligned = true
	reset.custom_minimum_size.x = MOVE_WIDTH
	reset.text = "Reset skill tree"
	reset.pressed.connect(pick.bind(RESET))
	reset.focus_entered.connect(_pick_quietly.bind(RESET))
	_grid.add_child(reset)
	tiles.append(reset)
	tile_ids.append(RESET)
	if town.level("academy") < TownPlans.ACADEMY_MOVES.size() - 1:
		panel.body.add_child(Kit.text(MORE_LATER, COLUMNS * (MOVE_WIDTH + GAP), &"PaperLabel"))
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
	_known = VBoxContainer.new()
	_known.add_theme_constant_override("separation", 4)
	card.body.add_child(_known)
	card.body.add_child(HSeparator.new())
	_title = Kit.text("", 0.0, &"PaperHeading")
	card.body.add_child(_title)
	_kind = Kit.text("", TEXT_WIDTH, &"PaperTitle")
	card.body.add_child(_kind)
	_icons = TextureRect.new()
	_icons.stretch_mode = TextureRect.STRETCH_KEEP
	card.body.add_child(_icons)
	_words = Kit.text("", TEXT_WIDTH, &"PaperLabel")
	card.body.add_child(_words)
	_hint = Kit.text("", TEXT_WIDTH, &"PaperLabel")
	_hint.add_theme_color_override("font_color", Kit.BLOOD)
	card.body.add_child(_hint)
	action = KitButton.new()
	action.kind = KitButton.Kind.PRIMARY
	action.press_sound = "coin"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.pressed.connect(_teach.bind(""))
	card.body.add_child(action)
	for index in TownData.current().move_slots():
		var swap := KitButton.new()
		swap.kind = KitButton.Kind.SMALL
		swap.press_sound = "coin"
		swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swap.pressed.connect(_swap.bind(index))
		card.body.add_child(swap)
		swaps.append(swap)
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
	bar.add_theme_constant_override("separation", GAP)
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
	for index in tiles.size():
		tiles[index].lit = tile_ids[index] == picked
	_show_person()
	_show_picked(town)


func _show_person() -> void:
	var one := learner()
	var many := TownData.current().roster.size() > 1
	prev_person.visible = many
	next_person.visible = many
	for child in _known.get_children():
		_known.remove_child(child)
		child.queue_free()
	if one == null:
		_who.text = "Nobody on your roster"
		return
	_who.text = "For %s, level %d" % [one.person.display_name, one.level]
	_known.add_child(Kit.text("Knows %d of %d moves:" % [one.learned.size(), TownData.current().move_slots()], 0.0, &"PaperLabel"))
	for move_id in one.learned:
		_known.add_child(_move_row(Database.get_move(move_id)))


func _show_picked(town: TownData) -> void:
	for swap in swaps:
		swap.visible = false
	_hint.text = ""
	if picked == "":
		_title.text = ""
		_kind.text = ""
		_words.text = ""
		_icons.texture = null
		action.visible = false
		return
	if picked == RESET:
		_show_reset(town)
		return
	var tome := Database.get_item(picked)
	var move := Database.get_move(tome.teaches)
	_title.text = move.display_name
	_kind.text = "%s, %d gold" % [CATEGORY_WORDS.get(move.category, "Move"), tome.price]
	_icons.texture = MoveIcons.for_move(move)
	var cost := "" if move.mp_cost == 0 else " Uses %d MP." % move.mp_cost
	_words.text = MoveIcons.hint_for(move) + cost
	action.visible = true
	var one := learner()
	if one == null:
		action.text = "Hire someone first"
		action.block("Moves are taught to someone on your roster.")
		return
	var problem := town.teach_problem(picked, one)
	var full := problem == "Choose a move to forget"
	action.visible = not full
	action.text = problem if problem != "" else "Teach for %d gold" % tome.price
	action.block("" if problem == "" else _reason(town, tome, one, problem))
	if full:
		_hint.text = "%s knows %d moves already. Pick one to forget." % [one.person.display_name, TownData.current().move_slots()]
		for index in swaps.size():
			var old := Database.get_move(one.learned[index])
			swaps[index].visible = true
			swaps[index].text = "Forget %s for %d gold" % [old.display_name, tome.price]
			swaps[index].block("")


func _show_reset(town: TownData) -> void:
	_title.text = "Reset skill tree"
	_kind.text = "%d gold a point" % SkillTree.RESET_PRICE_PER_POINT
	_icons.texture = null
	_words.text = "Takes back every point spent on the skill tree, to spend again on the details page."
	action.visible = true
	var one := learner()
	if one == null:
		action.text = "Hire someone first"
		action.block("A skill tree belongs to someone on your roster.")
		return
	var problem := town.reset_problem(one)
	action.text = problem if problem != "" else "Reset for %d gold" % one.reset_price()
	if problem == "No points spent":
		action.block("%s has no points spent." % one.person.display_name)
	elif problem != "":
		action.block("You have %d gold, and it costs %d." % [town.gold, one.reset_price()])
	else:
		action.block("")


func _reason(town: TownData, tome: ItemData, one: Member, problem: String) -> String:
	if one.learned.has(tome.teaches):
		return "%s knows this move." % one.person.display_name
	if tome.price > town.gold:
		return "You have %d gold, and it costs %d." % [town.gold, tome.price]
	return problem


func _move_row(move: MoveData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(Kit.text(move.display_name, 0.0, &"PaperTitle"))
	var icons := MoveIcons.for_move(move)
	if icons != null:
		var picture := TextureRect.new()
		picture.texture = icons
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
	Tips.attach(row, move.display_name, MoveIcons.hint_for(move))
	return row


func _say(words: String) -> void:
	var area := Rect2(ROOM_AREA.position + _stage.position, ROOM_AREA.size)
	bubble.say(words, KeeperRoom.KEEPER_HEAD + _stage.position, area)


# --- Doing things ------------------------------------------------------------

func _pick_quietly(tome_id: String) -> void:
	if picked != tome_id:
		picked = tome_id
		_refresh(false)


func _turn_person(step: int) -> void:
	var size := TownData.current().roster.size()
	if size > 0:
		person_index = posmod(person_index + step, size)
		_refresh(false)


func _swap(index: int) -> void:
	var one := learner()
	if one != null and index < one.learned.size():
		_teach(one.learned[index], swaps[index])


func _teach(forgotten: String, button: KitButton = null) -> void:
	var one := learner()
	var pressed: KitButton = action if button == null else button
	if picked == RESET:
		if one == null or not TownData.current().reset_tree(one):
			pressed.deny()
			return
		_say(SAY_RESET % one.person.display_name)
		Sound.play("magic")
		_refresh()
		tile_of(RESET).grab_focus()
		return
	if one == null or not TownData.current().teach(picked, one, forgotten):
		pressed.deny()
		return
	_say(SAY_TAUGHT % one.person.display_name)
	Sound.play("magic")
	_refresh()
	(tile_of(picked) if tile_of(picked) != null else back).grab_focus()


## The button of `tome_id`, or null.
func tile_of(tome_id: String) -> KitButton:
	var index := tile_ids.find(tome_id)
	return null if index < 0 else tiles[index]


func _leave() -> void:
	Screens.go(TOWN)
