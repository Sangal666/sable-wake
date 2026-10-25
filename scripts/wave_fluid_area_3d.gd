extends "res://addons/floatable_body/fluid_area_3d.gd"
class_name WaveFluidArea3D

const WAVE_FREQUENCIES := [0.045, 0.082, 0.145, 0.029, 0.245, 0.380]
const WAVE_RATES := [0.50, 0.75, 1.08, 0.34, 1.48, 1.92]
const WAVE_PHASES := [0.0, 1.7, 3.2, 0.8, 4.4, 2.3]
const WAVE_HORIZONTAL_WEIGHTS := [0.72, 0.50, 0.24, 0.42, 0.0, 0.0]
const WAVE_GROUP_WEIGHTS := [1.0, 0.62, 0.24, 0.88, 0.0, 0.0]
const WAVE_CREST_WEIGHTS := [1.0, 0.42, 0.0, 0.78, 0.0, 0.0]

@export var sea_level := -0.18
@export var sea_state := 1.16
@export var wave_speed := 1.0
@export var wave_chop := 0.90
var simulation_time := 0.0
var wind_direction := Vector2(0.85, -0.35).normalized()
var _cached_wind := Vector2.ZERO
var _wave_directions := PackedVector2Array()


func _ensure_wave_directions() -> void:
	var primary := wind_direction.normalized()
	if primary.length_squared() < 0.01:
		primary = Vector2(0.85, -0.35).normalized()
	if _wave_directions.size() == 6 and primary.is_equal_approx(_cached_wind):
		return
	_cached_wind = primary
	var perpendicular := Vector2(-primary.y, primary.x)
	_wave_directions = PackedVector2Array([
		primary,
		(perpendicular * 0.58 + primary * 0.42).normalized(),
		(Vector2(primary.y, -primary.x) * 0.78 + primary * 0.22).normalized(),
		(-primary * 0.16 + Vector2(0.33, 0.94)).normalized(),
		(primary * 0.72 + Vector2(-0.68, 0.22)).normalized(),
		((perpendicular * 0.58 + primary * 0.42).normalized() * 0.35 - primary * 0.65).normalized(),
	])


