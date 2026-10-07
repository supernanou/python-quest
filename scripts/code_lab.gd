extends Control
## The Code Lab: write a whole Python program, press Run, see what it prints.
## Free play is always open; challenge N unlocks when level N is finished.

signal closed
signal wallet_changed

const MiniPython = preload("res://scripts/mini_python.gd")
const PythonText = preload("res://scripts/python_text.gd")
const Challenges = preload("res://scripts/lab_challenges.gd")
const Lang = preload("res://scripts/lang.gd")
const Speech = preload("res://scripts/speech.gd")

const FREE_PLAY_CODE := "# Free play! Write any Python you like, then press Run.\nname = input(\"What is your name? \")\nprint(\"Hello,\", name)\nfor i in range(3):\n    print(\"Python is fun!\")\n"
const FREE_PLAY_CODE_EL := "# Γράψε ό,τι θέλεις και πάτα Εκτέλεση!\nname = input(\"Πώς σε λένε; \")\nprint(\"Γεια σου,\", name)\nfor i in range(3):\n    print(\"Η Python είναι τέλεια!\")\n"

const ERROR_TIPS := {
	"NameError": "Python doesn't know that name. Check the spelling, and make sure you created the variable first.",
	"SyntaxError": "Python can't read this line. Look for a missing bracket, quote mark or colon.",
	"IndentationError": "Check the spaces at the start of the line. Code inside if/for/while/def must be moved right.",
	"TypeError": "You're mixing types that don't go together, like text + a number. Try str() or int().",
	"ValueError": "That value can't be turned into what you asked for - like int(\"hello\").",
	"IndexError": "That item number doesn't exist. Remember counting starts at 0!",
	"ZeroDivisionError": "You can't divide by zero!",
	"AttributeError": "That method doesn't exist for this kind of value. Check the spelling.",
	"TooLong": "Your program kept going and going. Does a loop ever stop?",
	"RecursionError": "A function keeps calling itself forever.",
}

var save
var current := -1  # -1 = free play
var drafts := {}  # what the child typed for each challenge, so switching doesn't lose it
var py: MiniPython
var running := false

var mono: SystemFont
var wallet_label: Label
var list_box: VBoxContainer
var task_label: Label
var editor: CodeEdit
var console: RichTextLabel
var input_row: HBoxContainer
var input_edit: LineEdit
var run_button: Button
var stop_button: Button
var read_button: Button


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])

	var bg := ColorRect.new()
	bg.color = Color("#0f172a")
	bg.size = size
	add_child(bg)

	var heading := HBoxContainer.new()
	heading.position = Vector2(20, 12)
	heading.add_theme_constant_override("separation", 18)
	add_child(heading)
	var title := _label("Code Lab", 30, Color("#facc15"))
	heading.add_child(title)
	var subtitle := _label("Write real Python and run it!", 16, Color("#94a3b8"))
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(subtitle)

	wallet_label = _label("", 22, Color("#38bdf8"))
	wallet_label.position = Vector2(620, 18)
	wallet_label.size = Vector2(180, 30)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(wallet_label)

	var back := _button("< Back", Color("#334155"))
	back.position = Vector2(820, 14)
	back.size = Vector2(120, 40)
	back.pressed.connect(_close)
	add_child(back)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 70)
	scroll.size = Vector2(222, 552)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	task_label = _label("", 17, Color("#e2e8f0"))
	task_label.position = Vector2(258, 66)
	task_label.size = Vector2(682, 80)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(task_label)

	editor = CodeEdit.new()
	editor.position = Vector2(258, 150)
	editor.size = Vector2(682, 250)
	editor.gutters_draw_line_numbers = true
	editor.indent_automatic = true
	editor.indent_use_spaces = true
	editor.indent_size = 4
	editor.auto_brace_completion_enabled = true
	editor.add_theme_font_override("font", mono)
	editor.add_theme_font_size_override("font_size", 18)
	editor.add_theme_color_override("background_color", Color("#020617"))
	editor.add_theme_color_override("font_color", Color("#e2e8f0"))
	editor.add_theme_color_override("line_number_color", Color("#475569"))
	editor.syntax_highlighter = _highlighter()
	add_child(editor)

	var buttons := HBoxContainer.new()
	buttons.position = Vector2(258, 408)
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	run_button = _button("Run  >", Color("#16a34a"))
	run_button.pressed.connect(_run)
	buttons.add_child(run_button)
	stop_button = _button("Stop", Color("#b91c1c"))
	stop_button.pressed.connect(func() -> void:
		if py != null:
			py.stop())
	stop_button.disabled = true
	buttons.add_child(stop_button)
	var reset := _button("Start over", Color("#334155"))
	reset.pressed.connect(_reset_code)
	buttons.add_child(reset)
	var hint := _button("Hint", Color("#0369a1"))
	hint.pressed.connect(_show_hint)
	buttons.add_child(hint)
	read_button = _button("Read aloud", Color("#7c3aed"))
	read_button.pressed.connect(func() -> void: Speech.say(task_label.text))
	buttons.add_child(read_button)

	var console_box := PanelContainer.new()
	console_box.position = Vector2(258, 458)
	console_box.size = Vector2(682, 164)
	console_box.add_theme_stylebox_override("panel", _box(Color("#000000"), Color("#1e293b"), 2, 8, 10))
	add_child(console_box)
	var console_v := VBoxContainer.new()
	console_box.add_child(console_v)
	console = RichTextLabel.new()
	console.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console.scroll_following = true
	console.selection_enabled = true
	console.add_theme_font_override("normal_font", mono)
	console.add_theme_font_size_override("normal_font_size", 16)
	console.add_theme_color_override("default_color", Color("#e2e8f0"))
	console_v.add_child(console)
	input_row = HBoxContainer.new()
	input_row.visible = false
	console_v.add_child(input_row)
	var arrow := _label("type here >", 15, Color("#22c55e"))
	input_row.add_child(arrow)
	input_edit = LineEdit.new()
	input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_edit.add_theme_font_override("font", mono)
	input_edit.text_submitted.connect(_on_input_submitted)
	input_row.add_child(input_edit)


