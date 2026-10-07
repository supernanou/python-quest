extends Control
## "Create your hero" screen. Two tabs:
##   Look     - boy or girl, skin, and extras unlocked with </> code icons
##   Hair     - 10 hairstyles and hair colours
##   Clothes  - 10 outfits and colours (anyone can pick anything)
##   About me - wheelchair, hearing aids, glasses... so every child can make a hero
##              just like them. These are always free.

signal confirmed(look: Dictionary)
signal back

const HeroSprite = preload("res://scripts/hero_sprite.gd")
const BackButton = preload("res://scripts/back_button.gd")

const SKINS := ["#ffe0bd", "#f5c9a0", "#d8a378", "#a8724c", "#6e4630"]
const HAIRS := ["#2b1d14", "#6b3e26", "#c68642", "#f2d16b", "#e25822", "#7c3aed"]
const OUTFITS := ["#3776ab", "#ef4444", "#22c55e", "#f59e0b", "#ec4899", "#8b5cf6"]

var save  # SaveData: icons and owned items
var look: Dictionary = HeroSprite.DEFAULT_LOOK.duplicate(true)
var preview: HeroSprite
var name_edit: LineEdit
var name_tag: Label
var wallet_label: Label
var message_label: Label
var boy_button: Button
var girl_button: Button
var swatches := {}  # "skin" -> [[button, "#hex"], ...]
var item_buttons := {}  # "crown" -> button
var aid_buttons := {}  # "wheelchair" -> button
var look_page: VBoxContainer
var hair_page: VBoxContainer
var clothes_page: VBoxContainer
var me_page: VBoxContainer
var look_tab: Button
var hair_tab: Button
var clothes_tab: Button
var me_tab: Button
var style_buttons := {}  # "hair_style" / "clothes" -> {id: [button, mini hero]}


