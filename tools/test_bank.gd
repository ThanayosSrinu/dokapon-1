extends "res://tools/test_kit.gd"
## Tests dates, bills, loans, time out, warnings and game over, with no window. Run with:
##   godot --headless --path . res://tools/test_bank.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const BANK := "res://bank/BankScreen.tscn"
const PORTAL := "res://portal/PortalScreen.tscn"
const GAME_OVER := "res://town/GameOverScreen.tscn"
const TAVERN := "res://tavern/TavernScreen.tscn"
const FAST := 40.0


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_calendar()
	_test_bills()
	_test_loans()
	_test_time_out()
	_test_next_step()
	_test_warning_steps()
	_test_forecast()
	_test_no_game_over_without_warning()
	await _test_date_chip()
	await _test_bank_screen()
	await _test_bank_with_mouse_and_pad()
	await _test_short_of_gold()
	await _test_loan_screen()
	await _test_rest()
	await _test_rest_past_the_due_day()
	await _test_portal_forecast()
	await _test_pick_who_goes()
	await _test_warnings_on_a_trip()
	await _test_game_over_after_the_report()
	await _test_game_over_screen()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _town_with(ids: Array[String], gold := 1000) -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 10000
	for id in ids:
		town.hire(Database.get_adventurer(id))
	town.gold = gold
	town.history.clear()
	return town


## The test the plan asks for: every rollover from day to year.
func _test_calendar() -> void:
	_expect(Calendar.DAYS_IN_MONTH == 28 and Calendar.DAYS_IN_YEAR == 336, "a month is 28 days and a year 336")
	_expect(Calendar.date(1) == "Y1 M1 D1", "day 1 is the first of everything")
	_expect(Calendar.date(5) == "Y1 M1 D5", "the days count up through the month")
	_expect(Calendar.date(8) == "Y1 M1 D8", "with no weeks in the date")
	_expect(Calendar.date(28) == "Y1 M1 D28", "day 28 ends the month")
	_expect(Calendar.date(29) == "Y1 M2 D1", "day 29 starts the next")
	_expect(Calendar.season(84) == "spring" and Calendar.season(85) == "summer", "three months make a season")
	_expect(Calendar.season(169) == "autumn" and Calendar.season(253) == "winter", "the seasons run in order")
	_expect(Calendar.date(336) == "Y1 M12 D28", "day 336 ends the year")
	_expect(Calendar.date(337) == "Y2 M1 D1", "day 337 starts the next")
	_expect(Calendar.season(337) == "spring", "and spring comes back")
	var last_date := 0
	for day in range(1, Calendar.DAYS_IN_YEAR * 3):
		_expect(Calendar.month(day) in range(1, 13), "month stays in range on day %d" % day)
		var date := Calendar.day_of_month(day)
		_expect(date in range(1, 29), "day of the month stays in range on day %d" % day)
		_expect(date == last_date % 28 + 1, "days follow in order on day %d" % day)
		last_date = date


func _test_bills() -> void:
	var town := _town_with(["bram"], 1000)
	var bram := Database.get_adventurer("bram")
	var tax := TownData.KING_TAX
	_expect(town.bill_due() == 56, "the first bill is due at the end of month 2")
	_expect(not town.bill_open(), "and no bill comes in the first month")
	_expect(town.pay_problem() == "No bill yet", "so there is nothing to pay")
	town.day = 28
	_expect(not town.bill_open(), "right up to its last day")
	town.day = 29
	_expect(town.bill_open(), "and it comes on the first day of month 2")
	_expect(town.bill_amount() == tax + bram.wage, "the bill is the tax and each wage")
	_expect(town.bill_lines().size() == 2, "each has its own line")
	town.gold = 10000
	town.hire(Database.get_adventurer("wren"))
	_expect(town.bill_amount() == tax + bram.wage + Database.get_adventurer("wren").wage, "someone new is on the bill")
	town.dismiss(Database.get_adventurer("wren"))
	_expect(town.bill_amount() == tax + bram.wage, "someone dismissed comes off it")
	town.gold = tax
	_expect(town.pay_problem() != "", "a bill can't be paid without the gold")
	_expect(not town.pay_bill() and town.gold == tax, "and trying changes nothing")
	town.gold = tax + bram.wage
	_expect(town.pay_bill() and town.gold == 0, "a bill can be paid with the last coin")
	_expect(town.months_paid == 1 and town.bill_due() == 84, "the next bill is a month later")
	_expect(not town.bill_open(), "and isn't listed yet")
	town.gold = 1000
	_expect(not town.pay_bill() and town.gold == 1000, "nothing can be paid twice")
	town.day = 56
	_expect(not town.bill_open(), "the paid month lasts to its end")
	town.day = 57
	_expect(town.bill_open(), "the next bill opens on the next day")
	_expect(town.overdue().is_empty(), "a paid bill is never overdue")
	town.day = 84
	_expect(town.overdue().is_empty(), "the due day itself is still in time")
	town.day = 85
	_expect(town.overdue()["what"] == "bill", "the day after, it is overdue")
	_expect(town.overdue()["amount"] == town.bill_amount(), "and says how much")


