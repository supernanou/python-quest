extends HBoxContainer
## Two buttons: English | Ελληνικά. Used on the title screen and the level map.

signal changed

const Lang = preload("res://scripts/lang.gd")

var buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for code in ["en", "el"]:
		var button := Button.new()
		button.text = "English" if code == "en" else "Ελληνικά"
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(108, 38)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_choose.bind(code))
		add_child(button)
		buttons[code] = button
	_refresh()


func _choose(code: String) -> void:
	Lang.set_language(code)
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not buttons.is_empty():
		_refresh()


func _refresh() -> void:
	for code in buttons:
		var selected: bool = code == Lang.current()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0369a1") if selected else Color("#1e293b")
		style.border_color = Color.WHITE if selected else Color("#334155")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		for state in ["normal", "hover", "pressed"]:
			buttons[code].add_theme_stylebox_override(state, style)
		buttons[code].add_theme_color_override("font_color", Color.WHITE if selected else Color("#94a3b8"))
