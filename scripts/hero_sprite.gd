extends Node2D
## Draws the hero from a "look": boy/girl, skin, hair, outfit, an extra (bought
## with </> icons) and "About me" choices like a wheelchair or hearing aids (free).
## Used by the player in the game and by every hero preview on the menus.

const DEFAULT_LOOK := {
	"name": "",
	"style": "boy",
	"skin": "#f5c9a0",
	"hair": "#6b3e26",
	"outfit": "#3776ab",
	"item": "none",
	"aids": [],
}

## Fun extras. They are bought with </> code icons.
const ITEMS := [
	{"id": "none", "name": "None", "price": 0},
	{"id": "cap", "name": "Cap", "price": 3},
	{"id": "sunglasses", "name": "Sunglasses", "price": 5},
	{"id": "headphones", "name": "Phones", "price": 8},
	{"id": "crown", "name": "Crown", "price": 12},
	{"id": "wizard", "name": "Wizard", "price": 15},
]

## "About me": things kids use every day, so every child can make a hero like them.
## Always free. Pick as many as you like.
const AIDS := [
	{"id": "wheelchair", "name": "Wheelchair"},
	{"id": "crutches", "name": "Crutches"},
	{"id": "leg_braces", "name": "Leg braces"},
	{"id": "prosthetic_leg", "name": "Prosthetic leg"},
	{"id": "prosthetic_arm", "name": "Prosthetic arm"},
	{"id": "glasses", "name": "Glasses"},
	{"id": "eye_patch", "name": "Eye patch"},
	{"id": "hearing_aids", "name": "Hearing aids"},
	{"id": "cochlear_implant", "name": "Cochlear implant"},
	{"id": "ear_defenders", "name": "Ear defenders"},
	{"id": "insulin_pump", "name": "Insulin pump"},
	{"id": "service_dog", "name": "Service dog"},
]
## Choices that can't go together (picking one removes the other).
const AID_CONFLICTS := {"wheelchair": ["crutches"], "crutches": ["wheelchair"]}

const SHOE := Color("#1e293b")
const METAL := Color("#9ca3af")
const DARK_METAL := Color("#374151")

var look: Dictionary = DEFAULT_LOOK.duplicate(true)
var facing := Vector2.DOWN
var walk_time := 0.0


func has_aid(id: String) -> bool:
	if id == "glasses" and look.get("item", "") == "glasses":
		return true  # heroes saved before glasses moved to "About me"
	return id in look.get("aids", [])


