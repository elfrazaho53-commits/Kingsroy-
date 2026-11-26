class_name TrackBuilder
extends RefCounted

const ROAD_WIDTH := 9.0
const SAMPLE_SPACING := 4.0

static func generate_curve(seed_value: int, target_length: float) -> Curve3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := PackedVector3Array()
	var pos := Vector3.ZERO
	var heading := 0.0
	var travelled := 0.0
	points.append(pos)
	while travelled < target_length:
		heading = clampf(heading + rng.randf_range(-0.55, 0.55), -1.1, 1.1)
		var step := rng.randf_range(28.0, 55.0)
		pos = pos + Vector3(sin(heading), 0.0, -cos(heading)) * step
		travelled += step
		points.append(pos)
	var curve := Curve3D.new()
	for i in points.size():
		var tangent := Vector3.ZERO
		if i == 0:
			tangent = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			tangent = (points[i] - points[i - 1]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()
		curve.add_point(points[i], -tangent * 12.0, tangent * 12.0)
	return curve

static func sample_curve(curve: Curve3D, spacing: float) -> PackedVector3Array:
	var length := curve.get_baked_length()
	var count := maxi(int(length / spacing), 2)
	var samples := PackedVector3Array()
	for i in count + 1:
		samples.append(curve.sample_baked(minf(length, float(i) * spacing)))
	return samples

static func road_direction(samples: PackedVector3Array, index: int) -> Vector3:
	var a := samples[maxi(index - 1, 0)]
	var b := samples[mini(index + 1, samples.size() - 1)]
	var dir := b - a
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.FORWARD
	return dir.normalized()

static func build_road(samples: PackedVector3Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Road"
	root.add_child(_make_ribbon(samples, ROAD_WIDTH, 0.02, Color(0.16, 0.16, 0.17)))
	root.add_child(_make_center_line(samples))
	root.add_child(_make_curbs(samples, true))
	root.add_child(_make_curbs(samples, false))
	return root

static func build_start_line(samples: PackedVector3Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i := 2
	var dir := road_direction(samples, i)
	var side := dir.cross(Vector3.UP).normalized()
	var half := ROAD_WIDTH * 0.5
	var cols := 8
	var rows := 2
	for r in rows:
		for c in cols:
			var color := Color.BLACK if (r + c) % 2 == 0 else Color.WHITE
			var t0 := float(c) / float(cols) * ROAD_WIDTH - half
			var t1 := float(c + 1) / float(cols) * ROAD_WIDTH - half
			var s0 := float(r) / float(rows) * 3.0
			var s1 := float(r + 1) / float(rows) * 3.0
			var base := samples[i]
			var a := base + side * t0 + dir * s0 + Vector3.UP * 0.04
			var b := base + side * t1 + dir * s0 + Vector3.UP * 0.04
			var c2 := base + side * t1 + dir * s1 + Vector3.UP * 0.04
			var d := base + side * t0 + dir * s1 + Vector3.UP * 0.04
			_add_quad(st, a, b, c2, d, color)
	return _commit(st)

static func build_ground(samples: PackedVector3Array, theme: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Ground"
	var aabb := AABB(samples[0], Vector3.ONE * 0.001)
	for p in samples:
		aabb = aabb.expand(p)
	var size := maxf(aabb.size.x, aabb.size.z) + 1000.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.material = _material(theme.get("ground_color", Color(0.55, 0.5, 0.3)))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane
	mesh_instance.position = Vector3(aabb.get_center().x, -0.06, aabb.get_center().z)
	root.add_child(mesh_instance)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	root.add_child(body)
	return root

static func build_props(samples: PackedVector3Array, seed_value: int, theme: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var root := Node3D.new()
	root.name = "Props"

	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	for i in range(4, samples.size() - 4, 3):
		var dir := road_direction(samples, i)
		var side := dir.cross(Vector3.UP).normalized()
		for j in int(theme.get("tree_count", 2)):
			var offset := rng.randf_range(12.0, 45.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var pos := samples[i] + side * offset + Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-5.0, 5.0))
			var scale_factor := rng.randf_range(0.8, 1.6)
			var scale_y := scale_factor * rng.randf_range(0.9, 1.3)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_factor, scale_y, scale_factor))
			trunk_transforms.append(Transform3D(basis, pos))
			crown_transforms.append(Transform3D(basis, pos + Vector3(0.0, 3.6 * scale_factor, 0.0)))
	var trunk_mesh := _cylinder_mesh(0.18, 0.3, 3.8, theme.get("trunk_color", Color(0.35, 0.25, 0.15)))
	root.add_child(_make_multi_mesh(trunk_mesh, trunk_transforms))
	var crown := SphereMesh.new()
	crown.radius = 1.6
	crown.height = 2.4
	crown.material = _material(theme.get("tree_color", Color(0.2, 0.5, 0.25)))
	root.add_child(_make_multi_mesh(crown, crown_transforms))

	if theme.get("buildings", false):
		var building_transforms: Array[Transform3D] = []
		for i in range(6, samples.size() - 6, 5):
			var dir := road_direction(samples, i)
			var side := dir.cross(Vector3.UP).normalized()
			var offset := rng.randf_range(20.0, 35.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var height := rng.randf_range(8.0, 30.0)
			var width := rng.randf_range(6.0, 12.0)
			var depth := rng.randf_range(6.0, 12.0)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, depth))
			building_transforms.append(Transform3D(basis, samples[i] + side * offset + Vector3(0.0, height * 0.5, 0.0)))
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		box.material = _material(Color(0.55, 0.55, 0.58))
		root.add_child(_make_multi_mesh(box, building_transforms))

	var hill_transforms: Array[Transform3D] = []
	for k in 26:
		var i := rng.randi_range(0, samples.size() - 1)
		var dir := road_direction(samples, i)
		var side := dir.cross(Vector3.UP).normalized()
		var offset := rng.randf_range(120.0, 300.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var height := rng.randf_range(25.0, 80.0)
		var radius := height * rng.randf_range(1.2, 2.0)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(radius, height, radius))
		hill_transforms.append(Transform3D(basis, samples[i] + side * offset + Vector3(0.0, height * 0.5, 0.0)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 16
	cone.material = _material(theme.get("hill_color", Color(0.45, 0.42, 0.3)))
	root.add_child(_make_multi_mesh(cone, hill_transforms))
	return root

static func build_checkpoints(samples: PackedVector3Array, spacing: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "Checkpoints"
	var gates: Array = []
	var finish_index := samples.size() - 1
	var sample_step := maxi(int(spacing / SAMPLE_SPACING), 4)
	var number := 1
	var idx := sample_step
	while idx < finish_index - sample_step:
		_make_gate(root, samples, idx, number, false, gates)
		number += 1
		idx += sample_step
	_make_gate(root, samples, finish_index, number, true, gates)
	return {"root": root, "gates": gates}

static func _make_gate(root: Node3D, samples: PackedVector3Array, sample_index: int, number: int,
		is_finish: bool, gates: Array) -> void:
	var pos := samples[sample_index]
	var dir := road_direction(samples, sample_index)
	var side := dir.cross(Vector3.UP).normalized()
	var area := Area3D.new()
	area.basis = Basis(side, Vector3.UP, -dir)
	area.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROAD_WIDTH + 4.0, 6.0, 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, 3.0, 0.0)
	area.add_child(shape)

	var half := ROAD_WIDTH * 0.5 + 0.6
	var pillar_color := Color(0.95, 0.6, 0.1) if is_finish else Color(0.9, 0.9, 0.9)
	for sx in [-half, half]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.5, 5.0, 0.5)
		pillar_mesh.material = _material(pillar_color)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(sx, 2.5, 0.0)
		area.add_child(pillar)

	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(half * 2.0, 0.8, 0.3)
	banner_mesh.material = _material(Color(0.12, 0.12, 0.14) if is_finish else Color(0.85, 0.3, 0.1))
	banner.mesh = banner_mesh
	banner.position = Vector3(0.0, 5.2, 0.0)
	area.add_child(banner)

	var label := Label3D.new()
	label.text = "ARRIVÉE" if is_finish else "CP %d" % number
	label.font_size = 220
	label.outline_size = 40
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 6.4, 0.0)
	area.add_child(label)

	root.add_child(area)
	gates.append({
		"area": area,
		"number": number,
		"is_finish": is_finish,
		"position": pos,
		"direction": dir,
	})

static func _make_ribbon(samples: PackedVector3Array, width: float, y_offset: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in samples.size() - 1:
		var dir := (samples[i + 1] - samples[i]).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var half := width * 0.5
		var p0l := samples[i] - side * half + Vector3.UP * y_offset
		var p0r := samples[i] + side * half + Vector3.UP * y_offset
		var p1l := samples[i + 1] - side * half + Vector3.UP * y_offset
		var p1r := samples[i + 1] + side * half + Vector3.UP * y_offset
		_add_quad(st, p0l, p0r, p1r, p1l, color)
	return _commit(st)

static func _make_center_line(samples: PackedVector3Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(0.9, 0.9, 0.9)
	var dash := 6.0
	var gap := 6.0
	for i in samples.size() - 1:
		var seg := samples[i + 1] - samples[i]
		var seg_len := seg.length()
		var dir := seg / seg_len
		var side := dir.cross(Vector3.UP).normalized()
		var local := 0.0
		while local < seg_len:
			var dash_len := minf(dash, seg_len - local)
			var a := samples[i] + dir * local - side * 0.18 + Vector3.UP * 0.035
			var b := samples[i] + dir * local + side * 0.18 + Vector3.UP * 0.035
			var c := samples[i] + dir * (local + dash_len) + side * 0.18 + Vector3.UP * 0.035
			var d := samples[i] + dir * (local + dash_len) - side * 0.18 + Vector3.UP * 0.035
			_add_quad(st, a, b, c, d, color)
			local += dash + gap
	return _commit(st)

static func _make_curbs(samples: PackedVector3Array, left: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := ROAD_WIDTH * 0.5
	var segment := 0
	for i in samples.size() - 1:
		var dir := (samples[i + 1] - samples[i]).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		if not left:
			side = -side
		var color := Color(0.85, 0.1, 0.1) if segment % 2 == 0 else Color(0.95, 0.95, 0.95)
		var a := samples[i] + side * half + Vector3.UP * 0.03
		var b := samples[i] + side * (half + 0.8) + Vector3.UP * 0.03
		var c := samples[i + 1] + side * (half + 0.8) + Vector3.UP * 0.03
		var d := samples[i + 1] + side * half + Vector3.UP * 0.03
		_add_quad(st, a, b, c, d, color)
		segment += 1
	return _commit(st)

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_normal(Vector3.UP)
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(d)

static func _commit(st: SurfaceTool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	st.commit(array_mesh)
	mesh_instance.mesh = array_mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mesh_instance.material_override = mat
	return mesh_instance

static func _make_multi_mesh(mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

static func _cylinder_mesh(top: float, bottom: float, height: float, color: Color) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.material = _material(color)
	return cylinder

static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
