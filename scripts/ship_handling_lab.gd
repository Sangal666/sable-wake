extends Node3D

const FloatableShip := preload("res://scripts/floatable_lab_ship.gd")
const FFTWaveFluid := preload("res://scripts/fft_wave_fluid_area_3d.gd")
const SmoothShipCamera := preload("res://scripts/smooth_ship_camera.gd")
const BattleEnvironmentProfiles := preload("res://scripts/battle_environment_profiles.gd")
const StormRain := preload("res://scripts/storm_rain.gd")
const RogueWave := preload("res://scripts/rogue_wave.gd")

const SHIP_CLASSES := ["Brig", "Frigate", "Ship of the Line", "Man o' War"]

var _ship: RigidBody3D
var _camera: Camera3D
var _fluid: Node3D
var _ocean_material: ShaderMaterial
var _ocean_time := 0.0
var _class_index := 0
var _stats: Label
var _run_origin := Vector3.ZERO
var _config: Dictionary = {}
var _profile: Dictionary = {}
var _world_environment: WorldEnvironment
var _sun_light: DirectionalLight3D
var _storm_rain: GPUParticles3D
var _active_storm_breaker: Node3D
var _storm_breaker_cooldown := 999.0
var _storm_breaker_impacted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_config = BattleEnvironmentProfiles.consume_lab_config()
	_profile = BattleEnvironmentProfiles.build_profile(_config)
	var requested_ship := String(_config.get("player_type", SHIP_CLASSES[0]))
	if requested_ship in SHIP_CLASSES:
		_class_index = SHIP_CLASSES.find(requested_ship)
	_ensure_input_actions()
	_create_environment()
	_create_fluid_volume()
	_create_course_markers()
	_create_camera()
	_create_weather_fx()
	_create_interface()
	_spawn_ship(SHIP_CLASSES[_class_index])
	if bool(_profile.storm_breakers_enabled):
		_storm_breaker_cooldown = randf_range(float(_profile.storm_breaker_interval_min) * 0.45, float(_profile.storm_breaker_interval_min) * 0.72)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_ocean_time += delta
	if _ocean_material:
		_ocean_material.set_shader_parameter("simulation_time", _ocean_time)
	if _fluid:
		_fluid.set("simulation_time", _ocean_time)
	_update_storm_breaker(delta)
	_update_stats()


func _create_weather_fx() -> void:
	_storm_rain = StormRain.new()
	add_child(_storm_rain)
	var storm_enabled := String(_profile.weather) == "Storm"
	_storm_rain.emitting = storm_enabled
	_storm_rain.visible = storm_enabled


func _update_storm_breaker(delta: float) -> void:
	if not bool(_profile.get("storm_breakers_enabled", false)):
		_clear_storm_breaker()
		return
	if is_instance_valid(_active_storm_breaker):
		if not _storm_breaker_impacted and is_instance_valid(_ship):
			var distance := float(_active_storm_breaker.call("distance_to_front", _ship.global_position))
			if distance <= 2.4:
				_storm_breaker_impacted = true
				var direction: Vector3 = _active_storm_breaker.get("travel_direction")
				var braced := Input.is_action_pressed("brace")
				_ship.call("apply_storm_breaker_impact", direction, float(_profile.storm_breaker_scale), braced)
		return
	_active_storm_breaker = null
	_storm_breaker_cooldown = maxf(_storm_breaker_cooldown - delta, 0.0)
	if _storm_breaker_cooldown <= 0.0:
		_spawn_storm_breaker()


func _spawn_storm_breaker(source_direction := Vector3.ZERO) -> void:
	if not is_instance_valid(_ship) or is_instance_valid(_active_storm_breaker) or not bool(_profile.get("storm_breakers_enabled", false)):
		return
	var from_ship := Vector3(source_direction.x, 0.0, source_direction.z).normalized()
	if from_ship.length_squared() < 0.01:
		var angle := randf_range(0.0, TAU)
		from_ship = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	var scale := float(_profile.storm_breaker_scale)
	var wave := RogueWave.new()
	wave.name = "StormBreaker"
	wave.configure(
		_ship.global_position + from_ship * 135.0,
		-from_ship,
		randf_range(14.0, 15.5) * scale,
		190.0 * scale,
		scale,
		{
			"deep_color": _profile.deep_color,
			"face_color": _profile.face_color,
			"foam_color": _profile.foam_color,
		}
	)
	add_child(wave)
	wave.connect("expired", Callable(self, "_on_storm_breaker_expired"))
	_active_storm_breaker = wave
	_storm_breaker_impacted = false
	_storm_breaker_cooldown = randf_range(float(_profile.storm_breaker_interval_min), float(_profile.storm_breaker_interval_max))


