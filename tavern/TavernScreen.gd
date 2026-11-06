class_name TavernScreen
extends Control
## The Tavern. Two tabs: Recruit shows strangers looking for work, and Roster shows your
## own people. People stand in the room, and pointing at one fills the card, which never
## moves. The rules are in TownData: this only asks and redraws.

enum Tab { RECRUIT, ROSTER }

const TOWN := "res://town/TownScreen.tscn"
const GAME_OVER := "res://town/GameOverScreen.tscn"
## The part of the window that a 1280 by 720 layout uses. A larger window centers it.
const STAGE := Vector2(1280, 720)
const GUEST_FEET_Y := 440.0
const GUEST_X: Array[float] = [190.0, 388.0, 586.0]
const CARD_LEFT := 816.0
const CARD_TOP := 80.0
## The tabs sit on top of the card.
const TABS_SPOT := Vector2(816, 24)
const DISMISS_WIDTH := 460.0
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
const FULL := "Your roster is full"
const OURS := "Your people, %d of %d"
## The headings when nobody on the roster can go.
const NOBODY_READY := "Nobody can go. Hire someone new"
const NOBODY_READY_FULL := "Nobody can go. Dismiss someone"
## What someone who can't work says.
const DOWN_LINE := "Ugh... I need %s more."
const DISMISS_HEADING := "Dismiss %s?"
const DISMISS_WORDS := "They leave your roster, and their wage of %d gold comes off the next bill. The joining fee is not paid back."
const DISMISS_LOST := "Nobody else could go, and you could not hire anyone. It is GAME OVER."

var back: KitBackButton
var card: TavernCard
var bubble: TavernBubble
var gold_chip: KitChip
var arrow: KitArrow
var heading: Label
var guests: Array[TavernGuest] = []
## Whoever the card is showing.
var chosen: TavernGuest
var tab := Tab.RECRUIT
var recruit_tab: KitButton
var roster_tab: KitButton
## Asks before someone is dismissed.
var dismiss_panel: KitPanel
var keep_button: KitButton
var dismiss_button: KitButton

var _stage: Node2D
var _people: Control
var _leaving := false
var _dim: ColorRect
var _dismiss_words: Label
var _dismiss_lost: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	_stage.add_child(TavernRoom.new())
	_people = Control.new()
	_people.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_people)
	bubble = TavernBubble.new()
	_stage.add_child(bubble)
	_build_card()
	_build_top_bar(town)
	_build_dismiss_panel()
	arrow = KitArrow.new(null, KitArrow.Side.LEFT)
	add_child(arrow)
	Sound.music("shop")
	_show_tab(Tab.ROSTER if _strangers(town).is_empty() else Tab.RECRUIT)
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


# Whoever could still be hired.
func _strangers(town: TownData) -> Array[Adventurer]:
	var found: Array[Adventurer] = []
	for person in Database.adventurers_by_fee():
		if town.member(person) == null:
			found.append(person)
	return found


# Fills the room with the people of `new_tab`, and points at the first.
func _show_tab(new_tab: Tab) -> void:
	var town := TownData.current()
	tab = new_tab
	chosen = null
	guests.clear()
	for child in _people.get_children():
		_people.remove_child(child)
		child.queue_free()
	if tab == Tab.RECRUIT:
		_fill_recruits(town)
	else:
		_fill_roster(town)
	_refresh_tabs(town)
	_refresh_heading(town)
	_link_focus()
	_choose(guests[0])
	guests[0].grab_focus()


func _fill_recruits(town: TownData) -> void:
	var people := Database.adventurers_by_fee()
	for index in people.size():
		# Whoever has been hired leaves a gap: the others keep their places.
		if town.member(people[index]) == null:
			_add_guest(people[index], index)


func _fill_roster(town: TownData) -> void:
	for index in town.roster.size():
		var one := _add_guest(town.roster[index].person, index)
		if not town.roster[index].is_ready(town.day):
			one.lie_down()


func _add_guest(person: Adventurer, place: int) -> TavernGuest:
	var one := TavernGuest.new(person)
	one.position = Vector2(GUEST_X[place], GUEST_FEET_Y) - TavernGuest.FEET
	one.focus_entered.connect(_choose.bind(one))
	one.pressed.connect(_on_guest_pressed)
	_people.add_child(one)
	guests.append(one)
	return one


