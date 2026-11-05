class_name Confetti
extends Control
## Bright paper falling down the whole screen, for the winner. It draws square pixels
## to match the art, lets every click through and stops when the node is freed.

const PIECES := 90
const PIECE_SIZE := 6.0
const MIN_SPEED := 120.0
const MAX_SPEED := 240.0
const SWAY := 24.0

var _colors: Array[Color] = []
# Each piece, as [x, y, speed, phase of its sway, color].
var _pieces: Array[Array] = []
var _clock := 0.0


## `colors` are picked from at random for each piece.
func start(colors: Array[Color]) -> void:
	_colors = colors
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var area := get_viewport_rect().size
	for index in PIECES:
		_pieces.append([randf() * area.x, -randf() * area.y, randf_range(MIN_SPEED, MAX_SPEED),
				randf() * TAU, colors.pick_random()])


func _process(delta: float) -> void:
	_clock += delta
	var area := get_viewport_rect().size
	for piece in _pieces:
		piece[1] += piece[2] * delta
		if piece[1] > area.y:
			piece[0] = randf() * area.x
			piece[1] = -PIECE_SIZE
	queue_redraw()


func _draw() -> void:
	for piece in _pieces:
		var sway: float = sin(_clock * 2.0 + piece[3]) * SWAY
		# Pieces flip as they fall, so they narrow and widen.
		var width: float = PIECE_SIZE if sin(_clock * 6.0 + piece[3]) > 0.0 else PIECE_SIZE * 0.5
		var spot := Vector2(piece[0] + sway, piece[1]).round()
		draw_rect(Rect2(spot, Vector2(width, PIECE_SIZE)), piece[4])