func _test_loans() -> void:
	var town := _town_with(["bram"], 0)
	town.day = 56
	_expect(TownData.loan_repays(500) == 600, "500 costs 600")
	_expect(TownData.loan_repays(100) == 120, "interest is flat")
	_expect(not town.borrow(77), "only the sums on offer")
	_expect(town.new_loan_due() == 84, "a loan today is due on day 84")
	_expect(town.borrow(500), "a loan can be taken")
	_expect(town.gold == 500, "it pays out")
	_expect(town.loan_owed == 600 and town.loan_due == 84, "and records what is owed")
	_expect(town.borrow_problem() != "", "one loan at a time")
	_expect(not town.borrow(100) and town.gold == 500, "a second changes nothing")
	_expect(town.repay_problem() != "", "it can't be repaid short")
	_expect(not town.repay() and town.gold == 500 and town.loan_owed == 600, "and trying changes nothing")
	town.gold = 601
	_expect(town.repay() and town.gold == 1, "it is repaid in full")
	_expect(town.loan_owed == 0 and town.borrow_problem() == "", "and another can be taken")
	_expect(not town.repay(), "nothing is left to repay")
	town = _town_with(["bram"], 0)
	town.day = 33
	town.borrow(100)
	_expect(town.next_debt()["what"] == "bill", "the bill on day 56 comes before the loan on day 61")
	town.months_paid = 1
	_expect(town.next_debt()["what"] == "loan", "with it paid, the loan is next")
	town.day = 61
	_expect(town.overdue().is_empty(), "a loan can be repaid on its due day")
	town.day = 62
	_expect(town.overdue()["what"] == "loan", "the day after, it is overdue")


func _ended_trip(town: TownData, ending: Expedition.Ending, days: int) -> Expedition:
	var trip := Expedition.new(town.going, town.stage, 1)
	trip.day = days
	trip.ending = ending
	return trip


func _test_time_out() -> void:
	var town := _town_with(["bram", "wren"])
	var bram := Database.get_adventurer("bram")
	var wren := Database.get_adventurer("wren")
	_expect(town.going == bram, "the first hired goes first")
	town.bring_home(_ended_trip(town, Expedition.Ending.BEATEN, 5))
	_expect(town.day == 6, "the days of a trip pass in town")
	var one := town.member(bram)
	_expect(one.days_out(town.day) == TownData.OUT_AFTER_DEFEAT, "a defeat costs days of work")
	_expect(one.trips == 1 and one.trips_home == 0, "and goes on their record")
	_expect(town.going == wren, "someone else steps up")
	_expect(not town.pick(bram), "the hurt can't be picked")
	town.bring_home(_ended_trip(town, Expedition.Ending.STARVED, 1))
	_expect(town.member(wren).days_out(town.day) == TownData.OUT_AFTER_DEFEAT, "hunger counts as a defeat")
	_expect(town.going == null and town.send_problem() == "Everyone is resting", "with all hurt, nobody can go")
	_expect(town.days_until_ready() == TownData.OUT_AFTER_DEFEAT - 1, "the soonest back is known")
	town.rest(town.days_until_ready())
	_expect(town.going == bram, "they come back in order")
	town.rest(1)
	_expect(town.pick(wren), "and a healed person can be picked")
	_expect(town.member(bram).days_out(town.day) == 0, "the count stops at 0")
	town.bring_home(_ended_trip(town, Expedition.Ending.WARPED, 0))
	_expect(town.member(wren).days_out(town.day) == TownData.OUT_AFTER_WARP, "the Warp Stone costs days too")
	var going_gold := town.gold
	town.pick(bram)
	var good := _ended_trip(town, Expedition.Ending.HOME, 4)
	good.player.gold = 90
	town.bring_home(good)
	_expect(town.gold == going_gold + 90, "gold from a good trip comes in")
	_expect(town.member(bram).days_out(town.day) == 0, "a trip home costs no days")
	_expect(town.member(bram).trips_home == 1 and town.member(bram).gold_home == 90, "and is on their record")


