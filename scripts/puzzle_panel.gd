extends Control
## The pop-up window where a child reads code and types an answer.
## Each computer has a short list of exercises, shown one after another.

signal exercise_solved(letter: String, index: int)
signal wallet_changed
signal notebook_requested
signal closed

const CodeText = preload("res://scripts/code_text.gd")
const Lang = preload("res://scripts/lang.gd")
const Speech = preload("res://scripts/speech.gd")
const HINT_PRICE := 1
const ENCOURAGEMENT := [
	"Not quite - try again!",
	"Almost! Have another go.",
	"Every programmer gets bugs. Try again!",
	"Keep going, you can do it!",
]

var save  # SaveData, for paying for hints
var hero_name := "Hero"
var letter := ""
var exercises: Array = []
var index := 0
var puzzle: Dictionary = {}
var tries := 0
var solved_now := false
var hint_unlocked := false
var hint_recorded := false

var mono: SystemFont
var step_label: Label
var title_label: Label
var lesson_label: Label
var code_label: RichTextLabel
var error_box: PanelContainer
var error_label: Label
var question_label: Label
var answer_edit: LineEdit
var feedback_label: Label
var hint_button: Button
var run_button: Button
var read_button: Button


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = size
	add_child(dim)

	var center := CenterContainer.new()
	center.size = size
	add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(800, 0)
	box.add_theme_stylebox_override("panel", _style(Color("#0f172a"), Color("#38bdf8"), 3, 14, 22))
	center.add_child(box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)

	step_label = _label(15, Color("#94a3b8"))
	v.add_child(step_label)

	title_label = _label(28, Color("#facc15"))
	v.add_child(title_label)

	lesson_label = _label(18, Color("#e2e8f0"))
	v.add_child(lesson_label)

	var code_box := PanelContainer.new()
	code_box.add_theme_stylebox_override("panel", _style(Color("#020617"), Color("#1e293b"), 2, 8, 14))
	v.add_child(code_box)
	code_label = RichTextLabel.new()
	code_label.bbcode_enabled = true
	code_label.fit_content = true
	code_label.scroll_active = false
	code_label.add_theme_font_override("normal_font", mono)
	code_label.add_theme_font_size_override("normal_font_size", 20)
	code_box.add_child(code_label)

	# Some exercises show the error the computer gives, so kids learn to read them
	error_box = PanelContainer.new()
	error_box.add_theme_stylebox_override("panel", _style(Color("#2a0a0a"), Color("#ef4444"), 2, 8, 10))
	v.add_child(error_box)
	error_label = _label(16, Color("#fca5a5"))
	error_label.add_theme_font_override("font", mono)
	error_box.add_child(error_label)

	question_label = _label(20, Color.WHITE)
	v.add_child(question_label)

	var row := HBoxContainer.new()
	v.add_child(row)
	var prompt := Label.new()
	prompt.text = ">>>"
	prompt.add_theme_font_override("font", mono)
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color("#22c55e"))
	row.add_child(prompt)
	answer_edit = LineEdit.new()
	answer_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer_edit.add_theme_font_override("font", mono)
	answer_edit.add_theme_font_size_override("font_size", 20)
	answer_edit.text_submitted.connect(func(_text: String) -> void: _on_run())
	row.add_child(answer_edit)

	feedback_label = _label(18, Color.WHITE)
	v.add_child(feedback_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	read_button = _button("Read aloud", _read_aloud)
	buttons.add_child(read_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	buttons.add_child(_button("Notes", func() -> void: notebook_requested.emit()))
	hint_button = _button("Hint", _on_hint)
	buttons.add_child(hint_button)
	buttons.add_child(_button("Close (Esc)", close))
	run_button = _button("Run  >", _on_run)
	buttons.add_child(run_button)


## Opens a computer. Starts at the first exercise that isn't solved yet.
func open(p_letter: String, p_exercises: Array, solved_count: int) -> void:
	letter = p_letter
	exercises = p_exercises
	var practice := solved_count >= exercises.size()
	_show_exercise(0 if practice else solved_count)
	if practice:
		_feedback("You already solved this computer - practise again!", Color("#94a3b8"))
		hint_recorded = true
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	Speech.stop()
	closed.emit()


func _show_exercise(i: int) -> void:
	index = i
	puzzle = exercises[i]
	tries = 0
	solved_now = false
	hint_unlocked = false
	hint_recorded = false
	step_label.text = tr("Computer %s   -   Exercise %d of %d") % [letter.to_upper(), i + 1, exercises.size()]
	title_label.text = Lang.pick(puzzle, "title")
	lesson_label.text = Lang.pick(puzzle, "lesson")
	code_label.text = CodeText.highlight(puzzle["code"])
	error_box.visible = puzzle.has("error")
	error_label.text = tr("Error!") + "  " + puzzle.get("error", "")
	question_label.text = Lang.pick(puzzle, "question")
	answer_edit.text = ""
	answer_edit.editable = true
	if puzzle["mode"] == "output":
		answer_edit.placeholder_text = "Type what will be printed..."
	else:
		answer_edit.placeholder_text = "Type your code..."
	_feedback("", Color.WHITE)
	run_button.text = "Run  >"
	_update_hint_button()
	Speech.stop()
	read_button.visible = Speech.available()
	answer_edit.call_deferred("grab_focus")


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_run() -> void:
	if solved_now:
		if index + 1 < exercises.size():
			_show_exercise(index + 1)
		else:
			close()
		return
	var answer := answer_edit.text
	if answer.strip_edges() == "":
		_feedback("Type an answer first!", Color("#fbbf24"))
		return
	if CodeText.matches(answer, Lang.answers(puzzle), puzzle["mode"], puzzle.get("case_sensitive", false)):
		solved_now = true
		answer_edit.editable = false
		var more := index + 1 < exercises.size()
		run_button.text = "Next exercise  >" if more else "Continue  >"
		run_button.grab_focus()
		if more:
			_feedback(tr("Correct, %s! One more to open the door.") % hero_name, Color("#4ade80"))
		else:
			_feedback(tr("Correct, %s! You're a coding wizard! The door is open.") % hero_name, Color("#4ade80"))
		if save != null:
			save.record_solved(puzzle.get("id", ""))
		exercise_solved.emit(letter, index)
		return
	tries += 1
	if save != null:
		save.record_try(puzzle.get("id", ""))
	var message: String = tr(ENCOURAGEMENT[randi() % ENCOURAGEMENT.size()])
	var tip := _mistake_tip(answer)
	if tip != "":
		message = tip
	elif tries >= 2:
		message += "\n" + tr("Free hint:") + " " + str(Lang.pick(puzzle, "hint"))
		_note_hint_used()
	_update_hint_button()
	_feedback(message, Color("#fb923c"))


## Hints cost 1 </> icon. After 2 wrong tries the hint is free.
func _on_hint() -> void:
	if not (hint_unlocked or tries >= 2):
		if save == null or save.icons < HINT_PRICE:
			_feedback("You need a </> icon to buy a hint - find them on the map!\n(After 2 tries you get a free hint.)", Color("#fbbf24"))
			return
		save.icons -= HINT_PRICE
		save.save_file()
		hint_unlocked = true
		wallet_changed.emit()
	_update_hint_button()
	_note_hint_used()
	_feedback(tr("Hint:") + " " + str(Lang.pick(puzzle, "hint")), Color("#93c5fd"))
	answer_edit.grab_focus()


## Reads the title, lesson, question and any feedback (not the code).
func _read_aloud() -> void:
	var parts := [title_label.text, lesson_label.text, question_label.text, feedback_label.text]
	Speech.say(". ".join(PackedStringArray(parts.filter(func(p): return p != ""))))
	answer_edit.grab_focus()


func _note_hint_used() -> void:
	if not hint_recorded and save != null:
		hint_recorded = true
		save.record_hint(puzzle.get("id", ""))


func _update_hint_button() -> void:
	hint_button.text = "Hint" if (hint_unlocked or tries >= 2) else "Hint (1 </>)"


func _mistake_tip(answer: String) -> String:
	var mode: String = puzzle["mode"]
	var case_sensitive: bool = puzzle.get("case_sensitive", false)
	var given := CodeText.normalize(answer, mode, case_sensitive)
	var mistakes: Dictionary = Lang.mistakes(puzzle)
	for wrong in mistakes:
		if given == CodeText.normalize(wrong, mode, case_sensitive):
			return tr(mistakes[wrong])
	if mode == "output" and answer.strip_edges().length() > 2:
		var unquoted := answer.strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
		if CodeText.matches(unquoted, Lang.answers(puzzle), mode, case_sensitive):
			return "So close! print() shows the words WITHOUT the quote marks."
	if (mode == "code" or case_sensitive) and CodeText.matches_ignoring_case(answer, Lang.answers(puzzle), mode):
		return "So close! Check your capital letters - computers are picky about them."
	return ""


func _feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 40)
	button.add_theme_font_size_override("font_size", 18)
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