func _draw() -> void:
	var skin := Color(look.get("skin", DEFAULT_LOOK["skin"]))
	var hair := Color(look.get("hair", DEFAULT_LOOK["hair"]))
	var outfit := Color(look.get("outfit", DEFAULT_LOOK["outfit"]))
	var is_girl: bool = look.get("style", "boy") == "girl"
	var facing_away := facing.y < -0.5
	var item: String = look.get("item", "none")
	var in_chair := has_aid("wheelchair")

	# Sitting in a wheelchair: no bouncing steps, the wheels turn instead
	var bob := 0.0 if in_chair else -absf(sin(walk_time)) * 3.0
	var step := 0.0 if in_chair else sin(walk_time) * 4.0
	var head := Vector2(0, -12 + bob)
	var body_edge := 9.5 if is_girl else 11.0

	if has_aid("service_dog"):
		_draw_dog(in_chair)

	# Shadow
	draw_set_transform(Vector2(0, 18), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 19.0 if in_chair else 14.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if in_chair:
		draw_rect(Rect2(-12, -9, 24, 14), Color("#475569"))  # back rest
		draw_rect(Rect2(-12, -9, 24, 14), Color("#334155"), false, 1.5)

	# Long hair goes behind the body
	if is_girl:
		draw_circle(head + Vector2(0, 1), 12.5, hair)
		draw_rect(Rect2(head.x - 12.5, head.y, 25, 15), hair)

	_draw_legs(skin, outfit, is_girl, bob, step, in_chair)

	# Body
	if is_girl:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9, -4 + bob), Vector2(9, -4 + bob),
			Vector2(13, 12 + bob), Vector2(-13, 12 + bob),
		]), outfit)
		draw_rect(Rect2(-10, 2 + bob, 20, 3), Color("#ffd43b"))
	else:
		draw_rect(Rect2(-11, -4 + bob, 22, 14), outfit)
		draw_rect(Rect2(-11, 3 + bob, 22, 3), Color("#ffd43b"))

	if has_aid("insulin_pump"):
		var pump := Vector2(4, 4 + bob)
		draw_rect(Rect2(pump, Vector2(6, 5)), Color("#e5e7eb"))
		draw_rect(Rect2(pump, Vector2(6, 5)), Color("#6b7280"), false, 0.8)
		draw_rect(Rect2(pump + Vector2(1.2, 1), Vector2(3.6, 1.6)), Color("#38bdf8"))

	if in_chair:
		_draw_wheelchair()

	_draw_arms(skin, outfit, body_edge, bob, step, in_chair)

	# Head and hair
	draw_circle(head, 11, skin)
	if facing_away:
		draw_circle(head, 11, hair)
	else:
		draw_arc(head, 11, PI, TAU, 16, hair, 6.0)
		if not is_girl:
			draw_circle(head + Vector2(-5, -8), 4, hair)
			draw_circle(head + Vector2(1, -9), 4, hair)

	if is_girl and not item in ["cap", "crown", "wizard", "headphones"] and not has_aid("ear_defenders"):
		var bow := head + Vector2(8, -9)
		var bow_color := Color("#f472b6")
		draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(-6, -4), bow + Vector2(-6, 4)]), bow_color)
		draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(6, -4), bow + Vector2(6, 4)]), bow_color)
		draw_circle(bow, 2, bow_color.darkened(0.2))

	# Face looks the way the hero is walking
	var look_dir := Vector2(facing.x * 3.0, maxf(facing.y, 0.0) * 2.0)
	if not facing_away:
		for side in [-1, 1]:
			var eye: Vector2 = head + Vector2(4 * side, 1) + look_dir
			draw_circle(eye, 2.2, Color.BLACK)
			draw_circle(eye + Vector2(-0.6, -0.7), 0.7, Color.WHITE)
		draw_circle(head + Vector2(-6, 6) + look_dir, 2, Color(1, 0.4, 0.4, 0.35))
		draw_circle(head + Vector2(6, 6) + look_dir, 2, Color(1, 0.4, 0.4, 0.35))

	_draw_head_aids(head, look_dir, facing_away)
	if not (item == "headphones" and has_aid("ear_defenders")):
		_draw_item(item, head, facing_away)


func _draw_legs(skin: Color, outfit: Color, is_girl: bool, bob: float, step: float, in_chair: bool) -> void:
	var leg_color := skin if is_girl else outfit.darkened(0.45)
	var top := 10.0 + bob
	for side in [-1, 1]:
		var x: float = -9.0 if side == -1 else 2.0
		var swing: float = step * 0.5 * side
		var prosthetic: bool = side == 1 and has_aid("prosthetic_leg")
		if in_chair:
			# Knees forward, feet resting on the footrest
			draw_rect(Rect2(x, top, 7, 4), leg_color)
			if prosthetic:
				draw_rect(Rect2(x + 2.5, top + 4, 2, 6), METAL)
			else:
				draw_rect(Rect2(x, 14, 7, 4), SHOE)
			continue
		if prosthetic:
			# Socket, metal post and a curved running-blade foot
			draw_rect(Rect2(x + 0.5, top - 1 - swing, 6, 5), Color("#e5e7eb"))
			draw_rect(Rect2(x + 0.5, top - 1 - swing, 6, 5), DARK_METAL, false, 0.8)
			draw_rect(Rect2(x + 2.2, top + 4 - swing, 2.6, 3.5), METAL)
			draw_polyline(PackedVector2Array([
				Vector2(x + 3.5, top + 7 - swing), Vector2(x + 2.6, 15.5 - swing), Vector2(x + 3.8, 18.3 - swing),
				Vector2(x + 9, 18.3 - swing),
			]), DARK_METAL, 2.8)
			continue
		draw_rect(Rect2(x, top - swing, 7, 5), leg_color)
		draw_rect(Rect2(x, 14 - swing, 7, 4.5), SHOE)
		if has_aid("leg_braces"):
			draw_rect(Rect2(x - 0.5, top + 0.5 - swing, 8, 7.5), Color(0.65, 0.95, 0.99, 0.85))
			draw_line(Vector2(x - 0.5, top + 2.5 - swing), Vector2(x + 7.5, top + 2.5 - swing), Color("#0e7490"), 1.2)


