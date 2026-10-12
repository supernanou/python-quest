extends RefCounted
## The courses in the game. Each level lives in its own file under scripts/courses/.
## All levels are kept in one list: Beginner levels first, then Intermediate.
## Passing the last quiz of a course unlocks the first level of the next one.

const COURSES := [
	{
		"id": "beginner",
		"name": "Beginner Course",
		"short": "Beginner",
		"files": [
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
		],
	},
	{
		"id": "intermediate",
		"name": "Intermediate Course",
		"short": "Intermediate",
		"files": [
			"res://scripts/courses/intermediate/level_01.gd",
			"res://scripts/courses/intermediate/level_02.gd",
			"res://scripts/courses/intermediate/level_03.gd",
			"res://scripts/courses/intermediate/level_04.gd",
			"res://scripts/courses/intermediate/level_05.gd",
			"res://scripts/courses/intermediate/level_06.gd",
			"res://scripts/courses/intermediate/level_07.gd",
			"res://scripts/courses/intermediate/level_08.gd",
			"res://scripts/courses/intermediate/level_09.gd",
			"res://scripts/courses/intermediate/level_10.gd",
		],
	},
]


## Every level of every course, in order. Each level gets:
##   "course"  - index into COURSES
##   "number"  - 1..10 inside its course
##   exercise "id"s like "13:7" (level 14 overall, exercise 8) for progress tracking
static func all() -> Array:
	var levels := []
	for course_index in COURSES.size():
		var files: Array = COURSES[course_index]["files"]
		for n in files.size():
			var level: Dictionary = load(files[n]).LEVEL.duplicate(true)
			var index := levels.size()
			level["course"] = course_index
			level["number"] = n + 1
			for i in level["exercises"].size():
				level["exercises"][i]["id"] = "%d:%d" % [index, i]
			levels.append(level)
	return levels


## First and last level index (in the all() list) of a course.
static func course_range(course_index: int) -> Array:
	var start := 0
	for c in course_index:
		start += COURSES[c]["files"].size()
	return [start, start + COURSES[course_index]["files"].size() - 1]


static func beginner() -> Array:
	return all().slice(0, COURSES[0]["files"].size())
