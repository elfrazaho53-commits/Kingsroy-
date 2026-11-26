class_name RaceHud
extends CanvasLayer

signal pause_pressed
signal reset_pressed
signal restart_pressed
signal next_pressed
signal menu_pressed

var _time_label: Label
var _speed_label: Label
var _progress_bar: ProgressBar
var _countdown_label: Label
var _toast_label: Label
var _stage_label: Label
var _target_label: Label
var _toast_tween: Tween
var _countdown_tween: Tween

var _pause_panel: Control
var _results_panel: Control
var _results_title: Label
var _results_body: Label
var _next_button: Button
var _touch_root: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()

func set_stage_info(stage_name: String, target: float) -> void:
	_stage_label.text = stage_name
	_target_label.text = "Objectif : %.1f s" % target

func set_time(t: float) -> void:
	_time_label.text = "%.1f s" % t

func set_speed(kmh: float) -> void:
	_speed_label.text = "%d km/h" % int(kmh)

func set_progress(p: float) -> void:
	_progress_bar.value = clampf(p, 0.0, 1.0)

func set_countdown(text: String) -> void:
	_countdown_label.text = text
	_countdown_label.modulate.a = 1.0

func fade_countdown() -> void:
	if _countdown_tween:
		_countdown_tween.kill()
	_countdown_tween = create_tween()
	_countdown_tween.tween_interval(0.8)
	_countdown_tween.tween_property(_countdown_label, "modulate:a", 0.0, 0.4)

func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)

func show_pause() -> void:
	_pause_panel.visible = true

func hide_pause() -> void:
	_pause_panel.visible = false

func show_results(data: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("Temps : %.1f s" % float(data.time))
	if bool(data.new_best):
		lines.append("Nouveau record !")
	lines.append("Meilleur temps : %.1f s" % float(data.best_time))
	lines.append("Récompense : %d F" % int(data.reward))
	lines.append("Points championnat : +%d" % int(data.points))
	_results_body.text = "\n".join(lines)
	_next_button.visible = bool(data.next_exists)
	if bool(data.get("champion", false)):
		_results_title.text = "Championnat remporté !"
	else:
		_results_title.text = "Étape terminée !"
	_results_panel.visible = true

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := VBoxContainer.new()
	_place(top_left, 0.0, 0.0, 0.0, 0.0, 24.0, 20.0, 700.0, 190.0)
	root.add_child(top_left)
	_stage_label = _make_label(24, Color.WHITE)
	_target_label = _make_label(18, Color(1.0, 0.85, 0.6))
	_time_label = _make_label(56, Color.WHITE)
	top_left.add_child(_stage_label)
	top_left.add_child(_target_label)
	top_left.add_child(_time_label)

	_speed_label = _make_label(44, Color.WHITE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_speed_label, 1.0, 1.0, 1.0, 1.0, -330.0, -350.0, -24.0, -296.0)
	root.add_child(_speed_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.55, 0.08)
	fill.set_corner_radius_all(6)
	_progress_bar.add_theme_stylebox_override("background", bg)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	_place(_progress_bar, 0.0, 1.0, 1.0, 1.0, 24.0, -26.0, -24.0, -14.0)
	root.add_child(_progress_bar)

	_countdown_label = _make_label(140, Color(1.0, 0.62, 0.1))
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_countdown_label, 0.0, 0.0, 1.0, 1.0, 0.0, -100.0, 0.0, 100.0)
	root.add_child(_countdown_label)

	_toast_label = _make_label(34, Color.WHITE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_toast_label, 0.0, 0.0, 1.0, 0.0, 0.0, 250.0, 0.0, 310.0)
	_toast_label.modulate.a = 0.0
	root.add_child(_toast_label)

	var reset_btn := _icon_button("↺")
	reset_btn.pressed.connect(func(): reset_pressed.emit())
	_place(reset_btn, 1.0, 0.0, 1.0, 0.0, -190.0, 20.0, -110.0, 100.0)
	root.add_child(reset_btn)

	var pause_btn := _icon_button("II")
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	_place(pause_btn, 1.0, 0.0, 1.0, 0.0, -100.0, 20.0, -20.0, 100.0)
	root.add_child(pause_btn)

	_touch_root = Control.new()
	_touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_touch_root)

	var steer_left := _touch_button("◀", "steer_left", Vector2(120, 120))
	_place(steer_left, 0.0, 1.0, 0.0, 1.0, 24.0, -150.0, 156.0, -18.0)
	_touch_root.add_child(steer_left)

	var steer_right := _touch_button("▶", "steer_right", Vector2(120, 120))
	_place(steer_right, 0.0, 1.0, 0.0, 1.0, 168.0, -150.0, 300.0, -18.0)
	_touch_root.add_child(steer_right)

	var accel := _touch_button("▲", "accelerate", Vector2(140, 140))
	_place(accel, 1.0, 1.0, 1.0, 1.0, -164.0, -164.0, -24.0, -24.0)
	_touch_root.add_child(accel)

	var brake := _touch_button("▼", "brake", Vector2(96, 96))
	_place(brake, 1.0, 1.0, 1.0, 1.0, -276.0, -120.0, -180.0, -24.0)
	_touch_root.add_child(brake)

	var handbrake := _touch_button("F", "handbrake", Vector2(80, 80))
	_place(handbrake, 1.0, 1.0, 1.0, 1.0, -164.0, -256.0, -84.0, -176.0)
	_touch_root.add_child(handbrake)

	if not DisplayServer.is_touchscreen_available():
		_touch_root.visible = false

	_pause_panel = _build_panel("Pause", [
		["Reprendre", func(): pause_pressed.emit()],
		["Recommencer", func(): restart_pressed.emit()],
		["Retour au menu", func(): menu_pressed.emit()],
	])
	root.add_child(_pause_panel)

	_results_panel = _build_results_panel()
	root.add_child(_results_panel)

