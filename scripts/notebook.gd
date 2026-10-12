extends Control
## "My Code Notebook": a note card for every exercise the player has solved,
## so they can look back at what they learned.

signal closed

const CodeText = preload("res://scripts/code_text.gd")
const Lang = preload("res://scripts/lang.gd")
const Courses = preload("res://scripts/courses.gd")

var levels: Array = []
var save
var mono: SystemFont
var level_buttons: Array = []
var course_tabs: Array = []
var course := 0
var page_title: Label
var cards_box: VBoxContainer
var scroll: ScrollContainer


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = size
	add_child(dim)

	var book := Panel.new()
	book.position = Vector2(24, 20)
	book.size = Vector2(912, 600)
	book.add_theme_stylebox_override("panel", _box(Color("#fef9c3"), Color("#a16207"), 4, 16, 0))
	add_child(book)

	var title := _label("My Code Notebook", 21, Color("#713f12"))
	title.position = Vector2(44, 34)
	add_child(title)

	# Course tabs, then one button per level of that course
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(44, 78)
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	for c in Courses.COURSES.size():
		var tab := Button.new()
		tab.text = Courses.COURSES[c]["short"]
		tab.custom_minimum_size = Vector2(112, 34)
		tab.add_theme_font_size_override("font_size", 14)
		tab.pressed.connect(func() -> void: _show_course(c, -1))
		tabs.add_child(tab)
		course_tabs.append(tab)

	var levels_box := VBoxContainer.new()
	levels_box.position = Vector2(44, 120)
	levels_box.size = Vector2(230, 480)
	levels_box.add_theme_constant_override("separation", 5)
	add_child(levels_box)
	for i in 10:
		var button := Button.new()
		button.custom_minimum_size = Vector2(230, 41)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(func() -> void: _show_page(Courses.course_range(course)[0] + i))
		levels_box.add_child(button)
		level_buttons.append(button)

	page_title = _label("", 22, Color("#713f12"))
	page_title.position = Vector2(296, 36)
	page_title.size = Vector2(500, 32)
	add_child(page_title)

	var close := Button.new()
	close.text = "Close (Esc)"
	close.position = Vector2(784, 32)
	close.size = Vector2(130, 40)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(_close)
	add_child(close)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(296, 84)
	scroll.size = Vector2(618, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	cards_box = VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation", 12)
	scroll.add_child(cards_box)


func open(p_levels: Array, p_save, level_index := -1) -> void:
	levels = p_levels
	save = p_save
	# Start on the level being played, or the newest level with notes
	var start := level_index
	if start < 0 or save.solved_in_level(start) == 0:
		start = -1
		for i in levels.size():
			if save.solved_in_level(i) > 0:
				start = i
	var start_course: int = levels[maxi(start, 0)]["course"]
	_show_course(start_course, start)
	visible = true


func _show_course(c: int, level_index: int) -> void:
	course = c
	var span := Courses.course_range(course)
	for t in course_tabs.size():
		var on: bool = t == course
		var tab: Button = course_tabs[t]
		tab.add_theme_stylebox_override("normal", _box(Color("#fbbf24") if on else Color("#fef3c7"), Color("#a16207"), 2, 8, 6))
		tab.add_theme_color_override("font_color", Color("#713f12"))
	var page := -1
	for n in level_buttons.size():
		var i: int = span[0] + n
		var button: Button = level_buttons[n]
		var has_notes: bool = i < levels.size() and save.solved_in_level(i) > 0
		button.text = "%d. %s" % [n + 1, Lang.pick(levels[i], "name")] if i < levels.size() else ""
		button.disabled = not has_notes
		button.visible = i < levels.size()
		var bg := Color("#fde68a") if has_notes else Color("#f5f5f4")
		button.add_theme_stylebox_override("normal", _box(bg, Color("#a16207"), 2, 8, 8))
		button.add_theme_stylebox_override("hover", _box(bg.lightened(0.2), Color("#713f12"), 2, 8, 8))
		button.add_theme_stylebox_override("pressed", _box(Color("#fbbf24"), Color("#713f12"), 3, 8, 8))
		button.add_theme_stylebox_override("disabled", _box(bg, Color("#d6d3d1"), 2, 8, 8))
		button.add_theme_color_override("font_color", Color("#713f12"))
		button.add_theme_color_override("font_hover_color", Color("#713f12"))
		button.add_theme_color_override("font_pressed_color", Color("#713f12"))
		button.add_theme_color_override("font_disabled_color", Color("#a8a29e"))
		if has_notes:
			page = i
	if level_index >= span[0] and level_index <= span[1] and save.solved_in_level(level_index) > 0:
		page = level_index
	_show_page(page if page >= 0 else span[0])


func _show_page(i: int) -> void:
	for child in cards_box.get_children():
		child.queue_free()
	page_title.text = tr("Level %d: %s") % [levels[i]["number"], Lang.pick(levels[i], "name")]
	var count := 0
	for exercise in levels[i]["exercises"]:
		if save.is_solved(exercise["id"]):
			cards_box.add_child(_card(exercise))
			count += 1
	if count == 0:
		var empty := _label("Solve exercises in this level and your notes will appear here!", 18, Color("#78716c"))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cards_box.add_child(empty)
	scroll.scroll_vertical = 0


func _card(exercise: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color.WHITE, Color("#e7e5e4"), 2, 10, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var title := _label(Lang.pick(exercise, "title"), 19, Color("#b45309"))
	v.add_child(title)
	var lesson := _label(Lang.pick(exercise, "lesson"), 16, Color("#292524"))
	lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lesson)
	var code_box := PanelContainer.new()
	code_box.add_theme_stylebox_override("panel", _box(Color("#0f172a"), Color("#0f172a"), 0, 8, 10))
	v.add_child(code_box)
	var code := RichTextLabel.new()
	code.bbcode_enabled = true
	code.fit_content = true
	code.scroll_active = false
	code.add_theme_font_override("normal_font", mono)
	code.add_theme_font_size_override("normal_font_size", 16)
	code.text = CodeText.highlight(exercise["code"])
	code_box.add_child(code)
	if exercise.has("error"):
		var error := _label(tr("Error!") + "  " + exercise["error"], 14, Color("#b91c1c"))
		error.add_theme_font_override("font", mono)
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(error)
	return card


func _close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("notebook")):
		_close()
		get_viewport().set_input_as_handled()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
