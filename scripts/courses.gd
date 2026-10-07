extends RefCounted
## The courses in the game. Each level lives in its own file under scripts/courses/.
## To add an Intermediate course later, make a folder with level files and a new list here.

const BEGINNER_FILES := [
	"res://scripts/courses/beginner/level_01.gd",
	"res://scripts/courses/beginner/level_02.gd",
	"res://scripts/courses/beginner/level_03.gd",
	"res://scripts/courses/beginner/level_04.gd",
	"res://scripts/courses/beginner/level_05.gd",
	"res://scripts/courses/beginner/level_06.gd",
	"res://scripts/courses/beginner/level_07.gd",
	"res://scripts/courses/beginner/level_08.gd",
	"res://scripts/courses/beginner/level_09.gd",
	"res://scripts/courses/beginner/level_10.gd",
]


static func beginner() -> Array:
	var levels := []
	for level_index in BEGINNER_FILES.size():
		var level: Dictionary = load(BEGINNER_FILES[level_index]).LEVEL.duplicate(true)
		# Give every exercise an id like "3:7" (level 4, exercise 8) for progress tracking
		for i in level["exercises"].size():
			level["exercises"][i]["id"] = "%d:%d" % [level_index, i]
		levels.append(level)
	return levels
