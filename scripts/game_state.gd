extends Node

const SAVE_PATH := "user://savegame.json"

var money: int = 500
var owned_cars: Array = ["taxi"]
var selected_car: String = "taxi"
var best_times: Dictionary = {}
var stage_points: Dictionary = {}
var championship_stage_index: int = 0

var current_stage: Dictionary = {}
var current_stage_index: int = 0
var race_mode: String = "quick"

func _ready() -> void:
	_register_input_actions()
	load_game()

func _register_input_actions() -> void:
	var bindings := {
		"accelerate": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE],
		"reset_car": [KEY_R],
		"pause": [KEY_ESCAPE],
	}
	for action in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func car_stats(car_id: String) -> Dictionary:
	for car in StageDefs.CARS:
		if car.id == car_id:
			return car
	return StageDefs.CARS[0]

func record_result(stage_id: String, time_seconds: float) -> Dictionary:
	var stage := StageDefs.get_stage(stage_id)
	var points := 10
	if time_seconds <= stage.target_time:
		points = 25
	elif time_seconds <= stage.target_time * 1.15:
		points = 15
	var first_time: bool = not best_times.has(stage_id)
	var reward: int = stage.reward if first_time else int(stage.reward / 4.0)
	var new_best: bool = first_time or time_seconds < best_times[stage_id]
	if new_best:
		best_times[stage_id] = time_seconds
	if not stage_points.has(stage_id) or points > stage_points[stage_id]:
		stage_points[stage_id] = points
	money += reward
	save_game()
	return {"new_best": new_best, "points": points, "reward": reward, "first_time": first_time}

func total_championship_points() -> int:
	var total := 0
	for key in stage_points.keys():
		total += stage_points[key]
	return total

func save_game() -> void:
	var data := {
		"money": money,
		"owned_cars": owned_cars,
		"selected_car": selected_car,
		"best_times": best_times,
		"stage_points": stage_points,
		"championship_stage_index": championship_stage_index,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	money = int(parsed.get("money", 500))
	owned_cars = parsed.get("owned_cars", ["taxi"])
	selected_car = parsed.get("selected_car", "taxi")
	championship_stage_index = int(parsed.get("championship_stage_index", 0))
	best_times = {}
	var saved_best: Variant = parsed.get("best_times", {})
	if typeof(saved_best) == TYPE_DICTIONARY:
		for key in saved_best.keys():
			best_times[key] = float(saved_best[key])
	stage_points = {}
	var saved_points: Variant = parsed.get("stage_points", {})
	if typeof(saved_points) == TYPE_DICTIONARY:
		for key in saved_points.keys():
			stage_points[key] = int(saved_points[key])
