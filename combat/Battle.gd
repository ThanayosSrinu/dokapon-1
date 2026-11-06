class_name Battle
extends RefCounted
## The rules of one fight, with no animation or UI. ui/BattleScreen.gd shows it,
## and tools/test_battle.gd runs thousands of them without opening a window.
##
## A round gives each fighter one action. The acting fighter picks an offense in
## secret, the other picks a defense, then resolve() works out what happened:
##
##                 Guard     Dodge              Counter
##   Attack        half      miss or 1.25x      1.25x
##   Smash         1.5x      miss or 1.75x      nothing, and it hits the smasher
##   Spell         0.75x     miss or 1.25x      1.25x
##
## Guard beats Attack, Smash beats Guard, Counter beats Smash, and Attack beats
## Counter. Dodge depends on speed, so it is only a good bet for quick fighters.
##
## Every random result uses GameState.rng, so a seed replays the same battle.

enum Offense { ATTACK, SMASH, SPELL, ITEM, FLEE }
enum Defense { NONE, GUARD, DODGE, COUNTER }
enum Ending { NONE, KNOCKOUT, FLED, DRAW }

## The fight stops as a draw after this many rounds.
const MAX_ROUNDS := 8
## How much of the defender's Defense is taken off each hit.
const DEFENSE_FACTOR := 0.5
## Damage varies by this share either way.
const VARIANCE := 0.1

## Offense -> Defense -> multiplier on damage. Dodge's entry is for a failed dodge.
const DAMAGE_TABLE := {
	Offense.ATTACK: {Defense.GUARD: 0.5, Defense.DODGE: 1.25, Defense.COUNTER: 1.25},
	Offense.SMASH: {Defense.GUARD: 1.5, Defense.DODGE: 1.75, Defense.COUNTER: 0.0},
	Offense.SPELL: {Defense.GUARD: 0.75, Defense.DODGE: 1.25, Defense.COUNTER: 1.25},
}
## A countered Smash hits the smasher for this much of its own force.
const COUNTER_RETURN := 1.0

## The chance to dodge, plus this much per point of speed over the attacker.
const DODGE_BASE := 0.3
const DODGE_PER_SPEED := 0.03
const DODGE_MIN := 0.1
const DODGE_MAX := 0.7
## A Smash is slow, so it is this much easier to dodge.
const DODGE_SMASH_BONUS := 0.15

## The chance to flee, plus this much per point of speed over the enemy.
const FLEE_BASE := 0.5
const FLEE_PER_SPEED := 0.05
const FLEE_MIN := 0.2
const FLEE_MAX := 0.9

## The winner of a player fight earns this much EXP per level of the loser.
const PVP_EXP_PER_LEVEL := 30
## The share of their gold a player knocked out by a monster loses. A rival takes
## spoils instead: see Rivalry.
const KO_GOLD_SHARE := 0.25

## Below this share of HP, a monster or an Easy CPU player tries to heal.
const CPU_HEAL_BELOW := 0.35
## How often an Easy CPU player picks each move. Monsters use their own habits, and
## CpuBrain assumes that anyone it has not seen fight has these habits too.
const CPU_OFFENSE := {"attack": 5, "smash": 2, "spell": 3}
const CPU_DEFENSE := {"guard": 4, "dodge": 2, "counter": 3}
const OFFENSE_NAMES := {"attack": Offense.ATTACK, "smash": Offense.SMASH, "spell": Offense.SPELL}
const DEFENSE_NAMES := {"guard": Defense.GUARD, "dodge": Defense.DODGE, "counter": Defense.COUNTER}


## An offense, and the id of the spell or item when it uses one.
class Choice:
	var offense: Offense
	var id: String

	func _init(new_offense: Offense, new_id := "") -> void:
		offense = new_offense
		id = new_id


## What resolve() worked out, for the screen to show.
class Outcome:
	var attacker: Fighter
	var defender: Fighter
	var offense: Offense
	var defense: Defense
	var spell: SpellData
	## Damage to the defender.
	var damage := 0
	## Damage to the attacker from a Counter.
	var reflected := 0
	## HP or MP the attacker gained.
	var healed := 0
	var mana_restored := 0
	var dodged := false
	var fled := false
	## The sentence that announces the move.
	var opening := ""
	## The sentence that says how it went.
	var result := ""


