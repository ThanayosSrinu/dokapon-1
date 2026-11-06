class_name ExpeditionScreen
extends Node2D
## One trip on screen, from the far side of the Portal to the report. The rules stay in
## Expedition.gd: this script runs its steps in order and shows what came back, so the
## same seed gives the same trip as tools/sim_expedition.tscn.
##
## Speed is Engine.time_scale, so the buttons work on everything at once, fights too.
## Anything that must still answer at ×0, such as the kit's buttons, ignores it.

const TOWN := "res://town/TownScreen.tscn"
const BOARD: PackedScene = preload("res://maps/WorldMap.tscn")
const TOKEN: PackedScene = preload("res://player/Player.tscn")

## The speed buttons, in order.
const SPEEDS: Array[float] = [0.0, 1.0, 3.0]
const SPEED_WORDS: Array[String] = ["x0", "x1", "x3"]
const SPEED_FROM_RIGHT := 24.0
const SPEED_TOP := 24.0
const SPEED_GAP := 8
const STRIP_FROM_BOTTOM := 12.0
const NEWS_TOP := 24.0
const NEWS_WIDTH := 600.0

## Waits for the light of the flash to thin out.
const APPEAR_DELAY := 0.5
const APPEAR_SECONDS := 0.7
const BURST_SECONDS := 1.4
const BURST_REACH := Vector2(140, 90)
## How long their first words stay up.
const LINE_SECONDS := 1.6
const STEP_SECONDS := 0.45
## How long something found stays on screen. A quiet space takes a blink.
const NEWS_SECONDS := 1.0
const QUIET_SECONDS := 0.25
const DISSOLVE_SECONDS := 0.7
const HERO_LAYER := 10
const HEAD := Vector2(0, -46)
const DIE_SIZE := Vector2(144, 144)
const DIE_TOP := 130.0
const TOKEN_RING := Color(1.0, 0.85, 0.42)
const FIGHT_LAYER := 1
const UI_LAYER := 2
const DIM := Color(0.06, 0.05, 0.12, 0.62)
const LEAVE_WIDTH := 460.0
const DEFEAT_DIM := Color(0.3, 0.02, 0.05, 0.6)
const WARP_NAME := "Emergency Warp"
const LEAVE_HEADING := "Abandon the trip?"
const LEAVE_TEXT := "Abandon the trip"
const LEAVE_WORDS := "The Warp Stone saves %s's life and nothing else. The trip fails, and only walking back to the Portal brings anything home."
const LEAVE_COST := "You will lose %s."
const WARP_LINE := "I failed you... I'm sorry."
const WARP_CAMERA_SECONDS := 0.4
const WARP_LOSS_DELAY := 0.5
const WARP_LINE_SECONDS := 1.4

## The speed to start at, so a player who likes ×3 keeps it from trip to trip.
static var chosen_speed := 1.0
## Above 0, the seed of the next trip. For tests.
static var next_seed := 0

var trip: Expedition
var board: BoardManager
var camera: BoardCamera
## The adventurer's piece on the board.
var token: PlayerMovement
## The adventurer while they appear and fade away, which a token can't do.
var hero: CharacterFigure
var hud: TripHud
var die: DiceRoller
var battle_screen: BattleScreen
var back: KitBackButton
var arrow: KitArrow
var bubble: TavernBubble
## The speed buttons, in the order of SPEEDS.
var speed_buttons: Array[KitButton] = []
## What just happened, in a line.
var news: KitPanel
var report: TripReport
var report_card: TripReportCard
## The town's gold, shown once the trip is over.
var town_gold: KitChip
## Asks before the Warp Stone is used.
var leave_panel: KitPanel
var stay_button: KitButton
var leave_button: KitButton
## What giving up would cost, right now.
var leave_cost: Label

var _motes: PortalMotes
var _layer: Control
var _dim: ColorRect
var _news_words: Label
var _speed_row: HBoxContainer
# The speed in use, kept while the leave panel holds time still.
var _speed := 1.0