func open(p_save) -> void:
	save = p_save
	_build_list()
	_select(current)
	visible = true


func _close() -> void:
	if py != null:
		py.stop()
	_store_draft()
	Speech.stop()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and (event.ctrl_pressed or event.meta_pressed):
		_run()
		get_viewport().set_input_as_handled()


func _build_list() -> void:
	for child in list_box.get_children():
		child.queue_free()
	wallet_label.text = "</>  %d" % save.icons
	var free_play := _button("Free play", Color("#7c3aed"))
	free_play.alignment = HORIZONTAL_ALIGNMENT_LEFT
	free_play.pressed.connect(_select.bind(-1))
	list_box.add_child(free_play)
	for i in Challenges.CHALLENGES.size():
		var c: Dictionary = Challenges.CHALLENGES[i]
		var done: bool = c["id"] in save.lab_done
		var unlocked: bool = save.is_done(i) or done
		var color := Color("#15803d") if done else (Color("#1e3a5f") if unlocked else Color("#1e293b"))
		var button := _button("%d. %s%s" % [i + 1, Lang.pick(c, "title"), "  - " + tr("done") if done else ""], color)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		if not unlocked:
			button.text = "%d. " % (i + 1) + tr("Finish Level %d") % (i + 1)
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", Color("#64748b"))
			button.add_theme_stylebox_override("disabled", _box(color, color, 2, 10, 8))
		button.pressed.connect(_select.bind(i))
		list_box.add_child(button)


func _select(index: int) -> void:
	_store_draft()
	current = index
	if current >= 0 and not (save.is_done(current) or Challenges.CHALLENGES[current]["id"] in save.lab_done):
		current = -1
	if current == -1:
		task_label.text = tr("Free play: write anything you like! Try changing this program, then press Run.")
		editor.text = drafts.get(-1, FREE_PLAY_CODE_EL if Lang.current() == "el" else FREE_PLAY_CODE)
	else:
		var c: Dictionary = Challenges.CHALLENGES[current]
		task_label.text = (tr("Challenge %d:") + " %s\n%s") % [current + 1, Lang.pick(c, "title"), Lang.pick(c, "task")]
		editor.text = drafts.get(current, Lang.pick(c, "starter"))
	editor.set_caret_line(editor.get_line_count() - 1)
	editor.set_caret_column(editor.get_line(editor.get_line_count() - 1).length())
	console.clear()
	_console(tr("Press Run (or Cmd/Ctrl + Enter) to start your program.") + "\n", Color("#64748b"))
	read_button.visible = Speech.available()
	Speech.stop()
	editor.call_deferred("grab_focus")


func _store_draft() -> void:
	if editor != null and editor.text != "":
		drafts[current] = editor.text


func _reset_code() -> void:
	drafts.erase(current)
	_select(current)


func _show_hint() -> void:
	if current == -1:
		_console("\n" + tr("Tip: print() shows things, input() asks a question, and Python runs top to bottom.") + "\n", Color("#93c5fd"))
	else:
		_console("\n" + tr("Hint:") + " %s\n" % Lang.pick(Challenges.CHALLENGES[current], "hint"), Color("#93c5fd"))


# ---------------------------------------------------------------- running

func _run() -> void:
	if running:
		return
	running = true
	run_button.disabled = true
	stop_button.disabled = false
	console.clear()
	py = MiniPython.new()
	py.tree = get_tree()
	py.printed.connect(func(text: String) -> void: console.add_text(text))
	py.input_requested.connect(_on_input_requested)
	var ok: bool = await py.run(editor.text)
	input_row.visible = false
	if not ok:
		_show_error(py)
	elif current >= 0:
		await _check_challenge()
	else:
		_console("\n- " + tr("program finished") + " -\n", Color("#64748b"))
	running = false
	run_button.disabled = false
	stop_button.disabled = true
	editor.grab_focus()


func _on_input_requested(_prompt: String) -> void:
	input_row.visible = true
	input_edit.text = ""
	input_edit.call_deferred("grab_focus")


