class_name BattlePanel
extends PanelContainer
## One fighter's plate: a big name and level, HP and MP as bars with their numbers, and
## what is raised, lowered or poisoned as small icons with the turns left. Words only
## come in the tip of each icon. A monster's plate also shows its moves as icons, from the
## first meeting (D25), but never which one comes next. Call refresh() after anything
## changes: the bars slide to the new values.

const WIDTH := 400.0
const BAR_WIDTH := 260.0
## At or below this share of HP the bar turns red.
const LOW_HP := 0.3
const NUMBER_WIDTH := 72.0
## The picture for each stat a move can raise or lower.
const STAT_ICONS := {
	"attack": "sword", "defense": "shield", "magic": "magic", "speed": "boot",
	"max_hp": "heart", "max_mp": "magic",
}
const UP_COLOR := Color(0.5, 0.95, 0.55)
const DOWN_COLOR := Color(1.0, 0.45, 0.4)
const POISON_COLOR := Color(0.76, 0.48, 0.96)

static var _arrows := {}
static var _move_box: StyleBoxFlat

var _fighter: Fighter
var _shows_mp := true
var _name_label: Label
var _level_label: Label
var _hp_bar: KitBar
var _hp_number: Label
var _mp_row: HBoxContainer
var _mp_bar: KitBar
var _mp_number: Label
var _status_row: HBoxContainer
var _moves_box: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(heading)
	_name_label = Kit.text("", 0.0, &"Heading")
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_name_label)
	_level_label = Kit.text("")
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_level_label)

	var hp_row := _bar_row(box, Kit.HEALTH, "heart")
	_hp_bar = hp_row[0]
	_hp_number = hp_row[1]
	var mp_row := _bar_row(box, Kit.MAGIC, "magic")
	_mp_bar = mp_row[0]
	_mp_number = mp_row[1]
	_mp_row = _mp_bar.get_parent()

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 12)
	box.add_child(_status_row)
	_moves_box = VBoxContainer.new()
	_moves_box.add_theme_constant_override("separation", 6)
	box.add_child(_moves_box)


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	_name_label.text = fighter.display_name
	_level_label.text = "Lv %d" % fighter.level
	# A monster with no spells has no use for MP.
	_shows_mp = fighter.player != null or not fighter.moves_in(MoveData.Category.MAGIC).is_empty()
	_mp_row.visible = _shows_mp
	_list_moves(fighter)
	refresh(0.0)


func refresh(duration := 0.3) -> void:
	var fighter := _fighter
	var slide := duration > 0.0
	var max_hp := fighter.get_stat("max_hp")
	_hp_number.text = "%d/%d" % [fighter.hp, max_hp]
	_hp_bar.bar_color = Kit.DANGER if float(fighter.hp) / max_hp <= LOW_HP else Kit.HEALTH
	_hp_bar.set_amount(fighter.hp, max_hp, slide)
	if _shows_mp:
		var max_mp := fighter.get_stat("max_mp")
		_mp_number.text = "%d/%d" % [fighter.mp, max_mp]
		_mp_bar.set_amount(fighter.mp, max_mp, slide)
	_show_status(fighter)


## The words on the plate's status icons, for tests and tips.
func status_words() -> PackedStringArray:
	var words := PackedStringArray()
	for chip in _status_row.get_children():
		words.append(chip.get_meta(&"words", ""))
	return words


func _bar_row(parent: Container, color: Color, icon_name: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var bar := KitBar.new(color, Kit.icon(icon_name))
	bar.width = BAR_WIDTH
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var number := Kit.text("")
	number.custom_minimum_size.x = NUMBER_WIDTH
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	return [bar, number]


# One icon per boost or weaken, an arrow for which way, and its turns left.
func _show_status(fighter: Fighter) -> void:
	for child in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()
	for boost in fighter.boosts():
		var up: bool = boost["share"] > 0.0
		var stat: String = boost["stat"]
		var words := "%s %s by %d%%, %s." % [ItemData.STAT_NAMES[stat], "up" if up else "down",
				roundi(absf(boost["share"]) * 100.0), Expedition.turns_words(boost["turns"])]
		_status_row.add_child(_status_chip(Kit.icon(STAT_ICONS.get(stat, "star")), _arrow(up),
				UP_COLOR if up else DOWN_COLOR, boost["turns"], words))
	if fighter.poison_turns > 0:
		var words := "Poisoned: loses %d HP a turn, %s." % [fighter.poison_damage,
				Expedition.turns_words(fighter.poison_turns)]
		_status_row.add_child(_status_chip(MoveIcons.strip([MoveData.STATUS]), null, POISON_COLOR,
				fighter.poison_turns, words))
	_status_row.visible = _status_row.get_child_count() > 0


func _status_chip(picture: Texture2D, arrow: Texture2D, color: Color, turns: int, words: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.set_meta(&"words", words)
	var image := TextureRect.new()
	image.texture = picture
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.custom_minimum_size = Vector2(Kit.ICON_SIZE, Kit.ICON_SIZE)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(image)
	if arrow != null:
		var pointer := TextureRect.new()
		pointer.texture = arrow
		pointer.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pointer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(pointer)
	# The number is the turns left.
	var label := Kit.text(str(turns))
	label.modulate = color
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	Tips.attach(chip, "Turns left", words)
	return chip


# A small arrow, up and green or down and red, drawn at the game's 2x pixel size.
static func _arrow(up: bool) -> Texture2D:
	var key := "up" if up else "down"
	if _arrows.has(key):
		return _arrows[key]
	var rows := ["...o...", "..oxo..", ".oxxxo.", "oxxxxxo", "oooxooo", "..oxo..", "..oxo..", "..ooo.."]
	if not up:
		rows.reverse()
	var shades := {"o": GameArt.INK, "x": UP_COLOR if up else DOWN_COLOR}
	var image := Image.create_empty(14, 16, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 7:
			var mark: String = rows[y][x]
			if shades.has(mark):
				image.fill_rect(Rect2i(x * 2, y * 2, 2, 2), shades[mark])
	_arrows[key] = ImageTexture.create_from_image(image)
	return _arrows[key]


# A monster's moves as icons: one row for its moves, one for its defenses. Each icon's tip
# names the move and how it works.
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
	row.add_theme_constant_override("separation", 6)
	var title := Kit.text(heading)
	title.modulate = Kit.GOLD
	title.custom_minimum_size.x = 44
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	for move_id in moves:
		var move := Database.get_move(move_id)
		var names := MoveIcons.names_for(move)
		if names.is_empty():
			names.append(MoveIcons.PLAIN)
		# A thin box around each move's icons, so that a heavy poison hit reads as one move.
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", move_box())
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.set_meta(&"move", move_id)
		var picture := TextureRect.new()
		picture.texture = MoveIcons.strip(names)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.custom_minimum_size.y = 24
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(picture)
		Tips.attach(chip, move.display_name, MoveIcons.hint_for(move))
		row.add_child(chip)
	return row


## The thin box each of a monster's moves sits in.
static func move_box() -> StyleBoxFlat:
	if _move_box == null:
		_move_box = StyleBoxFlat.new()
		_move_box.bg_color = Color(0.06, 0.05, 0.12, 0.45)
		_move_box.border_color = Color(1.0, 0.95, 0.82, 0.28)
		_move_box.set_border_width_all(2)
		_move_box.set_corner_radius_all(4)
		_move_box.anti_aliasing = false
		_move_box.content_margin_left = 6
		_move_box.content_margin_right = 6
		_move_box.content_margin_top = 2
		_move_box.content_margin_bottom = 2
	return _move_box
