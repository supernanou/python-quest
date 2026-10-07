extends Node2D
## Draws the hero from a "look" (boy/girl, skin, hair, outfit).
## Used by the player in the game and by the preview in the character creator.

const DEFAULT_LOOK := {
	"name": "",
	"style": "boy",
	"skin": "#f5c9a0",
	"hair": "#6b3e26",
	"outfit": "#3776ab",
	"item": "none",
}

## Extras the hero can wear. They are bought with </> code icons.
const ITEMS := [
	{"id": "none", "name": "None", "price": 0},
	{"id": "cap", "name": "Cap", "price": 3},
	{"id": "glasses", "name": "Glasses", "price": 5},
	{"id": "headphones", "name": "Phones", "price": 8},
	{"id": "crown", "name": "Crown", "price": 12},
	{"id": "wizard", "name": "Wizard", "price": 15},
]

var look: Dictionary = DEFAULT_LOOK.duplicate()
var facing := Vector2.DOWN
var walk_time := 0.0


func _draw() -> void:
	var skin := Color(look.get("skin", DEFAULT_LOOK["skin"]))
	var hair := Color(look.get("hair", DEFAULT_LOOK["hair"]))
	var outfit := Color(look.get("outfit", DEFAULT_LOOK["outfit"]))
	var is_girl: bool = look.get("style", "boy") == "girl"
	var facing_away := facing.y < -0.5
	var item: String = look.get("item", "none")

	var bob := -absf(sin(walk_time)) * 3.0
	var step := sin(walk_time) * 4.0
	var head := Vector2(0, -12 + bob)

	# Shadow
	draw_set_transform(Vector2(0, 18), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Feet
	draw_rect(Rect2(-9, 12 + step * 0.5, 7, 6), Color("#1e293b"))
	draw_rect(Rect2(2, 12 - step * 0.5, 7, 6), Color("#1e293b"))

	# Long hair goes behind the body
	if is_girl:
		draw_circle(head + Vector2(0, 1), 12.5, hair)
		draw_rect(Rect2(head.x - 12.5, head.y, 25, 15), hair)

	# Body
	if is_girl:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9, -4 + bob), Vector2(9, -4 + bob),
			Vector2(14, 14 + bob), Vector2(-14, 14 + bob),
		]), outfit)
		draw_rect(Rect2(-10, 2 + bob, 20, 3), Color("#ffd43b"))
	else:
		draw_rect(Rect2(-11, -4 + bob, 22, 18), outfit)
		draw_rect(Rect2(-11, 6 + bob, 22, 4), Color("#ffd43b"))

	# Head and hair
	draw_circle(head, 11, skin)
	if facing_away:
		draw_circle(head, 11, hair)
	else:
		draw_arc(head, 11, PI, TAU, 16, hair, 6.0)
		if not is_girl:
			draw_circle(head + Vector2(-5, -8), 4, hair)
			draw_circle(head + Vector2(1, -9), 4, hair)

	if is_girl and not item in ["cap", "crown", "wizard", "headphones"]:
		var bow := head + Vector2(8, -9)
		var bow_color := Color("#f472b6")
		draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(-6, -4), bow + Vector2(-6, 4)]), bow_color)
		draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(6, -4), bow + Vector2(6, 4)]), bow_color)
		draw_circle(bow, 2, bow_color.darkened(0.2))

	# Face looks the way the hero is walking
	if not facing_away:
		var look_dir := Vector2(facing.x * 3.0, maxf(facing.y, 0.0) * 2.0)
		for side in [-1, 1]:
			var eye: Vector2 = head + Vector2(4 * side, 1) + look_dir
			draw_circle(eye, 2.2, Color.BLACK)
			draw_circle(eye + Vector2(-0.6, -0.7), 0.7, Color.WHITE)
		draw_circle(head + Vector2(-6, 6) + look_dir, 2, Color(1, 0.4, 0.4, 0.35))
		draw_circle(head + Vector2(6, 6) + look_dir, 2, Color(1, 0.4, 0.4, 0.35))

	_draw_item(item, head, facing_away)


func _draw_item(item: String, head: Vector2, facing_away: bool) -> void:
	match item:
		"cap":
			var cap := Color("#ef4444")
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + i * PI / 12.0
				dome.append(head + Vector2(0, -3) + Vector2(cos(a), sin(a)) * 12.0)
			draw_colored_polygon(dome, cap)
			if not facing_away:
				draw_rect(Rect2(head.x - 13, head.y - 5, 26, 3.5), cap.darkened(0.25))
		"glasses":
			if not facing_away:
				var frame := Color("#111827")
				var look_x := facing.x * 3.0
				draw_arc(head + Vector2(-4 + look_x, 1), 4.0, 0, TAU, 16, frame, 1.5)
				draw_arc(head + Vector2(4 + look_x, 1), 4.0, 0, TAU, 16, frame, 1.5)
				draw_line(head + Vector2(-0.5 + look_x, 1), head + Vector2(0.5 + look_x, 1), frame, 1.5)
		"headphones":
			draw_arc(head, 13.0, PI, TAU, 20, Color("#1f2937"), 3.0)
			draw_circle(head + Vector2(-12.5, 0), 4.5, Color("#ef4444"))
			draw_circle(head + Vector2(12.5, 0), 4.5, Color("#ef4444"))
		"crown":
			var gold := Color("#facc15")
			var y := head.y - 8
			draw_colored_polygon(PackedVector2Array([
				Vector2(-9, y), Vector2(-9, y - 9), Vector2(-4.5, y - 4), Vector2(0, y - 11),
				Vector2(4.5, y - 4), Vector2(9, y - 9), Vector2(9, y),
			]), gold)
			draw_circle(Vector2(0, y - 3), 1.8, Color("#ef4444"))
			draw_circle(Vector2(-5.5, y - 2.5), 1.4, Color("#38bdf8"))
			draw_circle(Vector2(5.5, y - 2.5), 1.4, Color("#22c55e"))
		"wizard":
			var purple := Color("#6d28d9")
			var base := head.y - 5
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12, base), Vector2(12, base), Vector2(3, base - 26),
			]), purple)
			draw_rect(Rect2(-14, base - 2, 28, 4), purple.darkened(0.3))
			draw_circle(Vector2(-2, base - 10), 1.6, Color("#facc15"))
			draw_circle(Vector2(3, base - 17), 1.2, Color("#facc15"))
