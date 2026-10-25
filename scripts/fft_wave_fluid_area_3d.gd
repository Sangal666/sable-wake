extends "res://addons/floatable_body/fluid_area_3d.gd"
class_name FFTWaveFluidArea3D

signal surface_ready


const OceanScript := preload("res://addons/tessarakkt.oceanfft/components/Ocean3D.gd")
const QuadTreeScript := preload("res://addons/tessarakkt.oceanfft/components/QuadTree3D.gd")
const OceanMaterial := preload("res://addons/tessarakkt.oceanfft/Ocean.tres")

@export var sea_level := -0.18
@export var sea_state := 1.16
@export var wave_speed := 0.66
@export var wave_chop := 0.90
@export var wind_direction := Vector2(0.85, -0.35).normalized()
@export var simulation_time := 0.0

var ocean_material: ShaderMaterial
var _ocean: Resource
var _ocean_mesh: Node3D
var _height_bias := 0.0
var _initial_sync_requested := false
var _surface_calibrated := false
var _sync_wait := 0.0
var _rogue_wave_origin := Vector3.ZERO
var _rogue_wave_direction := Vector3.FORWARD
var _rogue_wave_width := 260.0
var _rogue_wave_strength := 0.0
var _rogue_wave_source_id := 0
const ROGUE_WAVE_LENGTH := 7.5


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("fft_wave_fluid")
	_create_fft_simulation()


func _process(delta: float) -> void:
	if _ocean == null or not bool(_ocean.get("initialized")):
		return
	if not _initial_sync_requested:
		_initial_sync_requested = true
		_ocean.call("force_simulate", 1.0 / 30.0, true)
		return
	_ocean.call("simulate", delta)
	if not _surface_calibrated:
		_sync_wait += delta
		if _sync_wait >= 0.22:
			_surface_calibrated = _calibrate_surface_offset()
			if _surface_calibrated:
				_create_ocean_mesh()
				surface_ready.emit()


func _exit_tree() -> void:
	if _ocean != null and _ocean.has_method("cleanup_simulation"):
		_ocean.call("cleanup_simulation")


func _create_fft_simulation() -> void:
	ocean_material = (OceanMaterial as ShaderMaterial).duplicate(true)
	_ocean = OceanScript.new()
	_ocean.set("material", ocean_material)
	_ocean.set("fft_resolution", 64)
	_ocean.set("horizontal_dimension", 420)
	_ocean.set("simulation_frameskip", 1)
	_ocean.set("heightmap_sync_frameskip", 1)
	_ocean.set("planetary_curve_strength", 0.0)
	_ocean.set("amplitude_scale_min", 1.0)
	_ocean.set("amplitude_scale_max", 1.0)
	_apply_ocean_profile()
	_ocean.call("initialize_simulation")


func configure_profile(profile: Dictionary) -> void:
	sea_state = float(profile.get("sea_state", sea_state))
	wave_speed = float(profile.get("wave_speed", wave_speed))
	wave_chop = float(profile.get("wave_chop", wave_chop))
	var wind_3d := Vector3(profile.get("wind_direction", Vector3(wind_direction.x, 0.0, wind_direction.y)))
	wind_direction = Vector2(wind_3d.x, wind_3d.z).normalized()
	if ocean_material != null:
		var abyss := Color(profile.get("abyss_color", Color(0.005, 0.035, 0.052)))
		var deep := Color(profile.get("deep_color", Color(0.012, 0.10, 0.13)))
		var face := Color(profile.get("face_color", Color(0.04, 0.22, 0.23)))
		var foam := Color(profile.get("foam_color", Color(0.82, 0.90, 0.87)))
		var sky_horizon := Color(profile.get("sky_horizon", Color(0.32, 0.48, 0.52)))
		ocean_material.set_shader_parameter("deep_color", abyss.lerp(deep, 0.48))
		ocean_material.set_shader_parameter("shallow_color", deep.lerp(face, 0.58).darkened(0.12))
		ocean_material.set_shader_parameter("fresnel_sky_color", sky_horizon.lerp(Color.WHITE, 0.12))
		ocean_material.set_shader_parameter("sss_color", face.lerp(foam, 0.24))
		ocean_material.set_shader_parameter("foam_diffuse_color", foam)
	_apply_ocean_profile()


