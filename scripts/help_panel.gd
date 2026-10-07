extends Control
## "How to play": every key and what it does. Opened from the title screen.

signal closed

const Speech = preload("res://scripts/speech.gd")

var read_button: Button

const ROWS := [
	["Arrows / WASD", "Walk your hero"],
	["E", "Use a computer and solve its Python puzzles"],
	["Enter", "Check your answer"],
	["</>", "Collect code icons - use them for hints and hero extras"],
	["EXIT", "Finish the level and take the quiz (4 out of 5 to pass)"],
	["N", "Open your notebook with everything you learned"],
	["M", "Go to the level map"],
	["F", "Full screen"],
	["Esc", "Close a window"],
]


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = size
	add_child(dim)

	var center := CenterContainer.new()
	center.size = size
	add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(820, 0)
	box.add_theme_stylebox_override("panel", _box(Color("#0f172a"), Color("#ffd43b"), 3, 16, 20))
	center.add_child(box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)

	var title := _label("How to play", 26, Color("#ffd43b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var intro := _label("Walk through the levels, solve Python puzzles on the computers and open the doors!", 15, Color("#cbd5e1"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(intro)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for row in ROWS:
		var key := PanelContainer.new()
		key.custom_minimum_size = Vector2(150, 0)
		key.add_theme_stylebox_override("panel", _box(Color("#1e293b"), Color("#475569"), 2, 8, 4))
		var key_label := _label(row[0], 15, Color.WHITE)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_child(key_label)
		grid.add_child(key)
		var text := _label(row[1], 15, Color("#e2e8f0"))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	read_button = Button.new()
	read_button.text = "Read aloud"
	read_button.custom_minimum_size = Vector2(160, 40)
	read_button.add_theme_font_size_override("font_size", 18)
	read_button.add_theme_stylebox_override("normal", _box(Color("#0369a1"), Color("#38bdf8"), 2, 22, 8))
	read_button.add_theme_stylebox_override("hover", _box(Color("#0284c7"), Color.WHITE, 2, 22, 8))
	read_button.add_theme_stylebox_override("pressed", _box(Color("#075985"), Color.WHITE, 2, 22, 8))
	read_button.pressed.connect(_read_aloud)
	row.add_child(read_button)

	var ok := Button.new()
	ok.text = "Got it!"
	ok.custom_minimum_size = Vector2(160, 40)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		ok.add_theme_color_override(state, Color("#0f172a"))
	ok.add_theme_stylebox_override("normal", _box(Color("#ffd43b"), Color("#ffd43b"), 0, 22, 8))
	ok.add_theme_stylebox_override("hover", _box(Color("#ffe066"), Color("#ffe066"), 0, 22, 8))
	ok.add_theme_stylebox_override("pressed", _box(Color("#f5c518"), Color("#f5c518"), 0, 22, 8))
	ok.pressed.connect(close)
	row.add_child(ok)


func open() -> void:
	read_button.visible = Speech.available()
	visible = true


func _read_aloud() -> void:
	var parts := [tr("How to play"), tr("Walk through the levels, solve Python puzzles on the computers and open the doors!")]
	for row in ROWS:
		parts.append("%s: %s" % [tr(row[0]), tr(row[1])])
	Speech.say(". ".join(PackedStringArray(parts)))


func close() -> void:
	Speech.stop()
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		close()
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
