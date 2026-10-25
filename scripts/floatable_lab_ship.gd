extends "res://addons/floatable_body/floatable_body_3d.gd"
class_name FloatableLabShip

const PlayerShipVisual := preload("res://scripts/player_ship.gd")
const SAIL_STEPS := [0.0, 0.38, 0.68, 1.0]
const SAIL_LABELS := ["Furled", "Battle", "Half", "Full"]

@export var hull_class := "Brig"
@export var max_speed := 8.0
@export var wind_direction := Vector3(0.85, 0.0, -0.35).normalized()
@export var wind_strength := 1.0
@export var ocean_sea_state := 0.95
@export var ocean_wave_speed := 1.0
@export var ocean_wave_chop := 0.90

var sail_step_index := 1
var sail_setting := 0.38
var current_rudder := 0.0
var target_rudder := 0.0
var speed := 0.0
var lateral_slip := 0.0

var _hull_width := 3.2
var _hull_length := 8.4
var _hull_depth := 1.45
var _maximum_sail_force := 100.0
var _forward_drag := 1.55
var _keel_drag := 42.0
var _rudder_force := 0.44
var _yaw_drag := 175.0
var _roll_damping := 4.2
var _rudder_response := 1.85
var _target_draft := 0.68
var _vertical_water_damping := 4.4
var _maximum_yaw_rate := 0.44
var _turn_response := 1.75
var _buoyancy_local_points: Array[Vector3] = []
var _buoyancy_weights := PackedFloat32Array()
var _buoyancy_weight_total := 0.0
var _last_water_normal := Vector3.UP
var _last_surface_velocity := Vector3.ZERO
var _bow_wave_impact := 0.0
var _bow_wave_contact := 0.0
var _water_spawn_pending := true
var _water_spawn_wait := 0.0
var _visual_ship: Node3D
var _wake_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_configure_profile()
	_build_physics_hull()
	super._ready()
	fluid_damp = 0.0
	continuous_cd = true
	can_sleep = false
	linear_damp = 0.015
	angular_damp = 0.025
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -_hull_depth * 0.34, 0.12)
	_configure_buoyancy_points()
	_build_visual_ship()
	prepare_water_spawn()


func _physics_process(delta: float) -> void:
	if _water_spawn_pending:
		_update_water_spawn(delta)
		return
	_update_controls(delta)
	_apply_floatable_body_buoyancy()
	_apply_hydrodynamic_forces()
	_update_readings()
	_update_wake_feedback()


func prepare_water_spawn() -> void:
	_water_spawn_pending = true
	_water_spawn_wait = 0.0
	freeze = true
	visible = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _update_water_spawn(delta: float) -> void:
	_water_spawn_wait += delta
	if _water_spawn_wait < 0.12:
		return
	var fluid_area := _find_spawn_fluid()
	if fluid_area == null:
		return
	if fluid_area.has_method("is_surface_ready") and not bool(fluid_area.call("is_surface_ready")):
		return
	_snap_to_water_surface(fluid_area)
	_water_spawn_pending = false
	freeze = false
	visible = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_surface_velocity = Vector3.ZERO
	_last_water_normal = Vector3.UP
	reset_physics_interpolation()


func _find_spawn_fluid() -> Node:
	if fluid_interactor.fluid_area != null:
		return fluid_interactor.fluid_area
	var fft_fluids := get_tree().get_nodes_in_group("fft_wave_fluid")
	if not fft_fluids.is_empty():
		return fft_fluids[0]
	for candidate in get_tree().root.find_children("*", "Area3D", true, false):
		if candidate is FluidArea3D:
			return candidate
	return null


func _snap_to_water_surface(fluid_area: Node) -> void:
	var yaw := rotation.y
	rotation = Vector3(0.0, yaw, 0.0)
	var level_basis := global_transform.basis.orthonormalized()
	var required_y_total := 0.0
	var sample_weight_total := 0.0
	for index in range(_buoyancy_local_points.size()):
		var local_point := _buoyancy_local_points[index]
		var horizontal_offset := level_basis * Vector3(local_point.x, 0.0, local_point.z)
		var sample_position := Vector3(global_position.x + horizontal_offset.x, 0.0, global_position.z + horizontal_offset.z)
		var water_height := float(fluid_area.call("get_surface_sample", sample_position).get("height", -0.18)) if fluid_area.has_method("get_surface_sample") else float(fluid_area.call("get_height", sample_position))
		var weight := float(_buoyancy_weights[index])
		required_y_total += (water_height - _target_draft - local_point.y) * weight
		sample_weight_total += weight
	if sample_weight_total > 0.01:
		global_position.y = required_y_total / sample_weight_total + 0.08


