class_name TurnBanner
extends Control
## A ribbon in the player's color that sweeps across the screen to announce a
## turn. Await play() to continue once it has gone:
##     await banner.play("Red's turn", Color.RED, sheet)

const RIBBON_SIZE := Vector2(460, 56)
const PORTRAIT_SIZE := Vector2(32, 32)
const PORTRAIT_POSITION := Vector2(40, 12)
## Slice of the ribbon that may stretch, in pixels of its image.
const RIBBON_MARGIN := 40

## Seconds to sweep in, and to sweep out again.
@export var slide_duration := 0.3

## Seconds the ribbon stays in the middle.
@export var hold_duration := 0.55

var _ribbon: NinePatchRect
var _label: Label
var _portrait: TextureRect


func _ready() -> void:
	hide()
	_ribbon = NinePatchRect.new()
	_ribbon.texture = GameArt.RIBBON
	_ribbon.patch_margin_left = RIBBON_MARGIN
	_ribbon.patch_margin_right = RIBBON_MARGIN
	_ribbon.size = RIBBON_SIZE
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ribbon)

	# The ribbon is tinted, so what sits on it goes on a separate parent.
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.name = "Content"
	add_child(content)

	_portrait = TextureRect.new()
	_portrait.position = PORTRAIT_POSITION
	_portrait.size = PORTRAIT_SIZE
	content.add_child(_portrait)

	_label = Label.new()
	_label.position = Vector2.ZERO
	_label.size = RIBBON_SIZE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 32)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", GameArt.INK)
	content.add_child(_label)


func play(message: String, color: Color, sheet: Texture2D) -> void:
	_label.text = message
	_ribbon.modulate = color
	_portrait.texture = GameArt.portrait(sheet)

	var content: Control = get_node("Content")
	var middle := (size.x - RIBBON_SIZE.x) * 0.5
	_ribbon.position.x = -RIBBON_SIZE.x
	content.position.x = -RIBBON_SIZE.x
	show()

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ribbon, "position:x", middle, slide_duration)
	tween.parallel().tween_property(content, "position:x", middle, slide_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(_ribbon, "position:x", size.x, slide_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(content, "position:x", size.x, slide_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	hide()
