extends Area2D
## A </> code icon to collect. Spend them on hints and hero extras.

var id := ""
var t := randf() * TAU
var badge := StyleBoxFlat.new()


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	add_child(shape)
	badge.bg_color = Color("#0ea5e9")
	badge.border_color = Color("#e0f2fe")
	badge.set_border_width_all(2)
	badge.set_corner_radius_all(6)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var offset := Vector2(0, sin(t * 3.0) * 3.0)
	draw_circle(offset, 18, Color(0.05, 0.65, 0.91, 0.18 + 0.1 * sin(t * 4.0)))
	badge.draw(get_canvas_item(), Rect2(offset + Vector2(-15, -10), Vector2(30, 20)))
	draw_string(ThemeDB.fallback_font, offset + Vector2(-15, 5), "</>", HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color.WHITE)
