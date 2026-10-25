extends StaticBody3D

signal sunk(target: Node)
signal health_changed(current: float, maximum: float)
signal phase_changed(target: Node, phase: int)
signal capture_started(target: Node)
signal capture_stage_changed(target: Node, stage: int)
signal capture_completed(target: Node)

const Cannonball := preload("res://scripts/cannonball.gd")
const CombatFx := preload("res://scripts/combat_fx.gd")

@export var display_name := "Blackglass Bastion"
@export var team_id := 1
@export var max_health := 520.0
@export var fire_range := 255.0
@export var reload_time := 5.4
@export var battery_count := 3
@export var fort_style := "citadel"

var health := max_health
var is_sunk := false
var is_incapacitated := false
var accepts_player_input := false
var velocity := Vector3.ZERO
var hull_class := "Coastal Fort"
var _hull_length := 25.0
var _hull_width := 18.0
var max_sail_integrity := 1.0
var sail_integrity := 1.0
var _reload := 2.2
var _battery_points: Array[Vector3] = []
var _battery_nodes: Array[Node3D] = []
var _battery_health: Array[float] = []
var _battery_max_health := 1.0
var _damage_sections: Array[Node3D] = []
var fort_phase := 0
var _keep_health := 1.0
var _keep_max_health := 1.0
var _magazine_health := 1.0
var _magazine_max_health := 1.0
var _keep_node: Node3D
var _magazine_node: Node3D
var _flag_node: MeshInstance3D
var capture_sequence_active := false
var capture_progress := 0.0
var capture_stage := -1
var capture_duration := 5.4
var is_captured := false
var _flag_base_position := Vector3.ZERO
var _capture_material: StandardMaterial3D


func configure_fort(data: Dictionary) -> void:
	display_name = String(data.get("name", display_name))
	max_health = float(data.get("health", max_health))
	health = max_health
	fire_range = float(data.get("range", fire_range))
	reload_time = float(data.get("reload", reload_time))
	battery_count = clampi(int(data.get("guns", battery_count)), 1, 5)
	fort_style = String(data.get("style", fort_style))
	if fort_style == "tower":
		_hull_length = 13.0
		_hull_width = 13.0
	elif fort_style == "battery":
		_hull_length = 24.0
		_hull_width = 11.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 1
	collision_mask = 1
	add_to_group("ships")
	add_to_group("enemies")
	add_to_group("scenario_fort")
	_build_collision()
	_build_visual()
	_initialize_phase_health()


func _physics_process(delta: float) -> void:
	if is_sunk:
		return
	if capture_sequence_active:
		_update_capture_sequence(delta)
		return
	_reload = maxf(_reload - delta, 0.0)
	if _reload > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_fire_battery(target)
	_reload = reload_time


func _find_target() -> Node3D:
	var best: Node3D
	var best_distance := fire_range
	for node in get_tree().get_nodes_in_group("ships"):
		if node == self or not (node is Node3D) or bool(node.get("is_sunk")):
			continue
		if int(node.get("team_id")) == team_id:
			continue
		var distance := global_position.distance_to(node.global_position)
		if distance < best_distance:
			best = node as Node3D
			best_distance = distance
	return best


func _fire_battery(target: Node3D) -> void:
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	var target_velocity: Vector3 = target.get("velocity") if target.get("velocity") is Vector3 else Vector3.ZERO
	for index in range(_battery_points.size()):
		if index >= _battery_health.size() or _battery_health[index] <= 0.0:
			continue
		var muzzle := to_global(_battery_points[index])
		var distance := muzzle.distance_to(target.global_position)
		var aim := target.global_position + target_velocity * clampf(distance / 50.0, 0.15, 1.2)
		aim += Vector3(randf_range(-5.5, 5.5), randf_range(-0.35, 1.2), randf_range(-5.5, 5.5))
		var direction := (aim - muzzle).normalized()
		var projectile := Cannonball.acquire(scene, "round", {
			"hit_radius": 1.15,
			"salvo_id": get_instance_id() * 1000 + Engine.get_physics_frames(),
			"salvo_critical": false,
		})
		if projectile == null:
			continue
		projectile.global_position = muzzle
		projectile.launch(direction, Vector3.ZERO, 48.0, self, 7.2, 4.0)
		CombatFx.spawn_muzzle_burst(scene, muzzle, direction)


