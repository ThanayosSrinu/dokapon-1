class_name ExpeditionScreen
extends Node2D
## One trip on screen, from the far side of the Portal to the report, played by the person
## at the keys. The rules stay in Expedition.gd: this script runs the steps of a day in
## order, asks for each choice, and shows what came back. Every choice waits for the player:
## roll or camp, where a roll lands, each move of a fight, and going home at the Portal.
##
## A road is picked by clicking a green space, or with the arrow keys or the controller,
## because every link on a map runs straight along the grid, so each road has its own
## direction.

## The day's choice was made.
signal _day_chosen(to_camp: bool)
## A space was picked for the roll to land on.
signal _landing_picked(id: int)
## The Portal's question was answered.
signal _portal_answered(going_home: bool)

const TOWN := "res://town/TownScreen.tscn"
const GAME_OVER := "res://town/GameOverScreen.tscn"
const BOARD: PackedScene = preload("res://maps/WorldMap.tscn")
const TOKEN: PackedScene = preload("res://player/Player.tscn")

const EDGE_RIGHT := 24.0
const EDGE_TOP := 24.0
const STRIP_FROM_BOTTOM := 12.0
const STRIP_FROM_LEFT := 28.0
const BAG_TOP := 80.0
const MAP_PANEL_TOP := 80.0
const NEWS_TOP := 24.0
const NEWS_WIDTH := 600.0
## Where Roll stands: beside the strip, in the gap before the bag, so it hides no road.
const ROLL_LEFT := 738.0
## Where Camp stands, above Roll.
const CAMP_ABOVE := 96.0
## How far right of the adventurer the camera looks with the map open, so the panel covers
## less of them.
const MAP_VIEW_SHIFT := Vector2(240, 0)
const MAP_VIEW_SECONDS := 0.4

