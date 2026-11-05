class_name BoardCamera
extends Camera2D
## Camera for looking around the board.
##   - WASD / arrow keys: pan (Input Map actions camera_left/right/up/down)
##   - Mouse wheel: zoom toward the cursor
##   - Hold the right or middle mouse button and drag: pan

## Pan speed in pixels per second at zoom 1.
@export var pan_speed := 900.0
@export var min_zoom := 0.4
@export var max_zoom := 2.5
## Zoom multiplier for one notch of the mouse wheel.
@export var zoom_step := 1.1

var _dragging := false
var _focus_tween: Tween


func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction != Vector2.ZERO:
		_stop_focus()
		# Divide by zoom so panning feels equally fast at every zoom level.
		global_position += direction * pan_speed * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_toward_mouse(zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_toward_mouse(1.0 / zoom_step)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
				_stop_focus()
	elif event is InputEventMouseMotion and _dragging:
		global_position -= event.relative / zoom.x


## Smoothly moves the camera so `world_position` is in the center.
func focus_on(world_position: Vector2, duration := 0.4) -> void:
	_stop_focus()
	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "global_position", world_position, duration)


# Cancels a running focus_on(), so manual panning always wins.
func _stop_focus() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()


func _zoom_toward_mouse(factor: float) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(new_zoom, old_zoom):
		return
	_stop_focus()
	# Keep the world point under the cursor in place while zooming.
	var mouse_offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	var world_under_mouse := global_position + mouse_offset / old_zoom
	zoom = Vector2(new_zoom, new_zoom)
	global_position = world_under_mouse - mouse_offset / new_zoom