func _update_controls(delta: float) -> void:
	if Input.is_action_just_pressed("sail_up"):
		set_sail_step(sail_step_index + 1)
	elif Input.is_action_just_pressed("sail_down"):
		set_sail_step(sail_step_index - 1)

	target_rudder = Input.get_action_strength("rudder_left") - Input.get_action_strength("rudder_right")
	current_rudder = move_toward(current_rudder, target_rudder, _rudder_response * delta)


func _apply_floatable_body_buoyancy() -> void:
	var fluid_area: FluidArea3D = fluid_interactor.fluid_area
	if fluid_area == null or _buoyancy_local_points.is_empty():
		return
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * gravity_scale
	var heavy_sea_ratio := clampf((ocean_sea_state - 1.20) / 1.95, 0.0, 1.0)
	var class_scale := clampf((_hull_length - 6.6) / (18.4 - 6.6), 0.0, 1.0)
	var normal_sum := Vector3.ZERO
	var surface_velocity_sum := Vector3.ZERO
	var immersed_weight := 0.0
	var bow_impact_target := 0.0
	var bow_contact_target := 0.0
	for index in range(_buoyancy_local_points.size()):
		var local_point := _buoyancy_local_points[index]
		var world_point: Vector3 = global_transform * local_point
		var sample := fluid_area.call("get_surface_sample", world_point) as Dictionary if fluid_area.has_method("get_surface_sample") else {
			"height": fluid_area.get_height(world_point),
			"normal": Vector3.UP,
			"velocity": Vector3(0.0, float(fluid_area.call("get_vertical_velocity", world_point)) if fluid_area.has_method("get_vertical_velocity") else 0.0, 0.0),
		}
		var water_height := float(sample.get("height", -0.18))
		var water_normal := Vector3(sample.get("normal", Vector3.UP)).normalized()
		var surface_velocity := Vector3(sample.get("velocity", Vector3.ZERO))
		var depth := water_height - world_point.y
		if depth <= 0.0:
			continue
		var offset := world_point - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(offset)
		var relative_velocity := point_velocity - surface_velocity
		var submergence := depth / maxf(_target_draft, 0.1)
		var excess := maxf(submergence - 1.0, 0.0)
		var support_curve := minf(submergence, 1.0) + excess * 1.65 + excess * excess * lerpf(0.55, 0.88, heavy_sea_ratio)
		var point_weight := float(_buoyancy_weights[index])
		var support_force := mass * gravity * point_weight / maxf(_buoyancy_weight_total, 0.01)
		var spring_force := support_force * clampf(support_curve, 0.0, lerpf(3.2, 4.8, heavy_sea_ratio))
		var normal_speed := relative_velocity.dot(water_normal)
		var point_damping := mass * _vertical_water_damping * point_weight / maxf(_buoyancy_weight_total, 0.01)
		var damping_force := -normal_speed * point_damping * lerpf(0.72, 1.05, heavy_sea_ratio)
		var bow_factor := clampf((-local_point.z / maxf(_hull_length, 0.1) - 0.18) / 0.34, 0.0, 1.0)
		var entry_speed := maxf(-normal_speed - lerpf(0.70, 1.05, class_scale), 0.0)
		var slamming_force := minf(entry_speed * entry_speed * mass * bow_factor * 0.055, support_force * 1.65)
		if bow_factor > 0.0:
			var contact_ratio := clampf(submergence / 1.18, 0.0, 1.35) * bow_factor
			var entry_threshold := lerpf(2.15, 1.55, class_scale)
			var impact_ratio := clampf(entry_speed / entry_threshold, 0.0, 1.35) * contact_ratio
			bow_contact_target = maxf(bow_contact_target, contact_ratio)
			bow_impact_target = maxf(bow_impact_target, impact_ratio)
		var pressure := maxf(spring_force + damping_force + slamming_force, 0.0)
		var pressure_direction := Vector3.UP.lerp(water_normal, lerpf(0.22, 0.12, class_scale)).normalized()
		apply_force(pressure_direction * pressure, offset)
		normal_sum += water_normal * point_weight
		surface_velocity_sum += surface_velocity * point_weight
		immersed_weight += point_weight
	if immersed_weight > 0.01:
		_last_water_normal = (normal_sum / immersed_weight).normalized()
		_last_surface_velocity = surface_velocity_sum / immersed_weight
	else:
		_last_water_normal = _last_water_normal.slerp(Vector3.UP, 0.08)
		_last_surface_velocity = _last_surface_velocity.lerp(Vector3.ZERO, 0.08)
	var impact_blend := 0.48 if bow_impact_target > _bow_wave_impact else 0.075
	_bow_wave_impact = lerpf(_bow_wave_impact, clampf(bow_impact_target, 0.0, 1.0), impact_blend)
	_bow_wave_contact = lerpf(_bow_wave_contact, clampf(bow_contact_target, 0.0, 1.0), 0.18)
	var wave_alignment := lerpf(0.34, 0.12, class_scale) * lerpf(0.68, 1.0, heavy_sea_ratio)
	var desired_up := Vector3.UP.lerp(_last_water_normal, wave_alignment).normalized()
	var righting_lever := lerpf(0.82, 1.42, class_scale)
	var hull_up := global_transform.basis.orthonormalized().y
	apply_torque(hull_up.cross(desired_up) * mass * gravity * righting_lever)
	var rotational_damping := lerpf(0.72, 1.18, class_scale) * lerpf(0.92, 1.16, heavy_sea_ratio)
	var water_rotation_damping := Vector3(
		-angular_velocity.x * mass * _roll_damping * rotational_damping,
		0.0,
		-angular_velocity.z * mass * _roll_damping * rotational_damping
	)
	apply_torque(water_rotation_damping)
	_apply_heavy_sea_stability(gravity, heavy_sea_ratio, class_scale)


