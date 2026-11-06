class_name TownScreen
extends Control
## The town. The player points at a building to read its sign, and visits it by
## clicking it or pressing Accept. Only buildings in TownData.BUILDINGS can be visited.

const MENU := "res://ui/menu/MainMenu.tscn"
const TAVERN := "res://tavern/TavernScreen.tscn"
const PORTAL := "res://portal/PortalScreen.tscn"
const BANK := "res://bank/BankScreen.tscn"
const GAME_OVER := "res://town/GameOverScreen.tscn"
## How far the resources stand from the screen's edge. Back has the other corner.
const BAR_MARGIN := 24.0
## Where a hired adventurer waits, from the Portal's feet.
const WAITING_SPOT := Vector2(124, -36)
const BAR_GAP := 8
const REST_TOP := 80.0
## What the Bank's sign says while something falls due soon.
const BANK_MARK := "Pay by Day %d"

var back: KitBackButton
var art: TownArt
var gold_chip: KitChip
var date_chip: DateChip
var rest_button: KitButton
## Asks how long to rest.
var rest_panel: RestPanel
var arrow: KitArrow
## Who goes next, waiting by the Portal, if there is one.
var waiting: CharacterFigure
## Building id -> its TownBuilding.
var buildings := {}
## Building id -> its TownSign.
var signs := {}

var _world: Node2D
var _ui: Control
var _dim: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_build_world(town)
	_build_ui(town)
	_link_focus()
	_refresh(town, false)
	arrow.target.grab_focus()
	Sound.music("hometown")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_world.position = Kit.snap_point(get_viewport_rect().size / 2.0)


func building(id: String) -> TownBuilding:
	return buildings[id]


# The numbers, the Bank's sign and the arrow, as the town stands now.
func _refresh(town: TownData, roll := true) -> void:
	gold_chip.set_amount(town.gold, roll)
	date_chip.show_day(town, town.day)
	var level := date_chip.level
	var words := BANK_MARK % town.next_due() if level != TownData.Alert.NONE else ""
	signs["bank"].mark(words, level)
	var step := town.next_step()
	arrow.target = rest_button if step == "rest" else buildings[step]


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
	date_chip = DateChip.new()
	bar.add_child(date_chip)
	gold_chip = KitChip.new("coin", town.gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(gold_chip)
	Tips.attach(gold_chip, "Gold", "Pays for adventurers, bills and upgrades.")
	_build_rest()
	back = KitBackButton.new()
	back.pressed.connect(_on_back)
	_ui.add_child(back)


func _build_rest() -> void:
	rest_button = KitButton.new()
	rest_button.kind = KitButton.Kind.SMALL
	rest_button.icon = Kit.icon("moon")
	rest_button.text = "Rest"
	rest_button.pressed.connect(_open_rest)
	_ui.add_child(rest_button)
	rest_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rest_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	rest_button.offset_left -= BAR_MARGIN
	rest_button.offset_right -= BAR_MARGIN
	rest_button.offset_top += REST_TOP
	rest_button.offset_bottom += REST_TOP
	Tips.attach(rest_button, "Rest", "Let days pass, so that the hurt can heal. The next bill comes closer.")
	_dim = ColorRect.new()
	_dim.color = Kit.DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	_ui.add_child(_dim)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(holder)
	rest_panel = RestPanel.new()
	rest_panel.rest_chosen.connect(_on_rest)
	rest_panel.closed.connect(_close_rest)
	rest_panel.hide()
	holder.add_child(rest_panel)


## The arrows always reach the buildings, in a row that wraps, and Back from above.
func _link_focus() -> void:
	var places: Array[Control] = []
	for id: String in buildings:
		places.append(buildings[id])
	places.append(rest_button)
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
	Screens.go({"tavern": TAVERN, "bank": BANK, "portal": PORTAL}[place.id])


func _on_back() -> void:
	if rest_panel.visible:
		_close_rest()
	else:
		Screens.go(MENU)


func _open_rest() -> void:
	rest_panel.show_town(TownData.current())
	_dim.show()
	rest_panel.show()
	rest_panel.play_open()
	rest_panel.day_buttons[0].grab_focus()


func _close_rest() -> void:
	rest_panel.hide()
	_dim.hide()
	arrow.target.grab_focus()


func _on_rest(days: int) -> void:
	var town := TownData.current()
	town.rest(days)
	if not town.overdue().is_empty():
		Screens.go(GAME_OVER)
		return
	_refresh(town)
	rest_panel.show_town(town)
	_show_waiting(town)


# Someone healed may now stand by the Portal.
func _show_waiting(town: TownData) -> void:
	if town.going == null or waiting != null:
		return
	waiting = CharacterFigure.new(town.going.sheet, CharacterFigure.FACING_LEFT)
	waiting.position = TownArt.BUILDING_FEET["portal"] + WAITING_SPOT
	_world.add_child(waiting)