func _apply_ocean_profile() -> void:
	if _ocean == null:
		return
	var storm_ratio := clampf((sea_state - 0.38) / 2.77, 0.0, 1.0)
	var wind_angle := rad_to_deg(atan2(wind_direction.y, wind_direction.x))
	_ocean.set("wind_direction_degrees", fposmod(wind_angle, 360.0))
	_ocean.set("wind_speed", lerpf(7.5, 34.0, pow(storm_ratio, 0.72)))
	_ocean.set("choppiness", lerpf(0.36, 1.92, storm_ratio) * clampf(wave_chop / 1.35, 0.62, 1.20))
	_ocean.set("time_scale", clampf(wave_speed * 0.68, 0.24, 0.68))
	_ocean.set("wave_scroll_speed", -0.0012 * lerpf(0.55, 1.0, storm_ratio))
	if ocean_material == null:
		return
	ocean_material.set_shader_parameter("normal_factor", lerpf(0.82, 0.96, storm_ratio))
	ocean_material.set_shader_parameter("foam_jacobian_limit", lerpf(0.51, 0.28, storm_ratio))
	ocean_material.set_shader_parameter("foam_coverage", lerpf(0.28, 0.62, storm_ratio))
	ocean_material.set_shader_parameter("foam_mix_strength", lerpf(0.38, 0.68, storm_ratio))
	ocean_material.set_shader_parameter("foam_diffuse_strength", lerpf(0.66, 0.92, storm_ratio))
	ocean_material.set_shader_parameter("detail_normal_strength", lerpf(0.045, 0.105, storm_ratio))
	ocean_material.set_shader_parameter("detail_normal_scale", lerpf(0.24, 0.38, storm_ratio))
	ocean_material.set_shader_parameter("detail_normal_speed", lerpf(0.10, 0.19, storm_ratio))
	ocean_material.set_shader_parameter("fresnel_offset", lerpf(0.035, 0.075, storm_ratio))
	ocean_material.set_shader_parameter("fresnel_strength", lerpf(0.18, 0.34, storm_ratio))
	ocean_material.set_shader_parameter("fresnel_power", lerpf(4.8, 3.4, storm_ratio))
	ocean_material.set_shader_parameter("fresnel_exposure", lerpf(0.82, 0.66, storm_ratio))
	ocean_material.set_shader_parameter("specular_strength", lerpf(0.48, 0.30, storm_ratio))
	ocean_material.set_shader_parameter("specular_power", lerpf(720.0, 380.0, storm_ratio))
	ocean_material.set_shader_parameter("pbr_specular_strength", 0.24)
	ocean_material.set_shader_parameter("pbr_specular_offset", 0.055)
	ocean_material.set_shader_parameter("refraction_factor_max", 0.008)
	ocean_material.set_shader_parameter("refraction_background_brightness", lerpf(0.46, 0.30, storm_ratio))
	ocean_material.set_shader_parameter("sss_backlight_strength", lerpf(0.010, 0.018, storm_ratio))
	ocean_material.set_shader_parameter("sss_upwelling", lerpf(0.018, 0.045, storm_ratio))


func _calibrate_surface_offset() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var image: Image = _ocean.call("get_waves", 0)
	if image == null or image.is_empty():
		return false
	var sample_min := INF
	var sample_max := -INF
	var total := 0.0
	var count := 0
	for x in range(-48, 49, 12):
		for z in range(-48, 49, 12):
			var height := float(_ocean.call("get_wave_height", camera, Vector3(float(x), 0.0, float(z)), 3, 3))
			sample_min = minf(sample_min, height)
			sample_max = maxf(sample_max, height)
			total += height
			count += 1
	if sample_max - sample_min < 0.02:
		return false
	_height_bias = -total / float(maxi(count, 1))
	return true


func _create_ocean_mesh() -> void:
	if is_instance_valid(_ocean_mesh) or get_viewport().get_camera_3d() == null:
		return
	_ocean_mesh = Node3D.new()
	_ocean_mesh.name = "OceanFFTMesh"
	_ocean_mesh.set_script(QuadTreeScript)
	var lod_ranges: Array[float] = [150.0, 330.0, 700.0, 1450.0]
	_ocean_mesh.set("lod_level", 3)
	_ocean_mesh.set("quad_size", 1800.0)
	_ocean_mesh.set("mesh_vertex_resolution", 80)
	_ocean_mesh.set("ranges", lod_ranges)
	_ocean_mesh.set("material", ocean_material)
	_ocean_mesh.position.y = sea_level + _height_bias
	add_child(_ocean_mesh)


