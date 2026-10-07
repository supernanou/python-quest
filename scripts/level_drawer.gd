extends Node2D
## Draws the floor and walls of a stage from its text map.

var map: Array = []
var tile := 48
var floor_a := Color("#7ec850")
var floor_b := Color("#76bf49")
var wall := Color("#6b7280")


func _draw() -> void:
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			var r := Rect2(x * tile, y * tile, tile, tile)
			if row[x] == "#":
				draw_rect(r, wall)
				draw_rect(Rect2(r.position, Vector2(tile, tile * 0.3)), wall.lightened(0.25))
				draw_rect(r, wall.darkened(0.35), false, 2.0)
			else:
				draw_rect(r, floor_a if (x + y) % 2 == 0 else floor_b)