func _test_next_step() -> void:
	TownData.start_new()
	var town := TownData.current()
	_expect(town.next_step() == "tavern", "a new town starts at the Tavern")
	town.gold = 0
	_expect(town.next_step() == "bank", "with no gold and nobody, the Bank pays the next fee")
	town.gold = 500
	town.hire(Database.get_adventurer("bram"))
	_expect(town.next_step() == "portal", "with someone ready, the Portal is next")
	town.member(town.going).ready_on = 10
	town.rest(0)
	_expect(town.next_step() == "rest", "with everyone hurt, resting is next")
	town.day = 49
	_expect(town.next_step() == "bank", "a warning sends the player to the Bank")


func _test_warning_steps() -> void:
	var town := _town_with(["bram"])
	town.day = 48
	_expect(town.alert() == TownData.Alert.NONE, "8 days left is quiet")
	town.day = 49
	_expect(town.alert() == TownData.Alert.WARN, "7 days left is yellow")
	town.day = 52
	_expect(town.alert() == TownData.Alert.WARN, "4 days left is still yellow")
	town.day = 53
	_expect(town.alert() == TownData.Alert.ALARM, "3 days left is red")
	town.pay_bill()
	_expect(town.alert() == TownData.Alert.NONE, "paying clears it")
	town.borrow(100)
	town.day = 77
	_expect(town.alert() == TownData.Alert.WARN, "a loan warns too")
	_expect(town.alert(town.day + 1) == TownData.Alert.ALARM, "a day can be asked about ahead of time")


func _test_forecast() -> void:
	var town := _town_with(["bram"])
	var person := town.going
	var small := Database.get_stage("grass_s")
	var large := Database.get_stage("grass_l")
	var plan := town.forecast(small, person)
	_expect(plan["home"] > town.day, "nobody is home before they leave")
	_expect(plan["home"] <= plan["whole"], "a quick trip is no longer than a whole one")
	_expect(plan["whole"] == town.day + small.food_days, "a whole trip lasts as long as the food")
	_expect(plan["due"] == 56 and plan["fit"] == TownData.Forecast.SAFE, "day 1 has time for a small trip")
	town.day = 40
	_expect(town.forecast(large, person)["fit"] == TownData.Forecast.TIGHT, "a large trip then only fits if cut short")
	town.day = 55
	_expect(town.forecast(small, person)["fit"] == TownData.Forecast.LATE, "day 27 is too late for anything")


## The plan's fairness test. Every mix of resting and a trip of any length is walked as
## the screens show it: the town on arrival, and the strip each day of a trip. Whatever
## was shown only counts if it came before the due day had passed.
func _test_no_game_over_without_warning() -> void:
	for start in range(29, 56):
		for away in range(1, 45):
			for rests: int in [0, 1, 3, 7]:
				_play_out(start, rests, away)


func _play_out(start: int, rests: int, away: int) -> void:
	var town := _town_with(["bram"], 0)
	var due := town.bill_due()
	town.day = start
	town.show_alert()
	if rests > 0:
		town.rest(rests)
		if not town.overdue().is_empty():
			# One press of Rest can jump the last days, but never from an unwarned town.
			_expect(town.warned.get(due, 0) != TownData.Alert.NONE, "warned before resting past day %d" % due)
			return
		town.show_alert()
	for trip_day in range(1, away + 1):
		if town.day + trip_day <= due:
			town.show_alert(town.day + trip_day)
	town.day += away
	if not town.overdue().is_empty():
		_expect(town.warned.get(due, 0) == TownData.Alert.ALARM,
				"both steps shown before day %d, from day %d, rest %d, trip %d" % [due, start, rests, away])