func _draw_arms(skin: Color, outfit: Color, edge: float, bob: float, step: float, in_chair: bool) -> void:
	for side in [-1, 1]:
		var x: float = -edge - 3.5 if side == -1 else edge
		var swing: float = 0.0 if in_chair else step * 0.35 * side
		var top := -3.0 + bob
		if in_chair:
			top += 2.0  # hands down on the wheels
		draw_rect(Rect2(x, top, 3.5, 5), outfit.darkened(0.1))  # sleeve
		var prosthetic: bool = side == 1 and has_aid("prosthetic_arm")
		var hand := Vector2(x + 1.75, top + 11 + swing)
		if prosthetic:
			# Light metal forearm with a hook hand
			draw_rect(Rect2(x, top + 5, 3.5, 5 + swing), Color("#d1d5db"))
			draw_rect(Rect2(x, top + 5, 3.5, 5 + swing), DARK_METAL, false, 0.8)
			draw_line(Vector2(x, top + 6.5), Vector2(x + 3.5, top + 6.5), DARK_METAL, 0.8)
			draw_arc(hand + Vector2(0, 0.6), 2.3, 0.2, PI - 0.2, 10, DARK_METAL, 1.6)
			draw_line(hand + Vector2(0, -1.5), hand + Vector2(0, 0.4), DARK_METAL, 1.4)
		else:
			draw_rect(Rect2(x, top + 5, 3.5, 5 + swing), skin)
			draw_circle(hand, 2.0, skin)
		if has_aid("crutches"):
			var foot := Vector2(x + 1.75 + side * 3.0 - swing * 0.6, 19)
			var cuff := Vector2(x + 1.75 + side * 0.5, top + 4)
			draw_line(cuff, foot, Color("#94a3b8"), 1.7)
			draw_arc(cuff, 2.6, PI, TAU, 8, Color("#64748b"), 1.4)
			draw_line(hand, hand + Vector2(side * 2.5, 0), Color("#64748b"), 1.6)
			draw_circle(foot, 1.2, DARK_METAL)


func _draw_wheelchair() -> void:
	var spin := walk_time * 1.5
	for side in [-1, 1]:
		var wheel := Vector2(14 * side, 8)
		draw_arc(wheel, 9.0, 0, TAU, 24, Color("#1f2937"), 2.6)
		draw_arc(wheel, 6.8, 0, TAU, 20, METAL, 1.0)  # push rim
		for i in 3:
			var a := spin + i * PI / 3.0
			draw_line(wheel - Vector2(cos(a), sin(a)) * 6.5, wheel + Vector2(cos(a), sin(a)) * 6.5, Color("#6b7280"), 0.8)
		draw_circle(wheel, 1.5, DARK_METAL)
		draw_circle(Vector2(9 * side, 18.5), 1.8, DARK_METAL)  # small front wheels
	draw_rect(Rect2(-10, 17.5, 20, 1.8), DARK_METAL)  # footrest


