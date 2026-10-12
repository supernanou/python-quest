extends RefCounted
## Read-aloud using the computer's own voices (English or Greek).
## Needs "audio/general/text_to_speech" switched on in project.godot.

const Lang = preload("res://scripts/lang.gd")

## Read-aloud is switched OFF for now: every "Read aloud" button is hidden.
## Change this to true to bring it back.
const READ_ALOUD_ON := false

## Nice, clear voices to prefer (macOS names). Funny novelty voices are skipped.
const PREFERRED := {
	"en": ["Samantha", "Karen", "Daniel", "Moira", "Tessa", "Serena", "Alex"],
	"el": ["Melina"],
}
const NOVELTY := ["Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos", "Good News",
	"Jester", "Organ", "Superstar", "Trinoids", "Whisper", "Wobble", "Zarvox", "Junior", "Ralph", "Fred", "Kathy"]


static func enabled() -> bool:
	return ProjectSettings.get_setting("audio/general/text_to_speech", false)


## True when there is a voice for the current language.
static func available() -> bool:
	return READ_ALOUD_ON and enabled() and _voice() != ""


static func say(text: String) -> void:
	if not READ_ALOUD_ON:
		return
	var voice := _voice()
	if voice == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(_tidy(text), voice, 80, 1.0, 0.9)


static func stop() -> void:
	if enabled():
		DisplayServer.tts_stop()


static func _voice() -> String:
	if not enabled():
		return ""
	var language := Lang.current()
	var voices := DisplayServer.tts_get_voices()
	var matching := []
	for v in voices:
		if str(v.get("language", "")).begins_with(language):
			matching.append(v)
	for wanted in PREFERRED.get(language, []):
		for v in matching:
			if str(v.get("name", "")).begins_with(wanted):
				return v["id"]
	for v in matching:
		if not str(v.get("name", "")) in NOVELTY:
			return v["id"]
	return ""


## Make text sound right: say "code icons" instead of reading out "</>".
static func _tidy(text: String) -> String:
	var icons := "εικονίδια κώδικα" if Lang.current() == "el" else "code icons"
	return text.replace("</>", icons).replace(">>>", "").replace("_", " ")