func _test_date_chip() -> void:
	var town := _town_with(["bram"])
	var screen: TownScreen = await _open(TOWN)
	_expect(screen.date_chip.shown_words() == "Y1 M1 D1", "the town shows the date")
	_expect(screen.date_chip.level == TownData.Alert.NONE, "with nothing to fear yet")
	_expect(screen.signs["bank"].shown_mark() == "", "and the Bank's sign is plain")
	_expect(not screen.date_chip.get_global_rect().intersects(screen.gold_chip.get_global_rect()), "date and gold stay apart")
	town.day = 49
	screen = await _open(TOWN)
	_expect(screen.date_chip.level == TownData.Alert.WARN, "at 7 days left the date is yellow")
	_expect(screen.signs["bank"].shown_mark().contains("Y1 M2 D28"), "the Bank's sign is marked")
	_expect(screen.arrow.target == screen.building("bank"), "and the arrow goes there")
	_expect(_focused() == screen.building("bank"), "and so does the focus")
	town.day = 54
	screen = await _open(TOWN)
	_expect(screen.date_chip.level == TownData.Alert.ALARM, "at 3 days left it is red")
	var box: Rect2 = screen.signs["bank"].get_global_rect()
	var middle := screen.get_viewport_rect().size / 2.0
	_expect(Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE)).encloses(box), "the marked sign is on screen")
	_expect(not box.intersects(screen.building("bank").get_global_rect()), "and leaves the Bank in view")
	town.pay_bill()
	screen = await _open(TOWN)
	_expect(screen.date_chip.level == TownData.Alert.NONE, "paying clears the color")
	_expect(screen.signs["bank"].shown_mark() == "", "and the sign")


func _test_bank_screen() -> void:
	var town := _town_with(["bram", "wren"], 1000)
	var early: BankScreen = await _open(BANK)
	_expect(early.pay.disabled and early.pay.text == "No bill yet", "the first month has no bill to pay")
	town.day = 29
	var bill := town.bill_amount()
	var screen: TownScreen = await _open(TOWN)
	screen.building("bank").grab_focus()
	await _tap("ui_accept")
	await _until_settled()
	var bank: BankScreen = get_tree().current_scene
	_expect(bank is BankScreen, "Enter on the Bank goes inside")
	_expect(bank.pay.kind == KitButton.Kind.PRIMARY, "Pay is the main action")
	_expect(not bank.pay.disabled and bank.pay.text.contains(str(bill)), "Pay says how much")
	_expect(_focused() == bank.pay and bank.arrow.target == bank.pay, "and has focus and the arrow")
	_expect(bank._lines.get_child_count() == 4, "the tax, each wage and the total are listed")
	_expect(bank.back.position == Kit.BACK_POSITION, "Back is in its usual place")
	_expect(bank.bubble.shown_words().contains("Y1 M2 D28"), "the banker says when")
	var middle := bank.get_viewport_rect().size / 2.0
	var view := Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE))
	_expect(view.encloses(bank.pay.get_global_rect()), "Pay is on screen")
	_expect(view.encloses(bank.loan_button.get_global_rect()), "the loan is on screen")
	await _tap("ui_accept")
	await _wait()
	_expect(town.gold == 1000 - bill and town.months_paid == 1, "Enter pays the bill")
	await get_tree().create_timer(KitChip.ROLL_SECONDS).timeout
	_expect(bank.gold_chip.amount == town.gold, "the top bar shows the new gold")
	_expect(bank.pay.disabled, "Pay turns off")
	_expect(_focused() == bank.back and bank.arrow.target == bank.back, "and the way out is next")
	_expect(bank.bubble.shown_words() == BankScreen.SAY_PAID, "the banker thanks you")
	await _tap("ui_accept")
	await _wait()
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Back goes to town")


func _test_bank_with_mouse_and_pad() -> void:
	_town_with(["bram"], 1000)
	var bank: BankScreen = await _open(BANK)
	await get_tree().create_timer(Screens.WIPE_SECONDS).timeout
	await _click(bank.sizes[0])
	await _wait()
	_expect(bank.chosen_loan == TownData.LOAN_SIZES[0], "a click chooses a sum")
	_expect(bank.sizes[0].lit and not bank.sizes[2].lit, "and it is lit")
	_expect(bank._loan_words.text.contains("Borrow 100, repay 120 by Y1 M2 D1"), "the sum, cost and day show first")
	await _pad(JOY_BUTTON_B)
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "B leaves the Bank")