func _evaluate_parametric(point: Vector2) -> Dictionary:
	_ensure_wave_directions()
	var time_value := simulation_time * wave_speed
	var horizontal_scale := lerpf(0.38, 1.22, wave_chop * 0.5)
	var secondary_scale := lerpf(0.64, 1.12, wave_chop * 0.5)
	# Ocean swell arrives in sets. The long envelope makes several crests build,
	# peak and decay together instead of repeating six equally strong sine waves.
	var primary := _wave_directions[0]
	var cross_direction := Vector2(-primary.y, primary.x)
	var set_strength := clampf((sea_state - 0.88) / 1.92, 0.0, 1.0) * clampf(wave_chop / 1.82, 0.0, 1.0)
	var group_phase_a := point.dot(primary) * 0.0105 + time_value * 0.075 + 0.35
	var group_phase_b := point.dot(cross_direction) * 0.0160 - time_value * 0.055 + 2.10
	var group_direction_c := (primary * 0.68 + cross_direction * 0.32).normalized()
	var group_phase_c := point.dot(group_direction_c) * 0.0072 + time_value * 0.038 + 4.20
	var group_delta := set_strength * (
		sin(group_phase_a) * 0.24
		+ sin(group_phase_b) * 0.12
		+ sin(group_phase_c) * 0.07
	)
	var group_gradient := set_strength * (
		primary * cos(group_phase_a) * 0.24 * 0.0105
		+ cross_direction * cos(group_phase_b) * 0.12 * 0.0160
		+ group_direction_c * cos(group_phase_c) * 0.07 * 0.0072
	)
	var group_rate := set_strength * (
		cos(group_phase_a) * 0.24 * 0.075
		- cos(group_phase_b) * 0.12 * 0.055
		+ cos(group_phase_c) * 0.07 * 0.038
	)
	var crest_strength := 0.22 * set_strength
	var amplitudes := PackedFloat32Array([
		0.42 * sea_state,
		0.24 * secondary_scale * sea_state,
		0.12 * wave_chop * sea_state,
		0.30 * sea_state,
		0.065 * wave_chop * sea_state,
		0.032 * wave_chop * sea_state,
	])
	var height := 0.0
	var vertical_velocity := 0.0
	var horizontal := Vector2.ZERO
	var horizontal_velocity := Vector2.ZERO
	var height_gradient := Vector2.ZERO
	var j00 := 1.0
	var j01 := 0.0
	var j10 := 0.0
	var j11 := 1.0
	for index in range(6):
		var direction := _wave_directions[index]
		var frequency := float(WAVE_FREQUENCIES[index])
		var rate := float(WAVE_RATES[index])
		var amplitude := float(amplitudes[index])
		var phase := point.dot(direction) * frequency + time_value * rate + float(WAVE_PHASES[index])
		var sine := sin(phase)
		var cosine := cos(phase)
		var envelope_weight := float(WAVE_GROUP_WEIGHTS[index])
		var envelope := 1.0 + group_delta * envelope_weight
		var envelope_gradient := group_gradient * envelope_weight
		var envelope_rate := group_rate * envelope_weight
		var crest_bias := crest_strength * float(WAVE_CREST_WEIGHTS[index])
		var shaped_sine := sine + crest_bias * (sine * sine - 0.5)
		var shaped_derivative := cosine * (1.0 + 2.0 * crest_bias * sine)
		var phase_gradient := direction * frequency
		height += shaped_sine * amplitude * envelope
		vertical_velocity += amplitude * (shaped_derivative * rate * envelope + shaped_sine * envelope_rate) * wave_speed
		height_gradient += amplitude * (phase_gradient * shaped_derivative * envelope + envelope_gradient * shaped_sine)
		var horizontal_amount := amplitude * float(WAVE_HORIZONTAL_WEIGHTS[index]) * horizontal_scale
		if horizontal_amount <= 0.0:
			continue
		var horizontal_scalar := cosine * horizontal_amount * envelope
		var horizontal_gradient := horizontal_amount * (envelope_gradient * cosine - phase_gradient * sine * envelope)
		var horizontal_rate := horizontal_amount * (envelope_rate * cosine - sine * rate * envelope) * wave_speed
		horizontal += direction * horizontal_scalar
		horizontal_velocity += direction * horizontal_rate
		j00 += direction.x * horizontal_gradient.x
		j01 += direction.x * horizontal_gradient.y
		j10 += direction.y * horizontal_gradient.x
		j11 += direction.y * horizontal_gradient.y
	var tangent_x := Vector3(j00, height_gradient.x, j10)
	var tangent_z := Vector3(j01, height_gradient.y, j11)
	var surface_normal := tangent_z.cross(tangent_x).normalized()
	if surface_normal.y < 0.0:
		surface_normal = -surface_normal
	return {
		"height": height,
		"horizontal": horizontal,
		"normal": surface_normal,
		"velocity": Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.y),
		"steepness": height_gradient.length(),
	}


func get_surface_sample(world_position: Vector3) -> Dictionary:
	# Shader vertices are displaced sideways as well as vertically. Invert that
	# displacement so a world-space physics query lands on the same visible crest.
	var world_point := Vector2(world_position.x, world_position.z)
	var parameter_point := world_point
	for iteration in range(2):
		var estimate := _evaluate_parametric(parameter_point)
		var displacement: Vector2 = estimate.horizontal
		parameter_point = world_point - displacement
	var sample := _evaluate_parametric(parameter_point)
	sample.height = sea_level + float(sample.height)
	return sample


func get_height(world_position: Vector3) -> float:
	return float(get_surface_sample(world_position).height)


func get_vertical_velocity(world_position: Vector3) -> float:
	return float((get_surface_sample(world_position).velocity as Vector3).y)


func get_surface_normal(world_position: Vector3) -> Vector3:
	return get_surface_sample(world_position).normal


func get_surface_velocity(world_position: Vector3) -> Vector3:
	return get_surface_sample(world_position).velocity