func _on_storm_breaker_expired(wave: Node3D) -> void:
	if wave == _active_storm_breaker:
		_active_storm_breaker = null
		_storm_breaker_impacted = false


func _clear_storm_breaker() -> void:
	if is_instance_valid(_active_storm_breaker):
		_active_storm_breaker.queue_free()
	_active_storm_breaker = null
	_storm_breaker_impacted = false
	_storm_breaker_cooldown = 999.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_return_to_main_menu()
			KEY_1:
				_select_ship(0)
			KEY_2:
				_select_ship(1)
			KEY_3:
				_select_ship(2)
			KEY_4:
				_select_ship(3)


func _select_ship(index: int) -> void:
	if index == _class_index and is_instance_valid(_ship):
		return
	_class_index = clampi(index, 0, SHIP_CLASSES.size() - 1)
	_spawn_ship(SHIP_CLASSES[_class_index])


func _spawn_ship(type_name: String) -> void:
	if is_instance_valid(_ship):
		_ship.queue_free()
	_storm_breaker_impacted = false
	_ship = FloatableShip.new()
	_ship.name = "Lab%s" % type_name.replace(" ", "")
	_ship.set("hull_class", type_name)
	_ship.set("wind_direction", _profile.wind_direction)
	_ship.set("wind_strength", _profile.wind_strength)
	_ship.set("ocean_sea_state", _profile.sea_state)
	_ship.set("ocean_wave_speed", _profile.wave_speed)
	_ship.set("ocean_wave_chop", _profile.wave_chop)
	_ship.position = Vector3(0.0, 1.2, 0.0)
	add_child(_ship)
	_ship.call("set_sail_step", 3)
	_ship.linear_velocity = Vector3(0.0, 0.0, -float(_ship.get("max_speed")) * 0.62)
	_run_origin = _ship.global_position
	if _camera:
		_camera.target = _ship
		match type_name:
			"Brig":
				_camera.side_offset = 3.8
			"Frigate":
				_camera.side_offset = 4.8
			"Ship of the Line":
				_camera.side_offset = 6.4
			"Man o' War":
				_camera.side_offset = 8.0
		_camera.global_position = _ship.global_position + Vector3(_camera.side_offset, 9.0, 18.0)


func _create_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "LabEnvironment"
	var settings := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = _profile.sky_top
	sky_material.sky_horizon_color = _profile.sky_horizon
	sky_material.ground_bottom_color = _profile.ground_bottom
	sky_material.ground_horizon_color = _profile.ground_horizon
	sky_material.sky_curve = 0.12
	sky_material.sky_energy_multiplier = float(_profile.sky_energy)
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.07
	sky.sky_material = sky_material
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if bool(_profile.use_color_ambient) else Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_color = _profile.ambient_color
	settings.ambient_light_energy = float(_profile.ambient_energy)
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.fog_enabled = true
	settings.fog_light_color = _profile.fog_color
	settings.fog_density = float(_profile.fog_density)
	settings.fog_aerial_perspective = float(_profile.fog_aerial)
	settings.fog_sky_affect = float(_profile.fog_sky_affect)
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = float(_profile.exposure)
	settings.ssao_enabled = true
	settings.ssao_radius = 2.25
	settings.ssao_intensity = 1.18
	settings.adjustment_enabled = true
	settings.adjustment_brightness = float(_profile.brightness)
	settings.adjustment_contrast = float(_profile.contrast)
	settings.adjustment_saturation = float(_profile.saturation)
	environment.environment = settings
	add_child(environment)
	_world_environment = environment

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = _profile.sun_rotation
	sun.light_color = _profile.sun_color
	sun.light_energy = float(_profile.sun_energy)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.35
	sun.directional_shadow_max_distance = 360.0
	add_child(sun)
	_sun_light = sun


