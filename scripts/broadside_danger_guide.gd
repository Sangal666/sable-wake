extends Node3D

var _line_instance: MeshInstance3D
var _fill_instance: MeshInstance3D
var _danger_material: StandardMaterial3D
var _danger_fill_material: StandardMaterial3D
var _reload_material: StandardMaterial3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_fill_instance = MeshInstance3D.new()
	_fill_instance.name = "BroadsideDangerFill"
	add_child(_fill_instance)

	_line_instance = MeshInstance3D.new()
	_line_instance.name = "BroadsideDangerLines"
	add_child(_line_instance)

	_danger_material = _make_material(Color(1.0, 0.18, 0.08, 0.62))
	_danger_fill_material = _make_material(Color(1.0, 0.12, 0.05, 0.18))
	_reload_material = _make_material(Color(1.0, 0.62, 0.16, 0.34))
	visible = false


func show_threats(enemy_nodes: Array, player: Node3D) -> void:
	if player == null:
		hide_threats()
		return

	var mesh := ImmediateMesh.new()
	var fill_mesh := ImmediateMesh.new()
	var has_lines := false
	var surface_open := false
	var fill_surface_open := false
	for enemy in enemy_nodes:
		if not _should_show_enemy(enemy, player):
			continue
		var side := _enemy_threat_side(enemy, player)
		if side == 0:
			continue
		if not surface_open:
			mesh.surface_begin(Mesh.PRIMITIVE_LINES, _danger_material)
			surface_open = true
		if not fill_surface_open:
			fill_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _danger_fill_material)
			fill_surface_open = true
		_add_lane(mesh, enemy, side)
		_add_lane_fill(fill_mesh, enemy, side)
		has_lines = true

	if not has_lines:
		hide_threats()
		return

	mesh.surface_end()
	fill_mesh.surface_end()
	_line_instance.mesh = mesh
	_fill_instance.mesh = fill_mesh
	visible = true


func hide_threats() -> void:
	visible = false
	if _line_instance:
		_line_instance.mesh = null
	if _fill_instance:
		_fill_instance.mesh = null


func _should_show_enemy(enemy: Node, player: Node3D) -> bool:
	if not is_instance_valid(enemy) or bool(enemy.get("is_sunk")):
		return false
	if enemy.global_position.distance_to(player.global_position) > 95.0:
		return false
	if enemy.has_method("get_ai_state_name") and String(enemy.get_ai_state_name()) == "broadside":
		return true
	return enemy.has_method("can_fire_side") and (enemy.can_fire_side(1) or enemy.can_fire_side(-1))


func _enemy_threat_side(enemy: Node3D, player: Node3D) -> int:
	var to_player := player.global_position - enemy.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.01:
		return 0
	var side_score := to_player.normalized().dot(enemy.global_transform.basis.x.normalized())
	if absf(side_score) < 0.35:
		return 0
	return 1 if side_score > 0.0 else -1


func _add_lane(mesh: ImmediateMesh, enemy: Node3D, side: int) -> void:
	var lane := _get_lane_points(enemy, side)
	var origin: Vector3 = lane["origin"]
	var far_center: Vector3 = lane["far_center"]
	var near_a: Vector3 = lane["near_a"]
	var near_b: Vector3 = lane["near_b"]
	var far_a: Vector3 = lane["far_a"]
	var far_b: Vector3 = lane["far_b"]
	var forward: Vector3 = lane["forward"]
	var lane_width_near: float = lane["lane_width_near"]
	var lane_width_far: float = lane["lane_width_far"]

	mesh.surface_add_vertex(near_a)
	mesh.surface_add_vertex(far_a)
	mesh.surface_add_vertex(near_b)
	mesh.surface_add_vertex(far_b)
	mesh.surface_add_vertex(far_a)
	mesh.surface_add_vertex(far_b)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(far_center)

	for i in range(1, 4):
		var t := float(i) / 4.0
		var center := origin.lerp(far_center, t)
		var width := lerpf(lane_width_near, lane_width_far, t)
		mesh.surface_add_vertex(center + forward * width)
		mesh.surface_add_vertex(center - forward * width)


func _add_lane_fill(mesh: ImmediateMesh, enemy: Node3D, side: int) -> void:
	var lane := _get_lane_points(enemy, side)
	mesh.surface_add_vertex(lane["near_a"])
	mesh.surface_add_vertex(lane["far_a"])
	mesh.surface_add_vertex(lane["far_b"])
	mesh.surface_add_vertex(lane["near_a"])
	mesh.surface_add_vertex(lane["far_b"])
	mesh.surface_add_vertex(lane["near_b"])


func _get_lane_points(enemy: Node3D, side: int) -> Dictionary:
	var side_dir := enemy.global_transform.basis.x.normalized() * float(side)
	var forward := -enemy.global_transform.basis.z.normalized()
	var origin := enemy.global_position + Vector3.UP * 0.045 + side_dir * 2.25
	var lane_length := 58.0
	var lane_width_near := 3.8
	var lane_width_far := 14.0
	var far_center := origin + side_dir * lane_length
	return {
		"side_dir": side_dir,
		"forward": forward,
		"origin": origin,
		"far_center": far_center,
		"near_a": origin + forward * lane_width_near,
		"near_b": origin - forward * lane_width_near,
		"far_a": far_center + forward * lane_width_far,
		"far_b": far_center - forward * lane_width_far,
		"lane_width_near": lane_width_near,
		"lane_width_far": lane_width_far,
	}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material
