extends Node
## Every item, spell and class in the game. Registered as the "Database"
## autoload. It reads the folders under data/, so adding a .tres file is all it
## takes to add content: no code changes.

const ITEM_FOLDER := "res://data/items"
const SPELL_FOLDER := "res://data/spells"
const CLASS_FOLDER := "res://data/classes"

## Every stat a character has.
const STATS: Array[String] = ["max_hp", "max_mp", "attack", "defense", "magic", "speed"]

var items := {}
var spells := {}
var classes := {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	items = _load_folder(ITEM_FOLDER)
	spells = _load_folder(SPELL_FOLDER)
	classes = _load_folder(CLASS_FOLDER)


func get_item(id: String) -> ItemData:
	return items.get(id)


func get_spell(id: String) -> SpellData:
	return spells.get(id)


func get_class_data(id: String) -> ClassData:
	return classes.get(id)


## Sorted, so a seeded random pick gives the same result on every computer.
func sorted_ids(table: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(table.keys())
	ids.sort()
	return ids


## Lists every mistake in the data. tools/check_data.gd prints these.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for folder: String in [ITEM_FOLDER, SPELL_FOLDER, CLASS_FOLDER]:
		_check_folder(folder, problems)
	for id: String in items:
		_check_item(items[id], problems)
	for id: String in spells:
		_check_spell(spells[id], problems)
	for id: String in classes:
		_check_class(classes[id], problems)
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
	if consumable and item.heal_hp <= 0 and item.heal_mp <= 0:
		problems.append("item %s heals nothing" % item.id)
	if consumable and not item.bonuses.is_empty():
		problems.append("item %s is consumable but has bonuses" % item.id)
	if not consumable and item.bonuses.is_empty():
		problems.append("item %s is equipment with no bonuses" % item.id)
	for stat: String in item.bonuses:
		if not STATS.has(stat):
			problems.append("item %s has unknown stat '%s'" % [item.id, stat])


func _check_spell(spell: SpellData, problems: PackedStringArray) -> void:
	if spell.mp_cost <= 0 or spell.power <= 0:
		problems.append("spell %s needs mp_cost and power above 0" % spell.id)


func _check_class(data: ClassData, problems: PackedStringArray) -> void:
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
