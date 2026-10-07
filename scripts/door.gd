extends StaticBody2D
## A locked gate. It slides open when its computer's puzzle is solved.

var size := 48.0
var is_open := false
var open_amount := 0.0
var shape: CollisionShape2D


func _ready() -> void:
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size)
	shape.shape = rect
	add_child(shape)


func open(instant := false) -> void:
	if is_open:
		return
	is_open = true
	shape.set_deferred("disabled", true)
	if instant:
		open_amount = 1.0
		return
	var tween := create_tween()
	tween.tween_property(self, "open_amount", 1.0, 0.7).set_trans(Tween.TRANS_BACK)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var h := size / 2.0
	var height := size * (1.0 - open_amount)
	if height <= 0.5:
		return
	draw_rect(Rect2(-h, -h, size, height), Color("#92400e"))
	for i in 4:
		draw_rect(Rect2(-h + 5 + i * 11, -h, 5, height), Color("#78350f"))
	draw_rect(Rect2(-h, -h, size, height), Color("#451a03"), false, 2.0)
	if not is_open:
		draw_circle(Vector2(0, -4), 7, Color("#facc15"))
		draw_rect(Rect2(-6, -2, 12, 10), Color("#facc15"))
		draw_circle(Vector2(0, 3), 2, Color("#451a03"))
