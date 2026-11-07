class_name BattlePanel
extends PanelContainer
## One fighter's name, HP and MP. Call refresh() after anything changes: the bars
## slide to the new values. A monster's panel also lists its moves with their icons, from
## the first meeting (D25), but never which one comes next.

const BAR_SIZE := Vector2(190, 10)
const HP_COLOR := Color(0.36, 0.82, 0.42)
const HP_LOW_COLOR := Color(0.9, 0.3, 0.26)
const MP_COLOR := Color(0.35, 0.58, 0.95)
const BAR_BACK := Color(0.125, 0.086, 0.133)
## At or below this share of HP the bar turns red.
const LOW_HP := 0.3
const DOWN_COLOR := Color(1.0, 0.45, 0.4)
const SMALL_TEXT := 14

var _fighter: Fighter
var _shows_mp := true
var _name_label: Label
var _hp_label: Label
var _boost_label: Label
var _down_label: Label
var _moves_box: VBoxContainer
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
	_boost_label = Label.new()
	_boost_label.add_theme_font_size_override("font_size", 14)
	_boost_label.add_theme_color_override("font_color", GameArt.GOLD)
	_boost_label.hide()
	box.add_child(_boost_label)
	_down_label = Label.new()
	_down_label.add_theme_font_size_override("font_size", SMALL_TEXT)
	_down_label.add_theme_color_override("font_color", DOWN_COLOR)
	_down_label.hide()
	box.add_child(_down_label)
	_moves_box = VBoxContainer.new()
	_moves_box.add_theme_constant_override("separation", 2)
	box.add_child(_moves_box)


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	_name_label.text = "%s  Lv %d" % [fighter.display_name, fighter.level]
	# A monster with no spells has no use for MP.
	_shows_mp = fighter.player != null or not fighter.moves_in(MoveData.Category.MAGIC).is_empty()
	_mp_bar.get_parent().visible = _shows_mp
	_list_moves(fighter)
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
	var boosts := PackedStringArray()
	var downs := PackedStringArray()
	for boost in fighter.boosts():
		var up: bool = boost["share"] > 0.0
		(boosts if up else downs).append("%s %s, %s" % [ItemData.STAT_NAMES[boost["stat"]], "up" if up else "down",
				Expedition.turns_words(boost["turns"])])
	if fighter.poison_turns > 0:
		downs.append("Poisoned, %s" % Expedition.turns_words(fighter.poison_turns))
	_boost_label.text = "  ".join(boosts)
	_boost_label.visible = not boosts.is_empty()
	_down_label.text = "  ".join(downs)
	_down_label.visible = not downs.is_empty()


# A monster's moves: one row for its moves, one for its defenses. Hovering one gives the
# line of text the menu would.
func _list_moves(fighter: Fighter) -> void:
	for child in _moves_box.get_children():
		_moves_box.remove_child(child)
		child.queue_free()
	_moves_box.visible = fighter.monster != null
	if fighter.monster == null:
		return
	_moves_box.add_child(_move_row("ATK", Battle.offense_moves(fighter)))
	_moves_box.add_child(_move_row("DEF", Battle.defense_moves(fighter)))


func _move_row(heading: String, moves: Array[String]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", SMALL_TEXT)
	title.add_theme_color_override("font_color", GameArt.GOLD)
	title.custom_minimum_size.x = 30
	row.add_child(title)
	for move_id in moves:
		var move := Database.get_move(move_id)
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 2)
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.tooltip_text = MoveIcons.hint_for(move)
		var icon := MoveIcons.for_move(move)
		if icon != null:
			var picture := TextureRect.new()
			picture.texture = icon
			picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.add_child(picture)
		var label := Label.new()
		label.text = move.display_name
		label.add_theme_font_size_override("font_size", SMALL_TEXT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		row.add_child(item)
	return row


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
