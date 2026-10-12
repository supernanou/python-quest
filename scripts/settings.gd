extends RefCounted
## Grown-up settings shared by every player on this computer:
## the grown-up PIN and the break reminder. Stored in the same file as the language.

const Lang = preload("res://scripts/lang.gd")

const BREAK_PLAY_CHOICES := [15, 20, 30, 45, 60]  # minutes of play before a break
const BREAK_LENGTH_CHOICES := [3, 5, 10]  # minutes of break


static func get_value(key: String, default):
	var config := ConfigFile.new()
	config.load(Lang.settings_file)
	return config.get_value("grownups", key, default)


static func set_value(key: String, value) -> void:
	var config := ConfigFile.new()
	config.load(Lang.settings_file)
	config.set_value("grownups", key, value)
	config.save(Lang.settings_file)


# ---- grown-up PIN (stored scrambled, not as the plain number)

static func has_pin() -> bool:
	return get_value("pin_hash", "") != ""


static func check_pin(pin: String) -> bool:
	return has_pin() and _scramble(pin) == get_value("pin_hash", "")


static func set_pin(pin: String) -> void:
	set_value("pin_hash", _scramble(pin))


static func _scramble(pin: String) -> String:
	return ("code-quest-pin:" + pin).sha256_text()


# ---- break reminder

static func break_on() -> bool:
	return get_value("break_on", true)


static func break_play_minutes() -> int:
	return get_value("break_play_minutes", 30)


static func break_length_minutes() -> int:
	return get_value("break_length_minutes", 5)
