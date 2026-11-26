extends Control

var _stage_panel: Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var stripes := [Color(0.95, 0.55, 0.05), Color(0.95, 0.95, 0.95), Color(0.15, 0.65, 0.3)]
	for i in 3:
		var stripe := ColorRect.new()
		stripe.color = stripes[i]
		stripe.anchor_top = 0.0
		stripe.anchor_bottom = 1.0
		stripe.anchor_left = 0.0
		stripe.anchor_right = 0.0
		stripe.offset_left = float(i * 10)
		stripe.offset_right = float(i * 10 + 6)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(540, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "RALLYE IVOIRE"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.05))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Le championnat des pistes ivoiriennes"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	_add_button(vbox, "Championnat", _start_championship)
	_add_button(vbox, "Course rapide", _show_stage_select)
	_add_button(vbox, "Garage", _open_garage)
	_add_button(vbox, "Quitter", func(): get_tree().quit())

	var total_points := GameState.total_championship_points()
	var progress_text := ""
	if GameState.championship_stage_index >= StageDefs.STAGES.size():
		progress_text = "Championnat terminé — %d points !" % total_points
	else:
		progress_text = "Championnat : étape %d / %d — %d points" % [
			GameState.championship_stage_index + 1, StageDefs.STAGES.size(), total_points,
		]
	var progress_label := Label.new()
	progress_label.text = progress_text
	progress_label.add_theme_font_size_override("font_size", 20)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(progress_label)

	var money_label := Label.new()
	money_label.text = "%d F" % GameState.money
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(money_label)

	_stage_panel = _build_stage_panel()
	add_child(_stage_panel)
	_stage_panel.visible = false

func _add_button(parent: Container, text: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(460, 68)
	btn.add_theme_font_size_override("font_size", 28)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	parent.add_child(btn)

func _start_championship() -> void:
	var index := mini(GameState.championship_stage_index, StageDefs.STAGES.size() - 1)
	_start_stage(index, "championship")

func _start_stage(index: int, mode: String) -> void:
	GameState.current_stage = StageDefs.STAGES[index]
	GameState.current_stage_index = index
	GameState.race_mode = mode
	get_tree().change_scene_to_file("res://scenes/stage.tscn")

func _show_stage_select() -> void:
	_stage_panel.visible = true

func _open_garage() -> void:
	get_tree().change_scene_to_file("res://scenes/garage.tscn")

func _on_stage_selected(index: int) -> void:
	_start_stage(index, "quick")

func _build_stage_panel() -> Control:
	var wrapper := Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	wrapper.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(900, 0)
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "Choisis une étape"
	header.add_theme_font_size_override("font_size", 44)
	header.add_theme_color_override("font_color", Color(0.95, 0.55, 0.05))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	for i in StageDefs.STAGES.size():
		var stage: Dictionary = StageDefs.STAGES[i]
		var btn := Button.new()
		var best := ""
		if GameState.best_times.has(stage.id):
			best = " — record : %.1f s" % GameState.best_times[stage.id]
		btn.text = "%s\n%s — objectif %.0f s%s" % [stage.name, stage.difficulty, stage.target_time, best]
		btn.custom_minimum_size = Vector2(0, 96)
		btn.add_theme_font_size_override("font_size", 24)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_stage_selected.bind(i))
		vbox.add_child(btn)

	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 60)
	back.add_theme_font_size_override("font_size", 24)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): _stage_panel.visible = false)
	vbox.add_child(back)
	return wrapper
