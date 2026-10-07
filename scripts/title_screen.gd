extends Control
## The first screen: a bouncy title, a hero strolling on the grass and a start button.

signal start_pressed

const HeroSprite = preload("res://scripts/hero_sprite.gd")
const LangToggle = preload("res://scripts/lang_toggle.gd")
const HelpPanel = preload("res://scripts/help_panel.gd")
const TITLE := "Python Quest"
const TITLE_COLORS := [Color("#4b8bbe"), Color("#ffd43b")]
const GRASS_TOP := 510.0

var t := 0.0
var hero: HeroSprite
var hero_dir := 1.0
var title_font := SystemFont.new()
var sparkles := []  # [position, phase]
var start_button: Button
var help_button: Button
var help: Control


func _ready() -> void:
	size = Vector2(960, 640)
	title_font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Nunito", "Avenir Next", "Helvetica Neue", "sans-serif"])
	title_font.font_weight = 800
	for i in 40:
		sparkles.append([Vector2(randf() * size.x, randf() * (GRASS_TOP - 40)), randf() * TAU])

	hero = HeroSprite.new()
	hero.scale = Vector2(2.6, 2.6)
	hero.position = Vector2(200, GRASS_TOP - 40)
	add_child(hero)

	start_button = Button.new()
	start_button.text = "Press ENTER to start"
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.position = Vector2(370, 296)
	start_button.size = Vector2(240, 48)
	start_button.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		start_button.add_theme_color_override(state, Color("#0f172a"))
	start_button.add_theme_stylebox_override("normal", _pill(Color("#ffd43b")))
	start_button.add_theme_stylebox_override("hover", _pill(Color("#ffe066")))
	start_button.add_theme_stylebox_override("pressed", _pill(Color("#f5c518")))
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	add_child(start_button)

	# Pick the language first - Greek or English instructions
	var languages := LangToggle.new()
	languages.position = Vector2(size.x - 238, 16)
	add_child(languages)

	# "How to play" opens a menu that explains every key
	help_button = Button.new()
	help_button.text = "How to play"
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.position = Vector2(360, 358)
	help_button.size = Vector2(240, 48)
	help_button.add_theme_font_size_override("font_size", 17)
	help_button.add_theme_color_override("font_color", Color("#cbd5e1"))
	help_button.add_theme_color_override("font_hover_color", Color.WHITE)
	help_button.add_theme_stylebox_override("normal", _outline(Color("#475569")))
	help_button.add_theme_stylebox_override("hover", _outline(Color("#cbd5e1")))
	help_button.add_theme_stylebox_override("pressed", _outline(Color.WHITE))
	add_child(help_button)

	var credit := Label.new()
	credit.text = "made by @vaslabs"
	credit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	credit.position = Vector2(0, 604)
	credit.size = Vector2(size.x, 24)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 15)
	credit.add_theme_color_override("font_color", Color("#2f5d1a"))
	add_child(credit)

	help = HelpPanel.new()
	add_child(help)
	help_button.pressed.connect(help.open)


func set_look(look: Dictionary) -> void:
	hero.look = look


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta

	hero.position.x += hero_dir * 90.0 * delta
	if hero.position.x > size.x - 60:
		hero_dir = -1.0
	elif hero.position.x < 60:
		hero_dir = 1.0
	hero.facing = Vector2(hero_dir, 0)
	hero.walk_time += delta * 10.0
	hero.queue_redraw()

	# Both buttons are the same size, wide enough for the longer text (Greek is longer)
	var width := maxf(240.0, maxf(start_button.get_minimum_size().x, help_button.get_minimum_size().x) + 44.0)
	for button in [start_button, help_button]:
		button.size = Vector2(width, 48)
		button.position.x = (size.x - width) / 2.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0f172a"))
	for sparkle in sparkles:
		var alpha := 0.15 + 0.45 * absf(sin(t * 1.5 + sparkle[1]))
		draw_circle(sparkle[0], 1.6, Color(1, 1, 1, alpha))

	# Title letters bob up and down in a wave
	var font_size := 84
	var width := title_font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := (size.x - width) / 2.0
	var color_index := 0
	for i in TITLE.length():
		var ch := TITLE[i]
		if ch != " ":
			var pos := Vector2(x, 180 + sin(t * 3.0 + i * 0.5) * 8.0)
			draw_string(title_font, pos + Vector2(0, 6), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#020617"))
			draw_string(title_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TITLE_COLORS[color_index % 2])
			color_index += 1
		x += title_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	draw_string(ThemeDB.fallback_font, Vector2(0, 245), tr("Learn Python. Open doors. Become a hero!"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color("#94a3b8"))

	# Grass strip for the hero to walk on
	for col in ceili(size.x / 48.0):
		for row in 3:
			var tile := Rect2(col * 48, GRASS_TOP + row * 48, 48, 48)
			draw_rect(tile, Color("#7ec850") if (col + row) % 2 == 0 else Color("#76bf49"))
	draw_rect(Rect2(0, GRASS_TOP, size.x, 6), Color("#5fa83a"))


func _outline(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	return style


func _pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(25)
	style.border_color = color.darkened(0.3)
	style.border_width_bottom = 4
	return style
