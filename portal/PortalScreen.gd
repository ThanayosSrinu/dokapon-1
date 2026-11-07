class_name PortalScreen
extends Control
## The Portal. The adventurer waits on the road, the card says where they are going and
## what they carry, and one button sends them off.

const TOWN := "res://town/TownScreen.tscn"
const BANK := "res://bank/BankScreen.tscn"
const EXPEDITION := "res://expedition/ExpeditionScreen.tscn"
## The part of the window that a 1280 by 720 layout uses. A larger window centers it.
const STAGE := Vector2(1280, 720)
const CARD_LEFT := 816.0
const CARD_TOP := 34.0
## What the forecast's colors mean, readable on paper.
const FIT_COLORS := {TownData.Forecast.SAFE: Color(0.1, 0.4, 0.16), TownData.Forecast.LATE: Kit.BLOOD}
const FIT_WORDS := {TownData.Forecast.SAFE: "Home in time to pay what is owed.",
		TownData.Forecast.LATE: "Home after the next due day: pay at the Bank first."}
## Speech bubbles stay inside the hilltop's part of the stage.
const SITE_AREA := Rect2(0, 0, 808, 720)
const HEADING_SPOT := Vector2(200, 30)
const HEADING_WIDTH := 608.0
const READY := "%s is ready to go"
const NOBODY := "Nobody is here yet"
const NOT_READY := "Nobody is ready"
const GOING := "Good luck, %s!"
const NO_FOOD := "No food: they will lose health every day."
const LOW_FOOD := "This food may not last the walk home."
const USUAL_FOOD := "A %s trip takes about %d turns."

const HERO_SPOT := Vector2(404, 610)
## Where they stand when the Portal takes them.
const HERO_GOAL := Vector2(404, 412)
const HERO_HEAD := Vector2(0, -46)
const WALK_SPEED := 120.0
## How long they stay to say their line.
const LINE_SECONDS := 1.0
const CARD_SECONDS := 0.3
const CARD_AWAY := 480.0
const DISSOLVE_SECONDS := 0.6
const CHARGE_SECONDS := 2.2
const BURST_SECONDS := 0.3
const SHAKE := 2.0

var back: KitBackButton
var card: PortalCard
var site: PortalSite
var bubble: TavernBubble
var arrow: KitArrow
var heading: Label
## The adventurer on the road, if there is one.
var hero: CharacterFigure
## Stops the player when the trip may not be home before the next due day.
var warning: TripWarning

var _stage: Node2D
# The sizes of trip on offer, in the same order as the card's buttons.
var _sizes: Array[Stage] = []
# Everyone on the roster, in the same order as the card's buttons.
var _people: Array[Adventurer] = []
var _dim: ColorRect
var _leaving := false
var _shaking := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	town.fill_food()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	site = PortalSite.new()
	_stage.add_child(site)
	_build_hero(town)
	_build_card(town)
	_build_top_bar(town)
	_link_focus()
	arrow = KitArrow.new(null, KitArrow.Side.LEFT)
	add_child(arrow)
	_build_warning()
	_refresh_enter(town)
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	var corner := _stage_corner()
	if _shaking:
		corner += Vector2(randf_range(-SHAKE, SHAKE), randf_range(-SHAKE, SHAKE)).snappedf(Kit.STEP)
	_stage.position = corner


func _stage_corner() -> Vector2:
	return Kit.snap_point(((get_viewport_rect().size - STAGE) / 2.0).max(Vector2.ZERO))


func _build_hero(town: TownData) -> void:
	if hero != null:
		hero.queue_free()
		hero = null
	if town.going != null:
		hero = CharacterFigure.new(town.going.sheet, CharacterFigure.FACING_UP)
		hero.position = HERO_SPOT
		_stage.add_child(hero)


func _build_card(town: TownData) -> void:
	card = PortalCard.new()
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	card.enter.pressed.connect(_on_enter)
	card.food.picked.connect(_choose_food)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(card)
	_build_sizes(town)
	_build_people(town)
	_show_trip(town)


func _build_sizes(town: TownData) -> void:
	_sizes = Database.sizes_of(town.stage.place)
	card.build_sizes(_sizes)
	for index in _sizes.size():
		var stage := _sizes[index]
		card.sizes[index].pressed.connect(_choose_size.bind(stage))


# With only one person there is nothing to pick.
func _build_people(town: TownData) -> void:
	if town.roster.size() < 2:
		return
	var names: Array[String] = []
	for one in town.roster:
		_people.append(one.person)
		names.append(one.person.display_name)
	card.build_people(names)
	for index in _people.size():
		var person := _people[index]
		var button := card.people[index]
		var out: int = town.member(person).days_out(town.day)
		button.pressed.connect(_choose_person.bind(person))
		if out > 0:
			button.text = TownData.days_words(out)
			button.block("%s is down, and can work again in %s." % [person.display_name, TownData.days_words(out)])
		else:
			Tips.attach(button, person.display_name, "Walks up to %d spaces a day." % person.die_top)


