class_name Battle
extends RefCounted
## The rules of one fight, with no animation or UI. ui/BattleScreen.gd shows it,
## and tools/test_battle.gd runs thousands of them without opening a window.
##
## A round gives each fighter one action. The acting fighter picks a move in secret, the
## other picks a defense move, then resolve() works out what happened. What a move does
## against a defense comes from its keywords (see MoveData), not from where it came from:
##
##                 Guard                  Counter                  Ward
##   plain         less                   full                     full
##   heavy         1.5x, it breaks        misses, hits the user    1.5x, it breaks
##   magic         full                   full                     less
##   status        shorter                full                     blocked
##
## A move on its user, such as a heal or a boost, asks for no defense. How much "less" is,
## and how hard a Counter hits back, comes from the defender's move. Heavy armor's Guard
## holds a heavy hit to full damage instead of 1.5x.
##
## Plain and heavy moves are free. Magic uses MP, and a move with "once" works once per
## fight. Boosts, weakens and poison count the turns of the fighter they are on.
##
## Every random result uses GameState.rng, so a seed replays the same battle.

enum Offense { ATTACK, SMASH, MAGIC, SPECIAL, ITEM, FLEE }
enum Defense { NONE, GUARD, COUNTER, WARD }
enum Ending { NONE, KNOCKOUT, FLED }
## How a move can be answered, from its keywords. SELF needs no answer.
enum Kind { PLAIN, HEAVY, MAGIC, STATUS, SELF }

## How much of the defender's Defense is taken off each hit.
const DEFENSE_FACTOR := 0.5
## Damage varies by this share either way.
const VARIANCE := 0.1

## How much of a hit a heavy move lands on a Guard or a Ward, unless the move answering it
## says otherwise.
const BROKEN_HIT := 1.5
## What a critical hit multiplies by. A skill tree's Assassin adds to it.
const CRIT_TIMES := 2.0
## The most of a hit a Guard or a Ward can take off, however strong.
const MOST_BLOCK := 0.9
## How much a Guard or a Ward takes off when nobody says otherwise.
const USUAL_BLOCK := 0.5
## What a Guard leaves of a status move's turns, rounded up.
const GUARDED_TURNS := 0.5

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
## How much a habit to Smash grows against a foe with no Counter (D25).
const SMASH_WITH_NO_COUNTER := 2
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
const DEFENSE_WORDS := {Defense.GUARD: "Guard", Defense.COUNTER: "Counter", Defense.WARD: "Ward"}


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
	## How the move could be answered. SELF for an item or fleeing too.
	var kind := Kind.SELF
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
	## A status move: true if a Ward stopped it, and how many turns it holds if not.
	var blocked := false
	var turns := 0
	## HP the attacker lost to poison at the end of this turn.
	var poison := 0
	var fled := false
	## A skill tree's Evasion made a weapon hit miss.
	var dodged := false
	## The hit landed double, or more, from a skill tree.
	var critical := false
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
## Fighter -> Kind or Defense -> how often it has shown that in this fight. Moves are
## shown when they resolve, so CpuBrain may learn from them.
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
	# A skill tree's First Blow beats speed, unless both have it.
	var challenger_leads := challenger.perk(SkillTree.FIRST) > 0.0
	var opponent_leads := opponent.perk(SkillTree.FIRST) > 0.0
	if challenger_leads != opponent_leads:
		challenger_first = challenger_leads
	elif challenger_speed == opponent_speed:
		challenger_first = GameState.rng.randf() < 0.5
	attacker = challenger if challenger_first else opponent
	defender = opponent if challenger_first else challenger


func is_over() -> bool:
	return ending != Ending.NONE


## The choice to use the move `move_id`.
static func move_choice(move_id: String) -> Choice:
	var category := Database.get_move(move_id).category
	for offense: Offense in OFFENSE_CATEGORIES:
		if OFFENSE_CATEGORIES[offense] == category:
			return Choice.new(offense, move_id)
	return null


## True when the defender gets to answer this choice: any move that is not on its user.
func needs_defense(choice: Choice) -> bool:
	var move := _move_of(attacker, choice)
	return move != null and not move.on_self()


## How `move` can be answered, from its keywords.
static func kind_of(move: MoveData) -> Kind:
	if move == null or move.on_self():
		return Kind.SELF
	if move.has(MoveData.STATUS):
		return Kind.STATUS
	if move.has(MoveData.HEAVY):
		return Kind.HEAVY
	if move.has(MoveData.MAGIC):
		return Kind.MAGIC
	return Kind.PLAIN


