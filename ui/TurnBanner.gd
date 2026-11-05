class_name TurnBanner
extends Label
## Big text that fades in and out in the middle of the screen to announce a
## turn. Await play() to continue once it has gone:
##     await banner.play("Red's turn", Color.RED)

## Seconds to fade in, and to fade out again.
@export var fade_duration := 0.2

## Seconds the text stays fully visible.
@export var hold_duration := 0.7


func _ready() -> void:
	hide()


func play(message: String, color: Color) -> void:
	text = message
	add_theme_color_override("font_color", color)
	modulate.a = 0.0
	show()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished
	hide()
