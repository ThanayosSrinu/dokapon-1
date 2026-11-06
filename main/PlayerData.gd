class_name PlayerData
extends RefCounted
## Everything the game remembers about one player, separate from the token on
## the board. Rules code reads this, and to_save() turns it into plain values.
## Items, spells and the class are stored by stable id, never as resources.

## Emitted after anything on the character sheet changes, so UI can redraw.
signal changed

## Emitted once per level gained.
signal leveled_up(new_level: int)

const INVENTORY_SIZE := 6
const MAX_LEVEL := 30
## Reaching the next level takes this much experience, times the current level.
const EXP_PER_LEVEL := 30
## Turns a knocked out player spends recovering.
const KO_TURNS_LOST := 1
## Weak: these stats drop to this share, on an expedition with no food left.
const WEAK_SHARE := 0.75
const WEAK_STATS: Array[String] = ["attack", "defense", "magic", "speed"]
## The slots a player can wear something in.
const EQUIPMENT_SLOTS: Array[ItemData.Kind] = [
	ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY,
]

var player_name := "Player"
var token_color := Color.WHITE

## This player's character sheet, used for portraits in the UI.
var character_sheet: Texture2D

## True when the computer plays this player.
var is_cpu := false
## How well the computer plays them.
var difficulty := CpuBrain.Level.NORMAL

## The stable ID of the space the player stands on. Saved instead of a node
## reference, because nodes do not exist in a save file.
var space_id := -1

## The id of this player's class, empty until choose_class() is called.
var class_id := ""
var level := 1
## Experience toward the next level.
var experience := 0
var gold := 0
var hp := 0
var mp := 0

## Item ids in the bag, at most INVENTORY_SIZE.
var inventory: Array[String] = []
## ItemData.Kind -> the id of the item worn in that slot. A slot may be missing.
var equipment := {}
## The ids of the spells this player knows.
var spells: Array[String] = []
## Turns left to sit out, after a knockout or a snare.
var turns_to_skip := 0
## How much of this week's royal quest this player has done.
var quest_progress := 0
## Added to this player's next roll, then cleared. Below 0 after a Mire spell.
var roll_bonus := 0
## The names of the rivals who knocked this player out. See Rivalry.
var grudges: Array[String] = []
## True while hunger has them. Only an expedition sets this, so it isn't saved.
var weak := false


func _init(new_name := "Player", new_color := Color.WHITE, cpu := false) -> void:
	player_name = new_name
	token_color = new_color
	is_cpu = cpu


## Everything worth keeping, as plain values. The color and the character sheet
## are left out, because they come from this player's token.
func to_save() -> Dictionary:
	return {
		"name": player_name,
		"is_cpu": is_cpu,
		"difficulty": difficulty,
		"space_id": space_id,
		"class_id": class_id,
		"level": level,
		"experience": experience,
		"gold": gold,
		"hp": hp,
		"mp": mp,
		"inventory": inventory.duplicate(),
		"equipment": equipment.duplicate(),
		"spells": spells.duplicate(),
		"turns_to_skip": turns_to_skip,
		"quest_progress": quest_progress,
		"roll_bonus": roll_bonus,
		"grudges": grudges.duplicate(),
	}


## Rebuilds a player from what to_save() returned.
static func from_save(saved: Dictionary) -> PlayerData:
	var player := PlayerData.new(saved["name"], Color.WHITE, saved["is_cpu"])
	player.difficulty = saved["difficulty"] as CpuBrain.Level
	player.space_id = saved["space_id"]
	player.class_id = saved["class_id"]
	player.level = saved["level"]
	player.experience = saved["experience"]
	player.gold = saved["gold"]
	player.hp = saved["hp"]
	player.mp = saved["mp"]
	player.inventory.assign(saved["inventory"])
	player.equipment = saved["equipment"].duplicate()
	player.spells.assign(saved["spells"])
	player.turns_to_skip = saved["turns_to_skip"]
	player.quest_progress = saved["quest_progress"]
	player.roll_bonus = saved["roll_bonus"]
	player.grudges.assign(saved["grudges"])
	return player


## Sets up a level 1 character of the class `id`, at full HP and MP.
func choose_class(id: String) -> void:
	var data := Database.get_class_data(id)
	class_id = id
	level = 1
	experience = 0
	gold = data.starting_gold
	inventory = data.starting_items.duplicate()
	equipment.clear()
	for item_id in data.starting_equipment:
		equipment[Database.get_item(item_id).kind] = item_id
	spells.clear()
	_learn_spells()
	hp = get_stat("max_hp")
	mp = get_stat("max_mp")
	changed.emit()


func get_class_name_text() -> String:
	return Database.get_class_data(class_id).display_name


## What a stat would be with `item_id` worn in place of what is in its slot.
func get_stat_with(item_id: String, stat: String) -> int:
	var item := Database.get_item(item_id)
	var worn_bonus := 0
	if equipment.has(item.kind):
		worn_bonus = Database.get_item(equipment[item.kind]).bonuses.get(stat, 0)
	return maxi(get_stat(stat) - worn_bonus + item.bonuses.get(stat, 0), 1)