func take_projectile_hit(amount: float, source: Node, hit_position: Vector3, incoming_direction: Vector3, _shot_mode := "round", _profile := {}) -> Dictionary:
	if is_sunk:
		return {"health_damage": 0.0, "zone": "ruins", "source": source}
	CombatFx.spawn_hull_hit(get_tree().current_scene if get_tree().current_scene else get_parent(), hit_position, incoming_direction)
	var before := health
	var zone := "main keep"
	if is_captured:
		_damage_captured_fort(maxf(amount, 0.0))
		zone = "captured battery"
	elif fort_phase == 0:
		var battery_index := _nearest_active_battery(hit_position)
		if battery_index >= 0:
			var distance := hit_position.distance_to(to_global(_battery_points[battery_index]))
			var accuracy_bonus := 1.35 if distance <= 4.8 else 0.82
			_damage_battery(battery_index, maxf(amount, 0.0) * accuracy_bonus)
			zone = "shore gun"
	elif fort_phase == 1:
		_damage_keep(maxf(amount, 0.0))
	elif fort_phase == 2:
		_damage_magazine(maxf(amount, 0.0) * 1.35)
		zone = "powder magazine"
	return {"health_damage": maxf(before - health, 0.0), "zone": zone, "source": source}


func take_hit(amount: float, source: Node = null, _hit_position := Vector3.ZERO, _incoming_direction := Vector3.ZERO) -> void:
	take_damage(amount, source)


func take_damage(amount: float, _source: Node = null) -> void:
	if is_sunk:
		return
	if is_captured:
		_damage_captured_fort(maxf(amount, 0.0))
		return
	var remaining := maxf(amount, 0.0)
	while remaining > 0.001 and not is_sunk:
		if fort_phase == 0:
			var index := _first_active_battery()
			if index < 0:
				_advance_phase(1)
				continue
			var applied := minf(remaining, _battery_health[index])
			_damage_battery(index, applied)
			remaining -= applied
		elif fort_phase == 1:
			var applied := minf(remaining, _keep_health)
			_damage_keep(applied)
			remaining -= applied
		elif fort_phase == 2:
			var applied := minf(remaining, _magazine_health)
			_damage_magazine(applied)
			remaining -= applied
		else:
			break


func is_projectile_point_inside(world_point: Vector3, _shot_mode := "round") -> bool:
	var local := to_local(world_point)
	return absf(local.x) <= 10.5 and local.y >= -1.0 and local.y <= 8.5 and absf(local.z) <= 8.0


func get_projectile_hit_radius(_shot_mode := "round") -> float:
	return 10.0


func get_ai_state_name() -> String:
	if is_captured:
		return "%d allied shore guns" % _active_battery_count()
	match fort_phase:
		0:
			return "%d shore guns" % _active_battery_count()
		1:
			return "keep exposed"
		2:
			return "magazine exposed"
	return "captured fort"


func _initialize_phase_health() -> void:
	fort_phase = 0
	_battery_max_health = max_health * 0.35 / maxf(float(battery_count), 1.0)
	_battery_health.clear()
	for _index in range(battery_count):
		_battery_health.append(_battery_max_health)
	_keep_max_health = max_health * 0.45
	_keep_health = _keep_max_health
	_magazine_max_health = max_health * 0.20
	_magazine_health = _magazine_max_health
	_sync_total_health()


func _sync_total_health() -> void:
	var battery_total := 0.0
	for value in _battery_health:
		battery_total += value
	health = clampf(battery_total + _keep_health + _magazine_health, 0.0, max_health)
	health_changed.emit(health, max_health)


func _nearest_active_battery(world_hit: Vector3) -> int:
	var best_index := -1
	var best_distance := INF
	for index in range(_battery_health.size()):
		if _battery_health[index] <= 0.0:
			continue
		var distance := world_hit.distance_squared_to(to_global(_battery_points[index]))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func _first_active_battery() -> int:
	for index in range(_battery_health.size()):
		if _battery_health[index] > 0.0:
			return index
	return -1


