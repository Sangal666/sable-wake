extends Camera3D

@export var target: Node3D
@export var follow_distance := 18.5
@export var speed_distance_bonus := 5.5
@export var height := 9.2
@export var speed_height_bonus := 2.2
@export var side_offset := 0.0
@export var turn_lead := 2.6
@export var look_ahead := 4.5
@export var mouse_sensitivity := 0.0032
@export var invert_y := false
@export var min_pitch := -0.35
@export var max_pitch := 0.92
@export var aim_follow_distance := 14.5
@export var aim_height := 6.8
@export var position_lerp := 6.2
@export var look_lerp := 8.0

var _look_target := Vector3.ZERO
var _base_fov := 62.0
var _yaw_offset := 0.0
var _pitch := 0.12
var _is_aiming := false
var _aim_side := 1
var _input_enabled := true
var _shake_strength := 0.0
var _recoil_kick := 0.0
var _roll_kick := 0.0
var _broadside_slide := 0.0
var _fov_kick := 0.0
var _hit_impulses := 0
var _near_miss_impulses := 0
var _boarding_focus_target: Node3D
var _boarding_stage := 0
var _boarding_view_side := 1.0
var _fort_capture_focus_target: Node3D
var _fort_capture_stage := 0
var _fort_capture_view_side := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 100
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = _base_fov
	near = 0.05
	far = 1200.0


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var telemetry := _get_target_telemetry()
	var speed_ratio := _get_speed_ratio(telemetry)
	var ship_scale := _get_ship_camera_scale(String(telemetry.get("hull_class", target.get("hull_class"))))
	var rudder := float(telemetry.get("rudder", 0.0))
	var ship_transform := target.get_global_transform_interpolated()
	var ship_position := ship_transform.origin
	var ship_basis := ship_transform.basis
	if _is_aiming:
		_update_aim_side(ship_basis)
	var back := ship_basis.z.normalized().rotated(Vector3.UP, _yaw_offset)
	var forward := -back.normalized()
	var base_distance := aim_follow_distance if _is_aiming else follow_distance
	var base_height := aim_height if _is_aiming else height
	var target_distance := base_distance * ship_scale + speed_ratio * speed_distance_bonus * lerpf(0.58, 1.0, ship_scale)
	var target_height := base_height * lerpf(0.67, 1.0, ship_scale) + speed_ratio * speed_height_bonus * ship_scale + _pitch * 7.0 * lerpf(0.72, 1.0, ship_scale)
	var focus_height := lerpf(0.92, 2.15, ship_scale)
	var maximum_clearance := 0.0
	match String(telemetry.get("hull_class", target.get("hull_class"))):
		"Frigate":
			maximum_clearance = 1.25
		"Ship of the Line":
			maximum_clearance = 2.8
		"Man o' War":
			maximum_clearance = 4.6
	var broadside_score := forward.dot(ship_basis.x.normalized())
	var clearance_strength := 1.0 if _is_aiming else smoothstep(0.22, 0.88, absf(broadside_score)) * 0.72
	var clearance_side := float(_aim_side) if _is_aiming else signf(broadside_score)
	var sail_clearance := maximum_clearance * clearance_strength
	target_height += sail_clearance * 0.42
	var clearance_offset := ship_basis.x.normalized() * clearance_side * sail_clearance
	var focus := ship_position + Vector3.UP * focus_height + clearance_offset * 0.28 + forward * ((look_ahead + speed_ratio * 2.5) * lerpf(0.70, 1.0, ship_scale))
	var desired := ship_position
	desired += back * target_distance
	desired += ship_basis.x.normalized() * (side_offset - rudder * turn_lead * (0.45 if _is_aiming else 1.0)) + clearance_offset
	desired += ship_basis.x.normalized() * _broadside_slide
	desired += Vector3.UP * (target_height + _recoil_kick)
	var boarding_focus := is_instance_valid(_boarding_focus_target)
	if boarding_focus:
		var boarding_transform := _boarding_focus_target.get_global_transform_interpolated()
		var boarding_position := boarding_transform.origin
		var midpoint := ship_position.lerp(boarding_position, 0.5)
		var separation := ship_position.distance_to(boarding_position)
		var boarding_axis := boarding_position - ship_position
		boarding_axis.y = 0.0
		if boarding_axis.length_squared() < 0.01:
			boarding_axis = ship_basis.x.normalized()
		else:
			boarding_axis = boarding_axis.normalized()
		var deck_side := Vector3(-boarding_axis.z, 0.0, boarding_axis.x) * _boarding_view_side
		var deck_height := lerpf(1.45, 2.75, ship_scale)
		if _boarding_stage == 0:
			focus = midpoint + Vector3.UP * deck_height
			desired = midpoint + deck_side * maxf(15.0 * ship_scale, separation * 0.62 + 10.0)
			desired += boarding_axis * 1.4
			desired.y = midpoint.y + 7.2 * lerpf(0.82, 1.0, ship_scale) + _recoil_kick
		elif _boarding_stage == 1:
			focus = midpoint + Vector3.UP * (deck_height * 0.92)
			desired = midpoint + deck_side * maxf(11.6 * ship_scale, separation * 0.48 + 7.2)
			desired -= boarding_axis * 0.9
			desired.y = midpoint.y + 5.6 * lerpf(0.84, 1.0, ship_scale) + _recoil_kick
		else:
			focus = midpoint.lerp(boarding_position, 0.28) + Vector3.UP * (deck_height * 0.82)
			desired = midpoint + deck_side * maxf(9.4 * ship_scale, separation * 0.42 + 6.0)
			desired += boarding_axis * 1.1
			desired.y = midpoint.y + 4.8 * lerpf(0.86, 1.0, ship_scale) + _recoil_kick
	var fort_capture_focus := is_instance_valid(_fort_capture_focus_target)
	if fort_capture_focus:
		var fort_transform := _fort_capture_focus_target.global_transform
		var fort_position := fort_transform.origin
		var fort_front := fort_transform.basis.z.normalized()
		var fort_side := fort_transform.basis.x.normalized() * _fort_capture_view_side
		if _fort_capture_stage == 0:
			focus = fort_position + Vector3.UP * 3.6
			desired = fort_position + fort_front * 24.0 + fort_side * 18.0 + Vector3.UP * 13.0
		elif _fort_capture_stage == 1:
			focus = fort_position + Vector3.UP * 3.2
			desired = fort_position + fort_front * 18.0 + fort_side * 13.0 + Vector3.UP * 9.5
		else:
			focus = fort_position + Vector3.UP * 5.4
			desired = fort_position + fort_front * 15.0 + fort_side * 9.0 + Vector3.UP * 8.0
	if _shake_strength > 0.001:
		desired += Vector3(randf_range(-1.0, 1.0), randf_range(-0.45, 0.45), randf_range(-1.0, 1.0)) * _shake_strength

	global_position = global_position.lerp(desired, 1.0 - exp(-position_lerp * delta))
	_look_target = _look_target.lerp(focus, 1.0 - exp(-look_lerp * delta))
	var target_fov := (_base_fov - 7.0 if _is_aiming else _base_fov + speed_ratio * 5.0)
	if boarding_focus:
		target_fov = 66.0 if _boarding_stage == 0 else (59.0 if _boarding_stage == 1 else 54.0)
	if fort_capture_focus:
		target_fov = 62.0 if _fort_capture_stage == 0 else (56.0 if _fort_capture_stage == 1 else 51.0)
	fov = lerpf(fov, target_fov + _shake_strength * 1.6 + _fov_kick, 1.0 - exp(-5.2 * delta))
	look_at(_look_target, Vector3.UP)
	if absf(_roll_kick) > 0.0001:
		rotate_object_local(Vector3.FORWARD, _roll_kick)
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 3.8)
	_recoil_kick = move_toward(_recoil_kick, 0.0, delta * 2.6)
	_roll_kick = move_toward(_roll_kick, 0.0, delta * 3.1)
	_broadside_slide = move_toward(_broadside_slide, 0.0, delta * 4.2)
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 7.0)


