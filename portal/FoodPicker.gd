class_name FoodPicker
extends Control
## How much food to buy, as one bar filled by the share of their Max Food that is bought.
## The dark end costs more than the town has. A wooden - and + at the two ends say plainly that the amount can be changed:
## click or hold them, slide along the bar with the mouse, or step with left and right
## on the keys or the D-pad. Tips.attach() adds words.

signal picked(amount: int)

## The shortest the bar gets. It widens to fill the card.
const TRACK := 256.0
const ICON_GAP := 8.0
const BUTTON := 40.0
const BUTTON_GAP := 8.0
## Wooden button art keeps its corners this wide.
const BUTTON_EDGE := 12.0
const BAR_HEIGHT := 20.0
const BOUGHT_COLOR := Kit.SUPPLY
const SHINE_COLOR := Color(1.0, 0.85, 0.5)
const SHADE_COLOR := Color(0.78, 0.48, 0.14)
const SPARE_COLOR := Color(0.33, 0.23, 0.2, 0.25)
const TOO_DEAR_COLOR := Color(0.33, 0.23, 0.2, 0.7)
const EDGE := Color(0.33, 0.23, 0.2)
## Holding - or + steps once, waits this long, then keeps stepping.
const HOLD_WAIT := 0.35
const HOLD_STEP := 0.06

## Days of food bought.
var amount := 0
## The most they can carry.
var carry := 0
## The most the town can pay for, up to `carry`.
var afford := 0

# -1 or 1 while - or + is held down, else 0.
var _held := 0
var _repeat: Timer


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_repeat = Timer.new()
	_repeat.one_shot = true
	_repeat.timeout.connect(_on_repeat)
	add_child(_repeat)


func show_food(new_amount: int, new_carry: int, new_afford: int) -> void:
	amount = new_amount
	carry = new_carry
	afford = new_afford
	queue_redraw()


## Buys one day more, or with `step` -1 one less, as the + and - do.
func nudge(step: int) -> void:
	_pick(amount + step)


func _get_minimum_size() -> Vector2:
	return Vector2(BUTTON * 2.0 + BUTTON_GAP * 2.0 + Kit.ICON_SIZE + ICON_GAP + TRACK, BUTTON)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		accept_event()
		_pick(amount - 1)
	elif event.is_action_pressed("ui_right", true):
		accept_event()
		_pick(amount + 1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not event.pressed:
			_let_go()
			return
		grab_focus()
		var button := _button_at(event.position.x)
		if button != 0:
			_held = button
			queue_redraw()
			_pick(amount + button)
			_repeat.start(HOLD_WAIT)
		else:
			_pick(_amount_at(event.position.x))
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and _held == 0:
		accept_event()
		_pick(_amount_at(event.position.x))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_EXIT:
		_let_go()


func _let_go() -> void:
	_repeat.stop()
	if _held != 0:
		_held = 0
		queue_redraw()


func _on_repeat() -> void:
	if _held == 0:
		return
	_pick(amount + _held)
	_repeat.start(HOLD_STEP)


func _pick(wanted: int) -> void:
	var next := clampi(wanted, 0, afford)
	if next == amount:
		return
	amount = next
	Sound.play("hover")
	queue_redraw()
	picked.emit(amount)


# -1 over the -, 1 over the +, else 0.
func _button_at(x: float) -> int:
	if x < BUTTON:
		return -1
	if x >= size.x - BUTTON:
		return 1
	return 0


# How much food a click at `x` along the bar stands for. Left of the bar is none at all.
func _amount_at(x: float) -> int:
	return clampi(roundi((x - _left()) / _track() * carry), 0, carry)


func _left() -> float:
	return BUTTON + BUTTON_GAP + Kit.ICON_SIZE + ICON_GAP


# The bar's length: all the room between the bread and the +.
func _track() -> float:
	return maxf(size.x - _left() - BUTTON_GAP - BUTTON, TRACK)


# Where along the bar `days` of food ends, on the art's pixel grid.
func _edge_of(days: int) -> float:
	return Kit.snap(_track() * days / maxf(carry, 1))


func _draw() -> void:
	_draw_button(Rect2(0, 0, BUTTON, BUTTON), false, amount > 0, _held == -1)
	_draw_button(Rect2(size.x - BUTTON, 0, BUTTON, BUTTON), true, amount < afford, _held == 1)
	var middle := Kit.snap((BUTTON - Kit.ICON_SIZE) / 2.0)
	draw_texture(Kit.icon("food"), Vector2(BUTTON + BUTTON_GAP, middle))
	# One bar, filled by the share of their Max Food that is bought, so that it reads the
	# same whatever the Max Food is. The end the town can't pay for is darker.
	var top := Kit.snap((BUTTON - BAR_HEIGHT) / 2.0)
	var left := _left()
	var track := _track()
	draw_rect(Rect2(left - Kit.STEP, top - Kit.STEP, track + Kit.STEP * 2.0, BAR_HEIGHT + Kit.STEP * 2.0), EDGE)
	draw_rect(Rect2(left, top, track, BAR_HEIGHT), SPARE_COLOR)
	var dear := _edge_of(afford)
	if dear < track:
		draw_rect(Rect2(left + dear, top, track - dear, BAR_HEIGHT), TOO_DEAR_COLOR)
	var filled := _edge_of(amount)
	if filled > 0.0:
		draw_rect(Rect2(left, top, filled, BAR_HEIGHT), BOUGHT_COLOR)
		draw_rect(Rect2(left, top, filled, Kit.STEP), SHINE_COLOR)
		draw_rect(Rect2(left, top + BAR_HEIGHT - Kit.STEP, filled, Kit.STEP), SHADE_COLOR)
	Kit.draw_focus(self)


# A small wooden button with a - or a + drawn in art pixels. It sinks while held, and fades
# when it can go no further.
func _draw_button(rect: Rect2, plus: bool, usable: bool, down: bool) -> void:
	var art := "button_wood_down" if down else "button_wood"
	draw_style_box(Kit.box(art, BUTTON_EDGE), rect)
	var color := Kit.CREAM if usable else Color(Kit.CREAM, 0.35)
	var center := Kit.snap_point(rect.get_center() + Vector2(0, 2 if down else -1))
	draw_rect(Rect2(center.x - 8, center.y - 2, 16, 4), color)
	if plus:
		draw_rect(Rect2(center.x - 2, center.y - 8, 4, 16), color)