func _apply_heavy_sea_stability(gravity: float, heavy_sea_ratio: float, class_scale: float) -> void:
	var hull_basis := global_transform.basis.orthonormalized()
	var pitch := asin(clampf(hull_basis.z.y, -1.0, 1.0))
	var roll := asin(clampf(hull_basis.x.y, -1.0, 1.0))
	var soft_pitch_limit := lerpf(deg_to_rad(27.0), deg_to_rad(18.0), class_scale)
	var soft_roll_limit := lerpf(deg_to_rad(32.0), deg_to_rad(21.0), class_scale)
	var pitch_excess := maxf(absf(pitch) - soft_pitch_limit, 0.0)
	var roll_excess := maxf(absf(roll) - soft_roll_limit, 0.0)
	if pitch_excess > 0.0:
		apply_torque(hull_basis.x * signf(pitch) * pitch_excess * mass * gravity * lerpf(4.2, 8.0, class_scale))
	if roll_excess > 0.0:
		apply_torque(hull_basis.z * -signf(roll) * roll_excess * mass * gravity * lerpf(5.4, 10.0, class_scale))
	var angular_limit := lerpf(0.72, 0.38, class_scale) * lerpf(1.0, 1.16, heavy_sea_ratio)
	angular_velocity.x = clampf(angular_velocity.x, -angular_limit, angular_limit)
	angular_velocity.z = clampf(angular_velocity.z, -angular_limit, angular_limit)


func _apply_hydrodynamic_forces() -> void:
	var ship_basis := global_transform.basis.orthonormalized()
	var forward := -ship_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := ship_basis.x
	right.y = 0.0
	right = right.normalized()
	if forward.length_squared() < 0.5 or right.length_squared() < 0.5:
		return

	var forward_speed := (linear_velocity - _last_surface_velocity).dot(forward)
	var wind_efficiency := _get_wind_efficiency(forward)
	var sail_force := _maximum_sail_force * sail_setting * wind_efficiency * wind_strength
	apply_central_force(forward * sail_force)

	var forward_resistance := -signf(forward_speed) * forward_speed * forward_speed * _forward_drag
	apply_central_force(forward * forward_resistance)

	var bow_offset := ship_basis * Vector3(0.0, -_hull_depth * 0.18, -_hull_length * 0.31)
	var stern_offset := ship_basis * Vector3(0.0, -_hull_depth * 0.18, _hull_length * 0.36)
	_apply_keel_force(bow_offset, right, _last_surface_velocity)
	_apply_keel_force(stern_offset, right, _last_surface_velocity)

	var rudder_authority := maxf(absf(forward_speed), max_speed * 0.28)
	var rudder_magnitude := current_rudder * rudder_authority * rudder_authority * _rudder_force
	apply_force(right * rudder_magnitude, stern_offset)

	var speed_ratio := clampf(absf(forward_speed) / maxf(max_speed, 0.1), 0.0, 1.0)
	var steering_authority := lerpf(0.34, 1.0, sqrt(speed_ratio))
	var target_yaw_rate := current_rudder * _maximum_yaw_rate * steering_authority
	var yaw_inertia := mass * (_hull_length * _hull_length + _hull_width * _hull_width) / 12.0
	var steering_torque := (target_yaw_rate - angular_velocity.y) * yaw_inertia * _turn_response
	apply_torque(Vector3.UP * (steering_torque - angular_velocity.y * _yaw_drag))


