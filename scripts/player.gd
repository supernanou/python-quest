extends CharacterBody2D
## The hero the child walks around. Its looks come from the character creator.

const SPEED := 220.0
const HeroSprite = preload("res://scripts/hero_sprite.gd")

var frozen := false
var look: Dictionary = {}
var sprite: HeroSprite


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15
	shape.shape = circle
	add_child(shape)

	sprite = HeroSprite.new()
	if not look.is_empty():
		sprite.look = look
	add_child(sprite)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not frozen:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		sprite.facing = dir.normalized()
		sprite.walk_time += delta * 12.0
	else:
		sprite.walk_time = 0.0
	sprite.queue_redraw()
