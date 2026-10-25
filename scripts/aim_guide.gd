extends Node3D

var _line_instance: MeshInstance3D
var _area_instance: MeshInstance3D
var _target_marker: MeshInstance3D
var _impact_marker: MeshInstance3D
var _ready_material: StandardMaterial3D
var _reload_material: StandardMaterial3D
var _clamped_material: StandardMaterial3D
var _target_material: StandardMaterial3D
var _impact_material: StandardMaterial3D
var _spread_material: StandardMaterial3D
var _locked_material: StandardMaterial3D
var _focus := 0.0
var _pulse_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_line_instance = MeshInstance3D.new()
	_line_instance.name = "VolleyTrajectoryLines"
	add_child(_line_instance)
	_area_instance = MeshInstance3D.new()
	_area_instance.name = "BroadsideImpactArea"
	add_child(_area_instance)

	_target_marker = MeshInstance3D.new()
	_target_marker.name = "AimPointMarker"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.34
	marker_mesh.height = 0.68
	marker_mesh.radial_segments = 12
	marker_mesh.rings = 6
	_target_marker.mesh = marker_mesh
	add_child(_target_marker)

	_impact_marker = MeshInstance3D.new()
	_impact_marker.name = "AimImpactMarker"
	var impact_mesh := TorusMesh.new()
	impact_mesh.inner_radius = 0.62
	impact_mesh.outer_radius = 0.78
	impact_mesh.ring_segments = 36
	_impact_marker.mesh = impact_mesh
	_impact_marker.rotation = Vector3.ZERO
	add_child(_impact_marker)

	_ready_material = _make_material(Color(0.62, 1.0, 0.76, 0.72))
	_reload_material = _make_material(Color(1.0, 0.55, 0.24, 0.55))
	_clamped_material = _make_material(Color(1.0, 0.82, 0.34, 0.62))
	_target_material = _make_material(Color(0.94, 0.88, 0.50, 0.70))
	_impact_material = _make_material(Color(0.78, 0.96, 1.0, 0.82))
	_spread_material = _make_material(Color(0.28, 0.78, 0.70, 0.16))
	_locked_material = _make_material(Color(1.0, 0.70, 0.22, 0.24))
	_target_marker.material_override = _target_material
	_impact_marker.material_override = _impact_material
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	var pulse := 1.0 + sin(_pulse_time * (5.5 if _focus >= 0.82 else 3.2)) * (0.035 if _focus >= 0.82 else 0.018)
	_impact_marker.scale *= pulse / maxf(float(_impact_marker.get_meta("previous_pulse", 1.0)), 0.01)
	_impact_marker.set_meta("previous_pulse", pulse)


func show_solution(ship: Node, side: int, aim_point: Vector3, ready: bool) -> void:
	if ship == null or side == 0:
		hide_solution()
		return

	var solution := _get_solution(ship, side, aim_point)
	var lines: Array = solution.get("lines", [])
	if lines.is_empty():
		hide_solution()
		return

	visible = true
	_target_marker.global_position = aim_point
	_target_marker.visible = true
	var impact_point: Vector3 = solution.get("impact_point", aim_point)
	_impact_marker.global_position = Vector3(impact_point.x, maxf(impact_point.y, 0.04), impact_point.z)
	var area_radius := float(solution.get("area_radius", 1.0))
	_focus = float(solution.get("focus", 0.0))
	_area_instance.mesh = _build_area_mesh(ship.global_position, aim_point, area_radius, _locked_material if _focus >= 0.82 and ready else _spread_material)
	_area_instance.visible = true
	_impact_marker.scale = Vector3.ONE * clampf(area_radius / 0.78, 1.0, 24.0)
	_impact_marker.set_meta("previous_pulse", 1.0)
	_target_marker.scale = Vector3.ONE * lerpf(1.55, 0.62, _focus)
	_impact_marker.visible = true
	var material := _clamped_material if bool(solution.get("is_clamped", false)) else (_ready_material if ready else _reload_material)
	_line_instance.mesh = _build_line_mesh(lines, material)


func hide_solution() -> void:
	visible = false
	if _area_instance:
		_area_instance.visible = false


func _get_solution(ship: Node, side: int, aim_point: Vector3) -> Dictionary:
	if ship.has_method("get_cannon_aim_solution"):
		return ship.get_cannon_aim_solution(side, aim_point)
	if ship.has_method("get_cannon_preview_points"):
		var points: PackedVector3Array = ship.get_cannon_preview_points(side, aim_point)
		var impact_point := aim_point
		if points.size() > 0:
			impact_point = points[points.size() - 1]
		return {
			"lines": [points],
			"impact_point": impact_point,
			"is_clamped": false,
		}
	return {}


func _build_line_mesh(lines: Array, material: Material) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for raw_points in lines:
		var points: PackedVector3Array = raw_points
		if points.size() < 2:
			continue
		for i in range(points.size() - 1):
			mesh.surface_add_vertex(points[i])
			mesh.surface_add_vertex(points[i + 1])
	mesh.surface_end()
	return mesh


func _build_area_mesh(ship_position: Vector3, center: Vector3, radius: float, material: Material) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var forward := center - ship_position
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var tangent := Vector3(forward.z, 0.0, -forward.x)
	var longitudinal_radius := maxf(radius * 0.48, 0.85)
	var lateral_radius := maxf(radius, 0.85)
	var flat_center := Vector3(center.x, 0.055, center.z)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	var segments := 40
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var point_a := flat_center + tangent * cos(angle_a) * lateral_radius + forward * sin(angle_a) * longitudinal_radius
		var point_b := flat_center + tangent * cos(angle_b) * lateral_radius + forward * sin(angle_b) * longitudinal_radius
		mesh.surface_add_vertex(flat_center)
		mesh.surface_add_vertex(point_a)
		mesh.surface_add_vertex(point_b)
	mesh.surface_end()
	return mesh


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material
