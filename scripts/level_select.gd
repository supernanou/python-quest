extends Control
## The level map: pick a course (Beginner / Intermediate) and a level.
## Finished levels show their quiz score; locked levels open after passing the quiz before them.

signal level_chosen(index: int)
signal change_hero
signal switch_player
signal open_notebook
signal open_lab
signal open_report
signal back

const HeroSprite = preload("res://scripts/hero_sprite.gd")
const LangToggle = preload("res://scripts/lang_toggle.gd")
const BackButton = preload("res://scripts/back_button.gd")
const Lang = preload("res://scripts/lang.gd")
const Courses = preload("res://scripts/courses.gd")

var tiles: Array = []
var hero: HeroSprite
var hero_name_label: Label
var wallet_label: Label
var tiles_box: GridContainer
var t := 0.0
var next_tile: Button
var last_levels: Array = []
var last_save
var course := 0
var title_label: Label
var course_tabs: Array = []


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)

	var bg := ColorRect.new()
	bg.color = Color("#0f172a")
	bg.size = size
	add_child(bg)

	title_label = _label("", 34, Color("#facc15"))
	title_label.position = Vector2(0, 20)
	title_label.size = Vector2(size.x, 46)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	# Course tabs: Beginner | Intermediate
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.position = Vector2(size.x / 2 - 175, 72)
	add_child(tabs)
	for c in Courses.COURSES.size():
		var tab := Button.new()
		tab.text = Courses.COURSES[c]["short"]
		tab.custom_minimum_size = Vector2(170, 40)
		tab.add_theme_font_size_override("font_size", 17)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(func() -> void: open(last_levels, last_save, c))
		tabs.add_child(tab)
		course_tabs.append(tab)

	hero = HeroSprite.new()
	hero.position = Vector2(170, 60)
	hero.scale = Vector2(1.6, 1.6)
	add_child(hero)
	hero_name_label = _label("", 16, Color.WHITE)
	hero_name_label.position = Vector2(130, 96)
	hero_name_label.size = Vector2(80, 22)
	hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hero_name_label)

	wallet_label = _label("", 22, Color("#38bdf8"))
	wallet_label.position = Vector2(size.x - 220, 60)
	wallet_label.size = Vector2(196, 30)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(wallet_label)

	var back_button := BackButton.new()
	back_button.pressed.connect(func() -> void: back.emit())
	add_child(back_button)

	var languages := LangToggle.new()
	languages.position = Vector2(size.x - 238, 12)
	languages.changed.connect(func() -> void: open(last_levels, last_save, course))
	add_child(languages)

	tiles_box = GridContainer.new()
	tiles_box.columns = 5
	tiles_box.add_theme_constant_override("h_separation", 14)
	tiles_box.add_theme_constant_override("v_separation", 14)
	tiles_box.position = Vector2(53, 128)
	add_child(tiles_box)

	var buttons := HBoxContainer.new()
	buttons.position = Vector2(53, 534)
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	for entry in [
		["Switch player", Color("#334155"), switch_player],
		["Change hero", Color("#7c3aed"), change_hero],
		["Notebook", Color("#a16207"), open_notebook],
		["Code Lab", Color("#16a34a"), open_lab],
		["Grown-ups", Color("#475569"), open_report],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(161, 48)
		button.add_theme_font_size_override("font_size", 18)
		var color: Color = entry[1]
		button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.3), 2, 12))
		button.add_theme_stylebox_override("hover", _box(color.lightened(0.15), Color.WHITE, 2, 12))
		button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), Color.WHITE, 2, 12))
		var sig: Signal = entry[2]
		button.pressed.connect(func() -> void: sig.emit())
		buttons.add_child(button)

	var help := _label("Click a level to play   -   In a level: M = level map, N = notebook", 15, Color("#64748b"))
	help.position = Vector2(0, 598)
	help.size = Vector2(size.x, 24)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(help)


## course: which tab to show. -1 = the course of the newest unlocked level.
func open(levels: Array, save, show_course := -1) -> void:
	last_levels = levels
	last_save = save
	if show_course == -1:
		show_course = levels[clampi(save.unlocked - 1, 0, levels.size() - 1)]["course"]
	course = show_course
	title_label.text = tr(Courses.COURSES[course]["name"])
	for c in course_tabs.size():
		var on: bool = c == course
		var tab: Button = course_tabs[c]
		tab.add_theme_stylebox_override("normal", _box(Color("#0369a1") if on else Color("#1e293b"), Color.WHITE if on else Color("#334155"), 2, 10))
		tab.add_theme_stylebox_override("hover", _box(Color("#0284c7") if on else Color("#273449"), Color.WHITE, 2, 10))
		tab.add_theme_color_override("font_color", Color.WHITE if on else Color("#94a3b8"))
	hero.look = save.look
	hero.queue_redraw()
	hero_name_label.text = save.look.get("name", "")
	wallet_label.text = "</>  %d" % save.icons
	for child in tiles_box.get_children():
		child.queue_free()
	tiles.clear()
	next_tile = null
	var span := Courses.course_range(course)
	for i in range(span[0], mini(span[1], levels.size() - 1) + 1):
		var tile := _make_tile(i, levels[i], save)
		tiles_box.add_child(tile)
		tiles.append(tile)
	visible = true
	if next_tile != null:
		next_tile.call_deferred("grab_focus")


func _make_tile(i: int, level: Dictionary, save) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(160, 180)
	tile.add_theme_font_size_override("font_size", 17)
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var locked: bool = i >= save.unlocked
	var done: bool = save.is_done(i)
	var bg := Color("#1e3a5f")
	var border := Color("#38bdf8")
	var status := tr("Play!")
	if locked:
		bg = Color("#1e293b")
		border = Color("#334155")
		status = tr("Locked")
		if i == Courses.course_range(level["course"])[0] and level["course"] > 0:
			status = tr("Finish the %s first") % tr(Courses.COURSES[level["course"] - 1]["short"])
		tile.disabled = true
	elif done:
		bg = Color("#14532d")
		border = Color("#4ade80")
		status = tr("Done!  Quiz %d/5") % save.quiz_scores[i]
	elif next_tile == null:
		border = Color("#facc15")
		next_tile = tile
	if not locked and not done and save.solved_in_level(i) > 0:
		status = tr("%d/10 done") % save.solved_in_level(i)
	tile.text = (tr("Level %d") + "\n\n%s\n\n%s") % [level["number"], Lang.pick(level, "name"), status]
	tile.add_theme_stylebox_override("normal", _box(bg, border, 3, 14))
	tile.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), Color.WHITE, 3, 14))
	tile.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), Color.WHITE, 3, 14))
	tile.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color.WHITE, 3, 14))
	tile.add_theme_stylebox_override("disabled", _box(bg, border, 3, 14))
	tile.add_theme_color_override("font_disabled_color", Color("#64748b"))
	tile.pressed.connect(func() -> void: level_chosen.emit(i))
	return tile


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	hero.walk_time = t * 5.0
	hero.queue_redraw()
	if next_tile != null:
		var pulse := 1.0 + sin(t * 4.0) * 0.03
		next_tile.pivot_offset = next_tile.size / 2.0
		next_tile.scale = Vector2(pulse, pulse)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
