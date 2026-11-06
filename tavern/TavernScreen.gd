class_name TavernScreen
extends Control
## The Tavern. People stand in the room, and pointing at one fills the card, which never
## moves. The rules for hiring are in TownData: this only asks and redraws.

const TOWN := "res://town/TownScreen.tscn"
## The part of the window that a 1280 by 720 layout uses. A larger window centers it.
const STAGE := Vector2(1280, 720)
const GUEST_FEET_Y := 440.0
const GUEST_X: Array[float] = [190.0, 388.0, 586.0]
const CARD_LEFT := 816.0
const CARD_TOP := 92.0
## The room's part of the stage. Speech bubbles stay inside it.
const ROOM_AREA := Rect2(0, 0, 808, 720)
## A hired adventurer heads up the room, across, and out of the door.
const AISLE_Y := 310.0
const HEADING_SPOT := Vector2(200, 30)
const HEADING_WIDTH := 608.0
## How long someone stays to say their line after being hired.
const HIRED_PAUSE := 0.8
const BAR_MARGIN := 24.0
const ASK := "Who will you hire?"
const WAITING := "%s is waiting at the Portal"

var back: KitBackButton
var card: TavernCard
var bubble: TavernBubble
var gold_chip: KitChip
var arrow: KitArrow
var heading: Label
var guests: Array[TavernGuest] = []
## Whoever the card is showing.
var chosen: TavernGuest

var _stage: Node2D
var _people: Control
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	_stage.add_child(TavernRoom.new())
	_build_guests(town)
	_build_card()
	_build_top_bar(town)
	arrow = KitArrow.new(null, KitArrow.Side.LEFT)
	add_child(arrow)
	_link_focus()
	Sound.music("shop")
	_choose(guests[0])
	guests[0].grab_focus()
	_refresh_heading(town)
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_stage.position = _stage_corner()


func guest(id: String) -> TavernGuest:
	for one in guests:
		if one.adventurer.id == id:
			return one
	return null


func _stage_corner() -> Vector2:
	return Kit.snap_point(((get_viewport_rect().size - STAGE) / 2.0).max(Vector2.ZERO))


func _build_guests(town: TownData) -> void:
	_people = Control.new()
	_people.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_people)
	var people := Database.adventurers_by_fee()
	for index in people.size():
		# Whoever has been hired leaves a gap: the others keep their places.
		if people[index] == town.hired:
			continue
		var one := TavernGuest.new(people[index])
		one.position = Vector2(GUEST_X[index], GUEST_FEET_Y) - TavernGuest.FEET
		one.focus_entered.connect(_choose.bind(one))
		one.pressed.connect(_on_guest_pressed)
		_people.add_child(one)
		guests.append(one)
	bubble = TavernBubble.new()
	_stage.add_child(bubble)


func _build_card() -> void:
	card = TavernCard.new()
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	card.hire.pressed.connect(_on_hire)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(card)