func _test_short_of_gold() -> void:
	var town := _town_with(["bram"], 100)
	town.day = 29
	var short := town.bill_amount() - 100
	var bank: BankScreen = await _open(BANK)
	_expect(bank.pay.disabled and bank.pay.text.contains(str(short)), "Pay says what is missing")
	_expect(bank.chosen_loan >= short, "the Bank offers a loan that covers it")
	_expect(bank.arrow.target == bank.loan_button, "the arrow points at the loan")
	_expect(_focused() == bank.loan_button, "and so does the focus")
	_expect(bank.bubble.shown_words().contains(str(short)), "the banker says so")
	await _tap("ui_accept")
	await _wait()
	_expect(town.loan_owed > 0, "Enter takes the loan")
	_expect(not bank.pay.disabled, "and now the bill can be paid")
	_expect(bank.arrow.target == bank.pay, "and the arrow says so")
	await _tap("ui_accept")
	await _wait()
	_expect(town.months_paid == 1, "a loan can pay a bill")
	_expect(town.next_debt()["what"] == "loan", "and then it is the next thing due")


func _test_loan_screen() -> void:
	var town := _town_with(["bram"], 1000)
	town.pay_bill()
	town.borrow(250)
	town.gold = 2
	var bank: BankScreen = await _open(BANK)
	_expect(not bank.sizes[0].is_visible_in_tree(), "with a loan, no sums are offered")
	_expect(bank._loan_words.text.contains("300") and bank._loan_words.text.contains("Y1 M2 D1"), "the debt shows with its day")
	_expect(bank.loan_button.disabled, "it can't be repaid short")
	_expect(_focused() == bank.back, "the way out has focus")
	town.gold = 400
	bank = await _open(BANK)
	_expect(bank.loan_button.text.contains("300") and not bank.loan_button.disabled, "with the gold, it can be repaid")
	_expect(_focused() == bank.loan_button, "and that has focus")
	await _tap("ui_accept")
	await _wait()
	_expect(town.loan_owed == 0 and town.gold == 100, "Enter repays it all")
	_expect(bank.sizes[0].is_visible_in_tree(), "and the sums are back")
	_expect(bank.bubble.shown_words() == BankScreen.SAY_REPAID, "the banker says so")


func _test_rest() -> void:
	var town := _town_with(["bram"])
	var person := town.going
	town.member(person).ready_on = 4
	town.rest(0)
	var screen: TownScreen = await _open(TOWN)
	_expect(screen.arrow.target == screen.rest_button, "with everyone hurt, the arrow points at Rest")
	_expect(_focused() == screen.rest_button, "and it has focus")
	_expect(screen.waiting == null, "nobody waits at the Portal")
	await _tap("ui_accept")
	await _wait()
	_expect(screen.rest_panel.visible, "Enter opens the panel")
	_expect(_focused() == screen.rest_panel.day_buttons[0], "on the shortest rest")
	await _tap("ui_accept")
	await _wait()
	_expect(town.day == 2, "a day passes")
	_expect(get_tree().current_scene == screen and screen.rest_panel.visible, "and the panel stays")
	await _tap("ui_right")
	await _tap("ui_accept")
	await _wait()
	_expect(town.day == 5, "three more pass")
	_expect(town.going == person, "and they have healed")
	_expect(screen.date_chip.shown_words() == "Y1 M1 D5", "the date shows the day of the month")
	_expect(screen.waiting != null, "they wait at the Portal again")
	await _tap("ui_right")
	await _tap("ui_accept")
	await _wait()
	_expect(screen.date_chip.shown_words() == Calendar.date(town.day) and town.day > 5, "the date moves on")
	await _tap("ui_cancel")
	await _wait()
	_expect(not screen.rest_panel.visible and get_tree().current_scene == screen, "Esc closes the panel, and stays")
	_expect(_focused() == screen.arrow.target, "focus goes where the arrow points")


func _test_rest_past_the_due_day() -> void:
	var town := _town_with(["bram"])
	town.day = 55
	var screen: TownScreen = await _open(TOWN)
	screen.rest_button.grab_focus()
	await _tap("ui_accept")
	await _wait()
	var panel := screen.rest_panel
	_expect(not panel.day_buttons[0].danger, "a rest up to the due day is safe")
	_expect(panel.day_buttons[1].danger and panel.day_buttons[2].danger, "a rest past it is stained red")
	_expect(panel._warning.visible, "and says why")
	panel.day_buttons[1].pressed.emit()
	await _until_settled()
	_expect(get_tree().current_scene is GameOverScreen, "resting past a due day loses the town")