func _apply_keel_force(offset: Vector3, right: Vector3, water_velocity := Vector3.ZERO) -> void:
	var point_velocity := linear_velocity + angular_velocity.cross(offset) - water_velocity
	var side_speed := point_velocity.dot(right)
	var resistance := -side_speed * _keel_drag * (1.0 + absf(side_speed) * 0.20)
	apply_force(right * resistance, offset)


func _update_readings() -> void:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	speed = linear_velocity.dot(forward)
	lateral_slip = linear_velocity.dot(right)


func _update_wake_feedback() -> void:
	var speed_ratio := clampf(absf(speed) / maxf(max_speed, 0.1), 0.0, 1.0)
	if is_instance_valid(_visual_ship) and _visual_ship.has_method("set_external_water_feedback"):
		_visual_ship.call("set_external_water_feedback", speed_ratio, _bow_wave_impact, _bow_wave_contact)
	for index in range(_wake_meshes.size()):
		var wake := _wake_meshes[index]
		if not is_instance_valid(wake):
			continue
		var material := wake.material_override as StandardMaterial3D
		if material == null:
			continue
		var color := material.albedo_color
		color.a = speed_ratio * (0.72 if index < 2 else 0.48)
		material.albedo_color = color


func _get_wind_efficiency(forward: Vector3) -> float:
	var wind := wind_direction
	wind.y = 0.0
	if wind.length_squared() < 0.01:
		return 1.0
	wind = wind.normalized()
	var headwind := clampf(forward.dot(-wind), -1.0, 1.0)
	var beam_reach := absf(forward.dot(Vector3(-wind.z, 0.0, wind.x)))
	return clampf(0.72 - maxf(headwind, 0.0) * 0.14 + beam_reach * 0.28, 0.58, 1.0)


func set_sail_step(step: int) -> void:
	sail_step_index = clampi(step, 0, SAIL_STEPS.size() - 1)
	sail_setting = float(SAIL_STEPS[sail_step_index])
	if is_instance_valid(_visual_ship) and _visual_ship.has_method("set_sail_step"):
		_visual_ship.set_sail_step(sail_step_index, true)


func apply_storm_breaker_impact(direction: Vector3, scale: float, braced: bool) -> void:
	var horizontal_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if horizontal_direction.length_squared() < 0.01:
		horizontal_direction = Vector3.FORWARD
	var protection := 0.28 if braced else 1.0
	var impulse_strength := mass * lerpf(1.05, 1.65, clampf((scale - 0.8) / 0.6, 0.0, 1.0)) * protection
	apply_central_impulse((horizontal_direction * 0.72 + Vector3.UP * 0.44).normalized() * impulse_strength)
	var local_wave := global_transform.basis.inverse() * horizontal_direction
	var roll_side := signf(local_wave.x) if absf(local_wave.x) > 0.08 else 1.0
	apply_torque_impulse(Vector3(0.0, mass * 0.035 * roll_side, -mass * 0.34 * roll_side) * scale * protection)
	linear_velocity *= 0.92 if braced else 0.78


func get_telemetry() -> Dictionary:
	return {
		"name": "Handling Lab %s" % hull_class,
		"hull_class": hull_class,
		"speed": speed,
		"target_speed": max_speed * sail_setting,
		"sail": sail_setting,
		"sail_state": SAIL_LABELS[sail_step_index],
		"rudder": current_rudder,
		"target_rudder": target_rudder,
		"lateral_slip": lateral_slip,
		"wind_efficiency": _get_wind_efficiency(-global_transform.basis.z.normalized()),
	}


