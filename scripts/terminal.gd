extends Area2D
## A computer the hero walks up to. Holds a few exercises (2 per computer).

var letter := "a"
var exercises: Array = []
var progress := 0  # how many exercises are solved
var t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44
	shape.shape = circle
	add_child(shape)


func is_solved() -> bool:
	return progress >= exercises.size()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var solved := is_solved()
	draw_rect(Rect2(-6, 8, 12, 8), Color("#4b5563"))
	draw_rect(Rect2(-16, 15, 32, 5), Color("#4b5563"))
	draw_rect(Rect2(-21, -20, 42, 30), Color("#1f2937"))
	var screen := Color("#22c55e") if solved else Color("#38bdf8")
	screen.a = 0.75 + 0.25 * sin(t * 4.0)
	draw_rect(Rect2(-17, -16, 34, 22), screen)
	draw_string(font, Vector2(-15, 0), "OK" if solved else ">>>", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#0f172a"))
	# One dot per exercise: green when solved
	var count := exercises.size()
	for i in count:
		var dot := Vector2((i - (count - 1) / 2.0) * 11.0, 27)
		draw_circle(dot, 4.5, Color("#0f172a"))
		draw_circle(dot, 3.5, Color("#22c55e") if i < progress else Color("#cbd5e1"))
	if not solved:
		draw_string(font, Vector2(-5, -28 + sin(t * 5.0) * 3.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#facc15"))