## Where someone knocked out wakes up, in words.
var carried_to := "the castle"
## The side that started the battle, and the side it attacked. Never swapped.
var challenger: Fighter
var opponent: Fighter
## Who acts next, and who defends against it.
var attacker: Fighter
var defender: Fighter
## The current round, starting at 1.
var round_number := 1
var ending := Ending.NONE
## Set when the battle ends in a knockout.
var winner: Fighter
var loser: Fighter
## Set when the battle ends with someone running away.
var fled_fighter: Fighter
## Fighter -> Offense or Defense -> how often it has shown that move in this fight.
## Moves are shown when they resolve, so CpuBrain may learn from them.
var seen_offenses := {}
var seen_defenses := {}

# How many fighters have acted this round.
var _actions_this_round := 0


## The faster fighter acts first. A tie goes to a coin toss.
func _init(new_challenger: Fighter, new_opponent: Fighter) -> void:
	challenger = new_challenger
	opponent = new_opponent
	var challenger_speed := challenger.get_stat("speed")
	var opponent_speed := opponent.get_stat("speed")
	var challenger_first := challenger_speed > opponent_speed
	if challenger_speed == opponent_speed:
		challenger_first = GameState.rng.randf() < 0.5
	attacker = challenger if challenger_first else opponent
	defender = opponent if challenger_first else challenger


func is_over() -> bool:
	return ending != Ending.NONE


## True when `choice` is aimed at the enemy, so the enemy gets to defend.
func needs_defense(choice: Choice) -> bool:
	match choice.offense:
		Offense.ATTACK, Offense.SMASH:
			return true
		Offense.SPELL:
			return Database.get_spell(choice.id).kind == SpellData.Kind.ATTACK
	return false


## The chance that `dodger` avoids `offense` from `striker`.
func dodge_chance(dodger: Fighter, striker: Fighter, offense: Offense) -> float:
	var chance := DODGE_BASE + DODGE_PER_SPEED * (dodger.get_stat("speed") - striker.get_stat("speed"))
	if offense == Offense.SMASH:
		chance += DODGE_SMASH_BONUS
	return clampf(chance, DODGE_MIN, DODGE_MAX)


## The chance that `runner` gets away from `enemy`.
func flee_chance(runner: Fighter, enemy: Fighter) -> float:
	var chance := FLEE_BASE + FLEE_PER_SPEED * (runner.get_stat("speed") - enemy.get_stat("speed"))
	return clampf(chance, FLEE_MIN, FLEE_MAX)


func can_cast(fighter: Fighter, spell_id: String) -> bool:
	var spell := Database.get_spell(spell_id)
	if fighter.mp < spell.mp_cost:
		return false
	return spell.kind == SpellData.Kind.ATTACK or fighter.hp < fighter.get_stat("max_hp")


## Plays the attacker's action and passes play to the other fighter.
func resolve(choice: Choice, defense := Defense.NONE) -> Outcome:
	var outcome := Outcome.new()
	outcome.attacker = attacker
	outcome.defender = defender
	outcome.offense = choice.offense
	outcome.defense = defense
	if needs_defense(choice):
		_remember(seen_offenses, attacker, choice.offense)
		_remember(seen_defenses, defender, defense)
	match choice.offense:
		Offense.ATTACK:
			outcome.opening = "%s attacks!" % attacker.display_name
			_strike(outcome, _physical_force())
		Offense.SMASH:
			outcome.opening = "%s winds up a Smash!" % attacker.display_name
			_strike(outcome, _physical_force())
		Offense.SPELL:
			_cast(outcome, Database.get_spell(choice.id))
		Offense.ITEM:
			_use_item(outcome, choice.id)
		Offense.FLEE:
			_try_to_flee(outcome)

	if not is_over():
		_pass_play()
	return outcome


## Hands out rewards and penalties. Call it once, when is_over() is true.
## Returns the sentences to show. Moving a loser's token is left to the caller.
func conclude() -> PackedStringArray:
	var lines := PackedStringArray()
	match ending:
		Ending.FLED:
			lines.append("%s got away." % fled_fighter.display_name)
		Ending.DRAW:
			lines.append("Neither side gives way. The fight is a draw.")
		Ending.KNOCKOUT:
			lines.append("%s wins!" % winner.display_name)
			if winner.player != null:
				_reward(winner.player, lines)
			if loser.player != null:
				_knock_out(loser.player, lines)
	return lines


