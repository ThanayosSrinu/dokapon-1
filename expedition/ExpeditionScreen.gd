class_name ExpeditionScreen
extends Node2D
## One trip on screen, from the far side of the Portal to the report. The rules stay in
## Expedition.gd: this script runs its steps in order and shows what came back, so the
## same seed gives the same trip as tools/sim_expedition.tscn.
##
## Speed is Engine.time_scale, so the buttons work on everything at once, fights too.
## Anything that must still answer at ×0, such as the kit's buttons, ignores it.

const TOWN := "res://town/TownScreen.tscn"
const GAME_OVER := "res://town/GameOverScreen.tscn"
const BOARD: PackedScene = preload("res://maps/WorldMap.tscn")
const TOKEN: PackedScene = preload("res://player/Player.tscn")

## The speed buttons, in order.
const SPEEDS: Array[float] = [0.0, 1.0, 3.0]
const SPEED_WORDS: Array[String] = ["x0", "x1", "x3"]
const SPEED_FROM_RIGHT := 24.0
const SPEED_TOP := 24.0
const SPEED_GAP := 8
const STRIP_FROM_BOTTOM := 12.0
const STRIP_FROM_LEFT := 28.0
## Keeps the fight's window clear of the strip and the bag.
const FIGHT_ROOM_BELOW := 44.0
const FIGHT_ROOM_RIGHT := 40.0
const BAG_TOP := 128.0
const NEWS_TOP := 24.0
const NEWS_WIDTH := 600.0
const ORDERS_TOP := 80.0
const ORDERS_PANEL_TOP := 136.0
## How far right of what matters the camera looks with the orders open, so the panel covers
## less of it.
const ORDERS_VIEW_SHIFT := Vector2(240, 0)
const ORDERS_VIEW_SECONDS := 0.4
## How long a spoken line stays up, in real time so it can be read at x3.
const SPEECH_MS := 2200
## What the Orders button says for each order.
const ORDER_WORDS := {Expedition.Order.ROAM: "Explore", Expedition.Order.HOME: "Return home"}

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
const WARP_LINE := "Warp Stone, take me home!"
const WARP_CAMERA_SECONDS := 0.4
const WARP_LOSS_DELAY := 0.5
const WARP_LINE_SECONDS := 1.4
## Diary lines the news leaves out, because the die, the fight screen, the bubble or the
## Orders button has already shown them.
const SHOWN_ELSEWHERE: Array[String] = ["roll", "fight", "say", "recall"]
## What they say as a due day comes close, at each step of TownData.Alert.
const SAY_DEBT := {TownData.Alert.WARN: "My lord, the %s is due in %s!",
		TownData.Alert.ALARM: "The %s is due in %s! Call me home!"}
const SAY_DEBT_TODAY := "The %s is due today, my lord!"
const SAY_DEBT_MISSED := "My lord... we missed the %s."
const OUT_WORDS := "%s can't work for %s."

## The speed to start at, so a player who likes ×3 keeps it from trip to trip.
static var chosen_speed := 1.0
## Ids of the items the bot must leave alone, kept from trip to trip.
static var items_off_auto: Array[String] = []
## True when the player chooses what is worn. Tests turn it off, to match the rules.
static var gear_by_hand := true
## Above 0, the seed of the next trip. For tests.
static var next_seed := 0
## Above 0, the day the next trip is called home. For tests.
static var next_recall_day := 0

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
## Opens the orders, and says which one is in force.
var orders_button: KitButton
var orders: OrdersPanel
var zone_overlay: ZoneOverlay
## Points at the Orders button once they ask to come home.
var orders_arrow: KitArrow

var _motes: PortalMotes
var _layer: Control
var _dim: ColorRect
var _news_words: Label
var _speed_row: HBoxContainer
# The speed in use, kept while the leave panel holds time still.
var _speed := 1.0
# The lines waiting to be spoken.
var _speech: Array[String] = []
# When the line being spoken ends, in real milliseconds.
var _speech_ends := 0
# The camera's zoom from before the orders opened.
var _zoom_before := 1
# The strongest warning about money that they have spoken on this trip.
var _said_alert := TownData.Alert.NONE


func _ready() -> void:
	var town := TownData.current()
	trip = Expedition.new(town.going, town.stage, next_seed)
	trip.recall_day = next_recall_day
	trip.by_hand = gear_by_hand
	trip.player.auto_off = items_off_auto
	trip.said.connect(func(line: String) -> void: _speech.append(line))
	_build_world(town)
	_build_ui(town)
	_set_speed(chosen_speed if chosen_speed > 0.0 else 1.0)
	Sound.music("board")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()
	_play()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	_update_speech()
	_update_bag_panel()


