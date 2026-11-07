class_name HeroPage
extends KitPage
## Everything about one person, behind the hero card's Details button: their stats, gear,
## moves, traits, history and skill tree, one tab at a time. The numbers come from HeroFacts, so they
## are the ones a trip that starts now would use. Left and right move between the tabs,
## and down reads the rows, each with a tip.

enum Tab { STATS, GEAR, MOVES, TRAITS, HISTORY, TREE }

const TAB_NAMES: Array[String] = ["Stats", "Gear", "Moves", "Traits", "History", "Skill tree"]
const WIDTH := 820.0
const LIST_HEIGHT := 380.0
const PORTRAIT_SIZE := Vector2(112, 112)
const NAME_WIDTH := 200.0
const VALUE_WIDTH := 110.0

var tabs: Array[KitButton] = []
var tab := Tab.STATS
## The rows of the tab shown, which can take focus.
var rows: Array[Control] = []
## The Skill tree tab's grid, while that tab is shown, or null.
var tree_grid: SkillGrid

var _person: Adventurer
var _one: Member
var _made: PlayerData
var _portrait: TextureRect
var _name: Label
var _class: Label
var _scroll: ScrollContainer
var _list: VBoxContainer


func _init() -> void:
	super("")
	panel.custom_minimum_size.x = WIDTH
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	panel.body.add_child(top)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	top.add_child(_portrait)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(words)
	_name = Kit.text("", 0.0, &"Heading")
	words.add_child(_name)
	_class = Kit.text("")
	words.add_child(_class)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.body.add_child(row)
	for index in TAB_NAMES.size():
		var button := KitButton.new()
		button.kind = KitButton.Kind.SMALL
		button.text = TAB_NAMES[index]
		button.focus_entered.connect(_show_tab.bind(index))
		button.pressed.connect(_show_tab.bind(index))
		row.add_child(button)
		tabs.append(button)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(WIDTH - 32.0, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	panel.body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)


func _ready() -> void:
	super()
	for index in tabs.size():
		var button := tabs[index]
		button.focus_neighbor_left = button.get_path_to(tabs[index - 1])
		button.focus_neighbor_right = button.get_path_to(tabs[(index + 1) % tabs.size()])
		button.focus_neighbor_top = button.get_path_to(back)
	back.focus_neighbor_bottom = back.get_path_to(tabs[0])


## Shows `person`, as they are on the roster if `one` is given, on the tab last shown.
func show_person(person: Adventurer, one: Member) -> void:
	_person = person
	_one = one
	_made = HeroFacts.sheet(person, one)
	_portrait.texture = person.portrait
	_name.text = person.display_name
	_class.text = "%s, level %d" % [person.class_data().display_name, _made.level]
	_name_tree_tab()
	_show_tab(tab, true)


# The Skill tree tab says how many points wait to be spent.
func _name_tree_tab() -> void:
	var free := 0 if _one == null else _one.points_free()
	tabs[Tab.TREE].text = TAB_NAMES[Tab.TREE] if free <= 0 else "%s (%d)" % [TAB_NAMES[Tab.TREE], free]


func first_focus() -> Control:
	return tabs[tab]


## The words of every row on the tab shown, for tests.
func shown_words() -> String:
	var lines := PackedStringArray()
	for row in rows:
		var parts := PackedStringArray()
		for label in row.find_children("*", "Label", true, false):
			parts.append((label as Label).text)
		lines.append(" ".join(parts))
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("game_character"):
		get_viewport().set_input_as_handled()
		close()


func _show_tab(which: int, again := false) -> void:
	if which == tab and not again:
		return
	tab = which as Tab
	for index in tabs.size():
		tabs[index].lit = index == tab
	Tips.close()
	rows.clear()
	tree_grid = null
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _person == null:
		return
	match tab:
		Tab.STATS:
			_fill_stats()
		Tab.GEAR:
			_fill_gear()
		Tab.MOVES:
			_fill_moves()
		Tab.TRAITS:
			_fill_traits()
		Tab.HISTORY:
			_fill_history()
		Tab.TREE:
			_fill_tree()
	_link_rows()
	_scroll.scroll_vertical = 0


func _fill_tree() -> void:
	tree_grid = SkillGrid.new()
	tree_grid.show_tree(_person, _one)
	tree_grid.taken.connect(_on_taken)
	_list.add_child(tree_grid)


# A point was spent: the numbers change, and the town keeps it.
func _on_taken(_id: String) -> void:
	_made = HeroFacts.sheet(_person, _one)
	_class.text = "%s, level %d" % [_person.class_data().display_name, _made.level]
	_name_tree_tab()
	var town := TownData.current()
	if town != null and town.roster.has(_one):
		town.save()


func _fill_stats() -> void:
	for stat in HeroFacts.STATS:
		_add_row(HeroFacts.ICONS[stat], "%s (%s)" % [ItemData.STAT_NAMES[stat], HeroFacts.SHORT[stat]],
				"%d %s" % [_made.get_stat(stat), HeroFacts.growth_words(_person, stat)],
				"%s %s" % [HeroFacts.job(stat), HeroFacts.sum_words(_person, _made, stat)],
				ItemData.STAT_NAMES[stat], HeroFacts.stat_tip(_person, _made, stat))
	_add_row("die", "Movement die", "0-%d" % _person.die_top, "Rolls 0 to %d each day, and they walk that far." % _person.die_top,
			"Movement die", "Each day on a trip they roll 0 to %d." % _person.die_top)
	var food := HeroFacts.food(_person, _one)
	_add_row("food", "Max Food", str(food), "The most days of food a trip can take. Each level adds %d." % Adventurer.FOOD_PER_LEVEL,
			"Max Food", "%s, at level %d." % [Expedition.turns_words(food), _made.level])