func _ready() -> void:
	var town := TownData.current()
	trip = Expedition.new(town.hired, town.stage, next_seed)
	_build_world(town)
	_build_ui(town)
	_set_speed(chosen_speed if chosen_speed > 0.0 else 1.0)
	Sound.music("board")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()
	_play()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- Playing the trip -------------------------------------------------------

func _play() -> void:
	await _appear()
	while not trip.is_over():
		await _play_day()
	await _finish()


func _appear() -> void:
	await _pause(APPEAR_DELAY)
	Sound.play("magic")
	_motes.power = 1.0
	create_tween().tween_property(_motes, "power", 0.0, BURST_SECONDS)
	hero.show()
	await hero.dissolve(1.0, 0.0, APPEAR_SECONDS)
	hero.act(CharacterFigure.SWING_FRAMES)
	var head := get_viewport().get_canvas_transform() * (hero.global_position + HEAD)
	bubble.say(trip.person.arrive_line, head, get_viewport_rect())
	await _pause(LINE_SECONDS)
	bubble.hide()
	hero.hide()
	token.show()
	camera.follow(token)


func _play_day() -> void:
	var read_from := trip.diary.size()
	var can_move := trip.start_day()
	hud.refresh()
	await _show_news(read_from)
	if can_move:
		await _walk()
		read_from = trip.diary.size()
		var before := _purse()
		trip.land()
		_play_landing_sound(before)
		hud.refresh()
		await _catch_up_token()
		await _show_news(read_from)
		await _fight_if_needed()
	trip.end_day()


func _walk() -> void:
	var steps := trip.roll()
	await die.throw(steps)
	var path: Array[BoardNode] = []
	for id in trip.walk(steps):
		path.append(board.get_board_node(id))
	camera.follow(token)
	if not path.is_empty():
		await token.walk_path(path)


func _fight_if_needed() -> void:
	while trip.fight != null:
		_set_news("")
		var read_from := trip.diary.size()
		trip.finish_fight(await battle_screen.run(trip.fight))
		hud.refresh()
		await _catch_up_token()
		# A chest opened after beating its guardian has news of its own.
		await _show_news(read_from)


# What they hold now, to tell how a space treated them.
func _purse() -> Dictionary:
	var player := trip.player
	return {"gold": player.gold, "hp": player.hp, "items": player.inventory.size()}


func _play_landing_sound(before: Dictionary) -> void:
	var player := trip.player
	if player.hp < before["hp"]:
		Sound.play("trap")
	elif player.hp > before["hp"]:
		Sound.play("heal")
	elif player.gold > before["gold"]:
		Sound.play("coin")
	elif player.gold < before["gold"]:
		Sound.play("coin_loss")
	elif player.inventory.size() > before["items"]:
		Sound.play("item")


# Something can pull them off their space: a trapdoor, or an event.
func _catch_up_token() -> void:
	if token.current_node.node_id == trip.space_id:
		return
	Sound.play("whoosh")
	token.spawn_at(board.get_board_node(trip.space_id))
	await _pause(QUIET_SECONDS)


func _finish() -> void:
	_set_time(1.0)
	await _close_trip()


# Fades them off the board and reports. It runs on real time, because the Warp Stone
# keeps the game stopped: that holds the day where it was, however far it had got.
func _close_trip() -> void:
	if trip.ending == Expedition.Ending.BEATEN:
		hud.show_beaten()
	_clear_for_ending()
	_put_hero_on_board()
	Sound.play("magic" if trip.ending == Expedition.Ending.HOME else "whoosh")
	await hero.dissolve(0.0, 1.0, DISSOLVE_SECONDS, true)
	var town := TownData.current()
	var gold_before := town.gold
	town.bring_home(trip)
	report = TripReport.new(trip)
	Sound.play("defeat" if report.failed else "fanfare")
	_show_report(town, gold_before)


func _clear_for_ending() -> void:
	_speed_row.hide()
	back.hide()
	_set_news("")


func _put_hero_on_board() -> void:
	hero.global_position = token.global_position
	hero.show()
	token.hide()