func _test_portal_forecast() -> void:
	var town := _town_with(["bram"])
	var portal: PortalScreen = await _open(PORTAL)
	_expect(portal.card.shown_forecast(0) == "Home Y1 M1 D8", "a small trip is back after 7 days")
	_expect(portal.card.shown_forecast(1) == "Home Y1 M1 D15", "a medium trip after 14")
	_expect(portal.card.shown_forecast(2) == "Home Y1 M1 D22", "a large trip after 21")
	_expect(portal.card._forecasts[0].get_theme_color("font_color") == PortalScreen.FIT_COLORS[TownData.Forecast.SAFE],
			"a safe trip is green")
	var middle := portal.get_viewport_rect().size / 2.0
	var view := Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE))
	_expect(view.encloses(portal.card.get_global_rect()), "the card still fits")
	portal.card.enter.pressed.emit()
	await get_tree().process_frame
	_expect(not portal.warning.visible and portal._leaving, "a trip home in time goes straight in")
	town.day = 45
	town.stage = portal._sizes[2]
	portal = await _open(PORTAL)
	var plan := town.forecast(town.stage, town.going)
	_expect(plan["fit"] == TownData.Forecast.TIGHT, "this trip only fits if cut short")
	portal.card.enter.pressed.emit()
	await get_tree().process_frame
	_expect(portal.warning.visible and not portal._leaving, "a risky trip stops to warn")
	_expect(portal.warning.shown_words().contains(str(town.bill_amount())), "with what is owed")
	_expect(portal.warning.shown_words().contains("Y1 M2 D28"), "and the due day")
	_expect(portal.warning.shown_words().contains(Calendar.date(plan["whole"])), "and the day home")
	_expect(view.encloses(portal.warning.get_global_rect()), "the warning fits")
	_expect(_focused() == portal.warning.bank_button, "the Bank has the focus, not Go on")
	await _tap("ui_up")
	await _tap("ui_down")
	_expect(_focused() == portal.warning.bank_button, "the keys stay in the warning")
	await _tap("ui_cancel")
	_expect(not portal.warning.visible and get_tree().current_scene == portal, "Esc goes back to the card")
	_expect(_focused() == portal.card.enter, "with the focus on Enter")
	await _tap("ui_accept")
	await _tap("ui_left")
	_expect(_focused() == portal.warning.go_button, "left reaches Go on")
	await _tap("ui_accept")
	_expect(not portal.warning.visible and portal._leaving, "Go on goes in anyway")
	town.day = 54
	town.stage = portal._sizes[0]
	portal = await _open(PORTAL)
	_expect(portal.card._forecasts[0].get_theme_color("font_color") == PortalScreen.FIT_COLORS[TownData.Forecast.LATE],
			"a trip that can't make it is red")
	portal.card.enter.pressed.emit()
	await get_tree().process_frame
	_expect(portal.warning.visible, "and it warns")
	_expect(town.warned.get(town.next_due(), 0) == TownData.Alert.ALARM, "which counts as warning the player")
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is BankScreen, "the warning goes to the Bank")


func _test_pick_who_goes() -> void:
	var town := _town_with(["bram", "wren", "maren"])
	var bram := Database.get_adventurer("bram")
	var wren := Database.get_adventurer("wren")
	var maren := Database.get_adventurer("maren")
	town.member(maren).ready_on = 4
	var portal: PortalScreen = await _open(PORTAL)
	var people := portal.card.people
	_expect(people.size() == 3, "everyone on the roster has a button")
	_expect(people[0].lit and not people[1].lit, "who goes is lit")
	_expect(people[2].disabled and people[2].text == "3 days", "the hurt can't be picked, and say how long")
	_expect(portal.card.shown_person() == "Bram", "the card shows who goes")
	await _tap("ui_up")
	_expect(_focused() == people[0], "up from Enter reaches who goes")
	await _tap("ui_right")
	_expect(_focused() == people[1], "right walks along the people")
	await _tap("ui_accept")
	await _wait()
	_expect(town.going == wren, "pressing picks them")
	_expect(portal.card.shown_person() == "Wren" and people[1].lit, "the card follows")
	_expect(portal.heading.text.contains("Wren"), "and the heading")
	_expect(portal.hero.texture == wren.sheet, "and they stand on the road")
	_expect(portal.card.food.trip_days == town.stage.food_days, "the food follows them")
	people[2].pressed.emit()
	await _wait()
	_expect(town.going == wren, "the hurt stay at home")
	_expect(bram != null, "nobody was lost")
	town = _town_with(["bram"])
	portal = await _open(PORTAL)
	_expect(portal.card.people.is_empty(), "with one person there is nothing to pick")