func get_surface_sample(world_position: Vector3) -> Dictionary:
	if not _surface_calibrated or _ocean == null:
		return {
			"height": sea_level,
			"normal": Vector3.UP,
			"velocity": Vector3.ZERO,
			"steepness": 0.0,
		}
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {"height": sea_level, "normal": Vector3.UP, "velocity": Vector3.ZERO, "steepness": 0.0}
	var spacing := 1.15
	var center := _sample_height(camera, world_position)
	var left := _sample_height(camera, world_position - Vector3(spacing, 0.0, 0.0))
	var right := _sample_height(camera, world_position + Vector3(spacing, 0.0, 0.0))
	var back := _sample_height(camera, world_position - Vector3(0.0, 0.0, spacing))
	var front := _sample_height(camera, world_position + Vector3(0.0, 0.0, spacing))
	var gradient := Vector2((right - left) / (spacing * 2.0), (front - back) / (spacing * 2.0))
	var normal := Vector3(-gradient.x, 1.0, -gradient.y).normalized()
	var phase_velocity := wind_direction * lerpf(2.8, 5.8, clampf((sea_state - 0.38) / 2.77, 0.0, 1.0)) * wave_speed
	var vertical_velocity := -gradient.dot(phase_velocity)
	var orbital_speed := clampf(gradient.length() * 1.8, 0.0, 2.8)
	var surface_velocity := Vector3(wind_direction.x * orbital_speed, vertical_velocity, wind_direction.y * orbital_speed)
	return {
		"height": center,
		"normal": normal,
		"velocity": surface_velocity,
		"steepness": gradient.length(),
	}


func is_surface_ready() -> bool:
	return _surface_calibrated and _ocean != null


func _sample_height(camera: Camera3D, world_position: Vector3) -> float:
	return sea_level + _height_bias + float(_ocean.call("get_wave_height", camera, world_position, 3, 2)) + _rogue_wave_height(world_position)


func set_rogue_wave_data(origin: Vector3, direction: Vector3, width: float, strength: float, source_id: int) -> void:
	_rogue_wave_origin = origin
	_rogue_wave_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if _rogue_wave_direction.length_squared() < 0.01:
		_rogue_wave_direction = Vector3.FORWARD
	_rogue_wave_width = maxf(width, 20.0)
	_rogue_wave_strength = maxf(strength, 0.0)
	_rogue_wave_source_id = source_id
	if ocean_material != null:
		ocean_material.set_shader_parameter("rogue_wave_origin", Vector2(origin.x, origin.z))
		ocean_material.set_shader_parameter("rogue_wave_direction", Vector2(_rogue_wave_direction.x, _rogue_wave_direction.z))
		ocean_material.set_shader_parameter("rogue_wave_width", _rogue_wave_width)
		ocean_material.set_shader_parameter("rogue_wave_length", ROGUE_WAVE_LENGTH)
		ocean_material.set_shader_parameter("rogue_wave_strength", _rogue_wave_strength)


func clear_rogue_wave_data(source_id: int) -> void:
	if source_id != 0 and source_id != _rogue_wave_source_id:
		return
	_rogue_wave_strength = 0.0
	_rogue_wave_source_id = 0
	if ocean_material != null:
		ocean_material.set_shader_parameter("rogue_wave_strength", 0.0)


func _rogue_wave_height(world_position: Vector3) -> float:
	if _rogue_wave_strength <= 0.001:
		return 0.0
	var delta := world_position - _rogue_wave_origin
	var across := Vector3(_rogue_wave_direction.z, 0.0, -_rogue_wave_direction.x)
	var forward_distance := delta.dot(_rogue_wave_direction)
	var side_distance := absf(delta.dot(across))
	var lateral := 1.0 - smoothstep(_rogue_wave_width * 0.38, _rogue_wave_width * 0.50, side_distance)
	var ridge := exp(-pow(forward_distance / ROGUE_WAVE_LENGTH, 2.0))
	var trough := exp(-pow((forward_distance - ROGUE_WAVE_LENGTH * 1.72) / (ROGUE_WAVE_LENGTH * 1.35), 2.0)) * 0.26
	return (ridge - trough) * _rogue_wave_strength * lateral


func get_height(world_position: Vector3) -> float:
	return float(get_surface_sample(world_position).height)


func get_vertical_velocity(world_position: Vector3) -> float:
	return float((get_surface_sample(world_position).velocity as Vector3).y)


func get_surface_normal(world_position: Vector3) -> Vector3:
	return Vector3(get_surface_sample(world_position).normal)


func get_surface_velocity(world_position: Vector3) -> Vector3:
	return Vector3(get_surface_sample(world_position).velocity)
