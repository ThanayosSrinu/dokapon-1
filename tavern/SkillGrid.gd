class_name SkillGrid
extends Control
## The Skill tree tab of the details page (E20): the hero's class tree on a plain grid,
## with the hero in the middle and 3 branches going up, left and right, each splitting into
## lanes. Small spaces are dots, and notables and keystones are big, with a picture. A
## column on the right tells the space pointed at and takes it. Every shape is drawn here,
## and the pictures are the kit's icons at their own size.
##
## Pointing at a space or moving onto it with keys shows it on the right. A click on it,
## Accept on it, or Take spends a point. Only someone on the roster has points to spend.

## A point was spent on space `id`.
signal taken(id: String)

const GRID_SIZE := Vector2(788, 380)
## One grid cell, in pixels.
const CELL := 26.0
## Where the hero's cell is drawn.
const HUB := Vector2(256, 262)
const HUB_RADIUS := 16.0
const DOT := 6.0
const NOTABLE_HALF := 17.0
const KEYSTONE_RADIUS := 19.0
const BRANCH_COLORS: Array[Color] = [Color(0.93, 0.4, 0.32), Color(0.38, 0.62, 0.96), Color(0.46, 0.82, 0.4)]
const CLASS_ICONS := {"warrior": "sword", "mage": "magic", "rogue": "boot", "cleric": "heart"}
const SIZE_WORDS := {SkillTree.Size.SMALL: "Small", SkillTree.Size.NOTABLE: "Notable", SkillTree.Size.KEYSTONE: "Keystone"}
const SIDE_LEFT := 520.0
const SIDE_WIDTH := 260.0
const LOCKED := Color(0.16, 0.14, 0.22)
const LINE := Color(1, 1, 1, 0.16)
const RING := Color(0.45, 0.42, 0.5)

## Space id -> the control that takes focus and clicks for it.
var spots := {}
var take_button: KitButton
## The space shown on the right.
var selected := ""

var _person: Adventurer
var _one: Member
var _taken: Array[String] = []
var _points: Label
var _branch_rows: Array[Label] = []
var _title: Label
var _kind: Label
var _words: Label
var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = GRID_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	var side := VBoxContainer.new()
	side.position = Vector2(SIDE_LEFT, 0)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, GRID_SIZE.y)
	side.add_theme_constant_override("separation", 6)
	add_child(side)
	_points = Kit.text("", SIDE_WIDTH)
	_points.modulate = Kit.GOLD
	side.add_child(_points)
	for branch in 3:
		var row := Kit.text("")
		row.modulate = BRANCH_COLORS[branch]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		side.add_child(row)
		_branch_rows.append(row)
	side.add_child(HSeparator.new())
	_title = Kit.text("", SIDE_WIDTH, &"Heading")
	side.add_child(_title)
	_kind = Kit.text("", SIDE_WIDTH)
	_kind.modulate = Kit.MUTED
	side.add_child(_kind)
	_words = Kit.text("", SIDE_WIDTH)
	side.add_child(_words)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(filler)
	take_button = KitButton.new()
	take_button.kind = KitButton.Kind.PRIMARY
	take_button.press_sound = "level_up"
	take_button.pressed.connect(func() -> void: take(selected))
	side.add_child(take_button)


## Shows the tree of `person`, as they are on the roster if `one` is given.
func show_tree(person: Adventurer, one: Member) -> void:
	_person = person
	_one = one
	_taken = one.tree if one != null else ([] as Array[String])
	for spot: Control in spots.values():
		remove_child(spot)
		spot.queue_free()
	spots.clear()
	for id in SkillTree.ids(person.class_id):
		_add_spot(id)
	if selected == "" or not spots.has(selected):
		selected = _first_open()
	var branches := SkillTree.branches(person.class_id)
	for branch in _branch_rows.size():
		Tips.attach(_branch_rows[branch], branches[branch]["name"], branches[branch]["words"])
	_refresh()


## The space a key press should start on.
func first_spot() -> Control:
	return spots.get(selected, spots.get("a1"))


## Points they can spend now.
func points_free() -> int:
	return 0 if _one == null else _one.points_free()


## Shows space `id` on the right.
func select(id: String) -> void:
	if selected != id and spots.has(id):
		selected = id
		_refresh()


## Spends a point on space `id`. Returns false, with a shake, if it can't be taken.
func take(id: String) -> bool:
	if _one == null or not _one.take(id):
		take_button.deny()
		return false
	selected = id
	_refresh()
	taken.emit(id)
	return true


## Where space `id` sits, in pixels.
static func spot_center(class_id: String, id: String) -> Vector2:
	var cell: Vector2i = SkillTree.space(class_id, id)["cell"]
	return HUB + Vector2(cell) * CELL


## How far from its middle a space reaches.
static func reach(size: SkillTree.Size) -> float:
	match size:
		SkillTree.Size.NOTABLE:
			return NOTABLE_HALF
		SkillTree.Size.KEYSTONE:
			return KEYSTONE_RADIUS
	return DOT


func _process(delta: float) -> void:
	if is_visible_in_tree() and points_free() > 0:
		_pulse = fmod(_pulse + delta, 1.2)
		queue_redraw()