## A stat's current value: the fed value, less what being weak takes.
func get_stat(stat: String) -> int:
	var value := fed_stat(stat)
	if weak and WEAK_STATS.has(stat):
		value = int(value * WEAK_SHARE)
	return maxi(value, 1)


## A stat when not weak: class, then level, then everything worn. Always at least 1,
## because equipment can lower a stat.
func fed_stat(stat: String) -> int:
	var data := Database.get_class_data(class_id)
	var value: int = data.base_stats[stat] + data.growth[stat] * (level - 1)
	for item_id: String in equipment.values():
		value += Database.get_item(item_id).bonuses.get(stat, 0)
	return maxi(value, 1)


## How much experience the next level takes.
func exp_to_next_level() -> int:
	return level * EXP_PER_LEVEL


## Adds experience and returns how many levels were gained. Levels also refill
## HP and MP by what the level added to their maximums.
func add_experience(amount: int) -> int:
	var gained := 0
	if level < MAX_LEVEL:
		experience += amount
	while level < MAX_LEVEL and experience >= exp_to_next_level():
		experience -= exp_to_next_level()
		var old_hp := get_stat("max_hp")
		var old_mp := get_stat("max_mp")
		level += 1
		gained += 1
		hp += get_stat("max_hp") - old_hp
		mp += get_stat("max_mp") - old_mp
		_learn_spells()
		leveled_up.emit(level)
	if level == MAX_LEVEL:
		experience = 0
	changed.emit()
	return gained


func add_gold(amount: int) -> void:
	gold = maxi(gold + amount, 0)
	changed.emit()


## Returns false if the bag is full.
func add_item(item_id: String) -> bool:
	if inventory.size() >= INVENTORY_SIZE:
		return false
	inventory.append(item_id)
	changed.emit()
	return true


## Takes one of an item out of the bag. Returns false if there is none.
func remove_item(item_id: String) -> bool:
	if not inventory.has(item_id):
		return false
	inventory.erase(item_id)
	changed.emit()
	return true


## True if a consumable is in the bag and would do something right now.
func can_use_item(item_id: String) -> bool:
	var item := Database.get_item(item_id)
	if not inventory.has(item_id) or item.kind != ItemData.Kind.CONSUMABLE:
		return false
	var heals_hp := item.heal_hp > 0 and hp < get_stat("max_hp")
	var heals_mp := item.heal_mp > 0 and mp < get_stat("max_mp")
	return heals_hp or heals_mp


## Uses a consumable from the bag. Returns false if it would do nothing.
func use_item(item_id: String) -> bool:
	if not can_use_item(item_id):
		return false
	var item := Database.get_item(item_id)
	hp = mini(hp + item.heal_hp, get_stat("max_hp"))
	mp = mini(mp + item.heal_mp, get_stat("max_mp"))
	inventory.erase(item_id)
	changed.emit()
	return true


## Lost a battle: back to full health, but sitting out the next turn.
func knock_out() -> void:
	turns_to_skip = KO_TURNS_LOST
	heal_fully()


func heal_fully() -> void:
	hp = get_stat("max_hp")
	mp = get_stat("max_mp")
	changed.emit()


func spend_mp(amount: int) -> void:
	mp = maxi(mp - amount, 0)
	changed.emit()


func add_roll_bonus(amount: int) -> void:
	roll_bonus += amount
	changed.emit()


## Returns the bonus for this roll and clears it.
func take_roll_bonus() -> int:
	var bonus := roll_bonus
	roll_bonus = 0
	return bonus


func refill_mp() -> void:
	mp = get_stat("max_mp")
	changed.emit()


## Damage outside of battle. It can leave 1 HP but never knocks anyone out.
func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 1)
	changed.emit()


func lose_turn() -> void:
	turns_to_skip += 1
	changed.emit()


## Teaches a spell from outside this player's class.
func learn_spell(spell_id: String) -> void:
	if not spells.has(spell_id):
		spells.append(spell_id)
		changed.emit()


## Wears an item from the bag. What it replaces goes back into the bag.
func equip(item_id: String) -> bool:
	var item := Database.get_item(item_id)
	if not inventory.has(item_id) or item.kind == ItemData.Kind.CONSUMABLE:
		return false
	inventory.erase(item_id)
	if equipment.has(item.kind):
		inventory.append(equipment[item.kind])
	equipment[item.kind] = item_id
	_clamp_hp_and_mp()
	changed.emit()
	return true


## Moves the item in `slot` into the bag. Returns false if there is no room.
func unequip(slot: ItemData.Kind) -> bool:
	if not equipment.has(slot) or inventory.size() >= INVENTORY_SIZE:
		return false
	inventory.append(equipment[slot])
	equipment.erase(slot)
	_clamp_hp_and_mp()
	changed.emit()
	return true


func _learn_spells() -> void:
	var spells_by_level := Database.get_class_data(class_id).spells_by_level
	for learned_at: int in spells_by_level:
		var spell_id: String = spells_by_level[learned_at]
		if learned_at <= level and not spells.has(spell_id):
			spells.append(spell_id)


# Removing a Life Pendant lowers max HP, so current HP must follow it.
func _clamp_hp_and_mp() -> void:
	hp = mini(hp, get_stat("max_hp"))
	mp = mini(mp, get_stat("max_mp"))