func _active_battery_count() -> int:
	var count := 0
	for value in _battery_health:
		if value > 0.0:
			count += 1
	return count


func _damage_battery(index: int, amount: float) -> void:
	if index < 0 or index >= _battery_health.size() or _battery_health[index] <= 0.0:
		return
	_battery_health[index] = maxf(_battery_health[index] - amount, 0.0)
	if _battery_health[index] <= 0.0:
		_break_battery(index)
	_sync_total_health()
	if _active_battery_count() <= 0:
		_advance_phase(1)


func _break_battery(index: int) -> void:
	if index < 0 or index >= _battery_nodes.size():
		return
	var mount := _battery_nodes[index]
	mount.rotation.z = randf_range(-0.22, 0.22)
	mount.rotation.x += randf_range(-0.10, 0.16)
	mount.position.y -= 0.42
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	CombatFx.spawn_powder_explosion(scene, to_global(_battery_points[index]), Vector3.UP)


func _damage_keep(amount: float) -> void:
	_keep_health = maxf(_keep_health - amount, 0.0)
	_sync_total_health()
	_update_damage_visuals()
	if _keep_health <= 0.0:
		_advance_phase(2)


func _damage_magazine(amount: float) -> void:
	_magazine_health = maxf(_magazine_health - amount, 0.0)
	_sync_total_health()
	if _magazine_health <= 0.0:
		_start_capture_sequence()


func _advance_phase(next_phase: int) -> void:
	if is_sunk or next_phase <= fort_phase:
		return
	fort_phase = next_phase
	if fort_phase == 1 and is_instance_valid(_keep_node):
		_keep_node.scale = Vector3(1.0, 0.96, 1.0)
	elif fort_phase == 2:
		if is_instance_valid(_keep_node):
			_keep_node.position += Vector3(4.6 if fort_style != "tower" else 3.2, -2.2, 0.0)
			_keep_node.rotation.z = 0.24 if fort_style != "tower" else 0.34
		if is_instance_valid(_magazine_node):
			_magazine_node.visible = true
		var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
		CombatFx.spawn_powder_explosion(scene, to_global(_magazine_node.position if is_instance_valid(_magazine_node) else Vector3(0.0, 3.0, -2.0)), Vector3.UP)
	phase_changed.emit(self, fort_phase)


func _start_capture_sequence() -> void:
	if is_sunk or capture_sequence_active:
		return
	capture_sequence_active = true
	capture_progress = 0.0
	capture_stage = -1
	fort_phase = 3
	_reload = 999.0
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	for offset in [Vector3(-2.4, 2.0, 0.0), Vector3(2.4, 2.4, 1.0)]:
		CombatFx.spawn_powder_explosion(scene, global_position + offset, Vector3.UP)
	phase_changed.emit(self, fort_phase)
	capture_started.emit(self)


func _update_capture_sequence(delta: float) -> void:
	capture_progress = minf(capture_progress + delta / maxf(capture_duration, 0.1), 1.0)
	var next_stage := 0 if capture_progress < 0.30 else (1 if capture_progress < 0.72 else 2)
	if next_stage != capture_stage:
		capture_stage = next_stage
		_apply_capture_stage(capture_stage)
		capture_stage_changed.emit(self, capture_stage)
	if is_instance_valid(_flag_node):
		if capture_stage <= 1:
			var lower_t := clampf(capture_progress / 0.52, 0.0, 1.0)
			_flag_node.position = _flag_base_position - Vector3.UP * lerpf(0.0, 2.8, lower_t)
			_flag_node.scale = Vector3(1.0, lerpf(1.0, 0.16, lower_t), 1.0)
		else:
			var raise_t := smoothstep(0.72, 1.0, capture_progress)
			_flag_node.position = _flag_base_position - Vector3.UP * lerpf(2.8, 0.0, raise_t)
			_flag_node.scale = Vector3(1.0, lerpf(0.16, 1.0, raise_t), 1.0)
	if capture_progress >= 1.0:
		_complete_capture()


