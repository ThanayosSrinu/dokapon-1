class_name CpuBrain
extends RefCounted
## Every choice a CPU player makes, with no UI. GameController and Battle ask it
## what to do, and the rules still happen in the scripts they always did.
##
## It plays fair. It sees what a person at the table could see, gets no bonus stats
## or dice, never peeks at a shop it is not standing in, and never reads the move
## picked in secret in a fight. Only Level changes how well it thinks.
##
## It compares things in gold: a space, a fight or a spell is worth what it would
## earn, less what it risks. Win chances come from win_odds(), which works them out
## from stats, so thinking never uses up numbers from GameState.rng. Dice are only
## thrown to mix up battle moves and to make mistakes on purpose.

enum Level { EASY, NORMAL, HARD }

const LEVEL_NAMES := {Level.EASY: "Easy", Level.NORMAL: "Normal", Level.HARD: "Hard"}

## What sets the levels apart:
##   blunder    the chance of taking a random path at a fork
##   foresight  how much a prize beyond this roll counts, from 0 to 1
##   nerve      the win chance it wants before it picks a fight
##   quests     whether it chases the royal quest
##   reads      whether it remembers what this enemy did earlier in the fight
##   mix        how firmly it sticks to its best battle move. Higher is firmer
##   cures      how many healing items it carries
const PROFILES := {
	Level.EASY: {"blunder": 0.35, "foresight": 0.0, "nerve": 0.45, "quests": false,
			"reads": false, "mix": 1.0, "cures": 1},
	Level.NORMAL: {"blunder": 0.1, "foresight": 0.5, "nerve": 0.55, "quests": true,
			"reads": false, "mix": 3.0, "cures": 2},
	Level.HARD: {"blunder": 0.0, "foresight": 0.8, "nerve": 0.6, "quests": true,
			"reads": true, "mix": 6.0, "cures": 3},
}

## What one point of EXP is worth in gold.
const EXP_VALUE := 2.0
## A town is judged on this many weeks of its income.
const INCOME_WEEKS := 8
## Being knocked out or put to sleep costs a turn, worth this plus this per level.
const TURN_VALUE_BASE := 100
const TURN_VALUE_PER_LEVEL := 25
## A prize one step further away counts for this share of itself.
const PRIZE_FADE := 0.8
## How many steps away a prize can be and still be felt.
const PRIZE_REACH := 12
## Damage that lands, on average, once guards, wards and counters are counted.
const TYPICAL_HIT := 0.9
## How much of a healing item counts as extra HP, since using it costs an action.
const HEAL_WORTH := 0.6
## win_odds(): the edge of acting first, and how sharply a lead becomes a sure win.
const SPEED_EDGE := 1.1
const ODDS_SHARPNESS := 3.0
## win_odds(): the chance that is left if the fight would run out of rounds.
const DRAW_ODDS := 0.25
## Rounds counted before a fight is called hopeless.
const ROUND_LIMIT := 30
## The richer a player is, the more a knockout costs. This much gold adds 0.1 to
## the win chance it wants, up to MAX_EXTRA_NERVE.
const GOLD_PER_NERVE := 3000.0
const MAX_EXTRA_NERVE := 0.15
## It fights a rival it can only just beat when the prize is high, down to this far
## below its nerve.
const DUEL_NERVE_DISCOUNT := 0.2
## In battle it heals below this share of HP.
const HEAL_BELOW := 0.35
## On the board it heals below this share of HP, and refills MP below this.
const TIDY_HEAL_BELOW := 0.6
const TIDY_MANA_BELOW := 0.3
## What a Special Boost is worth, in plain hits.
const BOOST_WORTH := 2.0
## A status move on the foe counts as this many hits, when it lands in full.
const STATUS_WORTH := 1.5
## It runs from a fight it has less chance than this of winning.
const FLEE_BELOW_ODDS := 0.25
## The worst hit it plans around, as a multiple of a plain hit.
const WORST_HIT := 1.25
## When comparing defenses, it never expects to take less than this share of a hit.
const LEAST_EXPECTED_HIT := 0.1
## It keeps this much gold after investing, plus this per level.
const KEEP_GOLD_BASE := 100
const KEEP_GOLD_PER_LEVEL := 20
## An Easy CPU keeps this many times as much.
const EASY_KEEP_TIMES := 3
## A monster guards a chest about this often. Matches SpaceEffects.
const GUARDIAN_SHARE := SpaceEffects.CHEST_GUARDIAN_CHANCE
## The win chance it wants against a chest's guardian.
const CHEST_ODDS := 0.35
## Mire is worth this share of a lost turn.
const MIRE_SHARE := 0.3
## Sleep and mud matter more on someone ahead of the caster than on someone behind.
const TARGET_AHEAD_TIMES := 1.5
const TARGET_BEHIND_TIMES := 0.7
## A point of MP is worth this plus the caster's level, and twice that to a caster.
const MANA_PRICE := 8
const MANA_PRICE_CASTER_TIMES := 2
## How often an Easy CPU casts when it can, and how often it challenges a rival.
const EASY_CAST_CHANCE := 0.35
const EASY_CHALLENGE_CHANCE := 0.5
## What each stat is worth on a piece of gear. The main stat counts for more.
const STAT_WEIGHTS := {"defense": 2.0, "speed": 1.0, "max_hp": 0.25, "max_mp": 0.25}
const MAIN_STAT_WEIGHT := 3.0


