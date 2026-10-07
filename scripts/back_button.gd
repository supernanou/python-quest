extends Button
## The same "< Back" button on every screen (top-left corner).


func _ready() -> void:
	text = "< Back"
	focus_mode = Control.FOCUS_NONE
	position = Vector2(14, 14)
	size = Vector2(100, 40)
	add_theme_font_size_override("font_size", 17)
	add_theme_color_override("font_color", Color("#e2e8f0"))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_stylebox_override("normal", _box(Color("#1e293b"), Color("#475569")))
	add_theme_stylebox_override("hover", _box(Color("#334155"), Color("#cbd5e1")))
	add_theme_stylebox_override("pressed", _box(Color("#0f172a"), Color.WHITE))


func _process(_delta: float) -> void:
	# Grow to fit the text (Greek is longer)
	size.x = maxf(100.0, get_minimum_size().x + 24.0)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	return style