## Makes the card show the trip the town has chosen.
func _show_trip(town: TownData) -> void:
	card.show_stage(town.stage)
	card.show_person(town.going, 1 if town.going == null else town.member(town.going).level)
	card.mark_size(_sizes.find(town.stage))
	card.mark_person(_people.find(town.going))
	_show_food(town)


# The food, and the forecasts that follow from it.
func _show_food(town: TownData) -> void:
	var carry := 0 if town.going == null else town.max_food(town.going)
	var afford := 0 if town.going == null else town.food_limit(town.going)
	card.show_food(town.food, carry, afford, town.food_cost(), town.gold, _food_warning(town),
			mini(town.food, town.food_store))
	var guide := USUAL_FOOD % [town.stage.size_name.to_lower(), town.stage.usual_food]
	# Red when they can't carry that much: the Food line above says how much they can.
	var short := town.going != null and carry < town.stage.usual_food
	card.show_food_guide(guide, town.going != null, short)
	Tips.attach(card.food, "Food", _food_tip(town))
	_show_forecasts(town)


func _food_warning(town: TownData) -> String:
	if town.going == null:
		return ""
	if town.food == 0:
		return NO_FOOD
	var map := town.stage.sample_map()
	return LOW_FOOD if town.food < ceili(map.days_around(map.portal, town.going.die_top)) else ""


# Each size says about when it could be back, in the color of how that sits with the due day.
func _show_forecasts(town: TownData) -> void:
	for index in _sizes.size():
		var stage := _sizes[index]
		var words := "A new island each trip, about %d spaces, %d monsters and %d chests." % [stage.spaces, stage.monsters, stage.chests]
		if town.going == null:
			card.show_forecast(index, "", Kit.SOFT_INK)
		else:
			var plan := town.forecast(stage)
			card.show_forecast(index, "Home %s" % Calendar.date(plan["home"]), FIT_COLORS[plan["fit"]])
			words += " It takes %s, even if it is cut short, so they are home %s. %s" % [
					TownData.days_words(stage.days), Calendar.date(plan["home"]), FIT_WORDS[plan["fit"]]]
		Tips.attach(card.sizes[index], "%s trip" % stage.size_name, words)


func _choose_person(person: Adventurer) -> void:
	var town := TownData.current()
	if _leaving or not town.pick(person):
		return
	_build_hero(town)
	heading.text = READY % person.display_name
	town.fill_food()
	_show_trip(town)


func _choose_size(stage: Stage) -> void:
	var town := TownData.current()
	if _leaving or town.stage == stage:
		return
	town.stage = stage
	town.fill_food()
	_show_trip(town)
	card.food.focus_neighbor_top = card.food.get_path_to(_chosen_size_button())


func _choose_food(amount: int) -> void:
	var town := TownData.current()
	if not _leaving:
		town.choose_food(amount)
		_show_food(town)


## Says where the food comes from, because that is what the player can change.
func _food_tip(town: TownData) -> String:
	var words := "One roll of the die is one turn, and a day at camp too. Each costs a day of food, at %d gold a day." % TownData.FOOD_PRICE
	if town.store_room() == 0:
		words += " Leftover food is lost."
	else:
		words += " The Storehouse keeps %s, eaten before any is bought, and keeps what comes home, up to %d days." % [
				TownData.days_words(town.food_store), town.store_room()]
	if town.going != null:
		words += " %s can carry %d, on any trip. Levels and the town's upgrades raise it." % [town.going.display_name, town.max_food(town.going)]
	return words


func _build_top_bar(town: TownData) -> void:
	var words := READY % town.going.display_name if town.going != null else (NOBODY if town.roster.is_empty() else NOT_READY)
	heading = Kit.text(words, 0.0, &"Heading")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = HEADING_SPOT
	heading.size = Vector2(HEADING_WIDTH, 0)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(heading)
	bubble = TavernBubble.new()
	_stage.add_child(bubble)
	back = KitBackButton.new()
	back.pressed.connect(_leave)
	add_child(back)


func _build_warning() -> void:
	_dim = ColorRect.new()
	_dim.color = Kit.DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	add_child(_dim)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	warning = TripWarning.new()
	warning.go_on.connect(_on_go_on)
	warning.to_bank.connect(_go_to_bank)
	warning.hide()
	holder.add_child(warning)


