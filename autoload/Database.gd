extends Node
## Every item, spell, class, monster, adventurer and stage in the game. Registered as the "Database"
## autoload. It reads the folders under data/, so adding a .tres file is all it
## takes to add content: no code changes.

const ITEM_FOLDER := "res://data/items"
const SPELL_FOLDER := "res://data/spells"
const MOVE_FOLDER := "res://data/moves"
const CLASS_FOLDER := "res://data/classes"
const MONSTER_FOLDER := "res://data/monsters"
const ADVENTURER_FOLDER := "res://data/adventurers"
const STAGE_FOLDER := "res://data/stages"

## Every stat a character has.
const STATS: Array[String] = ["max_hp", "max_mp", "attack", "defense", "magic", "speed"]
## The movement dice an adventurer can have, by their highest number.
const DIE_TOPS: Array[int] = [6, 8, 10]
## How many people the Tavern has room for.
const TAVERN_SIZE := 3

var items := {}
var spells := {}
var moves := {}
var classes := {}
var monsters := {}
var adventurers := {}
var stages := {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	items = _load_folder(ITEM_FOLDER)
	spells = _load_folder(SPELL_FOLDER)
	moves = _load_folder(MOVE_FOLDER)
	classes = _load_folder(CLASS_FOLDER)
	monsters = _load_folder(MONSTER_FOLDER)
	adventurers = _load_folder(ADVENTURER_FOLDER)
	stages = _load_folder(STAGE_FOLDER)


func get_item(id: String) -> ItemData:
	return items.get(id)


func get_spell(id: String) -> SpellData:
	return spells.get(id)


func get_move(id: String) -> MoveData:
	return moves.get(id)


func get_class_data(id: String) -> ClassData:
	return classes.get(id)


func get_monster(id: String) -> MonsterData:
	return monsters.get(id)


func get_adventurer(id: String) -> Adventurer:
	return adventurers.get(id)


func get_stage(id: String) -> Stage:
	return stages.get(id)


## The sizes of `place`, the shortest trip first.
func sizes_of(place: String) -> Array[Stage]:
	var found: Array[Stage] = []
	for id: String in stages:
		if stages[id].place == place:
			found.append(stages[id])
	found.sort_custom(func(a: Stage, b: Stage) -> bool: return a.food_scale < b.food_scale)
	return found


## Everyone at the Tavern, cheapest first.
func adventurers_by_fee() -> Array[Adventurer]:
	var list: Array[Adventurer] = []
	for id in sorted_ids(adventurers):
		list.append(adventurers[id])
	list.sort_custom(func(a: Adventurer, b: Adventurer) -> bool: return a.fee < b.fee)
	return list


## The monsters a player of `level` may meet, sorted like sorted_ids().
func monster_ids_for_level(level: int) -> Array[String]:
	var ids: Array[String] = []
	for id in sorted_ids(monsters):
		var monster: MonsterData = monsters[id]
		if monster.min_level <= level and level <= monster.max_level:
			ids.append(id)
	return ids


## Sorted, so a seeded random pick gives the same result on every computer.
func sorted_ids(table: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(table.keys())
	ids.sort()
	return ids


## Lists every mistake in the data. tools/check_data.gd prints these.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for folder: String in [ITEM_FOLDER, SPELL_FOLDER, MOVE_FOLDER, CLASS_FOLDER, MONSTER_FOLDER, ADVENTURER_FOLDER, STAGE_FOLDER]:
		_check_folder(folder, problems)
	for id: String in items:
		_check_item(items[id], problems)
	for id: String in spells:
		_check_spell(spells[id], problems)
	for id: String in moves:
		_check_move(moves[id], problems)
	for id: String in classes:
		_check_class(classes[id], problems)
	for id: String in monsters:
		_check_monster(monsters[id], problems)
	if adventurers.size() != TAVERN_SIZE:
		problems.append("the Tavern needs %d adventurers, not %d" % [TAVERN_SIZE, adventurers.size()])
	for id: String in adventurers:
		_check_adventurer(adventurers[id], problems)
	for id: String in stages:
		_check_stage(stages[id], problems)
	if not stages.has(TownData.FIRST_STAGE):
		problems.append("no stage called '%s'" % TownData.FIRST_STAGE)
	for level in range(1, PlayerData.MAX_LEVEL + 1):
		if monster_ids_for_level(level).is_empty():
			problems.append("no monster for a player of level %d" % level)
	return problems


func _load_folder(folder: String) -> Dictionary:
	var table := {}
	for path in _resource_paths(folder):
		var entry := load(path)
		if entry != null:
			table[entry.id] = entry
	return table


func _resource_paths(folder: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		# An exported game lists "sword.tres.remap", which still loads as "sword.tres".
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			paths.append("%s/%s" % [folder, name])
	return paths


func _check_folder(folder: String, problems: PackedStringArray) -> void:
	for path in _resource_paths(folder):
		var entry := load(path)
		if entry == null or not "id" in entry:
			problems.append("%s does not load" % path)
		elif entry.id != path.get_file().get_basename():
			problems.append("%s has id '%s'" % [path, entry.id])
		elif entry.display_name == "" or entry.description == "":
			problems.append("%s needs a name and a description" % path)


func _check_item(item: ItemData, problems: PackedStringArray) -> void:
	var consumable := item.kind == ItemData.Kind.CONSUMABLE
	if item.price <= 0:
		problems.append("item %s needs a price above 0" % item.id)
	if item.icon < 0 or item.icon >= GameArt.ITEM_ICONS.get_width() / GameArt.ITEM_ICON_SIZE:
		problems.append("item %s has icon %d, which is not on the sheet" % [item.id, item.icon])
	if consumable and item.heal_hp <= 0 and item.heal_mp <= 0:
		problems.append("item %s heals nothing" % item.id)
	if consumable and not item.bonuses.is_empty():
		problems.append("item %s is consumable but has bonuses" % item.id)
	if item.is_gear() and item.bonuses.is_empty():
		problems.append("item %s is equipment with no bonuses" % item.id)
	if item.kind == ItemData.Kind.WEAPON:
		_check_gear_moves(item, MoveData.WEAPON_CATEGORIES, problems)
	elif item.kind == ItemData.Kind.ARMOR:
		_check_gear_moves(item, MoveData.ARMOR_CATEGORIES, problems)
		if item.moves.size() > MoveData.MOST_ON_ARMOR:
			problems.append("item %s has too many moves" % item.id)
	elif not item.moves.is_empty():
		problems.append("item %s can't give moves" % item.id)
	if item.kind == ItemData.Kind.TOME:
		var taught := get_move(item.teaches)
		if taught == null or not MoveData.MOST_LEARNED.has(taught.category):
			problems.append("item %s teaches '%s', which can't be learned" % [item.id, item.teaches])
	elif item.teaches != "":
		problems.append("item %s is no tome, so it can't teach" % item.id)
	for stat: String in item.bonuses:
		if not STATS.has(stat):
			problems.append("item %s has unknown stat '%s'" % [item.id, stat])


func _check_spell(spell: SpellData, problems: PackedStringArray) -> void:
	if spell.kind == SpellData.Kind.FIELD:
		if spell.mp_cost <= 0 or spell.field_effect == SpellData.FieldEffect.NONE:
			problems.append("field spell %s needs mp_cost above 0 and a field_effect" % spell.id)
	elif spell.mp_cost <= 0 or spell.power <= 0:
		problems.append("spell %s needs mp_cost and power above 0" % spell.id)


# A weapon or armor needs 1 to 4 moves in each of `categories`, and no others.
func _check_gear_moves(item: ItemData, categories: Array[MoveData.Category], problems: PackedStringArray) -> void:
	var counts := {}
	for id in item.moves:
		var move := get_move(id)
		if move == null:
			problems.append("item %s has unknown move '%s'" % [item.id, id])
		elif not categories.has(move.category):
			problems.append("item %s can't give the move %s" % [item.id, id])
		else:
			counts[move.category] = counts.get(move.category, 0) + 1
	for category in categories:
		if not counts.has(category) or counts[category] > MoveData.MOST_IN_CATEGORY:
			problems.append("item %s needs 1 to %d moves in each category" % [item.id, MoveData.MOST_IN_CATEGORY])


func _check_move(move: MoveData, problems: PackedStringArray) -> void:
	var uses_mp := move.category == MoveData.Category.MAGIC
	if uses_mp != (move.mp_cost > 0):
		problems.append("move %s: Magic, and only Magic, costs MP" % move.id)
	if move.power <= 0.0:
		problems.append("move %s needs power above 0" % move.id)
	if (move.category == MoveData.Category.SPECIAL) != (move.effect != MoveData.Effect.NONE):
		problems.append("move %s: Specials, and only Specials, have an effect" % move.id)
	if move.effect == MoveData.Effect.BOOST and (not STATS.has(move.boost_stat) or move.boost_turns <= 0):
		problems.append("move %s needs a stat and a number of turns to boost" % move.id)


func _check_class(data: ClassData, problems: PackedStringArray) -> void:
	var learned := {}
	for id in data.starting_moves:
		var move := get_move(id)
		if move == null or not MoveData.MOST_LEARNED.has(move.category):
			problems.append("class %s can't start with the move '%s'" % [data.id, id])
		else:
			learned[move.category] = learned.get(move.category, 0) + 1
	for category: MoveData.Category in learned:
		if learned[category] > MoveData.MOST_LEARNED[category]:
			problems.append("class %s starts with too many moves" % data.id)
	for stat in STATS:
		if data.base_stats.get(stat, 0) <= 0:
			problems.append("class %s needs base_stats %s above 0" % [data.id, stat])
		if not data.growth.has(stat):
			problems.append("class %s needs growth %s" % [data.id, stat])
	for stat: String in data.base_stats.keys() + data.growth.keys():
		if not STATS.has(stat):
			problems.append("class %s has unknown stat '%s'" % [data.id, stat])
	if data.starting_items.size() > 6:
		problems.append("class %s starts with more than 6 items" % data.id)
	for id in data.starting_items:
		if not items.has(id):
			problems.append("class %s starts with unknown item '%s'" % [data.id, id])
	var worn_kinds := {}
	for id in data.starting_equipment:
		var item: ItemData = items.get(id)
		if item == null or item.kind == ItemData.Kind.CONSUMABLE:
			problems.append("class %s wears '%s', which is not equipment" % [data.id, id])
		elif worn_kinds.has(item.kind):
			problems.append("class %s wears two items in one slot" % data.id)
		else:
			worn_kinds[item.kind] = true
	for level: int in data.spells_by_level:
		if not spells.has(data.spells_by_level[level]):
			problems.append("class %s learns unknown spell at level %d" % [data.id, level])


func _check_adventurer(person: Adventurer, problems: PackedStringArray) -> void:
	if not classes.has(person.class_id):
		problems.append("adventurer %s has unknown class '%s'" % [person.id, person.class_id])
	if person.sheet == null or person.portrait == null:
		problems.append("adventurer %s needs a sheet and a portrait" % person.id)
	if person.level < 1 or person.level > PlayerData.MAX_LEVEL:
		problems.append("adventurer %s has a bad level" % person.id)
	if not DIE_TOPS.has(person.die_top):
		problems.append("adventurer %s has a die that does not exist: %d" % [person.id, person.die_top])
	if person.max_food <= 0:
		problems.append("adventurer %s needs Max Food above 0" % person.id)
	if person.fee <= 0:
		problems.append("adventurer %s needs a fee above 0" % person.id)
	if person.lines.is_empty() or person.hired_line == "" or person.send_line == "" or person.arrive_line == "":
		problems.append("adventurer %s needs something to say" % person.id)


func _check_stage(stage: Stage, problems: PackedStringArray) -> void:
	if not FileAccess.file_exists(stage.map_file):
		problems.append("stage %s has no map at '%s'" % [stage.id, stage.map_file])
	if stage.picture == null:
		problems.append("stage %s needs a picture" % stage.id)
	if stage.food_scale <= 0.0:
		problems.append("stage %s needs a food scale above 0" % stage.id)
	if FileAccess.file_exists(stage.map_file):
		var map := IslandMap.open(stage.map_file)
		if stage.monsters < 0 or stage.chests < map.fixed_chests():
			problems.append("stage %s has fewer chests than its map fixes in place" % stage.id)
		if stage.monsters + stage.chests >= map.spaces().size():
			problems.append("stage %s has more monsters and chests than its map has room for" % stage.id)
	if stage.place == "" or stage.size_name == "":
		problems.append("stage %s needs a place and a size name" % stage.id)


func _check_monster(monster: MonsterData, problems: PackedStringArray) -> void:
	if monster.sheet == null:
		problems.append("monster %s needs a sheet" % monster.id)
	if monster.min_level < 1 or monster.max_level < monster.min_level:
		problems.append("monster %s has a bad level range" % monster.id)
	if monster.exp_reward <= 0:
		problems.append("monster %s needs exp_reward above 0" % monster.id)
	for stat in STATS:
		if monster.stats.get(stat, 0) <= 0:
			problems.append("monster %s needs stat %s above 0" % [monster.id, stat])
	_check_weights(monster, monster.offense_weights, Battle.OFFENSE_NAMES, problems)
	_check_weights(monster, monster.defense_weights, Battle.DEFENSE_NAMES, problems)
	var known := {}
	for id in monster.moves:
		if not moves.has(id):
			problems.append("monster %s knows unknown move '%s'" % [monster.id, id])
		else:
			known[get_move(id).category] = true
	for habits: Dictionary in [monster.offense_weights, monster.defense_weights]:
		for habit: String in habits:
			if Battle.CATEGORY_NAMES.has(habit) and not known.has(Battle.CATEGORY_NAMES[habit]):
				problems.append("monster %s has the habit %s but no such move" % [monster.id, habit])
	if not known.has(MoveData.Category.ATTACK):
		problems.append("monster %s needs an Attack move" % monster.id)
	for id in monster.loot:
		if not items.has(id):
			problems.append("monster %s drops unknown item '%s'" % [monster.id, id])


func _check_weights(monster: MonsterData, weights: Dictionary, names: Dictionary,
		problems: PackedStringArray) -> void:
	if weights.is_empty():
		problems.append("monster %s has an empty habit" % monster.id)
	for key: String in weights:
		if not names.has(key) or weights[key] <= 0:
			problems.append("monster %s has bad habit '%s'" % [monster.id, key])