## The defense a defense move gives, from its category.
static func defense_of(move: MoveData) -> Defense:
	for defense: Defense in DEFENSE_CATEGORIES:
		if DEFENSE_CATEGORIES[defense] == move.category:
			return defense
	return Defense.NONE


## The kinds of move that `defense` does something against: makes weaker, stops, shortens
## or hits back. These are the icons a defense move shows.
static func answers(defense: Defense) -> Array[Kind]:
	match defense:
		Defense.GUARD:
			return [Kind.PLAIN, Kind.STATUS]
		Defense.COUNTER:
			return [Kind.HEAVY]
		Defense.WARD:
			return [Kind.MAGIC, Kind.STATUS]
	return []


## How much of a hit lands when a move of `kind` meets `defense`. `block` is what the
## defender's move takes off when it answers that hit, and `broken` is what a heavy hit
## lands through it. A countered heavy hit lands nothing.
static func hit_share(kind: Kind, defense: Defense, block := USUAL_BLOCK, broken := BROKEN_HIT) -> float:
	if kind == Kind.HEAVY and defense == Defense.COUNTER:
		return 0.0
	if kind == Kind.HEAVY and defense != Defense.NONE:
		return broken
	if (kind == Kind.PLAIN and defense == Defense.GUARD) or (kind == Kind.MAGIC and defense == Defense.WARD):
		return 1.0 - block
	return 1.0


## How much of the hit in `outcome` lands, with the answer it met and both sides' skill
## trees.
static func share_of(outcome: Outcome) -> float:
	var block := USUAL_BLOCK if outcome.answer == null else outcome.answer.power
	var broken := BROKEN_HIT if outcome.answer == null else outcome.answer.broken_share
	var defender := outcome.defender
	if defender != null:
		if outcome.defense == Defense.GUARD:
			block += defender.perk(SkillTree.GUARD_POWER)
		elif outcome.defense == Defense.WARD:
			block += defender.perk(SkillTree.WARD_POWER)
			if defender.perk(SkillTree.WARD_HOLDS) > 0.0:
				broken = minf(broken, 1.0)
	if outcome.attacker != null and broken > 1.0:
		broken += outcome.attacker.perk(SkillTree.HEAVY_BREAK)
	return hit_share(outcome.kind, outcome.defense, minf(block, MOST_BLOCK), broken)


## How many turns a status move of `turns` holds against `defense`. A Ward blocks it, and
## a Guard makes it shorter.
static func status_turns(turns: int, defense: Defense) -> int:
	if defense == Defense.WARD:
		return 0
	if defense == Defense.GUARD:
		return ceili(turns * GUARDED_TURNS)
	return turns


## The chance that `runner` gets away from `enemy`.
func flee_chance(runner: Fighter, enemy: Fighter) -> float:
	var chance := FLEE_BASE + FLEE_PER_SPEED * (runner.get_stat("speed") - enemy.get_stat("speed"))
	return clampf(chance + runner.perk(SkillTree.FLEE), FLEE_MIN, FLEE_MAX)


## True if `fighter` could use `move_id` right now.
func can_use(fighter: Fighter, move_id: String) -> bool:
	var move := Database.get_move(move_id)
	if fighter.mp < fighter.mp_cost(move) or (move.has(MoveData.ONCE) and fighter.specials_used.has(move_id)):
		return false
	return move.effect != MoveData.Effect.HEAL or fighter.hp < fighter.get_stat("max_hp")


## The moves `fighter` could use right now in `category`.
func usable_moves(fighter: Fighter, category: MoveData.Category) -> Array[String]:
	return fighter.moves_in(category).filter(func(id: String) -> bool: return can_use(fighter, id))


## Every move `fighter` can make on its own turn, in the order the ATK menu lists them.
static func offense_moves(fighter: Fighter) -> Array[String]:
	var found: Array[String] = []
	for offense: Offense in OFFENSE_CATEGORIES:
		found.append_array(fighter.moves_in(OFFENSE_CATEGORIES[offense]))
	return found


## Every defense move `fighter` has, in the order the DEF menu lists them.
static func defense_moves(fighter: Fighter) -> Array[String]:
	var found: Array[String] = []
	for defense: Defense in DEFENSE_CATEGORIES:
		found.append_array(fighter.moves_in(DEFENSE_CATEGORIES[defense]))
	return found


## The defenses `fighter` has a move for.
func usable_defenses(fighter: Fighter) -> Array[Defense]:
	var found: Array[Defense] = []
	for defense: Defense in DEFENSE_CATEGORIES:
		if not fighter.moves_in(DEFENSE_CATEGORIES[defense]).is_empty():
			found.append(defense)
	return found