func _get_ship_camera_scale(type_name: String) -> float:
	match type_name:
		"Sloop":
			return 0.58
		"Brig":
			return 0.69
		"Frigate":
			return 0.80
		"Ship of the Line":
			return 0.92
		"Man o' War":
			return 1.0
	return 0.72


func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_delta(event.relative)


func apply_mouse_delta(delta: Vector2) -> void:
	_yaw_offset -= delta.x * mouse_sensitivity
	var pitch_sign := -1.0 if invert_y else 1.0
	_pitch = clampf(_pitch + delta.y * mouse_sensitivity * pitch_sign, min_pitch, max_pitch)
	if _is_aiming and is_instance_valid(target):
		_update_aim_side(target.global_transform.basis)


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


func set_aiming(active: bool) -> void:
	if active and not _is_aiming and is_instance_valid(target):
		_update_aim_side(target.global_transform.basis)
	_is_aiming = active


func is_aiming() -> bool:
	return _is_aiming


func get_aim_side() -> int:
	return _aim_side


func get_aim_direction() -> Vector3:
	if is_instance_valid(target):
		var back := target.global_transform.basis.z.normalized().rotated(Vector3.UP, _yaw_offset)
		return -back.normalized()

	var direction := -global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return Vector3.FORWARD
	return direction.normalized()


