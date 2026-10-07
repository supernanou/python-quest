extends Control
## The end-of-level quiz: 5 questions (click-an-answer or typed). 4 right to pass.
## If the child fails, they see what they missed and can try again.

signal passed(score: int)
signal finished(score: int)
signal next_level
signal to_map
signal cancelled

const CodeText = preload("res://scripts/code_text.gd")
const Lang = preload("res://scripts/lang.gd")
const Speech = preload("res://scripts/speech.gd")
const QUESTIONS_PER_QUIZ := 5
const PASS_MARK := 4

var reward_text := ""  # filled in by main when the quiz is passed
var level_number := 1
var pool: Array = []
var questions: Array = []
var current := 0
var score := 0
var missed: Array = []
var answered := false
var correct_option := ""

var mono: SystemFont
var quiz_view: VBoxContainer
var result_view: VBoxContainer
var header_label: Label
var dots: HBoxContainer
var question_label: Label
var code_box: PanelContainer
var code_label: RichTextLabel
var options_grid: GridContainer
var answer_row: HBoxContainer
var answer_edit: LineEdit
var feedback_label: Label
var next_button: Button
var read_button: Button
var result_title: Label
var result_body: RichTextLabel
var retry_button: Button
var next_level_button: Button


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.12, 0.96)
	bg.size = size
	add_child(bg)

	var center := CenterContainer.new()
	center.size = size
	add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(800, 0)
	box.add_theme_stylebox_override("panel", _style(Color("#0f172a"), Color("#facc15"), 3, 14, 22))
	center.add_child(box)
	var holder := VBoxContainer.new()
	box.add_child(holder)

	# ---- question view
	quiz_view = VBoxContainer.new()
	quiz_view.add_theme_constant_override("separation", 12)
	holder.add_child(quiz_view)

	var top := HBoxContainer.new()
	quiz_view.add_child(top)
	header_label = _label(26, Color("#facc15"))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header_label)
	dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	top.add_child(dots)

	question_label = _label(21, Color.WHITE)
	quiz_view.add_child(question_label)

	code_box = PanelContainer.new()
	code_box.add_theme_stylebox_override("panel", _style(Color("#020617"), Color("#1e293b"), 2, 8, 14))
	quiz_view.add_child(code_box)
	code_label = RichTextLabel.new()
	code_label.bbcode_enabled = true
	code_label.fit_content = true
	code_label.scroll_active = false
	code_label.add_theme_font_override("normal_font", mono)
	code_label.add_theme_font_size_override("normal_font_size", 19)
	code_box.add_child(code_label)

	options_grid = GridContainer.new()
	options_grid.columns = 2
	options_grid.add_theme_constant_override("h_separation", 10)
	options_grid.add_theme_constant_override("v_separation", 10)
	quiz_view.add_child(options_grid)

	answer_row = HBoxContainer.new()
	quiz_view.add_child(answer_row)
	var prompt := Label.new()
	prompt.text = ">>>"
	prompt.add_theme_font_override("font", mono)
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color("#22c55e"))
	answer_row.add_child(prompt)
	answer_edit = LineEdit.new()
	answer_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer_edit.add_theme_font_override("font", mono)
	answer_edit.add_theme_font_size_override("font_size", 20)
	answer_edit.text_submitted.connect(func(_t: String) -> void: _on_submit())
	answer_row.add_child(answer_edit)
	answer_row.add_child(_button("Check", _on_submit, Color("#0369a1")))

	feedback_label = _label(18, Color.WHITE)
	quiz_view.add_child(feedback_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	quiz_view.add_child(bottom)
	read_button = _button("Read aloud", _read_aloud, Color("#0369a1"))
	bottom.add_child(read_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	bottom.add_child(_button("Back to level (Esc)", func() -> void: _cancel(), Color("#334155")))
	next_button = _button("Next question  >", _on_next, Color("#16a34a"))
	bottom.add_child(next_button)

	# ---- result view
	result_view = VBoxContainer.new()
	result_view.add_theme_constant_override("separation", 14)
	holder.add_child(result_view)
	result_title = _label(36, Color("#facc15"))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_view.add_child(result_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_view.add_child(scroll)
	result_body = RichTextLabel.new()
	result_body.bbcode_enabled = true
	result_body.fit_content = true
	result_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_body.add_theme_font_size_override("normal_font_size", 19)
	result_body.add_theme_font_override("mono_font", mono)
	result_body.add_theme_font_size_override("mono_font_size", 18)
	scroll.add_child(result_body)
	var result_buttons := HBoxContainer.new()
	result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	result_buttons.add_theme_constant_override("separation", 12)
	result_view.add_child(result_buttons)
	result_buttons.add_child(_button("Level map", func() -> void: to_map.emit(), Color("#334155")))
	retry_button = _button("Try again  >", _new_attempt, Color("#7c3aed"))
	result_buttons.add_child(retry_button)
	next_level_button = _button("Next level  >", func() -> void: next_level.emit(), Color("#16a34a"))
	result_buttons.add_child(next_level_button)


func start(p_level_number: int, p_pool: Array, is_last_level: bool) -> void:
	level_number = p_level_number
	pool = p_pool
	next_level_button.text = "Finish course  >" if is_last_level else "Next level  >"
	visible = true
	_new_attempt()


func _new_attempt() -> void:
	questions = pool.duplicate()
	questions.shuffle()
	questions = questions.slice(0, QUESTIONS_PER_QUIZ)
	current = 0
	score = 0
	missed = []
	quiz_view.visible = true
	result_view.visible = false
	_show_question()


func _show_question() -> void:
	var q: Dictionary = questions[current]
	answered = false
	header_label.text = tr("Level %d Quiz   -   Question %d of %d") % [level_number, current + 1, questions.size()]
	_update_dots()
	question_label.text = Lang.pick(q, "question")
	var code: String = q.get("code", "")
	code_box.visible = code != ""
	code_label.text = CodeText.highlight(code)
	_feedback("", Color.WHITE)
	next_button.visible = false
	Speech.stop()
	read_button.visible = Speech.available()
	for child in options_grid.get_children():
		child.queue_free()

	if q["type"] == "choice":
		answer_row.visible = false
		options_grid.visible = true
		var options: Array = Lang.pick(q, "options").duplicate()
		correct_option = options[q["answer"]]
		options.shuffle()
		for option in options:
			var button := _button(option, Callable(), Color("#1e293b"))
			button.custom_minimum_size = Vector2(368, 52)
			button.add_theme_font_override("font", mono)
			button.pressed.connect(_on_choice.bind(button, option))
			options_grid.add_child(button)
	else:
		options_grid.visible = false
		answer_row.visible = true
		answer_edit.text = ""
		answer_edit.editable = true
		answer_edit.placeholder_text = "Type what will be printed..." if q["type"] == "output" else "Type your code..."
		answer_edit.call_deferred("grab_focus")


func _update_dots() -> void:
	for child in dots.get_children():
		child.queue_free()
	for i in questions.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = Color("#facc15") if i == current else (Color("#64748b") if i > current else Color("#e2e8f0"))
		dots.add_child(dot)


func _on_choice(button: Button, option: String) -> void:
	if answered:
		return
	for other in options_grid.get_children():
		if other is Button and other.text == correct_option:
			other.add_theme_stylebox_override("normal", _style(Color("#15803d"), Color.WHITE, 2, 10, 8))
			other.add_theme_stylebox_override("disabled", _style(Color("#15803d"), Color.WHITE, 2, 10, 8))
		elif other == button:
			other.add_theme_stylebox_override("normal", _style(Color("#b91c1c"), Color.WHITE, 2, 10, 8))
			other.add_theme_stylebox_override("disabled", _style(Color("#b91c1c"), Color.WHITE, 2, 10, 8))
		other.disabled = true
	_after_answer(option == correct_option, correct_option)


func _on_submit() -> void:
	if answered:
		_on_next()
		return
	var q: Dictionary = questions[current]
	if answer_edit.text.strip_edges() == "":
		_feedback("Type an answer first!", Color("#fbbf24"))
		return
	var ok := CodeText.matches(answer_edit.text, Lang.answers(q), q["type"], q.get("case_sensitive", false))
	answer_edit.editable = false
	_after_answer(ok, q["answers"][0])


func _after_answer(ok: bool, right_answer: String) -> void:
	answered = true
	var q: Dictionary = questions[current]
	var explain: String = str(Lang.pick(q, "explain")) if q.has("explain") else ""
	if ok:
		score += 1
		_feedback(tr("Correct!") + "  " + explain, Color("#4ade80"))
	else:
		missed.append({"question": Lang.pick(q, "question"), "code": q.get("code", ""), "right": right_answer, "explain": explain})
		_feedback(tr("Not quite. The answer is:") + "  %s\n%s" % [right_answer, explain], Color("#fb923c"))
	next_button.text = tr("Next question  >") if current + 1 < questions.size() else tr("See my score  >")
	next_button.visible = true
	next_button.grab_focus()


func _on_next() -> void:
	current += 1
	if current < questions.size():
		_show_question()
	else:
		_show_result()


func _show_result() -> void:
	quiz_view.visible = false
	result_view.visible = true
	var total := questions.size()
	finished.emit(score)
	if score >= PASS_MARK:
		reward_text = ""
		passed.emit(score)
		result_title.text = tr("You passed!") + "  %d / %d" % [score, total]
		result_title.add_theme_color_override("font_color", Color("#4ade80"))
		var body := "[center]" + tr("Level %d complete - amazing work!") % level_number
		if reward_text != "":
			body += "\n\n[color=#38bdf8]%s[/color]" % reward_text
		result_body.text = body + "[/center]" + _missed_text()
		retry_button.visible = false
		next_level_button.visible = true
		next_level_button.grab_focus()
	else:
		result_title.text = "%s  %d / %d" % [tr("So close!") if score == PASS_MARK - 1 else tr("Keep practising!"), score, total]
		result_title.add_theme_color_override("font_color", Color("#fb923c"))
		result_body.text = "[center]" + tr("You need %d right to pass. Let's look at the ones you missed, then try again!") % PASS_MARK + "[/center]" + _missed_text()
		retry_button.visible = true
		next_level_button.visible = false
		retry_button.grab_focus()


func _missed_text() -> String:
	if missed.is_empty():
		return ""
	var text := "\n"
	for m in missed:
		text += "\n[color=#e2e8f0]%s[/color]" % CodeText.escape(m["question"])
		if m["code"] != "":
			text += "\n[code]%s[/code]" % CodeText.escape(m["code"])
		text += "\n[color=#4ade80]" + tr("Answer:") + " %s[/color]  [color=#94a3b8]%s[/color]\n" % [CodeText.escape(m["right"]), CodeText.escape(m["explain"])]
	return text


## Reads the question, the answer choices and any feedback.
func _read_aloud() -> void:
	var parts := [question_label.text]
	if options_grid.visible:
		for b in options_grid.get_children():
			if not b.is_queued_for_deletion():
				parts.append(b.text)
	if feedback_label.text != "":
		parts.append(feedback_label.text)
	Speech.say(". ".join(PackedStringArray(parts)))


func _cancel() -> void:
	Speech.stop()
	visible = false
	cancelled.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if quiz_view.visible:
		_cancel()
	else:
		to_map.emit()


func _feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _style(color, color.lightened(0.25), 2, 10, 8))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12), Color.WHITE, 2, 10, 8))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), Color.WHITE, 2, 10, 8))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("#facc15"), 2, 10, 8))
	button.add_theme_color_override("font_disabled_color", Color.WHITE)
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _style(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
