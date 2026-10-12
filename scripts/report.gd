extends RichTextLabel
## Progress report for parents and teachers (shown in the grown-ups area):
## how each level went, and which exercises needed extra help.

const Challenges = preload("res://scripts/lab_challenges.gd")
const Courses = preload("res://scripts/courses.gd")
const Lang = preload("res://scripts/lang.gd")
const HELP_TRIES := 3  # this many wrong tries counts as "needed extra help"


func _ready() -> void:
	bbcode_enabled = true
	add_theme_color_override("default_color", Color("#0f172a"))
	add_theme_font_size_override("normal_font_size", 15)
	add_theme_font_size_override("bold_font_size", 15)
	add_theme_constant_override("table_h_separation", 18)
	add_theme_constant_override("table_v_separation", 5)


func show_for(levels: Array, save) -> void:
	var name: String = save.look.get("name", "")
	var solved_total := 0
	for i in levels.size():
		solved_total += save.solved_in_level(i)
	var text := "[font_size=24][b]" + tr("Progress report: %s") % (name if name != "" else tr("Player")) + "[/b][/font_size]\n"
	text += ("[color=#475569]" + tr("Exercises solved:") + " [b]%d / %d[/b]     " + tr("Quizzes passed:") + " [b]%d / %d[/b]     " + tr("Code Lab challenges:") + " [b]%d / %d[/b]     </> " + tr("icons:") + " [b]%d[/b][/color]\n") % [
		solved_total, levels.size() * 10, save.quiz_scores.size(), levels.size(),
		save.lab_done.size(), Challenges.CHALLENGES.size(), save.icons]

	var tricky := []
	for course_index in Courses.COURSES.size():
		var span := Courses.course_range(course_index)
		text += "\n[font_size=19][b]%s[/b][/font_size]\n" % tr(Courses.COURSES[course_index]["name"])
		text += "[table=5]"
		for heading in ["Level", "Exercises", "Wrong tries", "Hints used", "Quiz (best / tries)"]:
			text += "[cell][b]%s[/b][/cell]" % tr(heading)
		for i in range(span[0], span[1] + 1):
			if i >= levels.size():
				break
			var level: Dictionary = levels[i]
			var tries := 0
			var hints := 0
			for exercise in level["exercises"]:
				var s: Dictionary = save.stats.get(exercise["id"], {})
				tries += s.get("tries", 0)
				hints += s.get("hints", 0)
				if s.get("solved", false) and (s.get("tries", 0) >= HELP_TRIES or s.get("hints", 0) > 0):
					tricky.append({"course": course_index, "number": level["number"], "title": Lang.pick(exercise, "title"), "tries": s.get("tries", 0), "hints": s.get("hints", 0)})
			var locked: bool = i >= save.unlocked
			var quiz := "-"
			if save.is_done(i):
				quiz = "%d/5  (%d)" % [save.quiz_scores[i], save.quiz_attempts.get(i, 1)]
			elif save.quiz_attempts.get(i, 0) > 0:
				quiz = tr("not passed yet") + "  (%d)" % save.quiz_attempts[i]
			var color := "#94a3b8" if locked else "#0f172a"
			text += "[cell][color=%s]%d. %s[/color][/cell]" % [color, level["number"], Lang.pick(level, "name")]
			text += "[cell][color=%s]%s[/color][/cell]" % [color, tr("locked") if locked else "%d / 10" % save.solved_in_level(i)]
			text += "[cell][color=%s]%s[/color][/cell]" % [_heat(tries, 10, 20), str(tries) if not locked else ""]
			text += "[cell][color=%s]%s[/color][/cell]" % [_heat(hints, 2, 5), str(hints) if not locked else ""]
			text += "[cell][color=%s]%s[/color][/cell]" % [color, quiz]
		text += "[/table]\n"

	text += "\n[font_size=19][b]" + tr("Exercises that needed extra help") + "[/b][/font_size]\n"
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
			text += ("-  %s - " + tr("Level %d") + "  [b]%s[/b]   [color=#b45309]%s[/color]\n") % [
				tr(Courses.COURSES[t["course"]]["short"]), t["number"], t["title"], ", ".join(PackedStringArray(notes))]
	self.text = text


func _heat(value: int, warm: int, hot: int) -> String:
	if value >= hot:
		return "#dc2626"
	if value >= warm:
		return "#d97706"
	return "#0f172a"