func _draw() -> void:
	if _person == null:
		return
	var class_id := _person.class_id
	for id in spots:
		var from := spot_center(class_id, id)
		var color := BRANCH_COLORS[SkillTree.branch_of(id)]
		if SkillTree.is_root(id):
			var lit := _taken.has(id)
			draw_line(HUB, from, color if lit else LINE, 4.0 if lit else 2.0)
		for other: String in SkillTree.links(class_id, id):
			if other > id:
				var both := _taken.has(id) and _taken.has(other)
				draw_line(from, spot_center(class_id, other), color if both else LINE, 4.0 if both else 2.0)
	draw_circle(HUB, HUB_RADIUS, Kit.INK)
	draw_arc(HUB, HUB_RADIUS, 0.0, TAU, 32, Kit.GOLD, 2.0)
	var hub := Kit.icon(CLASS_ICONS.get(class_id, "star"))
	draw_texture(hub, (HUB - hub.get_size() / 2.0).round())
	for id: String in spots:
		_draw_space(class_id, id)


func _draw_space(class_id: String, id: String) -> void:
	var found := SkillTree.space(class_id, id)
	var center := spot_center(class_id, id)
	var size: SkillTree.Size = found["size"]
	var color := BRANCH_COLORS[SkillTree.branch_of(id)]
	var lit := _taken.has(id)
	var open := not lit and _one != null and _one.can_take(id)
	var ring := Kit.CREAM if lit else (Kit.GOLD if open else RING)
	var fill := color.darkened(0.35) if lit else LOCKED
	match size:
		SkillTree.Size.SMALL:
			draw_circle(center, DOT, color if lit else LOCKED)
			draw_arc(center, DOT, 0.0, TAU, 20, ring, 2.0)
		SkillTree.Size.NOTABLE:
			var box := Rect2(center - Vector2(NOTABLE_HALF, NOTABLE_HALF), Vector2(NOTABLE_HALF, NOTABLE_HALF) * 2.0)
			draw_rect(box, fill)
			draw_rect(box, ring, false, 2.0)
		SkillTree.Size.KEYSTONE:
			draw_circle(center, KEYSTONE_RADIUS, fill)
			draw_arc(center, KEYSTONE_RADIUS, 0.0, TAU, 32, ring, 2.0)
			draw_arc(center, KEYSTONE_RADIUS - 4.0, 0.0, TAU, 32, ring, 1.0)
	if size != SkillTree.Size.SMALL:
		var picture := Kit.icon(found["icon"])
		draw_texture(picture, (center - picture.get_size() / 2.0).round(), Color.WHITE if lit or open else Color(1, 1, 1, 0.45))
	var edge := reach(size)
	if open:
		var grow := 3.0 + 2.0 * sin(_pulse / 1.2 * TAU)
		draw_arc(center, edge + grow, 0.0, TAU, 28, Color(Kit.GOLD, 0.6), 1.0)
	if id == selected:
		draw_arc(center, edge + 6.0, 0.0, TAU, 32, Color.WHITE, 2.0)


func _add_spot(id: String) -> void:
	var class_id := _person.class_id
	var half: float = reach(SkillTree.space(class_id, id)["size"]) + 3.0
	var spot := Control.new()
	spot.name = id
	spot.size = Vector2(half, half) * 2.0
	spot.position = spot_center(class_id, id) - Vector2(half, half)
	spot.focus_mode = Control.FOCUS_ALL
	spot.mouse_filter = Control.MOUSE_FILTER_STOP
	spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	spot.draw.connect(Kit.draw_focus.bind(spot))
	spot.focus_entered.connect(func() -> void:
			spot.queue_redraw()
			select(id))
	spot.focus_exited.connect(spot.queue_redraw)
	spot.mouse_entered.connect(select.bind(id))
	spot.gui_input.connect(_on_spot_input.bind(id))
	add_child(spot)
	spots[id] = spot


func _on_spot_input(event: InputEvent, id: String) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if clicked and id != selected:
		select(id)
		accept_event()
	elif clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		if take(id):
			Sound.play("level_up")


func _first_open() -> String:
	for id in SkillTree.ids(_person.class_id):
		if SkillTree.can_take(_person.class_id, _taken, id):
			return id
	return "a1"


func _refresh() -> void:
	var class_id := _person.class_id
	var branches := SkillTree.branches(class_id)
	if _one == null:
		_points.text = "Hire them to spend points. Each level gives 1."
	elif points_free() == 1:
		_points.text = "1 point to spend."
	elif points_free() > 0:
		_points.text = "%d points to spend." % points_free()
	else:
		_points.text = "No points to spend. Each level gives 1."
	for branch in _branch_rows.size():
		_branch_rows[branch].text = "%s: %d of %d taken" % [branches[branch]["name"], SkillTree.taken_in(_taken, branch),
				SkillTree.branch_size()]
	var found := SkillTree.space(class_id, selected)
	_title.text = found["name"]
	_kind.text = "%s, %s" % [SIZE_WORDS[found["size"]], branches[SkillTree.branch_of(selected)]["name"]]
	_words.text = found["text"]
	take_button.visible = _one != null
	take_button.text = "Take"
	if _taken.has(selected):
		take_button.text = "Taken"
		take_button.block("They have this space already.")
	elif not SkillTree.can_take(class_id, _taken, selected):
		take_button.block("Take a space joined to it first.")
	elif points_free() <= 0:
		take_button.block("No points left. Each level gives 1.")
	else:
		take_button.block("")
	queue_redraw()