func get_aim_point(max_distance := 155.0) -> Vector3:
	if is_instance_valid(target):
		var horizontal := get_aim_direction()
		horizontal.y = 0.0
		if horizontal.length_squared() < 0.01:
			horizontal = -target.global_transform.basis.z.normalized()
		var range_t := clampf(inverse_lerp(max_pitch, min_pitch, _pitch), 0.0, 1.0)
		var distance := lerpf(28.0, max_distance, range_t)
		return target.global_position + Vector3.UP * 0.75 + horizontal.normalized() * distance

	var origin := global_position
	var direction := get_aim_ray_direction()
	var plane_y := 0.75
	var distance := max_distance
	if absf(direction.y) > 0.001:
		var plane_hit_distance := (plane_y - origin.y) / direction.y
		if plane_hit_distance > 8.0 and plane_hit_distance < max_distance:
			distance = plane_hit_distance

	return origin + direction * distance


func get_aim_ray_direction() -> Vector3:
	if is_instance_valid(target):
		var horizontal := get_aim_direction()
		return (horizontal + Vector3.UP * clampf(_pitch * 0.45, -0.16, 0.36)).normalized()

	return -global_transform.basis.z.normalized()


func apply_settings(settings: Dictionary) -> void:
	mouse_sensitivity = float(settings.get("mouse_sensitivity", mouse_sensitivity))
	follow_distance = float(settings.get("camera_distance", follow_distance))
	invert_y = bool(settings.get("invert_y", invert_y))


func add_combat_impulse(side: int) -> void:
	var class_kick := 1.0
	if is_instance_valid(target):
		match String(target.get("hull_class")):
			"Sloop":
				class_kick = 0.72
			"Brig":
				class_kick = 0.86
			"Frigate":
				class_kick = 1.0
			"Ship of the Line":
				class_kick = 1.18
			"Man o' War":
				class_kick = 1.34
	_shake_strength = maxf(_shake_strength, (0.54 if _is_aiming else 0.42) * class_kick)
	_recoil_kick = maxf(_recoil_kick, (0.46 if _is_aiming else 0.31) * class_kick)
	_roll_kick += float(side) * 0.026 * class_kick
	_yaw_offset += float(side) * 0.017 * class_kick
	_broadside_slide = -float(side) * 0.72 * class_kick
	_fov_kick = 2.8 * class_kick


func add_boarding_impulse(strength := 0.45) -> void:
	var amount := clampf(strength, 0.0, 1.0)
	_shake_strength = maxf(_shake_strength, amount * 0.42)
	_recoil_kick = maxf(_recoil_kick, amount * 0.20)
	_roll_kick += randf_range(-0.018, 0.018) * amount


func set_boarding_focus(other_ship: Node3D) -> void:
	_boarding_focus_target = other_ship
	_is_aiming = false
	_boarding_stage = 0
	if is_instance_valid(target) and is_instance_valid(other_ship):
		var midpoint := target.global_position.lerp(other_ship.global_position, 0.5)
		var axis := other_ship.global_position - target.global_position
		axis.y = 0.0
		if axis.length_squared() > 0.01:
			var side := Vector3(-axis.normalized().z, 0.0, axis.normalized().x)
			_boarding_view_side = 1.0 if (global_position - midpoint).dot(side) >= 0.0 else -1.0


