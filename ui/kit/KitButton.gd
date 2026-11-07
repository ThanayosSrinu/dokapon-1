class_name KitButton
extends BaseButton
## The game's button. It draws itself, so that lifting and sinking move only the
## picture: the area that takes clicks stays still, and a container can't undo the
## movement. Hovering and having focus look the same, and hovering takes the focus,
## so only one button is ever lit, whichever of mouse, keys or controller is in use.

enum Kind {
	## The one main action on a screen. Rule U1: use only one per screen.
	PRIMARY,
	NORMAL,
	SMALL,
}
## How a button looks. LIVE follows what the player does; the gallery forces the rest.
enum Look { LIVE, REST, HOT, DOWN, OFF, FOCUS }

## How far the face stands above its shadow.
const DEPTH := 4.0
const LIFT := -2.0
const MOVE_SECONDS := 0.1
const SHAKE_SECONDS := 0.3
const SHAKE_SIZE := 4.0
const ICON_GAP := 10.0
const FOCUS_GROWTH := 6.0
const EDGE := 16.0
const TEXT_SHADOW := Vector2(0, 2)
## The face's lip takes up room at the bottom, so its contents sit a little higher.
const LIP := 3.0
const HEIGHTS := {Kind.PRIMARY: 84.0, Kind.NORMAL: 60.0, Kind.SMALL: 46.0}
const PADDING := {Kind.PRIMARY: 40.0, Kind.NORMAL: 24.0, Kind.SMALL: 18.0}

@export var text := "":
	set(value):
		text = value
		accessibility_name = value
		update_minimum_size()
		queue_redraw()
@export var icon: Texture2D:
	set(value):
		icon = value
		update_minimum_size()
		queue_redraw()
@export var kind := Kind.NORMAL:
	set(value):
		kind = value
		update_minimum_size()
		queue_redraw()
## Stains the button red, for an action that costs the player something.
var danger := false:
	set(value):
		danger = value
		queue_redraw()
## Shows this button as the one picked from a row, such as a speed.
var lit := false:
	set(value):
		lit = value
		queue_redraw()
## Puts the contents at the left edge instead of the middle.
@export var left_aligned := false
## The sound of being pressed.
@export var press_sound := "click"

var forced_look := Look.LIVE:
	set(value):
		forced_look = value
		_rest_at(_offset_for(_chosen_look()))
		queue_redraw()

## The face's height above or below where it rests.
var shown_offset := 0.0:
	set(value):
		shown_offset = Kit.snap(value)
		queue_redraw()
var shown_shake := 0.0:
	set(value):
		shown_shake = Kit.snap(value)
		queue_redraw()

var _mouse_inside := false
var _held := false
var _move: Tween


func _init() -> void:
	# Sound clicks every button by itself, except ones already marked. These choose
	# their own sound, and only sound when it means something.
	set_meta("clicks", true)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	button_down.connect(_on_held.bind(true))
	button_up.connect(_on_held.bind(false))
	pressed.connect(func() -> void: Sound.play(press_sound))


func _gui_input(event: InputEvent) -> void:
	# Rule U7: even a button that can't be used answers.
	if disabled and (event.is_action_pressed("ui_accept")
			or event is InputEventMouseButton and event.pressed):
		deny()
		accept_event()


func _get_minimum_size() -> Vector2:
	return Vector2(PADDING[kind] * 2.0 + _contents_width(), HEIGHTS[kind])


func _draw() -> void:
	var look := _chosen_look()
	var height := size.y - DEPTH
	var left := shown_shake
	if look != Look.DOWN:
		draw_style_box(Kit.box("button_shadow", EDGE), Rect2(left, DEPTH, size.x, height))
	var face := Rect2(left, shown_offset, size.x, height)
	var art := _face_art(look)
	draw_style_box(Kit.danger_box(art, EDGE) if danger and look != Look.OFF else Kit.box(art, EDGE), face)
	_draw_contents(face, look)
	if look != Look.OFF and (look == Look.FOCUS or forced_look == Look.LIVE and PadInput.shows_focus(self)):
		draw_style_box(Kit.box("focus", 12.0), face.grow(FOCUS_GROWTH))


