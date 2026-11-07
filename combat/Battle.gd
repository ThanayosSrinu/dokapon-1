class_name Battle
extends RefCounted
## The rules of one fight, with no animation or UI. ui/BattleScreen.gd shows it,
## and tools/test_battle.gd runs thousands of them without opening a window.
##
## A round gives each fighter one action. The acting fighter picks a category and a move in
## secret, the other picks a defense, then resolve() works out what happened:
##
##                 Guard                Counter                  Ward
##   Attack        less                 full                     full
##   Smash         1.5x, it breaks      misses, hits the smasher 1.5x, it breaks
##   Magic         full                 full                     less
##
## A Special asks for no defense. How much "less" is, and how hard a Counter hits back, comes
## from the defender's move. See MoveData for what comes from where.
##
## Attack, Smash, Guard, Counter and Ward are free. Magic uses MP, and a Special works once
## per fight, with its turns counted in the user's own turns.
##
## Every random result uses GameState.rng, so a seed replays the same battle.

enum Offense { ATTACK, SMASH, MAGIC, SPECIAL, ITEM, FLEE }
enum Defense { NONE, GUARD, COUNTER, WARD }
enum Ending { NONE, KNOCKOUT, FLED, DRAW }

## The fight stops as a draw after this many rounds.
const MAX_ROUNDS := 8
## How much of the defender's Defense is taken off each hit.
const DEFENSE_FACTOR := 0.5
## Damage varies by this share either way.
const VARIANCE := 0.1

## How much of a hit a Smash lands on a Guard or a Ward.
const BROKEN_HIT := 1.5
## How much a Guard or a Ward takes off when nobody says otherwise.
const USUAL_BLOCK := 0.5

## The moves anyone has with no weapon and no armor.
const BARE_ATTACK := "punch"
const BARE_GUARD := "brace"

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
## How often an Easy CPU player picks each category. Monsters use their own habits, and
## CpuBrain assumes that anyone it has not seen fight has these habits too.
const CPU_OFFENSE := {"attack": 5, "smash": 2, "magic": 3}
const CPU_DEFENSE := {"guard": 4, "counter": 3, "ward": 2}
const OFFENSE_NAMES := {
	"attack": Offense.ATTACK, "smash": Offense.SMASH, "magic": Offense.MAGIC, "special": Offense.SPECIAL,
}
const DEFENSE_NAMES := {"guard": Defense.GUARD, "counter": Defense.COUNTER, "ward": Defense.WARD}
## A habit's name -> the category of move it needs.
const CATEGORY_NAMES := {
	"attack": MoveData.Category.ATTACK, "smash": MoveData.Category.SMASH,
	"magic": MoveData.Category.MAGIC, "special": MoveData.Category.SPECIAL,
	"guard": MoveData.Category.GUARD, "counter": MoveData.Category.COUNTER,
	"ward": MoveData.Category.WARD,
}
const OFFENSE_CATEGORIES := {
	Offense.ATTACK: MoveData.Category.ATTACK, Offense.SMASH: MoveData.Category.SMASH,
	Offense.MAGIC: MoveData.Category.MAGIC, Offense.SPECIAL: MoveData.Category.SPECIAL,
}
const DEFENSE_CATEGORIES := {
	Defense.GUARD: MoveData.Category.GUARD, Defense.COUNTER: MoveData.Category.COUNTER,
	Defense.WARD: MoveData.Category.WARD,
}


## An offense, and the id of the move or item it uses. With no id, an offense uses the
## first move of its category.
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
	## The move the attacker used, or null for an item or fleeing.
	var move: MoveData
	## The move the defender answered with, or null if there was no answer.
	var answer: MoveData
	## Damage to the defender.
	var damage := 0
	## Damage to the attacker from a Counter.
	var reflected := 0
	## HP or MP the attacker gained.
	var healed := 0
	var mana_restored := 0
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


## True when the defender gets to answer an offense of this kind.
func needs_defense(choice: Choice) -> bool:
	return choice.offense in [Offense.ATTACK, Offense.SMASH, Offense.MAGIC]


