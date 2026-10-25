extends Node3D

signal ownership_changed(point: Node, new_owner: int)

@export var display_name := "Sea Objective"
@export var capture_radius := 30.0
@export var capture_duration := 9.0
@export var owner_team := -1

var capture_team := -1
var capture_progress := 0.0
var _ring_material: StandardMaterial3D
var _flag_material: StandardMaterial3D
var _marker_materials: Array[StandardMaterial3D] = []


func configure(data: Dictionary) -> void:
	display_name = String(data.get("name", display_name))
	capture_radius = float(data.get("radius", capture_radius))
	capture_duration = float(data.get("capture_duration", capture_duration))
	owner_team = int(data.get("owner", owner_team))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("scenario_content")
	add_to_group("scenario_control_point")
	_build_visual()
	_refresh_colors()


func _physics_process(delta: float) -> void:
	var presence := [0, 0]
	for ship in get_tree().get_nodes_in_group("ships"):
		if not is_instance_valid(ship) or not (ship is Node3D):
			continue
		if bool(ship.get("is_sunk")) or bool(ship.get("is_incapacitated")):
			continue
		var team := int(ship.get("team_id"))
		if team < 0 or team > 1:
			continue
		if global_position.distance_squared_to(ship.global_position) <= capture_radius * capture_radius:
			presence[team] += 1

	var dominant := -1
	if presence[0] > 0 and presence[1] == 0:
		dominant = 0
	elif presence[1] > 0 and presence[0] == 0:
		dominant = 1

	if dominant < 0 or dominant == owner_team:
		capture_progress = move_toward(capture_progress, 0.0, delta * 1.8)
		if capture_progress <= 0.01:
			capture_team = -1
		return

	if capture_team != dominant:
		capture_team = dominant
		capture_progress = 0.0
	capture_progress += delta
	if capture_progress >= capture_duration:
		owner_team = dominant
		capture_team = -1
		capture_progress = 0.0
		_refresh_colors()
		ownership_changed.emit(self, owner_team)


func get_capture_fraction() -> float:
	return clampf(capture_progress / maxf(capture_duration, 0.1), 0.0, 1.0)


func get_status_text() -> String:
	var owner := "Neutral"
	if owner_team == 0:
		owner = "Allied"
	elif owner_team == 1:
		owner = "Enemy"
	if capture_team >= 0:
		return "%s - %s capture %d%%" % [display_name, "Allied" if capture_team == 0 else "Enemy", int(get_capture_fraction() * 100.0)]
	return "%s - %s" % [display_name, owner]


func _build_visual() -> void:
	_ring_material = _material(Color(0.78, 0.62, 0.22, 0.72), true)
	_flag_material = _material(Color(0.78, 0.62, 0.22), false)

	var ring := MeshInstance3D.new()
	ring.name = "CaptureBoundary"
	ring.mesh = _build_ring_mesh()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	for index in range(12):
		var angle := float(index) / 12.0 * TAU
		var marker := MeshInstance3D.new()
		marker.name = "BoundaryMarker"
		var marker_mesh := CylinderMesh.new()
		marker_mesh.top_radius = 0.28
		marker_mesh.bottom_radius = 0.42
		marker_mesh.height = 1.8
		marker_mesh.radial_segments = 8
		marker.mesh = marker_mesh
		marker.position = Vector3(cos(angle) * capture_radius, 0.8, sin(angle) * capture_radius)
		var marker_material := _material(Color(0.78, 0.62, 0.22, 0.82), true)
		_marker_materials.append(marker_material)
		marker.material_override = marker_material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.14
	pole_mesh.height = 8.5
	pole_mesh.radial_segments = 10
	pole.mesh = pole_mesh
	pole.position.y = 4.1
	pole.material_override = _material(Color(0.16, 0.13, 0.09), false)
	add_child(pole)

	var flag := MeshInstance3D.new()
	flag.name = "ControlFlag"
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(3.8, 1.7, 0.08)
	flag.mesh = flag_mesh
	flag.position = Vector3(2.0, 7.2, 0.0)
	flag.material_override = _flag_material
	add_child(flag)


func _refresh_colors() -> void:
	var solid := Color(0.80, 0.64, 0.24)
	if owner_team == 0:
		solid = Color(0.20, 0.66, 0.90)
	elif owner_team == 1:
		solid = Color(0.88, 0.24, 0.16)
	if _ring_material:
		_ring_material.albedo_color = Color(solid.r, solid.g, solid.b, 0.72)
	if _flag_material:
		_flag_material.albedo_color = solid
	for material in _marker_materials:
		material.albedo_color = Color(solid.r, solid.g, solid.b, 0.82)


func _material(color: Color, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _build_ring_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var segments := 64
	var half_width := 0.42
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ring_material)
	for index in range(segments):
		var angle_a := float(index) / float(segments) * TAU
		var angle_b := float(index + 1) / float(segments) * TAU
		var inner := capture_radius - half_width
		var outer := capture_radius + half_width
		var inner_a := Vector3(cos(angle_a) * inner, 0.28, sin(angle_a) * inner)
		var outer_a := Vector3(cos(angle_a) * outer, 0.28, sin(angle_a) * outer)
		var inner_b := Vector3(cos(angle_b) * inner, 0.28, sin(angle_b) * inner)
		var outer_b := Vector3(cos(angle_b) * outer, 0.28, sin(angle_b) * outer)
		mesh.surface_add_vertex(inner_a)
		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(outer_b)
		mesh.surface_add_vertex(inner_a)
		mesh.surface_add_vertex(outer_b)
		mesh.surface_add_vertex(inner_b)
	mesh.surface_end()
	return mesh