func _apply_capture_stage(stage: int) -> void:
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	if stage == 1:
		for offset in [Vector3(-3.2, 3.6, 1.0), Vector3(0.0, 3.2, -0.5), Vector3(3.0, 3.5, 0.8)]:
			CombatFx.spawn_boarding_clash(scene, global_position + offset)
	elif stage == 2:
		if is_instance_valid(_flag_node):
			_flag_node.material_override = _capture_material
		CombatFx.spawn_boarding_capture(scene, global_position + Vector3.UP * 3.0)


func _complete_capture() -> void:
	if is_sunk or is_captured:
		return
	capture_sequence_active = false
	is_captured = true
	fort_phase = 4
	team_id = 0
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if not is_in_group("allies"):
		add_to_group("allies")
	if not is_in_group("combat_ships"):
		add_to_group("combat_ships")
	_restore_captured_battery()
	health = max_health * 0.32
	health_changed.emit(health, max_health)
	collision_layer = 1
	collision_mask = 1
	if is_instance_valid(_flag_node):
		_flag_node.material_override = _capture_material
		_flag_node.position = _flag_base_position
		_flag_node.scale = Vector3.ONE
	capture_completed.emit(self)


func _restore_captured_battery() -> void:
	var restored_count := maxi(1, ceili(float(battery_count) * 0.5))
	for index in range(_battery_health.size()):
		_battery_health[index] = _battery_max_health * 0.42 if index < restored_count else 0.0
		if index < _battery_nodes.size() and is_instance_valid(_battery_nodes[index]):
			var mount := _battery_nodes[index]
			mount.rotation = Vector3.ZERO
			mount.position.y = 0.0
	_reload = 1.2
	reload_time = maxf(reload_time * 1.12, 4.2)


func _damage_captured_fort(amount: float) -> void:
	if not is_captured or is_sunk or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health > 0.0:
		return
	is_sunk = true
	for index in range(_battery_health.size()):
		if _battery_health[index] > 0.0:
			_battery_health[index] = 0.0
			_break_battery(index)
	collision_layer = 0
	collision_mask = 0
	if is_in_group("combat_ships"):
		remove_from_group("combat_ships")
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	CombatFx.spawn_powder_explosion(scene, global_position + Vector3.UP * 3.5, Vector3.UP)
	sunk.emit(self)


func _update_damage_visuals() -> void:
	var ratio := _keep_health / maxf(_keep_max_health, 1.0)
	var broken_count := clampi(int(floor((1.0 - ratio) * float(_damage_sections.size()))), 0, _damage_sections.size())
	for index in range(_damage_sections.size()):
		var section := _damage_sections[index]
		if is_instance_valid(section):
			section.visible = index >= broken_count or index % 2 == 0


func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	if fort_style == "battery":
		shape.size = Vector3(24.0, 5.5, 11.0)
	elif fort_style == "tower":
		shape.size = Vector3(13.0, 12.0, 13.0)
	else:
		shape.size = Vector3(25.0, 10.0, 18.0)
	collider.shape = shape
	collider.position.y = shape.size.y * 0.42
	add_child(collider)