func _build_panel(title_text: String, buttons: Array) -> Control:
	var wrapper := Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(460, 0)
	panel.add_child(vbox)
	var title := _make_label(42, Color(1.0, 0.62, 0.1))
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for entry in buttons:
		vbox.add_child(_menu_button(entry[0], entry[1]))
	return wrapper

func _build_results_panel() -> Control:
	var wrapper := Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(480, 0)
	panel.add_child(vbox)
	_results_title = _make_label(44, Color(1.0, 0.62, 0.1))
	_results_title.text = "Étape terminée !"
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_results_title)
	_results_body = _make_label(26, Color.WHITE)
	_results_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_results_body)
	vbox.add_child(_menu_button("Recommencer", func(): restart_pressed.emit()))
	_next_button = _menu_button("Étape suivante", func(): next_pressed.emit())
	vbox.add_child(_next_button)
	vbox.add_child(_menu_button("Retour au menu", func(): menu_pressed.emit()))
	return wrapper

func _menu_button(text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(380, 60)
	btn.add_theme_font_size_override("font_size", 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	return btn

func _icon_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	sbp.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_font_size_override("font_size", 30)
	return btn

func _touch_button(text: String, action: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.set_corner_radius_all(24)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sbp.set_corner_radius_all(24)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_font_size_override("font_size", 40)
	btn.button_down.connect(func(): Input.action_press(action))
	btn.button_up.connect(func(): Input.action_release(action))
	return btn

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 44.0
	sb.content_margin_right = 44.0
	sb.content_margin_top = 32.0
	sb.content_margin_bottom = 32.0
	return sb

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = ""
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _place(control: Control, anchor_l: float, anchor_t: float, anchor_r: float, anchor_b: float,
		off_l: float, off_t: float, off_r: float, off_b: float) -> void:
	control.anchor_left = anchor_l
	control.anchor_top = anchor_t
	control.anchor_right = anchor_r
	control.anchor_bottom = anchor_b
	control.offset_left = off_l
	control.offset_top = off_t
	control.offset_right = off_r
	control.offset_bottom = off_b
