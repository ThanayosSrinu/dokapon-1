class_name KitPanel
extends PanelContainer
## A framed window with an optional heading. Add its contents to `body`.

const RISE := 16.0
const OPEN_SECONDS := 0.18

var body: VBoxContainer
## The heading, or null if there is none.
var title: Label

var _open_tween: Tween


func _init(heading := "", paper := false) -> void:
	if paper:
		theme_type_variation = &"PaperPanel"
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	if heading != "":
		title = Kit.text(heading, 0.0, &"PaperHeading" if paper else &"Heading")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(title)


## Rises and fades in. A panel in a container ends where the container puts it, even
## if the container had not placed it yet when the rise began.
func play_open() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	var holder := get_parent() as Container
	if holder != null:
		holder.queue_sort()
	await get_tree().process_frame
	if holder != null:
		holder.queue_sort()
		await holder.sort_children
	var home := position
	position = home + Vector2(0, RISE)
	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_ignore_time_scale(true)
	_open_tween.tween_property(self, "position", home, OPEN_SECONDS)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_SECONDS)
	if holder != null:
		_open_tween.chain().tween_callback(holder.queue_sort)