## What a player's next few steps are worth, worked out once per decision.
class Outlook:
	var board: BoardManager
	## BoardNode -> what stopping there is worth.
	var values := {}
	## BoardNode -> what lies beyond it, already scaled by the player's foresight.
	var beyond := {}
	## BoardNode -> what walking across it is worth, for a quest to reach a town.
	var passing := {}
	## Finished walks, so that a fork in the road is only worked out once.
	var memo := {}


# --- How good is this fight? ------------------------------------------------

## The chance that `me` beats `foe`, as they stand now, from 0.01 to 0.99.
static func win_odds(me: Fighter, foe: Fighter) -> float:
	var mine := _rounds_to_beat(me, foe)
	var theirs := _rounds_to_beat(foe, me)
	var edge := float(theirs) / mine
	if me.get_stat("speed") > foe.get_stat("speed"):
		edge *= SPEED_EDGE
	elif me.get_stat("speed") < foe.get_stat("speed"):
		edge /= SPEED_EDGE
	var sharp := pow(edge, ODDS_SHARPNESS)
	var odds := sharp / (1.0 + sharp)
	if mine > Battle.MAX_ROUNDS:
		odds *= DRAW_ODDS
	return clampf(odds, 0.01, 0.99)


## The chance that `player` beats this monster.
static func monster_odds(player: PlayerData, monster: MonsterData) -> float:
	return win_odds(Fighter.from_player(player), Fighter.from_monster(monster))


## The average chance against what lives at `level`.
static func level_odds(player: PlayerData, level: int) -> float:
	var ids := Database.monster_ids_for_level(level)
	var total := 0.0
	for id in ids:
		total += monster_odds(player, Database.get_monster(id))
	return total / ids.size()


# How many rounds `striker` needs to knock out `target`, using spells while the MP
# lasts.
static func _rounds_to_beat(striker: Fighter, target: Fighter) -> int:
	var left := target.hp + _carried_healing(target) * HEAL_WORTH
	var mp := striker.mp
	for round_number in range(1, ROUND_LIMIT + 1):
		var hit := _physical_force(striker, target)
		var cost := 0
		for id in striker.moves_in(MoveData.Category.MAGIC):
			var move := Database.get_move(id)
			if move.mp_cost <= mp:
				var force := _spell_force(striker, target, move)
				if force > hit:
					hit = force
					cost = move.mp_cost
		mp -= cost
		left -= hit * TYPICAL_HIT
		if left <= 0.0:
			return round_number
	return ROUND_LIMIT + 1


static func _carried_healing(fighter: Fighter) -> int:
	var total := 0
	if fighter.player != null:
		for id in fighter.player.inventory:
			total += Database.get_item(id).heal_hp
	return total


static func _physical_force(striker: Fighter, target: Fighter) -> float:
	return maxf(striker.get_stat("attack") - target.get_stat("defense") * Battle.DEFENSE_FACTOR, 1.0)


static func _spell_force(striker: Fighter, target: Fighter, move: MoveData) -> float:
	var total := striker.get_stat("magic") + move.power
	return maxf(total - target.get_stat("defense") * Battle.DEFENSE_FACTOR, 1.0)


# The hardest plain hit `striker` can throw at `target` right now.
static func _strongest_hit(striker: Fighter, target: Fighter) -> float:
	var hit := _physical_force(striker, target)
	for id in striker.moves_in(MoveData.Category.MAGIC):
		var move := Database.get_move(id)
		if move.mp_cost <= striker.mp:
			hit = maxf(hit, _spell_force(striker, target, move))
	return hit


# --- In battle --------------------------------------------------------------

