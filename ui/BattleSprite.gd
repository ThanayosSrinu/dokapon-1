class_name BattleSprite
extends Node2D
## A fighter standing in the battle arena: it plays the character sheet's
## animations and moves around. BattleScreen awaits its methods, so each one
## returns when its animation is over.

## The columns of a normal character sheet.
const CHARACTER_FRAMES := {
	"idle": [0, 1],
	"swing": [5, 6, 7],
	"cast": [13, 14, 15],
	"hurt": [20, 21],
	"down": [23],
}
## The Slime's sheet is a single row, used in every direction.
const SLIME_FRAMES := {
	"idle": [0, 1, 2, 1],
	"swing": [3, 4, 5],
	"cast": [3, 4, 5],
	"hurt": [6, 7],
	"down": [10, 11, 12, 13, 14],
}
const SLIME_COLUMNS := 15
## The rows of a character sheet that face right and left.
const ROW_FACING_RIGHT := 2
const ROW_FACING_LEFT := 6

const FRAME_TIME := 0.09
const IDLE_FRAME_TIME := 0.42
const RING_RADIUS := 26.0
const RING_SQUASH := 0.5
## How close an attacker stops from its target, in pixels.
const LUNGE_GAP := 56.0

var _sprite: Sprite2D
var _frames: Dictionary
var _ring_color := Color.TRANSPARENT
var _home := Vector2.ZERO
var _facing := 1.0
var _animation := "idle"
var _clock := 0.0
# Once true, the idle animation never comes back.
var _is_down := false


func setup(fighter: Fighter, home: Vector2, facing_right: bool) -> void:
	_home = home
	position = home
	_facing = 1.0 if facing_right else -1.0
	_ring_color = fighter.color
	_sprite = Sprite2D.new()
	_sprite.texture = fighter.sheet
	_sprite.scale = Vector2.ONE * GameArt.PIXEL
	# Lines the character's feet up with this node's position.
	_sprite.offset = Vector2(GameArt.CHARACTER_FRAME, GameArt.CHARACTER_FRAME) * 0.5 - GameArt.CHARACTER_FEET
	if fighter.sheet.get_height() == GameArt.CHARACTER_FRAME:
		_sprite.hframes = SLIME_COLUMNS
		_frames = SLIME_FRAMES
	else:
		_sprite.hframes = GameArt.CHARACTER_COLUMNS
		_sprite.vframes = GameArt.CHARACTER_ROWS
		_sprite.frame_coords.y = ROW_FACING_RIGHT if facing_right else ROW_FACING_LEFT
		_frames = CHARACTER_FRAMES
	add_child(_sprite)
	_show_column(_frames["idle"][0])
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if _animation == "idle":
		var frames: Array = _frames["idle"]
		_show_column(frames[int(_clock / IDLE_FRAME_TIME) % frames.size()])


func _draw() -> void:
	if _ring_color.a > 0.0:
		GameArt.draw_ground_ring(self, Vector2.ZERO, RING_RADIUS, _ring_color, 4.0, RING_SQUASH)


## Where text about this fighter should appear.
func get_head_position() -> Vector2:
	return position + Vector2(0, -56)


## Runs up to `target`, plays the swing, and stays there.
func lunge(target: Vector2) -> void:
	var stop := target - Vector2(_facing * LUNGE_GAP, 0)
	await _move_to(stop, 0.18, Tween.TRANS_QUAD)
	await _play("swing")


func go_home() -> void:
	await _move_to(_home, 0.2, Tween.TRANS_SINE)


func cast() -> void:
	await _play("cast")


func hurt() -> void:
	var tween := create_tween()
	var shove := Vector2(-_facing * 14.0, 0)
	tween.tween_property(self, "position", _home + shove, 0.07)
	tween.tween_property(self, "position", _home, 0.16)
	await _play("hurt")


func sidestep() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", _home + Vector2(-_facing * 42.0, -18.0), 0.14)
	tween.tween_property(self, "position", _home, 0.2)
	await tween.finished


func stumble() -> void:
	await _move_to(_home + Vector2(-_facing * 34.0, 0), 0.16, Tween.TRANS_SINE)
	await _move_to(_home, 0.18, Tween.TRANS_SINE)


func fall() -> void:
	_is_down = true
	await _play("down")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished


func run_away() -> void:
	await _move_to(_home + Vector2(-_facing * 320.0, 0), 0.5, Tween.TRANS_QUAD)


func cheer() -> void:
	var tween := create_tween()
	for bounce in 2:
		tween.tween_property(self, "position", _home + Vector2(0, -22), 0.14)
		tween.tween_property(self, "position", _home, 0.14)
	await tween.finished


func _move_to(target: Vector2, duration: float, transition: Tween.TransitionType) -> void:
	var tween := create_tween().set_trans(transition)
	tween.tween_property(self, "position", target, duration)
	await tween.finished


func _play(animation: String) -> void:
	_animation = animation
	for column: int in _frames[animation]:
		_show_column(column)
		await get_tree().create_timer(FRAME_TIME).timeout
	if not _is_down:
		_animation = "idle"


func _show_column(column: int) -> void:
	_sprite.frame_coords.x = column
