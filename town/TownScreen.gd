class_name TownScreen
extends Control
## The town. The player points at a building to read its sign, and visits it by
## clicking it or pressing Accept. Only buildings in TownData.BUILDINGS can be visited.

const MENU := "res://ui/menu/MainMenu.tscn"
const TAVERN := "res://tavern/TavernScreen.tscn"
const PORTAL := "res://portal/PortalScreen.tscn"
const BANK := "res://bank/BankScreen.tscn"
const SHOP := "res://shop/ShopScreen.tscn"
## How far the resources stand from the screen's edge. Back has the other corner.
const BAR_MARGIN := 24.0
## Where a hired adventurer waits, from the Portal's feet.
const WAITING_SPOT := Vector2(124, -36)
const BAR_GAP := 8
## What the Bank's sign says while something falls due soon.
const BANK_MARK := "Pay by %s"

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
	_build_world(town)
	_build_ui(town)
	_link_focus()
	_refresh(town)
	arrow.target.grab_focus()
	Sound.music("hometown")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_world.position = Kit.snap_point(get_viewport_rect().size / 2.0)


func building(id: String) -> TownBuilding:
	return buildings[id]


# The numbers, the Bank's sign and the arrow, as the town stands now.
func _refresh(town: TownData) -> void:
	gold_chip.set_amount(town.gold, false)
	date_chip.show_day(town, town.day)
	var level := date_chip.level
	var words := BANK_MARK % Calendar.date(town.next_due()) if level != TownData.Alert.NONE else ""
	signs["bank"].mark(words, level)
	arrow.target = buildings[town.next_step()]


func _build_world(town: TownData) -> void:
	_world = Node2D.new()
	_world.position = Kit.snap_point(get_viewport_rect().size / 2.0)
	add_child(_world)
	art = TownArt.paint_town(_world)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(stage)
	for id: String in town.buildings:
		var feet: Vector2 = TownArt.BUILDING_FEET[id]
		var place := TownBuilding.new(id)
		place.position = feet - Vector2(place.size.x / 2.0, place.size.y)
		place.pressed.connect(_visit.bind(place))
		place.focus_entered.connect(_refresh_signs)
		place.focus_exited.connect(_refresh_signs)
		stage.add_child(place)
		buildings[id] = place
	var folk_paths: Array = TownArt.FOLK_PATHS
	_world.add_child(TownFolk.new(folk_paths))
	var ambience := WorldAmbience.new()
	ambience.art = art
	_world.add_child(ambience)
	for id: String in town.buildings:
		var sign_board := TownSign.new(id, TownArt.BUILDING_FEET[id])
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


## The arrows always reach the buildings, in a row that wraps, and Back from above.
func _link_focus() -> void:
	var places: Array[Control] = []
	for id: String in buildings:
		places.append(buildings[id])
	for index in places.size():
		var place := places[index]
		var before := places[index - 1]
		var after := places[(index + 1) % places.size()]
		place.focus_neighbor_left = place.get_path_to(before)
		place.focus_neighbor_right = place.get_path_to(after)
		place.focus_neighbor_top = place.get_path_to(back)
		place.focus_neighbor_bottom = place.get_path_to(place)
		place.focus_next = place.get_path_to(after)
		place.focus_previous = place.get_path_to(before)
	back.focus_neighbor_top = back.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(back)
	for way: StringName in [&"focus_neighbor_bottom", &"focus_neighbor_right"]:
		back.set(way, back.get_path_to(places[0]))


func _refresh_signs() -> void:
	for id: String in buildings:
		signs[id].show_job(buildings[id].has_focus())


func _visit(place: TownBuilding) -> void:
	Screens.go({"tavern": TAVERN, "bank": BANK, "portal": PORTAL, "shop": SHOP}[place.id])


func _on_back() -> void:
	Screens.go(MENU)