## Picks a move for the attacker, who must be a player on Normal or Hard. It decides
## without knowing the defense, the same as a person would.
static func offense(battle: Battle) -> Battle.Choice:
	var me := battle.attacker
	var foe := battle.defender
	var defenses := _expected_defenses(battle, foe)
	var moves := []
	var weights: Array[float] = []
	var best_hit := 0.0
	for id in Battle.offense_moves(me):
		if not battle.can_use(me, id):
			continue
		var move := Database.get_move(id)
		var kind := Battle.kind_of(move)
		var value := 0.0
		match kind:
			Battle.Kind.SELF:
				if move.effect != MoveData.Effect.BOOST:
					continue
				value = _physical_force(me, foe) * BOOST_WORTH
			Battle.Kind.STATUS:
				value = _physical_force(me, foe) * STATUS_WORTH * _status_share(defenses)
			_:
				var force := _spell_force(me, foe, move) if move.has(MoveData.MAGIC) else _physical_force(me, foe) * move.power
				value = _move_value(kind, force, defenses)
				best_hit = maxf(best_hit, value)
		moves.append(Battle.move_choice(id))
		weights.append(value)

	if best_hit < foe.hp:
		var danger := _strongest_hit(foe, me) * WORST_HIT
		var hurt := me.hp <= danger or me.hp < me.get_stat("max_hp") * HEAL_BELOW
		if hurt:
			var healing := _best_healing(battle, me)
			if healing != null:
				return healing
		if me.hp <= danger and win_odds(me, foe) < FLEE_BELOW_ODDS:
			return Battle.Choice.new(Battle.Offense.FLEE)
	return moves[_mixed_pick(weights, _profile(me.player)["mix"])]


## Picks an answer for the defender, who must be a player on Normal or Hard. It does
## not know the move it is answering.
static func defense(battle: Battle) -> Battle.Defense:
	var me := battle.defender
	var foe := battle.attacker
	var offenses := _expected_offenses(battle, foe)
	var answers := battle.usable_defenses(me)
	var weights: Array[float] = []
	for answer in answers:
		var taken := 0.0
		for kind: Battle.Kind in offenses:
			var share: float = offenses[kind]
			var force := _physical_force(foe, me)
			if kind == Battle.Kind.MAGIC:
				force = _strongest_hit(foe, me)
			if kind == Battle.Kind.HEAVY and answer == Battle.Defense.COUNTER:
				taken -= share * force * 0.5
			elif kind == Battle.Kind.STATUS:
				taken += share * force * STATUS_WORTH * Battle.status_turns(2, answer) / 2.0
			else:
				taken += share * force * Battle.hit_share(kind, answer)
		weights.append(1.0 / maxf(taken, _physical_force(foe, me) * LEAST_EXPECTED_HIT))
	return answers[_mixed_pick(weights, _profile(me.player)["mix"])]


# The damage a move of `kind` should do against what the defender tends to answer with.
# The hit a Counter sends back is taken off.
static func _move_value(kind: Battle.Kind, force: float, defenses: Dictionary) -> float:
	var value := 0.0
	for answer: Battle.Defense in defenses:
		var share: float = defenses[answer]
		if kind == Battle.Kind.HEAVY and answer == Battle.Defense.COUNTER:
			value -= share * force
			continue
		value += share * force * Battle.hit_share(kind, answer)
	return maxf(value, 0.1)


# How much of a status move is expected to land, from 0 to 1.
static func _status_share(defenses: Dictionary) -> float:
	var landed := 0.0
	for answer: Battle.Defense in defenses:
		landed += defenses[answer] * Battle.status_turns(2, answer) / 2.0
	return maxf(landed, 0.05)


# Defense -> how likely it is, from the fighter's habits and, on Hard, what it has
# done so far in this fight.
static func _expected_defenses(battle: Battle, foe: Fighter) -> Dictionary:
	var habits: Dictionary = foe.monster.defense_weights if foe.monster != null else Battle.CPU_DEFENSE
	var counts := {}
	for habit: String in habits:
		counts[Battle.DEFENSE_NAMES[habit]] = float(habits[habit])
	if _profile(battle.attacker.player)["reads"]:
		var seen: Dictionary = battle.seen_defenses.get(foe, {})
		for answer: Battle.Defense in seen:
			counts[answer] = counts.get(answer, 0.0) + seen[answer] * 2.0
	return _shares(counts)


# Kind -> how likely it is, in the same way. Without MP, a spell is not an option, and a
# Special counts only while a status move on the foe is left.
static func _expected_offenses(battle: Battle, foe: Fighter) -> Dictionary:
	var habits: Dictionary = foe.monster.offense_weights if foe.monster != null else Battle.CPU_OFFENSE
	var counts := {}
	for habit: String in habits:
		var kind := Battle.Kind.PLAIN
		match habit:
			"smash":
				kind = Battle.Kind.HEAVY
			"magic":
				if _strongest_hit(foe, battle.defender) > _physical_force(foe, battle.defender):
					kind = Battle.Kind.MAGIC
			"special":
				if not _has_status_left(battle, foe):
					continue
				kind = Battle.Kind.STATUS
		counts[kind] = counts.get(kind, 0.0) + habits[habit]
	if _profile(battle.defender.player)["reads"]:
		var seen: Dictionary = battle.seen_offenses.get(foe, {})
		for kind: Battle.Kind in seen:
			counts[kind] = counts.get(kind, 0.0) + seen[kind] * 2.0
	return _shares(counts)


