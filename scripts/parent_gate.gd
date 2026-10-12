extends Control
## "Grown-ups only": asks for the 4-digit grown-up PIN before removing a player or
## opening the grown-ups area. The first time, it asks a grown-up to create the PIN.
## "Forgot PIN?" asks a multiplication that's easy with a calculator, hard for little kids.

const Settings = preload("res://scripts/settings.gd")

var mode := ""  # "create", "confirm", "enter" or "forgot"
var first_pin := ""
var on_ok: Callable
var factor_a := 0
var factor_b := 0

var message_label: Label
var info_label: Label
var pin_edit: LineEdit
var feedback_label: Label
var forgot_button: Button


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = size
	add_child(dim)

	var center := CenterContainer.new()
	center.size = size
	add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_stylebox_override("panel", _box(Color("#0f172a"), Color("#facc15"), 3, 16, 24))
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)

	v.add_child(_label("Grown-ups only", 28, Color("#facc15")))
	message_label = _label("", 18, Color.WHITE)
	v.add_child(message_label)
	info_label = _label("", 16, Color("#94a3b8"))
	v.add_child(info_label)

	pin_edit = LineEdit.new()
	pin_edit.custom_minimum_size = Vector2(220, 56)
	pin_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pin_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_edit.add_theme_font_size_override("font_size", 32)
	pin_edit.text_changed.connect(_digits_only)
	pin_edit.text_submitted.connect(func(_t: String) -> void: _on_ok())
	v.add_child(pin_edit)

	feedback_label = _label("", 16, Color("#f87171"))
	v.add_child(feedback_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	buttons.add_child(_button("Cancel", Color("#334155"), close))
	buttons.add_child(_button("OK", Color("#16a34a"), _on_ok))

	forgot_button = Button.new()
	forgot_button.text = "Forgot PIN?"
	forgot_button.flat = true
	forgot_button.add_theme_color_override("font_color", Color("#64748b"))
	forgot_button.add_theme_font_size_override("font_size", 14)
	forgot_button.pressed.connect(_start_forgot)
	v.add_child(forgot_button)


## Shows the gate. on_success runs only after the right PIN (or a newly made one).
func ask(message: String, on_success: Callable) -> void:
	on_ok = on_success
	message_label.text = message
	_set_mode("enter" if Settings.has_pin() else "create")
	visible = true


## Make a new PIN (used by "Change PIN" in the grown-ups area).
func ask_new_pin(on_success: Callable) -> void:
	on_ok = on_success
	message_label.text = tr("Choose a new grown-up PIN.")
	_set_mode("create")
	visible = true


func close() -> void:
	visible = false


func _set_mode(new_mode: String) -> void:
	mode = new_mode
	pin_edit.text = ""
	pin_edit.secret = mode != "forgot"
	pin_edit.max_length = 6 if mode == "forgot" else 4
	feedback_label.text = ""
	forgot_button.visible = mode == "enter"
	match mode:
		"create":
			info_label.text = tr("Choose a 4-digit PIN. You'll need it to remove players and to open the grown-ups area.")
		"confirm":
			info_label.text = tr("Type the same PIN again.")
		"enter":
			info_label.text = tr("Enter the 4-digit grown-up PIN.")
		"forgot":
			info_label.text = tr("Grown-up check: what is %d × %d? Then you can choose a new PIN.") % [factor_a, factor_b]
	pin_edit.call_deferred("grab_focus")


func _start_forgot() -> void:
	factor_a = randi_range(13, 39)
	factor_b = randi_range(12, 29)
	_set_mode("forgot")


func _digits_only(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != text:
		pin_edit.text = digits
		pin_edit.caret_column = digits.length()


func _on_ok() -> void:
	var pin := pin_edit.text
	match mode:
		"create":
			if pin.length() != 4:
				feedback_label.text = tr("Please use exactly 4 digits.")
				return
			first_pin = pin
			_set_mode("confirm")
		"confirm":
			if pin != first_pin:
				_set_mode("create")
				feedback_label.text = tr("The two PINs were different - please try again.")
				return
			Settings.set_pin(pin)
			_success()
		"enter":
			if Settings.check_pin(pin):
				_success()
			else:
				pin_edit.text = ""
				feedback_label.text = tr("That's not the right PIN.")
		"forgot":
			if pin.to_int() == factor_a * factor_b:
				message_label.text = tr("Choose a new grown-up PIN.")
				_set_mode("create")
			else:
				pin_edit.text = ""
				feedback_label.text = tr("Not quite - try again.")


func _success() -> void:
	visible = false
	if on_ok.is_valid():
		on_ok.call()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.25), 2, 10, 8))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), Color.WHITE, 2, 10, 8))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), Color.WHITE, 2, 10, 8))
	button.pressed.connect(action)
	return button


func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