func _show_report(town: TownData, gold_before: int) -> void:
	hud.hide()
	news.hide()
	_dim.color = DEFEAT_DIM if report.failed else DIM
	_dim.show()
	report_card = TripReportCard.new(trip.person, report)
	_centered(report_card)
	report_card.play_open()
	town_gold = KitChip.new("coin", gold_before)
	town_gold.focus_mode = Control.FOCUS_ALL
	_layer.add_child(town_gold)
	town_gold.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	town_gold.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	town_gold.offset_left -= SPEED_FROM_RIGHT
	town_gold.offset_right -= SPEED_FROM_RIGHT
	town_gold.offset_top += SPEED_TOP
	town_gold.offset_bottom += SPEED_TOP
	town_gold.set_amount(town.gold)
	Tips.attach(town_gold, "Town gold", "%d gold in the town." % town.gold)
	back.text = "Back to Town"
	back.icon = Kit.icon("back")
	back.danger = false
	back.kind = KitButton.Kind.NORMAL if report.failed else KitButton.Kind.PRIMARY
	back.show()
	back.grab_focus()
	_link_report_focus()
	# A failed trip gets no fuss: nothing here cheers the player on.
	if not report.failed:
		arrow = KitArrow.new(back, KitArrow.Side.RIGHT)
		_layer.get_parent().add_child(arrow)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- News -------------------------------------------------------------------

# Shows what the diary has gained since line `read_from`, if it is worth showing.
func _show_news(read_from: int) -> void:
	var lines := PackedStringArray()
	for index in range(read_from, trip.diary.size()):
		var line := trip.diary[index]
		# The die and the fight screen have already shown these.
		if line["kind"] != "roll" and line["kind"] != "fight":
			lines.append(line["text"])
	_set_news(" ".join(lines))
	await _pause(NEWS_SECONDS if not lines.is_empty() else QUIET_SECONDS)


func _set_news(words: String) -> void:
	_news_words.text = words
	var had_news := news.visible
	news.visible = words != ""
	if news.visible and not had_news:
		news.play_open()


# --- Speed ------------------------------------------------------------------

## Sets the speed of the whole trip, fights included. Any number works, for tests.
func _set_speed(speed: float) -> void:
	_speed = speed
	chosen_speed = speed
	_set_time(speed)
	for index in speed_buttons.size():
		speed_buttons[index].lit = SPEEDS[index] == speed


func _set_time(speed: float) -> void:
	Engine.time_scale = speed


# --- Leaving ----------------------------------------------------------------

func _on_back() -> void:
	if report != null:
		Screens.go(TOWN)
	elif leave_panel.visible:
		_close_leave_panel()
	else:
		_open_leave_panel()


func _open_leave_panel() -> void:
	_set_time(0.0)
	var what := TripReport.lost_words(trip.player.gold, trip.player.inventory.size())
	leave_cost.text = LEAVE_COST % what if what != "" else ""
	leave_cost.visible = what != ""
	_dim.show()
	leave_panel.show()
	leave_panel.play_open()
	stay_button.grab_focus()


func _close_leave_panel() -> void:
	leave_panel.hide()
	_dim.hide()
	_set_time(_speed)
	speed_buttons[SPEEDS.find(_speed) if SPEEDS.has(_speed) else 1].grab_focus()


# Time stays stopped from the question to the report, so that whatever was under way,
# a walk or a fight, never finishes.
func _warp_home() -> void:
	# They may have just reached the Portal, or fallen. Then it is too late to give up.
	if trip.is_over():
		_close_leave_panel()
		return
	leave_panel.hide()
	trip.warp_home()
	battle_screen.hide()
	die.hide()
	bubble.hide()
	Sound.music("")
	_clear_for_ending()
	_put_hero_on_board()
	_fade_to_defeat()
	camera.focus_on(hero.global_position, WARP_CAMERA_SECONDS)
	await _real_pause(WARP_CAMERA_SECONDS)
	var head := get_viewport().get_canvas_transform() * (hero.global_position + HEAD)
	# Above the red, so the last words can be read.
	_layer.move_child(bubble, -1)
	bubble.say(WARP_LINE, head, get_viewport_rect())
	Sound.play("trap")
	camera.shake()
	await _real_pause(WARP_LOSS_DELAY)
	if hud.gold.amount > 0 or hud.bag.amount > 0:
		Sound.play("coin_loss")
	hud.gold.set_amount(0)
	hud.bag.set_amount(0)
	await _real_pause(WARP_LINE_SECONDS)
	bubble.hide()
	await _close_trip()