func _configure_profile() -> void:
	match hull_class:
		"Frigate":
			mass = 150.0
			_hull_width = 3.75
			_hull_length = 10.7
			_hull_depth = 1.65
			max_speed = 8.0
			_maximum_sail_force = 300.0
			_forward_drag = 4.0
			_keel_drag = 34.0
			_rudder_force = 0.92
			_yaw_drag = 180.0
			_roll_damping = 4.8
			_rudder_response = 1.55
			_target_draft = 0.86
			_maximum_yaw_rate = 0.38
			_turn_response = 1.55
		"Ship of the Line":
			mass = 300.0
			_hull_width = 5.05
			_hull_length = 14.2
			_hull_depth = 2.35
			max_speed = 7.1
			_maximum_sail_force = 650.0
			_forward_drag = 10.0
			_keel_drag = 50.0
			_rudder_force = 3.40
			_yaw_drag = 330.0
			_roll_damping = 5.6
			_rudder_response = 1.24
			_target_draft = 1.15
			_maximum_yaw_rate = 0.30
			_turn_response = 1.28
		"Man o' War":
			mass = 450.0
			_hull_width = 6.25
			_hull_length = 17.4
			_hull_depth = 2.95
			max_speed = 6.3
			_maximum_sail_force = 1000.0
			_forward_drag = 19.0
			_keel_drag = 64.0
			_rudder_force = 7.20
			_yaw_drag = 480.0
			_roll_damping = 6.4
			_rudder_response = 1.02
			_target_draft = 1.42
			_maximum_yaw_rate = 0.25
			_turn_response = 1.08
		_:
			hull_class = "Brig"
			mass = 90.0
			_hull_width = 3.2
			_hull_length = 8.4
			_hull_depth = 1.45
			max_speed = 8.7
			_maximum_sail_force = 170.0
			_forward_drag = 2.0
			_keel_drag = 24.0
			_rudder_force = 0.44
			_yaw_drag = 90.0
			_roll_damping = 4.2
			_rudder_response = 1.85
			_target_draft = 0.68
			_maximum_yaw_rate = 0.44
			_turn_response = 1.75


func _build_physics_hull() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PhysicsHull"
	var shape := BoxShape3D.new()
	shape.size = Vector3(_hull_width * 0.82, _hull_depth * 0.82, _hull_length * 0.88)
	collision.shape = shape
	collision.position.y = -_hull_depth * 0.28
	add_child(collision)


func _configure_buoyancy_points() -> void:
	fluid_interactor.clear_floaters()
	_buoyancy_local_points.clear()
	_buoyancy_weights = PackedFloat32Array()
	_buoyancy_weight_total = 0.0
	var point_y := -_hull_depth * 0.28
	var half_width := _hull_width * 0.34
	var stations := [-0.48, -0.34, -0.16, 0.06, 0.25, 0.43]
	var beam_factors := [0.38, 0.72, 0.96, 1.0, 0.84, 0.56]
	for index in range(stations.size()):
		var station := float(stations[index])
		var beam_factor := float(beam_factors[index])
		var point_weight := lerpf(0.58, 1.0, beam_factor)
		for side in [-1.0, 1.0]:
			var point := Vector3(half_width * beam_factor * side, point_y, _hull_length * station)
			_buoyancy_local_points.append(point)
			_buoyancy_weights.append(point_weight)
			_buoyancy_weight_total += point_weight
			fluid_interactor.add_floater(point)
	for station in [-0.52, 0.46]:
		var point := Vector3(0.0, point_y + _hull_depth * 0.08, _hull_length * float(station))
		_buoyancy_local_points.append(point)
		_buoyancy_weights.append(0.34)
		_buoyancy_weight_total += 0.34
		fluid_interactor.add_floater(point)


func _build_visual_ship() -> void:
	_visual_ship = PlayerShipVisual.new()
	_visual_ship.name = "ShipVisual"
	_visual_ship.set("hull_class", hull_class)
	_visual_ship.set("display_name", "Handling Lab %s" % hull_class)
	_visual_ship.set("accepts_player_input", false)
	_visual_ship.call("set_ocean_wave_profile", ocean_sea_state, ocean_wave_speed, ocean_wave_chop)
	add_child(_visual_ship)
	_visual_ship.set("collision_layer", 0)
	_visual_ship.set("collision_mask", 0)
	_visual_ship.remove_from_group("ships")
	_visual_ship.remove_from_group("combat_ships")
	for child in _visual_ship.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	_visual_ship.process_mode = Node.PROCESS_MODE_DISABLED
	set_sail_step(sail_step_index)
	for wake_name in ["PortWake", "StarboardWake", "SternTurbulence"]:
		var wake := _visual_ship.find_child(wake_name, true, false) as MeshInstance3D
		if wake != null:
			_wake_meshes.append(wake)