static func _has_status_left(battle: Battle, fighter: Fighter) -> bool:
	return battle.usable_moves(fighter, MoveData.Category.SPECIAL).any(
			func(id: String) -> bool: return Battle.kind_of(Database.get_move(id)) == Battle.Kind.STATUS)


static func _shares(counts: Dictionary) -> Dictionary:
	var total := 0.0
	for key: Variant in counts:
		total += counts[key]
	var shares := {}
	for key: Variant in counts:
		shares[key] = counts[key] / total
	return shares


# The heal that restores the most, or null if nothing helps.
static func _best_healing(battle: Battle, me: Fighter) -> Battle.Choice:
	var missing := me.get_stat("max_hp") - me.hp
	var best: Battle.Choice = null
	var best_amount := 0
	for id in me.get_items():
		var amount := mini(Database.get_item(id).heal_hp, missing)
		if amount > best_amount:
			best = Battle.Choice.new(Battle.Offense.ITEM, id)
			best_amount = amount
	for id in me.moves_in(MoveData.Category.SPECIAL):
		var move := Database.get_move(id)
		if move.effect == MoveData.Effect.HEAL and battle.can_use(me, id):
			var amount := mini(me.get_stat("magic") + roundi(move.power), missing)
			if amount > best_amount:
				best = Battle.Choice.new(Battle.Offense.SPECIAL, id)
				best_amount = amount
	return best


# Picks an index at random. Weights are raised to `firmness`, so a higher number
# leans harder on the best one, but a person can never be sure of the move.
static func _mixed_pick(weights: Array[float], firmness: float) -> int:
	var total := 0.0
	var leaned: Array[float] = []
	var top: float = weights.max()
	for weight in weights:
		var share := pow(weight / top, firmness)
		leaned.append(share)
		total += share
	var ticket := GameState.rng.randf() * total
	for index in leaned.size():
		ticket -= leaned[index]
		if ticket <= 0.0:
			return index
	return leaned.size() - 1


# --- Choosing a road --------------------------------------------------------

## Picks one of `options` at a fork, with `steps_left` steps still to walk from
## `from`, which is where the player stands.
static func choose_path(player: PlayerData, board: BoardManager, options: Array[BoardNode],
		from: BoardNode, steps_left: int) -> BoardNode:
	if GameState.rng.randf() < float(_profile(player)["blunder"]):
		return options[GameState.rng.randi_range(0, options.size() - 1)]
	var outlook := _look_around(player, board)
	var best: BoardNode = options[0]
	var best_score := -INF
	for option in options:
		var score := _walk(outlook, option, from, steps_left - 1)
		if score > best_score:
			best = option
			best_score = score
	return best


## What stopping on `space` would be worth to `player`, in gold.
static func space_value(player: PlayerData, space: BoardNode) -> float:
	var value := _space_effect_value(player, space)
	if space.node_type == BoardNode.NodeType.CASTLE:
		return value
	for rival in GameState.players:
		if rival != player and rival.space_id == space.node_id:
			value = maxf(value, duel_value(player, rival))
	return value


# Everything `player` needs to weigh up the board at this moment.
static func _look_around(player: PlayerData, board: BoardManager) -> Outlook:
	var outlook := Outlook.new()
	outlook.board = board
	var nodes := board.get_all_nodes()
	var prizes := {}
	for node in nodes:
		outlook.values[node] = space_value(player, node)
		prizes[node] = maxf(outlook.values[node], 0.0)
	var quest_target := _quest_target(player)
	if quest_target >= 0:
		var reward: float = GameState.quest["reward"]
		var target := board.get_board_node(quest_target)
		outlook.passing[target] = reward
		prizes[target] = maxf(prizes[target], reward)

	# Each pass lets every prize reach one step further.
	for pass_number in PRIZE_REACH:
		for node in nodes:
			for neighbor in board.get_neighbors(node):
				prizes[node] = maxf(prizes[node], prizes[neighbor] * PRIZE_FADE)
	var foresight: float = _profile(player)["foresight"]
	for node in nodes:
		var best := 0.0
		for neighbor in board.get_neighbors(node):
			best = maxf(best, prizes[neighbor] * PRIZE_FADE)
		outlook.beyond[node] = best * foresight
	return outlook


# The best score from having just stepped onto `node` from `came_from`, with `steps`
# still to walk. These are the same rules that PlayerMovement walks by.
static func _walk(outlook: Outlook, node: BoardNode, came_from: BoardNode, steps: int) -> float:
	var key := Vector3i(node.node_id, came_from.node_id if came_from != null else -1, steps)
	if outlook.memo.has(key):
		return outlook.memo[key]
	var options := outlook.board.get_connected_nodes(node, came_from)
	var score: float = outlook.values[node] + outlook.beyond[node]
	if steps > 0 and not options.is_empty():
		score = -INF
		for option in options:
			score = maxf(score, _walk(outlook, option, node, steps - 1))
	score += outlook.passing.get(node, 0.0)
	outlook.memo[key] = score
	return score