func _on_input_submitted(text: String) -> void:
	input_row.visible = false
	if py != null:
		py.provide_input(text)


func _show_error(program: MiniPython) -> void:
	var kind: String = program.error.split(":")[0]
	if kind == "Stopped":
		_console("\n- " + tr("stopped") + " -\n", Color("#94a3b8"))
		return
	_console("\n" + tr("Line %d:") % program.error_line + "  %s\n" % program.error, Color("#f87171"))
	if ERROR_TIPS.has(kind):
		_console(tr("Tip:") + " %s\n" % tr(ERROR_TIPS[kind]), Color("#fbbf24"))
	if program.error_line > 0 and program.error_line <= editor.get_line_count():
		editor.set_caret_line(program.error_line - 1)


func _check_challenge() -> void:
	var c: Dictionary = Challenges.CHALLENGES[current]
	var code := editor.text
	for word in c.get("must_use", []):
		if not word in code:
			_console("\n" + tr("Almost! For this challenge your program must use:") + "  %s\n" % word, Color("#fb923c"))
			return
	var tests: Array = c.get("tests", [{"inputs": []}])
	for test in tests:
		var checker := MiniPython.new()
		checker.use_scripted = true
		checker.scripted_inputs = test["inputs"].duplicate()
		var ok: bool = await checker.run(code)
		if not ok:
			_console("\n" + tr("When I tested it, there was an error:") + "  %s\n" % checker.error, Color("#fb923c"))
			return
		var expected := _expected_output(c, test, checker)
		if expected == "":
			return
		var got := _tidy(checker.output)
		if got != expected:
			var when := "" if test["inputs"].is_empty() else " " + tr("(when someone types %s)") % ", ".join(PackedStringArray(test["inputs"]))
			_console("\n" + tr("Not quite yet") + "%s.\n" % when + tr("It should print:") + "\n", Color("#fb923c"))
			_console(expected + "\n", Color("#4ade80"))
			_console(tr("but it printed:") + "\n", Color("#fb923c"))
			_console((got if got != "" else tr("(nothing)")) + "\n", Color("#f87171"))
			return
	if c["id"] in save.lab_done:
		_console("\n" + tr("Challenge complete again - nice!") + "\n", Color("#4ade80"))
		return
	save.lab_done.append(c["id"])
	save.icons += Challenges.REWARD
	save.save_file()
	wallet_changed.emit()
	_console("\n" + tr("CHALLENGE COMPLETE!  +%d </> icons") % Challenges.REWARD + "\n", Color("#4ade80"))
	_build_list()


func _expected_output(c: Dictionary, test: Dictionary, checker: MiniPython) -> String:
	if test.has("output"):
		return test["output"]
	var check: Dictionary = c.get("check", {})
	var var_name: String = check.get("var", "")
	if not checker.globals.has(var_name):
		_console("\n" + tr("Almost! Make a variable called %s.") % var_name + "\n", Color("#fb923c"))
		return ""
	var value = checker.globals[var_name]
	if check.has("list_lines"):
		if not value is Array or value.size() != check["list_lines"]:
			_console("\n" + tr("Almost! %s should be a list with %d things in it.") % [var_name, check["list_lines"]] + "\n", Color("#fb923c"))
			return ""
		var lines := PackedStringArray()
		for item in value:
			lines.append(checker._str(item))
		return "\n".join(lines)
	if checker._str(value).strip_edges() == "":
		_console("\n" + tr("Almost! Put something inside %s.") % var_name + "\n", Color("#fb923c"))
		return ""
	return check["template"].replace("{value}", checker._str(value)).replace("{upper}", checker._str(value).to_upper())


## Ignore spaces at the end of lines and empty lines at the end.
func _tidy(text: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n"):
		lines.append(line.strip_edges(false, true))
	return "\n".join(lines).strip_edges(false, true)


func _console(text: String, color: Color) -> void:
	console.push_color(color)
	console.add_text(text)
	console.pop()


# ---------------------------------------------------------------- look

func _highlighter() -> CodeHighlighter:
	var hl := CodeHighlighter.new()
	hl.number_color = Color("#f472b6")
	hl.symbol_color = Color("#e2e8f0")
	hl.function_color = Color("#38bdf8")
	hl.member_variable_color = Color("#e2e8f0")
	for word in PythonText.KEYWORDS:
		hl.add_keyword_color(word, Color("#c084fc"))
	for word in PythonText.BUILTINS:
		hl.add_keyword_color(word, Color("#38bdf8"))
	hl.add_color_region("\"", "\"", Color("#fbbf24"))
	hl.add_color_region("'", "'", Color("#fbbf24"))
	hl.add_color_region("#", "", Color("#64748b"), true)
	return hl


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 40)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.25), 2, 10, 8))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), Color.WHITE, 2, 10, 8))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), Color.WHITE, 2, 10, 8))
	button.add_theme_stylebox_override("disabled", _box(color.darkened(0.3), color.darkened(0.3), 2, 10, 8))
	return button


func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
