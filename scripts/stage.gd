extends Node3D

enum RaceState { COUNTDOWN, RACING, FINISHED }

const CAMERA_DISTANCE := 8.0
const CAMERA_HEIGHT := 3.8

var car: RallyCar
var camera: Camera3D
var hud: RaceHud
var track_samples: PackedVector3Array = []
var gates: Array = []
var next_gate := 1
var race_time := 0.0
var state: int = RaceState.COUNTDOWN
var countdown := 3.0
var _offroad_check_timer := 0.0
var _progress_index := 0
var _last_reset_position: Vector3
var _last_reset_direction: Vector3
var _stage: Dictionary

func _ready() -> void:
	_stage = GameState.current_stage
	if _stage.is_empty():
		_stage = StageDefs.STAGES[0]
		GameState.current_stage = _stage
	var theme := _theme_for(_stage.get("theme", "savane"))

	_build_environment()

	var curve := TrackBuilder.generate_curve(int(_stage.seed), float(_stage.length))
	track_samples = TrackBuilder.sample_curve(curve, TrackBuilder.SAMPLE_SPACING)

	add_child(TrackBuilder.build_road(track_samples))
	add_child(TrackBuilder.build_start_line(track_samples))
	add_child(TrackBuilder.build_ground(track_samples, theme))
	add_child(TrackBuilder.build_props(track_samples, int(_stage.seed), theme))

	var checkpoint_data := TrackBuilder.build_checkpoints(track_samples, 160.0)
	add_child(checkpoint_data.root)
	gates = checkpoint_data.gates
	for gate in gates:
		gate.area.body_entered.connect(_on_gate_entered.bind(int(gate.number)))

	_spawn_car()
	_setup_camera()

	hud = RaceHud.new()
	add_child(hud)
	hud.pause_pressed.connect(_toggle_pause)
	hud.reset_pressed.connect(_reset_car)
	hud.restart_pressed.connect(_restart)
	hud.next_pressed.connect(_next_stage)
	hud.menu_pressed.connect(_go_menu)
	hud.set_stage_info(_stage.get("name", "Étape"), float(_stage.get("target_time", 60.0)))
	hud.set_countdown("3")

	_last_reset_position = track_samples[0]
	_last_reset_direction = TrackBuilder.road_direction(track_samples, 2)

func _physics_process(delta: float) -> void:
	if state == RaceState.COUNTDOWN:
		countdown -= delta
		if countdown <= 0.0:
			state = RaceState.RACING
			car.input_enabled = true
			hud.set_countdown("GO !")
			hud.fade_countdown()
		else:
			hud.set_countdown(str(int(ceil(countdown))))
	elif state == RaceState.RACING:
		race_time += delta
		hud.set_time(race_time)
	_update_camera(delta)
	_update_offroad(delta)
	hud.set_speed(absf(car.speed_kmh()))
	hud.set_progress(_car_progress())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("reset_car"):
		_reset_car()

func _on_gate_entered(body: Node3D, number: int) -> void:
	if body != car or state != RaceState.RACING:
		return
	if number != next_gate:
		return
	for gate in gates:
		if int(gate.number) == number:
			if bool(gate.is_finish):
				_finish_race()
			else:
				_last_reset_position = gate.position
				_last_reset_direction = gate.direction
				next_gate += 1
				hud.show_toast("Checkpoint %d — %.1f s" % [number, race_time])
			break

func _finish_race() -> void:
	if state == RaceState.FINISHED:
		return
	state = RaceState.FINISHED
	car.input_enabled = false
	var result := GameState.record_result(_stage.id, race_time)
	var is_championship: bool = GameState.race_mode == "championship"
	var can_advance := GameState.current_stage_index == GameState.championship_stage_index
	if is_championship and can_advance and GameState.championship_stage_index < StageDefs.STAGES.size():
		GameState.championship_stage_index += 1
		GameState.save_game()
	var champion := is_championship and GameState.championship_stage_index >= StageDefs.STAGES.size()
	var next_exists := GameState.current_stage_index < StageDefs.STAGES.size() - 1
	hud.show_results({
		"time": race_time,
		"new_best": result.new_best,
		"best_time": GameState.best_times.get(_stage.id, race_time),
		"reward": result.reward,
		"points": result.points,
		"next_exists": next_exists,
		"champion": champion,
	})