## Plays a trip with the bill nearly due, until `done` says to stop.
func _open_trip(seed_value: int, recall_day: int) -> ExpeditionScreen:
	ExpeditionScreen.next_seed = seed_value
	ExpeditionScreen.next_recall_day = recall_day
	ExpeditionScreen.chosen_speed = 1.0
	var screen: ExpeditionScreen = await _open(TOWN.replace("town/TownScreen", "expedition/ExpeditionScreen"))
	ExpeditionScreen.next_seed = 0
	ExpeditionScreen.next_recall_day = 0
	screen._set_speed(FAST)
	return screen


func _test_warnings_on_a_trip() -> void:
	var town := _town_with(["bram"])
	town.day = 47
	town.stage = Database.get_stage("grass_l")
	var screen := await _open_trip(3, 0)
	while not screen.trip.is_over() and screen.trip.day < 7:
		await get_tree().process_frame
	_expect(_said(screen.trip, "due in 7 days"), "they speak up at 7 days left")
	_expect(_said(screen.trip, "due in 3 days") or screen.trip.is_over(), "and again at 3 days left")
	_expect(screen.orders_arrow != null or screen.trip.is_over(), "the arrow points at Orders")
	screen.free()
	Engine.time_scale = 1.0
	await _wait()
	town.day = 54
	town.stage = Database.get_stage("grass_s")
	var late := await _open_trip(3, 0)
	while late.trip.day < 2 and not late.trip.is_over():
		await get_tree().process_frame
	_expect(_said(late.trip, "due in 1 day!"), "leaving late, they still say so on the first day")
	late.free()
	Engine.time_scale = 1.0
	await _wait()


func _said(trip: Expedition, words: String) -> bool:
	for line in trip.diary:
		if line["kind"] == "say" and line["text"].contains(words):
			return true
	return false


## Rule D11: a trip is never stopped, and the game over comes after its report.
func _test_game_over_after_the_report() -> void:
	var town := _town_with(["bram"], 5000)
	town.day = 55
	var screen := await _open_trip(5, 0)
	screen._warp_home.call_deferred()
	# The Warp Stone ends it at once, so three days of trip are added by hand.
	while screen.report == null:
		await get_tree().process_frame
	await _until_settled()
	_expect(get_tree().current_scene == screen, "the report comes first")
	town.day = 58
	await _tap("ui_accept")
	await _until_settled()
	_expect(get_tree().current_scene is GameOverScreen, "then the town is lost, whatever gold there is")


func _test_game_over_screen() -> void:
	var town := _town_with(["bram"], 412)
	town.day = 48
	town.remember_leaving()
	town.day = 59
	var bill := town.bill_amount()
	var over: GameOverScreen = await _open(GAME_OVER)
	_expect(over.story.size() == 2, "it tells what happened")
	_expect(over.story[0].begins_with("Y1 M2 D20:") and over.story[0].contains("412"), "starting with the day they left")
	_expect(over.story[-1].begins_with("Y1 M2 D28:") and over.story[-1].contains(str(bill)), "and ending with the bill")
	_expect(_focused() == over.new_town, "one button has focus")
	_expect(over.new_town.kind == KitButton.Kind.PRIMARY, "and it is the main action")
	var middle := over.get_viewport_rect().size / 2.0
	_expect(Rect2(middle - Vector2(WIDE) / 2.0, Vector2(WIDE)).encloses(over.new_town.get_global_rect()), "it is on screen")
	var fresh := TownData.current()
	_expect(fresh != town and fresh.gold == TownData.START_GOLD and fresh.day == 1, "the old town is gone")
	await _tap("ui_accept")
	await _until_settled()
	var screen: TownScreen = get_tree().current_scene
	_expect(screen is TownScreen, "the button starts a new town at once")
	_expect(_focused() == screen.building("tavern"), "at the Tavern")
	town = _town_with(["bram"])
	town.day = 57
	over = await _open(GAME_OVER)
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc does the same")