## Waits for the light of the flash to thin out.
const APPEAR_DELAY := 0.5
const APPEAR_SECONDS := 0.7
const BURST_SECONDS := 1.4
const BURST_REACH := Vector2(140, 90)
## How long their first words stay up.
const LINE_SECONDS := 1.6
const STEP_SECONDS := 0.45
## How long the marked spaces show before a walk starts.
const MARK_SECONDS := 0.5
## How long something found holds up the next step. A quiet space takes a blink.
const NEWS_SECONDS := 1.0
const QUIET_SECONDS := 0.25
const DISSOLVE_SECONDS := 0.7
const HERO_LAYER := 10
const HEAD := Vector2(0, -46)
## How far above their head the roll stands.
const DIE_GAP := 8.0
const TOKEN_RING := Color(1.0, 0.85, 0.42)
const FIGHT_LAYER := 1
const UI_LAYER := 2
const DIM := Color(0.06, 0.05, 0.12, 0.62)
const PANEL_WIDTH := 460.0
const DEFEAT_DIM := Color(0.3, 0.02, 0.05, 0.6)
const WARP_NAME := "Emergency Warp"
const SPEED_TEXT := "x%d"
const SPEED_TIP := "How fast the trip runs. F changes it. The music keeps its own pace."
const LEAVE_HEADING := "Abandon the trip?"
const LEAVE_TEXT := "Abandon the trip"
const LEAVE_WORDS := "The Warp Stone saves %s's life and nothing else. The trip fails, and only walking back to the Portal brings anything home."
const LEAVE_COST := "You will lose %s."
const PORTAL_HEADING := "The Portal"
const PORTAL_WORDS := "Go home with %s, and end the trip here?"
const PORTAL_NOTHING := "nothing"
const GO_HOME_TEXT := "Go home"
const STAY_OUT_TEXT := "Stay out"
const PICK_WORDS := "Where to? Pick a ringed space."
const CAMP_TEXT := "Camp"
const CAMP_WORDS := "Spend this turn's food to rest, and get back %d%% of HP and MP."
const CAMP_FULL := "They are fully rested."
const CAMP_HUNGRY := "There is no food to camp on."
const WARP_LINE := "Warp Stone, take me home!"
const WARP_CAMERA_SECONDS := 0.4
const WARP_LOSS_DELAY := 0.5
const WARP_LINE_SECONDS := 1.4
## Diary lines the news leaves out, because the die or the fight screen has shown them.
const SHOWN_ELSEWHERE: Array[String] = ["roll", "fight"]
## What the strip says while something is owed in town.
const DEBT_LEFT := "The %s is due in %s."
const DEBT_TODAY := "The %s is due today."
const DEBT_MISSED := "The %s was not paid."
const OUT_WORDS := "%s can't work for %s."
## The way each key points on the board, for picking a space.
const ROAD_KEYS := {"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT, "ui_up": Vector2.UP, "ui_down": Vector2.DOWN}
## How close to a key's direction a space must lie for that key to move to it.
const ROAD_AIM := 0.7

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
## What is worn and carried, and the box that explains things.
var bag_panel: BagPanel
var die: RollBlock
var battle_screen: BattleScreen
## Asks what to do with something found when the bag is full.
var bag_prompt: BagPrompt
var material_prompt: MaterialPrompt
var learn_prompt: LearnPrompt
var back: KitBackButton
var arrow: KitArrow
var bubble: TavernBubble
## The main action of each day.
var roll_button: KitButton
## Rests instead of rolling.
var camp_button: KitButton
## Points at Roll on the first day.
var roll_arrow: KitArrow
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
## Asks whether to go home, on landing on the Portal.
var portal_panel: KitPanel
var portal_words: Label
var home_button: KitButton
var stay_out_button: KitButton
## Opens the map of the island.
var map_button: KitButton
## Steps through Settings.TRIP_SPEEDS.
var speed_button: KitButton
var map_panel: MapPanel
## The ids of the spaces the roll can land on, while the player picks one, or empty.
var landing_choices: Array[int] = []
## The one of landing_choices that keys and the mouse point at now.
var selected_landing := -1

var _motes: PortalMotes
var _layer: Control
var _dim: ColorRect
var _news_words: Label
# The spaces marked as where this roll can end.
var _marked: Array[BoardNode] = []
# The time scale kept while the leave panel holds time still.
var _time_before := 1.0
# What had focus before the leave panel took it.
var _focus_before: Control
# The camera's zoom from before the map opened.
var _zoom_before := 1


func _ready() -> void:
	var town := TownData.current()
	trip = Expedition.new(town.going, town.stage, next_seed, true, town.food, town.member(town.going))
	trip.beacon = town.has_beacon()
	_build_world(town)
	_build_ui(town)
	EventBus.space_clicked.connect(_on_space_clicked)
	Sound.music("board")
	Engine.time_scale = Settings.trip_speed
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()
	_play()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	_place_die()
	_update_bag_panel()


func _input(event: InputEvent) -> void:
	if leave_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_leave_panel()
		return
	if speed_button.visible and event.is_action_pressed("trip_speed"):
		get_viewport().set_input_as_handled()
		_next_speed()
		return
	# The stone is out of the way here, so Esc has to be caught before it is missed.
	if portal_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_portal_answered.emit(false)
		return
	if roll_button.visible and get_viewport().gui_get_focus_owner() == null and event.is_action_pressed("ui_accept"):
		roll_button.grab_focus()
	if landing_choices.is_empty() or map_panel.visible:
		return
	if event is InputEventMouseMotion:
		var hovered := board.get_node_at(get_global_mouse_position())
		if hovered != null and landing_choices.has(hovered.node_id):
			_select_landing(hovered.node_id)
		elif event.relative.length() > 1.0:
			_select_landing(-1)
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		# Nothing lit yet: the first press lights a space, the next one takes it.
		if selected_landing < 0:
			_select_landing(landing_choices[0])
		else:
			_landing_picked.emit(selected_landing)
		return
	for action: String in ROAD_KEYS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			var id := landing_choices[0] if selected_landing < 0 else landing_toward(ROAD_KEYS[action])
			if id >= 0:
				_select_landing(id)
			return


## The nearest space to pick in direction `way` from the one selected, or -1 if none lies
## that way.
func landing_toward(way: Vector2) -> int:
	var here := board.get_board_node(selected_landing).global_position
	var best := -1
	var best_score := INF
	for id in landing_choices:
		var there := board.get_board_node(id).global_position
		if id == selected_landing or here.direction_to(there).dot(way) < ROAD_AIM:
			continue
		var score := here.distance_to(there) / here.direction_to(there).dot(way)
		if score < best_score:
			best = id
			best_score = score
	return best


func _on_space_emptied(id: int) -> void:
	var node := board.get_board_node(id)
	node.node_type = trip.type_at(id)
	node.guarded = trip.is_guarded(id)
	node.bump()
	_refresh_map()


func _on_space_clicked(node: BoardNode) -> void:
	if landing_choices.has(node.node_id):
		_landing_picked.emit(node.node_id)


# Keeps the bag shut during fights, and points its box at the space under the mouse.
func _update_bag_panel() -> void:
	bag_panel.locked = (battle_screen.visible or bag_prompt.visible or material_prompt.visible
			or learn_prompt.visible or trip.is_over())
	var space := board.get_node_at(get_global_mouse_position())
	if get_viewport().gui_get_hovered_control() != null or space == null:
		bag_panel.point_at_space(trip.space_id)
	else:
		bag_panel.point_at_space(space.node_id)


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
	_watch_token()


func _play_day() -> void:
	var read_from := trip.diary.size()
	var can_move := trip.start_day()
	_warn_of_debts()
	hud.refresh()
	_refresh_map()
	await _show_news(read_from)
	if can_move and await _wait_for_choice():
		await _camp()
	elif can_move:
		read_from = trip.diary.size()
		await _walk()
		var before := _purse()
		trip.land()
		_play_landing_sound(before)
		hud.refresh()
		await _catch_up_token()
		await _show_news(read_from)
		await _fight_if_needed()
		await _settle_found_item()
		await _settle_found_material()
		await _ask_about_portal()
	trip.end_day()


# Puts focus on what the day now asks. An open leave panel keeps it until it closes, or
# the arrow keys would walk off the panel.
func _ask_with(part: Control) -> void:
	if leave_panel.visible:
		_focus_before = part
	else:
		part.grab_focus()


# Waits for the day's choice, and returns true if it is to camp.
func _wait_for_choice() -> bool:
	_offer_camp()
	roll_button.show()
	camp_button.show()
	_ask_with(roll_button)
	if trip.day == 1:
		roll_arrow = KitArrow.new(roll_button, KitArrow.Side.RIGHT)
		_layer.get_parent().add_child(roll_arrow)
	var to_camp: bool = await _day_chosen
	roll_button.hide()
	camp_button.hide()
	_drop_roll_arrow()
	_close_map(false)
	_set_news("")
	return to_camp


func _offer_camp() -> void:
	if trip.can_camp():
		camp_button.block("")
		Tips.attach(camp_button, CAMP_TEXT, CAMP_WORDS % roundi(Expedition.CAMP_SHARE * 100.0))
	else:
		camp_button.block(CAMP_HUNGRY if trip.food_left == 0 else CAMP_FULL)


func _camp() -> void:
	var read_from := trip.diary.size()
	trip.camp()
	Sound.play("heal")
	hud.refresh()
	await _show_news(read_from)


func _drop_roll_arrow() -> void:
	if roll_arrow != null:
		roll_arrow.queue_free()
		roll_arrow = null


func _walk() -> void:
	var steps := trip.roll()
	await die.throw(steps, trip.person.die_top)
	if not trip.begin_walk(steps):
		return
	# The roll stays over the token's head while the landing is shown or picked.
	token.steps_left = trip.steps_left
	_watch_token()
	_mark_landings()
	var landings := trip.landing_spaces()
	var landing := landings[0]
	if landings.size() == 1:
		await _pause(MARK_SECONDS)
	else:
		landing = await _pick_landing(landings)
	_mark_nothing()
	board.get_board_node(landing).is_landing_spot = true
	_marked.append(board.get_board_node(landing))
	for next in trip.choose_landing(landing):
		var left := trip.steps_left
		trip.step_to(next)
		await token.walk_path([board.get_board_node(next)], left)
		_refresh_map()
	_mark_nothing()


# Rings every space this walk can still end on.
func _mark_landings() -> void:
	_mark_nothing()
	for id in trip.landing_spaces():
		var node := board.get_board_node(id)
		node.is_landing_spot = true
		_marked.append(node)


func _mark_nothing() -> void:
	for node in _marked:
		node.is_landing_spot = false
	_marked.clear()


# Waits for the player to pick where the roll lands, out of `options`, which are ringed.
# One is lit only while the mouse points at it, or once the arrow keys pick it: click any,
# or move with the arrow keys and press Accept. The camera stays as the player left it.
func _pick_landing(options: Array[int]) -> int:
	landing_choices = options
	_set_news(PICK_WORDS)
	var picked: int = await _landing_picked
	_clear_landing_choices()
	_set_news("")
	_watch_token()
	return picked


# Lights space `id` out of the choices, or none for -1.
func _select_landing(id: int) -> void:
	if selected_landing >= 0:
		board.get_board_node(selected_landing).is_path_choice = false
	selected_landing = id
	if id >= 0:
		board.get_board_node(id).is_path_choice = true


func _clear_landing_choices() -> void:
	if selected_landing >= 0:
		board.get_board_node(selected_landing).is_path_choice = false
	selected_landing = -1
	landing_choices = []


func _fight_if_needed() -> void:
	while trip.fight != null:
		_set_news("")
		_close_map(false)
		map_button.hide()
		var read_from := trip.diary.size()
		# The fight fills the window and has its own bars, so the strip and the bag step
		# aside. The way out stays.
		hud.hide()
		bag_panel.hide()
		trip.finish_fight(await battle_screen.run(trip.fight))
		hud.show()
		bag_panel.show()
		map_button.show()
		hud.refresh()
		await _catch_up_token()
		# A chest opened after beating its guardian has news of its own.
		await _show_news(read_from)


# Something was found with the bag full, so the player says what stays.
func _settle_found_item() -> void:
	if trip.found_item == "" or trip.is_over():
		return
	await bag_prompt.ask(trip.player, trip.found_item)
	trip.found_item = ""
	hud.refresh()


# A material was found with the materials bag full, so the player says what stays.
func _settle_found_material() -> void:
	if trip.found_material == "" or trip.is_over():
		return
	await material_prompt.ask(trip)
	bag_panel.refresh()


# A tome wants a move forgotten, so the player says which.
func _on_wants_to_forget(item_id: String) -> void:
	var before := get_viewport().gui_get_focus_owner()
	if await learn_prompt.ask(trip, item_id):
		Sound.play("heal")
	bag_panel.refresh()
	hud.refresh()
	if before != null and before.is_visible_in_tree():
		before.grab_focus()
	elif roll_button.visible:
		roll_button.grab_focus()


func _ask_about_portal() -> void:
	if not trip.may_go_home():
		return
	var what := TripReport.lost_words(trip.player.gold, trip.player.inventory.size(), trip.materials.size())
	portal_words.text = PORTAL_WORDS % (what if what != "" else PORTAL_NOTHING)
	_close_map(false)
	_dim.show()
	back.hide()
	portal_panel.show()
	portal_panel.play_open()
	_ask_with(home_button)
	var going_home: bool = await _portal_answered
	portal_panel.hide()
	_dim.hide()
	back.show()
	if going_home:
		trip.go_home()


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
	Engine.time_scale = 1.0
	await _close_trip()


# Fades them off the board and reports. It runs on real time, because the Warp Stone
# keeps the game stopped: that holds the day where it was, however far it had got.
func _close_trip() -> void:
	if trip.ending == Expedition.Ending.BEATEN:
		hud.show_beaten()
	_clear_for_ending()
	# The warp has already taken them.
	if trip.ending != Expedition.Ending.WARPED:
		_put_hero_on_board()
		Sound.play("magic" if trip.ending == Expedition.Ending.HOME else "whoosh")
		await hero.dissolve(0.0, 1.0, DISSOLVE_SECONDS, true)
	var town := TownData.current()
	var gold_before := town.gold
	town.bring_home(trip)
	town.save()
	report = TripReport.new(trip)
	var out: int = town.member(trip.person).days_out(town.day)
	if out > 0:
		report.story.append(OUT_WORDS % [trip.person.display_name, TownData.days_words(out)])
	if report.died:
		Sound.play("defeat")
	elif not report.failed:
		Sound.play("fanfare")
	_show_report(town, gold_before)


func _clear_for_ending() -> void:
	_close_map(false)
	bag_panel.hide()
	map_button.hide()
	speed_button.hide()
	roll_button.hide()
	camp_button.hide()
	portal_panel.hide()
	bag_prompt.hide()
	material_prompt.hide()
	_drop_roll_arrow()
	_clear_landing_choices()
	_mark_nothing()
	bubble.hide()
	back.hide()
	_set_news("")


func _put_hero_on_board() -> void:
	hero.global_position = token.global_position
	hero.show()
	token.hide()


func _show_report(town: TownData, gold_before: int) -> void:
	hud.hide()
	news.hide()
	_dim.color = DEFEAT_DIM if report.died else DIM
	_dim.show()
	report_card = TripReportCard.new(trip.person, report)
	_centered(report_card)
	report_card.play_open()
	town_gold = KitChip.new("coin", gold_before)
	town_gold.focus_mode = Control.FOCUS_ALL
	_layer.add_child(town_gold)
	town_gold.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	town_gold.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	town_gold.offset_left -= EDGE_RIGHT
	town_gold.offset_right -= EDGE_RIGHT
	town_gold.offset_top += EDGE_TOP
	town_gold.offset_bottom += EDGE_TOP
	town_gold.set_amount(town.gold)
	Tips.attach(town_gold, "Town gold", "%d gold in the town." % town.gold)
	back.text = "Back to Town"
	back.esc_presses = true
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

# Shows what the diary has gained since line `read_from`, if it is worth showing. With
# nothing new, the last news stays up, to be read until the next roll.
func _show_news(read_from: int) -> void:
	var lines := PackedStringArray()
	for index in range(read_from, trip.diary.size()):
		var line := trip.diary[index]
		if not SHOWN_ELSEWHERE.has(line["kind"]):
			lines.append(line["text"])
	if not lines.is_empty():
		_set_news(" ".join(lines))
	await _pause(NEWS_SECONDS if not lines.is_empty() else QUIET_SECONDS)


func _set_news(words: String) -> void:
	_news_words.text = words
	var had_news := news.visible
	news.visible = words != ""
	if news.visible and not had_news:
		news.play_open()


# The roll stands over their head, wherever the camera has gone.
func _place_die() -> void:
	if token.visible and report == null:
		var head := get_viewport().get_canvas_transform() * (token.global_position + HEAD)
		die.position = (head - Vector2(die.size.x * 0.5, die.size.y + DIE_GAP)).round()


# Puts what is owed in town on the strip, while it is close enough to matter. The trip is
# never stopped for it: see D11 in EXPEDITION_PLAN.md.
func _warn_of_debts() -> void:
	var town := TownData.current()
	# The day they will be home, as a trip's days are fixed.
	var today := town.day + trip.trip_days
	if town.show_alert(today) == TownData.Alert.NONE:
		hud.warn_of_debts("")
		return
	var debt := town.next_debt()
	var left: int = debt["due"] - today
	if left > 0:
		hud.warn_of_debts(DEBT_LEFT % [debt["what"], TownData.days_words(left)])
	else:
		hud.warn_of_debts((DEBT_TODAY if left == 0 else DEBT_MISSED) % debt["what"])


# --- Speed ------------------------------------------------------------------

# Goes to the next of Settings.TRIP_SPEEDS, and keeps it for the next trip. A stopped
# game stays stopped.
func _next_speed() -> void:
	var speeds := Settings.TRIP_SPEEDS
	Settings.trip_speed = speeds[(speeds.find(Settings.trip_speed) + 1) % speeds.size()]
	Settings.save()
	if Engine.time_scale != 0.0:
		Engine.time_scale = Settings.trip_speed
	_show_speed()


func _show_speed() -> void:
	speed_button.text = SPEED_TEXT % int(Settings.trip_speed)
	speed_button.lit = Settings.trip_speed > 1.0


# --- The map ----------------------------------------------------------------

func _toggle_map() -> void:
	if map_panel.visible:
		_close_map()
	else:
		_open_map()


# The view pulls back and the camera is free, so the arrow keys look around. The bag gives
# up its place to the panel.
func _open_map() -> void:
	map_panel.refresh()
	bag_panel.hide()
	map_panel.show()
	map_panel.play_open()
	_zoom_before = camera.zoom_index()
	camera.set_zoom_index(0, MAP_VIEW_SECONDS)
	camera.focus_on(token.global_position + MAP_VIEW_SHIFT, MAP_VIEW_SECONDS)
	camera.arrows_pan = true
	map_button.lit = true
	map_button.grab_focus()
	_link(map_button, map_button, map_button, map_button, map_button)


func _close_map(take_focus := true) -> void:
	if not map_panel.visible:
		return
	map_panel.hide()
	bag_panel.show()
	camera.set_zoom_index(_zoom_before, MAP_VIEW_SECONDS)
	camera.follow(token)
	camera.arrows_pan = false
	map_button.lit = false
	_link_focus()
	if take_focus:
		_focus_on_day()


func _refresh_map() -> void:
	if map_panel.visible:
		map_panel.refresh()


func _look_at_space(id: int) -> void:
	camera.focus_on(board.get_board_node(id).global_position + MAP_VIEW_SHIFT, MAP_VIEW_SECONDS)


# The camera goes back to them, unless the whole island is being looked at.
func _watch_token() -> void:
	if not map_panel.visible:
		camera.follow(token)


# Puts focus on whatever the day is waiting for.
func _focus_on_day() -> void:
	if roll_button.visible:
		roll_button.grab_focus()
	elif map_button.visible:
		map_button.grab_focus()


# --- Leaving ----------------------------------------------------------------

func _on_back() -> void:
	if report != null:
		Screens.go(GAME_OVER if TownData.current().lost() else TOWN)
	elif bag_prompt.visible or material_prompt.visible:
		return
	elif map_panel.visible:
		_close_map()
	elif leave_panel.visible:
		_close_leave_panel()
	else:
		_open_leave_panel()


func _open_leave_panel() -> void:
	_time_before = Engine.time_scale
	_focus_before = get_viewport().gui_get_focus_owner()
	Engine.time_scale = 0.0
	back.hide()
	var what := TripReport.lost_words(trip.player.gold, trip.player.inventory.size(), trip.materials.size())
	leave_cost.text = LEAVE_COST % what if what != "" else ""
	leave_cost.visible = what != ""
	_dim.show()
	leave_panel.show()
	leave_panel.play_open()
	stay_button.grab_focus()


func _close_leave_panel() -> void:
	leave_panel.hide()
	_dim.hide()
	back.show()
	Engine.time_scale = _time_before
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	else:
		_focus_on_day()


# Time stays stopped from the question to the report, so that whatever was under way,
# a walk or a fight, never finishes. Nobody dies here: no red, and they stay whole until
# the light takes them.
func _warp_home() -> void:
	# They may have just fallen. Then it is too late to give up.
	if trip.is_over():
		_close_leave_panel()
		return
	leave_panel.hide()
	trip.warp_home()
	battle_screen.hide()
	hud.show()
	die.hide()
	bubble.hide()
	Sound.music("")
	_clear_for_ending()
	_put_hero_on_board()
	_dim.hide()
	camera.focus_on(hero.global_position, WARP_CAMERA_SECONDS)
	await _real_pause(WARP_CAMERA_SECONDS)
	var head := get_viewport().get_canvas_transform() * (hero.global_position + HEAD)
	bubble.say(WARP_LINE, head, get_viewport_rect())
	Sound.play("magic")
	await _real_pause(WARP_LOSS_DELAY)
	if hud.gold.amount > 0 or not trip.player.inventory.is_empty():
		Sound.play("coin_loss")
	hud.gold.set_amount(0)
	await _real_pause(WARP_LINE_SECONDS)
	bubble.hide()
	Sound.play("portal_flash")
	await WarpBeam.take(hero)
	await _close_trip()


func _real_pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


# --- Building ---------------------------------------------------------------

func _build_world(town: TownData) -> void:
	board = BOARD.instantiate()
	board.map_data = trip.map_data
	board.print_on_ready = false
	add_child(board)
	for id in trip.map.spaces():
		board.get_board_node(id).node_type = trip.type_at(id)
		board.get_board_node(id).guarded = trip.is_guarded(id)
	trip.space_emptied.connect(_on_space_emptied)
	var start := board.get_starting_node().global_position
	camera = BoardCamera.new()
	camera.world_limit = board.get_world_rect()
	camera.global_position = start
	camera.arrows_pan = false
	add_child(camera)
	camera.make_current()
	token = TOKEN.instantiate()
	token.board_manager = board
	token.character_sheet = town.going.sheet
	token.player_name = town.going.display_name
	token.token_color = TOKEN_RING
	token.step_duration = STEP_SECONDS
	token.hide()
	token.step_finished.connect(func(_node: BoardNode, _left: int) -> void: Sound.play("step"))
	add_child(token)
	hero = CharacterFigure.new(town.going.sheet)
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
	bag_prompt = BagPrompt.new()
	fight_layer.add_child(bag_prompt)
	material_prompt = MaterialPrompt.new()
	fight_layer.add_child(material_prompt)
	learn_prompt = LearnPrompt.new()
	fight_layer.add_child(learn_prompt)
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
	_build_strip()
	_build_bag_panel()
	_build_news()
	_build_roll_button()
	_build_map()
	_build_cover()
	_build_leave_panel()
	_build_portal_panel()
	back = KitBackButton.new()
	back.text = WARP_NAME
	back.icon = Kit.icon("cross")
	back.danger = true
	back.pressed.connect(_on_back)
	# Esc opens the game menu during a trip. It goes back to town from the report.
	back.esc_presses = false
	_layer.add_child(back)
	_link_focus()


func _build_die() -> void:
	die = RollBlock.new()
	die.hide()
	_layer.add_child(die)


func _build_strip() -> void:
	hud = TripHud.new(trip)
	_layer.add_child(hud)
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	hud.offset_top -= STRIP_FROM_BOTTOM
	hud.offset_bottom -= STRIP_FROM_BOTTOM
	hud.offset_left += STRIP_FROM_LEFT
	hud.offset_right += STRIP_FROM_LEFT


func _build_bag_panel() -> void:
	bag_panel = BagPanel.new(trip)
	bag_panel.wants_to_forget.connect(_on_wants_to_forget)
	_at_top_right(bag_panel, BAG_TOP)


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


func _build_roll_button() -> void:
	roll_button = KitButton.new()
	roll_button.kind = KitButton.Kind.PRIMARY
	roll_button.text = "Roll"
	roll_button.icon = Kit.icon("die")
	roll_button.pressed.connect(func() -> void: _day_chosen.emit(false))
	_layer.add_child(roll_button)
	roll_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	roll_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	roll_button.offset_top -= STRIP_FROM_BOTTOM
	roll_button.offset_bottom -= STRIP_FROM_BOTTOM
	roll_button.offset_left += ROLL_LEFT
	roll_button.offset_right += ROLL_LEFT
	roll_button.hide()
	camp_button = KitButton.new()
	camp_button.kind = KitButton.Kind.SMALL
	camp_button.text = CAMP_TEXT
	camp_button.icon = Kit.icon("food")
	camp_button.pressed.connect(func() -> void: _day_chosen.emit(true))
	_layer.add_child(camp_button)
	camp_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	camp_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	camp_button.offset_top -= STRIP_FROM_BOTTOM + CAMP_ABOVE
	camp_button.offset_bottom -= STRIP_FROM_BOTTOM + CAMP_ABOVE
	camp_button.offset_left += ROLL_LEFT
	camp_button.offset_right += ROLL_LEFT
	camp_button.hide()


func _build_map() -> void:
	map_button = KitButton.new()
	map_button.kind = KitButton.Kind.SMALL
	map_button.icon = Kit.icon("book")
	map_button.text = "Map"
	map_button.pressed.connect(_toggle_map)
	speed_button = KitButton.new()
	speed_button.kind = KitButton.Kind.SMALL
	speed_button.icon = Kit.icon("boot")
	speed_button.pressed.connect(_next_speed)
	Tips.attach(speed_button, "Speed", SPEED_TIP)
	_show_speed()
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.add_child(speed_button)
	top_row.add_child(map_button)
	_at_top_right(top_row, EDGE_TOP)
	map_panel = MapPanel.new(trip, board)
	map_panel.island.space_clicked.connect(_look_at_space)
	_at_top_right(map_panel, MAP_PANEL_TOP)
	map_panel.hide()


func _at_top_right(part: Control, top: float) -> void:
	_layer.add_child(part)
	part.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	part.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	part.offset_left -= EDGE_RIGHT
	part.offset_right -= EDGE_RIGHT
	part.offset_top += top
	part.offset_bottom += top


# Darkens the island under the report and the panels, and keeps clicks off the rest.
func _build_cover() -> void:
	_dim = ColorRect.new()
	_dim.color = DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	_layer.add_child(_dim)


func _build_leave_panel() -> void:
	leave_panel = KitPanel.new(LEAVE_HEADING, true)
	leave_panel.title.add_theme_color_override("font_color", Kit.BLOOD)
	leave_panel.custom_minimum_size.x = PANEL_WIDTH
	var words := Kit.text(LEAVE_WORDS % trip.person.display_name, PANEL_WIDTH, &"PaperLabel")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_panel.body.add_child(words)
	leave_cost = Kit.text("", PANEL_WIDTH, &"PaperLabel")
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


func _build_portal_panel() -> void:
	portal_panel = KitPanel.new(PORTAL_HEADING, true)
	portal_panel.custom_minimum_size.x = PANEL_WIDTH
	portal_words = Kit.text("", PANEL_WIDTH, &"PaperLabel")
	portal_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal_panel.body.add_child(portal_words)
	home_button = KitButton.new()
	home_button.text = GO_HOME_TEXT
	home_button.kind = KitButton.Kind.PRIMARY
	home_button.icon = Kit.icon("door")
	home_button.pressed.connect(func() -> void: _portal_answered.emit(true))
	portal_panel.body.add_child(home_button)
	stay_out_button = KitButton.new()
	stay_out_button.text = STAY_OUT_TEXT
	stay_out_button.kind = KitButton.Kind.SMALL
	stay_out_button.pressed.connect(func() -> void: _portal_answered.emit(false))
	portal_panel.body.add_child(stay_out_button)
	_centered(portal_panel)
	portal_panel.hide()


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


# Up, down, left and right follow the strip's columns, and its right edge leads to the bag.
func _link_strip() -> void:
	var stats := hud.stats
	var slot: Control = bag_panel.slots[0]
	_link(hud.hp_bar, roll_button, hud.food_bar, hud.hp_bar, stats[0])
	_link(hud.gold, hud.hp_bar, hud.gold, hud.gold, hud.food_bar)
	_link(hud.food_bar, hud.hp_bar, hud.food_bar, hud.gold, stats[2])
	_link(stats[0], roll_button, stats[2], hud.hp_bar, stats[1])
	_link(stats[1], roll_button, stats[3], stats[0], slot)
	_link(stats[2], stats[0], stats[2], hud.food_bar, stats[3])
	_link(stats[3], stats[1], stats[3], stats[2], slot)
	slot.focus_neighbor_left = slot.get_path_to(stats[1])
	for gear_slot: Control in bag_panel.slots:
		gear_slot.focus_neighbor_top = gear_slot.get_path_to(map_button)


func _link(part: Control, up: Control, down: Control, left: Control, right: Control) -> void:
	part.focus_neighbor_top = part.get_path_to(up)
	part.focus_neighbor_bottom = part.get_path_to(down)
	part.focus_neighbor_left = part.get_path_to(left)
	part.focus_neighbor_right = part.get_path_to(right)


## Roll sits in the middle of everything, and each panel keeps focus to itself while open.
func _link_focus() -> void:
	var slot: Control = bag_panel.slots[0]
	_link(back, back, roll_button, back, speed_button)
	_link(speed_button, speed_button, slot, back, map_button)
	_link(map_button, map_button, slot, speed_button, map_button)
	_link(roll_button, camp_button, hud.hp_bar, roll_button, slot)
	_link(camp_button, back, roll_button, camp_button, slot)
	_link_strip()
	_link(stay_button, stay_button, leave_button, stay_button, stay_button)
	_link(leave_button, stay_button, leave_button, leave_button, leave_button)
	_link(home_button, home_button, stay_out_button, home_button, home_button)
	_link(stay_out_button, home_button, stay_out_button, stay_out_button, stay_out_button)