## Picks the attacker's move for a monster or CPU player. Monsters and Easy players
## go by habit, and CpuBrain thinks for the others.
func cpu_offense() -> Choice:
	var fighter := attacker
	if _thinks(fighter):
		return CpuBrain.offense(self)
	var healing := _cpu_healing_choice(fighter)
	if healing != null:
		return healing
	var weights: Dictionary = fighter.monster.offense_weights if fighter.monster != null else CPU_OFFENSE
	var offense: Offense = OFFENSE_NAMES[_weighted_pick(weights)]
	if offense == Offense.SPELL:
		var spell_id := _cpu_attack_spell(fighter)
		if spell_id != "":
			return Choice.new(Offense.SPELL, spell_id)
		offense = Offense.ATTACK
	return Choice.new(offense)


## Picks the defender's answer for a monster or CPU player.
func cpu_defense() -> Defense:
	var fighter := defender
	if _thinks(fighter):
		return CpuBrain.defense(self)
	var weights: Dictionary = fighter.monster.defense_weights if fighter.monster != null else CPU_DEFENSE
	return DEFENSE_NAMES[_weighted_pick(weights)]


func _thinks(fighter: Fighter) -> bool:
	return fighter.player != null and fighter.player.difficulty != CpuBrain.Level.EASY


func _remember(memory: Dictionary, fighter: Fighter, move: int) -> void:
	if not memory.has(fighter):
		memory[fighter] = {}
	memory[fighter][move] = memory[fighter].get(move, 0) + 1


# --- Resolving an action ----------------------------------------------------

func _physical_force() -> float:
	return attacker.get_stat("attack") - defender.get_stat("defense") * DEFENSE_FACTOR


# Applies a hit of `force`, before any multiplier, to the defender.
func _strike(outcome: Outcome, force: float) -> void:
	if outcome.defense == Defense.DODGE:
		if GameState.rng.randf() < dodge_chance(defender, attacker, outcome.offense):
			outcome.dodged = true
			outcome.result = "%s dodges!" % defender.display_name
			return

	if outcome.offense == Offense.SMASH and outcome.defense == Defense.COUNTER:
		outcome.reflected = _roll(force * COUNTER_RETURN)
		attacker.hp -= outcome.reflected
		outcome.result = "Countered! %s takes %d." % [attacker.display_name, outcome.reflected]
		if attacker.hp == 0:
			_end_by_knockout(defender, attacker)
		return

	var table: Dictionary = DAMAGE_TABLE[outcome.offense]
	outcome.damage = _roll(force * table.get(outcome.defense, 1.0))
	defender.hp -= outcome.damage
	outcome.result = "%s takes %d." % [defender.display_name, outcome.damage]
	if defender.hp == 0:
		_end_by_knockout(attacker, defender)


func _cast(outcome: Outcome, spell: SpellData) -> void:
	outcome.spell = spell
	outcome.opening = "%s casts %s!" % [attacker.display_name, spell.display_name]
	attacker.mp -= spell.mp_cost
	var total := attacker.get_stat("magic") + spell.power
	if spell.kind == SpellData.Kind.HEAL:
		var before := attacker.hp
		attacker.hp += _roll(total)
		outcome.healed = attacker.hp - before
		outcome.result = "%s recovers %d HP." % [attacker.display_name, outcome.healed]
	else:
		_strike(outcome, total - defender.get_stat("defense") * DEFENSE_FACTOR)


func _use_item(outcome: Outcome, item_id: String) -> void:
	var before_hp := attacker.hp
	var before_mp := attacker.mp
	attacker.player.use_item(item_id)
	outcome.healed = attacker.hp - before_hp
	outcome.mana_restored = attacker.mp - before_mp
	outcome.opening = "%s uses a %s." % [attacker.display_name, Database.get_item(item_id).display_name]
	var gains := PackedStringArray()
	if outcome.healed > 0:
		gains.append("%d HP" % outcome.healed)
	if outcome.mana_restored > 0:
		gains.append("%d MP" % outcome.mana_restored)
	outcome.result = "Recovered %s." % " and ".join(gains)


func _try_to_flee(outcome: Outcome) -> void:
	outcome.opening = "%s tries to run!" % attacker.display_name
	if GameState.rng.randf() < flee_chance(attacker, defender):
		outcome.fled = true
		fled_fighter = attacker
		ending = Ending.FLED
	else:
		outcome.result = "%s blocks the way!" % defender.display_name


