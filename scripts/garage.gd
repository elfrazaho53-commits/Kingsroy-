extends Control

var _money_label: Label
var _cards: VBoxContainer

func _ready() -> void:
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	vbox.add_child(header)

	var back := Button.new()
	back.text = "← Menu"
	back.custom_minimum_size = Vector2(140, 60)
	back.add_theme_font_size_override("font_size", 24)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_go_menu)
	header.add_child(back)

	var title := Label.new()
	title.text = "GARAGE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.05))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 30)
	_money_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_money_label)

	var hint := Label.new()
	hint.text = "Gagne des courses pour acheter de meilleures voitures."
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 18)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)

func _refresh() -> void:
	_money_label.text = "%d F" % GameState.money
	_money_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for car in StageDefs.CARS:
		_cards.add_child(_make_card(car))

func _make_card(car: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 26)
	panel.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = car.color
	swatch.custom_minimum_size = Vector2(90, 90)
	hbox.add_child(swatch)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = car.name
	name_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(name_label)

	var desc := Label.new()
	desc.text = car.desc
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(_stat_bar("Vitesse", float(car.top_speed) / 55.0))
	vbox.add_child(_stat_bar("Accélération", float(car.accel) / 20.0))
	vbox.add_child(_stat_bar("Adhérence", float(car.grip) / 10.0))

	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	hbox.add_child(action_box)

	var owned: bool = GameState.owned_cars.has(car.id)
	var selected: bool = GameState.selected_car == car.id
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 62)
	btn.add_theme_font_size_override("font_size", 24)
	btn.focus_mode = Control.FOCUS_NONE
	if selected:
		btn.text = "Sélectionnée"
		btn.disabled = true
	elif owned:
		btn.text = "Sélectionner"
		btn.pressed.connect(_on_select.bind(car.id))
	else:
		btn.text = "Acheter — %d F" % int(car.price)
		btn.pressed.connect(_on_buy.bind(car.id))
	action_box.add_child(btn)

	var price_label := Label.new()
	price_label.text = "Achetée" if owned else "Prix : %d F" % int(car.price)
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.add_child(price_label)
	return panel

func _stat_bar(label_text: String, ratio: float) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.55, 0.08)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	hbox.add_child(bar)
	return hbox

func _on_select(car_id: String) -> void:
	GameState.selected_car = car_id
	GameState.save_game()
	_refresh()

func _on_buy(car_id: String) -> void:
	var car: Dictionary = StageDefs.CARS[0]
	for candidate in StageDefs.CARS:
		if candidate.id == car_id:
			car = candidate
			break
	if GameState.money < int(car.price):
		_money_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		return
	GameState.money -= int(car.price)
	GameState.owned_cars.append(car_id)
	GameState.selected_car = car_id
	GameState.save_game()
	_refresh()

func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
