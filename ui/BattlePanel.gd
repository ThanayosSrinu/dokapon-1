class_name BattlePanel
extends PanelContainer
## One fighter's name, HP and MP. Call refresh() after anything changes: the bars
## slide to the new values.

const BAR_SIZE := Vector2(190, 10)
const HP_COLOR := Color(0.36, 0.82, 0.42)
const HP_LOW_COLOR := Color(0.9, 0.3, 0.26)
const MP_COLOR := Color(0.35, 0.58, 0.95)
const BAR_BACK := Color(0.125, 0.086, 0.133)
## At or below this share of HP the bar turns red.
const LOW_HP := 0.3

var _fighter: Fighter
var _shows_mp := true
var _name_label: Label
var _hp_label: Label
var _hp_bar: ColorRect
var _mp_bar: ColorRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", GameArt.GOLD)
	box.add_child(_name_label)
	_hp_bar = _add_bar(box, HP_COLOR)
	_mp_bar = _add_bar(box, MP_COLOR)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_hp_label)


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	_name_label.text = "%s  Lv %d" % [fighter.display_name, fighter.level]
	# A monster with no spells has no use for MP.
	_shows_mp = fighter.player != null or not fighter.get_spells().is_empty()
	_mp_bar.get_parent().visible = _shows_mp
	refresh(0.0)


func refresh(duration := 0.3) -> void:
	var fighter := _fighter
	_hp_label.text = "HP %d/%d" % [fighter.hp, fighter.get_stat("max_hp")]
	if _shows_mp:
		_hp_label.text += "   MP %d/%d" % [fighter.mp, fighter.get_stat("max_mp")]
	var hp_share := float(fighter.hp) / fighter.get_stat("max_hp")
	_hp_bar.color = HP_LOW_COLOR if hp_share <= LOW_HP else HP_COLOR
	_slide(_hp_bar, hp_share, duration)
	_slide(_mp_bar, float(fighter.mp) / fighter.get_stat("max_mp"), duration)


func _add_bar(parent: Container, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.custom_minimum_size = BAR_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = BAR_SIZE - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return fill


func _slide(bar: ColorRect, share: float, duration: float) -> void:
	var width := (BAR_SIZE.x - 4.0) * share
	if duration <= 0.0:
		bar.size.x = width
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(bar, "size:x", width, duration)
