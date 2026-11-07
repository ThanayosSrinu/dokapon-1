class_name FoodPicker
extends Control
## How much food to buy, as one mark for each day they can carry, so that a long trip looks
## long (rule U3). Filled marks are bought, and the dark ones at the end cost more than the
## town has. A wooden - and + at the two ends say plainly that the amount can be changed:
## click or hold them, slide along the marks with the mouse, or step with left and right
## on the keys or the D-pad. Tips.attach() adds words.

signal picked(amount: int)

## The narrowest the marks' track gets. It widens to fill the card.
const TRACK := 256.0
const MARK_HEIGHT := 22.0
const ICON_GAP := 8.0
const BUTTON := 40.0
const BUTTON_GAP := 8.0
## Wooden button art keeps its corners this wide.
const BUTTON_EDGE := 12.0
## The room each mark gets, however many there are. The most anyone can carry must fit.
const WIDEST_STEP := 14.0
const THINNEST_STEP := 4.0
## Wide marks get a wider gap.
const WIDE_GAP := 4.0
const THIN_GAP := 2.0
const BOUGHT_COLOR := Kit.SUPPLY
const SPARE_COLOR := Color(0.33, 0.23, 0.2, 0.3)
const TOO_DEAR_COLOR := Color(0.33, 0.23, 0.2, 0.8)
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


# How much food the mark under `x` stands for. Left of the first mark is none at all.
func _amount_at(x: float) -> int:
	return clampi(ceili((x - _left()) / _step()), 0, carry)


func _left() -> float:
	return BUTTON + BUTTON_GAP + Kit.ICON_SIZE + ICON_GAP


# The room for one mark, in whole art pixels.
func _step() -> float:
	var track := maxf(size.x - _left() - BUTTON_GAP - BUTTON, TRACK)
	var room := track / maxi(carry, 1)
	return clampf(floorf(room / Kit.STEP) * Kit.STEP, THINNEST_STEP, WIDEST_STEP)


func _draw() -> void:
	_draw_button(Rect2(0, 0, BUTTON, BUTTON), false, amount > 0, _held == -1)
	_draw_button(Rect2(size.x - BUTTON, 0, BUTTON, BUTTON), true, amount < afford, _held == 1)
	var middle := Kit.snap((BUTTON - Kit.ICON_SIZE) / 2.0)
	draw_texture(Kit.icon("food"), Vector2(BUTTON + BUTTON_GAP, middle))
	var top := Kit.snap((BUTTON - MARK_HEIGHT) / 2.0)
	var step := _step()
	var width := step - (WIDE_GAP if step >= WIDEST_STEP else THIN_GAP)
	for day in carry:
		var mark := Rect2(_left() + day * step, top, width, MARK_HEIGHT)
		draw_rect(mark, BOUGHT_COLOR if day < amount else (SPARE_COLOR if day < afford else TOO_DEAR_COLOR))
		if day < amount:
			draw_rect(Rect2(mark.position.x, top + MARK_HEIGHT - Kit.STEP, width, Kit.STEP), EDGE)
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