func _fill_gear() -> void:
	for slot: ItemData.Kind in PlayerData.EQUIPMENT_SLOTS:
		var kind_name: String = HeroFacts.SLOT_NAMES[slot]
		if not _made.equipment.has(slot):
			_add_row("", kind_name, "", "Nothing worn.", kind_name, "Nothing worn in this slot.")
			continue
		var item := Database.get_item(_made.equipment[slot])
		var effect := item.effect_text()
		_add_row(_slot_icon(slot), kind_name, item.display_name, effect if effect != "" else "No stat changes.",
				item.display_name, item.description)
		for move_id in item.moves:
			_add_move_row(Database.get_move(move_id))


func _fill_moves() -> void:
	for move_id in _made.learned:
		_add_move_row(Database.get_move(move_id))
	var free := MoveData.MOST_LEARNED - _made.learned.size()
	_add_row("book", "Free slots", "%d of %d" % [free, MoveData.MOST_LEARNED],
			"Tomes and the Academy teach Magic and Special moves.", "Free slots",
			"Magic and Special share %d slots. A new move with none free replaces one." % MoveData.MOST_LEARNED)


func _fill_traits() -> void:
	var found := _person.traits()
	for one: Dictionary in found:
		_add_row("star", one["name"], "", one["effect"], one["name"], one["effect"])
	if found.is_empty():
		_add_row("star", "No traits", "", "Movement die 0-%d and food for %d days, like most." % [_person.die_top, _person.max_food],
				"Traits", "Nothing sets them apart but their class and level.")


func _fill_history() -> void:
	var trips := 0 if _one == null else _one.trips
	var home := 0 if _one == null else _one.trips_home
	var gold := 0 if _one == null else _one.gold_home
	if _one == null:
		_add_row("heart", "Not hired", "", "Their history starts when they join your roster.", "History",
				"Nothing to show until they work for you.")
	_add_row("boot", "Trips", str(trips), "Trips they set out on.", "Trips", "%d trips set out on." % trips)
	_add_row("check", "Home safe", str(home), "Trips that ended back home through the Portal.", "Home safe",
			"%d of %d trips ended at home." % [home, trips])
	_add_row("coin", "Gold home", str(gold), "Gold they brought home, all trips together.", "Gold home",
			"%d gold brought home." % gold)
	_add_row("star", "Level", str(_made.level), "Stays with them between trips, won or lost.", "Level",
			"Level %d of %d." % [_made.level, PlayerData.MAX_LEVEL])
	if _made.level >= PlayerData.MAX_LEVEL:
		_add_row("book", "EXP", "Top level", "They can't grow any more.", "EXP", "Level %d is the highest." % PlayerData.MAX_LEVEL)
	else:
		var need := _made.exp_to_next_level()
		_add_row("book", "EXP", "%d / %d" % [_made.experience, need], "%d more to reach level %d." % [need - _made.experience, _made.level + 1],
				"EXP", "Beaten monsters give EXP. %d of the %d needed for the next level." % [_made.experience, need])


func _add_move_row(move: MoveData) -> void:
	var hint := MoveIcons.hint_for(move).trim_prefix(move.display_name + ".").strip_edges()
	var category: String = Battle.CATEGORY_NAMES.find_key(move.category).capitalize()
	_add_row("", move.display_name, category, hint, move.display_name, move.description, MoveIcons.for_move(move))


## One row: a picture, a name, a value and words. The tip says it again, for keys.
## A move's icons stand before its name.
func _add_row(icon_name: String, title: String, value: String, words: String, tip_title: String, tip: String,
		marks: Texture2D = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.draw.connect(Kit.draw_focus.bind(row))
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(Kit.ICON_SIZE, Kit.ICON_SIZE)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if icon_name != "":
		picture.texture = Kit.icon(icon_name)
	row.add_child(picture)
	var name_cell := HBoxContainer.new()
	name_cell.custom_minimum_size.x = NAME_WIDTH
	name_cell.add_theme_constant_override("separation", 6)
	row.add_child(name_cell)
	if marks != null:
		var strip := TextureRect.new()
		strip.texture = marks
		strip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_cell.add_child(strip)
	var name_label := Kit.text(title)
	name_label.modulate = Kit.GOLD
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_cell.add_child(name_label)
	var value_label := Kit.text(value)
	value_label.custom_minimum_size.x = VALUE_WIDTH
	row.add_child(value_label)
	var words_label := Kit.text(words)
	words_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words_label)
	if tip != "":
		Tips.attach(row, tip_title, tip)
	_list.add_child(row)
	rows.append(row)
	return row


func _link_rows() -> void:
	var above: Control = tabs[tab]
	var below: Control = rows[0] if not rows.is_empty() else (tree_grid.first_spot() if tree_grid != null else null)
	for button in tabs:
		button.focus_neighbor_bottom = button.get_path_to(below) if below != null else NodePath("")
	for index in rows.size():
		var row := rows[index]
		row.focus_neighbor_top = row.get_path_to(above)
		row.focus_neighbor_bottom = row.get_path_to(rows[mini(index + 1, rows.size() - 1)])
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row)
		above = row


func _slot_icon(slot: ItemData.Kind) -> String:
	match slot:
		ItemData.Kind.WEAPON:
			return "sword"
		ItemData.Kind.ARMOR:
			return "shield"
	return "star"