func _refresh_tabs(town: TownData) -> void:
	recruit_tab.lit = tab == Tab.RECRUIT
	roster_tab.lit = tab == Tab.ROSTER
	recruit_tab.block("Everyone here works for you." if _strangers(town).is_empty() else "")
	roster_tab.block("Nobody works for you yet." if town.roster.is_empty() else "")


func _build_card() -> void:
	card = TavernCard.new()
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	card.hire.pressed.connect(_on_main_button)
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
	var row := HBoxContainer.new()
	row.position = TABS_SPOT
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	recruit_tab = _add_tab(row, "Recruit", Tab.RECRUIT)
	roster_tab = _add_tab(row, "Roster", Tab.ROSTER)
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
	Tips.attach(gold_chip, "Gold", "Pays for adventurers, bills and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(_on_back)
	add_child(back)


func _add_tab(row: Container, words: String, which: Tab) -> KitButton:
	var button := KitButton.new()
	button.kind = KitButton.Kind.SMALL
	button.text = words
	button.pressed.connect(func() -> void:
			if tab != which and not _leaving:
				_show_tab(which))
	row.add_child(button)
	return button


func _build_dismiss_panel() -> void:
	_dim = ColorRect.new()
	_dim.color = Kit.DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	add_child(_dim)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	dismiss_panel = KitPanel.new(" ", true)
	dismiss_panel.title.add_theme_color_override("font_color", Kit.BLOOD)
	dismiss_panel.custom_minimum_size.x = DISMISS_WIDTH
	_dismiss_words = Kit.text("", DISMISS_WIDTH - 32.0, &"PaperLabel")
	_dismiss_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dismiss_panel.body.add_child(_dismiss_words)
	_dismiss_lost = Kit.text(DISMISS_LOST, DISMISS_WIDTH - 32.0, &"PaperLabel")
	_dismiss_lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dismiss_lost.add_theme_color_override("font_color", Kit.BLOOD)
	dismiss_panel.body.add_child(_dismiss_lost)
	keep_button = KitButton.new()
	keep_button.pressed.connect(_close_dismiss)
	dismiss_panel.body.add_child(keep_button)
	dismiss_button = KitButton.new()
	dismiss_button.kind = KitButton.Kind.SMALL
	dismiss_button.danger = true
	dismiss_button.pressed.connect(_on_dismiss)
	dismiss_panel.body.add_child(dismiss_button)
	holder.add_child(dismiss_panel)
	dismiss_panel.hide()
	keep_button.focus_neighbor_bottom = keep_button.get_path_to(dismiss_button)
	dismiss_button.focus_neighbor_top = dismiss_button.get_path_to(keep_button)
	for part: Control in [keep_button, dismiss_button]:
		for way: StringName in [&"focus_neighbor_left", &"focus_neighbor_right"]:
			part.set(way, part.get_path_to(part))
	keep_button.focus_neighbor_top = keep_button.get_path_to(keep_button)
	dismiss_button.focus_neighbor_bottom = dismiss_button.get_path_to(dismiss_button)


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
	back.focus_neighbor_bottom = back.get_path_to(guests[0])
	back.focus_neighbor_right = back.get_path_to(recruit_tab)
	recruit_tab.focus_neighbor_left = recruit_tab.get_path_to(back)
	recruit_tab.focus_neighbor_right = recruit_tab.get_path_to(roster_tab)
	roster_tab.focus_neighbor_left = roster_tab.get_path_to(recruit_tab)
	roster_tab.focus_neighbor_right = roster_tab.get_path_to(roster_tab)
	for part: KitButton in [recruit_tab, roster_tab]:
		part.focus_neighbor_top = part.get_path_to(part)
		part.focus_neighbor_bottom = part.get_path_to(guests[0])


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
	if tab == Tab.RECRUIT:
		card.show_recruit(one.adventurer)
	else:
		card.show_member(TownData.current().member(one.adventurer), TownData.current().day)
	_say(one, _line_of(one))
	_aim_at_chosen()
	_refresh_hire()


func _line_of(one: TavernGuest) -> String:
	if not one.is_down():
		return one.next_line()
	var town := TownData.current()
	return DOWN_LINE % TownData.days_words(town.member(one.adventurer).days_out(town.day))


func _refresh_hire() -> void:
	var town := TownData.current()
	var person := chosen.adventurer
	var hire := card.hire
	if tab == Tab.ROSTER:
		hire.kind = KitButton.Kind.NORMAL
		hire.danger = true
		hire.icon = null
		hire.text = "Dismiss %s" % person.display_name
		hire.block("")
		_point_on_roster(town)
		return
	hire.kind = KitButton.Kind.PRIMARY
	hire.danger = false
	var problem := town.hire_problem(person)
	hire.text = problem if problem != "" else "Hire %s" % person.display_name
	if problem == "":
		hire.block("")
	elif town.roster.size() >= TownData.ROSTER_ROOM:
		hire.block("You keep %d people at most. Dismiss someone first." % TownData.ROSTER_ROOM)
	else:
		hire.block("You have %d gold, and %s asks for %d." % [town.gold, person.display_name, person.fee])
	_point_at(null if hire.disabled else hire, KitArrow.Side.LEFT)


# With nobody able to go, the way forward is a new face, or a free place for one.
func _point_on_roster(town: TownData) -> void:
	if town.going != null:
		_point_at(back, KitArrow.Side.RIGHT)
	elif town.roster.size() >= TownData.ROSTER_ROOM:
		_point_at(card.hire, KitArrow.Side.LEFT)
	else:
		_point_at(recruit_tab, KitArrow.Side.LEFT)


func _say(one: TavernGuest, words: String) -> void:
	bubble.say(words, one.head(), Rect2(ROOM_AREA.position + _stage.position, ROOM_AREA.size))


func _refresh_heading(town: TownData) -> void:
	if town.going == null and not town.roster.is_empty():
		heading.text = NOBODY_READY_FULL if town.roster.size() >= TownData.ROSTER_ROOM else NOBODY_READY
	elif tab == Tab.ROSTER:
		heading.text = OURS % [town.roster.size(), TownData.ROSTER_ROOM]
	else:
		heading.text = FULL if town.roster.size() >= TownData.ROSTER_ROOM else ASK


func _point_at(target: Control, side: KitArrow.Side) -> void:
	arrow.target = target
	arrow.side = side
	arrow.rotation = KitArrow.TURNS[side]


func _on_guest_pressed() -> void:
	card.hire.grab_focus()


func _on_main_button() -> void:
	if tab == Tab.RECRUIT:
		_on_hire()
	else:
		_open_dismiss()


func _open_dismiss() -> void:
	var person := chosen.adventurer
	dismiss_panel.title.text = DISMISS_HEADING % person.display_name
	_dismiss_words.text = DISMISS_WORDS % person.wage
	_dismiss_lost.visible = TownData.current().dismiss_strands(person)
	keep_button.text = "Keep %s" % person.display_name
	dismiss_button.text = "Dismiss %s" % person.display_name
	_dim.show()
	dismiss_panel.show()
	dismiss_panel.play_open()
	keep_button.grab_focus()


func _close_dismiss() -> void:
	dismiss_panel.hide()
	_dim.hide()
	card.hire.grab_focus()


func _on_dismiss() -> void:
	var town := TownData.current()
	town.dismiss(chosen.adventurer)
	dismiss_panel.hide()
	_dim.hide()
	bubble.hide()
	if town.stranded():
		_leaving = true
		Screens.go(GAME_OVER)
		return
	_show_tab(Tab.RECRUIT if town.going == null else Tab.ROSTER)


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
	_say(one, one.adventurer.hired_line)
	one.greet()
	await get_tree().create_timer(HIRED_PAUSE).timeout
	bubble.hide()
	one.chosen = false
	var door := TavernRoom.DOOR_FEET - TavernGuest.FEET
	var aisle := Vector2(one.position.x, AISLE_Y - TavernGuest.FEET.y)
	await one.walk_away([aisle, Vector2(door.x, aisle.y), door])
	Screens.go(TOWN)


func _on_back() -> void:
	if dismiss_panel.visible:
		_close_dismiss()
	elif not _leaving:
		Screens.go(TOWN)