func _draw_head_aids(head: Vector2, look_dir: Vector2, facing_away: bool) -> void:
	if has_aid("hearing_aids"):
		for side in [-1, 1]:
			var aid: Vector2 = head + Vector2(11.2 * side, -1)
			draw_circle(aid, 2.3, Color("#f59e0b"))
			draw_line(aid + Vector2(0, 2), aid + Vector2(-side * 1.2, 4), Color("#f59e0b"), 1.2)
	if has_aid("cochlear_implant"):
		var magnet := head + Vector2(-9.5, -6)
		draw_line(magnet, head + Vector2(-11.5, 1), Color("#4338ca"), 1.0)
		draw_circle(magnet, 3.0, Color("#6366f1"))
		draw_circle(magnet, 1.3, Color("#c7d2fe"))
		draw_rect(Rect2(head + Vector2(-13, -1), Vector2(2.6, 5.5)), Color("#6366f1"))
	if has_aid("ear_defenders"):
		var band := Color("#0f766e")
		draw_arc(head, 13.5, PI, TAU, 20, band, 3.0)
		for side in [-1, 1]:
			draw_rect(Rect2(head + Vector2(side * 12.5 - 3.5, -4.5), Vector2(7, 9)), Color("#14b8a6"))
			draw_rect(Rect2(head + Vector2(side * 12.5 - 3.5, -4.5), Vector2(7, 9)), band, false, 1.0)
	if facing_away:
		return
	if has_aid("eye_patch"):
		var patch := head + Vector2(-4, 1) + look_dir
		draw_line(head + Vector2(-10.5, -3), head + Vector2(10.5, -5), Color("#1f2937"), 0.9)
		draw_circle(patch, 3.4, Color("#ec4899"))
		draw_circle(patch + Vector2(-0.8, -0.8), 0.9, Color(1, 1, 1, 0.5))
	if has_aid("glasses"):
		var frame := Color("#111827")
		draw_arc(head + Vector2(-4, 1) + look_dir, 4.0, 0, TAU, 16, frame, 1.5)
		draw_arc(head + Vector2(4, 1) + look_dir, 4.0, 0, TAU, 16, frame, 1.5)
		draw_line(head + Vector2(-0.5, 1) + look_dir, head + Vector2(0.5, 1) + look_dir, frame, 1.5)


func _draw_dog(in_chair: bool) -> void:
	var side := -1.0 if facing.x < -0.1 else 1.0
	var base := Vector2((30.0 if in_chair else 23.0) * side, 10)
	var fur := Color("#d4a373")
	var t := Time.get_ticks_msec() / 1000.0
	var trot := sin(walk_time) * 1.5
	# legs
	for lx in [-5.0, -2.0, 3.0, 6.0]:
		var leg_swing: float = trot if int(lx) % 2 == 0 else -trot
		draw_rect(Rect2(base + Vector2(lx * side - 0.8, 2 + leg_swing * 0.3), Vector2(1.8, 6)), fur.darkened(0.15))
	# tail wags
	var tail := base + Vector2(-8 * side, -2)
	draw_line(tail, tail + Vector2(-4 * side, -4 + sin(t * 12.0) * 2.0), fur.darkened(0.1), 1.8)
	# body with a blue vest
	draw_set_transform(base, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 8.5, fur)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(base + Vector2(-4, -4.5), Vector2(8, 6)), Color("#2563eb"))
	draw_rect(Rect2(base + Vector2(-1.2, -3.3), Vector2(2.4, 3.6)), Color.WHITE)
	draw_rect(Rect2(base + Vector2(-2.6, -2.2), Vector2(5.2, 1.4)), Color.WHITE)
	# head
	var dog_head := base + Vector2(8 * side, -5)
	draw_circle(dog_head, 4.6, fur)
	draw_circle(dog_head + Vector2(3.2 * side, 1.4), 2.2, fur.lightened(0.15))
	draw_circle(dog_head + Vector2(4.8 * side, 1.0), 0.9, Color.BLACK)  # nose
	draw_circle(dog_head + Vector2(1.2 * side, -1.0), 0.8, Color.BLACK)  # eye
	draw_colored_polygon(PackedVector2Array([
		dog_head + Vector2(-2.5 * side, -2.5), dog_head + Vector2(-0.5 * side, -3.5), dog_head + Vector2(-2 * side, 2.5),
	]), fur.darkened(0.3))  # ear


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
		"sunglasses":
			if not facing_away:
				var lens := Color("#111827")
				var look_x := facing.x * 3.0
				for side in [-1, 1]:
					var c: Vector2 = head + Vector2(4 * side + look_x, 1)
					draw_circle(c, 4.0, lens)
					draw_line(c + Vector2(-2, -1.5), c + Vector2(0, -2.5), Color(1, 1, 1, 0.6), 1.0)
				draw_line(head + Vector2(-0.5 + look_x, 0), head + Vector2(0.5 + look_x, 0), lens, 1.5)
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
