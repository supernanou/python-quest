extends Node2D
## Code Quest - runs the screens and builds each level from its map.
##
## Title -> Who's playing? -> Create your hero (new players) -> Level map -> Level -> Quiz -> next level
## From the level map: Notebook, Code Lab and the grown-ups' progress report.

const TILE := 48
const HUD_HEIGHT := 64
const SCREEN := Vector2(960, 640)
const EXERCISES_PER_COMPUTER := 2

const Courses = preload("res://scripts/courses.gd")
const Maps = preload("res://scripts/maps.gd")
const SaveData = preload("res://scripts/save_data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const LevelDrawer = preload("res://scripts/level_drawer.gd")
const Terminal = preload("res://scripts/terminal.gd")
const Door = preload("res://scripts/door.gd")
const CodeIcon = preload("res://scripts/code_icon.gd")
const ExitPortal = preload("res://scripts/exit_portal.gd")
const PuzzlePanel = preload("res://scripts/puzzle_panel.gd")
const QuizPanel = preload("res://scripts/quiz_panel.gd")
const CharacterCreator = preload("res://scripts/character_creator.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const LevelSelect = preload("res://scripts/level_select.gd")
const Profiles = preload("res://scripts/profiles.gd")
const ProfileSelect = preload("res://scripts/profile_select.gd")
const Notebook = preload("res://scripts/notebook.gd")
const Report = preload("res://scripts/report.gd")
const CodeLab = preload("res://scripts/code_lab.gd")
const BackButton = preload("res://scripts/back_button.gd")
const BreakReminder = preload("res://scripts/break_reminder.gd")
const Lang = preload("res://scripts/lang.gd")

var state := "title"  # "title", "players", "creator", "levels", "playing", "quiz" or "won"
var save: SaveData
var levels: Array = []
var level_index := 0
var transitioning := false

var level_root: Node2D
var player: CharacterBody2D
var terminals: Array = []
var doors := {}  # "A" -> [door, door...]
var near_terminal: Area2D = null

var level_label: Label
var progress_label: Label
var icons_label: Label
var prompt_label: Label
var banner: Label
var overlay: ColorRect
var overlay_label: Label
var panel: Control
var quiz: Control
var creator: Control
var title_screen: Control
var level_select: Control
var profile_select: Control
var notebook: Control
var report: Control
var code_lab: Control
var break_reminder: Control


func _ready() -> void:
	# Fill the screen; the game art stretches to fit any window size.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	Lang.setup()
	levels = Courses.beginner()
	_setup_inputs()
	_build_ui()
	var players := Profiles.all()
	if not players.is_empty():
		title_screen.set_look(players[-1].look)
	title_screen.visible = true


func _process(delta: float) -> void:
	# Count play time for the break reminder (not on the title screen)
	if state != "title" and save != null:
		break_reminder.count_play_time(delta, save.look)


func _setup_inputs() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("interact", [KEY_E, KEY_SPACE])
	_add_action("restart", [KEY_R])
	_add_action("level_map", [KEY_M])
	_add_action("notebook", [KEY_N])
	_add_action("fullscreen", [KEY_F, KEY_F11])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if event.is_action_pressed("ui_cancel") and _go_back():
		get_viewport().set_input_as_handled()
		return
	match state:
		"title":
			if event.is_action_pressed("ui_accept"):
				get_viewport().set_input_as_handled()
				_on_title_start()
		"won":
			if event.is_action_pressed("ui_accept"):
				get_viewport().set_input_as_handled()
				_show_level_select()
		"playing":
			if panel.visible or notebook.visible:
				return
			if event.is_action_pressed("interact") and near_terminal != null:
				player.frozen = true
				prompt_label.visible = false
				panel.open(near_terminal.letter, near_terminal.exercises, near_terminal.progress)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("restart"):
				_load_level(level_index)
			elif event.is_action_pressed("level_map"):
				_show_level_select()
			elif event.is_action_pressed("notebook"):
				get_viewport().set_input_as_handled()
				_open_notebook()


# ---------------------------------------------------------------- screens

## Esc = back, on every screen. Windows (exercise, quiz, notebook, report, Code Lab)
## close themselves first, so this only runs when nothing else used Esc.
func _go_back() -> bool:
	if code_lab.visible or report.visible or notebook.visible or quiz.visible or panel.visible:
		return false
	match state:
		"players":
			_show_title()
		"levels", "won":
			if state == "levels":
				_show_players()
			else:
				_show_level_select()
		"playing":
			_show_level_select()
		_:
			return false
	return true


func _show_title() -> void:
	state = "title"
	profile_select.visible = false
	level_select.visible = false
	title_screen.visible = true


func _on_creator_back() -> void:
	# Back from "Create your hero": an existing player keeps their old look,
	# a brand-new player (not saved yet) goes back to "Who's playing?"
	if save != null and save.has_hero:
		_show_level_select()
	else:
		_show_players()


func _on_title_start() -> void:
	title_screen.visible = false
	_show_players()


func _show_players() -> void:
	state = "players"
	_clear_level()
	level_select.visible = false
	profile_select.open()


func _on_player_chosen(player_save: SaveData) -> void:
	save = player_save
	panel.save = save
	panel.hero_name = _hero_name()
	profile_select.visible = false
	if save.has_hero:
		_show_level_select()
	else:
		_open_creator()


func _on_new_player() -> void:
	_on_player_chosen(Profiles.create())


func _open_creator() -> void:
	state = "creator"
	title_screen.visible = false
	level_select.visible = false
	profile_select.visible = false
	overlay.visible = false
	creator.open(save)


func _on_hero_created(look: Dictionary) -> void:
	save.look = look
	save.has_hero = true
	save.save_file()
	panel.hero_name = _hero_name()
	title_screen.set_look(look)
	_show_level_select()


func _show_level_select() -> void:
	state = "levels"
	_clear_level()
	overlay.visible = false
	quiz.visible = false
	panel.visible = false
	level_select.open(levels, save)


func _open_notebook() -> void:
	if player != null:
		player.frozen = true
	notebook.open(levels, save, level_index if state == "playing" else -1)


func _on_notebook_closed() -> void:
	if state == "playing" and player != null and not panel.visible:
		player.frozen = false


func _on_level_chosen(index: int) -> void:
	level_select.visible = false
	_load_level(index)


func _hero_name() -> String:
	var hero_name: String = save.look.get("name", "")
	return hero_name if hero_name != "" else tr("Hero")


# ---------------------------------------------------------------- levels

func _clear_level() -> void:
	if level_root != null:
		level_root.queue_free()
	level_root = null
	player = null
	near_terminal = null
	terminals.clear()
	doors.clear()
	prompt_label.visible = false


func _load_level(index: int) -> void:
	_clear_level()
	state = "playing"
	level_index = index
	transitioning = false

	var data: Dictionary = levels[index]
	var map: Array = Maps.get_map(data["map"], data.get("variant", 0))
	var exercises: Array = data["exercises"]

	level_root = Node2D.new()
	level_root.position = Vector2(0, HUD_HEIGHT)
	add_child(level_root)
	move_child(level_root, 0)

	var drawer := LevelDrawer.new()
	drawer.map = map
	drawer.tile = TILE
	drawer.floor_a = Color(data["floor"][0])
	drawer.floor_b = Color(data["floor"][1])
	drawer.wall = Color(data["wall"])
	level_root.add_child(drawer)

	var walls := StaticBody2D.new()
	level_root.add_child(walls)

	var start := Vector2.ZERO
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			var ch := row[x]
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			if ch == "#":
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(TILE, TILE)
				shape.shape = rect
				shape.position = pos
				walls.add_child(shape)
			elif ch == "P":
				start = pos
			elif ch == "X":
				var portal := ExitPortal.new()
				portal.position = pos
				portal.body_entered.connect(_on_exit_entered)
				level_root.add_child(portal)
			elif ch == "*":
				var id := "%d:%d,%d" % [index, x, y]
				if id in save.collected:
					continue
				var icon := CodeIcon.new()
				icon.id = id
				icon.position = pos
				icon.body_entered.connect(_on_icon_entered.bind(icon))
				level_root.add_child(icon)
			elif ch in "abcdefgh":
				var n := "abcdefgh".find(ch)
				var terminal := Terminal.new()
				terminal.position = pos
				terminal.letter = ch
				terminal.exercises = exercises.slice(n * EXERCISES_PER_COMPUTER, (n + 1) * EXERCISES_PER_COMPUTER)
				for exercise in terminal.exercises:
					if save.is_solved(exercise["id"]):
						terminal.progress += 1
				terminal.body_entered.connect(_on_terminal_entered.bind(terminal))
				terminal.body_exited.connect(_on_terminal_exited.bind(terminal))
				level_root.add_child(terminal)
				terminals.append(terminal)
			elif ch in "ABCDEFGH":
				var door := Door.new()
				door.position = pos
				level_root.add_child(door)
				if not doors.has(ch):
					doors[ch] = []
				doors[ch].append(door)

	# Progress inside the level is remembered: doors of finished computers start open
	for terminal in terminals:
		if terminal.is_solved():
			for door in doors.get(terminal.letter.to_upper(), []):
				door.open(true)

	player = PlayerScript.new()
	player.look = save.look
	player.position = start
	level_root.add_child(player)

	level_label.text = tr("Level %d/%d: %s") % [index + 1, levels.size(), Lang.pick(data, "name")]
	_update_hud()
	_show_banner((tr("Level %d") + "\n%s") % [index + 1, Lang.pick(data, "name")])


func _update_hud() -> void:
	var solved := 0
	var total := 0
	for terminal in terminals:
		solved += mini(terminal.progress, terminal.exercises.size())
		total += terminal.exercises.size()
	progress_label.text = tr("Exercises %d/%d") % [solved, total]
	icons_label.text = "</>  %d" % save.icons


func _terminal_prompt(terminal: Area2D) -> String:
	if terminal.is_solved():
		return tr("Solved! (E to practise)")
	return tr("Press E to code! (%d/%d)") % [terminal.progress, terminal.exercises.size()]


func _on_terminal_entered(body: Node2D, terminal: Area2D) -> void:
	if body == player:
		near_terminal = terminal
		prompt_label.text = _terminal_prompt(terminal)
		prompt_label.position = level_root.position + terminal.position + Vector2(-110, -74)
		prompt_label.visible = true


func _on_terminal_exited(body: Node2D, terminal: Area2D) -> void:
	if body == player and near_terminal == terminal:
		near_terminal = null
		prompt_label.visible = false


func _on_icon_entered(body: Node2D, icon: Area2D) -> void:
	if body != player or icon.is_queued_for_deletion():
		return
	save.icons += 1
	save.collected.append(icon.id)
	save.save_file()
	_update_hud()
	_float_text("+1 </>", level_root.position + icon.position)
	icon.queue_free()


func _on_exercise_solved(letter: String, index: int) -> void:
	for terminal in terminals:
		if terminal.letter == letter:
			terminal.progress = maxi(terminal.progress, index + 1)
			if terminal.is_solved():
				for door in doors.get(letter.to_upper(), []):
					door.open()
	_update_hud()


func _on_panel_closed() -> void:
	if player != null:
		player.frozen = false
	if near_terminal != null:
		prompt_label.text = _terminal_prompt(near_terminal)
		prompt_label.visible = true


# ---------------------------------------------------------------- quiz

func _on_exit_entered(body: Node2D) -> void:
	if body == player and not transitioning:
		transitioning = true
		call_deferred("_start_quiz")


func _start_quiz() -> void:
	state = "quiz"
	player.frozen = true
	prompt_label.visible = false
	quiz.start(level_index + 1, levels[level_index]["quiz"], level_index + 1 >= levels.size())


func _on_quiz_finished(_score: int) -> void:
	save.quiz_attempts[level_index] = save.quiz_attempts.get(level_index, 0) + 1
	save.save_file()


func _on_quiz_passed(score: int) -> void:
	var first_time := not save.is_done(level_index)
	save.quiz_scores[level_index] = maxi(score, save.quiz_scores.get(level_index, 0))
	save.unlocked = mini(maxi(save.unlocked, level_index + 2), levels.size())
	if first_time:
		var bonus := 3 if score == QuizPanel.QUESTIONS_PER_QUIZ else 2
		save.icons += bonus
		quiz.reward_text = tr("+%d </> bonus icons for passing!") % bonus
	save.save_file()
	_update_hud()


func _on_quiz_cancelled() -> void:
	# Back to the level - walk into the portal again to retry.
	state = "playing"
	transitioning = false
	if player != null:
		player.frozen = false


func _on_quiz_next_level() -> void:
	quiz.visible = false
	if level_index + 1 < levels.size():
		_load_level(level_index + 1)
	else:
		_clear_level()
		state = "won"
		_show_overlay(tr("YOU DID IT, %s!\n\nYou finished the Beginner course:\n100 exercises and 10 quizzes!\nYou are now a Code Hero!\n\n</> icons: %d\n\nPress ENTER to go to the level map") % [_hero_name().to_upper(), save.icons])


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var bar := ColorRect.new()
	bar.color = Color("#1e293b")
	bar.size = Vector2(SCREEN.x, HUD_HEIGHT)
	hud.add_child(bar)

	level_label = _make_label(22, Color.WHITE)
	level_label.position = Vector2(126, 6)
	hud.add_child(level_label)

	var help := _make_label(14, Color("#94a3b8"))
	help.position = Vector2(126, 38)
	help.text = "Walk: arrows   E: computer   N: notebook   Esc: back   R: back to start   F: full screen"

	# Back to the level map (progress in the level is saved)
	var hud_back := BackButton.new()
	hud_back.position = Vector2(8, 12)
	hud_back.pressed.connect(func() -> void:
		if state == "playing" and not panel.visible:
			_show_level_select())
	hud.add_child(hud_back)
	hud.add_child(help)

	progress_label = _make_label(18, Color("#4ade80"))
	progress_label.position = Vector2(SCREEN.x - 336, 8)
	progress_label.size = Vector2(180, 26)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(progress_label)

	icons_label = _make_label(24, Color("#38bdf8"))
	icons_label.position = Vector2(SCREEN.x - 146, 14)
	icons_label.size = Vector2(130, 32)
	icons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(icons_label)

	prompt_label = _make_label(16, Color.WHITE)
	prompt_label.size = Vector2(220, 24)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.z_index = 100
	prompt_label.visible = false
	add_child(prompt_label)

	banner = _make_label(44, Color.WHITE)
	banner.position = Vector2(0, 240)
	banner.size = Vector2(SCREEN.x, 140)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	hud.add_child(banner)

	var panel_layer := CanvasLayer.new()
	panel_layer.layer = 5
	add_child(panel_layer)
	panel = PuzzlePanel.new()
	panel.save = save
	panel.exercise_solved.connect(_on_exercise_solved)
	panel.wallet_changed.connect(_update_hud)
	panel.closed.connect(_on_panel_closed)
	panel.notebook_requested.connect(_open_notebook)
	panel_layer.add_child(panel)

	quiz = QuizPanel.new()
	quiz.passed.connect(_on_quiz_passed)
	quiz.finished.connect(_on_quiz_finished)
	quiz.next_level.connect(_on_quiz_next_level)
	quiz.to_map.connect(_show_level_select)
	quiz.cancelled.connect(_on_quiz_cancelled)
	panel_layer.add_child(quiz)

	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 10
	add_child(overlay_layer)
	overlay = ColorRect.new()
	overlay.color = Color(0.06, 0.09, 0.16, 1.0)
	overlay.size = SCREEN
	overlay.visible = false
	overlay_layer.add_child(overlay)
	overlay_label = _make_label(26, Color.WHITE)
	overlay_label.size = SCREEN
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_label)

	title_screen = TitleScreen.new()
	title_screen.start_pressed.connect(func() -> void:
		if state == "title":
			_on_title_start())
	overlay_layer.add_child(title_screen)

	level_select = LevelSelect.new()
	level_select.level_chosen.connect(_on_level_chosen)
	level_select.change_hero.connect(_open_creator)
	level_select.switch_player.connect(_show_players)
	level_select.back.connect(_show_players)
	level_select.open_notebook.connect(_open_notebook)
	level_select.open_lab.connect(func() -> void: code_lab.open(save))
	level_select.open_report.connect(func() -> void: report.open(levels, save))
	overlay_layer.add_child(level_select)

	profile_select = ProfileSelect.new()
	profile_select.chosen.connect(_on_player_chosen)
	profile_select.new_player.connect(_on_new_player)
	profile_select.back.connect(_show_title)
	overlay_layer.add_child(profile_select)

	var top_layer := CanvasLayer.new()
	top_layer.layer = 11
	add_child(top_layer)
	code_lab = CodeLab.new()
	code_lab.closed.connect(func() -> void: level_select.open(levels, save))
	top_layer.add_child(code_lab)
	report = Report.new()
	top_layer.add_child(report)
	notebook = Notebook.new()
	notebook.closed.connect(_on_notebook_closed)
	top_layer.add_child(notebook)

	var break_layer := CanvasLayer.new()
	break_layer.layer = 20
	add_child(break_layer)
	break_reminder = BreakReminder.new()
	break_layer.add_child(break_reminder)

	creator = CharacterCreator.new()
	creator.confirmed.connect(_on_hero_created)
	creator.back.connect(_on_creator_back)
	overlay_layer.add_child(creator)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label


func _show_overlay(text: String) -> void:
	overlay_label.text = text
	overlay.visible = true


func _show_banner(text: String) -> void:
	banner.text = text
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.2)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)


func _float_text(text: String, at: Vector2) -> void:
	var label := _make_label(20, Color("#38bdf8"))
	label.text = text
	label.position = at + Vector2(-30, -40)
	label.z_index = 100
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