func _ready() -> void:
	visible = false
	size = Vector2(960, 640)

	var bg := ColorRect.new()
	bg.color = Color("#0f172a")
	bg.size = size
	add_child(bg)

	var title := _label("Create your hero!", 36, Color("#facc15"))
	title.position = Vector2(0, 24)
	title.size = Vector2(960, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	wallet_label = _label("", 22, Color("#38bdf8"))
	wallet_label.position = Vector2(size.x - 236, 36)
	wallet_label.size = Vector2(200, 30)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(wallet_label)

	# Left: big preview of the hero
	var stage := Panel.new()
	stage.position = Vector2(50, 100)
	stage.size = Vector2(320, 440)
	stage.add_theme_stylebox_override("panel", _box(Color("#7ec850"), Color("#38bdf8"), 3, 16))
	add_child(stage)

	preview = HeroSprite.new()
	preview.position = Vector2(210, 330)
	preview.scale = Vector2(6, 6)
	add_child(preview)

	name_tag = _label("", 28, Color.WHITE)
	name_tag.position = Vector2(50, 486)
	name_tag.size = Vector2(320, 40)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_tag)

	# Right: choices, one row each
	var v := VBoxContainer.new()
	v.position = Vector2(400, 100)
	v.size = Vector2(520, 440)
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.placeholder_text = "Type your name..."
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(func(_t: String) -> void: _confirm())
	_row(v, "Name").add_child(name_edit)

	# Tabs: Look | About me
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var tab_group := ButtonGroup.new()
	look_tab = _choice_button("Look", tab_group, func() -> void: _show_tab("look"))
	hair_tab = _choice_button("Hair", tab_group, func() -> void: _show_tab("hair"))
	clothes_tab = _choice_button("Clothes", tab_group, func() -> void: _show_tab("clothes"))
	me_tab = _choice_button("About me", tab_group, func() -> void: _show_tab("me"))
	for tab in [look_tab, hair_tab, clothes_tab, me_tab]:
		tab.custom_minimum_size = Vector2(0, 40)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 17)
		tabs.add_child(tab)

	look_page = VBoxContainer.new()
	look_page.add_theme_constant_override("separation", 10)
	look_page.custom_minimum_size = Vector2(0, 278)
	v.add_child(look_page)

	var group := ButtonGroup.new()
	boy_button = _choice_button("Boy", group, func() -> void: _set_value("style", "boy"))
	girl_button = _choice_button("Girl", group, func() -> void: _set_value("style", "girl"))
	var style_row := _row(look_page, "I am a")
	style_row.add_child(boy_button)
	style_row.add_child(girl_button)

	_swatch_row(look_page, "Skin", "skin", SKINS)

	# Hair: 10 styles + colour
	hair_page = _page(v)
	hair_page.add_child(_style_grid("hair_style", HeroSprite.HAIR_STYLES))
	_swatch_row(hair_page, "Colour", "hair", HAIRS)

	# Clothes: 10 outfits + colour
	clothes_page = _page(v)
	clothes_page.add_child(_style_grid("clothes", HeroSprite.CLOTHES))
	_swatch_row(clothes_page, "Colour", "outfit", OUTFITS)

	# "About me": free, pick as many as you like
	me_page = VBoxContainer.new()
	me_page.add_theme_constant_override("separation", 10)
	me_page.custom_minimum_size = Vector2(0, 278)
	me_page.visible = false
	v.add_child(me_page)
	var intro := _label("Make your hero just like you! Pick anything you use - you can choose more than one.", 16, Color("#cbd5e1"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	me_page.add_child(intro)
	var aid_grid := GridContainer.new()
	aid_grid.columns = 3
	aid_grid.add_theme_constant_override("h_separation", 8)
	aid_grid.add_theme_constant_override("v_separation", 8)
	me_page.add_child(aid_grid)
	for aid in HeroSprite.AIDS:
		var button := Button.new()
		button.text = aid["name"]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(166, 44)
		button.add_theme_font_size_override("font_size", 14)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.toggled.connect(_on_aid_toggled.bind(aid["id"]))
		aid_grid.add_child(button)
		aid_buttons[aid["id"]] = button

	var items_row := _row(look_page, "Extras")
	items_row.add_theme_constant_override("separation", 6)
	for item in HeroSprite.ITEMS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(68, 50)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_item_pressed.bind(item))
		items_row.add_child(button)
		item_buttons[item["id"]] = button

	message_label = _label("", 16, Color("#94a3b8"))
	message_label.custom_minimum_size = Vector2(0, 24)
	v.add_child(message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var surprise := _big_button("Surprise me!", Color("#7c3aed"))
	surprise.pressed.connect(_randomize)
	buttons.add_child(surprise)
	var start := _big_button("Let's go!  >", Color("#16a34a"))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_confirm)
	buttons.add_child(start)

	var back_button := BackButton.new()
	back_button.pressed.connect(_go_back)
	add_child(back_button)

	var help := _label("Collect </> icons in the levels to unlock extras!", 16, Color("#64748b"))
	help.position = Vector2(0, 596)
	help.size = Vector2(960, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(help)


func open(p_save) -> void:
	save = p_save
	look = HeroSprite.DEFAULT_LOOK.duplicate(true)
	look.merge(save.look.duplicate(true), true)
	if look["hair_style"] == "":
		look["hair_style"] = "long" if look["style"] == "girl" else "short"
	if look["clothes"] == "":
		look["clothes"] = "dress" if look["style"] == "girl" else "tshirt"
	_show_tab("look")
	name_edit.text = look["name"]
	message_label.text = ""
	_refresh()
	visible = true
	name_edit.call_deferred("grab_focus")
	name_edit.call_deferred("set_caret_column", name_edit.text.length())


func _process(delta: float) -> void:
	if visible:
		preview.walk_time += delta * 5.0
		preview.queue_redraw()


## Leave without saving changes.
func _go_back() -> void:
	visible = false
	back.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _confirm() -> void:
	look["name"] = name_edit.text.strip_edges()
	visible = false
	confirmed.emit(look.duplicate(true))


func _on_name_changed(text: String) -> void:
	look["name"] = text.strip_edges()
	_refresh()


func _show_tab(page: String) -> void:
	var pages := {"look": [look_page, look_tab], "hair": [hair_page, hair_tab], "clothes": [clothes_page, clothes_tab], "me": [me_page, me_tab]}
	for key in pages:
		pages[key][0].visible = key == page
		pages[key][1].set_pressed_no_signal(key == page)


func _page(parent: Container) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.custom_minimum_size = Vector2(0, 278)
	page.visible = false
	parent.add_child(page)
	return page


## A grid of 10 buttons, each showing a little hero with that hairstyle or outfit.
func _style_grid(key: String, styles: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	style_buttons[key] = {}
	for style in styles:
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 86)
		button.clip_contents = true
		button.tooltip_text = style["name"]
		button.pressed.connect(_set_value.bind(key, style["id"]))
		var mini := HeroSprite.new()
		if key == "hair_style":
			mini.scale = Vector2(2.7, 2.7)  # close-up of the head
			mini.position = Vector2(48, 44 + 12 * 2.7)
		else:
			mini.scale = Vector2(1.8, 1.8)  # the whole outfit
			mini.position = Vector2(48, 47)
		button.add_child(mini)
		grid.add_child(button)
		style_buttons[key][style["id"]] = [button, mini]
	return grid


func _on_aid_toggled(on: bool, id: String) -> void:
	var aids: Array = look["aids"]
	if on and not id in aids:
		aids.append(id)
		for other in HeroSprite.AID_CONFLICTS.get(id, []):
			aids.erase(other)
	elif not on:
		aids.erase(id)
	_refresh()


func _set_value(key: String, value: String) -> void:
	look[key] = value
	# Boy / Girl just picks a starting hairstyle and outfit - change them freely
	if key == "style":
		look["hair_style"] = "long" if value == "girl" else "short"
		look["clothes"] = "dress" if value == "girl" else "tshirt"
	_refresh()


func _on_item_pressed(item: Dictionary) -> void:
	var id: String = item["id"]
	if id in save.owned_items:
		look["item"] = id
		message_label.text = ""
	elif save.icons >= item["price"]:
		save.icons -= item["price"]
		save.owned_items.append(id)
		save.save_file()
		look["item"] = id
		_message(tr("You unlocked the %s!") % tr(item["name"]), Color("#4ade80"))
	else:
		_message(tr("You need %d more </> icons for the %s. Find them in the levels!") % [item["price"] - save.icons, tr(item["name"])], Color("#fbbf24"))
	_refresh()


func _randomize() -> void:
	look["style"] = ["boy", "girl"].pick_random()
	look["skin"] = SKINS.pick_random()
	look["hair"] = HAIRS.pick_random()
	look["outfit"] = OUTFITS.pick_random()
	look["hair_style"] = HeroSprite.HAIR_STYLES.pick_random()["id"]
	look["clothes"] = HeroSprite.CLOTHES.pick_random()["id"]
	_refresh()


func _refresh() -> void:
	preview.look = look
	preview.queue_redraw()
	# Zoom out a little when the service dog is there, so everyone fits on the stage
	var with_dog: bool = "service_dog" in look["aids"]
	preview.scale = Vector2.ONE * (4.5 if with_dog else 6.0)
	preview.position = Vector2(165 if with_dog else 210, 330)
	# Little heroes on the hairstyle and outfit buttons show the current colours
	for key in style_buttons:
		for id in style_buttons[key]:
			var entry: Array = style_buttons[key][id]
			var mini_look: Dictionary = look.duplicate(true)
			mini_look[key] = id
			mini_look["aids"] = look["aids"].filter(func(a): return not a in ["wheelchair", "service_dog", "crutches"])
			if key == "hair_style":
				mini_look["item"] = "none"
			entry[1].look = mini_look
			entry[1].queue_redraw()
			var selected: bool = look[key] == id
			var style := _box(Color("#7ec850") if selected else Color("#1e3a5f"), Color.WHITE if selected else Color("#334155"), 3 if selected else 2, 10)
			for state in ["normal", "hover", "pressed", "focus"]:
				entry[0].add_theme_stylebox_override(state, style)
	for id in aid_buttons:
		var on: bool = id in look["aids"]
		var button: Button = aid_buttons[id]
		button.set_pressed_no_signal(on)
		var style := _box(Color("#0369a1") if on else Color("#1e293b"), Color.WHITE if on else Color("#334155"), 3 if on else 2, 10)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", Color.WHITE if on else Color("#cbd5e1"))
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
	name_tag.text = look["name"] if look["name"] != "" else tr("Your hero")
	wallet_label.text = "</>  %d" % save.icons
	boy_button.set_pressed_no_signal(look["style"] == "boy")
	girl_button.set_pressed_no_signal(look["style"] == "girl")
	for key in swatches:
		for entry in swatches[key]:
			var selected: bool = entry[1] == look[key]
			var style := _box(Color(entry[1]), Color.WHITE if selected else Color("#334155"), 4 if selected else 2, 10)
			for state in ["normal", "hover", "pressed", "focus"]:
				entry[0].add_theme_stylebox_override(state, style)
	for item in HeroSprite.ITEMS:
		var button: Button = item_buttons[item["id"]]
		var owned: bool = item["id"] in save.owned_items
		var selected: bool = look.get("item", "none") == item["id"]
		button.text = tr(item["name"]) if owned else "%s\n%d </>" % [tr(item["name"]), item["price"]]
		var bg := Color("#0369a1") if selected else (Color("#1e3a5f") if owned else Color("#1e293b"))
		var style := _box(bg, Color.WHITE if selected else Color("#334155"), 3 if selected else 2, 10)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", Color.WHITE if owned else Color("#94a3b8"))


func _message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)


func _row(parent: Container, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := _label(title, 19, Color("#94a3b8"))
	label.custom_minimum_size = Vector2(76, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _swatch_row(parent: Container, title: String, key: String, colors: Array) -> void:
	var row := _row(parent, title)
	swatches[key] = []
	for hex in colors:
		var button := Button.new()
		button.custom_minimum_size = Vector2(42, 42)
		button.pressed.connect(_set_value.bind(key, hex))
		row.add_child(button)
		swatches[key].append([button, hex])


func _choice_button(text: String, group: ButtonGroup, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(130, 46)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _box(Color("#1e293b"), Color("#334155"), 2, 10))
	button.add_theme_stylebox_override("hover", _box(Color("#273449"), Color("#64748b"), 2, 10))
	button.add_theme_stylebox_override("pressed", _box(Color("#0369a1"), Color.WHITE, 3, 10))
	button.add_theme_stylebox_override("hover_pressed", _box(Color("#0369a1"), Color.WHITE, 3, 10))
	button.pressed.connect(action)
	return button


func _big_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.3), 2, 12))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.15), Color.WHITE, 2, 12))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), Color.WHITE, 2, 12))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
