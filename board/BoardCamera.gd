class_name BoardCamera
extends Camera2D
## Camera for looking around the board.
##   - WASD / arrow keys: pan (Input Map actions camera_left/right/up/down)
##   - Mouse wheel: zoom toward the cursor, through ZOOM_LEVELS
##   - Hold the right or middle mouse button and drag: pan
##   - follow(): keeps a node (a player token) in the center until the player
##     pans by hand
## The art is drawn at 2x, so zoom only goes to levels that keep every pixel of
## it the same size: at 1.5x an art pixel is 3 screen pixels, never 2.7.

## Pan speed in pixels per second at zoom 1.
@export var pan_speed := 900.0
## Seconds a change of zoom takes.
@export var zoom_duration := 0.15
## How quickly the camera catches up with a followed node. Higher is snappier.
@export var follow_speed := 6.0

const ZOOM_LEVELS: Array[float] = [0.5, 1.0, 1.5, 2.0, 3.0]

## The part of the world the camera may show. Set by GameController.
var world_limit := Rect2()

var _dragging := false
var _focus_tween: Tween
var _zoom_tween: Tween
# Which of ZOOM_LEVELS is in use.
var _zoom_index := 1
# The node being followed, or null.
var _follow_target: Node2D


func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction != Vector2.ZERO:
		_stop_focus()
		stop_following()
		# Divide by zoom so panning feels equally fast at every zoom level.
		global_position += direction * pan_speed * delta / zoom.x
	elif _follow_target != null:
		# Move a share of the remaining distance each frame. Using exp() makes
		# the speed the same at any frame rate.
		var weight := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(_follow_target.global_position, weight)
	_stay_in_world()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_toward_mouse(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_toward_mouse(-1)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
				_stop_focus()
				if event.pressed:
					stop_following()
	elif event is InputEventMouseMotion and _dragging:
		global_position -= event.relative / zoom.x


## Smoothly moves the camera so `world_position` is in the center.
func focus_on(world_position: Vector2, duration := 0.4) -> void:
	_stop_focus()
	stop_following()
	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "global_position", world_position, duration)


## Keeps `target` in the center of the screen until the player pans by hand,
## focus_on() is called, or stop_following() is called.
func follow(target: Node2D) -> void:
	_stop_focus()
	_follow_target = target


func stop_following() -> void:
	_follow_target = null


# Cancels a running focus_on(), so manual panning always wins.
func _stop_focus() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()


## Moves smoothly to one of ZOOM_LEVELS. Used for the view of the whole island.
func set_zoom_index(index: int, duration := 0.6) -> void:
	_zoom_index = clampi(index, 0, ZOOM_LEVELS.size() - 1)
	_kill_zoom()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * ZOOM_LEVELS[_zoom_index], duration)


## A short shake, for moments that deserve weight.
func shake(strength := 6.0, duration := 0.25) -> void:
	var tween := create_tween()
	tween.tween_method(func(left: float) -> void:
			offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * left).round(),
			1.0, 0.0, duration)
	tween.tween_callback(func() -> void: offset = Vector2.ZERO)


func _kill_zoom() -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()


func _stay_in_world() -> void:
	if world_limit.has_area():
		var half_view := get_viewport_rect().size * 0.5 / zoom.x
		var area := world_limit.grow_individual(-half_view.x, -half_view.y, -half_view.x, -half_view.y)
		global_position = global_position.clamp(area.position, area.end)


func _zoom_toward_mouse(direction: int) -> void:
	var index := clampi(_zoom_index + direction, 0, ZOOM_LEVELS.size() - 1)
	if index == _zoom_index:
		return
	_zoom_index = index
	_stop_focus()
	_kill_zoom()
	# Keep the world point under the cursor in place while zooming.
	var mouse_offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	var world_under_mouse := global_position + mouse_offset / zoom.x
	var new_zoom := ZOOM_LEVELS[index]
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(func(level: float) -> void:
			zoom = Vector2(level, level)
			global_position = world_under_mouse - mouse_offset / level,
			zoom.x, new_zoom, zoom_duration)
