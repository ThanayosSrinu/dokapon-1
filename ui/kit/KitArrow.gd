class_name KitArrow
extends Node2D
## The bouncing arrow that shows a new player where to go next (rule U6). It follows
## its target around, and hides while the target is hidden.
##     add_child(KitArrow.new(tavern_button, KitArrow.Side.ABOVE))

enum Side { ABOVE, BELOW, LEFT, RIGHT }

const ART: Texture2D = preload("res://assets/custom/kit/arrow.png")
const GAP := 26.0
const BOUNCE := 8.0
const BOUNCE_SPEED := 6.0
## The art points down. Quarter turns keep its pixels square.
const TURNS := {Side.ABOVE: 0.0, Side.BELOW: PI, Side.LEFT: -PI / 2.0, Side.RIGHT: PI / 2.0}
const AWAY := {Side.ABOVE: Vector2.UP, Side.BELOW: Vector2.DOWN, Side.LEFT: Vector2.LEFT,
		Side.RIGHT: Vector2.RIGHT}

var target: Control
var side := Side.ABOVE


func _init(point_at: Control = null, from_side := Side.ABOVE) -> void:
	target = point_at
	side = from_side
	z_index = 50
	rotation = TURNS[side]


func _process(_delta: float) -> void:
	visible = is_instance_valid(target) and target.is_visible_in_tree()
	if not visible:
		return
	var box := target.get_global_rect()
	var away: Vector2 = AWAY[side]
	# Real time, so it still bounces when the game is stopped.
	var clock := Time.get_ticks_msec() / 1000.0
	var edge := box.get_center() + box.size * away / 2.0
	global_position = Kit.snap_point(edge + away * (GAP + absf(sin(clock * BOUNCE_SPEED)) * BOUNCE))


func _draw() -> void:
	draw_texture(ART, -ART.get_size() / 2.0)
