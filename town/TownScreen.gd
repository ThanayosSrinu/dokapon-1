class_name TownScreen
extends Control
## The town. The player points at a building to read its sign, and visits it by
## clicking it or pressing Accept. Only buildings in TownData.BUILDINGS can be visited.
## A building with no room of its own opens the Castle on its plans. The town saves itself
## each time it is shown.

const MENU := "res://ui/menu/MainMenu.tscn"
const TAVERN := "res://tavern/TavernScreen.tscn"
const PORTAL := "res://portal/PortalScreen.tscn"
const BANK := "res://bank/BankScreen.tscn"
const SHOP := "res://shop/ShopScreen.tscn"
const CASTLE := "res://castle/CastleScreen.tscn"
const ACADEMY := "res://academy/AcademyScreen.tscn"
## How far the resources stand from the screen's edge. Back has the other corner.
const BAR_MARGIN := 24.0
## Where a hired adventurer waits, from the Portal's feet.
const WAITING_SPOT := Vector2(124, -36)
const BAR_GAP := 8
## How far below the window's middle the town's middle sits, so that the buildings north of
## the street have room under the top bar.
const WORLD_SHIFT := Vector2(0, 48)
## What the Bank's sign says while something falls due soon.
const BANK_MARK := "Pay by %s"
## What the Castle's sign says while a letter's reward waits there.
const CASTLE_MARK := "The King is pleased"

var back: KitBackButton
var art: TownArt
var gold_chip: KitChip
var date_chip: DateChip
## Material id -> its chip on the top bar. Only materials the town has get one.
var material_chips := {}
var arrow: KitArrow
## Who goes next, waiting by the Portal, if there is one.
var waiting: CharacterFigure
## Building id -> its TownBuilding.
var buildings := {}
## Building id -> its TownSign.
var signs := {}

var _world: Node2D
var _ui: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	town.save()
	_build_world(town)
	_build_ui(town)
	_link_focus()
	_refresh(town)
	arrow.target.grab_focus()
	Sound.music("hometown")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_world.position = Kit.snap_point(get_viewport_rect().size / 2.0 + WORLD_SHIFT)


func building(id: String) -> TownBuilding:
	return buildings[id]


# The numbers, the Bank's sign and the arrow, as the town stands now.
func _refresh(town: TownData) -> void:
	gold_chip.set_amount(town.gold, false)
	date_chip.show_day(town, town.day)
	var level := date_chip.level
	var words := BANK_MARK % Calendar.date(town.next_due()) if level != TownData.Alert.NONE else ""
	signs["bank"].mark(words, level)
	signs["castle"].mark(CASTLE_MARK if town.letter_done() else "", TownData.Alert.WARN)
	arrow.target = buildings[town.next_step()]


func _build_world(town: TownData) -> void:
	_world = Node2D.new()
	_world.position = Kit.snap_point(get_viewport_rect().size / 2.0 + WORLD_SHIFT)
	add_child(_world)
	var smoke: Array[Vector2] = []
	if town.is_built("smithy"):
		smoke.append(TownArt.BUILDING_FEET["smithy"] + TownArt.SMITHY_SMOKE[mini(town.level("smithy"), 2)])
	art = TownArt.paint_town(_world, smoke)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(stage)
	for id: String in town.buildings:
		var feet: Vector2 = TownArt.BUILDING_FEET[id]
		var place := TownBuilding.new(id, town.level(id))
		place.position = feet - Vector2(place.size.x / 2.0, place.size.y)
		place.pressed.connect(_visit.bind(place))
		place.focus_entered.connect(_refresh_signs)
		place.focus_exited.connect(_refresh_signs)
		place.mouse_entered.connect(_refresh_signs, CONNECT_DEFERRED)
		place.mouse_exited.connect(_refresh_signs, CONNECT_DEFERRED)
		stage.add_child(place)
		buildings[id] = place
	PadInput.keys_in_use_changed.connect(_refresh_signs)
	var folk_paths: Array = TownArt.FOLK_PATHS
	_world.add_child(TownFolk.new(folk_paths))
	var ambience := WorldAmbience.new()
	ambience.art = art
	_world.add_child(ambience)
	for id: String in town.buildings:
		var sign_board := TownSign.new(id, TownArt.BUILDING_FEET[id], town.job_words(id))
		_world.add_child(sign_board)
		signs[id] = sign_board
	if town.going != null:
		waiting = CharacterFigure.new(town.going.sheet, CharacterFigure.FACING_LEFT)
		waiting.position = TownArt.BUILDING_FEET["portal"] + WAITING_SPOT
		_world.add_child(waiting)
	arrow = KitArrow.new(null, KitArrow.Side.ABOVE)
	_world.add_child(arrow)