## Plays the attacker's action and passes play to the other fighter. `answer_id` is the move
## the defender answers with, and sets the defense. With none, they use the first move of
## `defense`.
func resolve(choice: Choice, defense := Defense.NONE, answer_id := "") -> Outcome:
	var outcome := Outcome.new()
	outcome.attacker = attacker
	outcome.defender = defender
	outcome.offense = choice.offense
	outcome.move = _move_of(attacker, choice)
	outcome.kind = kind_of(outcome.move)
	if outcome.kind == Kind.SELF:
		defense = Defense.NONE
		answer_id = ""
	elif answer_id != "":
		defense = defense_of(Database.get_move(answer_id))
	outcome.defense = defense
	outcome.answer = _answer_of(defender, defense, answer_id)
	if outcome.kind != Kind.SELF:
		_remember(seen_offenses, attacker, outcome.kind)
		_remember(seen_defenses, defender, defense)
	match choice.offense:
		Offense.ITEM:
			_use_item(outcome, choice.id)
		Offense.FLEE:
			_try_to_flee(outcome)
		_:
			_use_move(outcome)

	if not is_over():
		outcome.poison = attacker.poison_tick()
		if outcome.poison > 0 and attacker.hp == 0:
			_end_by_knockout(defender, attacker)
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
	var weights: Dictionary = (fighter.monster.offense_weights if fighter.monster != null else CPU_OFFENSE).duplicate()
	# D25: a smash is the better bet against someone who cannot Counter it.
	if weights.has("smash") and not usable_defenses(defender).has(Defense.COUNTER):
		weights["smash"] *= SMASH_WITH_NO_COUNTER
	var offense: Offense = OFFENSE_NAMES[_weighted_pick(weights)]
	# Heals are kept for when they are needed: see _cpu_healing_choice().
	var options := usable_moves(fighter, OFFENSE_CATEGORIES[offense]).filter(
			func(id: String) -> bool: return Database.get_move(id).effect != MoveData.Effect.HEAL)
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


func _remember(memory: Dictionary, fighter: Fighter, shown: Variant) -> void:
	if not memory.has(fighter):
		memory[fighter] = {}
	memory[fighter][shown] = memory[fighter].get(shown, 0) + 1


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


# Any move: a hit, a spell, a status on the foe, or a heal or a boost on its user.
func _use_move(outcome: Outcome) -> void:
	var move := outcome.move
	var magic := move.has(MoveData.MAGIC)
	outcome.opening = "%s %s %s!" % [attacker.display_name, "casts" if magic else "uses", move.display_name]
	if move.has(MoveData.ONCE):
		attacker.specials_used.append(move.id)
	attacker.mp -= attacker.mp_cost(move)
	match move.effect:
		MoveData.Effect.HEAL:
			var before := attacker.hp
			attacker.hp += _roll((attacker.get_stat("magic") + move.power) * (1.0 + attacker.perk(SkillTree.HEAL_POWER)))
			outcome.healed = attacker.hp - before
			outcome.result = "%s recovers %d HP." % [attacker.display_name, outcome.healed]
			if attacker.perk(SkillTree.CLEANSE) > 0.0:
				attacker.cleanse()
		MoveData.Effect.BOOST:
			attacker.add_boost(move.boost_stat, move.power, move.boost_turns)
			outcome.result = "%s up by %d%%, for %d turns." % [ItemData.STAT_NAMES[move.boost_stat],
					roundi(move.power * 100.0), move.boost_turns]
		MoveData.Effect.WEAKEN, MoveData.Effect.POISON:
			_afflict(outcome)
		_:
			var force := _physical_force() * move.power * (1.0 + attacker.perk(SkillTree.WEAPON_POWER))
			if magic:
				force = attacker.get_stat("magic") + move.power - defender.get_stat("defense") * DEFENSE_FACTOR
				force *= 1.0 + attacker.perk(SkillTree.MAGIC_POWER)
			_strike(outcome, force)


