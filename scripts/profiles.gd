extends RefCounted
## Players on this computer. Each one is a save file in the profiles folder.
## Removed players go to a "removed" folder, so a grown-up can bring them back.
## A player can also be saved to a backup file and restored from it.

const SaveData = preload("res://scripts/save_data.gd")
const MAX_PLAYERS := 8
const BACKUP_EXTENSION := "codequest"

static var folder := "user://profiles"
static var old_save_file := "user://hero.cfg"  # from before there were several players


static func all() -> Array:
	_move_old_save()
	DirAccess.make_dir_recursive_absolute(folder)
	return _load_folder(folder)


static func create() -> SaveData:
	DirAccess.make_dir_recursive_absolute(folder)
	var save := SaveData.new()
	save.created = Time.get_unix_time_from_system()
	save.path = _free_path(folder)
	return save


## Moves the player to the "removed" list (nothing is deleted).
static func remove(save: SaveData) -> void:
	var removed := _removed_folder()
	DirAccess.make_dir_recursive_absolute(removed)
	DirAccess.rename_absolute(_abs(save.path), _abs(_free_path(removed)))


static func removed_players() -> Array:
	return _load_folder(_removed_folder())


static func restore(save: SaveData) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.rename_absolute(_abs(save.path), _abs(_free_path(folder)))


static func delete_forever(save: SaveData) -> void:
	DirAccess.remove_absolute(_abs(save.path))


## Writes the player's progress to a backup file (e.g. on a USB stick).
static func export_to(save: SaveData, file_path: String) -> bool:
	save.save_file()
	return DirAccess.copy_absolute(_abs(save.path), file_path) == OK


## Reads a backup file. If it's the same player as one already here (made at the
## same moment), their progress is replaced; otherwise a new player is added.
static func import_from(file_path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(file_path) != OK or not config.has_section("hero"):
		return {"ok": false}
	var created: float = config.get_value("profile", "created", 0.0)
	var target := ""
	if created > 0.0:
		for existing in all():
			if is_equal_approx(existing.created, created):
				target = existing.path
	var replaced := target != ""
	if not replaced:
		if all().size() >= MAX_PLAYERS:
			return {"ok": false, "full": true}
		target = create().path
	config.save(target)
	return {"ok": true, "name": config.get_value("hero", "name", ""), "replaced": replaced}


static func _load_folder(path: String) -> Array:
	var players := []
	if not DirAccess.dir_exists_absolute(_abs(path)):
		return players
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".cfg"):
			var save := SaveData.new()
			save.path = path.path_join(file)
			save.load_file()
			players.append(save)
	players.sort_custom(func(a, b): return a.created < b.created)
	return players


static func _removed_folder() -> String:
	return folder.path_join("removed")


static func _free_path(in_folder: String) -> String:
	var n := 1
	while FileAccess.file_exists(in_folder.path_join("player_%d.cfg" % n)):
		n += 1
	return in_folder.path_join("player_%d.cfg" % n)


static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


## The first version saved one hero in hero.cfg - turn it into player 1.
static func _move_old_save() -> void:
	if old_save_file == "" or not FileAccess.file_exists(old_save_file):
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var target := folder.path_join("player_1.cfg")
	if not FileAccess.file_exists(target):
		DirAccess.copy_absolute(_abs(old_save_file), _abs(target))
	# Keep the old file as a backup instead of deleting it
	DirAccess.rename_absolute(_abs(old_save_file), _abs(old_save_file + ".backup"))