func _build_ui(town: TownData) -> void:
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = BAR_MARGIN
	bar.offset_right = -BAR_MARGIN
	bar.offset_top = BAR_MARGIN
	bar.add_theme_constant_override("separation", BAR_GAP)
	_ui.add_child(bar)
	for id in Database.sorted_ids(town.materials):
		if town.materials[id] <= 0:
			continue
		var material := Database.get_material(id)
		var chip := KitChip.new("coin", town.materials[id])
		chip.set_picture(GameArt.material_icon(material))
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		Tips.attach(chip, material.display_name, "Brought home by trips. The town will build with it, or the Shop buys it.")
		bar.add_child(chip)
		material_chips[id] = chip
	date_chip = DateChip.new()
	bar.add_child(date_chip)
	gold_chip = KitChip.new("coin", town.gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(gold_chip)
	Tips.attach(gold_chip, "Gold", "Pays for adventurers, bills and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(_on_back)
	_ui.add_child(back)


## The arrows walk two rows of buildings, each of which wraps. Up from the north row
## reaches Back, and down from Back reaches the south row. Tab goes through them all.
func _link_focus() -> void:
	var rows: Array[Array] = []
	for row: Array[String] in [TownArt.NORTH_ROW, TownArt.SOUTH_ROW]:
		var places: Array[Control] = []
		for id in row:
			places.append(buildings[id])
		rows.append(places)
	var north: Array = rows[0]
	var south: Array = rows[1]
	var every: Array = south + north
	for places: Array in rows:
		for index in places.size():
			var place: Control = places[index]
			place.focus_neighbor_left = place.get_path_to(places[index - 1])
			place.focus_neighbor_right = place.get_path_to(places[(index + 1) % places.size()])
	for place: Control in north:
		place.focus_neighbor_top = place.get_path_to(back)
		place.focus_neighbor_bottom = place.get_path_to(_nearest(place, south))
	for place: Control in south:
		place.focus_neighbor_top = place.get_path_to(_nearest(place, north))
		place.focus_neighbor_bottom = place.get_path_to(place)
	for index in every.size():
		var place: Control = every[index]
		place.focus_next = place.get_path_to(every[(index + 1) % every.size()])
		place.focus_previous = place.get_path_to(every[index - 1])
	back.focus_neighbor_top = back.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(back)
	for way: StringName in [&"focus_neighbor_bottom", &"focus_neighbor_right"]:
		back.set(way, back.get_path_to(south[0]))


# The one of `places` whose middle is nearest `place`'s, side to side.
func _nearest(place: Control, places: Array) -> Control:
	var best: Control = places[0]
	var middle := place.position.x + place.size.x / 2.0
	for other: Control in places:
		if absf(other.position.x + other.size.x / 2.0 - middle) < absf(best.position.x + best.size.x / 2.0 - middle):
			best = other
	return best


func _refresh_signs() -> void:
	for id: String in buildings:
		signs[id].show_job(buildings[id].is_lit())


func _visit(place: TownBuilding) -> void:
	var rooms := {"tavern": TAVERN, "bank": BANK, "portal": PORTAL, "shop": SHOP, "castle": CASTLE}
	if place.id == "academy" and TownData.current().is_built("academy"):
		Screens.go(ACADEMY)
	elif rooms.has(place.id):
		Screens.go(rooms[place.id])
	else:
		CastleScreen.open_on = place.id
		Screens.go(CASTLE)


func _on_back() -> void:
	Screens.go(MENU)