func set_boarding_stage(stage: int) -> void:
	_boarding_stage = clampi(stage, 0, 2)


func clear_boarding_focus() -> void:
	_boarding_focus_target = null
	_boarding_stage = 0
	_boarding_view_side = 1.0


func set_fort_capture_focus(fort: Node3D) -> void:
	_fort_capture_focus_target = fort
	_fort_capture_stage = 0
	_is_aiming = false
	if is_instance_valid(fort):
		var side := fort.global_transform.basis.x.normalized()
		_fort_capture_view_side = 1.0 if (global_position - fort.global_position).dot(side) >= 0.0 else -1.0


func set_fort_capture_stage(stage: int) -> void:
	_fort_capture_stage = clampi(stage, 0, 2)


func clear_fort_capture_focus() -> void:
	_fort_capture_focus_target = null
	_fort_capture_stage = 0
	_fort_capture_view_side = 1.0


func add_hit_impulse(report: Dictionary) -> void:
	var damage := float(report.get("health_damage", 0.0)) + float(report.get("sail_damage", 0.0)) + float(report.get("rudder_damage", 0.0)) + float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	var strength := clampf(damage / 42.0, 0.18, 0.82)
	_shake_strength = maxf(_shake_strength, strength)
	_recoil_kick = maxf(_recoil_kick, strength * 0.55)
	var incoming: Vector3 = report.get("incoming_direction", Vector3.ZERO)
	if incoming.length_squared() > 0.01 and is_instance_valid(target):
		var local_incoming := target.global_transform.basis.inverse() * incoming.normalized()
		_roll_kick += clampf(local_incoming.x, -1.0, 1.0) * strength * 0.075
		_yaw_offset += clampf(local_incoming.x, -1.0, 1.0) * strength * 0.018
	_hit_impulses += 1


func add_near_miss_impulse(position: Vector3) -> void:
	var strength := 0.42
	if is_instance_valid(target):
		var distance := target.global_position.distance_to(position)
		strength = clampf(1.0 - distance / 11.0, 0.24, 0.72)
		var local_pos := target.to_local(position)
		_roll_kick += signf(local_pos.x) * strength * 0.06
		_yaw_offset += signf(local_pos.x) * strength * 0.014
	_shake_strength = maxf(_shake_strength, strength)
	_recoil_kick = maxf(_recoil_kick, strength * 0.28)
	_near_miss_impulses += 1


func add_rogue_wave_impulse(strength: float, side: float) -> void:
	var amount := clampf(strength, 0.0, 1.0)
	_shake_strength = maxf(_shake_strength, lerpf(0.34, 1.15, amount))
	_recoil_kick = maxf(_recoil_kick, lerpf(0.18, 0.72, amount))
	_roll_kick += clampf(side, -1.0, 1.0) * lerpf(0.055, 0.16, amount)
	_yaw_offset += clampf(side, -1.0, 1.0) * lerpf(0.012, 0.038, amount)


func get_feedback_state() -> Dictionary:
	return {
		"shake": _shake_strength,
		"recoil": _recoil_kick,
		"roll": _roll_kick,
		"hit_impulses": _hit_impulses,
		"near_miss_impulses": _near_miss_impulses,
	}


func _update_aim_side(ship_basis: Basis) -> void:
	if not is_instance_valid(target):
		return

	var direction_score := get_aim_direction().dot(ship_basis.x.normalized())
	if absf(direction_score) > 0.035:
		_aim_side = 1 if direction_score > 0.0 else -1
		return

	var camera_offset := global_position - target.global_position
	camera_offset.y = 0.0
	var position_score := camera_offset.dot(ship_basis.x.normalized())
	if absf(position_score) > 1.2:
		_aim_side = -1 if position_score > 0.0 else 1
		return


func _get_target_telemetry() -> Dictionary:
	if target and target.has_method("get_telemetry"):
		return target.get_telemetry()
	return {}


func _get_speed_ratio(telemetry: Dictionary) -> float:
	var max_speed := 1.0
	var speed := absf(float(telemetry.get("speed", 0.0)))
	if target:
		max_speed = maxf(float(target.get("max_speed")), 1.0)
	return clampf(speed / max_speed, 0.0, 1.0)
