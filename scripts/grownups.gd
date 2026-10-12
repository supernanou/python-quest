extends Control
## The grown-ups area (behind the grown-up PIN): progress report, break reminder
## settings, backup & restore, removed players, unlocking levels and changing the PIN.

signal closed
signal players_changed
signal break_settings_changed
signal change_pin_requested

const Settings = preload("res://scripts/settings.gd")
const Profiles = preload("res://scripts/profiles.gd")
const Report = preload("res://scripts/report.gd")

const DARK := Color("#0f172a")
const MUTED := Color("#475569")

var levels: Array = []
var save
var header_name: Label
var nav_buttons := {}
var pages := {}
var report: Report
var break_toggle: CheckButton
var play_buttons := {}
var length_buttons := {}
var backup_status: Label
var backup_button: Button
var removed_list: VBoxContainer
var unlock_button: Button
var unlock_armed := false
var pin_status: Label
var file_dialog: FileDialog
var dialog_mode := ""
var delete_armed := ""


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)
	var bg := ColorRect.new()
	bg.color = Color("#f1f5f9")
	bg.size = size
	add_child(bg)
	var bar := ColorRect.new()
	bar.color = DARK
	bar.size = Vector2(size.x, 64)
	add_child(bar)
	var title := _label("Grown-ups", 26, Color("#facc15"))
	title.position = Vector2(20, 14)
	add_child(title)
	header_name = _label("", 18, Color("#cbd5e1"))
	header_name.position = Vector2(200, 22)
	add_child(header_name)
	var close_button := _button("Close (Esc)", Color("#334155"), _close)
	close_button.position = Vector2(size.x - 150, 12)
	close_button.size = Vector2(134, 40)
	add_child(close_button)

	var nav := VBoxContainer.new()
	nav.position = Vector2(16, 80)
	nav.size = Vector2(200, 540)
	nav.add_theme_constant_override("separation", 8)
	add_child(nav)
	for entry in [["report", "Progress report"], ["breaks", "Break reminder"], ["backup", "Backup & restore"],
			["removed", "Removed players"], ["more", "Levels & PIN"]]:
		var b := _button(entry[1], Color("#1e3a5f"), _show_page.bind(entry[0]))
		b.custom_minimum_size = Vector2(200, 48)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(b)
		nav_buttons[entry[0]] = b

	# --- Progress report
	report = Report.new()
	_add_page("report", report)

	# --- Break reminder
	var breaks := _page_box("breaks", "Break reminder")
	breaks.add_child(_text("After a while the game pauses and suggests a short break: stretching, a glass of water, resting the eyes."))
	break_toggle = CheckButton.new()
	break_toggle.text = "Remind kids to take breaks"
	break_toggle.add_theme_font_size_override("font_size", 17)
	break_toggle.add_theme_color_override("font_color", DARK)
	break_toggle.add_theme_color_override("font_pressed_color", DARK)
	break_toggle.add_theme_color_override("font_hover_color", DARK)
	break_toggle.add_theme_color_override("font_hover_pressed_color", DARK)
	break_toggle.toggled.connect(func(on: bool) -> void:
		Settings.set_value("break_on", on)
		break_settings_changed.emit()
		_refresh_breaks())
	breaks.add_child(break_toggle)
	breaks.add_child(_label("Remind after", 16, MUTED))
	breaks.add_child(_choice_row(Settings.BREAK_PLAY_CHOICES, play_buttons, "break_play_minutes"))
	breaks.add_child(_label("Break length", 16, MUTED))
	breaks.add_child(_choice_row(Settings.BREAK_LENGTH_CHOICES, length_buttons, "break_length_minutes"))

	# --- Backup & restore
	var backup := _page_box("backup", "Backup & restore")
	backup.add_child(_text("Save a player's progress to a file - for example on a USB stick or in a cloud folder. You can restore it on this computer or another one. Restoring the same player again updates their progress."))
	backup_button = _button("", Color("#16a34a"), _ask_export)
	backup_button.custom_minimum_size = Vector2(0, 48)
	backup.add_child(backup_button)
	var restore_button := _button("Restore from a backup file...", Color("#0369a1"), _ask_import)
	restore_button.custom_minimum_size = Vector2(0, 48)
	backup.add_child(restore_button)
	backup_status = _text("")
	backup.add_child(backup_status)

	# --- Removed players
	var removed := _page_box("removed", "Removed players")
	removed.add_child(_text("Players removed on the \"Who's playing?\" screen are kept here, so they can be brought back."))
	removed_list = VBoxContainer.new()
	removed_list.add_theme_constant_override("separation", 8)
	removed.add_child(removed_list)

	# --- Levels & PIN
	var more := _page_box("more", "Levels & PIN")
	more.add_child(_text("Useful for teachers: unlock every level for this player, so they can try any level without finishing the ones before."))
	unlock_button = _button("", Color("#7c3aed"), _on_unlock)
	unlock_button.custom_minimum_size = Vector2(0, 48)
	more.add_child(unlock_button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	more.add_child(spacer)
	more.add_child(_text("The grown-up PIN protects removing players and this grown-ups area."))
	more.add_child(_button("Change the grown-up PIN", Color("#334155"), func() -> void: change_pin_requested.emit()))
	pin_status = _text("")
	more.add_child(pin_status)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.%s ; Code Quest backup" % Profiles.BACKUP_EXTENSION])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)


func open(p_levels: Array, p_save) -> void:
	levels = p_levels
	save = p_save
	var name: String = save.look.get("name", "")
	header_name.text = tr("Player: %s") % (name if name != "" else tr("Player"))
	backup_button.text = tr("Save a backup of %s...") % (name if name != "" else tr("Player"))
	backup_status.text = ""
	pin_status.text = ""
	unlock_armed = false
	delete_armed = ""
	_show_page("report")
	visible = true


func _close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _show_page(page: String) -> void:
	for key in pages:
		pages[key].visible = key == page
		var on: bool = key == page
		nav_buttons[key].add_theme_stylebox_override("normal", _box(Color("#0369a1") if on else Color("#1e3a5f"), Color.WHITE if on else Color("#334155"), 2, 10, 10))
	match page:
		"report":
			report.show_for(levels, save)
		"breaks":
			_refresh_breaks()
		"removed":
			_refresh_removed()
		"more":
			_refresh_unlock()


# ---------------------------------------------------------------- break reminder

func _choice_row(choices: Array, store: Dictionary, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for minutes in choices:
		var b := _button("", Color("#1e3a5f"), func() -> void:
			Settings.set_value(key, minutes)
			break_settings_changed.emit()
			_refresh_breaks())
		b.custom_minimum_size = Vector2(90, 42)
		row.add_child(b)
		store[minutes] = b
	return row


func _refresh_breaks() -> void:
	var on := Settings.break_on()
	break_toggle.set_pressed_no_signal(on)
	for store in [[play_buttons, Settings.break_play_minutes()], [length_buttons, Settings.break_length_minutes()]]:
		for minutes in store[0]:
			var b: Button = store[0][minutes]
			b.text = tr("%d min") % minutes
			b.disabled = not on
			var selected: bool = minutes == store[1]
			var style := _box(Color("#16a34a") if selected else Color("#cbd5e1"), Color.WHITE if selected else Color("#94a3b8"), 2, 10, 6)
			for state in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(state, style)
			b.add_theme_color_override("font_color", Color.WHITE if selected else DARK)
			b.add_theme_color_override("font_disabled_color", Color("#94a3b8"))


# ---------------------------------------------------------------- backup & restore

func _ask_export() -> void:
	dialog_mode = "export"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = tr("Save backup")
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var name: String = save.look.get("name", "player")
	file_dialog.current_file = "%s.%s" % [name if name != "" else "player", Profiles.BACKUP_EXTENSION]
	file_dialog.popup_centered_ratio(0.7)


func _ask_import() -> void:
	dialog_mode = "import"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = tr("Restore from a backup file")
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	if dialog_mode == "export":
		export_to(path)
	else:
		import_from(path)


func export_to(path: String) -> void:
	if not path.ends_with("." + Profiles.BACKUP_EXTENSION):
		path += "." + Profiles.BACKUP_EXTENSION
	if Profiles.export_to(save, path):
		_status(tr("Backup saved: %s") % path, Color("#15803d"))
	else:
		_status(tr("Sorry, the backup could not be saved there."), Color("#dc2626"))


func import_from(path: String) -> void:
	var result := Profiles.import_from(path)
	if not result.get("ok", false):
		if result.get("full", false):
			_status(tr("There are already 8 players. Remove one first."), Color("#dc2626"))
		else:
			_status(tr("Sorry, that file isn't a Code Quest backup."), Color("#dc2626"))
		return
	var who: String = result.get("name", "")
	if result.get("replaced", false):
		_status(tr("%s's progress was restored from the backup.") % who, Color("#15803d"))
	else:
		_status(tr("%s was added as a new player.") % who, Color("#15803d"))
	players_changed.emit()


func _status(text: String, color: Color) -> void:
	backup_status.text = text
	backup_status.add_theme_color_override("font_color", color)


# ---------------------------------------------------------------- removed players

func _refresh_removed() -> void:
	for child in removed_list.get_children():
		child.queue_free()
	var players := Profiles.removed_players()
	if players.is_empty():
		removed_list.add_child(_text(tr("No removed players.")))
		return
	for player in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name: String = player.look.get("name", "")
		var label := _label(name if name != "" else tr("Player"), 18, DARK)
		label.custom_minimum_size = Vector2(220, 0)
		row.add_child(label)
		row.add_child(_button("Restore", Color("#16a34a"), func() -> void:
			if Profiles.all().size() >= Profiles.MAX_PLAYERS:
				return
			Profiles.restore(player)
			players_changed.emit()
			_refresh_removed()))
		var sure: bool = delete_armed == player.path
		row.add_child(_button("Sure? Click again" if sure else "Delete forever", Color("#dc2626") if sure else Color("#64748b"), func() -> void:
			if delete_armed == player.path:
				Profiles.delete_forever(player)
				delete_armed = ""
			else:
				delete_armed = player.path
			_refresh_removed()))
		removed_list.add_child(row)


# ---------------------------------------------------------------- levels & PIN

func _refresh_unlock() -> void:
	var name: String = save.look.get("name", "")
	if save.unlocked >= levels.size():
		unlock_button.text = tr("All levels are unlocked for %s") % name
		unlock_button.disabled = true
	else:
		unlock_button.disabled = false
		unlock_button.text = tr("Sure? Click again") if unlock_armed else tr("Unlock all levels for %s") % name


func _on_unlock() -> void:
	if not unlock_armed:
		unlock_armed = true
	else:
		unlock_armed = false
		save.unlocked = levels.size()
		save.save_file()
	_refresh_unlock()


func show_pin_changed() -> void:
	pin_status.text = tr("The grown-up PIN was changed.")
	pin_status.add_theme_color_override("font_color", Color("#15803d"))


# ---------------------------------------------------------------- building blocks

func _add_page(key: String, node: Control) -> void:
	node.position = Vector2(236, 80)
	node.size = Vector2(708, 544)
	node.visible = false
	add_child(node)
	pages[key] = node


func _page_box(key: String, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_add_page(key, v)
	v.add_child(_label(title, 24, DARK))
	return v


func _text(text: String) -> Label:
	var label := _label(text, 16, MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(700, 0)
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.25), 2, 10, 10))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), Color.WHITE, 2, 10, 10))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), Color.WHITE, 2, 10, 10))
	button.add_theme_stylebox_override("disabled", _box(color.lightened(0.4), color.lightened(0.4), 2, 10, 10))
	button.pressed.connect(action)
	return button


func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
