extends Control
## Progress report for parents and teachers: how each level went, and which
## exercises needed extra help (lots of wrong tries, or a hint).

signal closed

const Challenges = preload("res://scripts/lab_challenges.gd")
const Lang = preload("res://scripts/lang.gd")
const HELP_TRIES := 3  # this many wrong tries counts as "needed extra help"

var body: RichTextLabel


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)

	var bg := ColorRect.new()
	bg.color = Color("#f8fafc")
	bg.size = size
	add_child(bg)

	var close := Button.new()
	close.text = "Close (Esc)"
	close.position = Vector2(810, 18)
	close.size = Vector2(130, 40)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(_close)
	add_child(close)

	body = RichTextLabel.new()
	body.position = Vector2(36, 20)
	body.size = Vector2(888, 600)
	body.bbcode_enabled = true
	body.add_theme_color_override("default_color", Color("#0f172a"))
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_font_size_override("bold_font_size", 16)
	body.add_theme_constant_override("table_h_separation", 18)
	body.add_theme_constant_override("table_v_separation", 6)
	add_child(body)


func open(levels: Array, save) -> void:
	var name: String = save.look.get("name", "")
	var solved_total := 0
	for i in levels.size():
		solved_total += save.solved_in_level(i)
	var text := "[font_size=28][b]" + tr("Progress report: %s") % (name if name != "" else tr("Player")) + "[/b][/font_size]\n"
	text += ("[color=#475569]" + tr("Exercises solved:") + " [b]%d / %d[/b]     " + tr("Quizzes passed:") + " [b]%d / %d[/b]     " + tr("Code Lab challenges:") + " [b]%d / %d[/b]     </> " + tr("icons:") + " [b]%d[/b][/color]\n\n") % [
		solved_total, levels.size() * 10, save.quiz_scores.size(), levels.size(),
		save.lab_done.size(), Challenges.CHALLENGES.size(), save.icons]

	text += "[table=5]"
	for heading in ["Level", "Exercises", "Wrong tries", "Hints used", "Quiz (best / tries)"]:
		text += "[cell][b]%s[/b][/cell]" % tr(heading)
	var tricky := []
	for i in levels.size():
		var level: Dictionary = levels[i]
		var tries := 0
		var hints := 0
		for exercise in level["exercises"]:
			var s: Dictionary = save.stats.get(exercise["id"], {})
			tries += s.get("tries", 0)
			hints += s.get("hints", 0)
			if s.get("solved", false) and (s.get("tries", 0) >= HELP_TRIES or s.get("hints", 0) > 0):
				tricky.append({"level": i, "title": Lang.pick(exercise, "title"), "tries": s.get("tries", 0), "hints": s.get("hints", 0)})
		var locked: bool = i >= save.unlocked
		var quiz := "-"
		if save.is_done(i):
			quiz = "%d/5  (%d)" % [save.quiz_scores[i], save.quiz_attempts.get(i, 1)]
		elif save.quiz_attempts.get(i, 0) > 0:
			quiz = tr("not passed yet") + "  (%d)" % save.quiz_attempts[i]
		var color := "#94a3b8" if locked else "#0f172a"
		text += "[cell][color=%s]%d. %s[/color][/cell]" % [color, i + 1, Lang.pick(level, "name")]
		text += "[cell][color=%s]%s[/color][/cell]" % [color, tr("locked") if locked else "%d / 10" % save.solved_in_level(i)]
		text += "[cell][color=%s]%s[/color][/cell]" % [_heat(tries, 10, 20), str(tries) if not locked else ""]
		text += "[cell][color=%s]%s[/color][/cell]" % [_heat(hints, 2, 5), str(hints) if not locked else ""]
		text += "[cell][color=%s]%s[/color][/cell]" % [color, quiz]
	text += "[/table]\n\n"

	text += "[font_size=20][b]" + tr("Exercises that needed extra help") + "[/b][/font_size]\n"
	text += "[color=#64748b]" + tr("(%d or more wrong tries, or a hint was used - good topics to talk about together)") % HELP_TRIES + "[/color]\n"
	if tricky.is_empty():
		text += tr("Nothing yet - great going!") + "\n"
	else:
		tricky.sort_custom(func(a, b): return a["tries"] + a["hints"] * 2 > b["tries"] + b["hints"] * 2)
		for t in tricky:
			var notes := []
			if t["tries"] > 0:
				notes.append((tr("%d wrong try") if t["tries"] == 1 else tr("%d wrong tries")) % t["tries"])
			if t["hints"] > 0:
				notes.append(tr("used a hint"))
			text += ("-  " + tr("Level %d") + "  [b]%s[/b]   [color=#b45309]%s[/color]\n") % [t["level"] + 1, t["title"], ", ".join(PackedStringArray(notes))]
	body.text = text
	visible = true


func _heat(value: int, warm: int, hot: int) -> String:
	if value >= hot:
		return "#dc2626"
	if value >= warm:
		return "#d97706"
	return "#0f172a"


func _close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