func _spawn_car() -> void:
	car = RallyCar.new()
	car.stats = GameState.car_stats(GameState.selected_car)
	add_child(car)
	car.reset_to(track_samples[0], TrackBuilder.road_direction(track_samples, 2))

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 2000.0
	add_child(camera)
	var fwd := TrackBuilder.road_direction(track_samples, 2)
	camera.global_position = track_samples[0] - fwd * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	camera.look_at(track_samples[0] + Vector3.UP * 1.2, Vector3.UP)
	camera.current = true

func _update_camera(delta: float) -> void:
	var car_fwd := -car.global_transform.basis.z
	car_fwd.y = 0.0
	if car_fwd.length_squared() < 0.001:
		car_fwd = Vector3.FORWARD
	car_fwd = car_fwd.normalized()
	var target := car.global_position - car_fwd * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	var weight := 1.0 - exp(-6.0 * delta)
	camera.global_position = camera.global_position.lerp(target, weight)
	camera.look_at(car.global_position + Vector3.UP * 1.4, Vector3.UP)
	camera.fov = lerpf(camera.fov, 75.0 + clampf(absf(car.forward_speed) - 20.0, 0.0, 20.0), minf(2.0 * delta, 1.0))

func _update_offroad(delta: float) -> void:
	_offroad_check_timer -= delta
	if _offroad_check_timer > 0.0:
		return
	_offroad_check_timer = 0.2
	var car_pos := car.global_position
	var best_dist := INF
	var best_i := 0
	for i in range(0, track_samples.size(), 2):
		var d := track_samples[i].distance_squared_to(car_pos)
		if d < best_dist:
			best_dist = d
			best_i = i
	_progress_index = best_i
	car.off_road = sqrt(best_dist) > TrackBuilder.ROAD_WIDTH * 0.5 + 1.5

func _car_progress() -> float:
	if track_samples.is_empty():
		return 0.0
	return clampf(float(_progress_index) / float(track_samples.size() - 1), 0.0, 1.0)

func _reset_car() -> void:
	if state == RaceState.FINISHED:
		return
	car.reset_to(_last_reset_position, _last_reset_direction)

func _toggle_pause() -> void:
	if state == RaceState.FINISHED:
		return
	if get_tree().paused:
		get_tree().paused = false
		hud.hide_pause()
	else:
		get_tree().paused = true
		hud.show_pause()

func _restart() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage.tscn")

func _next_stage() -> void:
	var index := mini(GameState.current_stage_index + 1, StageDefs.STAGES.size() - 1)
	GameState.current_stage = StageDefs.STAGES[index]
	GameState.current_stage_index = index
	GameState.race_mode = "championship"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage.tscn")

func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.85)
	sky_mat.ground_bottom_color = Color(0.4, 0.38, 0.33)
	sky_mat.ground_horizon_color = Color(0.78, 0.82, 0.85)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.2
	world_env.environment = env
	add_child(world_env)

func _theme_for(theme_id: String) -> Dictionary:
	match theme_id:
		"coast":
			return {
				"ground_color": Color(0.8, 0.72, 0.5),
				"tree_color": Color(0.18, 0.5, 0.24),
				"trunk_color": Color(0.45, 0.33, 0.18),
				"hill_color": Color(0.55, 0.5, 0.36),
				"tree_count": 2,
				"buildings": false,
			}
		"city":
			return {
				"ground_color": Color(0.45, 0.46, 0.42),
				"tree_color": Color(0.2, 0.45, 0.2),
				"trunk_color": Color(0.4, 0.3, 0.2),
				"hill_color": Color(0.5, 0.48, 0.44),
				"tree_count": 1,
				"buildings": true,
			}
		"montagne":
			return {
				"ground_color": Color(0.42, 0.52, 0.3),
				"tree_color": Color(0.12, 0.4, 0.2),
				"trunk_color": Color(0.3, 0.22, 0.14),
				"hill_color": Color(0.4, 0.38, 0.32),
				"tree_count": 3,
				"buildings": false,
			}
	return {
		"ground_color": Color(0.68, 0.56, 0.3),
		"tree_color": Color(0.45, 0.45, 0.2),
		"trunk_color": Color(0.4, 0.3, 0.18),
		"hill_color": Color(0.55, 0.45, 0.3),
		"tree_count": 2,
		"buildings": false,
	}
