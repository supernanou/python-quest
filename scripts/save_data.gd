extends RefCounted
## Everything the game remembers about ONE player: their hero, code icons,
## extras, level progress, how each exercise went, and Code Lab challenges.
## Each player has their own file in user://profiles/ (see profiles.gd).

const HeroSprite = preload("res://scripts/hero_sprite.gd")

var path := ""
var created := 0.0
var has_hero := false
var look: Dictionary = HeroSprite.DEFAULT_LOOK.duplicate()
var icons := 0
var owned_items: Array = ["none"]
var collected: Array = []  # ids of code icons already picked up, e.g. "3:5,7"
var unlocked := 1  # how many levels can be played
var quiz_scores := {}  # level index -> best quiz score
var quiz_attempts := {}  # level index -> how many times the quiz was taken
var stats := {}  # exercise id "level:number" -> {"tries", "hints", "solved"}
var lab_done: Array = []  # Code Lab challenges finished


func load_file() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	has_hero = config.has_section("hero")
	for key in look:
		look[key] = config.get_value("hero", key, look[key])
	created = config.get_value("profile", "created", created)
	icons = config.get_value("wallet", "icons", icons)
	owned_items = config.get_value("wallet", "owned_items", owned_items)
	collected = config.get_value("wallet", "collected", collected)
	unlocked = config.get_value("progress", "unlocked", unlocked)
	quiz_scores = config.get_value("progress", "quiz_scores", quiz_scores)
	quiz_attempts = config.get_value("progress", "quiz_attempts", quiz_attempts)
	stats = config.get_value("progress", "stats", stats)
	lab_done = config.get_value("progress", "lab_done", lab_done)


func save_file() -> void:
	var config := ConfigFile.new()
	for key in look:
		config.set_value("hero", key, look[key])
	config.set_value("profile", "created", created)
	config.set_value("wallet", "icons", icons)
	config.set_value("wallet", "owned_items", owned_items)
	config.set_value("wallet", "collected", collected)
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "quiz_scores", quiz_scores)
	config.set_value("progress", "quiz_attempts", quiz_attempts)
	config.set_value("progress", "stats", stats)
	config.set_value("progress", "lab_done", lab_done)
	config.save(path)


func is_done(level_index: int) -> bool:
	return quiz_scores.has(level_index)


func is_solved(exercise_id: String) -> bool:
	return stats.has(exercise_id) and stats[exercise_id].get("solved", false)


func solved_in_level(level_index: int) -> int:
	var count := 0
	for id in stats:
		if id.begins_with("%d:" % level_index) and stats[id].get("solved", false):
			count += 1
	return count


## Wrong answers and hints only count until the exercise is solved the first time.
func record_try(exercise_id: String) -> void:
	var s := _stat(exercise_id)
	if not s["solved"]:
		s["tries"] += 1
		save_file()


func record_hint(exercise_id: String) -> void:
	var s := _stat(exercise_id)
	if not s["solved"]:
		s["hints"] += 1
		save_file()


func record_solved(exercise_id: String) -> void:
	_stat(exercise_id)["solved"] = true
	save_file()


func _stat(exercise_id: String) -> Dictionary:
	if not stats.has(exercise_id):
		stats[exercise_id] = {"tries": 0, "hints": 0, "solved": false}
	return stats[exercise_id]