# Keeps the bag shut during fights, and points its box at the space under the mouse.
func _update_bag_panel() -> void:
	bag_panel.locked = battle_screen.visible or trip.is_over()
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
	hud.refresh()
	_warn_of_debts()
	_refresh_orders()
	await _show_news(read_from)
	if can_move:
		await _walk()
		read_from = trip.diary.size()
		var before := _purse()
		trip.land()
		_play_landing_sound(before)
		hud.refresh()
		_refresh_orders()
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
	_watch_token()
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
	# The warp has already taken them.
	if trip.ending != Expedition.Ending.WARPED:
		_put_hero_on_board()
		Sound.play("magic" if trip.ending == Expedition.Ending.HOME else "whoosh")
		await hero.dissolve(0.0, 1.0, DISSOLVE_SECONDS, true)
	var town := TownData.current()
	var gold_before := town.gold
	town.bring_home(trip)
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
	_close_orders(false)
	bag_panel.hide()
	orders_button.hide()
	_drop_orders_arrow()
	zone_overlay.target_zone = ""
	_speech.clear()
	bubble.hide()
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
		if not SHOWN_ELSEWHERE.has(line["kind"]):
			lines.append(line["text"])
	_set_news(" ".join(lines))
	await _pause(NEWS_SECONDS if not lines.is_empty() else QUIET_SECONDS)


func _set_news(words: String) -> void:
	_news_words.text = words
	var had_news := news.visible
	news.visible = words != ""
	if news.visible and not had_news:
		news.play_open()


# --- Speech -----------------------------------------------------------------

# One line at a time, over their head, and none on top of a fight.
func _update_speech() -> void:
	if not token.visible or report != null:
		return
	if battle_screen.visible:
		bubble.hide()
		return
	var head := get_viewport().get_canvas_transform() * (token.global_position + HEAD)
	if bubble.visible and Time.get_ticks_msec() >= _speech_ends:
		bubble.hide()
	if bubble.visible:
		bubble.keep_above(head, get_viewport_rect())
	elif not _speech.is_empty() and not die.visible:
		bubble.say(_speech.pop_front(), head, get_viewport_rect())
		_speech_ends = Time.get_ticks_msec() + SPEECH_MS


# Each step of the warning is spoken once on a trip, however it began, so a lord who sent
# them off knowing the date still hears it.
func _warn_of_debts() -> void:
	var town := TownData.current()
	var today := town.day + trip.day
	var level := town.alert(today)
	if level <= _said_alert:
		return
	_said_alert = level
	var debt := town.next_debt()
	var left: int = debt["due"] - today
	if left > 0:
		trip.say(SAY_DEBT[level] % [debt["what"], TownData.days_words(left)])
	else:
		trip.say((SAY_DEBT_TODAY if left == 0 else SAY_DEBT_MISSED) % debt["what"])


# --- Orders -----------------------------------------------------------------

func _toggle_orders() -> void:
	if orders.visible:
		_close_orders()
	else:
		_open_orders()


# The view pulls back with the zones on it. The trip keeps running.
func _open_orders() -> void:
	orders.refresh()
	bag_panel.hide()
	orders.show()
	orders.play_open()
	zone_overlay.open = true
	_zoom_before = camera.zoom_index()
	camera.set_zoom_index(0, ORDERS_VIEW_SECONDS)
	camera.focus_on(token.global_position + ORDERS_VIEW_SHIFT, ORDERS_VIEW_SECONDS)
	orders.home_button.grab_focus()
	_refresh_orders()


func _close_orders(take_focus := true) -> void:
	if not orders.visible:
		return
	orders.hide()
	bag_panel.show()
	zone_overlay.open = false
	camera.set_zoom_index(_zoom_before, ORDERS_VIEW_SECONDS)
	camera.follow(token)
	if take_focus:
		orders_button.grab_focus()
	_refresh_orders()


# Lights a zone, and brings it into view if it was pointed at from the panel.
func _point_at_zone(id: String) -> void:
	zone_overlay.lit_zone = id
	orders.island.lit_zone = id
	if id != "":
		camera.focus_on(zone_overlay.middle_of(id) + ORDERS_VIEW_SHIFT, ORDERS_VIEW_SECONDS)


func _give_order(order: Expedition.Order, zone_id: String) -> void:
	trip.give_order(order, zone_id)
	hud.refresh()
	_close_orders()
	_refresh_orders()


func _refresh_orders() -> void:
	var zone_order := trip.order == Expedition.Order.ZONE
	var words: String = trip.order_zone["name"] if zone_order else ORDER_WORDS[trip.order]
	orders_button.text = "Orders: %s" % words
	zone_overlay.target_zone = trip.order_zone["id"] if zone_order else ""
	if orders.visible:
		orders.refresh()
	var called := trip.asked_home or _said_alert != TownData.Alert.NONE
	var waiting := called and trip.order != Expedition.Order.HOME and not orders.visible
	if waiting and orders_arrow == null:
		orders_arrow = KitArrow.new(orders_button, KitArrow.Side.LEFT)
		_layer.get_parent().add_child(orders_arrow)
	elif not waiting:
		_drop_orders_arrow()


