extends CanvasLayer
## The kit's tooltips. Registered as the "Tips" autoload. Godot's own tooltips only
## follow the mouse. These also open when a control gets focus, so that a keyboard
## or controller can read the same details.
##     Tips.attach(control, "Strength", "7 out of 10")

const DELAY := 0.25
const FADE_SECONDS := 0.12
const RISE := 6.0
const WIDTH := 280.0
const MARGIN := 8.0
const GAP := 10.0
const META := &"kit_tip"

var _card: PanelContainer
var _title: Label
var _body: Label
var _owner: Control
var _timer: Timer
var _fade: Tween


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parts := build_card("", "")
	_card = parts[0]
	_title = parts[1]
	_body = parts[2]
	_card.hide()
	add_child(_card)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.ignore_time_scale = true
	_timer.wait_time = DELAY
	_timer.timeout.connect(_open)
	add_child(_timer)


func _exit_tree() -> void:
	Kit.forget()
	BoardArt.forget()


## A tooltip card, as [the card, its title, its text]. The gallery shows one by itself.
func build_card(title: String, body: String) -> Array:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PaperPanel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var title_label := Kit.text(title, WIDTH, &"PaperTitle")
	column.add_child(title_label)
	var body_label := Kit.text(body, WIDTH, &"PaperLabel")
	column.add_child(body_label)
	title_label.visible = title != ""
	return [card, title_label, body_label]


## Gives `control` a tip, or changes the one it has.
func attach(control: Control, title: String, body: String) -> void:
	var known := control.has_meta(META)
	control.set_meta(META, [title, body])
	if control == _owner:
		_fill()
	if known:
		return
	control.mouse_entered.connect(_begin.bind(control))
	control.focus_entered.connect(_begin.bind(control))
	control.mouse_exited.connect(_end.bind(control))
	control.focus_exited.connect(_end.bind(control))
	control.tree_exiting.connect(_close_if_owned_by.bind(control))


## Takes a tip away.
func detach(control: Control) -> void:
	# Marking one that never had a tip would stop attach() from ever hooking it up.
	if not control.has_meta(META):
		return
	control.set_meta(META, [])
	_close_if_owned_by(control)


## Closes the tip straight away. Used when a screen changes.
func close() -> void:
	_timer.stop()
	_owner = null
	_card.hide()


func showing() -> bool:
	return _card.visible


func shown_text() -> String:
	return _body.text


func _begin(control: Control) -> void:
	if control.get_meta(META).is_empty():
		return
	_owner = control
	_timer.start()


func _end(control: Control) -> void:
	# Still pointed at or still focused means the tip stays.
	if control != _owner:
		return
	if control.is_inside_tree() and (control.has_focus()
			or control.get_global_rect().has_point(control.get_global_mouse_position())):
		return
	close()


func _close_if_owned_by(control: Control) -> void:
	if control == _owner:
		close()


func _fill() -> void:
	var words: Array = _owner.get_meta(META)
	if words.is_empty():
		return
	_title.text = words[0]
	_title.visible = words[0] != ""
	_body.text = words[1]


func _open() -> void:
	if not is_instance_valid(_owner) or not _owner.is_visible_in_tree():
		return
	_fill()
	_card.reset_size()
	_card.show()
	_card.reset_size()
	var box := _owner.get_global_rect()
	var screen := _card.get_viewport_rect().size
	var spot := Vector2(box.get_center().x - _card.size.x / 2.0, box.position.y - _card.size.y - GAP)
	if spot.y < MARGIN:
		spot.y = box.end.y + GAP
	spot.x = clampf(spot.x, MARGIN, screen.x - _card.size.x - MARGIN)
	spot = Kit.snap_point(spot)
	if _fade != null:
		_fade.kill()
	_card.modulate.a = 0.0
	_card.position = spot + Vector2(0, RISE)
	_fade = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_fade.tween_property(_card, "modulate:a", 1.0, FADE_SECONDS)
	_fade.tween_property(_card, "position", spot, FADE_SECONDS)
