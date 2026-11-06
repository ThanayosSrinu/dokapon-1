class_name TownScreen
extends Control
## The town. The player points at a building to read its sign, and visits it by
## clicking it or pressing Accept. Only buildings in TownData.BUILDINGS can be visited.

const MENU := "res://ui/menu/MainMenu.tscn"
const SOON_WIDTH := 420.0
## How far the resources stand from the screen's edge. Back has the other corner.
const BAR_MARGIN := 24.0

var back: KitBackButton
var art: TownArt
var gold_chip: KitChip
var arrow: KitArrow
## Building id -> its TownBuilding.
var buildings := {}
## Building id -> its TownSign.
var signs := {}

var _world: Node2D
var _ui: Control
var _page: KitPage


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_build_world(town)
	_build_ui(town)
	_link_focus()
	buildings[town.next_step()].grab_focus()
	Sound.music("hometown")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_world.position = Kit.snap_point(get_viewport_rect().size / 2.0)


func building(id: String) -> TownBuilding:
	return buildings[id]


## The window that is open, if any.
func page() -> KitPage:
	return _page


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
	arrow = KitArrow.new(buildings[town.next_step()], KitArrow.Side.ABOVE)
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
	_ui.add_child(bar)
	gold_chip = KitChip.new("coin", town.gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(gold_chip)
	Tips.attach(gold_chip, "Gold", "Pays for adventurers and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(func() -> void: Screens.go(MENU))
	_ui.add_child(back)


## The arrows always reach the buildings, in a row that wraps, and Back from above.
func _link_focus() -> void:
	var places: Array[TownBuilding] = []
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
	# E3 and E4 replace this window with the Tavern and the Portal.
	_page = KitPage.new(place.text)
	var words := Kit.text("Its doors open in the next part of the build.", SOON_WIDTH)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.panel.body.add_child(words)
	_page.closed.connect(_on_page_closed.bind(place))
	_ui.add_child(_page)
	back.hide()
	_set_buildings_focusable(false)
	_page.open()


func _on_page_closed(place: TownBuilding) -> void:
	_page.queue_free()
	_page = null
	back.show()
	_set_buildings_focusable(true)
	place.grab_focus()


func _set_buildings_focusable(able: bool) -> void:
	for id: String in buildings:
		buildings[id].focus_mode = Control.FOCUS_ALL if able else Control.FOCUS_NONE