## How much of a hit lands when `offense` meets `defense`, with `block` being what the
## defender's move takes off when it answers that hit. A countered Smash lands nothing.
static func hit_share(offense: Offense, defense: Defense, block := USUAL_BLOCK) -> float:
	if offense == Offense.SMASH and defense == Defense.COUNTER:
		return 0.0
	if offense == Offense.SMASH and defense != Defense.NONE:
		return BROKEN_HIT
	if (offense == Offense.ATTACK and defense == Defense.GUARD) or (offense == Offense.MAGIC and defense == Defense.WARD):
		return 1.0 - block
	return 1.0


## The chance that `runner` gets away from `enemy`.
func flee_chance(runner: Fighter, enemy: Fighter) -> float:
	var chance := FLEE_BASE + FLEE_PER_SPEED * (runner.get_stat("speed") - enemy.get_stat("speed"))
	return clampf(chance, FLEE_MIN, FLEE_MAX)


## True if `fighter` could use `move_id` right now.
func can_use(fighter: Fighter, move_id: String) -> bool:
	var move := Database.get_move(move_id)
	if fighter.mp < move.mp_cost or fighter.specials_used.has(move_id):
		return false
	return move.effect != MoveData.Effect.HEAL or fighter.hp < fighter.get_stat("max_hp")


## The moves `fighter` could use right now in `category`.
func usable_moves(fighter: Fighter, category: MoveData.Category) -> Array[String]:
	return fighter.moves_in(category).filter(func(id: String) -> bool: return can_use(fighter, id))


## The defenses `fighter` has a move for.
func usable_defenses(fighter: Fighter) -> Array[Defense]:
	var found: Array[Defense] = []
	for defense: Defense in DEFENSE_CATEGORIES:
		if not fighter.moves_in(DEFENSE_CATEGORIES[defense]).is_empty():
			found.append(defense)
	return found


## Plays the attacker's action and passes play to the other fighter. `answer_id` is the move
## the defender answers with. With none, they use the first of its category.
func resolve(choice: Choice, defense := Defense.NONE, answer_id := "") -> Outcome:
	var outcome := Outcome.new()
	outcome.attacker = attacker
	outcome.defender = defender
	outcome.offense = choice.offense
	outcome.defense = defense
	outcome.move = _move_of(attacker, choice)
	outcome.answer = _answer_of(defender, defense, answer_id)
	if needs_defense(choice):
		_remember(seen_offenses, attacker, choice.offense)
		_remember(seen_defenses, defender, defense)
	match choice.offense:
		Offense.ATTACK, Offense.SMASH:
			outcome.opening = "%s uses %s!" % [attacker.display_name, outcome.move.display_name]
			_strike(outcome, _physical_force() * outcome.move.power)
		Offense.MAGIC:
			_cast(outcome)
		Offense.SPECIAL:
			_use_special(outcome)
		Offense.ITEM:
			_use_item(outcome, choice.id)
		Offense.FLEE:
			_try_to_flee(outcome)

	outcome.attacker.tick_boosts()
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
	var options := usable_moves(fighter, OFFENSE_CATEGORIES[offense])
	if options.is_empty():
		offense = Offense.ATTACK
		options = fighter.moves_in(MoveData.Category.ATTACK)
	return Choice.new(offense, options[GameState.rng.randi_range(0, options.size() - 1)])


## Picks the defender's answer for a monster or CPU player.
func cpu_defense() -> Defense:
	var fighter := defender
	if _thinks(fighter):
		return CpuBrain.defense(self)
	var weights: Dictionary = fighter.monster.defense_weights if fighter.monster != null else CPU_DEFENSE
	var defense: Defense = DEFENSE_NAMES[_weighted_pick(weights)]
	return defense if usable_defenses(fighter).has(defense) else Defense.GUARD


func _thinks(fighter: Fighter) -> bool:
	return fighter.player != null and fighter.player.difficulty != CpuBrain.Level.EASY


func _remember(memory: Dictionary, fighter: Fighter, move: int) -> void:
	if not memory.has(fighter):
		memory[fighter] = {}
	memory[fighter][move] = memory[fighter].get(move, 0) + 1


