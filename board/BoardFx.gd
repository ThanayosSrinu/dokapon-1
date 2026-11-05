class_name BoardFx
extends RefCounted
## Little one-shot effects in the world: dust, smoke and sparkles. Each one is a
## short-lived Sprite2D that frees itself.

enum Kind { DUST, SMOKE, SPARKLE }

const FRAMES := 4
const FRAME_SIZE := 16


## Plays one effect at `world_position`, drifting by `drift` pixels.
static func play(parent: Node, world_position: Vector2, kind: Kind, duration := 0.4,
		drift := Vector2.ZERO, tint := Color.WHITE) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = GameArt.FX
	sprite.hframes = FRAMES
	sprite.vframes = FRAMES
	sprite.frame_coords = Vector2i(0, kind)
	sprite.scale = Vector2.ONE * GameArt.PIXEL
	sprite.modulate = tint
	sprite.z_index = 20
	parent.add_child(sprite)
	sprite.global_position = world_position

	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_method(func(progress: float) -> void:
			sprite.frame_coords = Vector2i(mini(int(progress * FRAMES), FRAMES - 1), kind),
			0.0, 1.0, duration)
	if drift != Vector2.ZERO:
		tween.tween_property(sprite, "global_position", world_position + drift, duration) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(sprite.queue_free)


## Kicks up a little dust around the feet.
static func dust(parent: Node, world_position: Vector2) -> void:
	for side: float in [-1.0, 1.0]:
		play(parent, world_position + Vector2(side * 12.0, 2.0), Kind.DUST, 0.32,
				Vector2(side * 16.0, -6.0))


## A ring of sparkles flying outwards.
static func burst(parent: Node, world_position: Vector2, tint: Color, count := 10) -> void:
	for index in count:
		var direction := Vector2.RIGHT.rotated(TAU * index / count)
		play(parent, world_position, Kind.SPARKLE, 0.55,
				direction * Vector2(58.0, 42.0), tint)