## Plays the "you can't do that" answer.
func deny() -> void:
	Sound.play("deny")
	var tween := create_tween().set_ignore_time_scale(true)
	var seconds := SHAKE_SECONDS / 4.0
	tween.tween_property(self, "shown_shake", SHAKE_SIZE, seconds)
	tween.tween_property(self, "shown_shake", -SHAKE_SIZE, seconds)
	tween.tween_property(self, "shown_shake", SHAKE_SIZE / 2.0, seconds)
	tween.tween_property(self, "shown_shake", 0.0, seconds)


## Turns the button off, with the reason as its tip. An empty reason turns it back on.
func block(reason: String) -> void:
	disabled = reason != ""
	if disabled:
		Tips.attach(self, "Not yet", reason)
	else:
		Tips.detach(self)


func _chosen_look() -> Look:
	if forced_look != Look.LIVE:
		return forced_look
	if disabled:
		return Look.OFF
	if _held:
		return Look.DOWN
	if _mouse_inside or PadInput.shows_focus(self):
		return Look.HOT
	return Look.REST


func _face_art(look: Look) -> String:
	if look == Look.OFF:
		return "button_stone"
	var family := "button_primary" if kind == Kind.PRIMARY or lit else "button_wood"
	match look:
		Look.HOT, Look.FOCUS:
			return family + "_hot"
		Look.DOWN:
			return family + "_down"
	return family


func _offset_for(look: Look) -> float:
	match look:
		Look.HOT, Look.FOCUS:
			return LIFT
		Look.DOWN:
			return DEPTH
	return 0.0


func _text_size() -> int:
	return Kit.BIG_TEXT if kind == Kind.PRIMARY else Kit.SMALL_TEXT


func _text_width() -> float:
	return GameArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_size()).x


func _contents_width() -> float:
	var width := _text_width()
	if icon != null:
		width += Kit.ICON_SIZE + (ICON_GAP if text != "" else 0.0)
	return width


func _draw_contents(face: Rect2, look: Look) -> void:
	var left: float = face.position.x + PADDING[kind]
	if not left_aligned:
		left = face.position.x + (face.size.x - _contents_width()) / 2.0
	left = Kit.snap(left)
	var middle := face.position.y + (face.size.y - LIP) / 2.0
	if icon != null:
		var tint := Color(1, 1, 1, 0.45) if look == Look.OFF else Color.WHITE
		draw_texture(icon, Vector2(left, Kit.snap(middle - Kit.ICON_SIZE / 2.0)), tint)
		left += Kit.ICON_SIZE + ICON_GAP
	if text == "":
		return
	var font: Font = GameArt.FONT
	var font_size := _text_size()
	var base := Kit.snap(middle - font.get_height(font_size) / 2.0 + font.get_ascent(font_size))
	var spot := Vector2(left, base)
	var dark_text := (kind == Kind.PRIMARY or lit) and look != Look.OFF
	if not dark_text:
		draw_string(font, spot + TEXT_SHADOW, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Kit.INK)
	var color := Kit.INK if dark_text else Kit.MUTED if look == Look.OFF else Kit.CREAM
	draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _refresh() -> void:
	_rest_at(_offset_for(_chosen_look()))
	queue_redraw()


func _rest_at(offset: float) -> void:
	if _move != null:
		_move.kill()
	if not is_inside_tree():
		shown_offset = offset
		return
	_move = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_ignore_time_scale(true)
	_move.tween_property(self, "shown_offset", offset, MOVE_SECONDS)


func _on_mouse_entered() -> void:
	_mouse_inside = true
	if not has_focus():
		Sound.play("hover")
		grab_focus()
	_refresh()


func _on_mouse_exited() -> void:
	_mouse_inside = false
	_refresh()


func _on_held(held: bool) -> void:
	_held = held
	_refresh()
