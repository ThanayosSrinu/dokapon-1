class_name BankScreen
extends Control
## The Bank. The card on the right lists the month's bill with one Pay button, and the
## panel on the left is the loan. The rules are in TownData: this only asks and redraws.

const TOWN := "res://town/TownScreen.tscn"
const STAGE := Vector2(1280, 720)
const CARD_LEFT := 816.0
const CARD_TOP := 92.0
const CARD_WIDTH := 440.0
const LOAN_SPOT := Vector2(112, 300)
const LOAN_WIDTH := 584.0
## Speech bubbles stay inside the room's part of the stage.
const ROOM_AREA := Rect2(0, 0, 808, 720)
const BAR_MARGIN := 24.0
const BAR_GAP := 8
const SAY_OPEN := "Everything falls due on %s, my lord."
const SAY_SHORT := "You are %d gold short, my lord. A loan could help."
const SAY_PAID := "Paid in full. Thank you, my lord."
const SAY_LOAN := "The gold is yours. Remember the day, my lord."
const SAY_REPAID := "The loan is cleared."

var back: KitBackButton
var pay: KitButton
## Takes a loan, or repays the one there is.
var loan_button: KitButton
## One for each sum on offer.
var sizes: Array[KitButton] = []
var gold_chip: KitChip
var date_chip: DateChip
var arrow: KitArrow
var bubble: TavernBubble
## The sum a new loan would be for.
var chosen_loan: int = TownData.LOAN_SIZES[-1]

var _stage: Node2D
var _lines: VBoxContainer
var _bill_title: Label
var _bill_when: Label
var _loan_words: Label
var _size_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var town := TownData.current()
	_stage = Node2D.new()
	_stage.position = _stage_corner()
	add_child(_stage)
	var room := BankRoom.new()
	_stage.add_child(room)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	layer.add_child(_build_card())
	layer.add_child(_build_loan())
	bubble = TavernBubble.new()
	_stage.add_child(bubble)
	_build_top_bar(town)
	arrow = KitArrow.new(null, KitArrow.Side.LEFT)
	add_child(arrow)
	_link_focus()
	_suggest_loan(town)
	_refresh(town, false)
	(arrow.target if arrow.target != null else back).grab_focus()
	_greet(town)
	Sound.music("shop")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _process(_delta: float) -> void:
	_stage.position = _stage_corner()


func _stage_corner() -> Vector2:
	return Kit.snap_point(((get_viewport_rect().size - STAGE) / 2.0).max(Vector2.ZERO))


func _build_card() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PaperPanel"
	card.custom_minimum_size.x = CARD_WIDTH
	card.position = Vector2(CARD_LEFT, CARD_TOP)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	_bill_title = Kit.text("", 0.0, &"PaperHeading")
	column.add_child(_bill_title)
	_bill_when = Kit.text("", 0.0, &"PaperTitle")
	column.add_child(_bill_when)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 8)
	column.add_child(_lines)
	pay = KitButton.new()
	pay.kind = KitButton.Kind.PRIMARY
	pay.press_sound = "coin"
	pay.pressed.connect(_on_pay)
	column.add_child(pay)
	return card


func _build_loan() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PaperPanel"
	panel.custom_minimum_size.x = LOAN_WIDTH
	panel.position = LOAN_SPOT
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(Kit.text("A loan", 0.0, &"PaperHeading"))
	_size_row = HBoxContainer.new()
	_size_row.add_theme_constant_override("separation", 8)
	column.add_child(_size_row)
	for amount in TownData.LOAN_SIZES:
		var button := KitButton.new()
		button.kind = KitButton.Kind.SMALL
		button.text = "%d gold" % amount
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_loan.bind(amount))
		_size_row.add_child(button)
		sizes.append(button)
	_loan_words = Kit.text("", LOAN_WIDTH - 32.0, &"PaperLabel")
	column.add_child(_loan_words)
	loan_button = KitButton.new()
	loan_button.press_sound = "coin"
	loan_button.pressed.connect(_on_loan)
	column.add_child(loan_button)
	return panel


func _build_top_bar(town: TownData) -> void:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", BAR_GAP)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = BAR_MARGIN
	bar.offset_right = -BAR_MARGIN
	bar.offset_top = BAR_MARGIN
	add_child(bar)
	date_chip = DateChip.new()
	bar.add_child(date_chip)
	gold_chip = KitChip.new("coin", town.gold)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(gold_chip)
	Tips.attach(gold_chip, "Gold", "Pays for adventurers, bills and upgrades.")
	back = KitBackButton.new()
	back.pressed.connect(_leave)
	add_child(back)


## Left and right cross the room, the sums walk along their row, and Back is up.
func _link_focus() -> void:
	for index in sizes.size():
		var button := sizes[index]
		button.focus_neighbor_top = button.get_path_to(back)
		button.focus_neighbor_bottom = button.get_path_to(loan_button)
		button.focus_neighbor_left = button.get_path_to(sizes[maxi(index - 1, 0)])
		button.focus_neighbor_right = button.get_path_to(sizes[index + 1] if index + 1 < sizes.size() else pay)
	loan_button.focus_neighbor_top = loan_button.get_path_to(sizes[0])
	loan_button.focus_neighbor_bottom = loan_button.get_path_to(loan_button)
	loan_button.focus_neighbor_left = loan_button.get_path_to(loan_button)
	loan_button.focus_neighbor_right = loan_button.get_path_to(pay)
	pay.focus_neighbor_top = pay.get_path_to(back)
	pay.focus_neighbor_bottom = pay.get_path_to(pay)
	pay.focus_neighbor_right = pay.get_path_to(pay)
	pay.focus_neighbor_left = pay.get_path_to(loan_button)
	back.focus_neighbor_top = back.get_path_to(back)
	back.focus_neighbor_left = back.get_path_to(back)
	back.focus_neighbor_right = back.get_path_to(pay)
	back.focus_neighbor_bottom = back.get_path_to(pay)