# Bleeds the colour out of the island.
func _fade_to_defeat() -> void:
	_dim.color = Color(DEFEAT_DIM, 0.0)
	_dim.show()
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_dim, "color", DEFEAT_DIM, WARP_CAMERA_SECONDS)


func _real_pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


# --- Building ---------------------------------------------------------------

func _build_world(town: TownData) -> void:
	board = BOARD.instantiate()
	board.map_file = town.stage.map_file
	board.print_on_ready = false
	board.clickable = false
	add_child(board)
	var start := board.get_starting_node().global_position
	camera = BoardCamera.new()
	camera.world_limit = board.get_world_rect()
	camera.global_position = start
	camera.arrows_pan = false
	add_child(camera)
	camera.make_current()
	token = TOKEN.instantiate()
	token.board_manager = board
	token.character_sheet = town.hired.sheet
	token.player_name = town.hired.display_name
	token.token_color = TOKEN_RING
	token.step_duration = STEP_SECONDS
	token.hide()
	token.step_finished.connect(func(_node: BoardNode, _left: int) -> void: Sound.play("step"))
	add_child(token)
	hero = CharacterFigure.new(town.hired.sheet)
	hero.global_position = start
	hero.z_index = HERO_LAYER
	hero.hide()
	add_child(hero)
	_motes = PortalMotes.new()
	_motes.global_position = start
	_motes.reach = BURST_REACH
	_motes.outward = true
	_motes.z_index = HERO_LAYER
	add_child(_motes)


func _build_ui(town: TownData) -> void:
	var fight_layer := CanvasLayer.new()
	fight_layer.layer = FIGHT_LAYER
	add_child(fight_layer)
	battle_screen = BattleScreen.new()
	fight_layer.add_child(battle_screen)
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	add_child(ui)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_layer)
	_build_die()
	bubble = TavernBubble.new()
	_layer.add_child(bubble)
	_build_strip(town)
	_build_news()
	_build_speed_row()
	_build_cover()
	_build_leave_panel()
	back = KitBackButton.new()
	back.text = WARP_NAME
	back.icon = Kit.icon("cross")
	back.danger = true
	back.pressed.connect(_on_back)
	_layer.add_child(back)
	_link_focus()
	speed_buttons[SPEEDS.find(1.0)].grab_focus()


func _build_die() -> void:
	die = DiceRoller.new()
	die.custom_minimum_size = DIE_SIZE
	die.size = DIE_SIZE
	die.hide()
	_layer.add_child(die)
	die.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	die.offset_top += DIE_TOP
	die.offset_bottom += DIE_TOP


func _build_strip(town: TownData) -> void:
	hud = TripHud.new(trip, town.stage)
	_layer.add_child(hud)
	hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	hud.offset_top -= STRIP_FROM_BOTTOM
	hud.offset_bottom -= STRIP_FROM_BOTTOM


func _build_news() -> void:
	news = KitPanel.new()
	news.custom_minimum_size.x = NEWS_WIDTH
	_news_words = Kit.text("", NEWS_WIDTH)
	_news_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news.body.add_child(_news_words)
	news.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(news)
	news.grow_horizontal = Control.GROW_DIRECTION_BOTH
	news.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	news.offset_top += NEWS_TOP
	news.offset_bottom += NEWS_TOP
	news.hide()


func _build_speed_row() -> void:
	_speed_row = HBoxContainer.new()
	_speed_row.add_theme_constant_override("separation", SPEED_GAP)
	for index in SPEEDS.size():
		var button := KitButton.new()
		button.kind = KitButton.Kind.SMALL
		button.text = SPEED_WORDS[index]
		var speed := SPEEDS[index]
		button.pressed.connect(func() -> void: _set_speed(speed))
		_speed_row.add_child(button)
		speed_buttons.append(button)
	_layer.add_child(_speed_row)
	_speed_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_speed_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_speed_row.offset_left -= SPEED_FROM_RIGHT
	_speed_row.offset_right -= SPEED_FROM_RIGHT
	_speed_row.offset_top += SPEED_TOP
	_speed_row.offset_bottom += SPEED_TOP