func _create_fluid_volume() -> void:
	_ocean_material = null
	_fluid = FFTWaveFluid.new()
	_fluid.name = "WaveFluid"
	_fluid.set("sea_level", -0.18)
	_fluid.set("sea_state", _profile.sea_state)
	_fluid.set("wave_speed", _profile.wave_speed)
	_fluid.set("wave_chop", _profile.wave_chop)
	var wind_direction: Vector3 = _profile.wind_direction
	_fluid.set("wind_direction", Vector2(wind_direction.x, wind_direction.z))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1100.0, 40.0, 1100.0)
	collision.shape = shape
	collision.position.y = -20.18
	_fluid.add_child(collision)
	add_child(_fluid)
	_fluid.call("configure_profile", _profile)


func _create_course_markers() -> void:
	var course := Node3D.new()
	course.name = "HandlingCourse"
	add_child(course)
	for gate_index in range(1, 11):
		var z := -float(gate_index) * 28.0
		var center_offset := sin(float(gate_index) * 0.72) * 11.0
		_create_buoy(course, Vector3(center_offset - 9.0, 0.05, z), Color(0.76, 0.15, 0.10))
		_create_buoy(course, Vector3(center_offset + 9.0, 0.05, z), Color(0.92, 0.68, 0.16))


func _create_buoy(parent: Node3D, buoy_position: Vector3, color: Color) -> void:
	var buoy := Node3D.new()
	buoy.position = buoy_position
	parent.add_child(buoy)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.52
	body_mesh.bottom_radius = 0.74
	body_mesh.height = 1.15
	body.mesh = body_mesh
	body.position.y = 0.34
	body.material_override = _make_marker_material(color)
	buoy.add_child(body)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 2.6
	pole.mesh = pole_mesh
	pole.position.y = 1.75
	pole.material_override = _make_marker_material(Color(0.16, 0.13, 0.09))
	buoy.add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.95, 0.52, 0.08)
	flag.mesh = flag_mesh
	flag.position = Vector3(0.48, 2.72, 0.0)
	flag.material_override = _make_marker_material(color.lightened(0.12))
	buoy.add_child(flag)


func _make_marker_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func _create_camera() -> void:
	_camera = SmoothShipCamera.new()
	_camera.name = "HandlingCamera"
	_camera.follow_distance = 20.0
	_camera.height = 9.8
	_camera.side_offset = 3.2
	_camera.look_ahead = 5.5
	add_child(_camera)
	_camera.current = true


func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(330.0, 154.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.075, 0.90)
	style.border_color = Color(0.55, 0.67, 0.62, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 15)
	_stats.add_theme_color_override("font_color", Color(0.86, 0.91, 0.84))
	panel.add_child(_stats)

	var class_bar := Label.new()
	class_bar.text = "1  BRIG     2  FRIGATE     3  LINE SHIP     4  MAN O' WAR"
	class_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	class_bar.position = Vector2(-315.0, 24.0)
	class_bar.size = Vector2(630.0, 34.0)
	class_bar.add_theme_font_size_override("font_size", 14)
	class_bar.add_theme_color_override("font_color", Color(0.93, 0.74, 0.34))
	layer.add_child(class_bar)


func _update_stats() -> void:
	if not is_instance_valid(_ship) or _stats == null or not _ship.has_method("get_telemetry"):
		return
	var telemetry: Dictionary = _ship.get_telemetry()
	var travel := _ship.global_position.distance_to(_run_origin)
	var storm_control := "    SPACE brace" if bool(_profile.get("storm_breakers_enabled", false)) else ""
	_stats.text = "%s\n%s\nSpeed  %4.1f kn    Sail  %s %d%%    Travel %.1f m\nRudder %+4.2f       Side drift %+4.2f\nW/S sail stage    A/D helm%s    Esc main menu" % [
		String(telemetry.get("hull_class", "Ship")),
		String(_profile.get("label", "Day / Clear / Rolling Sea")),
		float(telemetry.get("speed", 0.0)) * 1.94,
		String(telemetry.get("sail_state", "Battle")),
		int(float(telemetry.get("sail", 0.0)) * 100.0),
		travel,
		float(telemetry.get("rudder", 0.0)),
		float(telemetry.get("lateral_slip", 0.0)),
		storm_control,
	]


func _return_to_main_menu() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _ensure_input_actions() -> void:
	_bind_key("sail_up", KEY_W)
	_bind_key("sail_down", KEY_S)
	_bind_key("rudder_left", KEY_A)
	_bind_key("rudder_right", KEY_D)
	_bind_key("brace", KEY_SPACE)


func _bind_key(action_name: StringName, key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action_name, event)
