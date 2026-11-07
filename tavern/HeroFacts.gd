class_name HeroFacts
extends RefCounted
## What the hero card and the details page say about one person. The numbers come from the
## same PlayerData a trip starts with, so the card can never disagree with a fight.

## The stats the card shows, in its order: two columns, three rows.
const STATS: Array[String] = ["attack", "defense", "magic", "speed", "max_hp", "max_mp"]
const SHORT := {"attack": "ATK", "defense": "DEF", "magic": "MG", "speed": "SPD", "max_hp": "HP", "max_mp": "MP"}
const ICONS := {"attack": "sword", "defense": "shield", "magic": "magic", "speed": "boot", "max_hp": "heart", "max_mp": "star"}
const SLOT_NAMES := {ItemData.Kind.WEAPON: "Weapon", ItemData.Kind.ARMOR: "Armor", ItemData.Kind.ACCESSORY: "Accessory"}


## Who `person` would be on a trip that starts now: as they are on the roster if `one` is
## given, else as they would join.
static func sheet(person: Adventurer, one: Member) -> PlayerData:
	return one.sheet() if one != null else Expedition.make_player(person, true, null)


## What the stat `stat` gains each level.
static func growth(person: Adventurer, stat: String) -> int:
	return person.class_data().growth[stat]


## The card's way of writing growth, such as "+3/lv".
static func growth_words(person: Adventurer, stat: String) -> String:
	return "+%d/lv" % growth(person, stat)


## What the stat does, in a fight or on the board.
static func job(stat: String) -> String:
	match stat:
		"attack":
			return "Weapon moves hit with ATK, less half the foe's DEF."
		"defense":
			return "Every hit taken, weapon or magic, loses half of DEF."
		"magic":
			return "Magic moves hit with MG plus the move's power, less half the foe's DEF. Heals restore MG plus the move's power."
		"speed":
			return "The faster one acts first. Fleeing works %d%% of the time at equal SPD, and %d%% more for each point over the foe." % [
					roundi(Battle.FLEE_BASE * 100), roundi(Battle.FLEE_PER_SPEED * 100)]
		"max_hp":
			return "Health. At 0 they are beaten, the trip ends, and they rest %d days." % TownData.current().days_out_after_defeat()
		"max_mp":
			return "Paid for Magic moves. Camp gives back %d%%." % roundi(Expedition.CAMP_SHARE * 100)
	return ""


## Where the number comes from, such as "Rogue at level 1: 9. Dagger: +3."
static func sum_words(person: Adventurer, made: PlayerData, stat: String) -> String:
	var data := person.class_data()
	var parts := PackedStringArray()
	parts.append("%s at level %d: %d." % [data.display_name, made.level,
			data.base_stats[stat] + data.growth[stat] * (made.level - 1)])
	var tree_add := SkillTree.stat_add(made.class_id, made.tree, stat)
	if tree_add != 0:
		parts.append("Skill tree: %+d." % tree_add)
	for slot: ItemData.Kind in PlayerData.EQUIPMENT_SLOTS:
		if made.equipment.has(slot):
			var item := Database.get_item(made.equipment[slot])
			var bonus: int = item.bonuses.get(stat, 0)
			if bonus != 0:
				parts.append("%s: %+d." % [item.display_name, bonus])
	var times := SkillTree.stat_mult(made.class_id, made.tree, stat)
	if not is_equal_approx(times, 1.0):
		parts.append("Keystone: x%s." % str(snappedf(times, 0.01)))
	return " ".join(parts)


## The tooltip of one stat.
static func stat_tip(person: Adventurer, made: PlayerData, stat: String) -> String:
	return "%d now, %s a level. %s %s" % [made.get_stat(stat), "+%d" % growth(person, stat),
			sum_words(person, made, stat), job(stat)]


## Their trait names in one line, or "" with none.
static func trait_names(person: Adventurer) -> String:
	var names := PackedStringArray()
	for one: Dictionary in person.traits():
		names.append(one["name"])
	return ", ".join(names)


## Every trait with its effect, one a line.
static func trait_lines(person: Adventurer) -> String:
	var lines := PackedStringArray()
	for one: Dictionary in person.traits():
		lines.append("%s: %s" % [one["name"], one["effect"]])
	return "\n".join(lines)


## The days of food they can carry on a trip that starts now.
static func food(person: Adventurer, one: Member) -> int:
	return person.food_at() if one == null else one.max_food()