# Darkens the island under the report and the leave panel, and keeps clicks off the rest.
func _build_cover() -> void:
	_dim = ColorRect.new()
	_dim.color = DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	_layer.add_child(_dim)


func _build_leave_panel() -> void:
	leave_panel = KitPanel.new(LEAVE_HEADING, true)
	leave_panel.title.add_theme_color_override("font_color", Kit.BLOOD)
	leave_panel.custom_minimum_size.x = LEAVE_WIDTH
	var words := Kit.text(LEAVE_WORDS % trip.person.display_name, LEAVE_WIDTH, &"PaperLabel")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_panel.body.add_child(words)
	leave_cost = Kit.text("", LEAVE_WIDTH, &"PaperLabel")
	leave_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_cost.add_theme_color_override("font_color", Kit.BLOOD)
	leave_panel.body.add_child(leave_cost)
	stay_button = KitButton.new()
	stay_button.text = "Keep going"
	stay_button.pressed.connect(_close_leave_panel)
	leave_panel.body.add_child(stay_button)
	leave_button = KitButton.new()
	leave_button.text = LEAVE_TEXT
	leave_button.kind = KitButton.Kind.SMALL
	leave_button.danger = true
	leave_button.pressed.connect(_warp_home)
	leave_panel.body.add_child(leave_button)
	_centered(leave_panel)
	leave_panel.hide()


func _centered(panel: KitPanel) -> void:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(holder)
	# The Back button stays above what covers the rest.
	if back != null:
		_layer.move_child(holder, back.get_index())
	holder.add_child(panel)


## Back is the main action, and down reads the numbers on the card.
func _link_report_focus() -> void:
	var chips := report_card.stats
	for way: StringName in [&"focus_neighbor_top", &"focus_neighbor_left"]:
		back.set(way, back.get_path_to(back))
	for way: StringName in [&"focus_neighbor_bottom", &"focus_neighbor_right"]:
		back.set(way, back.get_path_to(chips[0]))
	for index in chips.size():
		var chip := chips[index]
		chip.focus_neighbor_top = chip.get_path_to(back)
		chip.focus_neighbor_bottom = chip.get_path_to(chip)
		chip.focus_neighbor_left = chip.get_path_to(chips[maxi(index - 1, 0)])
		chip.focus_neighbor_right = chip.get_path_to(chips[mini(index + 1, chips.size() - 1)])


## Left and right walk the top row, down reads the strip, and the panel keeps focus
## to itself while it is open.
func _link_focus() -> void:
	var top: Array[Control] = [back]
	top.append_array(speed_buttons)
	for index in top.size():
		var part := top[index]
		part.focus_neighbor_top = part.get_path_to(part)
		part.focus_neighbor_left = part.get_path_to(top[maxi(index - 1, 0)])
		part.focus_neighbor_right = part.get_path_to(top[mini(index + 1, top.size() - 1)])
		part.focus_neighbor_bottom = part.get_path_to(hud.hp_bar)
	var strip: Array[Control] = [hud.hp_bar, hud.food_bar, hud.bag, hud.gold]
	for index in strip.size():
		var part := strip[index]
		part.focus_neighbor_top = part.get_path_to(speed_buttons[1])
		part.focus_neighbor_bottom = part.get_path_to(part)
		part.focus_neighbor_left = part.get_path_to(strip[maxi(index - 1, 0)])
		part.focus_neighbor_right = part.get_path_to(strip[mini(index + 1, strip.size() - 1)])
	for part: Control in [stay_button, leave_button]:
		for way: StringName in [&"focus_neighbor_left", &"focus_neighbor_right"]:
			part.set(way, part.get_path_to(part))
	stay_button.focus_neighbor_top = stay_button.get_path_to(stay_button)
	stay_button.focus_neighbor_bottom = stay_button.get_path_to(leave_button)
	leave_button.focus_neighbor_top = leave_button.get_path_to(stay_button)
	leave_button.focus_neighbor_bottom = leave_button.get_path_to(leave_button)