## Up from the button reads the food, the sizes, then the people, and every way out of the
## card reaches Back. Left and right walk along the rows, and slide the food. Below Back is
## Enter.
func _link_focus() -> void:
	var enter := card.enter
	var food := card.food
	var people := card.people
	var sizes := card.sizes
	var above_sizes: Control = back
	if not people.is_empty():
		above_sizes = people[maxi(_people.find(TownData.current().going), 0)]
		for index in people.size():
			var button := people[index]
			button.focus_neighbor_top = button.get_path_to(back)
			button.focus_neighbor_bottom = button.get_path_to(_chosen_size_button())
			button.focus_neighbor_left = button.get_path_to(people[index - 1] if index > 0 else back)
			button.focus_neighbor_right = button.get_path_to(people[mini(index + 1, people.size() - 1)])
	enter.focus_neighbor_top = enter.get_path_to(food)
	enter.focus_neighbor_bottom = enter.get_path_to(enter)
	enter.focus_neighbor_left = enter.get_path_to(back)
	enter.focus_neighbor_right = enter.get_path_to(enter)
	food.focus_neighbor_bottom = food.get_path_to(enter)
	food.focus_neighbor_top = food.get_path_to(_chosen_size_button())
	for index in sizes.size():
		var button := sizes[index]
		button.focus_neighbor_top = button.get_path_to(above_sizes)
		button.focus_neighbor_bottom = button.get_path_to(food)
		button.focus_neighbor_left = button.get_path_to(sizes[index - 1] if index > 0 else back)
		button.focus_neighbor_right = button.get_path_to(sizes[mini(index + 1, sizes.size() - 1)])
	back.focus_neighbor_top = back.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(back)
	back.focus_neighbor_right = back.get_path_to(enter)
	back.focus_neighbor_bottom = back.get_path_to(enter)


func _chosen_size_button() -> KitButton:
	return card.sizes[_sizes.find(TownData.current().stage)]


func _refresh_enter(town: TownData) -> void:
	var enter := card.enter
	var problem := town.send_problem()
	enter.text = "Enter the Portal" if problem == "" else problem
	enter.block("" if problem == "" else _enter_tip(town))
	if problem == "":
		enter.grab_focus()
		arrow.target = enter
	else:
		# The way forward is back through the town, to the Tavern.
		back.grab_focus()
		arrow.target = back
		arrow.side = KitArrow.Side.RIGHT
		arrow.rotation = KitArrow.TURNS[arrow.side]


func _enter_tip(town: TownData) -> String:
	if town.roster.is_empty():
		return "Nobody works for you yet. Hire an adventurer at the Tavern."
	return "Nobody on your roster can work. Hire someone new at the Tavern, and dismiss someone if the roster is full."


func _on_enter() -> void:
	var town := TownData.current()
	if town.send_problem() != "" or _leaving:
		card.enter.deny()
		return
	var plan := town.forecast(town.stage)
	if plan["fit"] == TownData.Forecast.SAFE:
		_depart(town)
	else:
		_open_warning(town, plan)


func _open_warning(town: TownData, plan: Dictionary) -> void:
	Tips.close()
	town.show_alert()
	warning.show_trip(town, town.going, plan)
	_dim.show()
	warning.show()
	warning.play_open()
	# The careful choice has the focus, so that a second press of Enter can't skip this.
	warning.bank_button.grab_focus()


func _close_warning() -> void:
	warning.hide()
	_dim.hide()
	card.enter.grab_focus()


func _on_go_on() -> void:
	warning.hide()
	_dim.hide()
	_depart(TownData.current())


func _depart(town: TownData) -> void:
	_leaving = true
	town.buy_food()
	town.remember_leaving()
	for button in card.people:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.hide()
	arrow.target = null
	Tips.close()
	card.enter.release_focus()
	card.enter.focus_mode = Control.FOCUS_NONE
	card.food.focus_mode = Control.FOCUS_NONE
	card.enter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button in card.sizes:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.text = GOING % town.going.display_name
	_clear_the_card()
	bubble.say(town.going.send_line, hero.global_position + HERO_HEAD, _site_area())
	hero.act(_greeting(town.going))
	await get_tree().create_timer(LINE_SECONDS).timeout
	bubble.hide()
	_charge_up()
	await hero.walk_along([HERO_GOAL], WALK_SPEED)
	_shaking = Settings.screen_shake
	await hero.dissolve(0.0, 1.0, DISSOLVE_SECONDS)
	await get_tree().create_timer(BURST_SECONDS).timeout
	Sound.play("portal_flash")
	Screens.flash_to(EXPEDITION)


## The card slides away, so that nothing is in the way of the Portal.
func _clear_the_card() -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "position:x", CARD_LEFT + CARD_AWAY, CARD_SECONDS)
	tween.tween_property(card, "modulate:a", 0.0, CARD_SECONDS)


func _charge_up() -> void:
	Sound.music("")
	Sound.play("portal_charge")
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(site, "charge", 1.0, CHARGE_SECONDS)


func _greeting(person: Adventurer) -> Array[int]:
	var data := person.class_data()
	var caster := data.base_stats["magic"] > data.base_stats["attack"]
	return CharacterFigure.CAST_FRAMES if caster else CharacterFigure.SWING_FRAMES


func _site_area() -> Rect2:
	return Rect2(SITE_AREA.position + _stage.position, SITE_AREA.size)


func _leave() -> void:
	if warning.visible:
		_close_warning()
	elif not _leaving:
		Screens.go(TOWN)


func _go_to_bank() -> void:
	if not _leaving:
		Screens.go(BANK)