# --- Resolving an action ----------------------------------------------------

func _physical_force() -> float:
	return attacker.get_stat("attack") - defender.get_stat("defense") * DEFENSE_FACTOR


# The move `choice` means, or null for an item or fleeing.
func _move_of(fighter: Fighter, choice: Choice) -> MoveData:
	if not OFFENSE_CATEGORIES.has(choice.offense):
		return null
	if choice.id != "":
		return Database.get_move(choice.id)
	var moves := fighter.moves_in(OFFENSE_CATEGORIES[choice.offense])
	return Database.get_move(moves[0] if not moves.is_empty() else BARE_ATTACK)


# The move that answers, or null if the fighter gave no defense or has none of that kind.
func _answer_of(fighter: Fighter, defense: Defense, answer_id: String) -> MoveData:
	if answer_id != "":
		return Database.get_move(answer_id)
	if defense == Defense.NONE:
		return null
	var moves := fighter.moves_in(DEFENSE_CATEGORIES[defense])
	return null if moves.is_empty() else Database.get_move(moves[0])


# Applies a hit of `force`, before the defense counts, to the defender.
func _strike(outcome: Outcome, force: float) -> void:
	var answer_power := 1.0 if outcome.answer == null else outcome.answer.power
	if outcome.offense == Offense.SMASH and outcome.defense == Defense.COUNTER:
		outcome.reflected = _roll(force * answer_power)
		attacker.hp -= outcome.reflected
		outcome.result = "Countered! %s takes %d." % [attacker.display_name, outcome.reflected]
		if attacker.hp == 0:
			_end_by_knockout(defender, attacker)
		return

	outcome.damage = _roll(force * hit_share(outcome.offense, outcome.defense, answer_power))
	defender.hp -= outcome.damage
	outcome.result = _hit_words(outcome)
	if defender.hp == 0:
		_end_by_knockout(attacker, defender)


# What the defense did, in words, so that a player learns the table by reading it.
func _hit_words(outcome: Outcome) -> String:
	var who := defender.display_name
	var share := hit_share(outcome.offense, outcome.defense)
	if outcome.defense == Defense.NONE:
		return "%s takes %d." % [who, outcome.damage]
	var defense_word := "Guard" if outcome.defense == Defense.GUARD else ("Ward" if outcome.defense == Defense.WARD else "Counter")
	if share > 1.0:
		return "The %s breaks! %s takes %d." % [defense_word, who, outcome.damage]
	if share < 1.0:
		return "%s holds with %s, and takes %d." % [who, outcome.answer.display_name if outcome.answer != null else defense_word, outcome.damage]
	return "The %s does nothing. %s takes %d." % [defense_word, who, outcome.damage]


func _cast(outcome: Outcome) -> void:
	var move := outcome.move
	outcome.opening = "%s casts %s!" % [attacker.display_name, move.display_name]
	attacker.mp -= move.mp_cost
	_strike(outcome, attacker.get_stat("magic") + move.power - defender.get_stat("defense") * DEFENSE_FACTOR)


func _use_special(outcome: Outcome) -> void:
	var move := outcome.move
	outcome.opening = "%s uses %s!" % [attacker.display_name, move.display_name]
	attacker.specials_used.append(move.id)
	match move.effect:
		MoveData.Effect.HEAL:
			var before := attacker.hp
			attacker.hp += _roll(attacker.get_stat("magic") + move.power)
			outcome.healed = attacker.hp - before
			outcome.result = "%s recovers %d HP." % [attacker.display_name, outcome.healed]
		MoveData.Effect.BOOST:
			attacker.add_boost(move.boost_stat, move.power, move.boost_turns)
			outcome.result = "%s up by %d%%, for %d turns." % [ItemData.STAT_NAMES[move.boost_stat],
					roundi(move.power * 100.0), move.boost_turns]
		_:
			_strike(outcome, _physical_force() * move.power)


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
	for move_id in usable_moves(fighter, MoveData.Category.SPECIAL):
		if Database.get_move(move_id).effect == MoveData.Effect.HEAL:
			return Choice.new(Offense.SPECIAL, move_id)
	return null


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
