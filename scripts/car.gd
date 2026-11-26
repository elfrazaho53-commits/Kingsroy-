class_name RallyCar
extends CharacterBody3D

const GRAVITY := 24.0

var stats: Dictionary = {}
var input_enabled := false
var off_road := false
var forward_speed := 0.0
var lateral_speed := 0.0
var wheel_spin := 0.0
var steer_visual := 0.0

var _body_pivot: Node3D
var _front_hubs: Array[Node3D] = []
var _all_hubs: Array[Node3D] = []
var _pivot_quat := Quaternion.IDENTITY

func setup(p_stats: Dictionary) -> void:
	stats = p_stats

func _ready() -> void:
	floor_snap_length = 0.6
	_build_body()

func speed_kmh() -> float:
	return forward_speed * 3.6

func reset_to(pos: Vector3, dir: Vector3) -> void:
	global_position = pos + Vector3.UP * 0.6
	velocity = Vector3.ZERO
	forward_speed = 0.0
	lateral_speed = 0.0
	look_at(pos + dir, Vector3.UP)

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var brake_input := 0.0
	var steer := 0.0
	var handbrake := false
	if input_enabled:
		throttle = Input.get_action_strength("accelerate")
		brake_input = Input.get_action_strength("brake")
		steer = Input.get_axis("steer_left", "steer_right")
		handbrake = Input.is_action_pressed("handbrake")

	var fwd := -Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()

	forward_speed = velocity.dot(fwd)
	lateral_speed = velocity.dot(right)

	var top: float = stats.get("top_speed", 38.0)
	if off_road:
		top *= 0.5

	if throttle > 0.0 and forward_speed < top:
		var power: float = stats.get("accel", 15.0)
		forward_speed += power * throttle * delta * (1.0 - clampf(forward_speed / top, 0.0, 1.0) * 0.5)

	if brake_input > 0.0:
		if forward_speed > 0.5:
			forward_speed -= stats.get("accel", 15.0) * 1.8 * brake_input * delta
		else:
			forward_speed = maxf(forward_speed - 8.0 * brake_input * delta, -top * 0.4)

	if throttle < 0.01 and brake_input < 0.01:
		var drag := 9.0 if off_road else 3.5
		forward_speed = move_toward(forward_speed, 0.0, drag * delta)

	var grip: float = stats.get("grip", 6.5)
	if off_road:
		grip *= 0.45
	if handbrake:
		grip *= 0.22
	lateral_speed *= exp(-grip * delta)

	var speed_factor := clampf(absf(forward_speed) / 10.0, 0.0, 1.0)
	var yaw := -steer * 2.2 * speed_factor * delta
	if forward_speed < -0.5:
		yaw = -yaw
	if handbrake and absf(forward_speed) > 4.0:
		yaw *= 1.7
	rotate_y(yaw)

	steer_visual = lerpf(steer_visual, steer, minf(10.0 * delta, 1.0))

	var fwd_after := -Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z).normalized()
	var right_after := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()
	velocity = fwd_after * forward_speed + right_after * lateral_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	var target_quat := Quaternion.IDENTITY
	if is_on_floor():
		var normal := get_floor_normal()
		var local_normal := global_transform.basis.inverse() * normal
		if local_normal.length_squared() > 0.001 and local_normal.angle_to(Vector3.UP) > 0.01:
			target_quat = Quaternion(Vector3.UP, local_normal)
	_pivot_quat = _pivot_quat.slerp(target_quat, minf(8.0 * delta, 1.0))
	_body_pivot.quaternion = _pivot_quat

	wheel_spin += forward_speed / 0.35 * delta
	var steer_angle := steer_visual * 0.45
	for i in _all_hubs.size():
		var basis := Basis(Vector3(1.0, 0.0, 0.0), wheel_spin)
		if i < _front_hubs.size():
			basis = Basis(Vector3.UP, steer_angle) * basis
		_all_hubs[i].basis = basis

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 0.9, 3.6)
	col.shape = shape
	col.position = Vector3(0.0, 0.75, 0.0)
	add_child(col)

	_body_pivot = Node3D.new()
	add_child(_body_pivot)

	var color: Color = stats.get("color", Color(0.85, 0.45, 0.1))
	_body_pivot.add_child(_make_box(Vector3(1.7, 0.6, 3.7), Vector3(0.0, 0.7, 0.0), color))
	_body_pivot.add_child(_make_box(Vector3(1.45, 0.5, 1.7), Vector3(0.0, 1.2, 0.25), color.darkened(0.3)))
	_body_pivot.add_child(_make_box(Vector3(1.3, 0.4, 0.06), Vector3(0.0, 1.15, -0.72), Color(0.25, 0.55, 0.7)))
	_body_pivot.add_child(_make_box(Vector3(1.5, 0.08, 0.5), Vector3(0.0, 1.05, 1.7), color.darkened(0.5)))
	_body_pivot.add_child(_make_box(Vector3(0.4, 0.18, 0.06), Vector3(-0.5, 0.75, -1.86), Color(0.95, 0.95, 0.8)))
	_body_pivot.add_child(_make_box(Vector3(0.4, 0.18, 0.06), Vector3(0.5, 0.75, -1.86), Color(0.95, 0.95, 0.8)))
	_body_pivot.add_child(_make_box(Vector3(0.4, 0.18, 0.06), Vector3(-0.5, 0.75, 1.86), Color(0.8, 0.1, 0.1)))
	_body_pivot.add_child(_make_box(Vector3(0.4, 0.18, 0.06), Vector3(0.5, 0.75, 1.86), Color(0.8, 0.1, 0.1)))

	var wheel_positions := [
		Vector3(-0.85, 0.36, -1.25),
		Vector3(0.85, 0.36, -1.25),
		Vector3(-0.85, 0.36, 1.25),
		Vector3(0.85, 0.36, 1.25),
	]
	for i in wheel_positions.size():
		var hub := Node3D.new()
		hub.position = wheel_positions[i]
		_body_pivot.add_child(hub)
		hub.add_child(_make_wheel_mesh())
		_all_hubs.append(hub)
		if i < 2:
			_front_hubs.append(hub)

func _make_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	box.material = mat
	mesh_instance.mesh = box
	mesh_instance.position = pos
	return mesh_instance

func _make_wheel_mesh() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.36
	cylinder.bottom_radius = 0.36
	cylinder.height = 0.28
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mat.roughness = 0.9
	cylinder.material = mat
	mesh_instance.mesh = cylinder
	mesh_instance.rotation.z = PI * 0.5
	return mesh_instance
