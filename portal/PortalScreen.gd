class_name PortalScreen
extends Control
## The Portal. The adventurer waits on the road, the card says where they are going and
## what they carry, and one button sends them off.

const TOWN := "res://town/TownScreen.tscn"
const EXPEDITION := "res://expedition/ExpeditionScreen.tscn"
## The part of the window that a 1280 by 720 layout uses. A larger window centers it.
const STAGE := Vector2(1280, 720)
const CARD_LEFT := 816.0
const CARD_TOP := 48.0
## Speech bubbles stay inside the hilltop's part of the stage.
const SITE_AREA := Rect2(0, 0, 808, 720)
const HEADING_SPOT := Vector2(200, 30)
const HEADING_WIDTH := 608.0
const READY := "%s is ready to go"
const NOBODY := "Nobody is here yet"
const GOING := "Good luck, %s!"

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

var _stage: Node2D
var _leaving := false
var _shaking := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
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
	if town.hired != null:
		hero = CharacterFigure.new(town.hired.sheet, CharacterFigure.FACING_UP)
		hero.position = HERO_SPOT
		_stage.add_child(hero)


func _build_card(town: TownData) -> void:
	card = PortalCard.new()
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	card.show_stage(town.stage)
	card.show_person(town.stage, town.hired)
	card.enter.pressed.connect(_on_enter)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(card)
	Tips.attach(card.food, "Food", _food_tip(town))


## Says where the food comes from, because that is what the player can change.
func _food_tip(town: TownData) -> String:
	var stage := town.stage
	var words := "One roll of the die is one day. %s gives %d days of food." % [stage.display_name, stage.food_days]
	if town.hired != null and town.hired.bonus_food > 0:
		words += " %s brings %d more." % [town.hired.display_name, town.hired.bonus_food]
	return words


func _build_top_bar(town: TownData) -> void:
	heading = Kit.text(NOBODY if town.hired == null else READY % town.hired.display_name, 0.0, &"Heading")
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


## Up from the button reads the food, and every way out of the card reaches Back.
func _link_focus() -> void:
	var enter := card.enter
	var food := card.food
	enter.focus_neighbor_top = enter.get_path_to(food)
	enter.focus_neighbor_bottom = enter.get_path_to(enter)
	food.focus_neighbor_bottom = food.get_path_to(enter)
	food.focus_neighbor_top = food.get_path_to(back)
	for part: Control in [enter, food]:
		part.focus_neighbor_left = part.get_path_to(back)
		part.focus_neighbor_right = part.get_path_to(part)
	back.focus_neighbor_top = back.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(back)
	for way: StringName in [&"focus_neighbor_bottom", &"focus_neighbor_right"]:
		back.set(way, back.get_path_to(enter))


func _refresh_enter(town: TownData) -> void:
	var enter := card.enter
	var problem := town.send_problem()
	enter.text = "Enter the Portal" if problem == "" else problem
	enter.block("" if problem == "" else "Nobody works for you yet. Hire an adventurer at the Tavern.")
	if problem == "":
		enter.grab_focus()
		arrow.target = enter
	else:
		# The way forward is back through the town, to the Tavern.
		back.grab_focus()
		arrow.target = back
		arrow.side = KitArrow.Side.RIGHT
		arrow.rotation = KitArrow.TURNS[arrow.side]


func _on_enter() -> void:
	var town := TownData.current()
	if town.send_problem() != "" or _leaving:
		card.enter.deny()
		return
	_leaving = true
	back.hide()
	arrow.target = null
	Tips.close()
	card.enter.release_focus()
	card.enter.focus_mode = Control.FOCUS_NONE
	card.food.focus_mode = Control.FOCUS_NONE
	card.enter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.text = GOING % town.hired.display_name
	_clear_the_card()
	bubble.say(town.hired.send_line, hero.global_position + HERO_HEAD, _site_area())
	hero.act(_greeting(town.hired))
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
	if not _leaving:
		Screens.go(TOWN)
