extends Node3D

var assault_fort: Node3D
var assault_ship: Node3D
var lane_index := 0
var _start_position := Vector3.ZERO
var _beach_position := Vector3.ZERO
var _fort_position := Vector3.ZERO
var _boat_visual: Node3D
var _marines: Array[Node3D] = []
var _last_progress := 0.0
var _completed_elapsed := 0.0


func begin(ship: Node3D, fort: Node3D, lane: int) -> void:
	assault_ship = ship
	assault_fort = fort
	lane_index = lane
	_build_visual()
	_resolve_route()
	global_position = _start_position
	_face_point(_beach_position)


func _process(_delta: float) -> void:
	if not is_instance_valid(assault_fort):
		queue_free()
		return
	var progress := clampf(float(assault_fort.get("capture_progress")), 0.0, 1.0)
	if bool(assault_fort.get("is_captured")):
		_completed_elapsed += _delta
		if _completed_elapsed >= 2.2:
			queue_free()
			return
	_last_progress = maxf(_last_progress, progress)
	var boat_t := smoothstep(0.0, 0.42, progress)
	global_position = _start_position.lerp(_beach_position, boat_t)
	global_position.y = 0.15 + sin(Time.get_ticks_msec() * 0.0045 + float(lane_index) * 1.7) * 0.16 * (1.0 - boat_t * 0.6)
	rotation.z = sin(Time.get_ticks_msec() * 0.0038 + float(lane_index)) * 0.035
	if is_instance_valid(_boat_visual):
		_boat_visual.visible = progress < 0.80
	_update_marines(progress)


func _resolve_route() -> void:
	_fort_position = assault_fort.global_position
	var outward := assault_ship.global_position - _fort_position if is_instance_valid(assault_ship) else Vector3.BACK
	outward.y = 0.0
	if outward.length_squared() < 0.01:
		outward = Vector3.BACK
	outward = outward.normalized()
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	var lane_offset := (float(lane_index) - 1.0) * 5.2
	var ship_distance := assault_ship.global_position.distance_to(_fort_position) if is_instance_valid(assault_ship) else 64.0
	_start_position = _fort_position + outward * minf(maxf(ship_distance, 48.0), 76.0) + tangent * lane_offset
	_beach_position = _fort_position + outward * 26.0 + tangent * lane_offset * 0.72


func _update_marines(progress: float) -> void:
	var march_t := smoothstep(0.30, 0.82, progress)
	for index in range(_marines.size()):
		var marine := _marines[index]
		if not is_instance_valid(marine):
			continue
		marine.visible = progress >= 0.26
		if not marine.visible:
			continue
		var spread := (float(index) - float(_marines.size() - 1) * 0.5) * 0.85
		var outward := (_beach_position - _fort_position).normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var shore_start := _beach_position + tangent * spread
		var assault_end := _fort_position + tangent * spread * 0.42 + Vector3.UP * 3.2
		marine.global_position = shore_start.lerp(assault_end, march_t)
		marine.global_position.y += absf(sin(Time.get_ticks_msec() * 0.012 + float(index))) * 0.16 * (1.0 - march_t)
		var march_direction := _fort_position - shore_start
		march_direction.y = 0.0
		if march_direction.length_squared() > 0.01:
			marine.look_at(marine.global_position + march_direction.normalized(), Vector3.UP, true)


func _build_visual() -> void:
	_boat_visual = Node3D.new()
	_boat_visual.name = "LandingBoat"
	add_child(_boat_visual)
	var timber := _material(Color(0.20, 0.075, 0.028), 0.86)
	var trim := _material(Color(0.52, 0.31, 0.10), 0.72)
	_add_box(_boat_visual, Vector3(2.7, 0.48, 6.8), Vector3(0.0, 0.15, 0.0), timber)
	_add_box(_boat_visual, Vector3(3.1, 0.22, 5.8), Vector3(0.0, 0.48, 0.0), trim)
	for side in [-1.0, 1.0]:
		_add_box(_boat_visual, Vector3(0.16, 0.52, 6.5), Vector3(side * 1.48, 0.45, 0.0), trim)
	for index in range(5):
		var marine := _build_marine()
		marine.position = Vector3(-0.72 + float(index % 2) * 1.44, 0.72, -1.9 + float(index / 2) * 1.8)
		add_child(marine)
		_marines.append(marine)


func _build_marine() -> Node3D:
	var marine := Node3D.new()
	marine.name = "Marine"
	var coat := _material(Color(0.12, 0.28, 0.62), 0.84)
	var skin := _material(Color(0.72, 0.48, 0.30), 0.90)
	_add_box(marine, Vector3(0.42, 0.72, 0.30), Vector3(0.0, 0.48, 0.0), coat)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 8
	sphere.rings = 4
	head.mesh = sphere
	head.position = Vector3(0.0, 0.98, 0.0)
	head.material_override = skin
	marine.add_child(head)
	return marine


func _face_point(point: Vector3) -> void:
	var flat_point := Vector3(point.x, global_position.y, point.z)
	if global_position.distance_squared_to(flat_point) > 0.01:
		look_at(flat_point, Vector3.UP, true)


func _add_box(parent: Node, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
