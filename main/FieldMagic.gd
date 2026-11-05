class_name FieldMagic
extends RefCounted
## Spells cast on the board before rolling, with no UI. A player casts at most one
## a turn. Each spell is a .tres file in data/spells with the kind FIELD, and Magic
## spaces teach them. They never appear in the battle menu.
##
## GameController shows the Result. Every random result uses GameState.rng.

const HASTE_STEPS := 2
const MIRE_STEPS := 2
## Gold Leech takes this share of the target's gold, up to this much per caster level.
const LEECH_SHARE := 0.1
const LEECH_MAX_PER_LEVEL := 40


## Every field spell's id, sorted so that seeded picks are repeatable.
static func all_ids() -> Array[String]:
	return Database.sorted_ids(Database.spells).filter(func(id: String) -> bool:
			return Database.get_spell(id).kind == SpellData.Kind.FIELD)


## The field spells this player knows, sorted.
static func known(player: PlayerData) -> Array[String]:
	return all_ids().filter(func(id: String) -> bool: return player.spells.has(id))


## True if the spell is aimed at a rival, not at the caster.
static func targets_rival(id: String) -> bool:
	var effect := Database.get_spell(id).field_effect
	return effect == SpellData.FieldEffect.MIRE or effect == SpellData.FieldEffect.LEECH \
			or effect == SpellData.FieldEffect.SLUMBER


## The rivals this spell would do something to right now.
static func valid_targets(caster: PlayerData, id: String) -> Array[PlayerData]:
	var effect := Database.get_spell(id).field_effect
	var found: Array[PlayerData] = []
	for player in GameState.players:
		if player == caster:
			continue
		var useful := true
		match effect:
			SpellData.FieldEffect.MIRE:
				useful = player.roll_bonus > -MIRE_STEPS
			SpellData.FieldEffect.LEECH:
				useful = player.gold > 0
			SpellData.FieldEffect.SLUMBER:
				useful = player.turns_to_skip == 0
		if useful:
			found.append(player)
	return found


## Why this player cannot cast the spell, or "" if they can.
static func why_not(player: PlayerData, id: String) -> String:
	var spell := Database.get_spell(id)
	if player.mp < spell.mp_cost:
		return "Not enough MP."
	if spell.field_effect == SpellData.FieldEffect.RECALL and player.space_id == GameState.castle_id:
		return "Already at the castle."
	if spell.field_effect == SpellData.FieldEffect.HASTE and player.roll_bonus >= HASTE_STEPS:
		return "Already quickened."
	if targets_rival(id) and valid_targets(player, id).is_empty():
		return "No rival to aim it at."
	return ""


## Spends the MP and works the spell. `target` is null for a spell on the caster.
static func cast(caster: PlayerData, id: String, target: PlayerData = null) -> SpaceEffects.Result:
	var spell := Database.get_spell(id)
	caster.spend_mp(spell.mp_cost)
	var result := SpaceEffects.Result.new()
	match spell.field_effect:
		SpellData.FieldEffect.HASTE:
			caster.add_roll_bonus(HASTE_STEPS)
			result.text = "%s's next roll gets +%d." % [caster.player_name, HASTE_STEPS]
		SpellData.FieldEffect.MIRE:
			target.add_roll_bonus(-MIRE_STEPS)
			result.text = "%s's next roll gets -%d." % [target.player_name, MIRE_STEPS]
		SpellData.FieldEffect.RECALL:
			result.to_castle = true
			result.text = "%s returns to the castle." % caster.player_name
		SpellData.FieldEffect.LEECH:
			var stolen := mini(maxi(int(target.gold * LEECH_SHARE), 1), LEECH_MAX_PER_LEVEL * caster.level)
			result.gold_changes = {target: -stolen, caster: stolen}
			result.text = "%s takes %d gold from %s." % [caster.player_name, stolen, target.player_name]
		SpellData.FieldEffect.SLUMBER:
			target.lose_turn()
			result.text = "%s falls asleep and will miss a turn." % target.player_name
	return result