# What the coming roll is worth from `start`, over every face of the die.
static func _roll_value(outlook: Outlook, start: BoardNode, came_from: BoardNode, bonus: int) -> float:
	var total := 0.0
	for face in range(1, DiceRoller.SIDES + 1):
		var best := -INF
		for option in outlook.board.get_connected_nodes(start, came_from):
			best = maxf(best, _walk(outlook, option, start, maxi(face + bonus, 1) - 1))
		total += best
	return total / DiceRoller.SIDES


# What the effect of `space` is worth, leaving aside anyone standing there.
static func _space_effect_value(player: PlayerData, space: BoardNode) -> float:
	var level := player.level
	match space.node_type:
		BoardNode.NodeType.GOLD:
			return SpaceEffects.GOLD_BASE + SpaceEffects.GOLD_PER_LEVEL * level
		BoardNode.NodeType.ITEM:
			return 0.0 if _bag_is_full(player) else 0.5 * (SpaceEffects.ITEM_VALUE_BASE + SpaceEffects.ITEM_VALUE_PER_LEVEL * level)
		BoardNode.NodeType.EVENT:
			return 20.0 + 5.0 * level
		BoardNode.NodeType.TRAP:
			return -0.5 * _turn_value(player) - player.gold * 0.05
		BoardNode.NodeType.SHRINE:
			return _rest_value(player)
		BoardNode.NodeType.MAGIC:
			var learning := 0.0 if SpaceEffects.learnable_spells(player).is_empty() else 100.0
			return _mana_gap(player) * _turn_value(player) + learning * SpaceEffects.MAGIC_SPELL_CHANCE
		BoardNode.NodeType.TREASURE:
			return _chest_value(player, space.node_id)
		BoardNode.NodeType.SHOP:
			return _shop_value(player)
		BoardNode.NodeType.TOWN:
			return _town_value(player, space.node_id)
		BoardNode.NodeType.BATTLE:
			return _monster_space_value(player)
	return 0.0


static func _rest_value(player: PlayerData) -> float:
	var hurt := 1.0 - float(player.hp) / player.get_stat("max_hp")
	return (hurt * 2.0 + _mana_gap(player)) * _turn_value(player)


static func _mana_gap(player: PlayerData) -> float:
	var gap := 1.0 - float(player.mp) / player.get_stat("max_mp")
	return gap if _is_caster(player) else gap * 0.3


static func _chest_value(player: PlayerData, id: int) -> float:
	if not SpaceEffects.chest_is_full(id) or not will_open_chest(player):
		return 0.0
	return SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * player.level


static func _shop_value(player: PlayerData) -> float:
	if ShadowCrown.is_worn_by(player):
		return 0.0
	var best := 0
	for id in Database.sorted_ids(Database.items):
		var item := Database.get_item(id)
		if item.is_gear() and item.price <= player.gold and _upgrade_value(player, id) > 0.0:
			best = maxi(best, item.price)
	var cures_wanted: int = _profile(player)["cures"]
	var short := maxi(cures_wanted - _healing_items(player), 0)
	return best * 0.5 + (short * 40 if player.gold >= 100 else 0)


static func _town_value(player: PlayerData, id: int) -> float:
	var town_owner := Town.owner_of(id)
	if town_owner == null:
		if not will_fight_guard(player, id):
			return 0.0
		var quest := float(GameState.quest["reward"]) if _quest_wants(player, Quest.Kind.FREE) else 0.0
		return Town.income(id) * INCOME_WEEKS + quest
	if town_owner == player:
		if not will_invest(player, id):
			return 0.0
		return (Town.income(id, Town.level(id) + 1) - Town.income(id)) * INCOME_WEEKS
	if will_storm(player, id):
		return _storm_gain(player, id) * guard_odds(player, id)
	return -Town.toll(id)


static func _monster_space_value(player: PlayerData) -> float:
	var ids := Database.monster_ids_for_level(player.level)
	var gain := 0.0
	for id in ids:
		var monster := Database.get_monster(id)
		gain += monster.exp_reward * EXP_VALUE + monster.gold_reward
	gain /= ids.size()
	if _quest_wants(player, Quest.Kind.HUNT):
		gain += float(GameState.quest["reward"]) / GameState.quest["needed"]
	var odds := level_odds(player, player.level)
	return odds * gain - (1.0 - odds) * _knockout_cost(player)


# The town a VISIT quest wants this player to walk to, or -1.
static func _quest_target(player: PlayerData) -> int:
	return GameState.quest["target"] if _quest_wants(player, Quest.Kind.VISIT) else -1


static func _quest_wants(player: PlayerData, kind: Quest.Kind) -> bool:
	var quest := GameState.quest
	return (_profile(player)["quests"] and not quest.is_empty() and quest["winner"] == ""
			and quest["kind"] == kind)


# --- Towns, chests and rivals -----------------------------------------------