func _drop_orders_arrow() -> void:
	if orders_arrow != null:
		orders_arrow.queue_free()
		orders_arrow = null


# The camera goes back to them, unless the whole island is being looked at.
func _watch_token() -> void:
	if not orders.visible:
		camera.follow(token)


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
		Screens.go(GAME_OVER if TownData.current().lost() else TOWN)
	elif orders.visible:
		_close_orders()
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
# a walk or a fight, never finishes. Nobody dies here: no red, and they stay whole until
# the light takes them.
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
	board.map_file = town.stage.map_file
	board.print_on_ready = false
	board.clickable = false
	add_child(board)
	zone_overlay = ZoneOverlay.new(trip.map, board)
	zone_overlay.zone_clicked.connect(func(id: String) -> void: _give_order(Expedition.Order.ZONE, id))
	zone_overlay.zone_pointed.connect(func(id: String) -> void:
			zone_overlay.lit_zone = id
			orders.island.lit_zone = id)
	add_child(zone_overlay)
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
	battle_screen.room_below = FIGHT_ROOM_BELOW
	battle_screen.room_right = FIGHT_ROOM_RIGHT
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
	_build_bag_panel()
	_build_news()
	_build_speed_row()
	_build_orders()
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
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	hud.offset_top -= STRIP_FROM_BOTTOM
	hud.offset_bottom -= STRIP_FROM_BOTTOM
	hud.offset_left += STRIP_FROM_LEFT
	hud.offset_right += STRIP_FROM_LEFT


func _build_bag_panel() -> void:
	bag_panel = BagPanel.new(trip)
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


func _build_orders() -> void:
	orders_button = KitButton.new()
	orders_button.kind = KitButton.Kind.SMALL
	orders_button.icon = Kit.icon("book")
	orders_button.text = "Orders: %s" % ORDER_WORDS[trip.order]
	orders_button.pressed.connect(_toggle_orders)
	_at_top_right(orders_button, ORDERS_TOP)
	orders = OrdersPanel.new(trip, zone_overlay)
	orders.chosen.connect(_give_order)
	orders.zone_pointed.connect(_point_at_zone)
	_at_top_right(orders, ORDERS_PANEL_TOP)
	orders.hide()


func _at_top_right(part: Control, top: float) -> void:
	_layer.add_child(part)
	part.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	part.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	part.offset_left -= SPEED_FROM_RIGHT
	part.offset_right -= SPEED_FROM_RIGHT
	part.offset_top += top
	part.offset_bottom += top


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


# Up, down, left and right follow the strip's columns, and its right edge leads to the bag.
func _link_strip() -> void:
	var stats := hud.stats
	var slot: Control = bag_panel.slots[0]
	_link(hud.hp_bar, orders_button, hud.food_bar, hud.hp_bar, stats[0])
	_link(hud.gold, hud.hp_bar, hud.gold, hud.gold, hud.food_bar)
	_link(hud.food_bar, hud.hp_bar, hud.food_bar, hud.gold, stats[2])
	_link(stats[0], orders_button, stats[2], hud.hp_bar, stats[1])
	_link(stats[1], orders_button, stats[3], stats[0], slot)
	_link(stats[2], stats[0], stats[2], hud.food_bar, stats[3])
	_link(stats[3], stats[1], stats[3], stats[2], slot)
	slot.focus_neighbor_left = slot.get_path_to(stats[1])


func _link(part: Control, up: Control, down: Control, left: Control, right: Control) -> void:
	part.focus_neighbor_top = part.get_path_to(up)
	part.focus_neighbor_bottom = part.get_path_to(down)
	part.focus_neighbor_left = part.get_path_to(left)
	part.focus_neighbor_right = part.get_path_to(right)


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
		part.focus_neighbor_bottom = part.get_path_to(orders_button)
	orders_button.focus_neighbor_top = orders_button.get_path_to(speed_buttons[1])
	orders_button.focus_neighbor_bottom = orders_button.get_path_to(hud.hp_bar)
	orders_button.focus_neighbor_left = orders_button.get_path_to(orders_button)
	orders_button.focus_neighbor_right = orders_button.get_path_to(orders_button)
	_link_strip()
	for part: Control in [stay_button, leave_button]:
		for way: StringName in [&"focus_neighbor_left", &"focus_neighbor_right"]:
			part.set(way, part.get_path_to(part))
	stay_button.focus_neighbor_top = stay_button.get_path_to(stay_button)
	stay_button.focus_neighbor_bottom = stay_button.get_path_to(leave_button)
	leave_button.focus_neighbor_top = leave_button.get_path_to(stay_button)
	leave_button.focus_neighbor_bottom = leave_button.get_path_to(leave_button)
