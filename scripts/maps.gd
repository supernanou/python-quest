extends RefCounted
## Level layouts. Every map is 20 x 12 tiles.
##
##   #     wall
##   .     floor
##   P     where the player starts
##   a-e   computers (each one asks 2 exercises)
##   A-E   doors - each opens when the matching computer is finished
##   *     a </> code icon to collect
##   X     the exit portal (leads to the level quiz)
##
## Each map can be flipped with "variant": 0 = normal, 1 = mirrored,
## 2 = upside down, 3 = both. That gives lots of different-looking levels.

const ROOMS := [
	"####################",
	"#P....#......#.....#",
	"#.....#......#.....#",
	"#..a..A...b..B..c..#",
	"#.....#......#.....#",
	"#..*..#...*..#.....#",
	"################C###",
	"#.....#......#.....#",
	"#..X..E...e..D..d..#",
	"#.....#..*...#..*..#",
	"#.....#......#.....#",
	"####################",
]

const HALLS := [
	"####################",
	"#P........#........#",
	"#...a..*..A...b....#",
	"#.........#.....*..#",
	"###############B####",
	"#..*......#........#",
	"#...d.....C...c....#",
	"#.........#........#",
	"####D###############",
	"#..*...e..E........#",
	"#.........#....X...#",
	"####################",
]


static func get_map(map_name: String, variant: int) -> Array:
	var rows: Array = (HALLS if map_name == "halls" else ROOMS).duplicate()
	if variant & 1:
		rows = rows.map(func(row: String) -> String: return row.reverse())
	if variant & 2:
		rows.reverse()
	return rows