func _build_top_bar(town: TownData) -> void:
	heading = Kit.text("", 0.0, &"Heading")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = HEADING_SPOT
	heading.size = Vector2(HEADING_WIDTH, 0)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(heading)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = BAR_MARGIN
	bar.offset_right = -BAR_MARGIN
	bar.offset_top = BAR_MARGIN
	add_child(bar)
	gold_chip = KitChip.new("coin", town.gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(gold_chip)
	Tips.attach(gold_chip, "Gold", "Pays for adventurers and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(_leave)
	add_child(back)


## Left and right walk along the people. Down reaches Hire, and up from Hire goes
## through the details, for reading their tips, and back to the people.
func _link_focus() -> void:
	var hire := card.hire
	for index in guests.size():
		var one := guests[index]
		var before := guests[index - 1]
		var after := guests[(index + 1) % guests.size()]
		one.focus_neighbor_left = one.get_path_to(before)
		one.focus_neighbor_right = one.get_path_to(after)
		one.focus_neighbor_top = one.get_path_to(back)
		one.focus_neighbor_bottom = one.get_path_to(hire)
		one.focus_next = one.get_path_to(after)
		one.focus_previous = one.get_path_to(before)
	var chain: Array[Control] = [hire]
	var details := card.details()
	details.reverse()
	chain.append_array(details)
	for index in range(chain.size() - 1):
		chain[index].focus_neighbor_top = chain[index].get_path_to(chain[index + 1])
		chain[index + 1].focus_neighbor_bottom = chain[index + 1].get_path_to(chain[index])
	hire.focus_neighbor_bottom = hire.get_path_to(hire)
	back.focus_neighbor_top = back.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(back)
	for way: StringName in [&"focus_neighbor_bottom", &"focus_neighbor_right"]:
		back.set(way, back.get_path_to(guests[0]))


## From Hire and the details, every other way leads back to whoever is chosen.
func _aim_at_chosen() -> void:
	var parts := card.details()
	parts.append(card.hire)
	for part in parts:
		part.focus_neighbor_left = part.get_path_to(chosen)
		part.focus_neighbor_right = part.get_path_to(part)
	var top: Control = parts[0]
	top.focus_neighbor_top = top.get_path_to(chosen)


func _choose(one: TavernGuest) -> void:
	if one == chosen or _leaving:
		return
	if chosen != null:
		chosen.chosen = false
	chosen = one
	one.chosen = true
	one.greet()
	card.show_adventurer(one.adventurer)
	_say(one, one.next_line())
	_aim_at_chosen()
	_refresh_hire()


func _refresh_hire() -> void:
	var town := TownData.current()
	var person := chosen.adventurer
	var problem := town.hire_problem(person)
	var hire := card.hire
	hire.text = problem if problem != "" else "Hire %s" % person.display_name
	if town.hired != null:
		hire.block("You have one adventurer at a time, and %s has the job." % town.hired.display_name)
	elif problem != "":
		hire.block("You have %d gold, and %s asks for %d." % [town.gold, person.display_name, person.fee])
	else:
		hire.block("")
	if town.hired != null:
		_point_at(back, KitArrow.Side.RIGHT)
	else:
		_point_at(null if hire.disabled else hire, KitArrow.Side.LEFT)


func _say(one: TavernGuest, words: String) -> void:
	bubble.say(words, one.head(), Rect2(ROOM_AREA.position + _stage.position, ROOM_AREA.size))


func _refresh_heading(town: TownData) -> void:
	heading.text = WAITING % town.hired.display_name if town.hired != null else ASK


func _point_at(target: Control, side: KitArrow.Side) -> void:
	arrow.target = target
	arrow.side = side
	arrow.rotation = KitArrow.TURNS[side]


func _on_guest_pressed() -> void:
	card.hire.grab_focus()


func _on_hire() -> void:
	var town := TownData.current()
	var one := chosen
	if not town.hire(one.adventurer):
		card.hire.deny()
		return
	_leaving = true
	gold_chip.set_amount(town.gold)
	back.hide()
	arrow.target = null
	card.hire.text = "Hired!"
	card.hire.icon = Kit.icon("check")
	# Stays gold: this is good news, not a button that can't be used.
	card.hire.forced_look = KitButton.Look.REST
	card.hire.disabled = true
	card.hire.release_focus()
	for other in guests:
		other.focus_mode = Control.FOCUS_NONE
		other.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_heading(town)
	_say(one, one.adventurer.hired_line)
	one.greet()
	await get_tree().create_timer(HIRED_PAUSE).timeout
	bubble.hide()
	one.chosen = false
	var door := TavernRoom.DOOR_FEET - TavernGuest.FEET
	var aisle := Vector2(one.position.x, AISLE_Y - TavernGuest.FEET.y)
	await one.walk_away([aisle, Vector2(door.x, aisle.y), door])
	Screens.go(TOWN)


func _leave() -> void:
	if not _leaving:
		Screens.go(TOWN)
