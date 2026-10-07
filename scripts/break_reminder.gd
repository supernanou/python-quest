extends Control
## "Time for a break!" After 30 minutes of play the game pauses and suggests a
## 5-minute break with stretching tips. Change the minutes below if you like.

const HeroSprite = preload("res://scripts/hero_sprite.gd")
const Speech = preload("res://scripts/speech.gd")

const PLAY_MINUTES := 30.0  # play time before the first reminder
const SNOOZE_MINUTES := 15.0  # "Keep playing for now" asks again after this long
const BREAK_MINUTES := 5.0  # length of the break countdown

const TIPS := [
	"Stand up and stretch your arms up high!",
	"Look out of the window at something far away.",
	"Drink a glass of water.",
	"Roll your shoulders and wiggle your fingers.",
	"Walk around the room.",
	"Do 10 jumping jacks!",
]

var play_seconds := 0.0  # how long this session has been played
var next_reminder := PLAY_MINUTES * 60.0
var break_left := 0.0
var on_break := false
var tip_index := 0
var tip_time := 0.0

var ask_view: VBoxContainer
var break_view: VBoxContainer
var ask_text: Label
var countdown: Label
var tip_label: Label
var back_button: Button
var hero: HeroSprite
var hero_holder: Control
var t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	visible = false
	size = Vector2(960, 640)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.12, 0.96)
	bg.size = size
	add_child(bg)

	var center := CenterContainer.new()
	center.size = size
	add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_stylebox_override("panel", _box(Color("#0f172a"), Color("#4ade80"), 3, 18, 28))
	center.add_child(box)
	var holder := VBoxContainer.new()
	box.add_child(holder)

	# --- "Time for a break?"
	ask_view = VBoxContainer.new()
	ask_view.add_theme_constant_override("separation", 16)
	holder.add_child(ask_view)
	var title := _label("Time for a break!", 34, Color("#4ade80"))
	ask_view.add_child(title)
	ask_text = _label("", 19, Color("#e2e8f0"))
	ask_view.add_child(ask_text)
	var ask_buttons := HBoxContainer.new()
	ask_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	ask_buttons.add_theme_constant_override("separation", 14)
	ask_view.add_child(ask_buttons)
	ask_buttons.add_child(_button("Take a 5-minute break", Color("#16a34a"), _start_break))
	ask_buttons.add_child(_button("Keep playing for now", Color("#334155"), _keep_playing))

	# --- Break countdown
	break_view = VBoxContainer.new()
	break_view.add_theme_constant_override("separation", 14)
	holder.add_child(break_view)
	break_view.add_child(_label("Break time!", 34, Color("#4ade80")))
	hero_holder = Control.new()
	hero_holder.custom_minimum_size = Vector2(0, 170)
	break_view.add_child(hero_holder)
	hero = HeroSprite.new()
	hero.scale = Vector2(3, 3)
	hero_holder.add_child(hero)
	countdown = _label("5:00", 48, Color.WHITE)
	break_view.add_child(countdown)
	tip_label = _label("", 21, Color("#fde68a"))
	break_view.add_child(tip_label)
	back_button = _button("I'm back!", Color("#16a34a"), _end_break)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	break_view.add_child(back_button)


## Called by the game every frame while someone is playing.
func count_play_time(delta: float, look: Dictionary) -> void:
	if visible:
		return
	play_seconds += delta
	if play_seconds >= next_reminder:
		_ask(look)


func _ask(look: Dictionary) -> void:
	hero.look = look
	Speech.stop()
	get_tree().paused = true
	visible = true
	ask_view.visible = true
	break_view.visible = false
	ask_text.text = tr("You've been coding for %d minutes - great work! Give your eyes and your body a little rest.") % roundi(play_seconds / 60.0)


func _keep_playing() -> void:
	next_reminder = play_seconds + SNOOZE_MINUTES * 60.0
	_resume()


func _start_break() -> void:
	on_break = true
	break_left = BREAK_MINUTES * 60.0
	tip_index = randi() % TIPS.size()
	tip_time = 0.0
	ask_view.visible = false
	break_view.visible = true
	back_button.visible = false
	_show_tip()


func _end_break() -> void:
	on_break = false
	next_reminder = play_seconds + PLAY_MINUTES * 60.0
	_resume()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _show_tip() -> void:
	tip_label.text = tr(TIPS[tip_index % TIPS.size()])


func _process(delta: float) -> void:
	if not visible or not on_break:
		return
	t += delta
	# The hero does jumping jacks
	hero.position = Vector2(hero_holder.size.x / 2.0, 120 - absf(sin(t * 5.0)) * 22.0)
	hero.walk_time = t * 8.0
	hero.queue_redraw()
	if break_left > 0.0:
		break_left = maxf(break_left - delta, 0.0)
		countdown.text = "%d:%02d" % [int(break_left) / 60, int(break_left) % 60]
		tip_time += delta
		if tip_time > 20.0:
			tip_time = 0.0
			tip_index += 1
			_show_tip()
		if break_left <= 0.0:
			countdown.text = tr("Welcome back!")
			back_button.visible = true


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
	button.custom_minimum_size = Vector2(200, 50)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.3), 2, 12, 10))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.15), Color.WHITE, 2, 12, 10))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), Color.WHITE, 2, 12, 10))
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
