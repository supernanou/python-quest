extends RefCounted
## Players on this computer. Each one is a save file in the profiles folder.

const SaveData = preload("res://scripts/save_data.gd")
const MAX_PLAYERS := 8

static var folder := "user://profiles"
static var old_save_file := "user://hero.cfg"  # from before there were several players


static func all() -> Array:
	_move_old_save()
	DirAccess.make_dir_recursive_absolute(folder)
	var players := []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".cfg"):
			var save := SaveData.new()
			save.path = folder.path_join(file)
			save.load_file()
			players.append(save)
	players.sort_custom(func(a, b): return a.created < b.created)
	return players


static func create() -> SaveData:
	DirAccess.make_dir_recursive_absolute(folder)
	var save := SaveData.new()
	save.created = Time.get_unix_time_from_system()
	var n := 1
	while FileAccess.file_exists(folder.path_join("player_%d.cfg" % n)):
		n += 1
	save.path = folder.path_join("player_%d.cfg" % n)
	return save


static func remove(save: SaveData) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))


## The first version saved one hero in hero.cfg - turn it into player 1.
static func _move_old_save() -> void:
	if old_save_file == "" or not FileAccess.file_exists(old_save_file):
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var target := folder.path_join("player_1.cfg")
	if not FileAccess.file_exists(target):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(old_save_file), ProjectSettings.globalize_path(target))
	# Keep the old file as a backup instead of deleting it
	DirAccess.rename_absolute(ProjectSettings.globalize_path(old_save_file), ProjectSettings.globalize_path(old_save_file + ".backup"))