func _build_visual() -> void:
	var stone := _material(Color(0.075, 0.085, 0.088), 0.92)
	var edge := _material(Color(0.18, 0.19, 0.17), 0.88)
	var metal := _material(Color(0.045, 0.045, 0.04), 0.60)
	var gun_y := 3.5
	var gun_z := 8.0
	if fort_style == "battery":
		_keep_node = _add_box("BatteryWall", Vector3(24.0, 4.2, 9.0), Vector3(0.0, 1.7, 0.0), stone)
		_add_box("Earthwork", Vector3(27.0, 1.2, 12.0), Vector3(0.0, 0.1, -0.5), edge)
		gun_y = 3.6
		gun_z = 5.2
		for x in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
			_damage_sections.append(_add_box("BatteryMerlon", Vector3(1.4, 1.5, 1.4), Vector3(x, 4.4, 4.1), edge))
	elif fort_style == "tower":
		var tower := _add_cylinder("WatchTower", 6.2, 11.0, Vector3(0.0, 5.0, 0.0), stone)
		_keep_node = tower
		_damage_sections.append(tower)
		_add_cylinder("TowerCrown", 6.8, 1.0, Vector3(0.0, 10.8, 0.0), edge)
		gun_y = 8.4
		gun_z = 5.4
		for angle_index in range(8):
			var angle := float(angle_index) / 8.0 * TAU
			_damage_sections.append(_add_box("TowerMerlon", Vector3(1.3, 1.6, 1.3), Vector3(cos(angle) * 5.5, 11.8, sin(angle) * 5.5), edge))
	else:
		_keep_node = _add_box("Keep", Vector3(15.0, 7.2, 12.0), Vector3(0.0, 3.3, -1.0), stone)
		_add_box("SeaWall", Vector3(25.0, 5.0, 3.5), Vector3(0.0, 2.0, 7.0), stone)
		for side in [-1.0, 1.0]:
			var tower := _add_cylinder("Tower", 4.5, 8.5, Vector3(side * 9.5, 3.7, 4.2), stone)
			_damage_sections.append(tower)
			_add_cylinder("TowerCrown", 5.0, 0.9, Vector3(side * 9.5, 8.1, 4.2), edge)
		for x in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]:
			_damage_sections.append(_add_box("Merlon", Vector3(1.4, 1.6, 1.3), Vector3(x, 6.1, 7.8), edge))
		gun_y = 4.2
		gun_z = 9.0

	for index in range(battery_count):
		var x := (float(index) - float(battery_count - 1) * 0.5) * (4.0 if fort_style != "tower" else 2.8)
		var mount := Node3D.new()
		mount.name = "BatteryMount%d" % index
		mount.position.x = x
		add_child(mount)
		_add_box_to(mount, "GunCarriage", Vector3(1.35, 0.65, 2.25), Vector3(0.0, gun_y - 0.55, gun_z - 0.55), _material(Color(0.22, 0.10, 0.045), 0.86))
		var barrel := _add_cylinder_to(mount, "BatteryGun", 0.30, 3.6, Vector3(0.0, gun_y, gun_z), metal)
		barrel.rotation.x = PI * 0.5
		_battery_nodes.append(mount)
		_battery_points.append(Vector3(x, gun_y, gun_z + 2.0))
	_magazine_node = Node3D.new()
	_magazine_node.name = "PowderMagazine"
	_magazine_node.position = Vector3(0.0, 0.0, -2.6 if fort_style != "tower" else 0.0)
	add_child(_magazine_node)
	_add_box_to(_magazine_node, "MagazineVault", Vector3(5.2, 3.2, 4.5), Vector3(0.0, 1.8, 0.0), _material(Color(0.18, 0.075, 0.035), 0.90))
	var powder_target := _powder_target_material()
	for x in [-1.4, 0.0, 1.4]:
		_add_cylinder_to(_magazine_node, "PowderBarrel", 0.52, 1.65, Vector3(x, 3.2, 0.4), powder_target)
	_add_box_to(_magazine_node, "PowderCrates", Vector3(3.8, 1.1, 1.5), Vector3(0.0, 1.0, 2.3), powder_target)
	_magazine_node.visible = false
	var flag_height := 15.0 if fort_style == "tower" else (11.0 if fort_style == "citadel" else 8.0)
	var flagpole := _add_cylinder("Flagpole", 0.10, 8.0, Vector3(0.0, flag_height - 3.0, -1.0), edge)
	flagpole.rotation = Vector3.ZERO
	_flag_node = _add_box("FortFlag", Vector3(3.8, 1.9, 0.08), Vector3(2.0, flag_height, -1.0), _material(Color(0.60, 0.08, 0.055), 0.78))
	_flag_base_position = _flag_node.position
	_capture_material = _material(Color(0.08, 0.28, 0.62), 0.78)


func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	add_child(node)
	return node


func _add_cylinder(node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = position
	node.material_override = material
	add_child(node)
	return node


func _add_box_to(parent: Node, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


func _add_cylinder_to(parent: Node, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = 16
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


func _powder_target_material() -> StandardMaterial3D:
	var material := _material(Color(0.48, 0.12, 0.035), 0.78)
	material.emission_enabled = true
	material.emission = Color(0.42, 0.055, 0.012)
	material.emission_energy_multiplier = 1.35
	return material
