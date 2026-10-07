extends RefCounted
## English / Ελληνικά.
##
## - Buttons, menus and messages use Godot's tr(): the Greek for every English
##   sentence is in scripts/i18n/greek_ui.gd.
## - Course content keeps its Greek right next to the English in each level file:
##   an exercise can have "el": {"title": ..., "lesson": ..., "question": ..., "hint": ...}.
## - Code is never translated - code is written in English everywhere.

const GreekUI = preload("res://scripts/i18n/greek_ui.gd")

static var settings_file := "user://settings.cfg"
static var _initialized := false


static func setup() -> void:
	if _initialized:
		return
	_initialized = true
	var greek := Translation.new()
	greek.locale = "el"
	for english in GreekUI.TEXT:
		greek.add_message(english, GreekUI.TEXT[english])
	TranslationServer.add_translation(greek)
	# First time: follow the computer's language. After that: what the player picked.
	var language := "el" if OS.get_locale_language() == "el" else "en"
	var config := ConfigFile.new()
	if config.load(settings_file) == OK:
		language = config.get_value("settings", "language", language)
	TranslationServer.set_locale(language)


static func current() -> String:
	return "el" if TranslationServer.get_locale().begins_with("el") else "en"


static func set_language(language: String) -> void:
	TranslationServer.set_locale(language)
	var config := ConfigFile.new()
	config.load(settings_file)
	config.set_value("settings", "language", language)
	config.save(settings_file)


## A field of an exercise / quiz question / level / challenge in the current language.
static func pick(item: Dictionary, key: String):
	if current() == "el" and item.has("el") and item["el"].has(key):
		return item["el"][key]
	return item.get(key)


## Accepted answers: English ones, plus Greek words like "τρία" or "τίποτα".
static func answers(item: Dictionary) -> Array:
	var list: Array = item["answers"].duplicate()
	if item.has("el"):
		list.append_array(item["el"].get("answers", []))
	return list


## Friendly messages for common wrong answers (same wrong answers, translated messages).
static func mistakes(item: Dictionary) -> Dictionary:
	var result: Dictionary = item.get("mistakes", {}).duplicate()
	if current() == "el" and item.has("el"):
		result.merge(item["el"].get("mistakes", {}), true)
	return result
