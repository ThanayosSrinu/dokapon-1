class_name Stage
extends Resource
## A trip the Portal can lead to: one size of one place. Each is a .tres file in
## data/stages, and `id` must match the file name. A new stage needs only a new file, not
## a new screen. Stages with the same `place` are the sizes the Portal offers together.

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
## Which place this is a size of. Sizes of one place share this.
@export var place := ""
## A word for this size, on its button.
@export var size_name := ""
## One line about it, shown on its card.
@export_multiline var description := ""
## About how many spaces each new island has. Every trip makes a new island: see
## IslandMaker.gd.
@export var spaces := 36
## Its small view, from assets/custom/portal/. tools/art_portal.py draws these.
@export var picture: Texture2D
## Days the town's calendar moves on for a trip here, however it ends.
@export var days := 7
## About how many turns a whole trip here takes, said at the Portal so that the food can be
## judged. It never limits the food: only the person's own Max Food does.
@export var usual_food := 25
## How many monsters a trip here meets on the board, placed anew each trip. Tough
## monsters are counted apart, in `tough`.
@export var monsters := 0
## The monsters of this place: monster id -> how often it is met. A monster here
## belongs to the place, not to the hero's level, so going back somewhere easy feels easy.
@export var foes: Dictionary[String, int] = {}
## How many tough-monster spaces each island has. IslandMaker places them, and each is
## marked on the board, so the player can choose to face one or walk past.
@export var tough := 0
## The tough monsters of this place: monster id -> how often it is met.
@export var tough_foes: Dictionary[String, int] = {}
## How many chests a trip here finds, counting the ones the map file fixes in place.
@export var chests := 0



# Stage id -> an island made from a fixed seed, for numbers said before a trip starts.
static var _samples := {}


## A monster for an ordinary Battle space here.
func roll_foe() -> MonsterData:
	return Database.get_monster(SpaceEffects.weighted_pick(foes))


## A monster for a tough-monster space.
func roll_tough_foe() -> MonsterData:
	return Database.get_monster(SpaceEffects.weighted_pick(tough_foes))


## A monster to guard a chest here: the stronger of two of this place's foes.
func roll_guardian() -> MonsterData:
	var first := roll_foe()
	var second := roll_foe()
	return first if first.level >= second.level else second


## A new island for a trip here, the same for the same `seed_value`. A seed that makes no
## good island moves on to the next one, so this always gives one.
func make_map(seed_value: int) -> Dictionary:
	var data := IslandMaker.make(self, seed_value)
	var next := seed_value
	while data.is_empty():
		next += 1
		data = IslandMaker.make(self, next)
	return data


## One island made from a fixed seed, kept. The Portal uses it to judge food before the
## real island is made.
func sample_map() -> IslandMap:
	if not _samples.has(id):
		_samples[id] = IslandMap.new(make_map(1))
	return _samples[id]
