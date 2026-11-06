class_name TripHud
extends KitPanel
## The strip along the bottom while a trip plays. The top row is the date, health, food,
## bag and gold. The bottom row is who is out there and their stats, which turn red while
## hunger has them weak. Food turns gold once they ask to come home, because that is the
## lord's cue.
## Each part has a tip with the exact numbers (rule U3).

const BAR_WIDTH := 160.0
const HP_WORDS_WIDTH := 76.0
const FOOD_WORDS_WIDTH := 96.0
const WHO_WIDTH := 148.0
const GAP := 18
const ROW_GAP := 6
## The stats on the bottom row, with what each is called on screen.
const STATS := [
	{"stat": "attack", "short": "AT", "name": "Attack", "icon": "sword"},
	{"stat": "defense", "short": "DEF", "name": "Defense", "icon": "shield"},
	{"stat": "magic", "short": "MG", "name": "Magic", "icon": "magic"},
	{"stat": "speed", "short": "SPD", "name": "Speed", "icon": "boot"},
]

var date: DateChip
var hp_bar: KitBar
var hp_words: Label
var food_bar: KitBar
var food_words: Label
var bag: KitChip
var gold: KitChip
var who: Label
## One per entry of STATS, in the same order.
var stats: Array[KitStat] = []
## Says so while they are weak, for those who do not read colors.
var weak_words: Label

var _trip: Expedition
# The food they set out with, which is a full bar.
var _food_full := 1


func _init(trip: Expedition, stage: Stage) -> void:
	super()
	_trip = trip
	_food_full = maxi(stage.food_for(trip.person), 1)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	body.add_child(rows)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	rows.add_child(row)
	date = DateChip.new(true)
	date.focus_mode = Control.FOCUS_ALL
	date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(date)
	hp_bar = _bar(row, Kit.HEALTH, "heart")
	hp_words = _words(row, HP_WORDS_WIDTH)
	food_bar = _bar(row, Kit.SUPPLY, "food")
	food_words = _words(row, FOOD_WORDS_WIDTH)
	bag = _chip(row, "bag")
	gold = _chip(row, "coin")
	_build_stats(rows)


func _ready() -> void:
	refresh(false)
	_trip.player.changed.connect(refresh)


## Shows the trip as it stands.
func refresh(slide := true) -> void:
	var player := _trip.player
	var max_hp: int = player.get_stat("max_hp")
	var town := TownData.current()
	date.show_day(town, town.day + _trip.day)
	hp_bar.set_amount(player.hp, max_hp, slide)
	hp_words.text = "%d/%d" % [player.hp, max_hp]
	food_bar.set_amount(_trip.food_left, _food_full, slide)
	food_words.text = "No food!" if _trip.food_left == 0 else _days(_trip.food_left)
	food_words.modulate = _food_color()
	bag.set_amount(player.inventory.size(), slide)
	gold.set_amount(player.gold, slide)
	who.text = "%s  Lv %d" % [player.player_name, player.level]
	weak_words.visible = player.weak
	for index in STATS.size():
		_show_stat(stats[index], STATS[index], slide)
	Tips.attach(hp_bar, "Health", "%d of %d HP." % [player.hp, max_hp])
	Tips.attach(food_bar, "Food", _food_tip())
	Tips.attach(bag, "Bag", "%d of %d places used." % [player.inventory.size(), PlayerData.INVENTORY_SIZE])
	Tips.attach(gold, "Gold found", "%d gold. It only counts if they get home." % player.gold)


## Shows an empty health bar, because a defeat refills HP for the old board game.
func show_beaten() -> void:
	hp_bar.set_amount(0.0, 1.0)
	hp_words.text = "0/%d" % _trip.player.get_stat("max_hp")


func _build_stats(rows: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	rows.add_child(row)
	who = _words(row, WHO_WIDTH)
	for entry: Dictionary in STATS:
		var stat := KitStat.new(entry["icon"], entry["short"])
		stat.focus_mode = Control.FOCUS_ALL
		row.add_child(stat)
		stats.append(stat)
	weak_words = _words(row, 0.0)
	weak_words.text = "Weak!"
	weak_words.modulate = KitStat.LOW
	weak_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weak_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _show_stat(stat: KitStat, entry: Dictionary, slide: bool) -> void:
	var player := _trip.player
	var now: int = player.get_stat(entry["stat"])
	var fed: int = player.fed_stat(entry["stat"])
	stat.set_value(now, fed, slide)
	var tip := "%s is %d." % [entry["name"], now]
	if now < fed:
		tip = "%s is %d, down from %d. Hunger has them weak." % [entry["name"], now, fed]
	Tips.attach(stat, entry["name"], tip)


func _food_color() -> Color:
	if _trip.food_left == 0:
		return Kit.DANGER.lightened(0.3)
	return Kit.GOLD if _trip.asked_home else Color.WHITE


func _food_tip() -> String:
	var home := "About %s from the Portal." % _days(ceili(_trip.brain.days_home()))
	if _trip.food_left > 0:
		return "Food for %s. One roll of the die is one day. %s" % [_days(_trip.food_left), home]
	return "No food left. They lose health every day, and grow weak. %s" % home


func _days(count: int) -> String:
	return "1 day" if count == 1 else "%d days" % count


func _bar(row: Control, color: Color, icon_name: String) -> KitBar:
	var bar := KitBar.new(color, Kit.icon(icon_name))
	bar.width = BAR_WIDTH
	bar.focus_mode = Control.FOCUS_ALL
	row.add_child(bar)
	return bar


func _words(row: Control, width: float) -> Label:
	var words := Kit.text("")
	words.custom_minimum_size.x = width
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	return words


func _chip(row: Control, icon_name: String) -> KitChip:
	var chip := KitChip.new(icon_name)
	chip.focus_mode = Control.FOCUS_ALL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	return chip