# Applies a hit of `force`, before the defense counts, to the defender.
func _strike(outcome: Outcome, force: float) -> void:
	var answer_power := 1.0 if outcome.answer == null else outcome.answer.power
	if outcome.kind == Kind.HEAVY and outcome.defense == Defense.COUNTER:
		answer_power *= 1.0 + defender.perk(SkillTree.COUNTER_POWER)
		outcome.reflected = _roll(force * answer_power)
		attacker.hp -= outcome.reflected
		outcome.result = "Countered! %s takes %d." % [attacker.display_name, outcome.reflected]
		if attacker.hp == 0:
			_end_by_knockout(defender, attacker)
		return

	var weapon := outcome.kind == Kind.PLAIN or outcome.kind == Kind.HEAVY
	# Skill tree perks roll only for those who have them, so a seed replays the same
	# battle for everyone else.
	var dodge := defender.perk(SkillTree.DODGE)
	if weapon and dodge > 0.0 and GameState.rng.randf() < dodge:
		outcome.dodged = true
		outcome.result = "%s dodges! No harm done." % defender.display_name
		return
	var critical := false
	if weapon:
		critical = attacker.perk(SkillTree.OPENER) > 0.0 and not attacker.has_struck
		if not critical and attacker.perk(SkillTree.CRIT) > 0.0:
			critical = GameState.rng.randf() < attacker.perk(SkillTree.CRIT)
		attacker.has_struck = true
	if critical:
		force *= CRIT_TIMES + attacker.perk(SkillTree.CRIT_POWER)
		outcome.critical = true
	outcome.damage = _roll(force * share_of(outcome))
	defender.hp -= outcome.damage
	outcome.result = ("Critical! " if critical else "") + _hit_words(outcome)
	var mirror := defender.perk(SkillTree.MIRROR)
	if outcome.kind == Kind.MAGIC and outcome.defense == Defense.WARD and mirror > 0.0 and defender.hp > 0:
		outcome.reflected = _roll(outcome.damage * mirror)
		attacker.hp -= outcome.reflected
		outcome.result += " The Ward sends %d back." % outcome.reflected
		if attacker.hp == 0:
			_end_by_knockout(defender, attacker)
			return
	if defender.hp == 0:
		_end_by_knockout(attacker, defender)


# What the defense did, in words, so that a player learns the table by reading it.
func _hit_words(outcome: Outcome) -> String:
	var who := defender.display_name
	var share := share_of(outcome)
	if outcome.defense == Defense.NONE:
		return "%s takes %d." % [who, outcome.damage]
	var defense_word: String = DEFENSE_WORDS[outcome.defense]
	if share > 1.0:
		return "The %s breaks! %s takes %d." % [defense_word, who, outcome.damage]
	if share < 1.0:
		return "%s holds with %s, and takes %d." % [who, outcome.answer.display_name if outcome.answer != null else defense_word, outcome.damage]
	if outcome.kind == Kind.HEAVY:
		return "The %s bends but holds. %s takes %d." % [defense_word, who, outcome.damage]
	return "The %s does nothing. %s takes %d." % [defense_word, who, outcome.damage]


# A status move on the defender: a Ward blocks it, and a Guard makes it shorter.
func _afflict(outcome: Outcome) -> void:
	var move := outcome.move
	var defense := outcome.defense
	if defense == Defense.GUARD and defender.perk(SkillTree.GUARD_STOPS_STATUS) > 0.0:
		defense = Defense.WARD
	outcome.turns = status_turns(move.boost_turns, defense)
	if outcome.turns > 0 and defender.perk(SkillTree.STATUS_SHORT) > 0.0:
		outcome.turns = maxi(ceili(outcome.turns * (1.0 - defender.perk(SkillTree.STATUS_SHORT))), 1)
	if outcome.turns == 0:
		outcome.blocked = true
		outcome.result = "The %s stops it. Nothing happens." % DEFENSE_WORDS[outcome.defense]
		return
	var held := "The Guard keeps it short. " if outcome.defense == Defense.GUARD else ""
	var who := defender.display_name
	if move.effect == MoveData.Effect.POISON:
		defender.add_poison(roundi(defender.get_stat("max_hp") * move.power), outcome.turns)
		outcome.result = "%s%s is poisoned, for %s." % [held, who, Expedition.turns_words(outcome.turns)]
	else:
		defender.add_boost(move.boost_stat, -move.power, outcome.turns, false)
		outcome.result = "%s%s's %s down by %d%%, for %s." % [held, who, ItemData.STAT_NAMES[move.boost_stat],
				roundi(move.power * 100.0), Expedition.turns_words(outcome.turns)]


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


# Spreads a number by VARIANCE. Every hit does at least 1, so fights can end.
func _roll(amount: float) -> int:
	return maxi(roundi(amount * GameState.rng.randf_range(1.0 - VARIANCE, 1.0 + VARIANCE)), 1)


# --- After the battle -------------------------------------------------------

func _reward(player: PlayerData, lines: PackedStringArray) -> void:
	var exp_gain := PVP_EXP_PER_LEVEL * loser.level
	var gold_gain := 0
	if loser.monster != null:
		exp_gain = roundi(loser.monster.exp_reward * (1.0 + player.perk(SkillTree.EXP)))
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
