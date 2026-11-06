class_name TripReportCard
extends KitPanel
## The end of a trip, on paper: who, what happened, the best moment and the loot.

const WIDTH := 560.0
const PORTRAIT_SIZE := Vector2(112, 112)
const TEXT_WIDTH := 416.0
const STAT_GAP := 12

## The numbers along the bottom, which a keyboard can reach for their tips.
var stats: Array[KitChip] = []


func _init(person: Adventurer, report: TripReport) -> void:
	super(report.title, true)
	custom_minimum_size.x = WIDTH
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	var portrait := TextureRect.new()
	portrait.texture = person.portrait
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	top.add_child(portrait)
	top.add_child(Kit.text(" ".join(report.story), TEXT_WIDTH, &"PaperLabel"))
	if report.best != "":
		body.add_child(_best_moment(report.best))
	body.add_child(_stats(report))


func _best_moment(words: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var star := Kit.picture("star")
	star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(star)
	row.add_child(Kit.text(words, WIDTH - Kit.ICON_SIZE - 48.0, &"PaperLabel"))
	return row


func _stats(report: TripReport) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", STAT_GAP)
	row.add_child(_stat("food", report.days, "Days away"))
	row.add_child(_stat("boot", report.furthest, "Most steps from the Portal"))
	row.add_child(_stat("sword", report.fights_won, "Fights won"))
	row.add_child(_stat("star", report.levels_gained, "Levels gained on this trip"))
	row.add_child(_stat("coin", report.gold_home, "Gold brought home"))
	return row


func _stat(icon_name: String, amount: int, what: String) -> KitChip:
	var chip := KitChip.new(icon_name, amount)
	chip.focus_mode = Control.FOCUS_ALL
	Tips.attach(chip, what, str(amount))
	stats.append(chip)
	return chip