## The chance of beating the guard of town `id`.
static func guard_odds(player: PlayerData, id: int) -> float:
	return monster_odds(player, Town.guard(id))


## True if it wants to fight a town's monsters to free it.
static func will_fight_guard(player: PlayerData, id: int) -> bool:
	return guard_odds(player, id) >= _nerve(player)


## True if it would sooner storm a rival's town than pay the toll.
static func will_storm(player: PlayerData, id: int) -> bool:
	var odds := guard_odds(player, id)
	if odds < _nerve(player):
		return false
	return odds * _storm_gain(player, id) > (1.0 - odds) * _knockout_cost(player)


static func will_invest(player: PlayerData, id: int) -> bool:
	if Town.why_not_invest(player, id) != "":
		return false
	var keep := KEEP_GOLD_BASE + KEEP_GOLD_PER_LEVEL * player.level
	if player.difficulty == Level.EASY:
		keep *= EASY_KEEP_TIMES
	return player.gold - Town.invest_cost(id) >= keep


## True if the chest is worth the risk of its guardian.
static func will_open_chest(player: PlayerData) -> bool:
	if player.difficulty == Level.EASY:
		return true
	var level := mini(player.level + SpaceEffects.GUARDIAN_LEVELS_AHEAD, PlayerData.MAX_LEVEL)
	return level_odds(player, level) >= CHEST_ODDS


## What fighting `rival` is worth, in gold. It is below 0 for a bad idea.
static func duel_value(player: PlayerData, rival: PlayerData) -> float:
	var odds := win_odds(Fighter.from_player(player), Fighter.from_player(rival))
	var bullying := Rivalry.is_bullying(player, rival)
	if odds < _nerve(player) - DUEL_NERVE_DISCOUNT or (bullying and not ShadowCrown.is_worn_by(rival)):
		return -1.0
	var prize := float(Battle.PVP_EXP_PER_LEVEL * rival.level) * EXP_VALUE
	if bullying:
		prize = -player.gold * Rivalry.BULLY_FINE_SHARE
	elif Rivalry.has_grudge(player, rival):
		prize *= Rivalry.REVENGE_EXP_TIMES
	if ShadowCrown.is_worn_by(rival):
		prize += ShadowCrown.bounty()
	else:
		prize += _spoil_worth(player, rival)
	if _quest_wants(player, Quest.Kind.DUEL):
		prize += float(GameState.quest["reward"])
	return odds * prize - (1.0 - odds) * (_spoil_worth(rival, player) + _turn_value(player))


## Who it challenges on a space, or null. Challenging gives up the space's effect.
static func pick_rival(player: PlayerData, rivals: Array[PlayerData], space: BoardNode) -> PlayerData:
	if player.difficulty == Level.EASY:
		if GameState.rng.randf() < EASY_CHALLENGE_CHANCE:
			return rivals[GameState.rng.randi_range(0, rivals.size() - 1)]
		return null
	var best: PlayerData = null
	var best_value := maxf(_space_effect_value(player, space), 0.0)
	for rival in rivals:
		var value := duel_value(player, rival)
		if value > best_value:
			best = rival
			best_value = value
	return best


