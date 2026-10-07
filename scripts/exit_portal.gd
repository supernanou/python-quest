extends Area2D
## Walk into this to finish the stage.

var t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	for i in 4:
		var r := 22.0 - i * 5.0 + sin(t * 3.0 + i) * 1.5
		var c := Color("#a855f7").lerp(Color("#f0abfc"), i / 3.0)
		draw_circle(Vector2.ZERO, r, c)
	for i in 3:
		var a := t * 2.5 + i * TAU / 3.0
		draw_circle(Vector2(cos(a), sin(a)) * 14.0, 2.5, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(0, -26), tr("EXIT"), HORIZONTAL_ALIGNMENT_CENTER, 0, 13, Color.WHITE)
