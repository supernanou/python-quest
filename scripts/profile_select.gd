extends Control
## "Who's playing?" - pick your player, or add a new one. Each player has their
## own hero, icons and progress, so brothers, sisters or a whole class can share.

signal chosen(save)
signal new_player
signal back
signal remove_requested(save)

const HeroSprite = preload("res://scripts/hero_sprite.gd")
const Profiles = preload("res://scripts/profiles.gd")
const Courses = preload("res://scripts/courses.gd")
const BackButton = preload("res://scripts/back_button.gd")

var players: Array = []
var grid: GridContainer
var heroes: Array = []
var t := 0.0


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)

	var bg := ColorRect.new()
	bg.color = Color("#0f172a")
	bg.size = size
	add_child(bg)

	var title := Label.new()
	title.text = "Who's playing?"
	title.position = Vector2(0, 30)
	title.size = Vector2(size.x, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#facc15"))
	add_child(title)

	var back_button := BackButton.new()
	back_button.pressed.connect(func() -> void: back.emit())
	add_child(back_button)

	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(76, 110)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	add_child(grid)


func open() -> void:
	players = Profiles.all()
	_rebuild()
	visible = true


func _rebuild() -> void:
	for child in grid.get_children():
		child.queue_free()
	heroes.clear()
	for save in players:
		grid.add_child(_player_card(save))
	if players.size() < Profiles.MAX_PLAYERS:
		var add := _card_button(Color("#1e293b"), Color("#475569"))
		add.text = "+\nNew player"
		add.add_theme_font_size_override("font_size", 24)
		add.pressed.connect(func() -> void: new_player.emit())
		var holder := VBoxContainer.new()
		holder.add_child(add)
		grid.add_child(holder)


func _player_card(save) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	var card := _card_button(Color("#1e3a5f"), Color("#38bdf8"))
	card.pressed.connect(func() -> void: chosen.emit(save))
	holder.add_child(card)

	var hero := HeroSprite.new()
	hero.look = save.look
	hero.position = Vector2(95, 78)
	hero.scale = Vector2(2.4, 2.4)
	card.add_child(hero)
	heroes.append(hero)

	var name: String = save.look.get("name", "")
	var name_label := _label(name if name != "" else "Player", 20, Color.WHITE)
	name_label.position = Vector2(0, 128)
	card.add_child(name_label)
	var done := 0
	var total_levels := 0
	for c in Courses.COURSES.size():
		total_levels += Courses.COURSES[c]["files"].size()
	for i in total_levels:
		done += save.solved_in_level(i)
	# Where they are now, e.g. "Beginner 4" or "Intermediate 2"
	var newest := clampi(save.unlocked - 1, 0, total_levels - 1)
	var course_index := 0
	for c in Courses.COURSES.size():
		if newest >= Courses.course_range(c)[0]:
			course_index = c
	var number: int = newest - Courses.course_range(course_index)[0] + 1
	var progress := _label(tr("%s %d  -  %d exercises") % [tr(Courses.COURSES[course_index]["short"]), number, done], 14, Color("#94a3b8"))
	progress.position = Vector2(0, 156)
	card.add_child(progress)

	var remove := Button.new()
	remove.text = "Remove"
	remove.flat = true
	remove.add_theme_font_size_override("font_size", 13)
	remove.add_theme_color_override("font_color", Color("#64748b"))
	remove.pressed.connect(func() -> void: remove_requested.emit(save))
	holder.add_child(remove)
	return holder


func _card_button(bg: Color, border: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(190, 186)
	for state in ["normal", "focus"]:
		button.add_theme_stylebox_override(state, _box(bg, border, 3))
	button.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), Color.WHITE, 3))
	button.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), Color.WHITE, 3))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.size = Vector2(190, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	for hero in heroes:
		if is_instance_valid(hero):
			hero.walk_time = t * 5.0
			hero.queue_redraw()


func _box(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(14)
	return style