## What it takes from a beaten rival. A town keeps paying, and gear it can wear beats
## selling it on.
static func pick_spoil(winner: PlayerData, options: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = options[0]
	var best_value := -1.0
	for option in options:
		var value: float = option["value"]
		if option["kind"] == Rivalry.Spoil.TOWN:
			value *= 2.0
		elif option["kind"] == Rivalry.Spoil.ITEM and _upgrade_value(winner, option["item"]) > 0.0:
			value *= 1.5
		if value > best_value:
			best = option
			best_value = value
	return best


static func _spoil_worth(winner: PlayerData, loser: PlayerData) -> float:
	var worth := loser.gold * Rivalry.GOLD_SHARE
	var item := Rivalry.best_item(loser)
	if item != "":
		worth = maxf(worth, Database.get_item(item).price)
	if ShadowCrown.is_worn_by(winner):
		var town := Rivalry.best_town(loser)
		if town >= 0:
			worth = maxf(worth, Town.worth(town) * 2.0)
	return worth


static func _storm_gain(player: PlayerData, id: int) -> float:
	var kept_level := maxi(Town.level(id) - 1, 1)
	return Town.income(id, kept_level) * INCOME_WEEKS + Town.toll(id) + Town.worth(id) * 0.5


static func _knockout_cost(player: PlayerData) -> float:
	return player.gold * Battle.KO_GOLD_SHARE + _turn_value(player)


static func _turn_value(player: PlayerData) -> float:
	return TURN_VALUE_BASE + TURN_VALUE_PER_LEVEL * player.level


static func _nerve(player: PlayerData) -> float:
	var nerve: float = _profile(player)["nerve"]
	if player.difficulty != Level.EASY:
		nerve += minf(player.gold / GOLD_PER_NERVE * 0.1, MAX_EXTRA_NERVE)
	return nerve


# --- Field magic ------------------------------------------------------------

## What it casts before rolling: {"spell", "target"}, or an empty Dictionary for
## nothing. `came_from` is the space its token may not walk straight back to.
static func field_plan(player: PlayerData, board: BoardManager, came_from: BoardNode) -> Dictionary:
	var options: Array[String] = FieldMagic.known(player).filter(func(id: String) -> bool:
			return FieldMagic.why_not(player, id) == "")
	if options.is_empty():
		return {}
	if player.difficulty == Level.EASY:
		return _random_field_plan(player, options)

	var outlook := _look_around(player, board)
	var here := board.get_board_node(player.space_id)
	var bonus := player.roll_bonus + ShadowCrown.roll_bonus(player)
	var today := _roll_value(outlook, here, came_from, bonus)
	var best := {}
	var best_value := 0.0
	for id in options:
		var plan := _rate_spell(player, id, outlook, today, came_from, bonus)
		var value: float = plan["value"] - _mana_price(player, id)
		if value > best_value:
			best = {"spell": id, "target": plan["target"]}
			best_value = value
	return best


# What a spell would earn: {"value", "target"}.
static func _rate_spell(player: PlayerData, id: String, outlook: Outlook, today: float,
		came_from: BoardNode, bonus: int) -> Dictionary:
	var here := outlook.board.get_board_node(player.space_id)
	var value := 0.0
	var target: PlayerData = null
	match Database.get_spell(id).field_effect:
		SpellData.FieldEffect.HASTE:
			value = _roll_value(outlook, here, came_from, bonus + FieldMagic.HASTE_STEPS) - today
		SpellData.FieldEffect.RECALL:
			value = _roll_value(outlook, outlook.board.get_starting_node(), null, bonus) - today
		SpellData.FieldEffect.LEECH:
			target = _gold_target(player, id)
			value = 2.0 * mini(int(target.gold * FieldMagic.LEECH_SHARE), FieldMagic.LEECH_MAX_PER_LEVEL * player.level)
		SpellData.FieldEffect.SLUMBER:
			target = _richest_target(player, id)
			value = _turn_value(target) * _target_times(player, target)
		SpellData.FieldEffect.MIRE:
			target = _richest_target(player, id)
			value = _turn_value(target) * _target_times(player, target) * MIRE_SHARE
	return {"value": value, "target": target}


static func _target_times(player: PlayerData, target: PlayerData) -> float:
	return TARGET_AHEAD_TIMES if Town.net_worth(target) > Town.net_worth(player) else TARGET_BEHIND_TIMES


# Picks at random, and aims at whoever is ahead. Going home would waste its lead.
static func _random_field_plan(player: PlayerData, options: Array[String]) -> Dictionary:
	options = options.filter(func(id: String) -> bool:
			return Database.get_spell(id).field_effect != SpellData.FieldEffect.RECALL)
	if options.is_empty() or GameState.rng.randf() >= EASY_CAST_CHANCE:
		return {}
	var id: String = options[GameState.rng.randi_range(0, options.size() - 1)]
	var target: PlayerData = null
	if FieldMagic.targets_rival(id):
		target = _richest_target(player, id)
	return {"spell": id, "target": target}


static func _richest_target(player: PlayerData, id: String) -> PlayerData:
	var targets := FieldMagic.valid_targets(player, id)
	for rival in Town.ranking():
		if targets.has(rival):
			return rival
	return null


static func _gold_target(player: PlayerData, id: String) -> PlayerData:
	var best: PlayerData = null
	for rival in FieldMagic.valid_targets(player, id):
		if best == null or rival.gold > best.gold:
			best = rival
	return best


static func _mana_price(player: PlayerData, id: String) -> float:
	var price: int = (MANA_PRICE + player.level) * Database.get_spell(id).mp_cost
	return price * (MANA_PRICE_CASTER_TIMES if _is_caster(player) else 1)


# --- Gear and the bag -------------------------------------------------------

## True if wearing `item_id` would be better than what is worn.
static func is_upgrade(player: PlayerData, item_id: String) -> bool:
	return _upgrade_value(player, item_id) > 0.0


## Before rolling: wears what is in the bag, unless `wear` is false, then uses healing
## items if it is hurt. Returns the names of the items it used.
static func tidy(player: PlayerData, wear := true) -> PackedStringArray:
	if wear:
		_wear_best(player)
	var used := PackedStringArray()
	if player.difficulty == Level.EASY:
		return used
	while player.hp < player.get_stat("max_hp") * TIDY_HEAL_BELOW:
		var cure := _fitting_item(player, "heal_hp", player.get_stat("max_hp") - player.hp)
		if cure == "" or not player.use_item(cure):
			break
		used.append(Database.get_item(cure).display_name)
	if _is_caster(player) and player.mp < player.get_stat("max_mp") * TIDY_MANA_BELOW:
		var tonic := _fitting_item(player, "heal_mp", player.get_stat("max_mp") - player.mp)
		if tonic != "" and player.use_item(tonic):
			used.append(Database.get_item(tonic).display_name)
	return used


## Shops: better gear first, then healing. Returns the names of what it bought.
static func shop(player: PlayerData, shelves: Array[String]) -> PackedStringArray:
	var bought := PackedStringArray()
	_sell_spare_gear(player)
	while true:
		var upgrade := _best_upgrade(player, shelves)
		if upgrade == "":
			break
		Shop.buy(player, upgrade)
		player.equip(upgrade)
		bought.append(Database.get_item(upgrade).display_name)
		_sell_spare_gear(player)
		if player.difficulty == Level.EASY:
			break
	var cures_wanted: int = _profile(player)["cures"]
	while _healing_items(player) < cures_wanted:
		var cure := _shelf_item(player, shelves, "heal_hp")
		if cure == "":
			break
		Shop.buy(player, cure)
		bought.append(Database.get_item(cure).display_name)
	if _is_caster(player) and player.difficulty == Level.HARD and not _carries(player, "heal_mp"):
		var tonic := _shelf_item(player, shelves, "heal_mp")
		if tonic != "":
			Shop.buy(player, tonic)
			bought.append(Database.get_item(tonic).display_name)
	return bought


# Wears whatever in the bag beats what is worn.
static func _wear_best(player: PlayerData) -> void:
	for id in player.inventory.duplicate():
		if Database.get_item(id).is_gear() and _upgrade_value(player, id) > 0.0:
			player.equip(id)


static func _sell_spare_gear(player: PlayerData) -> void:
	_wear_best(player)
	for id in player.inventory.duplicate():
		if Database.get_item(id).is_gear():
			Shop.sell(player, id)


static func _best_upgrade(player: PlayerData, shelves: Array[String]) -> String:
	var best := ""
	var best_value := 0.0
	for id in shelves:
		if not Database.get_item(id).is_gear() or Shop.why_not_buy(player, id) != "":
			continue
		var value := _upgrade_value(player, id)
		if value > best_value:
			best = id
			best_value = value
	return best


# How much better the item is than what is worn in its slot.
static func _upgrade_value(player: PlayerData, id: String) -> float:
	var item := Database.get_item(id)
	var value := _item_value(player, item)
	if player.equipment.has(item.kind):
		value -= _item_value(player, Database.get_item(player.equipment[item.kind]))
	return value


static func _item_value(player: PlayerData, item: ItemData) -> float:
	var main_stat := _main_stat(player)
	var value := 0.0
	for stat: String in item.bonuses:
		var weight: float = MAIN_STAT_WEIGHT if stat == main_stat else STAT_WEIGHTS.get(stat, 0.0)
		value += item.bonuses[stat] * weight
	return value


static func _main_stat(player: PlayerData) -> String:
	return "magic" if _is_caster(player) else "attack"


## True if this class hits harder with magic than with weapons.
static func _is_caster(player: PlayerData) -> bool:
	var data := Database.get_class_data(player.class_id)
	return data.base_stats["magic"] > data.base_stats["attack"]


static func _healing_items(player: PlayerData) -> int:
	var count := 0
	for id in player.inventory:
		if Database.get_item(id).heal_hp > 0:
			count += 1
	return count


static func _carries(player: PlayerData, property: String) -> bool:
	for id in player.inventory:
		if Database.get_item(id).get(property) > 0:
			return true
	return false


static func _bag_is_full(player: PlayerData) -> bool:
	return player.inventory.size() >= player.bag_size


# The bag's item that wastes least of `property` on a gap of `gap`, or "".
static func _fitting_item(player: PlayerData, property: String, gap: int) -> String:
	var best := ""
	var best_power := 0
	for id in player.inventory:
		var power: int = Database.get_item(id).get(property)
		if power <= 0:
			continue
		var better := power > best_power if best_power <= gap else power < best_power and power >= gap
		if best == "" or better:
			best = id
			best_power = power
	return best


# The strongest item on the shelves that takes at most half its gold, or else the
# cheapest it can pay for. Returns "" if there is none.
static func _shelf_item(player: PlayerData, shelves: Array[String], property: String) -> String:
	var strongest := ""
	var cheapest := ""
	for id in shelves:
		var item := Database.get_item(id)
		if item.get(property) <= 0 or Shop.why_not_buy(player, id) != "":
			continue
		if cheapest == "" or item.price < Database.get_item(cheapest).price:
			cheapest = id
		if item.price * 2 <= player.gold and (strongest == "" or item.get(property) > Database.get_item(strongest).get(property)):
			strongest = id
	return strongest if strongest != "" else cheapest


static func _profile(player: PlayerData) -> Dictionary:
	return PROFILES[player.difficulty]