# With a bill it can't pay, the Bank starts on the smallest loan that covers it.
func _suggest_loan(town: TownData) -> void:
	var short := town.bill_amount() - town.gold
	if not town.bill_open() or short <= 0:
		return
	for amount in TownData.LOAN_SIZES:
		if amount >= short:
			chosen_loan = amount
			return


func _refresh(town: TownData, roll := true) -> void:
	gold_chip.set_amount(town.gold, roll)
	date_chip.show_day(town, town.day)
	_show_bill(town)
	_show_loan(town)
	_aim_arrow(town)


func _show_bill(town: TownData) -> void:
	for child in _lines.get_children():
		child.queue_free()
	var problem := town.pay_problem()
	if not town.bill_open():
		_bill_title.text = "Nothing to pay"
		_bill_when.text = "The next bill comes on %s" % Calendar.date(town.bill_due() - Calendar.DAYS_IN_MONTH + 1)
		pay.text = problem
		pay.block("The first bill comes next month." if town.months_paid == 0 else "This month's bill is paid.")
		return
	var left := town.bill_due() - town.day
	_bill_title.text = "This month's bill"
	_bill_when.text = "Pay by %s" % Calendar.date(town.bill_due())
	if left == 0:
		_bill_when.text += ", which is today"
	elif left <= TownData.WARN_DAYS:
		_bill_when.text += ", in %s" % TownData.days_words(left)
	for line in town.bill_lines():
		_lines.add_child(_row(line["text"], line["amount"]))
	_lines.add_child(_row("In all", town.bill_amount(), &"PaperTitle"))
	pay.text = problem if problem != "" else "Pay %d gold" % town.bill_amount()
	pay.block("You have %d gold, and the bill is %d." % [town.gold, town.bill_amount()] if problem != "" else "")


func _row(words: String, amount: int, style := &"PaperLabel") -> Control:
	var row := HBoxContainer.new()
	var name_label := Kit.text(words, 0.0, style)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var number := Kit.text(str(amount), 0.0, style)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	return row


func _show_loan(town: TownData) -> void:
	var owing := town.loan_owed > 0
	for index in sizes.size():
		sizes[index].lit = TownData.LOAN_SIZES[index] == chosen_loan
		sizes[index].visible = not owing
	_size_row.visible = not owing
	if owing:
		_loan_words.text = "You owe %d gold by %s. Repay it all, or it is GAME OVER." % [town.loan_owed, Calendar.date(town.loan_due)]
		var problem := town.repay_problem()
		loan_button.text = problem if problem != "" else "Repay %d gold" % town.loan_owed
		loan_button.block("You have %d gold, and the loan is %d." % [town.gold, town.loan_owed] if problem != "" else "")
		return
	var repays := TownData.loan_repays(chosen_loan)
	_loan_words.text = "Borrow %d, repay %d by %s. It must all be repaid by then, or it is GAME OVER." % [chosen_loan, repays, Calendar.date(town.new_loan_due())]
	loan_button.text = "Borrow %d gold" % chosen_loan
	loan_button.block("")


# The arrow goes to what most needs doing, or the way out.
func _aim_arrow(town: TownData) -> void:
	if town.pay_problem() == "":
		_point_at(pay, KitArrow.Side.LEFT)
	elif town.bill_open() and town.loan_owed == 0:
		_point_at(loan_button, KitArrow.Side.LEFT)
	elif town.loan_owed > 0 and town.repay_problem() == "":
		_point_at(loan_button, KitArrow.Side.LEFT)
	else:
		_point_at(back, KitArrow.Side.RIGHT)


func _point_at(target: Control, side: KitArrow.Side) -> void:
	arrow.target = target
	arrow.side = side
	arrow.rotation = KitArrow.TURNS[side]


func _greet(town: TownData) -> void:
	if not town.bill_open():
		return
	var short := town.bill_amount() - town.gold
	_say(SAY_SHORT % short if short > 0 else SAY_OPEN % Calendar.date(town.bill_due()))


func _say(words: String) -> void:
	var area := Rect2(ROOM_AREA.position + _stage.position, ROOM_AREA.size)
	bubble.say(words, BankRoom.BANKER_HEAD + _stage.position, area)


func _choose_loan(amount: int) -> void:
	chosen_loan = amount
	_show_loan(TownData.current())


func _on_pay() -> void:
	var town := TownData.current()
	if not town.pay_bill():
		pay.deny()
		return
	_say(SAY_PAID)
	_refresh(town)
	back.grab_focus()


func _on_loan() -> void:
	var town := TownData.current()
	var done := town.repay() if town.loan_owed > 0 else town.borrow(chosen_loan)
	if not done:
		loan_button.deny()
		return
	_say(SAY_LOAN if town.loan_owed > 0 else SAY_REPAID)
	_refresh(town)
	(arrow.target if arrow.target != null else back).grab_focus()


func _leave() -> void:
	Screens.go(TOWN)