func _end_by_knockout(new_winner: Fighter, new_loser: Fighter) -> void:
	winner = new_winner
	loser = new_loser
	ending = Ending.KNOCKOUT


func _pass_play() -> void:
	var next_attacker := defender
	defender = attacker
	attacker = next_attacker
	_actions_this_round += 1
	if _actions_this_round == 2:
		_actions_this_round = 0
		round_number += 1
		if round_number > MAX_ROUNDS:
			ending = Ending.DRAW


# Spreads a number by VARIANCE. Every hit does at least 1, so fights can end.
func _roll(amount: float) -> int:
	return maxi(roundi(amount * GameState.rng.randf_range(1.0 - VARIANCE, 1.0 + VARIANCE)), 1)


# --- After the battle -------------------------------------------------------

func _reward(player: PlayerData, lines: PackedStringArray) -> void:
	var exp_gain := PVP_EXP_PER_LEVEL * loser.level
	var gold_gain := 0
	if loser.monster != null:
		exp_gain = loser.monster.exp_reward
		gold_gain = player.found_gold(loser.monster.gold_reward)
	else:
		var usual := exp_gain
		exp_gain = Rivalry.duel_exp(player, loser.player, winner == challenger, usual)
		if exp_gain > usual:
			lines.append("Revenge! Double EXP.")
	if exp_gain == 0:
		lines.append("No EXP for beating someone so far below you.")
	elif gold_gain > 0:
		player.add_gold(gold_gain)
		lines.append("Earned %d EXP and %d gold." % [exp_gain, gold_gain])
	else:
		lines.append("Earned %d EXP." % exp_gain)

	var known_spells := player.spells.size()
	if player.add_experience(exp_gain) > 0:
		lines.append("Level up! Now level %d." % player.level)
	for index in range(known_spells, player.spells.size()):
		lines.append("Learned %s!" % Database.get_spell(player.spells[index]).display_name)

	if loser.monster != null:
		_roll_for_loot(player, loser.monster, lines)


func _roll_for_loot(player: PlayerData, monster: MonsterData, lines: PackedStringArray) -> void:
	if monster.loot.is_empty() or GameState.rng.randf() >= monster.loot_chance:
		return
	var item_id := monster.loot[GameState.rng.randi_range(0, monster.loot.size() - 1)]
	var item_name := Database.get_item(item_id).display_name
	if player.add_item(item_id):
		lines.append("It dropped a %s!" % item_name)
	else:
		lines.append("It dropped a %s, but the bag is full." % item_name)


func _knock_out(player: PlayerData, lines: PackedStringArray) -> void:
	if winner.player == null:
		var lost := int(player.gold * KO_GOLD_SHARE)
		player.add_gold(-lost)
		if lost > 0:
			lines.append("%s drops %d gold." % [player.player_name, lost])
	player.knock_out()
	lines.append("%s is carried back to %s." % [player.player_name, carried_to])


# --- CPU choices ------------------------------------------------------------

# Returns null when the fighter should not heal, or has no way to.
func _cpu_healing_choice(fighter: Fighter) -> Choice:
	if fighter.hp >= fighter.get_stat("max_hp") * CPU_HEAL_BELOW:
		return null
	for item_id in fighter.get_items():
		if Database.get_item(item_id).heal_hp > 0:
			return Choice.new(Offense.ITEM, item_id)
	for spell_id in fighter.get_spells():
		if Database.get_spell(spell_id).kind == SpellData.Kind.HEAL and can_cast(fighter, spell_id):
			return Choice.new(Offense.SPELL, spell_id)
	return null


# Returns "" when it cannot afford any attack spell.
func _cpu_attack_spell(fighter: Fighter) -> String:
	var options: Array[String] = []
	for spell_id in fighter.get_spells():
		if Database.get_spell(spell_id).kind == SpellData.Kind.ATTACK and can_cast(fighter, spell_id):
			options.append(spell_id)
	if options.is_empty():
		return ""
	return options[GameState.rng.randi_range(0, options.size() - 1)]


# Picks a key at random, in proportion to its value. The keys are sorted so a
# seed gives the same result on every computer.
func _weighted_pick(weights: Dictionary) -> String:
	var names: Array = weights.keys()
	names.sort()
	var total := 0
	for name: String in names:
		total += weights[name]
	var ticket := GameState.rng.randi_range(1, total)
	for name: String in names:
		ticket -= weights[name]
		if ticket <= 0:
			return name
	return names[0]
