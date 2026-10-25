extends "res://addons/floatable_body/floatable_body_3d.gd"

signal health_changed(current: float, maximum: float)
signal sunk(ship: Node)
signal broadside_fired(side: int)
signal hit_reported(ship: Node, report: Dictionary)
signal near_missed(ship: Node, position: Vector3, source: Node)
signal surrendered(ship: Node)

const Cannonball := preload("res://scripts/cannonball.gd")
const CombatFx := preload("res://scripts/combat_fx.gd")
const PirateKitAssets := preload("res://scripts/pirate_kit_assets.gd")
const WaterSprayTexture := preload("res://assets/vfx/kenney_smoke/whitePuff08.png")
const WeatheredPlanksAlbedo := preload("res://assets/materials/naval/weathered_planks/weathered_planks_diff_2k.jpg")
const WeatheredPlanksNormal := preload("res://assets/materials/naval/weathered_planks/weathered_planks_nor_gl_2k.jpg")
const WeatheredPlanksRoughness := preload("res://assets/materials/naval/weathered_planks/weathered_planks_rough_2k.jpg")
const WeatheredPlanksAO := preload("res://assets/materials/naval/weathered_planks/weathered_planks_ao_2k.jpg")
const DarkPlanksAlbedo := preload("res://assets/materials/naval/dark_planks/dark_planks_diff_2k.jpg")
const DarkPlanksNormal := preload("res://assets/materials/naval/dark_planks/dark_planks_nor_gl_2k.jpg")
const DarkPlanksRoughness := preload("res://assets/materials/naval/dark_planks/dark_planks_rough_2k.jpg")
const DarkPlanksAO := preload("res://assets/materials/naval/dark_planks/dark_planks_ao_2k.jpg")
const PaintedWoodAlbedo := preload("res://assets/materials/naval/painted_wood_003/PaintedWood003_2K-JPG_Tintable.jpg")
const PaintedWoodNormal := preload("res://assets/materials/naval/painted_wood_003/PaintedWood003_2K-JPG_NormalGL.jpg")
const PaintedWoodRoughness := preload("res://assets/materials/naval/painted_wood_003/PaintedWood003_2K-JPG_Roughness.jpg")
const SailFabricNormal := preload("res://assets/materials/naval/fabric_062/Fabric062_2K-JPG_NormalGL.jpg")
const SailFabricRoughness := preload("res://assets/materials/naval/fabric_062/Fabric062_2K-JPG_Roughness.jpg")
const SailFabricAO := preload("res://assets/materials/naval/fabric_062/Fabric062_2K-JPG_AmbientOcclusion.jpg")
const NavalDamageAtlas := preload("res://assets/materials/naval/damage_decals/naval_damage_atlas.png")
const RopeAlbedo := preload("res://assets/materials/naval/rope/Rope001_2K-JPG_Color.jpg")
const RopeNormal := preload("res://assets/materials/naval/rope/Rope001_2K-JPG_NormalGL.jpg")
const RopeRoughness := preload("res://assets/materials/naval/rope/Rope001_2K-JPG_Roughness.jpg")
const RustyMetalAlbedo := preload("res://assets/materials/naval/rusty_metal_05/rusty_metal_05_diff_2k.jpg")
const RustyMetalNormal := preload("res://assets/materials/naval/rusty_metal_05/rusty_metal_05_nor_gl_2k.jpg")
const RustyMetalRoughness := preload("res://assets/materials/naval/rusty_metal_05/rusty_metal_05_rough_2k.jpg")
const RustyMetalAO := preload("res://assets/materials/naval/rusty_metal_05/rusty_metal_05_ao_2k.jpg")

const SHOT_ROUND := "round"
const SHOT_CHAIN := "chain"
const SHOT_GRAPE := "grape"
const SHOT_MORTAR := "mortar"
const SAIL_SYSTEM_DAMAGE_SCALE := 0.40
const CANNON_SYSTEM_DAMAGE_SCALE := 0.32
const SAIL_STEPS := [0.0, 0.38, 0.68, 1.0]
const SAIL_STEP_LABELS := ["Furled", "Battle", "Half", "Full"]

@export var display_name := "Brig"
@export var team_id := 0
@export var hull_class := "Brig"
@export var max_health := 100.0
@export var incapacitation_health_ratio := 0.0
@export var incapacitated_sink_delay := 36.0
@export var max_speed := 18.0
@export var acceleration := 5.2
@export var deceleration := 3.4
@export var turn_rate := 0.82
@export var rudder_response := 1.85
@export var rudder_return_speed := 2.55
@export var sail_change_rate := 0.52
@export var cannon_reload := 2.4
@export var cannon_damage := 12.0
@export var cannon_shot_speed := 44.0
@export var cannon_gravity := 8.2
@export var broadside_arc_degrees := 72.0
@export var volley_interval := 0.085
@export var grape_pellets_per_cannon := 5
@export var grape_spread_degrees := 9.5
@export var mortar_reload := 12.0
@export var max_sail_integrity := 100.0
@export var max_rudder_integrity := 100.0
@export var max_cannon_integrity := 100.0
@export var crew_shock_decay_rate := 0.11
@export var base_cannons_per_side := 4
@export var brace_damage_reduction := 0.46
@export var perfect_brace_damage_reduction := 0.72
@export var perfect_brace_window := 0.55
@export var brace_drain_rate := 0.42
@export var brace_recover_rate := 0.26
@export var brace_speed_multiplier := 0.62
@export var brace_turn_multiplier := 0.72
@export var max_repair_supplies := 3
@export var emergency_repair_duration := 1.75
@export var emergency_repair_health := 32.0
@export var emergency_repair_fire := 0.70
@export var emergency_repair_flooding := 0.48
@export var fire_damage_rate := 1.05
@export var ram_min_speed := 5.2
@export var ram_damage_scale := 2.6
@export var ram_self_damage_ratio := 0.42
@export var ram_cooldown_duration := 1.4
@export var powder_explosion_fire_threshold := 0.46
@export var powder_explosion_health_threshold := 0.36
@export var powder_explosion_cooldown_duration := 4.0
@export var hull_color := Color(0.21, 0.11, 0.055)
@export var sail_color := Color(0.86, 0.82, 0.70)
@export var trim_color := Color(0.64, 0.47, 0.25)

var wind_direction := Vector3.FORWARD
var wind_strength := 1.0
var velocity: Vector3:
	get:
		return linear_velocity
	set(value):
		linear_velocity = value
var health := max_health
var sail_integrity := max_sail_integrity
var rudder_integrity := max_rudder_integrity
var port_cannon_integrity := max_cannon_integrity
var starboard_cannon_integrity := max_cannon_integrity
var flooding := 0.0
var sail_setting := 0.35
var sail_step_index := 1
var _target_sail_setting := 0.38
var speed := 0.0
var is_sunk := false
var is_incapacitated := false
var incapacitated_time_remaining := 0.0
var was_captured := false
var current_shot_mode := SHOT_ROUND
var brace_stamina := 1.0
var is_bracing := false
var _perfect_brace_timer := 0.0
var accepts_player_input := true
var navigation_input_only := false
var fire_intensity := 0.0
var crew_shock := 0.0
var combat_morale := 58.0
var max_combat_morale := 100.0
var is_surrendered := false
var repair_supplies := max_repair_supplies
var is_repairing := false
var _ram_cooldown := 0.0
var _powder_explosion_cooldown := 0.0
var _mortar_reload := 0.0
var _aim_focus := 0.0
var _combat_age := 0.0
var _received_salvo_count := 0
var _received_salvo_ids: Dictionary = {}
var _received_salvo_health_damage: Dictionary = {}
var _untracked_hit_serial := 0
var _wave_time := 0.0
var ocean_simulation_time := -1.0
var ocean_sea_state := 0.95
var ocean_wave_speed := 1.0
var ocean_wave_chop := 0.90
var _crew_nodes: Array[Node3D] = []
var _crew_loss_accumulator := 0.0
var _visual_crew_losses := 0
var _permanent_visual_crew_losses := 0
var _boarding_visual_active := false
var _boarding_visual_target := Vector3.ZERO
var _boarding_visual_progress := 0.0
var _boarding_bridge: MeshInstance3D
var _boarding_rope_nodes: Array[MeshInstance3D] = []
var _boarding_hook_nodes: Array[MeshInstance3D] = []
var _crew_broadside_pulse := 0.0
var _crew_broadside_side := 0
var _boarding_fx_timer := 0.0
var _crew_update_accumulator := 0.0
var _maximum_sail_force := 170.0
var _forward_drag := 2.0
var _keel_drag := 24.0
var _rudder_force := 0.44
var _yaw_drag := 90.0
var _roll_damping := 4.2
var _target_draft := 0.68
var _buoyancy_point_depth_ratio := 0.50
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
var _water_spawn_delay := 0.12

var _port_reload := 0.0
var _starboard_reload := 0.0
var _repair_progress := 0.0
var _target_speed := 0.0
var _target_rudder := 0.0
var _current_rudder := 0.0
var _water_velocity := Vector3.ZERO
var _yaw_velocity := 0.0
var _turn_heel := 0.0
var _lateral_slip := 0.0
var _combat_turn_grip := 1.0
var _bob_phase := 0.0
var _broadside_recoil := 0.0
var _broadside_recoil_side := 0.0
var _impact_recoil := 0.0
var _impact_recoil_side := 0.0
var _impact_push_velocity := Vector3.ZERO
var _rogue_wave_roll := 0.0
var _rogue_wave_heave := 0.0
var _rogue_wave_pitch := 0.0
var _sea_heave := 0.0
var _sea_pitch := 0.0
var _sea_roll := 0.0
var _wave_visual_response := 0.88
var _wave_visual_smoothing := 3.2
var _wave_control_lock := 0.0
var _sail_hit_flutter := 0.0
var _flooding_side := 0.0
var _visual_root: Node3D
var _wake_left: MeshInstance3D
var _wake_right: MeshInstance3D
var _wake_center: MeshInstance3D
var _bow_spray: GPUParticles3D
var _stern_wash: GPUParticles3D
var _port_hull_foam: GPUParticles3D
var _starboard_hull_foam: GPUParticles3D
var _damage_smoke: GPUParticles3D
var _fire_particles: GPUParticles3D
var _fire_ember_particles: GPUParticles3D
var _port_leak_particles: GPUParticles3D
var _starboard_leak_particles: GPUParticles3D
var _sail_material: StandardMaterial3D
var _sail_view_alpha := 1.0
var _sail_nodes: Array[MeshInstance3D] = []
var _sail_tear_overlays: Array[MeshInstance3D] = []
var _hull_scorch_marks: Array[MeshInstance3D] = []
var _waterline_breaches: Array[MeshInstance3D] = []
var _persistent_damage_marks: Array[Node3D] = []
var _mast_nodes: Array[Node3D] = []
var _rigging_nodes: Array[MeshInstance3D] = []
var _flag_nodes: Array[MeshInstance3D] = []
var _captured_flag := false
var _port_cannon_nodes: Array[MeshInstance3D] = []
var _starboard_cannon_nodes: Array[MeshInstance3D] = []
var _lower_port_cannon_nodes: Array[MeshInstance3D] = []
var _lower_starboard_cannon_nodes: Array[MeshInstance3D] = []
var _port_gunport_visuals: Array[Dictionary] = []
var _starboard_gunport_visuals: Array[Dictionary] = []
var _breakable_rail_segments: Array[Dictionary] = []
var _detached_damage_parts: Array[Dictionary] = []
var _hull_fragment_cooldown := 0.0
var _rail_fragment_cooldown := 0.0
var _mast_local_damage: Array[float] = []
var _port_cannon_recoil: Array[float] = []
var _starboard_cannon_recoil: Array[float] = []
var _port_cannon_ready_markers: Array[MeshInstance3D] = []
var _starboard_cannon_ready_markers: Array[MeshInstance3D] = []
var _cannon_normal_material: StandardMaterial3D
var _cannon_damage_material: StandardMaterial3D
var _cannon_ready_material: StandardMaterial3D
var _cannon_reloading_material: StandardMaterial3D
var _cannon_disabled_material: StandardMaterial3D
var _hull_width := 3.2
var _hull_length := 8.4
var _hull_depth := 1.5
var _deck_y := 0.68
var _mast_count := 2
var _cannon_rows := 1
var _muzzle_x := 1.78
var _muzzle_y := 0.65
var _salvo_serial := 0
var _creak_timer := 0.0
var _fire_audio_latched := false
var _flood_audio_latched := false
var _sink_elapsed := 0.0
var _sink_duration := 6.0
var _sink_start_y := 0.0
var _sink_roll_direction := 1.0
var _sink_fx_stage := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("combat_ships")
	add_to_group("ships")
	_configure_hull_dimensions()
	health = max_health
	sail_integrity = max_sail_integrity
	rudder_integrity = max_rudder_integrity
	port_cannon_integrity = max_cannon_integrity
	starboard_cannon_integrity = max_cannon_integrity
	repair_supplies = max_repair_supplies
	combat_morale = clampf(float(int(get_meta("campaign_morale", 58))), 0.0, max_combat_morale)
	collision_layer = 1
	collision_mask = 1
	_bob_phase = randf() * TAU
	_sync_sail_step_to_setting()
	_build_collision()
	super._ready()
	fluid_damp = 0.0
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 12
	linear_damp = 0.015
	angular_damp = 0.025
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_configure_physics_profile()
	_configure_buoyancy_points()
	_build_visual()
	prepare_water_spawn()
	health_changed.emit(health, max_health)


func set_hull_class(type_name: String) -> void:
	hull_class = _normalize_hull_class(type_name)
	_configure_hull_dimensions()
	_configure_physics_profile()
	if is_inside_tree() and _visual_root != null:
		_rebuild_ship_geometry()


func _normalize_hull_class(type_name: String) -> String:
	var key := type_name.to_lower().replace("_", " ").replace("-", " ").replace("'", " ")
	key = " ".join(key.split(" ", false))
	if key.contains("man o war") or key.contains("man-of-war") or key.contains("manowar"):
		return "Man o' War"
	if key.contains("ship of the line") or key.contains("line ship") or key.contains("line_ship"):
		return "Ship of the Line"
	if key.contains("frigate"):
		return "Frigate"
	if key.contains("sloop") or key.contains("courier") or key.contains("raider"):
		return "Sloop"
	return "Brig"


func _configure_hull_dimensions() -> void:
	hull_class = _normalize_hull_class(hull_class)
	match hull_class:
		"Sloop":
			_hull_width = 2.45
			_hull_length = 6.6
			_hull_depth = 1.25
			_deck_y = 0.60
			_mast_count = 1
			_cannon_rows = 1
		"Frigate":
			_hull_width = 3.75
			_hull_length = 10.7
			_hull_depth = 1.95
			_deck_y = 0.98
			_mast_count = 3
			_cannon_rows = 2
		"Ship of the Line":
			_hull_width = 5.05
			_hull_length = 14.2
			_hull_depth = 3.15
			_deck_y = 1.62
			_mast_count = 3
			_cannon_rows = 3
		"Man o' War":
			# Long, low and heavily armed. The previous proportions made this
			# class read as a square floating building beside the line ship.
			_hull_width = 5.95
			_hull_length = 18.4
			_hull_depth = 3.75
			_deck_y = 1.92
			_mast_count = 3
			_cannon_rows = 4
		_:
			_hull_width = 3.2
			_hull_length = 8.4
			_hull_depth = 1.5
			_deck_y = 0.68
			_mast_count = 2
			_cannon_rows = 1
	_muzzle_x = _hull_width * 0.55
	_muzzle_y = _deck_y - 0.03


func _configure_physics_profile() -> void:
	match hull_class:
		"Sloop":
			mass = 58.0
			_maximum_sail_force = 128.0
			_keel_drag = 20.0
			_rudder_force = 0.36
			_yaw_drag = 70.0
			_roll_damping = 3.8
			_target_draft = 0.30
			_buoyancy_point_depth_ratio = 0.48
			_maximum_yaw_rate = 0.50
			_turn_response = 1.95
			_wave_visual_response = 1.08
			_wave_visual_smoothing = 4.6
		"Frigate":
			mass = 150.0
			_maximum_sail_force = 300.0
			_keel_drag = 34.0
			_rudder_force = 0.92
			_yaw_drag = 180.0
			_roll_damping = 4.8
			_target_draft = 0.86
			_buoyancy_point_depth_ratio = 0.52
			_maximum_yaw_rate = 0.38
			_turn_response = 1.55
			_wave_visual_response = 0.78
			_wave_visual_smoothing = 3.3
		"Ship of the Line":
			mass = 300.0
			_maximum_sail_force = 650.0
			_keel_drag = 50.0
			_rudder_force = 3.40
			_yaw_drag = 330.0
			_roll_damping = 5.6
			_target_draft = 1.15
			_buoyancy_point_depth_ratio = 0.52
			_maximum_yaw_rate = 0.30
			_turn_response = 1.28
			_wave_visual_response = 0.58
			_wave_visual_smoothing = 2.35
		"Man o' War":
			mass = 450.0
			_maximum_sail_force = 1000.0
			_keel_drag = 64.0
			_rudder_force = 7.20
			_yaw_drag = 480.0
			_roll_damping = 6.4
			_target_draft = 1.42
			_buoyancy_point_depth_ratio = 0.52
			_maximum_yaw_rate = 0.25
			_turn_response = 1.08
			_wave_visual_response = 0.44
			_wave_visual_smoothing = 1.75
		_:
			mass = 90.0
			_maximum_sail_force = 170.0
			_keel_drag = 24.0
			_rudder_force = 0.44
			_yaw_drag = 90.0
			_roll_damping = 4.2
			_target_draft = 0.68
			_buoyancy_point_depth_ratio = 0.50
			_maximum_yaw_rate = 0.44
			_turn_response = 1.75
			_wave_visual_response = 0.90
			_wave_visual_smoothing = 3.8
	_forward_drag = _maximum_sail_force / maxf(max_speed * max_speed, 1.0) * 0.94
	_vertical_water_damping = 4.4
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -_hull_depth * 0.34, 0.12)


func _configure_buoyancy_points() -> void:
	if fluid_interactor == null:
		return
	fluid_interactor.clear_floaters()
	_buoyancy_local_points.clear()
	_buoyancy_weights = PackedFloat32Array()
	_buoyancy_weight_total = 0.0
	# A ship is not a rectangular raft. Beam and displacement taper strongly at
	# the bow and stern, so distribute hydrostatic support along the real hull plan.
	var point_y := -_hull_depth * _buoyancy_point_depth_ratio
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
	# Centerline stem samples catch a head sea before the broad midship body does.
	for station in [-0.52, 0.46]:
		var point := Vector3(0.0, point_y + _hull_depth * 0.08, _hull_length * float(station))
		_buoyancy_local_points.append(point)
		_buoyancy_weights.append(0.34)
		_buoyancy_weight_total += 0.34
		fluid_interactor.add_floater(point)


func _rebuild_ship_geometry() -> void:
	for detached in _detached_damage_parts:
		var detached_node := detached.get("node") as Node3D
		if is_instance_valid(detached_node):
			detached_node.queue_free()
	for child in get_children():
		if child == _visual_root or child.name == "HullCollision":
			remove_child(child)
			child.free()
	_visual_root = null
	_sail_nodes.clear()
	_sail_tear_overlays.clear()
	_hull_scorch_marks.clear()
	_waterline_breaches.clear()
	_persistent_damage_marks.clear()
	_mast_nodes.clear()
	_rigging_nodes.clear()
	_flag_nodes.clear()
	_captured_flag = false
	_port_cannon_nodes.clear()
	_starboard_cannon_nodes.clear()
	_lower_port_cannon_nodes.clear()
	_lower_starboard_cannon_nodes.clear()
	_port_gunport_visuals.clear()
	_starboard_gunport_visuals.clear()
	_breakable_rail_segments.clear()
	_detached_damage_parts.clear()
	_mast_local_damage.clear()
	_crew_nodes.clear()
	_wake_left = null
	_wake_right = null
	_wake_center = null
	_bow_spray = null
	_stern_wash = null
	_port_hull_foam = null
	_starboard_hull_foam = null
	_boarding_rope_nodes.clear()
	_boarding_hook_nodes.clear()
	_port_cannon_recoil.clear()
	_starboard_cannon_recoil.clear()
	_port_cannon_ready_markers.clear()
	_starboard_cannon_ready_markers.clear()
	_build_collision()
	_configure_buoyancy_points()
	_build_visual()


func _physics_process(delta: float) -> void:
	if _water_spawn_pending:
		_update_water_spawn(delta)
		return
	if is_sunk:
		_update_sinking(delta)
		return
	if is_incapacitated:
		_combat_age += delta
		_update_incapacitated_foundering(delta)
		if is_sunk:
			return
		_target_speed = 0.0
		_current_rudder = move_toward(_current_rudder, 0.0, rudder_return_speed * delta)
		_apply_floatable_body_buoyancy()
		_apply_hydrodynamic_forces(false)
		_resolve_island_grounding()
		_update_water_motion_readings()
		_impact_push_velocity = _impact_push_velocity.move_toward(Vector3.ZERO, delta * 5.8)
		_resolve_ram_collisions()
		_update_visual(delta)
		return

	var previous_port_reload := _port_reload
	_combat_age += delta
	var previous_starboard_reload := _starboard_reload
	_port_reload = maxf(_port_reload - delta, 0.0)
	_starboard_reload = maxf(_starboard_reload - delta, 0.0)
	_mortar_reload = maxf(_mortar_reload - delta, 0.0)
	if accepts_player_input and ((previous_port_reload > 0.0 and _port_reload <= 0.0) or (previous_starboard_reload > 0.0 and _starboard_reload <= 0.0)):
		_play_audio_event("reload", true, -5.0)
	_ram_cooldown = maxf(_ram_cooldown - delta, 0.0)
	_powder_explosion_cooldown = maxf(_powder_explosion_cooldown - delta, 0.0)
	_wave_control_lock = maxf(_wave_control_lock - delta, 0.0)
	_perfect_brace_timer = maxf(_perfect_brace_timer - delta, 0.0)
	crew_shock = move_toward(crew_shock, 0.0, crew_shock_decay_rate * delta)
	_update_damage_audio(delta)
	if _update_hazards(delta):
		return
	_update_emergency_repair(delta)

	_update_brace(delta)
	_update_sail_controls(delta)

	var forward := -global_transform.basis.z.normalized()
	var wind_efficiency := _get_wind_efficiency(forward)
	var sail_factor := _get_sail_factor()
	var brace_speed_factor := brace_speed_multiplier if is_bracing else 1.0
	var sailor_ratio := clampf(float(int(get_meta("campaign_sailors", 42))) / 42.0, 0.45, 1.0)
	var sailor_speed_scale := lerpf(0.68, 1.0, sailor_ratio)
	_target_speed = max_speed * sailor_speed_scale * sail_factor * sail_setting * wind_efficiency * wind_strength * brace_speed_factor

	_target_rudder = _get_rudder_input()
	var rudder_rate := rudder_response if absf(_target_rudder) > absf(_current_rudder) else rudder_return_speed
	_current_rudder = move_toward(_current_rudder, _target_rudder, rudder_rate * delta)
	_apply_floatable_body_buoyancy()
	_apply_hydrodynamic_forces(true)
	_resolve_island_grounding()
	_update_water_motion_readings()
	_impact_push_velocity = _impact_push_velocity.move_toward(Vector3.ZERO, delta * 5.8)
	_resolve_ram_collisions()

	_update_shot_mode_input()
	var fire_request := _get_fire_request()
	var fire_aim_point := _get_fire_aim_point(fire_request)
	_try_fire(fire_request, Vector3.ZERO, fire_aim_point, fire_request != 0 and fire_aim_point != Vector3.ZERO)
	_update_visual(delta)


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
	# Distributed pressure creates most pitch and roll. This metacentric term only
	# supplies the slow, weighty return expected from a deep sailing hull.
	var wave_alignment := lerpf(0.34, 0.12, class_scale) * lerpf(0.68, 1.0, heavy_sea_ratio)
	var desired_up := Vector3.UP.lerp(_last_water_normal, wave_alignment).normalized()
	var righting_lever := lerpf(0.82, 1.42, class_scale)
	var hull_up := global_transform.basis.orthonormalized().y
	apply_torque(hull_up.cross(desired_up) * mass * gravity * righting_lever)
	var rotational_damping := lerpf(0.72, 1.18, class_scale) * lerpf(0.92, 1.16, heavy_sea_ratio)
	apply_torque(Vector3(
		-angular_velocity.x * mass * _roll_damping * rotational_damping,
		0.0,
		-angular_velocity.z * mass * _roll_damping * rotational_damping
	))
	_apply_heavy_sea_stability(gravity, heavy_sea_ratio, class_scale)


func prepare_water_spawn(delay := 0.12) -> void:
	_water_spawn_pending = true
	_water_spawn_wait = 0.0
	_water_spawn_delay = maxf(delay, 0.0)
	freeze = true
	sleeping = false
	visible = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _update_water_spawn(delta: float) -> void:
	_water_spawn_wait += delta
	if _water_spawn_wait < _water_spawn_delay:
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
	# Start level and at the hydrostatic equilibrium draft. The distributed
	# buoyancy takes over from this stable pose on the following physics frame.
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
	if sample_weight_total <= 0.01:
		return
	global_position.y = required_y_total / sample_weight_total + 0.08


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


func _apply_hydrodynamic_forces(allow_controls: bool) -> void:
	var ship_basis := global_transform.basis.orthonormalized()
	var forward := -ship_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := ship_basis.x
	right.y = 0.0
	right = right.normalized()
	if forward.length_squared() < 0.5 or right.length_squared() < 0.5:
		return

	var relative_water_velocity := linear_velocity - _last_surface_velocity
	var forward_speed := relative_water_velocity.dot(forward)
	if allow_controls and _target_speed > 0.01:
		var drive_ratio := clampf(_target_speed / maxf(max_speed, 0.1), 0.0, 1.08)
		apply_central_force(forward * _maximum_sail_force * drive_ratio)
	var forward_resistance := -signf(forward_speed) * forward_speed * forward_speed * _forward_drag
	apply_central_force(forward * forward_resistance)

	var bow_offset := ship_basis * Vector3(0.0, -_hull_depth * 0.18, -_hull_length * 0.31)
	var stern_offset := ship_basis * Vector3(0.0, -_hull_depth * 0.18, _hull_length * 0.36)
	_apply_keel_force(bow_offset, right, _last_surface_velocity)
	_apply_keel_force(stern_offset, right, _last_surface_velocity)

	var speed_ratio := clampf(absf(forward_speed) / maxf(max_speed, 0.1), 0.0, 1.0)
	_combat_turn_grip = _get_combat_turn_grip(speed_ratio)
	var steering_authority := lerpf(0.34, 1.0, sqrt(speed_ratio))
	var effective_rudder := _current_rudder * _get_rudder_factor() * _get_sail_handling_multiplier() * _combat_turn_grip
	if is_bracing:
		effective_rudder *= brace_turn_multiplier
	if not allow_controls:
		effective_rudder = 0.0
	var rudder_authority := maxf(absf(forward_speed), max_speed * 0.28)
	apply_force(right * effective_rudder * rudder_authority * rudder_authority * _rudder_force, stern_offset)
	var target_yaw_rate := effective_rudder * _maximum_yaw_rate * steering_authority
	var yaw_inertia := mass * (_hull_length * _hull_length + _hull_width * _hull_width) / 12.0
	var steering_torque := (target_yaw_rate - angular_velocity.y) * yaw_inertia * _turn_response
	apply_torque(Vector3.UP * (steering_torque - angular_velocity.y * _yaw_drag))

	var horizontal_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	if horizontal_speed > max_speed * 1.16:
		var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		apply_central_force(-horizontal_velocity.normalized() * mass * (horizontal_speed - max_speed * 1.16) * 3.0)


func _apply_keel_force(offset: Vector3, right: Vector3, water_velocity := Vector3.ZERO) -> void:
	var point_velocity := linear_velocity + angular_velocity.cross(offset) - water_velocity
	var side_speed := point_velocity.dot(right)
	var resistance := -side_speed * _keel_drag * (1.0 + absf(side_speed) * 0.20)
	apply_force(right * resistance, offset)


func _update_water_motion_readings() -> void:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	speed = maxf(linear_velocity.dot(forward), 0.0)
	_water_velocity = linear_velocity
	_yaw_velocity = angular_velocity.y
	_lateral_slip = clampf(linear_velocity.dot(right) / maxf(max_speed, 1.0), -1.0, 1.0)
	_turn_heel = move_toward(_turn_heel, 0.0, 0.04)


func _apply_hull_yaw(yaw_delta: float) -> void:
	if absf(yaw_delta) <= 0.000001:
		return
	var speed_ratio := clampf(absf(speed) / maxf(max_speed, 1.0), 0.0, 1.0)
	var pivot_distance := _hull_length * lerpf(0.025, 0.17, sqrt(speed_ratio))
	var forward_before := -global_transform.basis.z.normalized()
	var pivot_before := global_position + forward_before * pivot_distance
	rotate_y(yaw_delta)
	var forward_after := -global_transform.basis.z.normalized()
	var pivot_after := global_position + forward_after * pivot_distance
	global_position += pivot_before - pivot_after


func _get_sail_input() -> float:
	if not accepts_player_input or _wave_control_lock > 0.0:
		return 0.0
	return Input.get_action_strength("sail_up") - Input.get_action_strength("sail_down")


func _update_sail_controls(delta: float) -> void:
	if accepts_player_input and _wave_control_lock <= 0.0:
		if Input.is_action_just_pressed("sail_up"):
			set_sail_step(sail_step_index + 1)
		elif Input.is_action_just_pressed("sail_down"):
			set_sail_step(sail_step_index - 1)
		sail_setting = move_toward(sail_setting, _target_sail_setting, sail_change_rate * delta)
		return

	var sail_input := _get_sail_input()
	sail_setting = clampf(sail_setting + sail_input * sail_change_rate * delta, 0.0, 1.0)


func set_sail_step(step: int, immediate := false) -> void:
	sail_step_index = clampi(step, 0, SAIL_STEPS.size() - 1)
	_target_sail_setting = float(SAIL_STEPS[sail_step_index])
	if immediate:
		sail_setting = _target_sail_setting
	if accepts_player_input and not immediate:
		_play_audio_event("command", true, -7.0)


func _sync_sail_step_to_setting() -> void:
	sail_step_index = _get_sail_step_for_value(sail_setting)
	_target_sail_setting = sail_setting


func _get_sail_step_for_value(value: float) -> int:
	if value < 0.12:
		return 0
	if value < 0.53:
		return 1
	if value < 0.84:
		return 2
	return 3


func get_sail_state_label() -> String:
	return String(SAIL_STEP_LABELS[clampi(sail_step_index, 0, SAIL_STEP_LABELS.size() - 1)])


func _get_sail_handling_multiplier() -> float:
	match sail_step_index:
		0: return 0.62
		1: return 1.34
		2: return 1.10
		_: return 0.86


func _get_combat_turn_grip(speed_ratio: float) -> float:
	var full_helm := smoothstep(0.58, 0.96, absf(_current_rudder))
	var class_grip := 1.04
	match hull_class:
		"Sloop": class_grip = 1.02
		"Frigate": class_grip = 1.04
		"Ship of the Line": class_grip = 1.07
		"Man o' War": class_grip = 1.09
	var speed_grip := lerpf(0.88, 1.0, clampf(speed_ratio / 0.55, 0.0, 1.0))
	return lerpf(1.0, class_grip, full_helm) * speed_grip


func _get_yaw_acceleration() -> float:
	match hull_class:
		"Sloop": return 2.05
		"Frigate": return 1.45
		"Ship of the Line": return 1.02
		"Man o' War": return 0.84
	return 1.70


func _get_yaw_damping() -> float:
	match hull_class:
		"Sloop": return 2.70
		"Frigate": return 1.85
		"Ship of the Line": return 1.28
		"Man o' War": return 1.04
	return 2.15


func _get_lateral_water_drag() -> float:
	match hull_class:
		"Sloop": return 2.55
		"Frigate": return 1.62
		"Ship of the Line": return 1.12
		"Man o' War": return 0.92
	return 2.02


func _get_turn_heel_scale() -> float:
	match hull_class:
		"Sloop": return 0.125
		"Frigate": return 0.095
		"Ship of the Line": return 0.070
		"Man o' War": return 0.058
	return 0.108


func _get_rudder_input() -> float:
	if not accepts_player_input or _wave_control_lock > 0.0:
		return 0.0
	return Input.get_action_strength("rudder_left") - Input.get_action_strength("rudder_right")


func _get_fire_request() -> int:
	if not accepts_player_input or navigation_input_only or _wave_control_lock > 0.0 or Input.is_action_pressed("aim_hold"):
		return 0
	if Input.is_action_just_pressed("fire_port"):
		return -1
	if Input.is_action_just_pressed("fire_starboard"):
		return 1
	return 0


func _update_hazards(_delta: float) -> bool:
	# Fire and flooding are intentionally disabled for the arcade combat model.
	flooding = 0.0
	fire_intensity = 0.0
	_flooding_side = 0.0
	_fire_audio_latched = false
	_flood_audio_latched = false
	return false


func _update_emergency_repair(delta: float) -> void:
	var wants_repair := accepts_player_input and not navigation_input_only and Input.is_action_pressed("emergency_repair")
	if not wants_repair or not can_emergency_repair():
		is_repairing = false
		_repair_progress = 0.0
		return

	is_repairing = true
	_repair_progress += delta
	if _repair_progress >= emergency_repair_duration:
		perform_emergency_repair()


func can_emergency_repair() -> bool:
	return repair_supplies > 0 and (health < max_health or sail_integrity < max_sail_integrity or rudder_integrity < max_rudder_integrity or port_cannon_integrity < max_cannon_integrity or starboard_cannon_integrity < max_cannon_integrity or crew_shock > 0.12 or _visual_crew_losses > _permanent_visual_crew_losses)


func perform_emergency_repair() -> bool:
	if not can_emergency_repair():
		return false

	repair_supplies -= 1
	var carpenter_ratio := clampf(float(int(get_meta("campaign_carpenters", 6))) / 6.0, 0.35, 1.0)
	var repair_scale := lerpf(0.72, 1.0, carpenter_ratio)
	var hull_repair := clampf(maxf(emergency_repair_health, max_health * 0.18), emergency_repair_health, 86.0)
	health = clampf(health + hull_repair * repair_scale, 0.0, max_health)
	sail_integrity = clampf(sail_integrity + 20.0 * repair_scale, 0.0, max_sail_integrity)
	rudder_integrity = clampf(rudder_integrity + 22.0 * repair_scale, 0.0, max_rudder_integrity)
	port_cannon_integrity = clampf(port_cannon_integrity + 14.0 * repair_scale, 0.0, max_cannon_integrity)
	starboard_cannon_integrity = clampf(starboard_cannon_integrity + 14.0 * repair_scale, 0.0, max_cannon_integrity)
	flooding = 0.0
	fire_intensity = 0.0
	_flooding_side = 0.0
	crew_shock = maxf(crew_shock - 0.55 * repair_scale, 0.0)
	_recover_visual_crew(maxi(int(ceil(float(_crew_nodes.size()) * 0.34 * repair_scale)), 1))
	is_repairing = false
	_repair_progress = 0.0
	_update_damage_smoke()
	_update_regional_damage_visuals()
	_update_flooding_visuals()
	health_changed.emit(health, max_health)
	_play_audio_event("command", accepts_player_input, -4.0)
	return true


func _update_brace(delta: float) -> void:
	var was_bracing := is_bracing
	var wants_brace := accepts_player_input and not navigation_input_only and Input.is_action_pressed("brace")
	if wants_brace and brace_stamina > 0.05:
		if not is_bracing:
			_perfect_brace_timer = perfect_brace_window
		is_bracing = true
		brace_stamina = maxf(brace_stamina - brace_drain_rate * delta, 0.0)
	else:
		is_bracing = false
		brace_stamina = minf(brace_stamina + brace_recover_rate * delta, 1.0)
	if is_bracing and not was_bracing:
		_play_audio_event("command", true, -3.0)


func _update_combat_morale(delta: float) -> void:
	var hazard_pressure := crew_shock * 0.34
	if hazard_pressure > 0.05:
		combat_morale = maxf(combat_morale - hazard_pressure * delta, 0.0)
	elif health / maxf(max_health, 1.0) > 0.72:
		combat_morale = minf(combat_morale + delta * 0.18, max_combat_morale)


func _update_damage_audio(delta: float) -> void:
	_creak_timer = maxf(_creak_timer - delta, 0.0)
	var hull_ratio := health / maxf(max_health, 1.0)
	if hull_ratio < 0.62 and _creak_timer <= 0.0:
		_creak_timer = lerpf(8.5, 3.2, 1.0 - hull_ratio) + randf_range(-0.6, 0.8)
		_play_audio_event("creak", false, -5.0)


func _play_audio_event(event_name: String, ui := false, volume_db := 0.0) -> void:
	if get_tree() == null:
		return
	var audio_nodes := get_tree().get_nodes_in_group("combat_audio")
	if audio_nodes.is_empty():
		return
	var audio: Node = audio_nodes[0]
	if ui and audio.has_method("play_ui"):
		audio.play_ui(event_name, volume_db)
	elif audio.has_method("play_spatial"):
		audio.play_spatial(event_name, global_position, volume_db)


func apply_morale_damage(amount: float) -> float:
	var previous := combat_morale
	combat_morale = clampf(combat_morale - maxf(amount, 0.0), 0.0, max_combat_morale)
	return previous - combat_morale


func surrender_ship() -> void:
	if is_sunk or is_surrendered:
		return
	is_surrendered = true
	combat_morale = 0.0
	incapacitate_for_boarding()
	surrendered.emit(self)


func get_surrender_resistance() -> float:
	match hull_class:
		"Sloop":
			return 0.0
		"Brig":
			return 7.0
		"Frigate":
			return 18.0
		"Ship of the Line":
			return 40.0
		"Man o' War":
			return 58.0
	return 8.0


func get_surrender_resolve() -> float:
	var health_ratio := health / maxf(max_health, 1.0)
	var systems_ratio := (sail_integrity + rudder_integrity + port_cannon_integrity + starboard_cannon_integrity) / maxf(max_sail_integrity + max_rudder_integrity + max_cannon_integrity * 2.0, 1.0)
	var disabled_penalty := 24.0 if is_incapacitated else 0.0
	var hazard_penalty := 0.0
	return combat_morale + health_ratio * 42.0 + systems_ratio * 18.0 + get_surrender_resistance() - disabled_penalty - hazard_penalty


func set_bracing(active: bool) -> void:
	var next_bracing := active and brace_stamina > 0.0
	if next_bracing and not is_bracing:
		_perfect_brace_timer = perfect_brace_window
	is_bracing = next_bracing


func get_brace_factor() -> float:
	if not is_bracing:
		return 1.0
	return 1.0 - (perfect_brace_damage_reduction if _perfect_brace_timer > 0.0 else brace_damage_reduction)


func is_perfect_bracing() -> bool:
	return is_bracing and _perfect_brace_timer > 0.0


func _update_shot_mode_input() -> void:
	current_shot_mode = SHOT_ROUND


func set_shot_mode(mode: String) -> void:
	current_shot_mode = SHOT_ROUND


func get_shot_mode_label() -> String:
	match current_shot_mode:
		SHOT_CHAIN:
			return "Chain"
		SHOT_GRAPE:
			return "Grape"
	return "Round"


func get_current_shot_profile() -> Dictionary:
	return _get_current_shot_profile()


func _get_fire_aim_point(_side: int) -> Vector3:
	return Vector3.ZERO


func fire_camera_broadside(aim_direction: Vector3, forced_side := 0, aim_point := Vector3.ZERO) -> bool:
	var resolved_side := get_broadside_side_for_camera_aim(aim_direction, aim_point)
	var side := resolved_side if resolved_side != 0 else forced_side
	if side == 0:
		side = 1

	return _try_fire(side, aim_direction, aim_point, aim_point != Vector3.ZERO)


func get_broadside_side_for_camera_aim(aim_direction: Vector3, aim_point := Vector3.ZERO) -> int:
	var point_side := get_broadside_side_for_point(aim_point)
	if point_side != 0:
		return point_side
	return get_broadside_side_for_direction(aim_direction)


func get_broadside_side_for_point(aim_point: Vector3) -> int:
	if aim_point == Vector3.ZERO:
		return 0

	var local_point := to_local(aim_point)
	if absf(local_point.x) < 0.30:
		return 0
	return 1 if local_point.x > 0.0 else -1


func get_broadside_side_for_direction(aim_direction: Vector3) -> int:
	aim_direction.y = 0.0
	if aim_direction.length_squared() < 0.01:
		return 0

	var side_score := aim_direction.normalized().dot(global_transform.basis.x.normalized())
	if absf(side_score) < 0.02:
		return 0
	return 1 if side_score > 0.0 else -1


func can_fire_side(side: int) -> bool:
	if is_sunk:
		return false
	if side < 0:
		return _port_reload <= 0.0 and not _get_active_cannon_placements(side).is_empty()
	if side > 0:
		return _starboard_reload <= 0.0 and not _get_active_cannon_placements(side).is_empty()
	return false


func can_fire_mortar() -> bool:
	return hull_class in ["Ship of the Line", "Man o' War"] and not is_sunk and not is_incapacitated and _mortar_reload <= 0.0


func fire_mortar(aim_point: Vector3) -> bool:
	if not can_fire_mortar():
		return false
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	if scene == null:
		return false
	_mortar_reload = _get_mortar_reload_duration()
	_salvo_serial += 1
	var salvo_id := "%d:mortar:%d" % [get_instance_id(), _salvo_serial]
	var shell_count := get_mortar_shell_count()
	var spread := lerpf(7.2, 2.4, clampf(_aim_focus, 0.0, 1.0))
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var pattern := [Vector2(-0.65, -0.30), Vector2(0.65, 0.30), Vector2(-0.22, 0.70), Vector2(0.22, -0.70)]
	for index in range(shell_count):
		var offset: Vector2 = pattern[index]
		var shell_target := aim_point + right * offset.x * spread + forward * offset.y * spread
		CombatFx.spawn_mortar_target(scene, shell_target, 3.2 + float(index) * 0.12, 2.2 if shell_count == 2 else 2.8)
		_launch_mortar_shell(scene, shell_target, salvo_id, index, shell_count)
	_play_audio_event("command", true, -8.0)
	return true


func get_mortar_shell_count() -> int:
	if hull_class == "Ship of the Line":
		return 2
	if hull_class == "Man o' War":
		return 4
	return 0


func _get_mortar_reload_duration() -> float:
	return 7.4 if hull_class == "Ship of the Line" else 5.8


func _launch_mortar_shell(scene: Node, aim_point: Vector3, salvo_id: String, index: int, shell_count: int) -> void:
	var delay := float(index) * 0.12
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self) or is_sunk or scene == null:
		return
	var tube_offset := (float(index) - float(shell_count - 1) * 0.5) * 0.42
	var mortar_z := _hull_length * 0.035 if hull_class == "Man o' War" else -_hull_length * 0.12
	var start := to_global(Vector3(tube_offset, _deck_y + 1.25, mortar_z))
	var horizontal_distance := Vector2(aim_point.x - start.x, aim_point.z - start.z).length()
	var flight_time := clampf(horizontal_distance / 31.0, 1.35, 3.35)
	var gravity := 13.8
	var displacement := aim_point - start
	var launch_velocity := Vector3(displacement.x / flight_time, (displacement.y + 0.5 * gravity * flight_time * flight_time) / flight_time, displacement.z / flight_time)
	var profile := {
		"salvo_id": salvo_id,
		"damage_scale": 1.0,
		"hit_radius": 1.65,
		"explosion_radius": 9.5 if hull_class == "Man o' War" else 8.5,
		"hull_scale": 1.15,
		"sail_scale": 0.68,
		"cannon_scale": 1.25,
		"flooding_scale": 0.80,
		"crew_shock_scale": 1.6,
		"fire_chance": 0.32,
	}
	var shell: Area3D = Cannonball.acquire(scene, SHOT_MORTAR, profile)
	if shell == null:
		return
	shell.call("_clear_pool_marker")
	shell.ballistic_gravity = gravity
	shell.lifetime = 6.5
	shell.global_position = start
	shell.launch_velocity(launch_velocity, self, 19.0 if hull_class == "Man o' War" else 23.0)
	CombatFx.spawn_muzzle_burst(scene, start, launch_velocity.normalized())


func get_reload_for_side(side: int) -> float:
	if side < 0:
		return _port_reload
	if side > 0:
		return _starboard_reload
	return 0.0


func get_cannon_integrity(side: int) -> float:
	if side < 0:
		return port_cannon_integrity
	if side > 0:
		return starboard_cannon_integrity
	return max_cannon_integrity


func set_aim_focus(value: float) -> void:
	_aim_focus = clampf(value, 0.0, 1.0)


func get_aim_focus() -> float:
	return _aim_focus


func get_salvo_area_radius() -> float:
	return get_salvo_area_radius_for_distance(-1.0)


func get_salvo_area_radius_for_distance(aim_distance: float) -> float:
	var loose_radius := 7.2
	var focused_radius := 1.10
	match hull_class:
		"Sloop":
			loose_radius = 5.2
			focused_radius = 0.85
		"Frigate":
			loose_radius = 9.2
			focused_radius = 1.15
		"Ship of the Line":
			loose_radius = 11.8
			focused_radius = 1.45
		"Man o' War":
			loose_radius = 14.4
			focused_radius = 1.75
	var distance_scale := 1.0
	if aim_distance >= 0.0:
		distance_scale = lerpf(0.76, 1.18, clampf((aim_distance - 18.0) / 102.0, 0.0, 1.0))
	return lerpf(loose_radius * distance_scale, focused_radius, smoothstep(0.0, 1.0, _aim_focus))


func get_cannon_preview_points(side: int, aim_point: Vector3, step := 0.12, count := 20) -> PackedVector3Array:
	var positions := _get_full_cannon_positions()
	var center_z := positions[int(positions.size() / 2)] if not positions.is_empty() else 0.0
	return get_cannon_preview_points_for_muzzle(side, aim_point, center_z, step, count)


func get_cannon_preview_points_for_muzzle(side: int, aim_point: Vector3, local_z: float, step := 0.12, count := 20) -> PackedVector3Array:
	var points := PackedVector3Array()
	if side == 0 or is_sunk:
		return points

	var preview_y := _deck_y - 0.28
	var preview_x := _get_hull_side_surface_x(preview_y, local_z) + 0.24
	var muzzle_position := to_global(Vector3(preview_x * float(side), preview_y, local_z))
	var fallback := _get_clamped_broadside_direction(side, aim_point - muzzle_position)
	var preview_velocity := _get_aimed_cannon_velocity(muzzle_position, aim_point, fallback, side, true)
	var position := muzzle_position

	for i in range(count):
		points.append(position)
		position += preview_velocity * step
		preview_velocity.y -= cannon_gravity * step
		if position.y < -0.35:
			points.append(Vector3(position.x, -0.35, position.z))
			break

	return points


func get_cannon_preview_lines(side: int, aim_point: Vector3, step := 0.12, count := 22) -> Array[PackedVector3Array]:
	var lines: Array[PackedVector3Array] = []
	if side == 0 or is_sunk:
		return lines

	var muzzles := _get_active_muzzle_z(side)
	var preview_count := mini(muzzles.size(), 7)
	var area_radius := get_salvo_area_radius_for_distance(global_position.distance_to(aim_point))
	var tangent := Vector3(aim_point.z - global_position.z, 0.0, -(aim_point.x - global_position.x)).normalized()
	for i in range(preview_count):
		var muzzle_index := int(round(float(i) * float(maxi(muzzles.size() - 1, 0)) / float(maxi(preview_count - 1, 1))))
		var spread_t := (float(i) / float(maxi(preview_count - 1, 1)) - 0.5) * 2.0
		lines.append(get_cannon_preview_points_for_muzzle(side, aim_point + tangent * spread_t * area_radius, muzzles[muzzle_index], step, count))
	return lines


func get_cannon_aim_solution(side: int, aim_point: Vector3) -> Dictionary:
	var lines := get_cannon_preview_lines(side, aim_point)
	var center_line := get_cannon_preview_points(side, aim_point)
	var impact_point := aim_point
	if center_line.size() > 0:
		impact_point = center_line[center_line.size() - 1]
	var horizontal_miss := Vector2(impact_point.x - aim_point.x, impact_point.z - aim_point.z).length()
	return {
		"lines": lines,
		"impact_point": impact_point,
		"aim_point": aim_point,
		"is_clamped": horizontal_miss > 1.15,
		"horizontal_miss": horizontal_miss,
		"focus": _aim_focus,
		"area_radius": get_salvo_area_radius_for_distance(global_position.distance_to(aim_point)),
	}


func _try_fire(side: int, aim_direction := Vector3.ZERO, aim_point := Vector3.ZERO, use_aim_point := false) -> bool:
	if side == 0 or is_sunk:
		return false
	var active_cannons := _get_active_cannon_placements(side)
	if active_cannons.is_empty():
		return false

	if side < 0:
		if _port_reload > 0.0:
			return false
		_port_reload = _get_reload_duration(side)
	else:
		if _starboard_reload > 0.0:
			return false
		_starboard_reload = _get_reload_duration(side)

	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()

	var aimed_basis := _get_clamped_broadside_direction(side, aim_direction)
	var shot_mode_snapshot := current_shot_mode
	var shot_profile_snapshot := _get_current_shot_profile().duplicate(true)
	_salvo_serial += 1
	shot_profile_snapshot["salvo_id"] = "%d:%d" % [get_instance_id(), _salvo_serial]
	shot_profile_snapshot["aim_focus"] = _aim_focus
	var total_shots := active_cannons.size()
	shot_profile_snapshot["salvo_shots"] = total_shots
	var critical_chance := lerpf(0.035, 0.13, smoothstep(0.0, 1.0, _aim_focus))
	var critical_index := randi_range(0, total_shots - 1) if total_shots > 0 and randf() < critical_chance else -1
	var shot_index := 0
	var aim_distance := global_position.distance_to(aim_point) if use_aim_point else 48.0
	var area_radius := get_salvo_area_radius_for_distance(aim_distance)
	shot_profile_snapshot["salvo_area_radius"] = area_radius
	shot_profile_snapshot["range_penetration"] = lerpf(1.12, 0.78, clampf((aim_distance - 18.0) / 102.0, 0.0, 1.0))
	var to_aim := aim_point - global_position
	var area_tangent := Vector3(to_aim.z, 0.0, -to_aim.x).normalized()
	if area_tangent.length_squared() < 0.01:
		area_tangent = -global_transform.basis.z.normalized()
	CombatFx.spawn_broadside_smoke_bank(scene, self, side, total_shots)
	for placement in active_cannons:
		var deck_row := int(placement.get("deck_row", 0))
		var local_z := float(placement.get("z", 0.0))
		var local_y := float(placement.get("y", _muzzle_y))
		var cannon_profile := shot_profile_snapshot.duplicate(true)
		cannon_profile["salvo_critical"] = shot_index == critical_index
		cannon_profile["muzzle_fx"] = true
		var column_t := clampf(local_z / maxf(_hull_length * 0.305, 0.1), -1.0, 1.0)
		var row_jitter := randf_range(-0.24, 0.24) * area_radius
		var shot_aim_point := aim_point + area_tangent * (column_t * area_radius * 0.72 + row_jitter)
		var vertical_spread := area_radius * lerpf(0.12, 0.035, _aim_focus)
		shot_aim_point.y += float(deck_row) * 0.08 + randf_range(-vertical_spread, vertical_spread)
		var column_delay := (column_t + 1.0) * 0.5 * float(maxi(base_cannons_per_side - 1, 1)) * _get_class_volley_interval()
		var delay := column_delay + float(deck_row) * _get_deck_volley_interval()
		_schedule_cannon_shot(scene, side, local_z, local_y, aimed_basis, shot_aim_point, use_aim_point, shot_mode_snapshot, cannon_profile, delay)
		shot_index += 1

	var broadside_weight := _get_broadside_class_weight()
	speed = maxf(speed - 0.24 * broadside_weight, 0.0)
	_broadside_recoil = maxf(_broadside_recoil, broadside_weight)
	_broadside_recoil_side = float(side)
	_crew_broadside_pulse = 1.0
	_crew_broadside_side = side
	broadside_fired.emit(side)
	return true


func _get_class_volley_interval() -> float:
	match hull_class:
		"Sloop": return 0.060
		"Frigate": return 0.090
		"Ship of the Line": return 0.112
		"Man o' War": return 0.132
	return 0.074


func _get_deck_volley_interval() -> float:
	match hull_class:
		"Frigate": return 0.095
		"Ship of the Line": return 0.125
		"Man o' War": return 0.145
	return 0.055


func _get_broadside_class_weight() -> float:
	match hull_class:
		"Sloop": return 0.68
		"Frigate": return 1.05
		"Ship of the Line": return 1.32
		"Man o' War": return 1.58
	return 0.84


func _schedule_cannon_shot(scene: Node, side: int, local_z: float, local_y: float, aimed_basis: Vector3, aim_point: Vector3, use_aim_point: bool, shot_mode: String, shot_profile: Dictionary, delay: float) -> void:
	if delay <= 0.001:
		_fire_single_cannon(scene, side, local_z, local_y, aimed_basis, aim_point, use_aim_point, shot_mode, shot_profile)
		return
	_fire_single_cannon_delayed(scene, side, local_z, local_y, aimed_basis, aim_point, use_aim_point, shot_mode, shot_profile, delay)


func _fire_single_cannon_delayed(scene: Node, side: int, local_z: float, local_y: float, aimed_basis: Vector3, aim_point: Vector3, use_aim_point: bool, shot_mode: String, shot_profile: Dictionary, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_fire_single_cannon(scene, side, local_z, local_y, aimed_basis, aim_point, use_aim_point, shot_mode, shot_profile)


func _fire_single_cannon(scene: Node, side: int, local_z: float, local_y: float, aimed_basis: Vector3, aim_point: Vector3, use_aim_point: bool, shot_mode: String, shot_profile: Dictionary) -> void:
	if is_sunk or scene == null or not is_instance_valid(scene):
		return
	var muzzle_x := _get_hull_side_surface_x(local_y, local_z) + 0.24
	var muzzle_local := Vector3(muzzle_x * float(side), local_y, local_z)
	var muzzle_position := _visual_root.to_global(muzzle_local) if is_instance_valid(_visual_root) else to_global(muzzle_local)
	_kick_cannon_recoil(side, local_z)

	if shot_mode == SHOT_GRAPE:
		_fire_grape_cluster(scene, side, local_z, local_y, aimed_basis, aim_point, use_aim_point, shot_profile)
		return

	var ball: Area3D = Cannonball.acquire(scene, shot_mode, shot_profile)
	if ball == null:
		return
	ball.call("_clear_pool_marker")
	ball.global_position = muzzle_position
	var integrity_ratio := clampf(get_cannon_integrity(side) / maxf(max_cannon_integrity, 1.0), 0.0, 1.0)
	var speed_ratio := clampf(absf(speed) / maxf(max_speed, 1.0), 0.0, 1.0)
	var focus_snapshot := clampf(float(shot_profile.get("aim_focus", _aim_focus)), 0.0, 1.0)
	var aimed_spread := lerpf(1.10, 0.12, smoothstep(0.0, 1.0, focus_snapshot)) + speed_ratio * 0.18 + (1.0 - integrity_ratio) * 0.48
	var spread := deg_to_rad(randf_range(-aimed_spread, aimed_spread) if use_aim_point else randf_range(-4.8, 4.8))
	var inherited := -global_transform.basis.z.normalized() * speed
	if use_aim_point:
		var launch_velocity := _get_aimed_cannon_velocity(muzzle_position, aim_point, aimed_basis, side, true).rotated(Vector3.UP, spread)
		launch_velocity.y += randf_range(-0.18, 0.18)
		if bool(shot_profile.get("muzzle_fx", false)):
			CombatFx.spawn_muzzle_burst(scene, muzzle_position, launch_velocity.normalized())
		ball.launch_velocity(launch_velocity, self, cannon_damage * float(shot_profile.get("damage_scale", 1.0)))
	else:
		var direction := _get_aimed_cannon_direction(muzzle_position, aim_point, aimed_basis, side, false).rotated(Vector3.UP, spread).normalized()
		if bool(shot_profile.get("muzzle_fx", false)):
			CombatFx.spawn_muzzle_burst(scene, muzzle_position, direction)
		ball.launch(direction, inherited, cannon_shot_speed * float(shot_profile.get("speed_scale", 1.0)), self, cannon_damage * float(shot_profile.get("damage_scale", 1.0)), 3.6)


func _kick_cannon_recoil(side: int, local_z: float) -> void:
	var positions := _get_full_cannon_positions()
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(positions.size()):
		var distance := absf(positions[i] - local_z)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
	if nearest_index < 0:
		return
	var recoil := _port_cannon_recoil if side < 0 else _starboard_cannon_recoil
	if nearest_index < recoil.size():
		recoil[nearest_index] = 1.0


func _fire_grape_cluster(scene: Node, side: int, local_z: float, local_y: float, aimed_basis: Vector3, aim_point: Vector3, use_aim_point: bool, shot_profile: Dictionary) -> void:
	var muzzle_x := _get_hull_side_surface_x(local_y, local_z) + 0.24
	var muzzle_position := to_global(Vector3(muzzle_x * float(side), local_y, local_z))
	var inherited := -global_transform.basis.z.normalized() * speed
	var base_velocity := Vector3.ZERO
	if use_aim_point:
		base_velocity = _get_aimed_cannon_velocity(muzzle_position, aim_point, aimed_basis, side, true)
	else:
		base_velocity = aimed_basis.normalized() * cannon_shot_speed * float(shot_profile.get("speed_scale", 1.0)) + inherited + Vector3.UP * 2.7
	if base_velocity.length_squared() < 0.01:
		base_velocity = aimed_basis.normalized() * cannon_shot_speed

	var pellet_count := 2 if _cannon_rows >= 3 else (3 if _cannon_rows == 2 else clampi(grape_pellets_per_cannon, 3, 6))
	var base_direction := base_velocity.normalized()
	if bool(shot_profile.get("muzzle_fx", false)):
		CombatFx.spawn_muzzle_burst(scene, muzzle_position, base_direction)
		CombatFx.spawn_grape_muzzle_cone(scene, muzzle_position, base_direction)

	for i in range(pellet_count):
		var pellet_profile := shot_profile.duplicate(true)
		pellet_profile["hit_radius"] = clampf(float(shot_profile.get("hit_radius", 1.0)) * 0.72, 0.62, 0.92)
		pellet_profile["salvo_critical"] = bool(shot_profile.get("salvo_critical", false)) and i == 0
		var pellet: Area3D = Cannonball.acquire(scene, SHOT_GRAPE, pellet_profile)
		if pellet == null:
			continue
		pellet.call("_clear_pool_marker")
		pellet.name = "GrapePellet"
		pellet.global_position = muzzle_position + base_direction * 0.12
		var yaw := deg_to_rad(randf_range(-grape_spread_degrees, grape_spread_degrees))
		var vertical_lift := randf_range(-0.035, 0.135)
		var velocity_direction := (base_direction.rotated(Vector3.UP, yaw) + Vector3.UP * vertical_lift).normalized()
		var velocity_scale := randf_range(0.86, 1.04)
		var pellet_velocity := velocity_direction * base_velocity.length() * velocity_scale
		if not use_aim_point:
			pellet_velocity += inherited * 0.18
		pellet.launch_velocity(pellet_velocity, self, cannon_damage * float(shot_profile.get("damage_scale", 1.0)) * 0.32)


func _get_reload_duration(_side: int) -> float:
	return cannon_reload


func _get_current_shot_profile() -> Dictionary:
	match current_shot_mode:
		SHOT_CHAIN:
			return {
				"damage_scale": 0.78,
				"speed_scale": 0.88,
				"reload_scale": 1.12,
				"hit_radius": 1.18,
				"sail_scale": 2.25,
				"rudder_scale": 1.35,
				"hull_scale": 0.42,
				"cannon_scale": 0.55,
				"flooding_scale": 0.18,
				"crew_shock_scale": 0.62,
			}
		SHOT_GRAPE:
			return {
				"damage_scale": 0.58,
				"speed_scale": 0.78,
				"reload_scale": 0.82,
				"hit_radius": 1.05,
				"sail_scale": 0.65,
				"rudder_scale": 0.7,
				"hull_scale": 0.35,
				"cannon_scale": 1.75,
				"flooding_scale": 0.08,
				"crew_shock_scale": 2.25,
			}
	return {
		"damage_scale": 1.0,
		"speed_scale": 1.0,
		"reload_scale": 1.0,
		"hit_radius": 1.15,
		"sail_scale": 1.0,
		"rudder_scale": 1.0,
		"hull_scale": 1.0,
		"cannon_scale": 1.0,
		"flooding_scale": 1.0,
		"crew_shock_scale": 1.0,
	}


func _get_active_muzzle_z(side: int) -> Array[float]:
	var active: Array[float] = []
	for placement in _get_active_cannon_placements(side):
		var z := float(placement.get("z", 0.0))
		var found := false
		for existing in active:
			if is_equal_approx(existing, z):
				found = true
				break
		if not found:
			active.append(z)
	return active


func _get_active_cannon_placements(side: int) -> Array[Dictionary]:
	var source := _port_gunport_visuals if side < 0 else _starboard_gunport_visuals
	var active: Array[Dictionary] = []
	for placement in source:
		if not bool(placement.get("disabled", false)):
			active.append(placement)
	return active


func _get_full_cannon_positions() -> Array[float]:
	return _get_cannon_positions_for_row(maxi(_cannon_rows - 1, 0))


func _get_cannon_positions_for_row(deck_row: int) -> Array[float]:
	var positions: Array[float] = []
	var count := maxi(base_cannons_per_side, 1)
	if _cannon_rows > 1:
		if deck_row == 0:
			count = maxi(base_cannons_per_side - 1, 2)
		elif deck_row == _cannon_rows - 1:
			count = base_cannons_per_side + 1
	var depth_ratio := float(deck_row) / float(maxi(_cannon_rows - 1, 1))
	var fore_fraction := lerpf(-0.26, -0.34, depth_ratio)
	var aft_fraction := lerpf(0.22, 0.30, depth_ratio)
	match hull_class:
		"Sloop":
			fore_fraction = -0.34
			aft_fraction = 0.27
		"Brig":
			fore_fraction = -0.37
			aft_fraction = 0.31
		"Frigate":
			# The lower battery runs through the long waist while the lighter
			# weather-deck guns leave room for the forecastle and quarterdeck.
			fore_fraction = -0.305 if deck_row == 0 else -0.405
			aft_fraction = 0.235 if deck_row == 0 else 0.335
		"Ship of the Line":
			fore_fraction = lerpf(-0.31, -0.42, depth_ratio)
			aft_fraction = lerpf(0.27, 0.37, depth_ratio)
		"Man o' War":
			# Four equal batteries create strong vertical gun columns. A tiny
			# alternate offset keeps them from looking mechanically stamped.
			count = maxi(base_cannons_per_side, 4)
			fore_fraction = -0.405 + (0.010 if deck_row % 2 == 1 else 0.0)
			aft_fraction = 0.355 + (0.010 if deck_row % 2 == 1 else 0.0)
	if _cannon_rows == 1:
		fore_fraction = -0.31
		aft_fraction = 0.28
	var start_z := _hull_length * fore_fraction
	var end_z := _hull_length * aft_fraction
	if count == 1:
		positions.append((start_z + end_z) * 0.5)
		return positions
	for i in range(count):
		positions.append(lerpf(start_z, end_z, float(i) / float(count - 1)))
	return positions


func get_cannon_layout() -> Array[float]:
	return _get_full_cannon_positions()


func get_broadside_fx_geometry(side: int) -> Dictionary:
	var visual_muzzle_x := _get_hull_side_surface_x(_deck_y - 0.28, 0.0) + 0.24
	return {
		"muzzle_x": visual_muzzle_x * float(side),
		"muzzle_y": _deck_y - 0.28,
		"cannon_positions": _get_full_cannon_positions(),
		"hull_length": _hull_length,
		"hull_width": _hull_width,
	}


func get_broadside_fx_transform() -> Transform3D:
	return _visual_root.global_transform if is_instance_valid(_visual_root) else global_transform


func _get_clamped_broadside_direction(side: int, aim_direction: Vector3) -> Vector3:
	var side_basis := global_transform.basis.x.normalized() * float(side)
	aim_direction.y = 0.0
	if aim_direction.length_squared() < 0.01:
		return side_basis

	var target := aim_direction.normalized()
	var signed_angle := atan2(side_basis.cross(target).y, side_basis.dot(target))
	var max_angle := deg_to_rad(broadside_arc_degrees)
	return side_basis.rotated(Vector3.UP, clampf(signed_angle, -max_angle, max_angle)).normalized()


func _get_aimed_cannon_direction(muzzle_position: Vector3, aim_point: Vector3, fallback_direction: Vector3, side: int, use_aim_point: bool) -> Vector3:
	return _get_aimed_cannon_velocity(muzzle_position, aim_point, fallback_direction, side, use_aim_point).normalized()


func _get_aimed_cannon_velocity(muzzle_position: Vector3, aim_point: Vector3, fallback_direction: Vector3, side: int, use_aim_point: bool) -> Vector3:
	if not use_aim_point:
		return fallback_direction.normalized() * cannon_shot_speed

	var to_point := aim_point - muzzle_position
	var horizontal := Vector3(to_point.x, 0.0, to_point.z)
	if horizontal.length_squared() < 0.01:
		return fallback_direction.normalized() * cannon_shot_speed

	var clamped_horizontal := _get_clamped_broadside_direction(side, horizontal)
	var horizontal_distance := clampf(horizontal.length(), 6.0, 155.0)
	var clamped_target := muzzle_position + clamped_horizontal * horizontal_distance
	clamped_target.y = aim_point.y
	return _get_ballistic_direction(muzzle_position, clamped_target, cannon_shot_speed) * cannon_shot_speed


func _get_ballistic_direction(origin: Vector3, target_point: Vector3, shot_speed: float) -> Vector3:
	var displacement := target_point - origin
	var horizontal := Vector3(displacement.x, 0.0, displacement.z)
	var horizontal_distance := horizontal.length()
	if horizontal_distance < 0.01:
		return displacement.normalized()

	var speed_sq := shot_speed * shot_speed
	var y := displacement.y
	var discriminant := speed_sq * speed_sq - cannon_gravity * (cannon_gravity * horizontal_distance * horizontal_distance + 2.0 * y * speed_sq)
	if discriminant >= 0.0:
		var tan_theta := (speed_sq - sqrt(discriminant)) / (cannon_gravity * horizontal_distance)
		var cos_theta := 1.0 / sqrt(1.0 + tan_theta * tan_theta)
		var sin_theta := tan_theta * cos_theta
		return (horizontal.normalized() * cos_theta + Vector3.UP * sin_theta).normalized()

	return (displacement.normalized() + Vector3.UP * 0.14).normalized()


func take_hit(amount: float, source: Node = null, hit_position := Vector3.ZERO, incoming_direction := Vector3.ZERO) -> Dictionary:
	return take_projectile_hit(amount, source, hit_position, incoming_direction, SHOT_ROUND, {})


func take_projectile_hit(amount: float, source: Node = null, hit_position := Vector3.ZERO, incoming_direction := Vector3.ZERO, shot_mode := SHOT_ROUND, shot_profile := {}) -> Dictionary:
	if is_sunk:
		return {}

	_register_received_salvo(shot_profile)
	var report := _build_damage_report(amount, hit_position, incoming_direction, shot_mode, shot_profile)
	var pre_brace_damage := float(report.get("health_damage", 0.0)) + float(report.get("sail_damage", 0.0)) + float(report.get("rudder_damage", 0.0)) + float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	_apply_brace_to_report(report)
	var post_brace_damage := float(report.get("health_damage", 0.0)) + float(report.get("sail_damage", 0.0)) + float(report.get("rudder_damage", 0.0)) + float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	report["brace_absorbed"] = maxf(pre_brace_damage - post_brace_damage, 0.0)
	report["source"] = source
	_apply_damage_report(report)
	_spawn_hit_feedback_fx(report)
	hit_reported.emit(self, report)
	return report


func _register_received_salvo(shot_profile: Dictionary) -> void:
	var salvo_id := String(shot_profile.get("salvo_id", ""))
	if salvo_id.is_empty():
		_untracked_hit_serial += 1
		salvo_id = "impact:%d" % _untracked_hit_serial
	if _received_salvo_ids.has(salvo_id):
		return
	if _received_salvo_ids.size() > 256:
		_received_salvo_ids.clear()
		_received_salvo_health_damage.clear()
	_received_salvo_ids[salvo_id] = true
	_received_salvo_health_damage[salvo_id] = 0.0
	_received_salvo_count += 1


func can_surrender_from_pressure() -> bool:
	var minimum_salvos := 1
	var minimum_time := 0.0
	match hull_class:
		"Brig":
			minimum_salvos = 2
		"Frigate":
			minimum_salvos = 3
			minimum_time = 7.0
		"Ship of the Line":
			minimum_salvos = 5
			minimum_time = 14.0
		"Man o' War":
			minimum_salvos = 7
			minimum_time = 20.0
	return _received_salvo_count >= minimum_salvos and _combat_age >= minimum_time


func get_received_salvo_count() -> int:
	return _received_salvo_count


func _spawn_hit_feedback_fx(report: Dictionary) -> void:
	var hit_position: Vector3 = report.get("hit_position", global_position)
	var incoming_direction: Vector3 = report.get("incoming_direction", Vector3.ZERO)
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	if String(report.get("shot_mode", SHOT_ROUND)) == SHOT_GRAPE:
		CombatFx.spawn_grape_impact(scene, hit_position, incoming_direction)
		return
	match String(report.get("zone", "hull")):
		"sails":
			CombatFx.spawn_sail_rip(scene, hit_position, incoming_direction)
		"cannons":
			CombatFx.spawn_cannon_deck_hit(scene, hit_position, incoming_direction)
		"deck":
			CombatFx.spawn_deck_hit(scene, hit_position, incoming_direction)
		"hull":
			if bool(report.get("powder_explosion", false)):
				CombatFx.spawn_powder_explosion(scene, hit_position, incoming_direction)
			if float(report.get("health_damage", 0.0)) > 0.1:
				CombatFx.spawn_hull_hit(scene, hit_position, incoming_direction)
			if bool(report.get("waterline", false)):
				CombatFx.spawn_water_splash(scene, hit_position)


func take_damage(amount: float, _source: Node = null) -> void:
	if is_sunk:
		return

	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	_update_damage_smoke()
	_resolve_incapacitation_or_sink()


func register_near_miss(position: Vector3, source: Node = null) -> void:
	if is_sunk:
		return
	near_missed.emit(self, position, source)


func apply_ram_impact(target: Node, impact_speed: float) -> Dictionary:
	if is_sunk or _ram_cooldown > 0.0 or impact_speed < ram_min_speed or target == null or target == self:
		return {"applied": false}
	var target_team = target.get("team_id")
	if target_team != null and int(target_team) == team_id:
		return {"applied": false}

	var target_node := target as Node3D
	var hit_position := global_position + (-global_transform.basis.z.normalized() * 2.2)
	var impact_direction := -global_transform.basis.z.normalized()
	if target_node != null:
		var to_target := target_node.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			impact_direction = to_target.normalized()
			hit_position = target_node.global_position - impact_direction * 1.45 + Vector3.UP * 0.55

	var damage := clampf((impact_speed - ram_min_speed) * ram_damage_scale + 5.0, 5.0, 34.0)
	var target_report := {}
	if target.has_method("take_projectile_hit"):
		target_report = target.take_projectile_hit(damage, self, hit_position, impact_direction, SHOT_ROUND, {
			"hull_scale": 1.22,
			"sail_scale": 0.20,
			"rudder_scale": 0.62,
			"cannon_scale": 0.34,
			"flooding_scale": 1.35,
		})
	elif target.has_method("take_hit"):
		target_report = target.take_hit(damage, self, hit_position, impact_direction)
	elif target.has_method("take_damage"):
		target.take_damage(damage, self)

	var self_hit := global_position + impact_direction * 1.55 + Vector3.UP * 0.48
	var self_report := take_projectile_hit(damage * ram_self_damage_ratio, target, self_hit, -impact_direction, SHOT_ROUND, {
		"hull_scale": 0.92,
		"sail_scale": 0.08,
		"rudder_scale": 0.38,
		"cannon_scale": 0.20,
		"flooding_scale": 0.82,
	})
	_play_audio_event("ram", false, -2.0)
	speed = maxf(speed - damage * 0.18, 0.0)
	_ram_cooldown = ram_cooldown_duration
	return {
		"applied": true,
		"damage": damage,
		"target_report": target_report,
		"self_report": self_report,
	}


func _resolve_ram_collisions() -> void:
	if _ram_cooldown > 0.0:
		return

	for collider in get_colliding_bodies():
		if collider == null or collider == self:
			continue
		var impact_speed := velocity.length()
		if collider is Node and collider.get("velocity") is Vector3:
			impact_speed = maxf(impact_speed, (velocity - collider.get("velocity")).length())
		var report := apply_ram_impact(collider, impact_speed)
		if bool(report.get("applied", false)):
			return


func _resolve_island_grounding() -> void:
	if not is_inside_tree():
		return
	var hull_clearance := maxf(_hull_width * 0.46, _hull_length * 0.15)
	for candidate in get_tree().get_nodes_in_group("island_obstacle"):
		var island := candidate as Node3D
		if not is_instance_valid(island):
			continue
		var island_radius := float(island.get_meta("collision_radius", 0.0))
		if island_radius <= 0.0:
			continue
		var separation := global_position - island.global_position
		separation.y = 0.0
		var distance := separation.length()
		var safe_distance := island_radius + hull_clearance
		if distance >= safe_distance:
			continue
		var outward := separation / distance if distance > 0.01 else global_transform.basis.z.normalized()
		outward.y = 0.0
		outward = outward.normalized()
		var penetration := safe_distance - distance
		global_position += outward * (penetration + 0.08)

		var corrected_velocity := linear_velocity
		var inward_speed := corrected_velocity.dot(outward)
		if inward_speed < 0.0:
			corrected_velocity -= outward * inward_speed
		var escape_speed := lerpf(1.8, 3.4, clampf(penetration / maxf(hull_clearance, 0.1), 0.0, 1.0))
		var outward_speed := corrected_velocity.dot(outward)
		if outward_speed < escape_speed:
			corrected_velocity += outward * (escape_speed - outward_speed)
		linear_velocity = corrected_velocity
		angular_velocity.y *= 0.92


func _build_damage_report(amount: float, hit_position: Vector3, incoming_direction: Vector3, shot_mode := SHOT_ROUND, shot_profile := {}) -> Dictionary:
	var local_hit := to_local(hit_position) if hit_position != Vector3.ZERO else Vector3.ZERO
	var zone := "hull"
	var health_damage := amount
	var sail_damage := 0.0
	var rudder_damage := 0.0
	var port_cannon_damage := 0.0
	var starboard_cannon_damage := 0.0
	var flooding_gain := amount * 0.004
	var fire_gain := 0.0
	var crew_shock_gain := 0.0
	var waterline_hit := false

	if local_hit.y > _deck_y + 0.55:
		zone = "sails"
		health_damage *= 0.42
		sail_damage = amount * 1.08
		flooding_gain = 0.0
	elif local_hit.z > _hull_length * 0.28:
		zone = "rudder"
		health_damage *= 0.72
		rudder_damage = amount * 0.72
		flooding_gain *= 0.8
	elif local_hit.y > _deck_y + 0.02:
		zone = "deck"
		health_damage *= 0.62
		crew_shock_gain = amount * 0.026
		fire_gain = amount * 0.007
		if local_hit.x < -_hull_width * 0.18:
			port_cannon_damage = amount * 0.34
		elif local_hit.x > _hull_width * 0.18:
			starboard_cannon_damage = amount * 0.34
		flooding_gain = 0.0
	elif absf(local_hit.x) > _hull_width * 0.37 and local_hit.y > _deck_y - _hull_depth * 0.40:
		zone = "cannons"
		health_damage *= 0.78
		fire_gain = amount * 0.006
		crew_shock_gain = amount * 0.010
		if local_hit.x < 0.0:
			port_cannon_damage = amount * 0.88
		else:
			starboard_cannon_damage = amount * 0.88
		flooding_gain *= 0.65
	else:
		zone = "hull"
		health_damage *= 1.06
		flooding_gain = amount * 0.012
		fire_gain = amount * 0.003
		waterline_hit = local_hit.y < _deck_y - _hull_depth * 0.42
		if waterline_hit:
			health_damage *= 1.08
			flooding_gain *= 1.75

	var critical := bool(shot_profile.get("salvo_critical", false))
	if not shot_profile.has("salvo_critical"):
		critical = randf() < clampf(amount / 110.0, 0.03, 0.16)
	if critical:
		health_damage *= 1.18
		flooding_gain *= 1.8
		fire_gain += amount * 0.010

	var sail_scale := float(shot_profile.get("sail_scale", 1.0))
	var rudder_scale := float(shot_profile.get("rudder_scale", 1.0))
	var hull_scale := float(shot_profile.get("hull_scale", 1.0))
	if shot_mode == SHOT_ROUND:
		hull_scale *= float(shot_profile.get("range_penetration", 1.0))
	var cannon_scale := float(shot_profile.get("cannon_scale", 1.0))
	var flooding_scale := float(shot_profile.get("flooding_scale", 1.0))
	var crew_shock_scale := float(shot_profile.get("crew_shock_scale", 1.0))
	health_damage *= hull_scale
	sail_damage *= sail_scale
	rudder_damage *= rudder_scale
	port_cannon_damage *= cannon_scale
	starboard_cannon_damage *= cannon_scale
	flooding_gain *= flooding_scale
	fire_gain *= hull_scale
	crew_shock_gain *= crew_shock_scale
	health_damage *= _get_class_hull_damage_scale()
	if shot_mode == SHOT_GRAPE:
		crew_shock_gain += amount * 0.012

	var angle_profile := _get_hit_angle_profile(incoming_direction)
	var angle_scale := float(angle_profile.get("damage_scale", 1.0))
	health_damage *= angle_scale
	sail_damage *= angle_scale
	rudder_damage *= angle_scale
	port_cannon_damage *= angle_scale
	starboard_cannon_damage *= angle_scale
	flooding_gain *= float(angle_profile.get("flooding_scale", angle_scale))
	fire_gain *= angle_scale
	crew_shock_gain *= angle_scale
	sail_damage *= SAIL_SYSTEM_DAMAGE_SCALE
	port_cannon_damage *= CANNON_SYSTEM_DAMAGE_SCALE
	starboard_cannon_damage *= CANNON_SYSTEM_DAMAGE_SCALE

	var powder_explosion := false
	var powder_explosion_damage := 0.0
	flooding_gain = 0.0
	fire_gain = 0.0

	var morale_damage := 0.0
	if String(angle_profile.get("name", "solid")) == "raking":
		morale_damage += 8.0
	if critical:
		morale_damage += 4.5
	if powder_explosion:
		morale_damage += 14.0
	morale_damage += (port_cannon_damage + starboard_cannon_damage) * 0.10

	return {
		"zone": zone,
		"hit_angle": angle_profile.get("name", "solid"),
		"hit_angle_scale": angle_scale,
		"shot_mode": shot_mode,
		"amount": amount,
		"health_damage": health_damage,
		"sail_damage": sail_damage,
		"rudder_damage": rudder_damage,
		"port_cannon_damage": port_cannon_damage,
		"starboard_cannon_damage": starboard_cannon_damage,
		"flooding_gain": flooding_gain,
		"fire_gain": fire_gain,
		"crew_shock_gain": crew_shock_gain,
		"morale_damage": morale_damage,
		"critical": critical,
		"waterline": waterline_hit,
		"powder_explosion": powder_explosion,
		"powder_explosion_damage": powder_explosion_damage,
		"hit_position": hit_position,
		"incoming_direction": incoming_direction,
		"salvo_id": String(shot_profile.get("salvo_id", "")),
		"salvo_shots": int(shot_profile.get("salvo_shots", 1)),
		"salvo_focus": float(shot_profile.get("aim_focus", 0.0)),
	}


func _get_class_hull_damage_scale() -> float:
	match hull_class:
		"Sloop":
			return 1.0
		"Frigate":
			return 0.88
		"Ship of the Line":
			return 0.80
		"Man o' War":
			return 0.74
	return 0.96


func _get_round_salvo_health_cap() -> float:
	var ratio := 0.38
	match hull_class:
		"Sloop": ratio = 0.45
		"Frigate": ratio = 0.32
		"Ship of the Line": ratio = 0.24
		"Man o' War": ratio = 0.19
	return max_health * ratio


func get_projectile_hit_radius(shot_mode := SHOT_ROUND) -> float:
	var radius := 1.15
	match hull_class:
		"Sloop":
			radius = 1.02
		"Frigate":
			radius = 1.48
		"Ship of the Line":
			radius = 1.86
		"Man o' War":
			radius = 2.28
		_:
			radius = 1.28
	if shot_mode == SHOT_CHAIN:
		radius *= 1.08
	elif shot_mode == SHOT_GRAPE:
		radius *= 0.82
	return radius


func is_projectile_point_inside(world_point: Vector3, shot_mode := SHOT_ROUND) -> bool:
	var point := to_local(world_point)
	var in_hull_length := absf(point.z) <= _hull_length * 0.55
	var in_hull_width := absf(point.x) <= _hull_width * 0.58
	var in_hull_height := point.y >= _deck_y - _hull_depth * 1.08 and point.y <= _deck_y + 0.62
	if in_hull_length and in_hull_width and in_hull_height:
		return true
	if shot_mode == SHOT_GRAPE and point.y > _deck_y + 1.8:
		return false
	for mast in _mast_nodes:
		if not is_instance_valid(mast):
			continue
		var height := float(mast.get_meta("rig_height", 5.0))
		var width := float(mast.get_meta("sail_width", 2.5))
		var relative_y := point.y - mast.position.y
		if absf(point.z - mast.position.z) <= 0.62 and absf(point.x - mast.position.x) <= width * 0.62 and relative_y >= height * 0.42 and relative_y <= height * 1.02:
			return true
	return false


func _get_hit_angle_profile(incoming_direction: Vector3) -> Dictionary:
	if incoming_direction.length_squared() < 0.01:
		return {"name": "solid", "damage_scale": 1.0, "flooding_scale": 1.0}

	var local_direction := global_transform.basis.inverse() * incoming_direction.normalized()
	local_direction.y = 0.0
	if local_direction.length_squared() < 0.01:
		return {"name": "solid", "damage_scale": 1.0, "flooding_scale": 1.0}

	local_direction = local_direction.normalized()
	var along_length := absf(local_direction.z)
	var along_broadside := absf(local_direction.x)
	if along_length > 0.80:
		return {"name": "raking", "damage_scale": 1.48, "flooding_scale": 1.35}
	if along_broadside > 0.72:
		return {"name": "solid", "damage_scale": 1.0, "flooding_scale": 1.0}
	return {"name": "glancing", "damage_scale": 0.78, "flooding_scale": 0.65}


func _apply_brace_to_report(report: Dictionary) -> void:
	report["braced"] = is_bracing
	report["perfect_brace"] = is_perfect_bracing()
	if not is_bracing:
		return

	var factor := get_brace_factor()
	report["health_damage"] = float(report.get("health_damage", 0.0)) * factor
	report["sail_damage"] = float(report.get("sail_damage", 0.0)) * factor
	report["rudder_damage"] = float(report.get("rudder_damage", 0.0)) * factor
	report["port_cannon_damage"] = float(report.get("port_cannon_damage", 0.0)) * factor
	report["starboard_cannon_damage"] = float(report.get("starboard_cannon_damage", 0.0)) * factor
	report["flooding_gain"] = float(report.get("flooding_gain", 0.0)) * factor
	report["crew_shock_gain"] = float(report.get("crew_shock_gain", 0.0)) * factor


func _apply_damage_report(report: Dictionary) -> void:
	report["flooding_gain"] = 0.0
	report["fire_gain"] = 0.0
	report["powder_explosion"] = false
	var previous_health := health
	var previous_sails := sail_integrity
	var previous_rudder := rudder_integrity
	var previous_port_cannons := port_cannon_integrity
	var previous_starboard_cannons := starboard_cannon_integrity
	var requested_health_damage := float(report.get("health_damage", 0.0))
	var salvo_id := String(report.get("salvo_id", ""))
	if String(report.get("shot_mode", SHOT_ROUND)) == SHOT_ROUND and not salvo_id.is_empty():
		var already_applied := float(_received_salvo_health_damage.get(salvo_id, 0.0))
		requested_health_damage = minf(requested_health_damage, maxf(_get_round_salvo_health_cap() - already_applied, 0.0))
	health = clampf(health - requested_health_damage, 0.0, max_health)
	sail_integrity = clampf(sail_integrity - float(report.get("sail_damage", 0.0)), 0.0, max_sail_integrity)
	rudder_integrity = clampf(rudder_integrity - float(report.get("rudder_damage", 0.0)), 0.0, max_rudder_integrity)
	port_cannon_integrity = clampf(port_cannon_integrity - float(report.get("port_cannon_damage", 0.0)), 0.0, max_cannon_integrity)
	starboard_cannon_integrity = clampf(starboard_cannon_integrity - float(report.get("starboard_cannon_damage", 0.0)), 0.0, max_cannon_integrity)
	report["health_damage"] = previous_health - health
	if String(report.get("shot_mode", SHOT_ROUND)) == SHOT_ROUND and not salvo_id.is_empty():
		_received_salvo_health_damage[salvo_id] = float(_received_salvo_health_damage.get(salvo_id, 0.0)) + float(report["health_damage"])
	report["sail_damage"] = previous_sails - sail_integrity
	report["rudder_damage"] = previous_rudder - rudder_integrity
	report["port_cannon_damage"] = previous_port_cannons - port_cannon_integrity
	report["starboard_cannon_damage"] = previous_starboard_cannons - starboard_cannon_integrity
	report["morale_damage"] = 0.0
	flooding = 0.0
	fire_intensity = 0.0
	_flooding_side = 0.0
	crew_shock = clampf(crew_shock + float(report.get("crew_shock_gain", 0.0)), 0.0, 1.0)
	_register_localized_structural_damage(report)
	_register_visual_crew_damage(report)
	_dispatch_crew_to_hit(report)
	_add_persistent_hit_damage(report)
	if bool(report.get("powder_explosion", false)):
		_powder_explosion_cooldown = powder_explosion_cooldown_duration
	if float(report.get("sail_damage", 0.0)) > 0.01:
		_sail_hit_flutter = maxf(_sail_hit_flutter, clampf(float(report.get("sail_damage", 0.0)) / 55.0, 0.22, 1.0))
	_apply_hit_recoil(report)
	health_changed.emit(health, max_health)
	_update_damage_smoke()
	_update_sail_damage_visual()
	_update_regional_damage_visuals()
	_update_cannon_ready_visuals()
	_update_flooding_visuals()
	_resolve_incapacitation_or_sink()


func _register_localized_structural_damage(report: Dictionary) -> void:
	if _visual_root == null:
		return
	var hit_position: Vector3 = report.get("hit_position", Vector3.ZERO)
	var local_hit := _visual_root.to_local(hit_position) if hit_position != Vector3.ZERO else Vector3.ZERO
	var zone := String(report.get("zone", "hull"))
	var incoming: Vector3 = report.get("incoming_direction", Vector3.ZERO)
	var side := -1 if local_hit.x < 0.0 else 1
	var side_cannon_damage := float(report.get("port_cannon_damage", 0.0)) if side < 0 else float(report.get("starboard_cannon_damage", 0.0))
	if side_cannon_damage > 0.01:
		_damage_nearest_cannon(side, local_hit, side_cannon_damage, report)

	var structural_damage := float(report.get("health_damage", 0.0)) + side_cannon_damage * 0.8
	if zone in ["hull", "deck", "cannons"] and structural_damage > 0.5:
		_damage_nearest_rail(side, local_hit.z, structural_damage, incoming)
		if structural_damage >= 7.5 and _hull_fragment_cooldown <= 0.0 and _count_detached_hull_fragments() < 3:
			_spawn_detached_hull_fragment(side, local_hit, incoming, structural_damage)
			_hull_fragment_cooldown = 0.45
	if zone == "sails" and float(report.get("sail_damage", 0.0)) > 0.01:
		_damage_nearest_mast(local_hit.z, float(report.get("sail_damage", 0.0)), incoming)


func _damage_nearest_cannon(side: int, local_hit: Vector3, damage: float, report: Dictionary) -> void:
	var placements := _port_gunport_visuals if side < 0 else _starboard_gunport_visuals
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for placement in placements:
		if bool(placement.get("disabled", false)):
			continue
		var distance := Vector2(local_hit.z - float(placement.get("z", 0.0)), local_hit.y - float(placement.get("y", 0.0))).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = placement
	if nearest.is_empty():
		return
	var local_damage := float(nearest.get("local_damage", 0.0)) + damage * 4.2
	nearest["local_damage"] = local_damage
	var threshold := 13.0
	match hull_class:
		"Sloop": threshold = 11.0
		"Frigate": threshold = 15.0
		"Ship of the Line": threshold = 18.0
		"Man o' War": threshold = 21.0
	if local_damage < threshold:
		return
	nearest["disabled"] = true
	report["disabled_cannons"] = int(report.get("disabled_cannons", 0)) + 1
	report["disabled_cannon_side"] = side
	report["disabled_cannon_z"] = float(nearest.get("z", 0.0))
	_animate_visual_crew_hit({
		"hit_position": _visual_root.to_global(Vector3(float(side) * _hull_width * 0.35, _deck_y + 0.10, float(nearest.get("z", 0.0)))),
		"incoming_direction": report.get("incoming_direction", Vector3.ZERO),
	}, false)


func _damage_nearest_rail(side: int, local_z: float, damage: float, incoming: Vector3) -> void:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for segment in _breakable_rail_segments:
		if int(segment.get("side", 0)) != side or bool(segment.get("broken", false)):
			continue
		var distance := absf(local_z - float(segment.get("z", 0.0)))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = segment
	if nearest.is_empty():
		return
	nearest["damage"] = float(nearest.get("damage", 0.0)) + damage
	var threshold := 14.0
	match hull_class:
		"Frigate": threshold = 19.0
		"Ship of the Line": threshold = 25.0
		"Man o' War": threshold = 31.0
	if float(nearest.get("damage", 0.0)) >= threshold:
		nearest["broken"] = true
		var rail := nearest.get("node") as Node3D
		if _rail_fragment_cooldown <= 0.0 and _count_detached_rail_fragments() < 2:
			_detach_structural_part(rail, incoming, 0.72)
			_rail_fragment_cooldown = 0.38
		elif is_instance_valid(rail):
			rail.visible = false


func _damage_nearest_mast(local_z: float, damage: float, incoming: Vector3) -> void:
	if _mast_nodes.is_empty():
		return
	while _mast_local_damage.size() < _mast_nodes.size():
		_mast_local_damage.append(0.0)
	var nearest_index := -1
	var nearest_distance := INF
	for index in range(_mast_nodes.size()):
		var mast := _mast_nodes[index]
		if not is_instance_valid(mast) or bool(mast.get_meta("detached", false)):
			continue
		var distance := absf(local_z - mast.position.z)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0:
		return
	_mast_local_damage[nearest_index] += damage * 2.2
	var threshold := 48.0 if hull_class in ["Sloop", "Brig"] else (62.0 if hull_class == "Frigate" else (82.0 if hull_class == "Ship of the Line" else 96.0))
	if _mast_local_damage[nearest_index] >= threshold:
		var mast := _mast_nodes[nearest_index]
		mast.set_meta("detached", true)
		_detach_structural_part(mast, incoming, 0.48)


func _spawn_detached_hull_fragment(side: int, local_hit: Vector3, incoming: Vector3, damage: float) -> void:
	var fragment := Node3D.new()
	fragment.name = "DetachedHullFragment"
	fragment.set_meta("damage_fragment_kind", "plank")
	_visual_root.add_child(fragment)
	fragment.position = Vector3(
		float(side) * _hull_width * 0.47,
		clampf(local_hit.y, _deck_y - _hull_depth * 0.52, _deck_y + 0.10),
		clampf(local_hit.z, -_hull_length * 0.40, _hull_length * 0.40)
	)
	var plank_material := _make_material(Color(0.27, 0.12, 0.055), 0.96)
	var plank_count := 1 if damage < 14.0 else 2
	for index in range(plank_count):
		var plank_length := randf_range(0.58, 0.94) if index == 0 else randf_range(0.30, 0.52)
		var plank := _add_box(
			fragment,
			"SplinteredPlank%d" % index,
			Vector3(0.055 if index == 0 else 0.035, 0.12 if index == 0 else 0.055, plank_length),
			Vector3(0.0, float(index) * 0.09, randf_range(-0.12, 0.12)),
			plank_material
		)
		plank.rotation = Vector3(randf_range(-0.05, 0.05), randf_range(-0.08, 0.08), randf_range(-0.12, 0.12))
	_detach_structural_part(fragment, incoming, clampf(damage / 18.0, 0.38, 0.88))


func _count_detached_hull_fragments() -> int:
	var count := 0
	for data in _detached_damage_parts:
		var node := data.get("node") as Node3D
		if is_instance_valid(node) and node.name == "DetachedHullFragment":
			count += 1
	return count


func _count_detached_rail_fragments() -> int:
	var count := 0
	for data in _detached_damage_parts:
		var node := data.get("node") as Node3D
		if is_instance_valid(node) and "RailSegment" in node.name:
			count += 1
	return count


func _detach_structural_part(part: Node3D, incoming: Vector3, force_scale: float) -> void:
	if not is_instance_valid(part) or bool(part.get_meta("damage_detached", false)):
		return
	var scene := get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
	if scene == null:
		return
	part.set_meta("damage_detached", true)
	part.reparent(scene, true)
	var is_mast := part.name == "RigMast"
	var outward := part.global_position - global_position
	outward.y = 0.0
	var rebound := -incoming
	rebound.y = 0.0
	if rebound.length_squared() > 0.01:
		rebound = rebound.normalized()
	if outward.length_squared() > 0.01:
		outward = outward.normalized()
	else:
		outward = rebound if rebound.length_squared() > 0.01 else global_transform.basis.x.normalized()
	var launch_direction := (outward * 0.78 + rebound * 0.22).normalized()
	var inherited_velocity := linear_velocity * (0.84 if is_mast else 0.68)
	var launch_speed := lerpf(0.65, 1.55, clampf(force_scale, 0.0, 1.0))
	var lift := lerpf(0.22, 0.62, clampf(force_scale, 0.0, 1.0))
	var tumble_axis := Vector3(randf_range(-0.75, 0.75), randf_range(-0.18, 0.18), randf_range(-0.75, 0.75))
	if is_mast:
		tumble_axis = Vector3(outward.z, 0.0, -outward.x) * 0.42
	_detached_damage_parts.append({
		"node": part,
		"velocity": inherited_velocity + launch_direction * launch_speed + Vector3.UP * lift,
		"spin": tumble_axis,
		"life": 0.0,
		"water_age": 0.0,
		"water_contact": false,
		"max_life": 9.0 if is_mast else 6.0,
	})


func _get_flooding_side_from_report(report: Dictionary) -> float:
	var hit_position: Vector3 = report.get("hit_position", Vector3.ZERO)
	if hit_position != Vector3.ZERO:
		var local_hit := to_local(hit_position)
		if absf(local_hit.x) > 0.12:
			return signf(local_hit.x)
	var incoming: Vector3 = report.get("incoming_direction", Vector3.ZERO)
	if incoming.length_squared() > 0.01:
		var local_incoming := global_transform.basis.inverse() * incoming.normalized()
		if absf(local_incoming.x) > 0.05:
			return signf(local_incoming.x)
	return 1.0


func _apply_hit_recoil(report: Dictionary) -> void:
	var total_damage := float(report.get("health_damage", 0.0)) + float(report.get("sail_damage", 0.0)) + float(report.get("rudder_damage", 0.0)) + float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	if total_damage <= 0.01:
		return
	var incoming: Vector3 = report.get("incoming_direction", Vector3.ZERO)
	var local_incoming := Vector3.ZERO
	if incoming.length_squared() > 0.01:
		local_incoming = global_transform.basis.inverse() * incoming.normalized()
	var side := 1.0
	if absf(local_incoming.x) > 0.05:
		side = signf(local_incoming.x)
	var shock := clampf(total_damage / 85.0, 0.08, 0.72)
	var source: Node = report.get("source", null)
	var close_broadside_scale := 1.0
	if source is Node3D:
		var source_distance := global_position.distance_to((source as Node3D).global_position)
		close_broadside_scale = lerpf(1.38, 1.0, clampf(inverse_lerp(12.0, 48.0, source_distance), 0.0, 1.0))
	shock = minf(shock * close_broadside_scale, 0.92)
	if bool(report.get("braced", false)):
		shock *= 0.58
	_impact_recoil = maxf(_impact_recoil, shock)
	_impact_recoil_side = side
	speed = maxf(speed - shock * 1.35, 0.0)
	_current_rudder = clampf(_current_rudder + side * shock * 0.18, -1.0, 1.0)
	var horizontal_incoming := Vector3(incoming.x, 0.0, incoming.z)
	var impact_push := Vector3.ZERO
	if horizontal_incoming.length_squared() > 0.01:
		var push_strength := shock * lerpf(2.0, 4.15, clampf(total_damage / 70.0, 0.0, 1.0))
		impact_push = horizontal_incoming.normalized() * push_strength
		_impact_push_velocity = (_impact_push_velocity + impact_push).limit_length(5.8)
		apply_central_impulse(impact_push * mass * 0.22)
		apply_torque_impulse(Vector3(0.0, 0.0, -side * shock * mass * _hull_width * 0.045))
	report["impact_push"] = impact_push.length()


func apply_rogue_wave_impact(wave_direction: Vector3, severity: float, protected := false) -> Dictionary:
	if is_sunk:
		return {}
	var force := clampf(severity, 0.0, 1.0)
	var horizontal_wave := Vector3(wave_direction.x, 0.0, wave_direction.z).normalized()
	if horizontal_wave.length_squared() < 0.01:
		horizontal_wave = Vector3.FORWARD
	var local_wave := global_transform.basis.inverse() * horizontal_wave
	var roll_side := signf(local_wave.x) if absf(local_wave.x) > 0.08 else (-1.0 if randf() < 0.5 else 1.0)
	_rogue_wave_roll = maxf(_rogue_wave_roll, force * roll_side)
	_rogue_wave_heave = maxf(_rogue_wave_heave, lerpf(0.48, 1.75, force))
	_rogue_wave_pitch = maxf(_rogue_wave_pitch, lerpf(0.10, 0.48, force))
	_impact_push_velocity = (_impact_push_velocity + horizontal_wave * lerpf(1.2, 5.8, force)).limit_length(7.2)
	apply_central_impulse(horizontal_wave * mass * lerpf(0.32, 1.45, force))
	apply_torque_impulse(Vector3(0.0, 0.0, -roll_side * mass * _hull_width * lerpf(0.06, 0.22, force)))
	speed *= lerpf(0.92, 0.44, force)
	if not protected:
		_wave_control_lock = maxf(_wave_control_lock, lerpf(0.55, 1.85, force))
		_current_rudder = clampf(_current_rudder + roll_side * force * 0.38, -1.0, 1.0)

	var hull_damage := 0.0 if protected else max_health * lerpf(0.018, 0.085, force)
	var crew_pressure := 0.08 if protected else lerpf(0.28, 0.82, force)
	health = maxf(health - hull_damage, 0.0)
	flooding = 0.0
	_flooding_side = 0.0
	crew_shock = clampf(crew_shock + crew_pressure, 0.0, 1.0)
	var report := {
		"zone": "deck",
		"shot_mode": "rogue_wave",
		"health_damage": hull_damage,
		"sail_damage": 0.0,
		"rudder_damage": 0.0,
		"port_cannon_damage": 0.0,
		"starboard_cannon_damage": 0.0,
		"crew_shock_gain": crew_pressure,
		"flooding_gain": 0.0,
		"hit_position": global_position + Vector3.UP * (_deck_y + 0.45),
		"incoming_direction": horizontal_wave,
		"protected": protected,
		"severity": force,
	}
	if not protected:
		var visible_reactions := 1 if force < 0.72 else 2
		for reaction_index in range(visible_reactions):
			_animate_visual_crew_hit(report, false)
		_recount_visual_crew_losses()
	_play_audio_event("splash", accepts_player_input, -1.0 if protected else 1.5)
	health_changed.emit(health, max_health)
	_update_damage_smoke()
	_update_regional_damage_visuals()
	_update_flooding_visuals()
	_resolve_incapacitation_or_sink()
	return report


func repair(amount: float) -> void:
	if is_sunk:
		return

	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	_update_damage_smoke()


func reset_for_sortie() -> void:
	freeze = true
	sleeping = false
	is_sunk = false
	is_incapacitated = false
	incapacitated_time_remaining = 0.0
	is_surrendered = false
	was_captured = false
	_captured_flag = false
	for mark in _persistent_damage_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_persistent_damage_marks.clear()
	for flag in _flag_nodes:
		if not is_instance_valid(flag):
			continue
		flag.material_override = flag.get_meta("base_material", flag.material_override)
		flag.position = flag.get_meta("base_position", flag.position)
		flag.scale = Vector3.ONE
	collision_layer = 1
	collision_mask = 1
	health = max_health
	sail_integrity = max_sail_integrity
	rudder_integrity = max_rudder_integrity
	port_cannon_integrity = max_cannon_integrity
	starboard_cannon_integrity = max_cannon_integrity
	flooding = 0.0
	fire_intensity = 0.0
	crew_shock = 0.0
	combat_morale = clampf(float(int(get_meta("campaign_morale", 58))), 0.0, max_combat_morale)
	brace_stamina = 1.0
	is_bracing = false
	_perfect_brace_timer = 0.0
	is_repairing = false
	_repair_progress = 0.0
	repair_supplies = max_repair_supplies
	speed = 0.0
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_water_velocity = Vector3.ZERO
	_yaw_velocity = 0.0
	_turn_heel = 0.0
	_lateral_slip = 0.0
	_port_reload = 0.0
	_starboard_reload = 0.0
	_ram_cooldown = 0.0
	_powder_explosion_cooldown = 0.0
	_mortar_reload = 0.0
	_combat_age = 0.0
	_received_salvo_count = 0
	_received_salvo_ids.clear()
	_received_salvo_health_damage.clear()
	_untracked_hit_serial = 0
	_wave_time = 0.0
	_aim_focus = 0.0
	_crew_loss_accumulator = 0.0
	_visual_crew_losses = 0
	_permanent_visual_crew_losses = 0
	_boarding_visual_active = false
	_boarding_visual_progress = 0.0
	_crew_broadside_pulse = 0.0
	_boarding_fx_timer = 0.0
	prepare_water_spawn()
	_reset_visual_crew_states()
	if _boarding_bridge:
		_boarding_bridge.visible = false
	_target_speed = 0.0
	_target_rudder = 0.0
	_current_rudder = 0.0
	_combat_turn_grip = 1.0
	_broadside_recoil = 0.0
	_broadside_recoil_side = 0.0
	_impact_recoil = 0.0
	_impact_recoil_side = 0.0
	_impact_push_velocity = Vector3.ZERO
	_rogue_wave_roll = 0.0
	_rogue_wave_heave = 0.0
	_rogue_wave_pitch = 0.0
	_sea_heave = 0.0
	_sea_pitch = 0.0
	_sea_roll = 0.0
	_wave_control_lock = 0.0
	_sail_hit_flutter = 0.0
	_flooding_side = 0.0
	_creak_timer = 0.0
	_fire_audio_latched = false
	_flood_audio_latched = false
	_sink_elapsed = 0.0
	_sink_duration = 6.0
	_sink_start_y = 0.0
	_sink_roll_direction = 1.0
	_sink_fx_stage = 0
	accepts_player_input = true
	navigation_input_only = false
	set_sail_step(1, true)
	global_position.y = 0.0
	_rebuild_ship_geometry()
	if _visual_root:
		_visual_root.position = Vector3.ZERO
		_visual_root.rotation = Vector3.ZERO
	_update_damage_smoke()
	_update_regional_damage_visuals()
	_update_flooding_visuals()
	health_changed.emit(health, max_health)


func get_telemetry() -> Dictionary:
	var port_active_guns := _get_active_cannon_placements(-1).size()
	var starboard_active_guns := _get_active_cannon_placements(1).size()
	var guns_per_side := maxi(_port_gunport_visuals.size(), base_cannons_per_side * _cannon_rows)
	return {
		"name": display_name,
		"hull_class": hull_class,
		"health": health,
		"max_health": max_health,
		"incapacitated": is_incapacitated,
		"sail": sail_setting,
		"sail_state": get_sail_state_label(),
		"speed": speed,
		"target_speed": _target_speed,
		"port_reload": _port_reload,
		"starboard_reload": _starboard_reload,
		"cannon_reload": cannon_reload,
		"shot_mode": current_shot_mode,
		"shot_mode_label": get_shot_mode_label(),
		"base_cannons_per_side": base_cannons_per_side,
		"cannon_decks": _cannon_rows,
		"guns_per_side": guns_per_side,
		"port_active_guns": port_active_guns,
		"starboard_active_guns": starboard_active_guns,
		"aim_focus": _aim_focus,
		"mortar_reload": _mortar_reload,
		"has_mortar": hull_class in ["Ship of the Line", "Man o' War"],
		"mortar_shells": get_mortar_shell_count(),
		"received_salvos": _received_salvo_count,
		"visible_crew": maxi(_crew_nodes.size() - _visual_crew_losses, 0),
		"brace": is_bracing,
		"perfect_brace": is_perfect_bracing(),
		"perfect_brace_timer": _perfect_brace_timer,
		"brace_stamina": brace_stamina,
		"wave_control_lock": _wave_control_lock,
		"heading": _heading_degrees(),
		"wind_efficiency": _get_wind_efficiency(-global_transform.basis.z.normalized()),
		"rudder": _current_rudder,
		"target_rudder": _target_rudder,
		"combat_turn_grip": _combat_turn_grip,
		"position": global_position,
		"sail_integrity": sail_integrity,
		"rudder_integrity": rudder_integrity,
		"port_cannon_integrity": port_cannon_integrity,
		"starboard_cannon_integrity": starboard_cannon_integrity,
		"flooding": flooding,
		"fire": fire_intensity,
		"crew_shock": crew_shock,
		"combat_morale": combat_morale,
		"is_surrendered": is_surrendered,
		"repair_supplies": repair_supplies,
		"campaign_sailors": int(get_meta("campaign_sailors", 42)),
		"campaign_gunners": int(get_meta("campaign_gunners", 18)),
		"campaign_carpenters": int(get_meta("campaign_carpenters", 6)),
		"campaign_morale": int(get_meta("campaign_morale", 58)),
		"campaign_speed_scale": lerpf(0.68, 1.0, clampf(float(int(get_meta("campaign_sailors", 42))) / 42.0, 0.45, 1.0)),
		"campaign_reload_scale": 1.0,
		"campaign_repair_scale": lerpf(0.55, 1.0, clampf(float(int(get_meta("campaign_carpenters", 6))) / 6.0, 0.35, 1.0)),
		"repairing": is_repairing,
		"repair_progress": _repair_progress / emergency_repair_duration if emergency_repair_duration > 0.0 else 0.0,
		"sail_factor": _get_sail_factor(),
		"rudder_factor": _get_rudder_factor(),
		"broadside_recoil": _broadside_recoil,
		"impact_recoil": _impact_recoil,
		"impact_push": _impact_push_velocity.length(),
		"sail_hit_flutter": _sail_hit_flutter,
		"visual_damage": get_visual_damage_state(),
	}


func get_visual_damage_state() -> Dictionary:
	var visible_tears := 0
	for tear in _sail_tear_overlays:
		if is_instance_valid(tear) and tear.visible:
			visible_tears += 1
	var visible_scorch := 0
	for scorch in _hull_scorch_marks:
		if is_instance_valid(scorch) and scorch.visible:
			visible_scorch += 1
	var visible_breaches := 0
	for breach in _waterline_breaches:
		if is_instance_valid(breach) and breach.visible:
			visible_breaches += 1
	var collapsed_masts := 0
	for mast in _mast_nodes:
		if is_instance_valid(mast) and (bool(mast.get_meta("detached", false)) or absf(mast.rotation.z) > 0.34):
			collapsed_masts += 1
	var sail_slump := 0.0
	for sail in _sail_nodes:
		if is_instance_valid(sail):
			sail_slump = maxf(sail_slump, 1.0 - sail.scale.y)
	var leak_emitters := 0
	if _port_leak_particles != null and _port_leak_particles.emitting:
		leak_emitters += 1
	if _starboard_leak_particles != null and _starboard_leak_particles.emitting:
		leak_emitters += 1
	var fire_emitters := 0
	if _fire_particles != null and _fire_particles.emitting:
		fire_emitters += 1
	if _fire_ember_particles != null and _fire_ember_particles.emitting:
		fire_emitters += 1
	var damaged_port_cannons := 0
	var port_cannon_tilt := 0.0
	for placement in _port_gunport_visuals:
		var cannon := placement.get("barrel") as MeshInstance3D
		if bool(placement.get("disabled", false)):
			damaged_port_cannons += 1
			if is_instance_valid(cannon):
				port_cannon_tilt = maxf(port_cannon_tilt, absf(cannon.rotation.z))
	var damaged_starboard_cannons := 0
	var starboard_cannon_tilt := 0.0
	for placement in _starboard_gunport_visuals:
		var cannon := placement.get("barrel") as MeshInstance3D
		if bool(placement.get("disabled", false)):
			damaged_starboard_cannons += 1
			if is_instance_valid(cannon):
				starboard_cannon_tilt = maxf(starboard_cannon_tilt, absf(cannon.rotation.z))
	var broken_rails := 0
	for segment in _breakable_rail_segments:
		if bool(segment.get("broken", false)):
			broken_rails += 1
	var port_ready_markers := _count_cannon_markers(_port_cannon_ready_markers, _cannon_ready_material)
	var starboard_ready_markers := _count_cannon_markers(_starboard_cannon_ready_markers, _cannon_ready_material)
	var port_disabled_markers := _count_cannon_markers(_port_cannon_ready_markers, _cannon_disabled_material)
	var starboard_disabled_markers := _count_cannon_markers(_starboard_cannon_ready_markers, _cannon_disabled_material)
	return {
		"sail_tears": visible_tears,
		"sail_slump": sail_slump,
		"flooding_side": _flooding_side,
		"leak_emitters": leak_emitters,
		"fire_emitters": fire_emitters,
		"hull_scorch": visible_scorch,
		"waterline_breaches": visible_breaches,
		"collapsed_masts": collapsed_masts,
		"broken_rails": broken_rails,
		"detached_parts": _detached_damage_parts.size(),
		"damaged_port_cannons": damaged_port_cannons,
		"damaged_starboard_cannons": damaged_starboard_cannons,
		"port_cannon_tilt": port_cannon_tilt,
		"starboard_cannon_tilt": starboard_cannon_tilt,
		"port_ready_markers": port_ready_markers,
		"starboard_ready_markers": starboard_ready_markers,
		"port_disabled_markers": port_disabled_markers,
		"starboard_disabled_markers": starboard_disabled_markers,
	}


func _count_cannon_markers(markers: Array[MeshInstance3D], material: Material) -> int:
	var count := 0
	for marker in markers:
		if is_instance_valid(marker) and marker.material_override == material:
			count += 1
	return count


func _sink() -> void:
	disable_ship(false)


func _should_incapacitate_for_boarding() -> bool:
	return incapacitation_health_ratio > 0.0 and not is_incapacitated and health > 0.0 and health / maxf(max_health, 1.0) <= incapacitation_health_ratio


func _resolve_incapacitation_or_sink() -> void:
	if is_sunk:
		return
	if health <= 0.0 and incapacitation_health_ratio > 0.0 and not is_incapacitated:
		health = max_health * maxf(incapacitation_health_ratio, 0.05)
		incapacitate_for_boarding()
	elif health <= 0.0:
		_sink()
	elif _should_incapacitate_for_boarding():
		incapacitate_for_boarding()


func incapacitate_for_boarding() -> void:
	if is_sunk or is_incapacitated:
		return
	is_incapacitated = true
	incapacitated_time_remaining = _get_foundering_delay_for_class()
	combat_morale = minf(combat_morale, 16.0)
	health = maxf(health, max_health * maxf(incapacitation_health_ratio, 0.05))
	speed = 0.0
	velocity = Vector3.ZERO
	_port_reload = 999.0
	_starboard_reload = 999.0
	is_bracing = false
	is_repairing = false
	if _damage_smoke:
		_damage_smoke.emitting = true
		_damage_smoke.amount_ratio = maxf(_damage_smoke.amount_ratio, 0.75)
	health_changed.emit(health, max_health)


func _get_foundering_delay_for_class() -> float:
	match hull_class:
		"Sloop":
			return 28.0
		"Brig":
			return 34.0
		"Frigate":
			return 42.0
		"Ship of the Line":
			return 50.0
		"Man o' War":
			return 58.0
	return incapacitated_sink_delay


func _update_incapacitated_foundering(delta: float) -> void:
	if not is_incapacitated or is_sunk:
		return
	if bool(get_meta("boarding_protected", false)) or _boarding_visual_active:
		return
	incapacitated_time_remaining = maxf(incapacitated_time_remaining - delta, 0.0)
	if incapacitated_time_remaining <= 0.0:
		_sink()


func get_boarding_window_remaining() -> float:
	return maxf(incapacitated_time_remaining, 0.0)


func disable_ship(captured := false) -> void:
	if is_sunk:
		return
	is_sunk = true
	is_incapacitated = false
	incapacitated_time_remaining = 0.0
	was_captured = captured
	health = 0.0
	collision_layer = 0
	collision_mask = 0
	speed = 0.0
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_sink_elapsed = 0.0
	_sink_start_y = global_position.y
	_sink_roll_direction = -1.0 if randf() < 0.5 else 1.0
	_sink_fx_stage = 0
	match hull_class:
		"Sloop": _sink_duration = 3.8
		"Brig": _sink_duration = 5.8
		"Frigate": _sink_duration = 8.0
		"Ship of the Line": _sink_duration = 11.5
		"Man o' War": _sink_duration = 14.5
		_: _sink_duration = 6.0
	if _damage_smoke:
		_damage_smoke.emitting = true
	if not captured:
		_play_audio_event("sinking", false, -1.5)
		CombatFx.spawn_sinking_burst(get_tree().current_scene if get_tree().current_scene else get_parent(), global_position, hull_class, 0)
	health_changed.emit(health, max_health)
	sunk.emit(self)


func _update_sinking(delta: float) -> void:
	_sink_elapsed += delta
	var progress := clampf(_sink_elapsed / maxf(_sink_duration, 0.1), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	var depth := 4.2
	var roll_target := 1.05
	var pitch_target := -0.22
	match hull_class:
		"Sloop":
			depth = 4.4
			roll_target = 1.38
			pitch_target = -0.38
		"Brig":
			depth = 5.1
			roll_target = 1.18
			pitch_target = -0.28
		"Frigate":
			depth = 6.4
			roll_target = 1.02
			pitch_target = -0.42
		"Ship of the Line":
			depth = 8.2
			roll_target = 0.84
			pitch_target = -0.30
			fire_intensity = maxf(fire_intensity, 0.48 * (1.0 - progress * 0.55))
		"Man o' War":
			depth = 9.8
			roll_target = 0.76
			pitch_target = -0.36
			fire_intensity = maxf(fire_intensity, 0.68 * (1.0 - progress * 0.48))
	global_position.y = _sink_start_y - pow(progress, 1.48) * depth
	_update_visual(delta)
	if _visual_root:
		_visual_root.rotation.z += _sink_roll_direction * roll_target * eased
		_visual_root.rotation.x += pitch_target * smoothstep(0.12, 1.0, progress)
	if hull_class == "Frigate" and progress > 0.46 and not _mast_nodes.is_empty():
		_mast_nodes[0].rotation.z = _sink_roll_direction * lerpf(0.0, 1.18, smoothstep(0.46, 0.78, progress))
	var wanted_stage := 1 if progress >= 0.34 else 0
	if progress >= 0.70:
		wanted_stage = 2
	if wanted_stage > _sink_fx_stage and progress < 0.96:
		_sink_fx_stage = wanted_stage
		CombatFx.spawn_sinking_burst(get_tree().current_scene if get_tree().current_scene else get_parent(), global_position, hull_class, wanted_stage)
	_update_damage_smoke()


func _get_wind_efficiency(forward: Vector3) -> float:
	var alignment := forward.dot(wind_direction.normalized())
	var side_load := absf(forward.cross(wind_direction.normalized()).y)
	var tailwind := clampf((alignment + 1.0) * 0.5, 0.0, 1.0)
	return clampf(0.56 + tailwind * 0.28 + side_load * 0.20, 0.54, 1.04)


func set_ocean_simulation_time(value: float) -> void:
	ocean_simulation_time = value


func set_ocean_wave_profile(sea_state: float, wave_speed: float, wave_chop: float) -> void:
	ocean_sea_state = sea_state
	ocean_wave_speed = wave_speed
	ocean_wave_chop = wave_chop


func stop_water_motion() -> void:
	speed = 0.0
	_target_speed = 0.0
	_target_rudder = 0.0
	_current_rudder = 0.0
	_water_velocity = Vector3.ZERO
	_yaw_velocity = 0.0
	_lateral_slip = 0.0
	_turn_heel = 0.0
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _get_active_ocean_time() -> float:
	return ocean_simulation_time if ocean_simulation_time >= 0.0 else _wave_time


func _update_ocean_position(delta: float) -> void:
	var target_height := -0.18 + _sample_ocean_height(global_position, _get_active_ocean_time())
	var follow_rate := 4.8
	match hull_class:
		"Sloop": follow_rate = 6.6
		"Frigate": follow_rate = 4.4
		"Ship of the Line": follow_rate = 3.4
		"Man o' War": follow_rate = 2.8
	global_position.y = lerpf(global_position.y, target_height, 1.0 - exp(-follow_rate * delta))


func _get_sail_factor() -> float:
	var ratio := clampf(sail_integrity / max_sail_integrity, 0.0, 1.0)
	return lerpf(0.42, 1.0, ratio)


func _get_rudder_factor() -> float:
	var ratio := clampf(rudder_integrity / max_rudder_integrity, 0.0, 1.0)
	return lerpf(0.48, 1.0, ratio)


func _heading_degrees() -> float:
	var forward := -global_transform.basis.z.normalized()
	var angle := rad_to_deg(atan2(forward.x, forward.z))
	return fposmod(angle + 360.0, 360.0)


func _signed_angle_to_direction(direction: Vector3) -> float:
	var forward := -global_transform.basis.z.normalized()
	var target := direction.normalized()
	return atan2(forward.cross(target).y, forward.dot(target))


func _update_visual(_delta: float) -> void:
	if _visual_root == null:
		return

	_wave_time += _delta
	_update_wave_visual_motion(_delta)
	_update_detached_damage_parts(_delta)
	var speed_ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	_broadside_recoil = move_toward(_broadside_recoil, 0.0, _delta * 2.45)
	_impact_recoil = move_toward(_impact_recoil, 0.0, _delta * 3.20)
	_rogue_wave_roll = move_toward(_rogue_wave_roll, 0.0, _delta * 0.72)
	_rogue_wave_heave = move_toward(_rogue_wave_heave, 0.0, _delta * 1.18)
	_rogue_wave_pitch = move_toward(_rogue_wave_pitch, 0.0, _delta * 0.62)
	_sail_hit_flutter = move_toward(_sail_hit_flutter, 0.0, _delta * 2.75)
	_decay_cannon_recoil(_port_cannon_recoil, _delta)
	_decay_cannon_recoil(_starboard_cannon_recoil, _delta)
	_visual_root.position.y = speed_ratio * 0.04 - flooding * 0.12 + _rogue_wave_heave * 0.34 + _sea_heave
	_visual_root.rotation.x = speed_ratio * 0.035 - _broadside_recoil * 0.030 - _impact_recoil * 0.045 - _rogue_wave_pitch * 0.32 + _sea_pitch
	_visual_root.rotation.z = _turn_heel - _broadside_recoil_side * _broadside_recoil * 0.060 + _impact_recoil_side * _impact_recoil * 0.095 + _flooding_side * flooding * 0.12 + _rogue_wave_roll * 0.28 + _sea_roll

	var wake_alpha := clampf(speed_ratio * 0.42, 0.0, 0.42)
	_set_wake_alpha(_wake_left, wake_alpha)
	_set_wake_alpha(_wake_right, wake_alpha)
	_set_wake_alpha(_wake_center, wake_alpha * 0.58)
	_update_water_contact_fx(speed_ratio)
	_update_sail_damage_visual()
	if _broadside_recoil > 0.001:
		_update_cannon_damage_visuals(_port_cannon_nodes, port_cannon_integrity, -1.0)
		_update_cannon_damage_visuals(_starboard_cannon_nodes, starboard_cannon_integrity, 1.0)
		_update_cannon_damage_visuals(_lower_port_cannon_nodes, port_cannon_integrity, -1.0)
		_update_cannon_damage_visuals(_lower_starboard_cannon_nodes, starboard_cannon_integrity, 1.0)
	_update_gunport_readiness(_port_gunport_visuals, -1, _port_reload)
	_update_gunport_readiness(_starboard_gunport_visuals, 1, _starboard_reload)
	_crew_update_accumulator += _delta
	var crew_update_interval := 0.0 if accepts_player_input else 0.10
	if not accepts_player_input and not _boarding_visual_active:
		var active_camera := get_viewport().get_camera_3d() if get_viewport() else null
		if is_instance_valid(active_camera):
			var camera_distance := global_position.distance_to(active_camera.global_position)
			if camera_distance > 110.0:
				crew_update_interval = 0.25
			elif camera_distance > 70.0:
				crew_update_interval = 0.16
	if _crew_update_accumulator >= crew_update_interval:
		_update_visual_crew(_crew_update_accumulator)
		_crew_update_accumulator = 0.0


func _update_wave_visual_motion(delta: float) -> void:
	# Ocean motion now belongs entirely to the rigid body. Keeping a second visual
	# wave solver here causes masts, crew and gunports to disagree with collisions.
	var settle := 1.0 - exp(-8.0 * delta)
	_sea_pitch = lerpf(_sea_pitch, 0.0, settle)
	_sea_roll = lerpf(_sea_roll, 0.0, settle)
	_sea_heave = lerpf(_sea_heave, 0.0, settle)


func set_external_water_feedback(speed_ratio: float, wave_impact: float, wave_contact: float) -> void:
	_bow_wave_impact = clampf(wave_impact, 0.0, 1.0)
	_bow_wave_contact = clampf(wave_contact, 0.0, 1.0)
	_update_water_contact_fx(clampf(speed_ratio, 0.0, 1.0))


func _update_water_contact_fx(speed_ratio: float) -> void:
	var impact := clampf(_bow_wave_impact, 0.0, 1.0)
	var contact := clampf(_bow_wave_contact, 0.0, 1.0)
	var spray_signal := clampf(speed_ratio * 0.52 + impact * 0.92 + contact * 0.12, 0.0, 1.0)
	if _bow_spray:
		_bow_spray.emitting = spray_signal > 0.055
		_bow_spray.amount_ratio = smoothstep(0.04, 0.92, spray_signal)
		var spray_process := _bow_spray.process_material as ParticleProcessMaterial
		if spray_process:
			var class_scale := clampf(_hull_width / 3.2, 0.68, 1.58)
			spray_process.direction = Vector3(0.0, lerpf(0.54, 0.90, impact), -lerpf(0.84, 0.44, impact)).normalized()
			spray_process.spread = lerpf(24.0, 38.0, impact)
			spray_process.initial_velocity_min = lerpf(1.15, 3.10, spray_signal) * class_scale
			spray_process.initial_velocity_max = lerpf(2.25, 5.70, spray_signal) * class_scale
	if _stern_wash:
		_stern_wash.emitting = speed_ratio > 0.10
		_stern_wash.amount_ratio = smoothstep(0.08, 0.78, speed_ratio)
	var hull_foam_amount := clampf(
		lerpf(0.12, 0.66, smoothstep(0.04, 0.88, speed_ratio))
		+ contact * 0.24
		+ impact * 0.18,
		0.0,
		1.0
	)
	for hull_foam in [_port_hull_foam, _starboard_hull_foam]:
		if hull_foam:
			hull_foam.emitting = speed_ratio > 0.035 or contact > 0.18
			hull_foam.amount_ratio = hull_foam_amount


func _sample_ocean_height(world_point: Vector3, time_value: float) -> float:
	var d1 := Vector2(wind_direction.x, wind_direction.z).normalized()
	if d1.length_squared() < 0.01:
		d1 = Vector2(0.85, -0.35).normalized()
	var perpendicular := Vector2(-d1.y, d1.x)
	var d2 := (perpendicular * 0.58 + d1 * 0.42).normalized()
	var d3 := (Vector2(d1.y, -d1.x) * 0.78 + d1 * 0.22).normalized()
	var d4 := (-d1 * 0.16 + Vector2(0.33, 0.94)).normalized()
	var d5 := (d1 * 0.72 + Vector2(-0.68, 0.22)).normalized()
	var d6 := (d2 * 0.35 - d1 * 0.65).normalized()
	var point := Vector2(world_point.x, world_point.z)
	time_value *= ocean_wave_speed
	var secondary_scale := lerpf(0.64, 1.12, ocean_wave_chop * 0.5)
	return (
		sin(point.dot(d1) * 0.045 + time_value * 0.50) * 0.42
		+ sin(point.dot(d2) * 0.082 + time_value * 0.75 + 1.7) * 0.24 * secondary_scale
		+ sin(point.dot(d3) * 0.145 + time_value * 1.08 + 3.2) * 0.12 * ocean_wave_chop
		+ sin(point.dot(d4) * 0.029 + time_value * 0.34 + 0.8) * 0.30
		+ sin(point.dot(d5) * 0.245 + time_value * 1.48 + 4.4) * 0.065 * ocean_wave_chop
		+ sin(point.dot(d6) * 0.380 + time_value * 1.92 + 2.3) * 0.032 * ocean_wave_chop
	) * ocean_sea_state


func _decay_cannon_recoil(recoil: Array[float], delta: float) -> void:
	for index in range(recoil.size()):
		recoil[index] = move_toward(recoil[index], 0.0, delta * 4.8)


func _set_wake_alpha(wake: MeshInstance3D, alpha: float) -> void:
	if wake == null or wake.material_override == null:
		return

	var material := wake.material_override as StandardMaterial3D
	material.albedo_color.a = alpha


func _update_damage_smoke() -> void:
	if _damage_smoke == null:
		return

	var damage_ratio := 1.0 - (health / max_health)
	_damage_smoke.amount_ratio = clampf(damage_ratio, 0.0, 1.0)
	_damage_smoke.emitting = damage_ratio > 0.28
	if _fire_particles:
		_fire_particles.amount_ratio = clampf(fire_intensity, 0.0, 1.0)
		_fire_particles.emitting = fire_intensity > 0.04
	if _fire_ember_particles:
		_fire_ember_particles.amount_ratio = clampf(fire_intensity * 1.35, 0.0, 1.0)
		_fire_ember_particles.emitting = fire_intensity > 0.08


func _update_flooding_visuals() -> void:
	var leak_amount := clampf(flooding * 1.65, 0.0, 1.0)
	if _port_leak_particles:
		_port_leak_particles.amount_ratio = leak_amount
		_port_leak_particles.emitting = flooding > 0.035 and _flooding_side < 0.0
	if _starboard_leak_particles:
		_starboard_leak_particles.amount_ratio = leak_amount
		_starboard_leak_particles.emitting = flooding > 0.035 and _flooding_side >= 0.0


func _update_sail_damage_visual() -> void:
	if _sail_material == null:
		return

	var damage_ratio := 1.0 - clampf(sail_integrity / max_sail_integrity, 0.0, 1.0)
	var deployment := smoothstep(0.02, 0.92, sail_setting)
	var furled_amount := 1.0 - smoothstep(0.16, 0.72, sail_setting)
	_sail_view_alpha = _get_sail_view_alpha()
	var warm_canvas := sail_color.lerp(Color(0.61, 0.55, 0.43), 0.34)
	var canvas_color := warm_canvas.lerp(Color(0.29, 0.27, 0.23), damage_ratio * 0.78)
	canvas_color.a = _sail_view_alpha
	_sail_material.albedo_color = canvas_color
	var t := Time.get_ticks_msec() * 0.001 + _bob_phase
	for i in range(_sail_nodes.size()):
		var sail := _sail_nodes[i]
		if not is_instance_valid(sail):
			continue
		if sail.get_parent() is Node and bool(sail.get_parent().get_meta("detached", false)):
			continue
		var flutter := sin(t * 5.4 + float(i) * 1.7) * (_sail_hit_flutter * 0.16 + damage_ratio * 0.035)
		sail.visible = deployment > 0.045
		sail.scale = Vector3(1.0 + damage_ratio * 0.05, lerpf(1.0, 0.72, damage_ratio) * maxf(deployment, 0.08), 1.0)
		sail.rotation.z = damage_ratio * (0.14 if i % 2 == 0 else -0.11) + flutter
		sail.rotation.x = damage_ratio * 0.08 + absf(flutter) * 0.22
		var furled_roll := sail.get_meta("furled_roll", null) as MeshInstance3D
		if is_instance_valid(furled_roll):
			furled_roll.visible = furled_amount > 0.02
			var roll_thickness := lerpf(0.45, 1.0, furled_amount)
			furled_roll.scale = Vector3(roll_thickness, 1.0, roll_thickness)
	for i in range(_mast_nodes.size()):
		var mast := _mast_nodes[i]
		if not is_instance_valid(mast) or bool(mast.get_meta("detached", false)):
			continue
		var collapse_threshold := 0.52 + float(i) * 0.08
		var collapse := clampf((damage_ratio - collapse_threshold) / 0.34, 0.0, 1.0)
		var collapse_side := -1.0 if i % 2 == 0 else 1.0
		mast.rotation.z = collapse_side * collapse * 1.08
		mast.rotation.x = collapse * 0.26
	for i in range(_rigging_nodes.size()):
		var rope := _rigging_nodes[i]
		if is_instance_valid(rope):
			rope.visible = damage_ratio < 0.46 + float(i % 5) * 0.10


func _get_sail_view_alpha() -> float:
	if team_id != 0 or hull_class in ["Sloop", "Brig"] or get_viewport() == null:
		return 1.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1.0
	var local_camera := to_local(camera.global_position)
	var behind := smoothstep(-_hull_length * 0.08, _hull_length * 0.38, local_camera.z)
	var centerline := 1.0 - smoothstep(_hull_width * 0.52, _hull_width * 1.65, absf(local_camera.x))
	var elevated := smoothstep(_deck_y + 0.8, _deck_y + 5.0, local_camera.y)
	var occlusion := clampf(behind * centerline * elevated, 0.0, 1.0)
	var minimum_alpha := 0.56 if hull_class == "Man o' War" else (0.66 if hull_class == "Ship of the Line" else 0.78)
	return lerpf(1.0, minimum_alpha, occlusion)


func _update_regional_damage_visuals() -> void:
	var sail_damage := 1.0 - clampf(sail_integrity / max_sail_integrity, 0.0, 1.0)
	for i in range(_sail_tear_overlays.size()):
		var tear := _sail_tear_overlays[i]
		if is_instance_valid(tear):
			tear.visible = sail_damage > 0.08 + float(i) * 0.15

	var hull_damage := 1.0 - clampf(health / max_health, 0.0, 1.0)
	for i in range(_hull_scorch_marks.size()):
		var scorch := _hull_scorch_marks[i]
		if is_instance_valid(scorch):
			scorch.visible = hull_damage > 0.12 + float(i) * 0.13
	for i in range(_waterline_breaches.size()):
		var breach := _waterline_breaches[i]
		if is_instance_valid(breach):
			var threshold := 0.18 + float(i) * 0.105
			breach.visible = hull_damage + flooding * 0.65 > threshold
			var breach_scale := 0.82 + clampf(hull_damage + flooding, 0.0, 1.0) * 0.42
			breach.scale = Vector3.ONE * breach_scale

	_update_cannon_damage_visuals(_port_cannon_nodes, port_cannon_integrity, -1.0)
	_update_cannon_damage_visuals(_starboard_cannon_nodes, starboard_cannon_integrity, 1.0)
	_update_cannon_damage_visuals(_lower_port_cannon_nodes, port_cannon_integrity, -1.0)
	_update_cannon_damage_visuals(_lower_starboard_cannon_nodes, starboard_cannon_integrity, 1.0)
	_update_gunport_damage_visuals(_port_gunport_visuals, port_cannon_integrity, -1.0)
	_update_gunport_damage_visuals(_starboard_gunport_visuals, starboard_cannon_integrity, 1.0)


func _update_cannon_damage_visuals(nodes: Array[MeshInstance3D], integrity: float, side: float) -> void:
	if _cannon_damage_material == null or nodes.is_empty():
		return
	var recoil := _port_cannon_recoil if side < 0.0 else _starboard_cannon_recoil
	for i in range(nodes.size()):
		var cannon := nodes[i]
		if not is_instance_valid(cannon):
			continue
		var base_position: Vector3 = cannon.get_meta("base_position", cannon.position)
		var base_rotation: Vector3 = cannon.get_meta("base_rotation", cannon.rotation)
		var recoil_index := i % maxi(recoil.size(), 1)
		var recoil_amount := recoil[recoil_index] if recoil_index < recoil.size() else 0.0
		cannon.position = base_position + Vector3(-side * recoil_amount * 0.24, 0.0, 0.0)
		if _is_cannon_barrel_disabled(cannon, int(side)):
			cannon.material_override = _cannon_damage_material
			cannon.rotation = base_rotation + Vector3(0.18, 0.0, -side * 0.38)
			cannon.position.y = base_position.y - 0.13
		else:
			cannon.material_override = _cannon_normal_material
			cannon.rotation = base_rotation


func _update_gunport_damage_visuals(visuals: Array[Dictionary], integrity: float, side: float) -> void:
	if visuals.is_empty():
		return
	for index in range(visuals.size()):
		var data := visuals[index]
		var broken := bool(data.get("disabled", false))
		var damage_ratio := clampf(float(data.get("local_damage", 0.0)) / 16.0, 0.0, 1.0)
		var door := data.get("door") as MeshInstance3D
		var frame_top := data.get("top") as MeshInstance3D
		var frame_bottom := data.get("bottom") as MeshInstance3D
		var frame_fore := data.get("fore") as MeshInstance3D
		var frame_aft := data.get("aft") as MeshInstance3D
		var carriage := data.get("carriage") as MeshInstance3D
		var barrel := data.get("barrel") as MeshInstance3D
		var cover := data.get("cover") as MeshInstance3D
		var splinter_a := data.get("splinter_a") as MeshInstance3D
		var splinter_b := data.get("splinter_b") as MeshInstance3D
		var kit_cannon := data.get("kit_cannon") as Node3D
		for part in [door, frame_top, frame_bottom, frame_fore, frame_aft, carriage, cover]:
			if is_instance_valid(part):
				part.position = part.get_meta("base_position", part.position)
				part.rotation = part.get_meta("base_rotation", part.rotation)
		if is_instance_valid(door):
			door.material_override = _cannon_damage_material if broken else data.get("door_material")
		if is_instance_valid(barrel):
			barrel.material_override = _cannon_damage_material if broken else _cannon_normal_material
			barrel.visible = true
		if is_instance_valid(carriage):
			carriage.visible = true
		if is_instance_valid(kit_cannon):
			kit_cannon.visible = not broken
			kit_cannon.position = kit_cannon.get_meta("base_position", kit_cannon.position)
		if broken:
			var break_amount := lerpf(0.18, 0.48, damage_ratio)
			if is_instance_valid(frame_top):
				frame_top.rotation.x += side * break_amount
				frame_top.position.y += 0.05
			if is_instance_valid(frame_bottom):
				frame_bottom.rotation.x -= side * break_amount * 0.62
				frame_bottom.position.y -= 0.04
			if is_instance_valid(frame_fore):
				frame_fore.rotation.z += side * break_amount
			if is_instance_valid(frame_aft):
				frame_aft.rotation.z -= side * break_amount * 0.85
			if is_instance_valid(carriage):
				carriage.rotation.z += side * 0.18
				carriage.position.y -= 0.08
			if is_instance_valid(cover):
				cover.rotation.z += side * 0.42
				cover.position.y -= 0.10
		if is_instance_valid(splinter_a):
			splinter_a.visible = broken
		if is_instance_valid(splinter_b):
			splinter_b.visible = broken


func _is_cannon_barrel_disabled(cannon: MeshInstance3D, side: int) -> bool:
	var visuals := _port_gunport_visuals if side < 0 else _starboard_gunport_visuals
	for data in visuals:
		if data.get("barrel") == cannon:
			return bool(data.get("disabled", false))
	return false


func _add_persistent_hit_damage(report: Dictionary) -> void:
	var total_damage := float(report.get("health_damage", 0.0)) + float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	if total_damage < 2.5 or _visual_root == null:
		return
	var world_hit: Vector3 = report.get("hit_position", global_position)
	var local_hit := _visual_root.to_local(world_hit)
	local_hit.x = clampf(local_hit.x, -_hull_width * 0.515, _hull_width * 0.515)
	local_hit.y = clampf(local_hit.y, _deck_y - _hull_depth * 0.92, _deck_y + 0.12)
	local_hit.z = clampf(local_hit.z, -_hull_length * 0.46, _hull_length * 0.46)
	var root := Node3D.new()
	root.name = "PersistentBattleDamage"
	root.position = local_hit
	_visual_root.add_child(root)
	var splinter := _make_material(Color(0.42, 0.24, 0.10), 0.92)
	var on_deck := String(report.get("zone", "hull")) == "deck"
	var decal_index := 1 if total_damage >= 15.0 else 0
	var decal_size := clampf(0.40 + total_damage * 0.018, 0.46, 0.74)
	var decal := MeshInstance3D.new()
	decal.name = "ImpactDecal"
	var decal_mesh := QuadMesh.new()
	decal_mesh.size = Vector2(decal_size, decal_size)
	decal.mesh = decal_mesh
	decal.material_override = _make_damage_decal_material(decal_index, 0.96)
	if on_deck:
		decal.position = Vector3(0.0, 0.022, 0.0)
		decal.rotation.x = -PI * 0.5
	else:
		var side := signf(local_hit.x) if absf(local_hit.x) > 0.1 else 1.0
		decal.position = Vector3(side * 0.026, 0.0, 0.0)
		decal.rotation.y = side * PI * 0.5
		decal.rotation.z = randf_range(-0.20, 0.20)
	root.add_child(decal)
	for index in range(1):
		var chip := _add_box(root, "BrokenPlank", Vector3(0.035, 0.045, randf_range(0.22, 0.38)), Vector3(0.0, randf_range(-0.10, 0.10), randf_range(-0.14, 0.14)), splinter)
		chip.rotation.x = randf_range(-0.75, 0.75)
		chip.rotation.z = randf_range(-0.55, 0.55)
	_persistent_damage_marks.append(root)
	if _persistent_damage_marks.size() > 8:
		var oldest: Node3D = _persistent_damage_marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _update_cannon_ready_visuals() -> void:
	_update_cannon_ready_markers(_port_cannon_ready_markers, -1, port_cannon_integrity, _port_reload)
	_update_cannon_ready_markers(_starboard_cannon_ready_markers, 1, starboard_cannon_integrity, _starboard_reload)
	_update_gunport_readiness(_port_gunport_visuals, -1, _port_reload)
	_update_gunport_readiness(_starboard_gunport_visuals, 1, _starboard_reload)


func _update_gunport_readiness(visuals: Array[Dictionary], side: int, reload_time: float) -> void:
	var reload_ratio := clampf(reload_time / maxf(_get_reload_duration(side), 0.01), 0.0, 1.0)
	var open_amount := 1.0 - smoothstep(0.12, 0.82, reload_ratio)
	for data in visuals:
		if bool(data.get("disabled", false)):
			continue
		var barrel := data.get("barrel") as MeshInstance3D
		var cover := data.get("cover") as MeshInstance3D
		if is_instance_valid(barrel):
			var barrel_base: Vector3 = barrel.get_meta("base_position", barrel.position)
			barrel.position = barrel_base - Vector3(float(side) * reload_ratio * 0.20, 0.0, 0.0)
		if is_instance_valid(cover):
			var cover_base: Vector3 = cover.get_meta("base_position", cover.position)
			var cover_rotation: Vector3 = cover.get_meta("base_rotation", cover.rotation)
			cover.position = cover_base + Vector3(float(side) * open_amount * 0.025, open_amount * 0.29, 0.0)
			cover.rotation = cover_rotation + Vector3(0.0, 0.0, -float(side) * open_amount * 0.08)


func _update_cannon_ready_markers(markers: Array[MeshInstance3D], side: int, integrity: float, reload_time: float) -> void:
	if _cannon_ready_material == null or _cannon_reloading_material == null or _cannon_disabled_material == null:
		return
	if markers.is_empty():
		return
	var reload_ratio := clampf(reload_time / maxf(_get_reload_duration(side), 0.01), 0.0, 1.0)
	var pulse := 0.86 + sin(Time.get_ticks_msec() * 0.008) * 0.14
	for i in range(markers.size()):
		var marker := markers[i]
		if not is_instance_valid(marker):
			continue
		var column_active := false
		for placement in _get_active_cannon_placements(side):
			if absf(float(placement.get("z", 0.0)) - marker.position.z) < 0.08:
				column_active = true
				break
		if not column_active:
			marker.material_override = _cannon_disabled_material
			marker.scale = Vector3.ONE * 0.58
		elif reload_time <= 0.01:
			marker.material_override = _cannon_ready_material
			marker.scale = Vector3.ONE * pulse
		else:
			marker.material_override = _cannon_reloading_material
			marker.scale = Vector3.ONE * lerpf(0.55, 0.92, 1.0 - reload_ratio)


func _update_detached_damage_parts(delta: float) -> void:
	_hull_fragment_cooldown = maxf(_hull_fragment_cooldown - delta, 0.0)
	_rail_fragment_cooldown = maxf(_rail_fragment_cooldown - delta, 0.0)
	for index in range(_detached_damage_parts.size() - 1, -1, -1):
		var data := _detached_damage_parts[index]
		var part := data.get("node") as Node3D
		if not is_instance_valid(part):
			_detached_damage_parts.remove_at(index)
			continue
		var life := float(data.get("life", 0.0)) + delta
		var velocity: Vector3 = data.get("velocity", Vector3.ZERO)
		var spin: Vector3 = data.get("spin", Vector3.ZERO)
		var water_height := -0.18
		if fluid_interactor != null and fluid_interactor.fluid_area != null:
			water_height = fluid_interactor.fluid_area.get_height(part.global_position)
		var water_contact := bool(data.get("water_contact", false))
		var water_age := float(data.get("water_age", 0.0))
		if not water_contact:
			velocity.y -= 7.2 * delta
			part.global_position += velocity * delta
			part.rotation += spin * delta
			if part.global_position.y <= water_height + 0.02:
				water_contact = true
				part.global_position.y = water_height + 0.02
				velocity = Vector3(velocity.x, 0.0, velocity.z) * 0.34
				spin *= 0.24
		else:
			water_age += delta
			velocity *= exp(-3.6 * delta)
			spin *= exp(-2.8 * delta)
			part.global_position += velocity * delta
			part.rotation += spin * delta
			var sink_depth := clampf((water_age - 1.6) * 0.075, 0.0, 0.34)
			part.global_position.y = lerpf(part.global_position.y, water_height - sink_depth, 1.0 - exp(-3.0 * delta))
		data["life"] = life
		data["velocity"] = velocity
		data["spin"] = spin
		data["water_contact"] = water_contact
		data["water_age"] = water_age
		if life >= float(data.get("max_life", 10.0)):
			part.queue_free()
			_detached_damage_parts.remove_at(index)


func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	collider.name = "HullCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(_hull_width * 0.94, _hull_depth * 0.90, _hull_length * 0.93)
	collider.shape = box
	collider.position.y = _deck_y - _hull_depth * 0.42
	add_child(collider)


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var hull_tint := hull_color.lerp(Color(0.96, 0.83, 0.66), 0.78)
	var hull_mat := _make_textured_material(
		hull_tint,
		0.86,
		DarkPlanksAlbedo,
		DarkPlanksNormal,
		DarkPlanksRoughness,
		DarkPlanksAO,
		Vector2(clampf(_hull_length / 7.2, 1.25, 2.25), 0.82),
		0.28
	)
	var deck_mat := _make_textured_material(
		Color(0.96, 0.88, 0.75),
		0.92,
		WeatheredPlanksAlbedo,
		WeatheredPlanksNormal,
		WeatheredPlanksRoughness,
		WeatheredPlanksAO,
		Vector2(clampf(_hull_width / 3.8, 0.95, 1.45), clampf(_hull_length / 8.0, 1.15, 2.15)),
		0.16
	)
	var class_trim := Color(0.48, 0.34, 0.18)
	if hull_class == "Frigate":
		class_trim = class_trim.lerp(Color(0.58, 0.40, 0.20), 0.28)
	elif hull_class == "Ship of the Line":
		class_trim = class_trim.lerp(Color(0.62, 0.43, 0.20), 0.34)
	elif hull_class == "Man o' War":
		class_trim = class_trim.lerp(Color(0.54, 0.36, 0.16), 0.36)
	var trim_mat := _make_material(class_trim, 0.78)
	var painted_wood_mat := _make_textured_material(
		hull_tint.lerp(class_trim, 0.22),
		0.84,
		PaintedWoodAlbedo,
		PaintedWoodNormal,
		PaintedWoodRoughness,
		null,
		Vector2(clampf(_hull_length / 10.0, 1.0, 1.7), 0.80),
		0.15
	)
	var dark_mat := _make_textured_material(Color(0.78, 0.70, 0.60), 0.91, DarkPlanksAlbedo, DarkPlanksNormal, DarkPlanksRoughness, DarkPlanksAO, Vector2(1.45, 0.72), 0.18)
	var carriage_mat := _make_textured_material(Color(0.90, 0.68, 0.48), 0.90, WeatheredPlanksAlbedo, WeatheredPlanksNormal, WeatheredPlanksRoughness, WeatheredPlanksAO, Vector2(1.15, 1.15), 0.16)
	var cannon_mat := _make_textured_material(Color(0.54, 0.52, 0.48), 0.68, RustyMetalAlbedo, RustyMetalNormal, RustyMetalRoughness, RustyMetalAO, Vector2(1.35, 1.35), 0.32)
	cannon_mat.metallic = 0.62
	_cannon_normal_material = cannon_mat
	_cannon_damage_material = _make_material(Color(0.11, 0.10, 0.09), 0.95)
	_cannon_ready_material = _make_emissive_material(Color(0.46, 1.0, 0.62, 0.86), Color(0.16, 1.0, 0.32), 0.55)
	_cannon_reloading_material = _make_emissive_material(Color(1.0, 0.60, 0.22, 0.72), Color(1.0, 0.36, 0.08), 0.45)
	_cannon_disabled_material = _make_emissive_material(Color(0.22, 0.18, 0.15, 0.48), Color(0.10, 0.07, 0.05), 0.9)
	var cloth_mat := _make_textured_material(sail_color.lerp(Color(1.0, 0.96, 0.84), 0.40), 0.94, null, SailFabricNormal, SailFabricRoughness, SailFabricAO, Vector2(18.0, 18.0), 0.03)
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sail_material = cloth_mat
	var flag_mat := _make_material(Color(0.04, 0.035, 0.032), 0.84)
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _create_hull_mesh()
	hull.material_override = hull_mat
	_visual_root.add_child(hull)

	var weather_deck := MeshInstance3D.new()
	weather_deck.name = "%sWeatherDeck" % hull_class.replace(" ", "").replace("'", "")
	weather_deck.mesh = _create_weather_deck_mesh()
	weather_deck.material_override = deck_mat
	_visual_root.add_child(weather_deck)
	_build_deck_surface_details(deck_mat, dark_mat, trim_mat)
	var rail_x := _get_hull_side_surface_x(_deck_y, 0.0) * 0.98
	_build_breakable_rails(rail_x, trim_mat)
	var bowsprit_length := _hull_length * (0.31 if hull_class == "Sloop" else 0.27)
	var bowsprit := _add_box(_visual_root, "Bowsprit", Vector3(0.15 + _hull_width * 0.012, 0.15, bowsprit_length), Vector3(0.0, _deck_y + 0.22, -_hull_length * 0.58), trim_mat)
	if hull_class == "Frigate":
		bowsprit.rotation.x = 0.11
		bowsprit.position.y += 0.10
	elif hull_class == "Man o' War":
		bowsprit.rotation.x = 0.10
		bowsprit.position.y += 0.12

	_build_class_superstructure(painted_wood_mat, deck_mat, trim_mat)
	var cannon_y := _deck_y - 0.28
	var cannon_row_spacing := clampf(_hull_depth * 0.215, 0.43, 0.60)
	if hull_class == "Sloop":
		# A sloop carries its light battery on the weather deck, not at the
		# waterline like an enclosed lower gun deck.
		cannon_y = _deck_y - 0.05
	elif hull_class == "Man o' War":
		cannon_y = _deck_y - 0.25
		cannon_row_spacing = 0.49
	_build_broadside_battery_architecture(cannon_y, cannon_row_spacing, dark_mat, trim_mat)
	for z in _get_full_cannon_positions():
		_port_cannon_recoil.append(0.0)
		_starboard_cannon_recoil.append(0.0)
		_port_cannon_ready_markers.append(_add_cannon_ready_marker("PortCannonReady", Vector3(-_muzzle_x, _muzzle_y, z)))
		_starboard_cannon_ready_markers.append(_add_cannon_ready_marker("StarboardCannonReady", Vector3(_muzzle_x, _muzzle_y, z)))
	for deck_row in range(_cannon_rows):
		var row_y := cannon_y - float(deck_row) * cannon_row_spacing
		for z in _get_cannon_positions_for_row(deck_row):
			var port_cannon := _add_cannon_emplacement(-1, z, row_y, cannon_mat, carriage_mat, carriage_mat, deck_row)
			var starboard_cannon := _add_cannon_emplacement(1, z, row_y, cannon_mat, carriage_mat, carriage_mat, deck_row)
			if deck_row == 0:
				_port_cannon_nodes.append(port_cannon)
				_starboard_cannon_nodes.append(starboard_cannon)
			else:
				_lower_port_cannon_nodes.append(port_cannon)
				_lower_starboard_cannon_nodes.append(starboard_cannon)

	_build_deck_fittings(deck_mat, trim_mat, dark_mat)
	_build_class_rig(cloth_mat, trim_mat, flag_mat)
	_build_standing_rigging()
	_create_damage_overlays()
	_create_wake()
	_create_damage_smoke()
	_build_visual_crew()
	_update_cannon_ready_visuals()


func _build_breakable_rails(rail_x: float, material: Material) -> void:
	var segment_count := clampi(base_cannons_per_side + 2, 6, 10)
	var total_length := _hull_length * 0.80
	var segment_length := total_length / float(segment_count)
	var rail_width := 0.13
	var rail_height := 0.30 + _cannon_rows * 0.06
	var rail_y := _deck_y + 0.27
	if hull_class == "Frigate":
		rail_width = 0.085
		rail_height = 0.14
		rail_y = _deck_y + 0.34
	for side in [-1, 1]:
		for index in range(segment_count):
			var z := -total_length * 0.5 + segment_length * (float(index) + 0.5)
			var conforming_x := minf(rail_x, _get_hull_side_surface_x(_deck_y + 0.04, z) * 0.98)
			var rail := _add_box(
				_visual_root,
				"PortRailSegment" if side < 0 else "StarboardRailSegment",
				Vector3(rail_width, rail_height, segment_length * 0.91),
				Vector3(float(side) * conforming_x, rail_y, z),
				material
			)
			rail.set_meta("base_position", rail.position)
			_breakable_rail_segments.append({"node": rail, "side": side, "z": z, "broken": false})


func _build_deck_surface_details(deck_mat: Material, dark_mat: Material, trim_mat: Material) -> void:
	var seam_mat := _make_material(Color(0.075, 0.040, 0.022), 0.96)
	var deck_width := _hull_width * 0.78
	var deck_length := _hull_length * 0.77
	var transverse_count := clampi(int(deck_length / 0.58), 9, 32)
	for index in range(transverse_count + 1):
		var z := lerpf(-deck_length * 0.5, deck_length * 0.5, float(index) / float(transverse_count))
		_add_box(_visual_root, "DeckPlankSeam%02d" % index, Vector3(deck_width, 0.012, 0.018), Vector3(0.0, _deck_y + 0.078, z), seam_mat)
	var longitudinal_lanes := [-0.30, -0.10, 0.10, 0.30]
	for lane_index in range(longitudinal_lanes.size()):
		_add_box(_visual_root, "DeckLongSeam%02d" % lane_index, Vector3(0.016, 0.013, deck_length), Vector3(_hull_width * float(longitudinal_lanes[lane_index]), _deck_y + 0.079, 0.0), seam_mat)
	_add_box(_visual_root, "PortDeckWaterway", Vector3(0.09, 0.06, deck_length), Vector3(-_hull_width * 0.385, _deck_y + 0.105, 0.0), trim_mat)
	_add_box(_visual_root, "StarboardDeckWaterway", Vector3(0.09, 0.06, deck_length), Vector3(_hull_width * 0.385, _deck_y + 0.105, 0.0), trim_mat)

	var barrel_count := 2 if hull_class in ["Sloop", "Brig"] else 4
	for index in range(barrel_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := lerpf(-_hull_length * 0.14, _hull_length * 0.18, float(index) / float(maxi(barrel_count - 1, 1)))
		var barrel := PirateKitAssets.instantiate_prop("barrel")
		if barrel:
			barrel.name = "PirateKitBarrel"
			barrel.position = Vector3(side * _hull_width * 0.29, _deck_y + 0.08, z)
			barrel.rotation.y = float(index) * 0.57
			barrel.scale = Vector3.ONE * 0.68
			_visual_root.add_child(barrel)
	if hull_class not in ["Sloop"]:
		var chest := PirateKitAssets.instantiate_prop("chest")
		if chest:
			chest.name = "PirateKitChest"
			chest.position = Vector3(_hull_width * 0.22, _deck_y + 0.09, -_hull_length * 0.10)
			chest.rotation.y = -0.18
			chest.scale = Vector3.ONE * 0.42
			_visual_root.add_child(chest)
		var bucket := PirateKitAssets.instantiate_prop("bucket")
		if bucket:
			bucket.name = "PirateKitBucket"
			bucket.position = Vector3(-_hull_width * 0.20, _deck_y + 0.08, _hull_length * 0.11)
			bucket.scale = Vector3.ONE * 0.52
			_visual_root.add_child(bucket)

	if hull_class in ["Frigate", "Ship of the Line", "Man o' War"]:
		var rise := 0.22 if hull_class == "Frigate" else (0.48 if hull_class == "Ship of the Line" else 0.62)
		var stair_count := 5
		for step in range(stair_count):
			var ratio := float(step + 1) / float(stair_count)
			_add_box(_visual_root, "QuarterdeckStep", Vector3(_hull_width * 0.20, rise / float(stair_count), 0.34), Vector3(-_hull_width * 0.22, _deck_y + 0.09 + rise * ratio * 0.5, _hull_length * (0.20 + ratio * 0.055)), deck_mat)


func _build_visual_crew() -> void:
	var crew_count := 10
	match hull_class:
		"Sloop": crew_count = 7
		"Frigate": crew_count = 15
		"Ship of the Line": crew_count = 28
		"Man o' War": crew_count = 38
	if not accepts_player_input:
		crew_count = maxi(int(ceil(float(crew_count) * 0.55)), 5)
	var uniform_base := Color(0.23, 0.48, 0.72) if team_id == 0 else Color(0.68, 0.20, 0.16)
	var uniform_mats: Array[StandardMaterial3D] = []
	for tint in [Color(0.88, 0.92, 0.94), Color(0.62, 0.72, 0.76), Color(0.72, 0.58, 0.42), Color(0.46, 0.52, 0.48), Color(0.92, 0.76, 0.48)]:
		uniform_mats.append(_make_material(uniform_base.lerp(tint, 0.24), 0.90))
	var skin_mats: Array[StandardMaterial3D] = [
		_make_material(Color(0.72, 0.53, 0.36), 0.94),
		_make_material(Color(0.54, 0.37, 0.25), 0.94),
		_make_material(Color(0.82, 0.66, 0.48), 0.94),
		_make_material(Color(0.38, 0.25, 0.18), 0.94),
	]
	var cloth_mats: Array[StandardMaterial3D] = [
		_make_material(Color(0.09, 0.075, 0.06), 0.92),
		_make_material(Color(0.20, 0.16, 0.11), 0.92),
		_make_material(Color(0.11, 0.14, 0.16), 0.92),
	]
	var steel_mat := _make_material(Color(0.38, 0.40, 0.39), 0.46)
	var leather_mat := _make_material(Color(0.19, 0.105, 0.055), 0.94)
	for i in range(crew_count):
		var crew := Node3D.new()
		crew.name = "DeckCrew%02d" % i
		var role := i % 5
		var role_slot := int(i / 5)
		var role_count := maxi(int(ceil(float(crew_count - role) / 5.0)), 1)
		crew.position = _get_crew_station_position(role, role_slot, role_count)
		crew.rotation.y = _get_crew_station_rotation(role, crew.position)
		var height_scale := 0.92 + float(i % 4) * 0.045
		var width_scale := 0.92 + float((i * 3) % 5) * 0.035
		crew.scale = Vector3(width_scale, height_scale, width_scale)
		crew.set_meta("base_position", crew.position)
		crew.set_meta("base_rotation", crew.rotation)
		crew.set_meta("crew_state", "active")
		crew.set_meta("crew_permanent", false)
		crew.set_meta("crew_velocity", Vector3.ZERO)
		crew.set_meta("crew_state_time", 0.0)
		crew.set_meta("crew_role", role)
		crew.set_meta("walk_phase", fmod(float(i) * 1.73, TAU))
		_visual_root.add_child(crew)
		var uniform_mat := uniform_mats[i % uniform_mats.size()]
		var skin_mat := skin_mats[(i * 3) % skin_mats.size()]
		var crew_cloth := cloth_mats[(i * 2) % cloth_mats.size()]
		var pirate_model := PirateKitAssets.instantiate_crew(i + (2 if team_id != 0 else 0))
		if pirate_model:
			pirate_model.name = "PirateModel"
			pirate_model.scale = Vector3.ONE * 0.43
			pirate_model.rotation.y = PI
			crew.add_child(pirate_model)
			var animator := PirateKitAssets.find_animation_player(pirate_model)
			if animator:
				crew.set_meta("asset_animator", animator)
				_set_crew_asset_animation(crew, "Idle")
			_add_box(crew, "TeamBandana", Vector3(0.23, 0.045, 0.18), Vector3(0.0, 0.64, 0.015), uniform_mat)
		else:
			_add_cylinder(crew, "Torso", 0.112, 0.42, Vector3(0.0, 0.35, 0.0), uniform_mat, Vector3.ZERO)
			_add_cylinder(crew, "LegL", 0.038, 0.32, Vector3(-0.058, 0.05, 0.0), crew_cloth, Vector3.ZERO)
			_add_cylinder(crew, "LegR", 0.038, 0.32, Vector3(0.058, 0.05, 0.0), crew_cloth, Vector3.ZERO)
			_add_cylinder(crew, "ArmL", 0.033, 0.31, Vector3(-0.145, 0.35, 0.0), skin_mat, Vector3(0.0, 0.0, 0.42))
			_add_cylinder(crew, "ArmR", 0.033, 0.31, Vector3(0.145, 0.35, 0.0), skin_mat, Vector3(0.0, 0.0, -0.42))
			var head := MeshInstance3D.new()
			head.name = "Head"
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.105
			head_mesh.height = 0.20
			head_mesh.radial_segments = 8
			head_mesh.rings = 4
			head.mesh = head_mesh
			head.position = Vector3(0.0, 0.63, 0.0)
			head.material_override = skin_mat
			crew.add_child(head)
			_add_crew_headwear(crew, i, uniform_mat, leather_mat)
			_add_crew_role_prop(crew, role, steel_mat, leather_mat)
			if i % 4 == 0:
				_add_cylinder(crew, "Cutlass", 0.015, 0.48, Vector3(0.22, 0.33, 0.0), steel_mat, Vector3(0.0, 0.0, -0.72))
		var team_sash := _add_box(crew, "TeamSash", Vector3(0.075, 0.42, 0.035), Vector3(0.0, 0.39, -0.13), uniform_mat)
		team_sash.rotation.z = -0.58 if team_id == 0 else 0.58
		_crew_nodes.append(crew)
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.34, 0.08, 1.0)
	_boarding_bridge = MeshInstance3D.new()
	_boarding_bridge.name = "BoardingGangway"
	_boarding_bridge.mesh = bridge_mesh
	_boarding_bridge.material_override = _make_material(Color(0.30, 0.18, 0.085), 0.92)
	_boarding_bridge.visible = false
	_visual_root.add_child(_boarding_bridge)
	var boarding_rope_mat := _make_material(Color(0.12, 0.075, 0.035), 0.96)
	var boarding_hook_mat := _make_material(Color(0.16, 0.17, 0.16), 0.48)
	for rope_index in range(3):
		var rope := _add_cylinder(_visual_root, "BoardingGrappleRope", 0.026, 1.0, Vector3.ZERO, boarding_rope_mat, Vector3.ZERO)
		rope.visible = false
		rope.set_meta("rope_index", rope_index)
		_boarding_rope_nodes.append(rope)
		var hook := _add_cylinder(_visual_root, "BoardingGrappleHook", 0.045, 0.42, Vector3.ZERO, boarding_hook_mat, Vector3(0.0, 0.0, PI * 0.5))
		hook.visible = false
		_boarding_hook_nodes.append(hook)


func _get_crew_station_position(role: int, slot: int, count: int) -> Vector3:
	var spread := float(slot) / float(maxi(count - 1, 1))
	match role:
		0:
			return Vector3(-_hull_width * 0.31, _deck_y + 0.14, lerpf(-_hull_length * 0.29, _hull_length * 0.26, spread))
		1:
			return Vector3(_hull_width * 0.31, _deck_y + 0.14, lerpf(-_hull_length * 0.29, _hull_length * 0.26, spread))
		2:
			var mast_z := _mast_nodes[slot % _mast_nodes.size()].position.z if not _mast_nodes.is_empty() else lerpf(-_hull_length * 0.24, _hull_length * 0.24, spread)
			return Vector3((-1.0 if slot % 2 == 0 else 1.0) * _hull_width * 0.10, _deck_y + 0.14, mast_z + (0.42 if slot % 3 == 0 else -0.28))
		3:
			return Vector3((-1.0 if slot % 2 == 0 else 1.0) * _hull_width * 0.16, _deck_y + 0.14, lerpf(-_hull_length * 0.28, _hull_length * 0.24, spread))
		_:
			if slot == 0:
				var raised := 0.0
				if hull_class == "Frigate": raised = 0.32
				elif hull_class == "Ship of the Line": raised = 0.60
				elif hull_class == "Man o' War": raised = 0.79
				return Vector3(0.0, _deck_y + 0.14 + raised, _hull_length * 0.29)
			var station_z := -_hull_length * 0.19 if slot % 2 == 1 else _hull_length * 0.06
			return Vector3((-1.0 if slot % 3 == 0 else 1.0) * _hull_width * 0.12, _deck_y + 0.14, station_z + float(slot) * 0.12)


func _get_crew_station_rotation(role: int, position: Vector3) -> float:
	if role == 0:
		return PI * 0.5
	if role == 1:
		return -PI * 0.5
	if role == 2:
		return PI if position.z > 0.0 else 0.0
	if role == 4 and position.z > _hull_length * 0.20:
		return PI
	return 0.0


func _add_crew_headwear(crew: Node3D, index: int, uniform_mat: Material, leather_mat: Material) -> void:
	match index % 4:
		0:
			_add_cylinder(crew, "HatBrim", 0.15, 0.025, Vector3(0.0, 0.73, 0.0), leather_mat, Vector3.ZERO)
			_add_cylinder(crew, "HatCrown", 0.105, 0.11, Vector3(0.0, 0.78, 0.0), leather_mat, Vector3.ZERO)
		1:
			_add_cylinder(crew, "SailorCap", 0.115, 0.065, Vector3(0.0, 0.75, 0.0), uniform_mat, Vector3.ZERO)
		2:
			_add_box(crew, "Bandana", Vector3(0.22, 0.055, 0.19), Vector3(0.0, 0.71, 0.0), uniform_mat)


func _add_crew_role_prop(crew: Node3D, role: int, steel_mat: Material, leather_mat: Material) -> void:
	match role:
		0, 1:
			_add_cylinder(crew, "Ramrod", 0.012, 0.68, Vector3(0.18 if role == 1 else -0.18, 0.30, 0.0), steel_mat, Vector3(PI * 0.5, 0.0, 0.0))
		2:
			_add_cylinder(crew, "RopeTool", 0.045, 0.36, Vector3(0.18, 0.30, 0.0), leather_mat, Vector3(0.0, 0.0, PI * 0.5))
		3:
			_add_box(crew, "CarriedCrate", Vector3(0.28, 0.22, 0.24), Vector3(0.0, 0.27, -0.20), leather_mat)
		_:
			_add_cylinder(crew, "DeckTool", 0.018, 0.44, Vector3(0.19, 0.28, 0.0), steel_mat, Vector3(0.0, 0.0, -0.62))


func _update_visual_crew(delta: float) -> void:
	var t := _wave_time + _bob_phase
	var local_target := _visual_root.to_local(_boarding_visual_target) if _boarding_visual_active else Vector3.ZERO
	var target_side := signf(local_target.x) if absf(local_target.x) > 0.01 else 1.0
	_crew_broadside_pulse = move_toward(_crew_broadside_pulse, 0.0, delta * 2.35)
	_update_boarding_clash_fx(delta, local_target)
	_update_boarding_grapples(local_target)
	var crew_detail_visible := true
	var active_camera := get_viewport().get_camera_3d()
	if not accepts_player_input and is_instance_valid(active_camera):
		crew_detail_visible = global_position.distance_to(active_camera.global_position) <= 145.0 or _boarding_visual_active
	for crew in _crew_nodes:
		if not is_instance_valid(crew):
			continue
		crew.visible = crew_detail_visible
		var animator := crew.get_meta("asset_animator") as AnimationPlayer if crew.has_meta("asset_animator") else null
		if is_instance_valid(animator):
			animator.process_mode = Node.PROCESS_MODE_INHERIT if crew_detail_visible else Node.PROCESS_MODE_DISABLED
	if not crew_detail_visible:
		return
	if _boarding_bridge:
		_boarding_bridge.visible = _boarding_visual_active and _is_boarding_visual_attacker() and _boarding_visual_progress > 0.12
		if _boarding_bridge.visible:
			var rail_local := Vector3(target_side * _hull_width * 0.46, _deck_y + 0.20, 0.0)
			var rail_global := _visual_root.to_global(rail_local)
			var bridge_target := _boarding_visual_target + Vector3.UP * (_deck_y + 0.18)
			var bridge_length := rail_global.distance_to(bridge_target)
			_boarding_bridge.global_position = rail_global.lerp(bridge_target, 0.5)
			_boarding_bridge.look_at(bridge_target, Vector3.UP, true)
			_boarding_bridge.scale = Vector3(1.0, 1.0, bridge_length)
	for i in range(_crew_nodes.size()):
		var crew := _crew_nodes[i]
		if not is_instance_valid(crew):
			continue
		var state := String(crew.get_meta("crew_state", "active"))
		if state != "active":
			_update_fallen_crew(crew, delta, state)
			continue
		var base: Vector3 = crew.get_meta("base_position", crew.position)
		var base_rotation: Vector3 = crew.get_meta("base_rotation", crew.rotation)
		var phase := float(crew.get_meta("walk_phase", float(i)))
		var desired := _get_crew_patrol_position(crew, base, t, phase)
		var aid_target := crew.get_meta("aid_target") as Node3D if crew.has_meta("aid_target") else null
		var aiding := is_instance_valid(aid_target) and String(aid_target.get_meta("crew_state", "active")) in ["down", "fallen"]
		var response_time := maxf(float(crew.get_meta("response_time", 0.0)) - delta, 0.0)
		crew.set_meta("response_time", response_time)
		if aiding:
			var aid_time := float(crew.get_meta("aid_time", 0.0)) + delta
			crew.set_meta("aid_time", aid_time)
			if aid_time < 1.05:
				desired = aid_target.position + Vector3(0.22 if i % 2 == 0 else -0.22, 0.0, 0.10)
			else:
				var hatch_target := Vector3(0.0, _deck_y + 0.14, 0.10)
				desired = hatch_target
				aid_target.position = aid_target.position.lerp(crew.position + Vector3(0.0, -0.10, 0.18), clampf(delta * 5.0, 0.0, 1.0))
			if aid_time >= 3.4:
				aid_target.set_meta("crew_state", "removed")
				crew.set_meta("aid_target", null)
				crew.set_meta("aid_time", 0.0)
		elif response_time > 0.0:
			desired = crew.get_meta("response_target", desired)
		var fighting := _boarding_visual_active and i < int(ceil(float(_crew_nodes.size()) * 0.82))
		if fighting:
			var rail := Vector3(target_side * _hull_width * 0.43, _deck_y + 0.15, base.z * 0.58)
			desired = base.lerp(rail, clampf(_boarding_visual_progress * 2.2, 0.0, 1.0))
			if _boarding_visual_progress > 0.30:
				var deck_tier := 0.42 if i % 4 == 0 else 0.0
				var target_deck := local_target + Vector3(-target_side * _hull_width * 0.18, _deck_y + 0.15 + deck_tier, base.z * 0.40)
				desired = rail.lerp(target_deck, clampf((_boarding_visual_progress - 0.30) / 0.70, 0.0, 0.82))
			crew.rotation = Vector3(sin(t * 7.0 + i) * 0.12, -target_side * PI * 0.5, sin(t * 9.0 + i) * 0.18)
		else:
			var walking := desired - crew.position
			if Vector2(walking.x, walking.z).length() > 0.015:
				crew.rotation.y = lerp_angle(crew.rotation.y, atan2(walking.x, walking.z), clampf(delta * 5.0, 0.0, 1.0))
			crew.rotation.x = lerp(crew.rotation.x, base_rotation.x, clampf(delta * 5.0, 0.0, 1.0))
			crew.rotation.z = lerp(crew.rotation.z, base_rotation.z, clampf(delta * 5.0, 0.0, 1.0))
			if _crew_broadside_pulse > 0.0:
				var at_firing_rail := signf(base.x) == float(_crew_broadside_side)
				desired.y -= _crew_broadside_pulse * (0.11 if at_firing_rail else 0.05)
				desired.x -= float(_crew_broadside_side) * _crew_broadside_pulse * (0.12 if at_firing_rail else 0.04)
				crew.rotation.z += float(_crew_broadside_side) * _crew_broadside_pulse * (0.34 if at_firing_rail else 0.16)
		var movement := desired - crew.position
		var crew_animation := "Sword" if fighting else ("Walk" if aiding or Vector2(movement.x, movement.z).length() > 0.025 else "Idle")
		if _crew_broadside_pulse > 0.35 and not fighting:
			crew_animation = "Duck"
		_set_crew_asset_animation(crew, crew_animation, 1.12 if fighting else 1.0)
		_animate_crew_limbs(crew, t + phase, fighting or aiding, _crew_broadside_pulse)
		crew.position = crew.position.lerp(desired, clampf(delta * (7.0 if fighting else 4.0), 0.0, 1.0))


func _update_boarding_grapples(local_target: Vector3) -> void:
	var active := _boarding_visual_active and _is_boarding_visual_attacker() and _boarding_visual_progress > 0.025
	var target_side := signf(local_target.x) if absf(local_target.x) > 0.01 else 1.0
	for index in range(_boarding_rope_nodes.size()):
		var rope := _boarding_rope_nodes[index]
		var hook := _boarding_hook_nodes[index] if index < _boarding_hook_nodes.size() else null
		if not is_instance_valid(rope):
			continue
		rope.visible = active
		if is_instance_valid(hook):
			hook.visible = active
		if not active:
			continue
		var z_ratio := -0.26 + float(index) * 0.26
		var start_local := Vector3(target_side * _hull_width * 0.47, _deck_y + 0.34, z_ratio * _hull_length)
		var start_global := _visual_root.to_global(start_local)
		var target_offset := Vector3(0.0, _deck_y + 0.40, z_ratio * _hull_length * 0.72)
		var target_global := _boarding_visual_target + global_transform.basis * target_offset
		var throw_t := smoothstep(0.0, 1.0, clampf((_boarding_visual_progress - 0.025) / 0.13, 0.0, 1.0))
		var end_global := start_global.lerp(target_global, throw_t)
		var direction := end_global - start_global
		var length := maxf(direction.length(), 0.05)
		rope.global_position = start_global.lerp(end_global, 0.5)
		rope.quaternion = Quaternion(Vector3.UP, direction.normalized())
		rope.scale = Vector3(1.0, length, 1.0)
		if is_instance_valid(hook):
			hook.global_position = end_global
			hook.quaternion = Quaternion(Vector3.UP, (direction.normalized() + Vector3.DOWN * 0.35).normalized())


func _get_crew_patrol_position(crew: Node3D, base: Vector3, t: float, phase: float) -> Vector3:
	var role := int(crew.get_meta("crew_role", 0))
	var cycle := t * (0.48 + float(role) * 0.035) + phase
	var desired := base
	match role:
		0, 1:
			desired.x = (-1.0 if role == 0 else 1.0) * _hull_width * 0.27
			desired.z = clampf(base.z + sin(cycle) * _hull_length * 0.075, -_hull_length * 0.31, _hull_length * 0.31)
		2:
			desired.x = sin(cycle * 0.72) * _hull_width * 0.10
			desired.z = clampf(base.z + cos(cycle) * _hull_length * 0.09, -_hull_length * 0.27, _hull_length * 0.27)
		3:
			desired.x = clampf(base.x + sin(cycle * 0.84) * _hull_width * 0.12, -_hull_width * 0.28, _hull_width * 0.28)
			desired.z = sin(cycle * 0.55) * _hull_length * 0.30
		_:
			desired.x = clampf(base.x + sin(cycle) * _hull_width * 0.11, -_hull_width * 0.29, _hull_width * 0.29)
			desired.z = clampf(base.z + cos(cycle * 0.77) * _hull_length * 0.08, -_hull_length * 0.30, _hull_length * 0.30)
	desired.y = base.y + absf(sin(cycle * 3.2)) * 0.022
	return desired


func _animate_crew_limbs(crew: Node3D, cycle: float, fighting: bool, broadside_pulse: float) -> void:
	var leg_l := crew.get_node_or_null("LegL") as Node3D
	var leg_r := crew.get_node_or_null("LegR") as Node3D
	var arm_l := crew.get_node_or_null("ArmL") as Node3D
	var arm_r := crew.get_node_or_null("ArmR") as Node3D
	var stride := sin(cycle * (8.6 if fighting else 5.2))
	var leg_swing := stride * (0.48 if fighting else 0.22)
	var arm_swing := -stride * (0.72 if fighting else 0.26)
	if leg_l:
		leg_l.rotation.x = leg_swing
	if leg_r:
		leg_r.rotation.x = -leg_swing
	if arm_l:
		arm_l.rotation.x = arm_swing
		arm_l.rotation.z = 0.42 + (sin(cycle * 11.0) * 0.28 if fighting else broadside_pulse * 0.36)
	if arm_r:
		arm_r.rotation.x = -arm_swing
		arm_r.rotation.z = -0.42 - (cos(cycle * 10.4) * 0.28 if fighting else broadside_pulse * 0.36)


func _update_fallen_crew(crew: Node3D, delta: float, state: String) -> void:
	if state == "removed":
		crew.visible = false
		return
	var state_time := float(crew.get_meta("crew_state_time", 0.0)) + delta
	crew.set_meta("crew_state_time", state_time)
	var base: Vector3 = crew.get_meta("base_position", crew.position)
	if state == "down":
		_set_crew_asset_animation(crew, "HitReact", 1.1)
		var velocity: Vector3 = crew.get_meta("crew_velocity", Vector3.ZERO)
		velocity.y -= 4.8 * delta
		crew.position += velocity * delta
		crew.rotation.x += delta * (2.5 + absf(velocity.z) * 0.5)
		crew.rotation.z += delta * (2.0 + absf(velocity.x) * 0.7) * signf(velocity.x if absf(velocity.x) > 0.02 else 1.0)
		if crew.position.y <= base.y - 0.11 or state_time > 0.72:
			crew.position.y = base.y - 0.11
			crew.rotation.x = lerp_angle(crew.rotation.x, PI * 0.5, 0.72)
			crew.set_meta("crew_state", "fallen")
			velocity = Vector3.ZERO
		crew.set_meta("crew_velocity", velocity)
	else:
		_set_crew_asset_animation(crew, "Death")
		crew.position.y = base.y - 0.11
		crew.rotation.x = lerp_angle(crew.rotation.x, PI * 0.5, clampf(delta * 6.0, 0.0, 1.0))


func _update_boarding_clash_fx(delta: float, local_target: Vector3) -> void:
	if not _boarding_visual_active or not _is_boarding_visual_attacker() or _boarding_visual_progress < 0.28:
		_boarding_fx_timer = 0.0
		return
	_boarding_fx_timer -= delta
	if _boarding_fx_timer > 0.0:
		return
	_boarding_fx_timer = 0.58 + fmod(float(_crew_nodes.size()) * 0.037, 0.22)
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		var clash_local := local_target.lerp(Vector3(signf(local_target.x) * _hull_width * 0.45, _deck_y + 0.55, 0.0), 0.48)
		CombatFx.spawn_boarding_clash(scene, _visual_root.to_global(clash_local))


func _register_visual_crew_damage(report: Dictionary) -> void:
	if _crew_nodes.is_empty():
		return
	var zone := String(report.get("zone", "hull"))
	var exposure := 0.24
	match zone:
		"deck":
			exposure = 1.0
		"cannons":
			exposure = 0.62
		"sails":
			exposure = 0.16
	var crew_pressure := float(report.get("crew_shock_gain", 0.0)) * float(_crew_nodes.size()) * 0.16 * exposure
	crew_pressure += float(report.get("health_damage", 0.0)) / maxf(max_health, 1.0) * float(_crew_nodes.size()) * 0.24 * exposure
	if bool(report.get("powder_explosion", false)):
		crew_pressure += 1.0
	_crew_loss_accumulator += crew_pressure
	var new_losses := mini(int(floor(_crew_loss_accumulator)), _crew_nodes.size() - _visual_crew_losses)
	if new_losses <= 0:
		return
	var animated_losses := 0
	for loss_index in range(new_losses):
		if _animate_visual_crew_hit(report, false):
			animated_losses += 1
	_crew_loss_accumulator -= float(animated_losses)
	_recount_visual_crew_losses()


func _animate_visual_crew_hit(report: Dictionary, permanent: bool) -> bool:
	var local_hit := Vector3.ZERO
	var hit_position: Vector3 = report.get("hit_position", Vector3.ZERO)
	if hit_position != Vector3.ZERO:
		local_hit = _visual_root.to_local(hit_position)
	else:
		local_hit = Vector3(float(_crew_broadside_side) * _hull_width * 0.25, _deck_y, 0.0)
	var chosen: Node3D = null
	var best_distance := INF
	for crew in _crew_nodes:
		if not is_instance_valid(crew) or String(crew.get_meta("crew_state", "active")) != "active":
			continue
		var distance := Vector2(crew.position.x - local_hit.x, crew.position.z - local_hit.z).length()
		if distance < best_distance:
			best_distance = distance
			chosen = crew
	if chosen == null:
		return false
	var incoming: Vector3 = report.get("incoming_direction", Vector3.ZERO)
	var local_incoming := _visual_root.global_transform.basis.inverse() * incoming.normalized() if incoming.length_squared() > 0.01 else Vector3(signf(local_hit.x), 0.0, 0.0)
	var base: Vector3 = chosen.get_meta("base_position", chosen.position)
	var rail_factor := clampf(absf(base.x) / maxf(_hull_width * 0.28, 0.1), 0.0, 1.0)
	var fore_factor := clampf(absf(base.z) / maxf(_hull_length * 0.31, 0.1), 0.0, 1.0)
	var side_variation := -1.0 if chosen.get_index() % 2 == 0 else 1.0
	var velocity := local_incoming * lerpf(0.55, 1.30, rail_factor)
	velocity += Vector3(side_variation * 0.22 * fore_factor, lerpf(0.82, 1.42, rail_factor), side_variation * 0.30)
	chosen.set_meta("crew_state", "down")
	chosen.set_meta("crew_permanent", permanent)
	chosen.set_meta("crew_velocity", velocity)
	chosen.set_meta("crew_state_time", 0.0)
	_assign_wounded_helper(chosen)
	return true


func _dispatch_crew_to_hit(report: Dictionary) -> void:
	if _crew_nodes.is_empty() or _visual_root == null:
		return
	var hit_position: Vector3 = report.get("hit_position", Vector3.ZERO)
	if hit_position == Vector3.ZERO:
		return
	var local_hit := _visual_root.to_local(hit_position)
	local_hit.x = clampf(local_hit.x, -_hull_width * 0.32, _hull_width * 0.32)
	local_hit.y = _deck_y + 0.14
	local_hit.z = clampf(local_hit.z, -_hull_length * 0.30, _hull_length * 0.30)
	var responders := 1
	if String(report.get("zone", "hull")) in ["deck", "cannons"]:
		responders = 2
	var candidates: Array[Dictionary] = []
	for crew in _crew_nodes:
		if not is_instance_valid(crew) or String(crew.get_meta("crew_state", "active")) != "active":
			continue
		if crew.has_meta("aid_target") and is_instance_valid(crew.get_meta("aid_target")):
			continue
		candidates.append({"crew": crew, "distance": Vector2(crew.position.x - local_hit.x, crew.position.z - local_hit.z).length()})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	for index in range(mini(responders, candidates.size())):
		var responder := candidates[index].crew as Node3D
		responder.set_meta("response_target", local_hit)
		responder.set_meta("response_time", 2.6 + float(index) * 0.35)


func _assign_wounded_helper(wounded: Node3D) -> void:
	if not is_instance_valid(wounded):
		return
	var helper: Node3D = null
	var nearest_distance := INF
	for crew in _crew_nodes:
		if crew == wounded or not is_instance_valid(crew) or String(crew.get_meta("crew_state", "active")) != "active":
			continue
		if crew.has_meta("aid_target") and is_instance_valid(crew.get_meta("aid_target")):
			continue
		var distance := Vector2(crew.position.x - wounded.position.x, crew.position.z - wounded.position.z).length()
		if distance < nearest_distance:
			nearest_distance = distance
			helper = crew
	if helper:
		helper.set_meta("aid_target", wounded)
		helper.set_meta("aid_time", 0.0)


func _recount_visual_crew_losses() -> void:
	_visual_crew_losses = 0
	_permanent_visual_crew_losses = 0
	for crew in _crew_nodes:
		if not is_instance_valid(crew) or String(crew.get_meta("crew_state", "active")) == "active":
			continue
		_visual_crew_losses += 1
		if bool(crew.get_meta("crew_permanent", false)):
			_permanent_visual_crew_losses += 1


func _recover_visual_crew(amount: int) -> void:
	if amount <= 0:
		return
	var recovered := 0
	for crew in _crew_nodes:
		if recovered >= amount:
			break
		if not is_instance_valid(crew) or String(crew.get_meta("crew_state", "active")) == "active" or bool(crew.get_meta("crew_permanent", false)):
			continue
		_reset_visual_crew_node(crew)
		recovered += 1
	_recount_visual_crew_losses()
	_crew_loss_accumulator = minf(_crew_loss_accumulator, 0.35)


func set_boarding_visual(active: bool, target_position: Vector3 = Vector3.ZERO, progress: float = 0.0) -> void:
	var starting := active and not _boarding_visual_active
	_boarding_visual_active = active
	_boarding_visual_target = target_position
	_boarding_visual_progress = clampf(progress, 0.0, 1.0)
	if starting:
		_boarding_fx_timer = 0.12
		if _is_boarding_visual_attacker():
			_play_audio_event("boarding", false, -7.0)
	_update_boarding_flag_visual()


func _is_boarding_visual_attacker() -> bool:
	return bool(get_meta("boarding_visual_attacker", team_id == 0))


func clear_boarding_visual() -> void:
	_boarding_visual_active = false
	_boarding_visual_progress = 0.0
	_boarding_fx_timer = 0.0
	if _boarding_bridge:
		_boarding_bridge.visible = false
	for rope in _boarding_rope_nodes:
		if is_instance_valid(rope):
			rope.visible = false
	for hook in _boarding_hook_nodes:
		if is_instance_valid(hook):
			hook.visible = false
	_update_boarding_flag_visual()


func strike_flag() -> void:
	for flag in _flag_nodes:
		if not is_instance_valid(flag):
			continue
		var base_position: Vector3 = flag.get_meta("base_position", flag.position)
		flag.position = base_position - Vector3.UP * 0.72
		flag.scale = Vector3(1.0, 0.18, 1.0)


func set_captured_flag(capturing_team := 0) -> void:
	_captured_flag = true
	var capture_color := Color(0.12, 0.42, 0.78) if capturing_team == 0 else Color(0.72, 0.16, 0.10)
	var capture_mat := _make_material(capture_color, 0.82)
	capture_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for flag in _flag_nodes:
		if not is_instance_valid(flag):
			continue
		flag.material_override = capture_mat
		flag.position = flag.get_meta("base_position", flag.position)
		flag.scale = Vector3.ONE


func _update_boarding_flag_visual() -> void:
	if _captured_flag:
		return
	var lower_amount := clampf((_boarding_visual_progress - 0.68) / 0.32, 0.0, 1.0) if _boarding_visual_active and not _is_boarding_visual_attacker() else 0.0
	for flag in _flag_nodes:
		if not is_instance_valid(flag):
			continue
		var base_position: Vector3 = flag.get_meta("base_position", flag.position)
		flag.position = base_position - Vector3.UP * lower_amount * 0.72
		flag.scale = Vector3(1.0, lerpf(1.0, 0.18, lower_amount), 1.0)
		flag.material_override = flag.get_meta("base_material", flag.material_override)


func apply_boarding_casualties(casualties: int, roster_size: int) -> void:
	if casualties <= 0 or _crew_nodes.is_empty():
		return
	var represented_losses := maxi(int(round(float(casualties) / float(maxi(roster_size, 1)) * float(_crew_nodes.size()))), 1)
	var report := {
		"hit_position": _boarding_visual_target if _boarding_visual_target != Vector3.ZERO else global_position + Vector3.UP * _deck_y,
		"incoming_direction": (_boarding_visual_target - global_position).normalized(),
	}
	for loss_index in range(mini(represented_losses, _crew_nodes.size() - _visual_crew_losses)):
		_animate_visual_crew_hit(report, true)
	_recount_visual_crew_losses()


func show_boarding_clash_losses(casualties: int, roster_size: int) -> void:
	if casualties <= 0 or _crew_nodes.is_empty():
		return
	var represented_losses := maxi(int(round(float(casualties) / float(maxi(roster_size, 1)) * float(_crew_nodes.size()))), 1)
	var report := {
		"hit_position": _boarding_visual_target if _boarding_visual_target != Vector3.ZERO else global_position + Vector3.UP * _deck_y,
		"incoming_direction": (_boarding_visual_target - global_position).normalized(),
	}
	for loss_index in range(mini(represented_losses, maxi(_crew_nodes.size() - _visual_crew_losses, 0))):
		_animate_visual_crew_hit(report, false)
	_recount_visual_crew_losses()


func _reset_visual_crew_node(crew: Node3D) -> void:
	crew.set_meta("crew_state", "active")
	crew.set_meta("crew_permanent", false)
	crew.set_meta("crew_velocity", Vector3.ZERO)
	crew.set_meta("crew_state_time", 0.0)
	crew.set_meta("aid_target", null)
	crew.set_meta("aid_time", 0.0)
	crew.set_meta("response_time", 0.0)
	crew.position = crew.get_meta("base_position", crew.position)
	crew.rotation = crew.get_meta("base_rotation", crew.rotation)
	crew.visible = true
	_set_crew_asset_animation(crew, "Idle")


func _set_crew_asset_animation(crew: Node3D, animation_name: String, speed: float = 1.0) -> void:
	var animator := crew.get_meta("asset_animator") as AnimationPlayer if crew.has_meta("asset_animator") else null
	if not is_instance_valid(animator) or not animator.has_animation(animation_name):
		return
	var current := String(crew.get_meta("asset_animation", ""))
	if current != animation_name or not animator.is_playing():
		animator.play(animation_name, 0.12, speed)
		crew.set_meta("asset_animation", animation_name)


func _reset_visual_crew_states() -> void:
	for crew in _crew_nodes:
		if is_instance_valid(crew):
			_reset_visual_crew_node(crew)


func _build_broadside_battery_architecture(cannon_y: float, row_spacing: float, dark_mat: Material, trim_mat: Material) -> void:
	var battery_mat := dark_mat.duplicate() as StandardMaterial3D
	battery_mat.albedo_color = Color(0.68, 0.61, 0.52)
	battery_mat.roughness = 0.91
	battery_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wale_mat := trim_mat.duplicate() as StandardMaterial3D
	wale_mat.albedo_color = wale_mat.albedo_color.lerp(Color(0.34, 0.21, 0.09), 0.42)
	wale_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if hull_class == "Frigate":
		battery_mat.albedo_color = Color(0.27, 0.20, 0.15)
		wale_mat.albedo_color = Color(0.55, 0.34, 0.14)
	elif hull_class in ["Ship of the Line", "Man o' War"]:
		battery_mat.albedo_color = Color(0.22, 0.17, 0.13) if hull_class == "Ship of the Line" else Color(0.27, 0.21, 0.16)
		wale_mat.albedo_color = Color(0.53, 0.32, 0.12)
	else:
		battery_mat.albedo_color = Color(0.36, 0.27, 0.20)
	for deck_row in range(_cannon_rows):
		var positions := _get_cannon_positions_for_row(deck_row)
		if positions.is_empty():
			continue
		var row_y := cannon_y - float(deck_row) * row_spacing
		var panel_height := maxf(0.39, row_spacing * 0.80)
		var fore_limit := -_hull_length * (0.46 if hull_class in ["Ship of the Line", "Man o' War"] else (0.43 if hull_class == "Frigate" else 0.40))
		var aft_limit := _hull_length * (0.41 if hull_class in ["Ship of the Line", "Man o' War"] else (0.36 if hull_class == "Frigate" else 0.34))
		var start_z := maxf(positions[0] - _hull_length * 0.035, fore_limit)
		var end_z := minf(positions[positions.size() - 1] + _hull_length * 0.035, aft_limit)
		if hull_class == "Frigate":
			panel_height = 0.34 if deck_row == 0 else 0.38
		for side in [-1, 1]:
			var side_name := "Port" if side < 0 else "Starboard"
			_add_conforming_hull_band("%sBatteryDeck%d" % [side_name, deck_row + 1], side, row_y, panel_height, start_z, end_z, battery_mat, 0.010)
			_add_conforming_hull_band("%sUpperWale%d" % [side_name, deck_row + 1], side, row_y + panel_height * 0.51, 0.045, start_z, end_z, wale_mat, 0.020)
			_add_conforming_hull_band("%sLowerWale%d" % [side_name, deck_row + 1], side, row_y - panel_height * 0.51, 0.040, start_z, end_z, wale_mat, 0.020)


func _add_conforming_hull_band(node_name: String, side: int, center_y: float, band_height: float, start_z: float, end_z: float, material: Material, surface_offset: float) -> MeshInstance3D:
	var band := MeshInstance3D.new()
	band.name = node_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 12
	for index in range(segments):
		var t0 := float(index) / float(segments)
		var t1 := float(index + 1) / float(segments)
		var z0 := lerpf(start_z, end_z, t0)
		var z1 := lerpf(start_z, end_z, t1)
		var y_top := center_y + band_height * 0.5
		var y_bottom := center_y - band_height * 0.5
		var top0 := Vector3(float(side) * (_get_hull_side_surface_x(y_top, z0) + surface_offset), y_top, z0)
		var bottom0 := Vector3(float(side) * (_get_hull_side_surface_x(y_bottom, z0) + surface_offset), y_bottom, z0)
		var top1 := Vector3(float(side) * (_get_hull_side_surface_x(y_top, z1) + surface_offset), y_top, z1)
		var bottom1 := Vector3(float(side) * (_get_hull_side_surface_x(y_bottom, z1) + surface_offset), y_bottom, z1)
		if side > 0:
			_add_tri_uv(st, bottom0, Vector2(t0, 1.0), top1, Vector2(t1, 0.0), top0, Vector2(t0, 0.0))
			_add_tri_uv(st, bottom0, Vector2(t0, 1.0), bottom1, Vector2(t1, 1.0), top1, Vector2(t1, 0.0))
		else:
			_add_tri_uv(st, bottom0, Vector2(t0, 1.0), top0, Vector2(t0, 0.0), top1, Vector2(t1, 0.0))
			_add_tri_uv(st, bottom0, Vector2(t0, 1.0), top1, Vector2(t1, 0.0), bottom1, Vector2(t1, 1.0))
	st.generate_normals()
	band.mesh = st.commit()
	band.material_override = material
	_visual_root.add_child(band)
	return band


func _get_hull_side_surface_x(y: float, z: float) -> float:
	var rings := _get_hull_profile_rings()
	var segment := 0
	for index in range(rings.size() - 1):
		if z >= float(rings[index].z) and z <= float(rings[index + 1].z):
			segment = index
			break
		if z > float(rings[index + 1].z):
			segment = index + 1
	segment = clampi(segment, 0, rings.size() - 2)
	var left: Dictionary = rings[segment]
	var right: Dictionary = rings[segment + 1]
	var z_ratio := inverse_lerp(float(left.z), float(right.z), clampf(z, float(left.z), float(right.z)))
	var ring_half := lerpf(float(left.half), float(right.half), z_ratio)
	var ring_top_scale := lerpf(float(left.get("top_scale", 1.0)), float(right.get("top_scale", 1.0)), z_ratio)
	var ring_chine_scale := lerpf(float(left.get("chine_scale", 0.82)), float(right.get("chine_scale", 0.82)), z_ratio)
	var ring_top := lerpf(float(left.top), float(right.top), z_ratio)
	var ring_chine := lerpf(float(left.chine), float(right.chine), z_ratio)
	var ring_keel := lerpf(float(left.keel), float(right.keel), z_ratio)
	if y >= ring_chine:
		var upper_ratio := clampf(inverse_lerp(ring_chine, ring_top, y), 0.0, 1.0)
		return ring_half * lerpf(ring_chine_scale, ring_top_scale, upper_ratio)
	var lower_ratio := clampf(inverse_lerp(ring_keel, ring_chine, y), 0.0, 1.0)
	return maxf(ring_half * ring_chine_scale * lower_ratio, _hull_width * 0.08)


func _add_cannon_emplacement(side: int, z: float, y: float, metal_mat: Material, carriage_mat: Material, frame_mat: Material, deck_row: int) -> MeshInstance3D:
	var side_name := "Port" if side < 0 else "Starboard"
	var battery_name := "%sDeck%d" % [side_name, deck_row + 1]
	var lower_deck := deck_row > 0
	var hull_surface_x := _get_hull_side_surface_x(y, z)
	var barrel_length := clampf(_hull_width * 0.17, 0.48, 0.86)
	var barrel_radius := 0.075 if hull_class == "Sloop" else (0.125 if hull_class == "Man o' War" else (0.11 if hull_class == "Ship of the Line" else 0.09))
	var port_scale := 1.0
	if hull_class == "Frigate" and deck_row == 0:
		barrel_radius *= 0.82
		port_scale = 0.86
	var exposed_length := 0.20 + barrel_radius * 0.62
	var barrel_x := float(side) * (hull_surface_x + exposed_length - barrel_length * 0.50)
	var barrel := _add_cylinder(_visual_root, "%s%sCannon" % ["Lower" if lower_deck else "", side_name], barrel_radius, barrel_length, Vector3(barrel_x, y, z), metal_mat, Vector3(0.0, 0.0, PI * 0.5))
	barrel.set_meta("base_position", barrel.position)
	barrel.set_meta("base_rotation", barrel.rotation)

	var port_x := float(side) * (hull_surface_x + 0.012)
	var gunport := _add_box(_visual_root, "%sGunportRecess" % battery_name, Vector3(0.052, 0.30 * port_scale, 0.43 * port_scale), Vector3(port_x, y, z), metal_mat)
	var frame_x := float(side) * (hull_surface_x + 0.024)
	var frame_top := _add_box(_visual_root, "%sGunportTop" % battery_name, Vector3(0.055, 0.045, 0.49 * port_scale), Vector3(frame_x, y + 0.175 * port_scale, z), frame_mat)
	var frame_bottom := _add_box(_visual_root, "%sGunportBottom" % battery_name, Vector3(0.055, 0.045, 0.49 * port_scale), Vector3(frame_x, y - 0.175 * port_scale, z), frame_mat)
	var frame_fore := _add_box(_visual_root, "%sGunportFore" % battery_name, Vector3(0.055, 0.31 * port_scale, 0.040), Vector3(frame_x, y, z - 0.245 * port_scale), frame_mat)
	var frame_aft := _add_box(_visual_root, "%sGunportAft" % battery_name, Vector3(0.055, 0.31 * port_scale, 0.040), Vector3(frame_x, y, z + 0.245 * port_scale), frame_mat)
	var cover := _add_box(_visual_root, "%sGunportLid" % battery_name, Vector3(0.060, 0.27 * port_scale, 0.40 * port_scale), Vector3(frame_x + float(side) * 0.015, y, z), carriage_mat)

	var carriage_x := float(side) * (hull_surface_x - 0.42)
	var carriage := _add_box(_visual_root, "%sCarriage" % side_name, Vector3(0.34, 0.13, 0.36), Vector3(carriage_x, y - 0.12, z), carriage_mat)
	for wheel_z in [-0.13, 0.13]:
		_add_cylinder(_visual_root, "%sTruck" % side_name, 0.065, 0.06, Vector3(carriage_x - float(side) * 0.05, y - 0.20, z + wheel_z), metal_mat, Vector3(PI * 0.5, 0.0, 0.0))
	var splinter_mat := _make_material(Color(0.48, 0.28, 0.11), 0.92)
	var splinter_a := _add_box(_visual_root, "%sBrokenGunport" % side_name, Vector3(0.05, 0.07, 0.58), Vector3(frame_x + float(side) * 0.035, y + 0.03, z), splinter_mat)
	var splinter_b := _add_box(_visual_root, "%sBrokenGunport" % side_name, Vector3(0.05, 0.06, 0.44), Vector3(frame_x + float(side) * 0.045, y - 0.04, z), splinter_mat)
	splinter_a.rotation.x = 0.58
	splinter_b.rotation.x = -0.72
	splinter_a.visible = false
	splinter_b.visible = false
	for part in [gunport, frame_top, frame_bottom, frame_fore, frame_aft, carriage, cover]:
		part.set_meta("base_position", part.position)
		part.set_meta("base_rotation", part.rotation)
	var kit_cannon: Node3D = null
	if deck_row == 0:
		kit_cannon = PirateKitAssets.instantiate_prop("cannon")
		if kit_cannon:
			kit_cannon.name = "%sPirateKitCannon" % side_name
			kit_cannon.position = Vector3(float(side) * (hull_surface_x - 0.68), y + 0.04, z)
			kit_cannon.rotation.y = 0.0 if side < 0 else PI
			var cannon_scale := 0.30 if hull_class in ["Sloop", "Brig"] else (0.34 if hull_class == "Frigate" else 0.38)
			kit_cannon.scale = Vector3.ONE * cannon_scale
			kit_cannon.set_meta("base_position", kit_cannon.position)
			_visual_root.add_child(kit_cannon)
	var damage_visual := {
		"door": gunport, "top": frame_top, "bottom": frame_bottom,
		"fore": frame_fore, "aft": frame_aft, "carriage": carriage,
		"cover": cover,
		"barrel": barrel, "side": side, "z": z, "y": y, "deck_row": deck_row,
		"local_damage": 0.0, "disabled": false,
		"splinter_a": splinter_a, "splinter_b": splinter_b,
		"door_material": metal_mat,
		"kit_cannon": kit_cannon,
	}
	if side < 0:
		_port_gunport_visuals.append(damage_visual)
	else:
		_starboard_gunport_visuals.append(damage_visual)
	return barrel


func _build_deck_fittings(deck_mat: Material, trim_mat: Material, dark_mat: Material) -> void:
	_add_box(_visual_root, "MainHatch", Vector3(_hull_width * 0.30, 0.10, _hull_length * 0.12), Vector3(0.0, _deck_y + 0.12, 0.12), dark_mat)
	for rib in [-0.35, 0.0, 0.35]:
		_add_box(_visual_root, "HatchGrating", Vector3(_hull_width * 0.27, 0.035, 0.035), Vector3(0.0, _deck_y + 0.19, 0.12 + rib * _hull_length * 0.10), trim_mat)
	var capstan_z := -_hull_length * 0.19
	_add_cylinder(_visual_root, "Capstan", 0.15 + _hull_width * 0.012, 0.48, Vector3(0.0, _deck_y + 0.28, capstan_z), trim_mat, Vector3.ZERO)
	_add_cylinder(_visual_root, "CapstanHead", 0.24 + _hull_width * 0.01, 0.09, Vector3(0.0, _deck_y + 0.54, capstan_z), dark_mat, Vector3.ZERO)

	var wheel_z := _hull_length * 0.29
	var wheel_y := _deck_y + (0.94 if hull_class == "Man o' War" else (0.82 if hull_class == "Ship of the Line" else 0.64))
	_add_cylinder(_visual_root, "HelmAxle", 0.055, 0.46, Vector3(0.0, wheel_y, wheel_z), dark_mat, Vector3(PI * 0.5, 0.0, 0.0))
	for spoke in range(8):
		var bar := _add_box(_visual_root, "HelmSpoke", Vector3(0.035, 0.62, 0.035), Vector3(0.0, wheel_y, wheel_z - 0.22), trim_mat)
		bar.rotation.z = float(spoke) * PI * 0.25

	var post_count := 6 if hull_class == "Sloop" else (12 if hull_class == "Man o' War" else (10 if hull_class == "Ship of the Line" else 8))
	for index in range(post_count):
		var z := lerpf(-_hull_length * 0.38, _hull_length * 0.38, float(index) / float(maxi(post_count - 1, 1)))
		var post_x := _get_hull_side_surface_x(_deck_y + 0.04, z) * 0.96
		for side in [-1.0, 1.0]:
			_add_box(_visual_root, "RailPost", Vector3(0.075, 0.46, 0.075), Vector3(side * post_x, _deck_y + 0.43, z), trim_mat)

	if hull_class == "Frigate":
		_add_tapered_box(_visual_root, "FrigateLaunchHull", _hull_width * 0.15, _hull_width * 0.24, 0.18, -_hull_length * 0.015, _hull_length * 0.125, _deck_y + 0.23, dark_mat)
		_add_tapered_box(_visual_root, "FrigateLaunchInterior", _hull_width * 0.10, _hull_width * 0.18, 0.060, -_hull_length * 0.005, _hull_length * 0.115, _deck_y + 0.33, deck_mat)
		for seat_z in [-0.015, 0.035, 0.085]:
			_add_box(_visual_root, "FrigateLaunchSeat", Vector3(_hull_width * 0.19, 0.028, 0.07), Vector3(0.0, _deck_y + 0.38, _hull_length * float(seat_z)), trim_mat)
	elif hull_class != "Sloop":
		_add_box(_visual_root, "Longboat", Vector3(_hull_width * 0.34, 0.28, _hull_length * 0.20), Vector3(0.0, _deck_y + 0.31, _hull_length * 0.06), deck_mat)


func _build_class_superstructure(wood_mat: Material, deck_mat: Material, trim_mat: Material) -> void:
	var stern_z := _hull_length * 0.34
	match hull_class:
		"Sloop":
			_add_box(_visual_root, "LowCabin", Vector3(_hull_width * 0.55, 0.42, _hull_length * 0.16), Vector3(0.0, _deck_y + 0.28, stern_z), wood_mat)
			_add_cylinder(_visual_root, "Tiller", 0.035, 1.15, Vector3(0.0, _deck_y + 0.48, stern_z - 0.35), trim_mat, Vector3(PI * 0.5, 0.0, 0.0))
		"Frigate":
			_add_tapered_box(_visual_root, "FrigateForecastle", _hull_width * 0.50, _hull_width * 0.76, 0.16, -_hull_length * 0.53, -_hull_length * 0.27, _deck_y + 0.19, deck_mat)
			_add_tapered_box(_visual_root, "FrigateQuarterdeck", _hull_width * 0.78, _hull_width * 0.64, 0.20, _hull_length * 0.17, _hull_length * 0.505, _deck_y + 0.27, deck_mat)
			_add_tapered_box(_visual_root, "FrigateSternCabin", _hull_width * 0.68, _hull_width * 0.55, 0.62, _hull_length * 0.32, _hull_length * 0.505, _deck_y + 0.49, wood_mat)
			_add_tapered_box(_visual_root, "FrigateSternRoof", _hull_width * 0.74, _hull_width * 0.62, 0.09, _hull_length * 0.31, _hull_length * 0.515, _deck_y + 0.85, deck_mat)
			_build_frigate_architecture(wood_mat, deck_mat, trim_mat)
		"Ship of the Line":
			_add_box(_visual_root, "Quarterdeck", Vector3(_hull_width * 0.84, 0.24, _hull_length * 0.30), Vector3(0.0, _deck_y + 0.48, stern_z), deck_mat)
			_add_box(_visual_root, "Forecastle", Vector3(_hull_width * 0.76, 0.22, _hull_length * 0.20), Vector3(0.0, _deck_y + 0.38, -_hull_length * 0.32), deck_mat)
			_add_box(_visual_root, "GrandStern", Vector3(_hull_width * 0.78, 1.18, _hull_length * 0.18), Vector3(0.0, _deck_y + 0.82, stern_z + 0.36), wood_mat)
			_add_box(_visual_root, "GrandSternRoof", Vector3(_hull_width * 0.86, 0.16, _hull_length * 0.21), Vector3(0.0, _deck_y + 1.45, stern_z + 0.34), deck_mat)
			_add_stern_windows(stern_z, trim_mat)
			_build_mortar_mount(trim_mat, wood_mat)
		"Man o' War":
			_build_man_o_war_architecture(wood_mat, deck_mat, trim_mat)
		_:
			_add_box(_visual_root, "SternCabin", Vector3(_hull_width * 0.64, 0.72, _hull_length * 0.16), Vector3(0.0, _deck_y + 0.48, stern_z), wood_mat)
			_add_box(_visual_root, "CabinRoof", Vector3(_hull_width * 0.72, 0.14, _hull_length * 0.19), Vector3(0.0, _deck_y + 0.90, stern_z), trim_mat)


func _add_stern_windows(stern_z: float, trim_mat: Material) -> void:
	var glass := _make_emissive_material(Color(0.14, 0.22, 0.24), Color(0.68, 0.54, 0.20), 0.42)
	for x in [-1.35, -0.68, 0.0, 0.68, 1.35]:
		var scaled_x: float = float(x) * (_hull_width / 5.05)
		_add_box(_visual_root, "SternWindow", Vector3(0.38, 0.30, 0.06), Vector3(scaled_x, _deck_y + 0.91, stern_z + _hull_length * 0.098), glass)
	_add_box(_visual_root, "SternGallery", Vector3(_hull_width * 0.86, 0.10, 0.24), Vector3(0.0, _deck_y + 0.55, stern_z + _hull_length * 0.105), trim_mat)


func _build_frigate_architecture(wood_mat: Material, deck_mat: Material, trim_mat: Material) -> void:
	var glass := _make_emissive_material(Color(0.085, 0.13, 0.15), Color(0.30, 0.24, 0.10), 0.18)
	var transom_mat := _make_textured_material(
		Color(0.58, 0.46, 0.34),
		0.92,
		DarkPlanksAlbedo,
		DarkPlanksNormal,
		DarkPlanksRoughness,
		DarkPlanksAO,
		Vector2(1.35, 0.72),
		0.20
	)
	var transom_z := _hull_length * 0.505
	_add_vertical_trapezoid(_visual_root, "FrigateLowerTransom", _hull_width * 0.47, _hull_width * 0.60, _hull_depth * 0.63, 0.075, Vector3(0.0, _deck_y - _hull_depth * 0.30, transom_z + 0.012), transom_mat)
	for band_y in [_deck_y - _hull_depth * 0.53, _deck_y - _hull_depth * 0.15]:
		_add_box(_visual_root, "FrigateTransomBand", Vector3(_hull_width * 0.62, 0.065, 0.09), Vector3(0.0, float(band_y), transom_z + 0.025), trim_mat)
	for window_index in range(5):
		var x := lerpf(-_hull_width * 0.25, _hull_width * 0.25, float(window_index) / 4.0)
		_add_box(_visual_root, "FrigateSternWindow", Vector3(_hull_width * 0.105, 0.30, 0.045), Vector3(x, _deck_y + 0.63, transom_z), glass)
	_add_box(_visual_root, "FrigateTransomRail", Vector3(_hull_width * 0.69, 0.08, 0.08), Vector3(0.0, _deck_y + 0.94, transom_z + 0.015), trim_mat)
	_add_box(_visual_root, "FrigateGallery", Vector3(_hull_width * 0.72, 0.10, 0.27), Vector3(0.0, _deck_y + 0.39, transom_z), trim_mat)
	var cabin_front_z := _hull_length * 0.295
	_add_box(_visual_root, "FrigateCabinFront", Vector3(_hull_width * 0.66, 0.58, 0.065), Vector3(0.0, _deck_y + 0.60, cabin_front_z), wood_mat)
	_add_box(_visual_root, "FrigateCabinDoor", Vector3(0.50, 0.48, 0.075), Vector3(0.0, _deck_y + 0.54, cabin_front_z - 0.012), trim_mat)
	for side in [-1.0, 1.0]:
		_add_box(_visual_root, "FrigateCabinFrontWindow", Vector3(0.42, 0.27, 0.078), Vector3(float(side) * _hull_width * 0.20, _deck_y + 0.65, cabin_front_z - 0.014), glass)
	for side in [-1.0, 1.0]:
		var side_x := float(side) * _hull_width * 0.375
		_add_tapered_box(_visual_root, "FrigateQuarterGallery", 0.22, 0.15, 0.42, _hull_length * 0.31, _hull_length * 0.49, _deck_y + 0.53, wood_mat, side_x)
		_add_box(_visual_root, "FrigateGalleryRail", Vector3(0.075, 0.10, _hull_length * 0.22), Vector3(float(side) * _hull_width * 0.405, _deck_y + 0.94, _hull_length * 0.40), trim_mat)
		for post_index in range(4):
			var post_z := lerpf(_hull_length * 0.31, _hull_length * 0.49, float(post_index) / 3.0)
			_add_box(_visual_root, "FrigateGalleryPost", Vector3(0.055, 0.34, 0.055), Vector3(float(side) * _hull_width * 0.405, _deck_y + 0.76, post_z), trim_mat)
		for step_index in range(4):
			var ratio := float(step_index) / 3.0
			_add_box(_visual_root, "FrigateQuarterdeckStep", Vector3(_hull_width * 0.15, 0.07, 0.28), Vector3(float(side) * _hull_width * 0.22, _deck_y + 0.13 + ratio * 0.20, _hull_length * (0.13 + ratio * 0.055)), deck_mat)
	var beak_z := -_hull_length * 0.505
	_add_tapered_box(_visual_root, "FrigateBeakhead", _hull_width * 0.42, _hull_width * 0.14, 0.10, -_hull_length * 0.48, -_hull_length * 0.61, _deck_y + 0.12, deck_mat)
	for side in [-1.0, 1.0]:
		_add_spar_between("FrigateHeadRail", Vector3(float(side) * _hull_width * 0.37, _deck_y + 0.34, -_hull_length * 0.44), Vector3(float(side) * _hull_width * 0.08, _deck_y + 0.25, -_hull_length * 0.64), 0.035, trim_mat)
		_add_spar_between("FrigateHeadKnee", Vector3(float(side) * _hull_width * 0.29, _deck_y - 0.02, -_hull_length * 0.47), Vector3(float(side) * _hull_width * 0.05, _deck_y - 0.18, -_hull_length * 0.60), 0.045, trim_mat)
	_add_cylinder(_visual_root, "FrigateFigurehead", 0.10, 0.72, Vector3(0.0, _deck_y - 0.05, -_hull_length * 0.59), trim_mat, Vector3(PI * 0.42, 0.0, 0.0))


func _build_man_o_war_architecture(wood_mat: Material, deck_mat: Material, trim_mat: Material) -> void:
	var glass := _make_emissive_material(Color(0.075, 0.12, 0.14), Color(0.28, 0.21, 0.08), 0.24)
	var transom_mat := _make_textured_material(
		Color(0.43, 0.32, 0.23),
		0.91,
		DarkPlanksAlbedo,
		DarkPlanksNormal,
		DarkPlanksRoughness,
		DarkPlanksAO,
		Vector2(1.55, 0.78),
		0.20
	)
	var stern_z := _hull_length * 0.505

	# Broad decks stay low and follow the narrowing hull instead of forming
	# rectangular slabs over it.
	_add_tapered_box(_visual_root, "WarForecastle", _hull_width * 0.42, _hull_width * 0.76, 0.15, -_hull_length * 0.56, -_hull_length * 0.29, _deck_y + 0.18, deck_mat)
	_add_tapered_box(_visual_root, "WarQuarterdeck", _hull_width * 0.84, _hull_width * 0.66, 0.17, _hull_length * 0.14, _hull_length * 0.51, _deck_y + 0.25, deck_mat)

	# Two stepped cabins produce a rising stern silhouette without the former
	# single-storey block. Each tier becomes narrower toward the transom.
	_add_tapered_box(_visual_root, "WarLowerCabin", _hull_width * 0.77, _hull_width * 0.61, 0.58, _hull_length * 0.29, _hull_length * 0.505, _deck_y + 0.53, wood_mat)
	_add_tapered_box(_visual_root, "WarUpperCabin", _hull_width * 0.63, _hull_width * 0.49, 0.46, _hull_length * 0.37, _hull_length * 0.505, _deck_y + 0.99, wood_mat)
	_add_tapered_box(_visual_root, "WarPoopDeck", _hull_width * 0.67, _hull_width * 0.53, 0.09, _hull_length * 0.35, _hull_length * 0.515, _deck_y + 1.25, deck_mat)

	_add_vertical_trapezoid(_visual_root, "WarTransom", _hull_width * 0.58, _hull_width * 0.46, 1.34, 0.075, Vector3(0.0, _deck_y + 0.54, stern_z + 0.018), transom_mat)
	for tier in range(2):
		var window_y := _deck_y + 0.35 + float(tier) * 0.48
		var tier_half_width := _hull_width * (0.235 if tier == 0 else 0.19)
		for window_index in range(6):
			var x := lerpf(-tier_half_width, tier_half_width, float(window_index) / 5.0)
			_add_box(_visual_root, "WarSternWindow", Vector3(_hull_width * 0.070, 0.25, 0.045), Vector3(x, window_y, stern_z + 0.065), glass)
	_add_box(_visual_root, "WarTransomCrown", Vector3(_hull_width * 0.54, 0.075, 0.10), Vector3(0.0, _deck_y + 1.23, stern_z + 0.075), trim_mat)
	_add_box(_visual_root, "WarSternGallery", Vector3(_hull_width * 0.68, 0.10, 0.30), Vector3(0.0, _deck_y + 0.20, stern_z + 0.01), trim_mat)

	for side in [-1.0, 1.0]:
		var side_x := float(side) * _hull_width * 0.405
		_add_tapered_box(_visual_root, "WarQuarterGallery", 0.26, 0.16, 0.50, _hull_length * 0.32, _hull_length * 0.50, _deck_y + 0.56, wood_mat, side_x)
		_add_box(_visual_root, "WarGalleryRail", Vector3(0.075, 0.10, _hull_length * 0.21), Vector3(float(side) * _hull_width * 0.435, _deck_y + 0.94, _hull_length * 0.41), trim_mat)
		for post_index in range(5):
			var post_z := lerpf(_hull_length * 0.32, _hull_length * 0.50, float(post_index) / 4.0)
			_add_box(_visual_root, "WarGalleryPost", Vector3(0.055, 0.34, 0.055), Vector3(float(side) * _hull_width * 0.435, _deck_y + 0.76, post_z), trim_mat)
		for step_index in range(5):
			var ratio := float(step_index) / 4.0
			_add_box(_visual_root, "WarQuarterdeckStep", Vector3(_hull_width * 0.14, 0.07, 0.30), Vector3(float(side) * _hull_width * 0.22, _deck_y + 0.12 + ratio * 0.24, _hull_length * (0.10 + ratio * 0.045)), deck_mat)

	# A long beakhead visually carries the bow forward and balances the stern.
	_add_tapered_box(_visual_root, "WarBeakhead", _hull_width * 0.44, _hull_width * 0.10, 0.11, -_hull_length * 0.49, -_hull_length * 0.66, _deck_y + 0.13, deck_mat)
	for side in [-1.0, 1.0]:
		_add_spar_between("WarHeadRail", Vector3(float(side) * _hull_width * 0.36, _deck_y + 0.37, -_hull_length * 0.43), Vector3(float(side) * _hull_width * 0.07, _deck_y + 0.25, -_hull_length * 0.67), 0.042, trim_mat)
		_add_spar_between("WarHeadKnee", Vector3(float(side) * _hull_width * 0.28, _deck_y - 0.03, -_hull_length * 0.48), Vector3(float(side) * _hull_width * 0.04, _deck_y - 0.23, -_hull_length * 0.64), 0.050, trim_mat)
	_add_cylinder(_visual_root, "WarFigurehead", 0.12, 0.92, Vector3(0.0, _deck_y - 0.07, -_hull_length * 0.63), trim_mat, Vector3(PI * 0.42, 0.0, 0.0))

	for grate_x in [-0.72, 0.72]:
		_add_box(_visual_root, "WarGunDeckGrate", Vector3(_hull_width * 0.15, 0.050, _hull_length * 0.085), Vector3(float(grate_x), _deck_y + 0.12, -_hull_length * 0.04), trim_mat)
	_build_mortar_mount(trim_mat, wood_mat)


func _build_mortar_mount(trim_mat: Material, wood_mat: Material) -> void:
	var mortar_z := _hull_length * 0.035 if hull_class == "Man o' War" else -_hull_length * 0.12
	var shell_count := get_mortar_shell_count()
	var bed_width := 2.15 if shell_count == 4 else 1.55
	_add_box(_visual_root, "MortarBed", Vector3(bed_width, 0.22, 1.38), Vector3(0.0, _deck_y + 0.34, mortar_z), wood_mat)
	var mortar_mat := _make_textured_material(
		Color(0.48, 0.46, 0.42),
		0.66,
		RustyMetalAlbedo,
		RustyMetalNormal,
		RustyMetalRoughness,
		RustyMetalAO,
		Vector2(1.4, 1.4),
		0.30
	)
	mortar_mat.metallic = 0.62
	for index in range(shell_count):
		var tube_x := (float(index) - float(shell_count - 1) * 0.5) * 0.42
		var tube := _add_cylinder(_visual_root, "HeavyMortar%d" % index, 0.22, 0.86, Vector3(tube_x, _deck_y + 0.77, mortar_z), mortar_mat, Vector3(deg_to_rad(28.0), 0.0, 0.0))
		tube.set_meta("mortar_muzzle", true)
	_add_cylinder(_visual_root, "MortarTrunnion", 0.10, 1.12, Vector3(0.0, _deck_y + 0.60, mortar_z), trim_mat, Vector3(0.0, 0.0, PI * 0.5))


func _build_class_rig(cloth_mat: Material, trim_mat: Material, flag_mat: Material) -> void:
	match hull_class:
		"Sloop":
			var mast_pos := Vector3(0.0, _deck_y, -0.35)
			_add_mast(_visual_root, mast_pos, 5.15, 2.55, cloth_mat, trim_mat, flag_mat)
			_add_cylinder(_visual_root, "LongBoom", 0.045, 3.5, Vector3(0.0, _deck_y + 2.15, 1.15), trim_mat, Vector3(PI * 0.5, 0.0, 0.0))
			_add_jib_sail(Vector3(0.03, _deck_y + 0.35, -_hull_length * 0.60), mast_pos + Vector3(0.03, 3.9, 0.0), mast_pos + Vector3(0.03, 0.65, 0.0), cloth_mat, "SloopJib")
		"Frigate":
			var fore := _add_mast_with_topsail(Vector3(0.0, _deck_y + 0.05, -_hull_length * 0.25), 6.90, 3.15, cloth_mat, trim_mat, flag_mat)
			var main := _add_mast_with_topsail(Vector3(0.0, _deck_y + 0.02, 0.01), 7.65, 3.55, cloth_mat, trim_mat, null)
			var mizzen := _add_mast(_visual_root, Vector3(0.0, _deck_y + 0.24, _hull_length * 0.27), 5.90, 2.30, cloth_mat, trim_mat, null)
			_add_topgallant_sail(fore, 6.90, 3.15, cloth_mat, trim_mat)
			_add_topgallant_sail(main, 7.65, 3.55, cloth_mat, trim_mat)
			_add_spanker_sail(mizzen, 5.90, 1.90, cloth_mat, trim_mat)
			_add_jib_sail(Vector3(0.03, _deck_y + 0.44, -_hull_length * 0.66), Vector3(0.03, _deck_y + 5.20, -_hull_length * 0.25), Vector3(0.03, _deck_y + 0.82, -_hull_length * 0.25), cloth_mat, "FlyingJib")
			_add_jib_sail(Vector3(0.04, _deck_y + 0.66, -_hull_length * 0.54), Vector3(0.04, _deck_y + 3.65, -_hull_length * 0.25), Vector3(0.04, _deck_y + 1.08, -_hull_length * 0.24), cloth_mat, "InnerJib")
		"Ship of the Line":
			_add_mast_with_topsail(Vector3(0.0, _deck_y + 0.20, -_hull_length * 0.25), 8.3, 4.35, cloth_mat, trim_mat, flag_mat)
			_add_mast_with_topsail(Vector3(0.0, _deck_y + 0.20, 0.0), 9.15, 4.75, cloth_mat, trim_mat, null)
			_add_mast_with_topsail(Vector3(0.0, _deck_y + 0.20, _hull_length * 0.24), 7.45, 3.65, cloth_mat, trim_mat, null)
			_add_jib_sail(Vector3(0.03, _deck_y + 0.48, -_hull_length * 0.64), Vector3(0.03, _deck_y + 6.8, -_hull_length * 0.25), Vector3(0.03, _deck_y + 0.82, -_hull_length * 0.22), cloth_mat, "GrandJib")
		"Man o' War":
			var fore := _add_mast_with_topsail(Vector3(0.0, _deck_y + 0.18, -_hull_length * 0.26), 9.55, 4.70, cloth_mat, trim_mat, flag_mat)
			var main := _add_mast_with_topsail(Vector3(0.0, _deck_y + 0.16, -_hull_length * 0.01), 10.65, 5.30, cloth_mat, trim_mat, null)
			var mizzen := _add_mast_with_topsail(Vector3(0.0, _deck_y + 0.30, _hull_length * 0.25), 8.55, 3.85, cloth_mat, trim_mat, null)
			_add_topgallant_sail(fore, 9.55, 4.70, cloth_mat, trim_mat)
			_add_topgallant_sail(main, 10.65, 5.30, cloth_mat, trim_mat)
			_add_spanker_sail(mizzen, 8.55, 2.75, cloth_mat, trim_mat)
			_add_jib_sail(Vector3(0.03, _deck_y + 0.50, -_hull_length * 0.68), Vector3(0.03, _deck_y + 7.25, -_hull_length * 0.26), Vector3(0.03, _deck_y + 0.88, -_hull_length * 0.24), cloth_mat, "WarFlyingJib")
			_add_jib_sail(Vector3(0.04, _deck_y + 0.66, -_hull_length * 0.56), Vector3(0.04, _deck_y + 5.05, -_hull_length * 0.26), Vector3(0.04, _deck_y + 1.12, -_hull_length * 0.23), cloth_mat, "WarInnerJib")
		_:
			_add_mast(_visual_root, Vector3(0.0, _deck_y, -_hull_length * 0.19), 5.45, 2.8, cloth_mat, trim_mat, flag_mat)
			_add_mast(_visual_root, Vector3(0.0, _deck_y, _hull_length * 0.19), 4.65, 2.2, cloth_mat, trim_mat, null)


func _add_mast_with_topsail(base_pos: Vector3, height: float, sail_width: float, cloth_mat: Material, trim_mat: Material, flag_mat: Material) -> Node3D:
	var mast_root := _add_mast(_visual_root, base_pos, height, sail_width, cloth_mat, trim_mat, flag_mat)
	var top_sail := MeshInstance3D.new()
	top_sail.name = "TopSail"
	top_sail.mesh = _create_billowed_sail_mesh(sail_width * 0.72, height * 0.23, 0.72, sail_width * 0.055)
	top_sail.position = Vector3(0.0, height * 0.87, 0.035)
	top_sail.material_override = cloth_mat
	mast_root.add_child(top_sail)
	_sail_nodes.append(top_sail)
	var top_roll := _add_cylinder(mast_root, "FurledTopSail", 0.075 + sail_width * 0.010, sail_width * 0.76, Vector3(0.0, height * 0.88, 0.035), cloth_mat, Vector3(0.0, 0.0, PI * 0.5))
	top_roll.visible = false
	top_sail.set_meta("furled_roll", top_roll)
	_add_sail_detail_bands(mast_root, height, sail_width, trim_mat, true)
	return mast_root


func _add_topgallant_sail(mast_root: Node3D, height: float, sail_width: float, cloth_mat: Material, trim_mat: Material) -> void:
	if mast_root == null:
		return
	_add_cylinder(mast_root, "TopgallantSpar", 0.032, sail_width * 0.62, Vector3(0.0, height * 1.035, 0.0), trim_mat, Vector3(0.0, 0.0, PI * 0.5))
	var sail := MeshInstance3D.new()
	sail.name = "TopgallantSail"
	sail.mesh = _create_billowed_sail_mesh(sail_width * 0.54, height * 0.17, 0.68, sail_width * 0.04)
	sail.position = Vector3(0.0, height * 0.965, 0.03)
	sail.material_override = cloth_mat
	mast_root.add_child(sail)
	_sail_nodes.append(sail)
	var roll := _add_cylinder(mast_root, "FurledTopgallant", 0.06, sail_width * 0.56, Vector3(0.0, height * 1.035, 0.035), cloth_mat, Vector3(0.0, 0.0, PI * 0.5))
	roll.visible = false
	sail.set_meta("furled_roll", roll)


func _add_spanker_sail(mast_root: Node3D, height: float, width: float, cloth_mat: Material, trim_mat: Material) -> void:
	if mast_root == null:
		return
	var boom_center := Vector3(0.0, height * 0.34, width * 0.34)
	_add_cylinder(mast_root, "SpankerBoom", 0.04, width * 1.18, boom_center, trim_mat, Vector3(PI * 0.5, 0.0, 0.0))
	_add_jib_sail(
		mast_root.position + Vector3(0.04, height * 0.35, 0.18),
		mast_root.position + Vector3(0.04, height * 0.77, 0.05),
		mast_root.position + Vector3(0.04, height * 0.35, width * 0.78),
		cloth_mat,
		"FrigateSpanker"
	)


func _add_mast(parent: Node3D, base_pos: Vector3, height: float, sail_width: float, cloth_mat: Material, trim_mat: Material, flag_mat: Material) -> Node3D:
	var mast_root := Node3D.new()
	mast_root.name = "RigMast"
	mast_root.position = base_pos
	mast_root.set_meta("rig_height", height)
	mast_root.set_meta("sail_width", sail_width)
	parent.add_child(mast_root)
	_mast_nodes.append(mast_root)
	_add_cylinder(mast_root, "Mast", 0.07 + height * 0.0025, height, Vector3(0.0, height * 0.5, 0.0), trim_mat, Vector3.ZERO)
	_add_cylinder(mast_root, "LowerSpar", 0.045, sail_width + 0.45, Vector3(0.0, height * 0.58, 0.0), trim_mat, Vector3(0.0, 0.0, PI * 0.5))
	_add_cylinder(mast_root, "UpperSpar", 0.04, sail_width, Vector3(0.0, height * 0.88, 0.0), trim_mat, Vector3(0.0, 0.0, PI * 0.5))

	var sail := MeshInstance3D.new()
	sail.name = "CourseSail"
	sail.mesh = _create_billowed_sail_mesh(sail_width, height * 0.42, 0.82, sail_width * 0.075)
	sail.position = Vector3(0.0, height * 0.68, 0.03)
	sail.material_override = cloth_mat
	mast_root.add_child(sail)
	_sail_nodes.append(sail)
	var course_roll := _add_cylinder(mast_root, "FurledCourseSail", 0.09 + sail_width * 0.012, sail_width * 0.96, Vector3(0.0, height * 0.58, 0.035), cloth_mat, Vector3(0.0, 0.0, PI * 0.5))
	course_roll.visible = false
	sail.set_meta("furled_roll", course_roll)
	_add_sail_detail_bands(mast_root, height, sail_width, trim_mat, false)

	if flag_mat:
		var flag := MeshInstance3D.new()
		var flag_mesh := QuadMesh.new()
		flag_mesh.size = Vector2(0.8, 0.42)
		flag.mesh = flag_mesh
		flag.position = Vector3(0.42, height + 0.1, 0.0)
		flag.material_override = flag_mat
		mast_root.add_child(flag)
		flag.set_meta("base_position", flag.position)
		flag.set_meta("base_material", flag_mat)
		_flag_nodes.append(flag)
	return mast_root


func _add_sail_detail_bands(mast_root: Node3D, height: float, sail_width: float, trim_mat: Material, upper: bool) -> void:
	var rope_mat := _make_textured_material(
		Color(0.54, 0.43, 0.28),
		0.96,
		RopeAlbedo,
		RopeNormal,
		RopeRoughness,
		null,
		Vector2(3.0, 1.0),
		0.20
	)
	var center_y := height * (0.87 if upper else 0.68)
	var band_width := sail_width * (0.68 if upper else 0.92)
	for offset in [-0.11, 0.10]:
		_add_box(mast_root, "SailReefBand", Vector3(band_width, 0.028, 0.028), Vector3(0.0, center_y + height * float(offset), 0.085), rope_mat)
	if not upper:
		for seam_x in [-0.24, 0.24]:
			_add_box(mast_root, "SailVerticalSeam", Vector3(0.018, height * 0.34, 0.025), Vector3(sail_width * float(seam_x), center_y, 0.08), rope_mat)


func _create_billowed_sail_mesh(width: float, height: float, top_ratio: float, billow: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 5
	var rows := 4
	for row in range(rows):
		var v0 := float(row) / float(rows)
		var v1 := float(row + 1) / float(rows)
		for column in range(columns):
			var u0 := float(column) / float(columns)
			var u1 := float(column + 1) / float(columns)
			var p00 := _sail_mesh_point(u0, v0, width, height, top_ratio, billow)
			var p10 := _sail_mesh_point(u1, v0, width, height, top_ratio, billow)
			var p11 := _sail_mesh_point(u1, v1, width, height, top_ratio, billow)
			var p01 := _sail_mesh_point(u0, v1, width, height, top_ratio, billow)
			_add_tri_uv(st, p00, Vector2(u0, 1.0 - v0), p10, Vector2(u1, 1.0 - v0), p11, Vector2(u1, 1.0 - v1))
			_add_tri_uv(st, p00, Vector2(u0, 1.0 - v0), p11, Vector2(u1, 1.0 - v1), p01, Vector2(u0, 1.0 - v1))
	st.generate_normals()
	return st.commit()


func _sail_mesh_point(u: float, v: float, width: float, height: float, top_ratio: float, billow: float) -> Vector3:
	var row_width := lerpf(width, width * top_ratio, v)
	var x := (u - 0.5) * row_width
	var y := (v - 0.5) * height
	var z := sin(u * PI) * sin(v * PI) * billow
	return Vector3(x, y, z)


func _add_jib_sail(a: Vector3, b: Vector3, c: Vector3, cloth_mat: Material, node_name: String) -> void:
	var center := (a + b + c) / 3.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tri_uv(st, a - center, Vector2(0.0, 1.0), b - center, Vector2(0.5, 0.0), c - center, Vector2(1.0, 1.0))
	st.generate_normals()
	var jib := MeshInstance3D.new()
	jib.name = node_name
	jib.mesh = st.commit()
	jib.position = center
	jib.material_override = cloth_mat
	_visual_root.add_child(jib)
	_sail_nodes.append(jib)
	var stay_direction := b - a
	var jib_roll := _add_cylinder(_visual_root, "%sFurled" % node_name, 0.065, stay_direction.length() * 0.92, a.lerp(b, 0.5), cloth_mat, Vector3.ZERO)
	if stay_direction.length_squared() > 0.001:
		jib_roll.quaternion = Quaternion(Vector3.UP, stay_direction.normalized())
	jib_roll.visible = false
	jib.set_meta("furled_roll", jib_roll)


func _build_standing_rigging() -> void:
	if _mast_nodes.is_empty():
		return
	var rope_mat := _make_material(Color(0.075, 0.052, 0.032), 0.96)
	var previous_top := Vector3.ZERO
	for index in range(_mast_nodes.size()):
		var mast := _mast_nodes[index]
		var height := float(mast.get_meta("rig_height", 5.0))
		var top := mast.position + Vector3.UP * height * 0.93
		var deck_z := mast.position.z + height * 0.08
		_add_rope_between(top, Vector3(-_hull_width * 0.43, _deck_y + 0.28, deck_z), rope_mat)
		_add_rope_between(top, Vector3(_hull_width * 0.43, _deck_y + 0.28, deck_z), rope_mat)
		if hull_class == "Frigate":
			_build_frigate_shrouds(mast, height, rope_mat)
		if index > 0:
			_add_rope_between(previous_top, top, rope_mat)
		previous_top = top
	var first := _mast_nodes[0]
	var first_top := first.position + Vector3.UP * float(first.get_meta("rig_height", 5.0)) * 0.91
	var last := _mast_nodes[_mast_nodes.size() - 1]
	var last_top := last.position + Vector3.UP * float(last.get_meta("rig_height", 5.0)) * 0.88
	_add_rope_between(first_top, Vector3(0.0, _deck_y + 0.28, -_hull_length * 0.62), rope_mat)
	_add_rope_between(last_top, Vector3(0.0, _deck_y + 0.36, _hull_length * 0.48), rope_mat)


func _build_frigate_shrouds(mast: Node3D, height: float, rope_mat: Material) -> void:
	var shroud_top := mast.position + Vector3.UP * height * 0.73
	var z_span := 0.58 if height > 7.0 else 0.46
	for side in [-1.0, 1.0]:
		var fore_anchor := Vector3(float(side) * _hull_width * 0.43, _deck_y + 0.24, mast.position.z - z_span)
		var aft_anchor := Vector3(float(side) * _hull_width * 0.43, _deck_y + 0.24, mast.position.z + z_span)
		_add_rope_between(shroud_top, fore_anchor, rope_mat)
		_add_rope_between(shroud_top, aft_anchor, rope_mat)
		for rung_index in range(1, 6):
			var ratio := float(rung_index) / 7.0
			var fore_point := fore_anchor.lerp(shroud_top, ratio)
			var aft_point := aft_anchor.lerp(shroud_top, ratio)
			_add_rope_between(fore_point, aft_point, rope_mat)


func _add_rope_between(start: Vector3, finish: Vector3, material: Material) -> void:
	var direction := finish - start
	if direction.length_squared() < 0.001:
		return
	var rope := _add_cylinder(_visual_root, "StandingRigging", 0.014, direction.length(), (start + finish) * 0.5, material, Vector3.ZERO)
	rope.quaternion = Quaternion(Vector3.UP, direction.normalized())
	_rigging_nodes.append(rope)


func _create_damage_overlays() -> void:
	var tear_mat := _make_material(Color(0.035, 0.028, 0.020, 0.78), 0.96)
	tear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rig_height := 5.0 if hull_class == "Sloop" else (10.1 if hull_class == "Man o' War" else (8.6 if hull_class == "Ship of the Line" else (6.7 if hull_class == "Frigate" else 5.2)))
	for data in [
		{"pos": Vector3(-_hull_width * 0.13, _deck_y + rig_height * 0.70, -_hull_length * 0.18), "size": Vector2(0.46, 0.74), "rot": -0.18},
		{"pos": Vector3(_hull_width * 0.16, _deck_y + rig_height * 0.58, -_hull_length * 0.17), "size": Vector2(0.36, 0.58), "rot": 0.12},
		{"pos": Vector3(-_hull_width * 0.09, _deck_y + rig_height * 0.53, _hull_length * 0.18), "size": Vector2(0.34, 0.52), "rot": 0.22},
		{"pos": Vector3(_hull_width * 0.11, _deck_y + rig_height * 0.44, _hull_length * 0.18), "size": Vector2(0.28, 0.42), "rot": -0.16},
	]:
		var tear := _add_damage_quad("SailTear", data.pos, data.size, tear_mat)
		tear.rotation.z = float(data.rot)
		_sail_tear_overlays.append(tear)

	var scorch_mat := _make_material(Color(0.025, 0.020, 0.016, 0.64), 1.0)
	scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scorch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for data in [
		{"pos": Vector3(-_hull_width * 0.505, _deck_y - 0.20, -_hull_length * 0.18), "size": Vector2(0.54, 0.32), "side": -1.0},
		{"pos": Vector3(_hull_width * 0.505, _deck_y - 0.18, _hull_length * 0.09), "size": Vector2(0.48, 0.30), "side": 1.0},
		{"pos": Vector3(-_hull_width * 0.505, _deck_y - 0.25, _hull_length * 0.25), "size": Vector2(0.42, 0.26), "side": -1.0},
		{"pos": Vector3(_hull_width * 0.505, _deck_y - 0.23, -_hull_length * 0.25), "size": Vector2(0.44, 0.28), "side": 1.0},
	]:
		var scorch := _add_damage_quad("HullScorch", data.pos, data.size, scorch_mat)
		scorch.rotation.y = PI * 0.5 * float(data.side)
		_hull_scorch_marks.append(scorch)

	var breach_mat := _make_material(Color(0.012, 0.010, 0.009), 1.0)
	for data in [
		{"side": -1.0, "z": -0.24, "y": 0.58},
		{"side": 1.0, "z": 0.18, "y": 0.54},
		{"side": -1.0, "z": 0.27, "y": 0.48},
		{"side": 1.0, "z": -0.31, "y": 0.44},
		{"side": -1.0, "z": 0.05, "y": 0.40},
		{"side": 1.0, "z": 0.34, "y": 0.36},
	]:
		var breach := _add_hull_breach(float(data.side), _hull_length * float(data.z), _deck_y - _hull_depth * float(data.y), breach_mat)
		_waterline_breaches.append(breach)

	_update_regional_damage_visuals()


func _add_damage_quad(node_name: String, pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	quad.position = pos
	quad.material_override = mat
	quad.visible = false
	_visual_root.add_child(quad)
	return quad


func _make_damage_decal_material(atlas_index: int, opacity: float) -> StandardMaterial3D:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = NavalDamageAtlas
	atlas_texture.region = Rect2(clampi(atlas_index, 0, 2) * 512, 0, 512, 512)
	var material := _make_material(Color(0.40, 0.38, 0.36, opacity * 0.78), 0.96)
	material.albedo_texture = atlas_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material.render_priority = 2
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _add_hull_breach(side: float, z: float, y: float, material: Material) -> MeshInstance3D:
	var breach := MeshInstance3D.new()
	breach.name = "WaterlineBreach"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.19
	mesh.bottom_radius = 0.24
	mesh.height = 0.035
	mesh.radial_segments = 10
	breach.mesh = mesh
	breach.position = Vector3(side * _hull_width * 0.506, y, z)
	breach.rotation.z = PI * 0.5
	breach.material_override = material
	breach.visible = false
	_visual_root.add_child(breach)
	return breach


func _create_wake() -> void:
	var wake_mat := StandardMaterial3D.new()
	wake_mat.albedo_color = Color(0.76, 0.94, 0.92, 0.0)
	wake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wake_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wake_mat.roughness = 0.72
	wake_mat.vertex_color_use_as_albedo = true

	_wake_left = _add_wake_ribbon(-1.0, wake_mat.duplicate())
	_wake_right = _add_wake_ribbon(1.0, wake_mat.duplicate())
	_wake_center = _add_center_wake(wake_mat.duplicate())
	_create_bow_spray()
	_create_stern_wash()
	_port_hull_foam = _create_hull_contact_foam(-1.0)
	_starboard_hull_foam = _create_hull_contact_foam(1.0)


func _create_hull_contact_foam(side: float) -> GPUParticles3D:
	var foam := GPUParticles3D.new()
	foam.name = "PortHullFoam" if side < 0.0 else "StarboardHullFoam"
	var class_scale := clampf(_hull_width / 3.2, 0.72, 1.55)
	foam.amount = clampi(int(round(9.0 + _hull_length * 0.72)), 12, 22)
	foam.process_mode = Node.PROCESS_MODE_PAUSABLE
	foam.amount_ratio = 0.0
	foam.lifetime = 0.74 + class_scale * 0.18
	foam.randomness = 0.68
	foam.fixed_fps = 18
	foam.local_coords = false
	var waterline_y := _target_draft - _hull_depth * _buoyancy_point_depth_ratio
	foam.position = Vector3(side * _hull_width * 0.43, waterline_y + 0.02, 0.02)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.14) * class_scale
	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_texture = WaterSprayTexture
	foam_material.albedo_color = Color(0.76, 0.91, 0.90, 0.46)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	foam_material.vertex_color_use_as_albedo = true
	quad.material = foam_material
	foam.draw_pass_1 = quad

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.05, 0.025, _hull_length * 0.31)
	process.direction = Vector3(side * 0.72, 0.30, 0.22).normalized()
	process.spread = 34.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 1.15 + class_scale * 0.25
	process.gravity = Vector3(0.0, -1.8, 0.0)
	process.scale_min = 0.35
	process.scale_max = 0.88
	process.color = Color(0.82, 0.95, 0.93, 0.54)
	foam.process_material = process
	_visual_root.add_child(foam)
	foam.emitting = false
	return foam


func _create_bow_spray() -> void:
	_bow_spray = GPUParticles3D.new()
	_bow_spray.name = "BowSpray"
	var class_amount := 16
	var class_scale := 1.0
	match hull_class:
		"Sloop":
			class_amount = 10
			class_scale = 0.68
		"Frigate":
			class_amount = 18
			class_scale = 1.12
		"Ship of the Line":
			class_amount = 22
			class_scale = 1.36
		"Man o' War":
			class_amount = 26
			class_scale = 1.58
	_bow_spray.amount = class_amount
	_bow_spray.process_mode = Node.PROCESS_MODE_PAUSABLE
	_bow_spray.amount_ratio = 0.0
	_bow_spray.lifetime = 0.92
	_bow_spray.randomness = 0.62
	_bow_spray.fixed_fps = 24
	_bow_spray.local_coords = false
	_bow_spray.position = Vector3(0.0, -0.10, -_hull_length * 0.49)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.44, 0.44) * class_scale
	var spray_material := StandardMaterial3D.new()
	spray_material.albedo_texture = WaterSprayTexture
	spray_material.albedo_color = Color(0.78, 0.91, 0.90, 0.62)
	spray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spray_material.vertex_color_use_as_albedo = true
	quad.material = spray_material
	_bow_spray.draw_pass_1 = quad
	var spray_process := ParticleProcessMaterial.new()
	spray_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spray_process.emission_box_extents = Vector3(_hull_width * 0.20, 0.05, 0.10)
	spray_process.direction = Vector3(0.0, 0.72, -0.70).normalized()
	spray_process.spread = 31.0
	spray_process.initial_velocity_min = 1.6 * class_scale
	spray_process.initial_velocity_max = 3.8 * class_scale
	spray_process.gravity = Vector3(0.0, -5.8, 0.0)
	spray_process.scale_min = 0.42
	spray_process.scale_max = 1.18
	spray_process.color = Color(0.86, 0.96, 0.94, 0.72)
	_bow_spray.process_material = spray_process
	_visual_root.add_child(_bow_spray)
	_bow_spray.emitting = false


func _create_stern_wash() -> void:
	_stern_wash = GPUParticles3D.new()
	_stern_wash.name = "SternWash"
	var class_scale := clampf(_hull_width / 3.0, 0.72, 1.65)
	_stern_wash.amount = clampi(int(10.0 + class_scale * 5.0), 12, 18)
	_stern_wash.process_mode = Node.PROCESS_MODE_PAUSABLE
	_stern_wash.amount_ratio = 0.0
	_stern_wash.lifetime = 1.85
	_stern_wash.randomness = 0.74
	_stern_wash.fixed_fps = 18
	_stern_wash.local_coords = false
	_stern_wash.position = Vector3(0.0, -0.08, _hull_length * 0.46)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.24) * class_scale
	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_texture = WaterSprayTexture
	foam_material.albedo_color = Color(0.79, 0.92, 0.89, 0.46)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	foam_material.vertex_color_use_as_albedo = true
	quad.material = foam_material
	_stern_wash.draw_pass_1 = quad
	var wash_process := ParticleProcessMaterial.new()
	wash_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	wash_process.emission_box_extents = Vector3(_hull_width * 0.27, 0.035, 0.08)
	wash_process.direction = Vector3(0.0, 0.08, 1.0).normalized()
	wash_process.spread = 38.0
	wash_process.initial_velocity_min = 0.25
	wash_process.initial_velocity_max = 0.80
	wash_process.gravity = Vector3.ZERO
	wash_process.scale_min = 0.34
	wash_process.scale_max = 0.92
	wash_process.color = Color(0.84, 0.96, 0.92, 0.58)
	_stern_wash.process_material = wash_process
	_visual_root.add_child(_stern_wash)
	_stern_wash.emitting = false


func _add_wake_ribbon(side: float, mat: Material) -> MeshInstance3D:
	var wake := MeshInstance3D.new()
	wake.name = "PortWake" if side < 0.0 else "StarboardWake"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 14
	var length := _hull_length * 0.68
	for index in range(segments):
		var t0 := float(index) / float(segments)
		var t1 := float(index + 1) / float(segments)
		var wobble0 := sin(t0 * 15.0 + side * 1.7) * _hull_width * 0.035 * t0
		var wobble1 := sin(t1 * 15.0 + side * 1.7) * _hull_width * 0.035 * t1
		var center0 := side * lerpf(_hull_width * 0.11, _hull_width * 0.48, pow(t0, 0.72)) + wobble0
		var center1 := side * lerpf(_hull_width * 0.11, _hull_width * 0.48, pow(t1, 0.72)) + wobble1
		var pulse0 := 0.66 + sin(t0 * 21.0 + side) * 0.20
		var pulse1 := 0.66 + sin(t1 * 21.0 + side) * 0.20
		var half0 := lerpf(_hull_width * 0.035, _hull_width * 0.13, t0) * pulse0
		var half1 := lerpf(_hull_width * 0.035, _hull_width * 0.13, t1) * pulse1
		var z0 := t0 * length
		var z1 := t1 * length
		var broken0 := 0.42 + 0.58 * maxf(0.0, sin(t0 * 24.0 + side * 2.3))
		var broken1 := 0.42 + 0.58 * maxf(0.0, sin(t1 * 24.0 + side * 2.3))
		var alpha0 := pow(1.0 - t0, 1.24) * 0.74 * broken0
		var alpha1 := pow(1.0 - t1, 1.24) * 0.74 * broken1
		_add_wake_vertex(st, Vector3(center0 - half0, 0.0, z0), alpha0)
		_add_wake_vertex(st, Vector3(center0 + half0, 0.0, z0), alpha0)
		_add_wake_vertex(st, Vector3(center1 + half1, 0.0, z1), alpha1)
		_add_wake_vertex(st, Vector3(center0 - half0, 0.0, z0), alpha0)
		_add_wake_vertex(st, Vector3(center1 + half1, 0.0, z1), alpha1)
		_add_wake_vertex(st, Vector3(center1 - half1, 0.0, z1), alpha1)
	wake.mesh = st.commit()
	wake.position = Vector3(0.0, -0.12, _hull_length * 0.40)
	wake.material_override = mat
	_visual_root.add_child(wake)
	return wake


func _add_center_wake(mat: Material) -> MeshInstance3D:
	var wake := MeshInstance3D.new()
	wake.name = "SternTurbulence"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var patches := 9
	var length := _hull_length * 0.42
	for index in range(patches):
		var t0 := float(index) / float(patches)
		var t1 := float(index + 1) / float(patches)
		var drift0 := sin(t0 * 18.0) * _hull_width * 0.10
		var drift1 := sin(t1 * 18.0) * _hull_width * 0.10
		var half0 := _hull_width * lerpf(0.16, 0.06, t0) * (0.72 + sin(t0 * 27.0) * 0.18)
		var half1 := _hull_width * lerpf(0.16, 0.06, t1) * (0.72 + sin(t1 * 27.0) * 0.18)
		var alpha0 := pow(1.0 - t0, 1.6) * (0.42 + maxf(0.0, sin(t0 * 25.0)) * 0.38)
		var alpha1 := pow(1.0 - t1, 1.6) * (0.42 + maxf(0.0, sin(t1 * 25.0)) * 0.38)
		_add_wake_vertex(st, Vector3(drift0 - half0, 0.0, t0 * length), alpha0)
		_add_wake_vertex(st, Vector3(drift0 + half0, 0.0, t0 * length), alpha0)
		_add_wake_vertex(st, Vector3(drift1 + half1, 0.0, t1 * length), alpha1)
		_add_wake_vertex(st, Vector3(drift0 - half0, 0.0, t0 * length), alpha0)
		_add_wake_vertex(st, Vector3(drift1 + half1, 0.0, t1 * length), alpha1)
		_add_wake_vertex(st, Vector3(drift1 - half1, 0.0, t1 * length), alpha1)
	wake.mesh = st.commit()
	wake.position = Vector3(0.0, -0.115, _hull_length * 0.41)
	wake.material_override = mat
	_visual_root.add_child(wake)
	return wake


func _add_wake_vertex(st: SurfaceTool, vertex: Vector3, alpha: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_color(Color(0.82, 0.97, 0.94, alpha))
	st.add_vertex(vertex)


func _create_damage_smoke() -> void:
	_damage_smoke = GPUParticles3D.new()
	_damage_smoke.name = "DamageSmoke"
	_damage_smoke.amount = 80
	_damage_smoke.amount_ratio = 0.0
	_damage_smoke.lifetime = 2.1
	_damage_smoke.position = Vector3(0.0, _deck_y + 0.68, _hull_length * 0.07)
	_damage_smoke.emitting = false

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 35.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0.0, 0.12, 0.0)
	process.scale_min = 0.35
	process.scale_max = 0.95
	process.color = Color(0.05, 0.05, 0.05, 0.42)
	_damage_smoke.process_material = process

	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.18
	draw_mesh.height = 0.22
	_damage_smoke.draw_pass_1 = draw_mesh
	_visual_root.add_child(_damage_smoke)


func _create_flooding_leaks() -> void:
	_port_leak_particles = _make_leak_particles("PortHullLeak", Vector3(-_hull_width * 0.49, _deck_y - _hull_depth * 0.36, -_hull_length * 0.07), Vector3(-1.0, -0.18, 0.0))
	_starboard_leak_particles = _make_leak_particles("StarboardHullLeak", Vector3(_hull_width * 0.49, _deck_y - _hull_depth * 0.36, _hull_length * 0.07), Vector3(1.0, -0.18, 0.0))
	_update_flooding_visuals()


func _make_leak_particles(node_name: String, pos: Vector3, direction: Vector3) -> GPUParticles3D:
	var leak := GPUParticles3D.new()
	leak.name = node_name
	leak.amount = 74
	leak.amount_ratio = 0.0
	leak.lifetime = 0.82
	leak.local_coords = true
	leak.position = pos
	leak.emitting = false
	var process := ParticleProcessMaterial.new()
	process.direction = direction.normalized()
	process.spread = 18.0
	process.initial_velocity_min = 0.9
	process.initial_velocity_max = 2.8
	process.gravity = Vector3(0.0, -2.8, 0.0)
	process.scale_min = 0.30
	process.scale_max = 0.85
	process.color = Color(0.62, 0.88, 0.92, 0.62)
	leak.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.10
	leak.draw_pass_1 = mesh
	_visual_root.add_child(leak)
	return leak


func _create_hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := _get_hull_profile_rings()

	var points: Array[Vector3] = []
	for ring in rings:
		var z: float = ring.z
		var half: float = ring.half
		var top_half := half * float(ring.get("top_scale", 1.0))
		var chine_half := half * float(ring.get("chine_scale", 0.82))
		points.append(Vector3(-top_half, ring.top, z))
		points.append(Vector3(top_half, ring.top, z))
		points.append(Vector3(chine_half, ring.chine, z))
		points.append(Vector3(0.0, ring.keel, z))
		points.append(Vector3(-chine_half, ring.chine, z))

	var first_z := float(rings[0].z)
	var last_z := float(rings[rings.size() - 1].z)
	for i in range(rings.size() - 1):
		for j in range(5):
			var a := points[i * 5 + j]
			var b := points[i * 5 + ((j + 1) % 5)]
			var c := points[(i + 1) * 5 + ((j + 1) % 5)]
			var d := points[(i + 1) * 5 + j]
			var u0 := inverse_lerp(first_z, last_z, float(rings[i].z))
			var u1 := inverse_lerp(first_z, last_z, float(rings[i + 1].z))
			var v0 := float(j) / 5.0
			var v1 := float(j + 1) / 5.0
			_add_tri_uv(st, a, Vector2(u0, v0), b, Vector2(u0, v1), c, Vector2(u1, v1))
			_add_tri_uv(st, a, Vector2(u0, v0), c, Vector2(u1, v1), d, Vector2(u1, v0))

	_cap_hull_ring(st, points, 0, true)
	_cap_hull_ring(st, points, (rings.size() - 1) * 5, false)

	st.generate_normals()
	return st.commit()


func _get_hull_profile_rings() -> Array:
	var half_width := _hull_width * 0.5
	var half_length := _hull_length * 0.5
	if hull_class == "Frigate":
		return [
			{"z": -half_length * 1.12, "half": half_width * 0.05, "top": _deck_y + 0.30, "chine": _deck_y - _hull_depth * 0.24, "keel": _deck_y - _hull_depth * 0.74, "top_scale": 0.72, "chine_scale": 0.76},
			{"z": -half_length * 0.98, "half": half_width * 0.28, "top": _deck_y + 0.23, "chine": _deck_y - _hull_depth * 0.39, "keel": _deck_y - _hull_depth * 0.91, "top_scale": 0.78, "chine_scale": 0.92},
			{"z": -half_length * 0.82, "half": half_width * 0.58, "top": _deck_y + 0.14, "chine": _deck_y - _hull_depth * 0.51, "keel": _deck_y - _hull_depth * 1.03, "top_scale": 0.82, "chine_scale": 0.98},
			{"z": -half_length * 0.60, "half": half_width * 0.84, "top": _deck_y + 0.06, "chine": _deck_y - _hull_depth * 0.58, "keel": _deck_y - _hull_depth * 1.09, "top_scale": 0.86, "chine_scale": 1.0},
			{"z": -half_length * 0.30, "half": half_width * 0.98, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.61, "keel": _deck_y - _hull_depth * 1.12, "top_scale": 0.88, "chine_scale": 1.0},
			{"z": half_length * 0.04, "half": half_width, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.62, "keel": _deck_y - _hull_depth * 1.12, "top_scale": 0.89, "chine_scale": 1.0},
			{"z": half_length * 0.34, "half": half_width * 0.98, "top": _deck_y + 0.04, "chine": _deck_y - _hull_depth * 0.60, "keel": _deck_y - _hull_depth * 1.09, "top_scale": 0.88, "chine_scale": 1.0},
			{"z": half_length * 0.60, "half": half_width * 0.91, "top": _deck_y + 0.12, "chine": _deck_y - _hull_depth * 0.55, "keel": _deck_y - _hull_depth * 1.02, "top_scale": 0.86, "chine_scale": 0.98},
			{"z": half_length * 0.82, "half": half_width * 0.78, "top": _deck_y + 0.24, "chine": _deck_y - _hull_depth * 0.47, "keel": _deck_y - _hull_depth * 0.92, "top_scale": 0.83, "chine_scale": 0.94},
			{"z": half_length * 1.01, "half": half_width * 0.61, "top": _deck_y + 0.38, "chine": _deck_y - _hull_depth * 0.39, "keel": _deck_y - _hull_depth * 0.78, "top_scale": 0.80, "chine_scale": 0.88},
		]
	match hull_class:
		"Sloop":
			return [
				{"z": -half_length * 1.14, "half": half_width * 0.04, "top": _deck_y + 0.18, "chine": _deck_y - _hull_depth * 0.24, "keel": _deck_y - _hull_depth * 0.68, "top_scale": 0.78, "chine_scale": 0.82},
				{"z": -half_length * 0.94, "half": half_width * 0.34, "top": _deck_y + 0.12, "chine": _deck_y - _hull_depth * 0.42, "keel": _deck_y - _hull_depth * 0.91, "top_scale": 0.84, "chine_scale": 0.96},
				{"z": -half_length * 0.66, "half": half_width * 0.78, "top": _deck_y + 0.04, "chine": _deck_y - _hull_depth * 0.56, "keel": _deck_y - _hull_depth * 1.05, "top_scale": 0.90, "chine_scale": 1.0},
				{"z": -half_length * 0.28, "half": half_width, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.61, "keel": _deck_y - _hull_depth * 1.10, "top_scale": 0.93, "chine_scale": 1.0},
				{"z": half_length * 0.18, "half": half_width * 0.98, "top": _deck_y + 0.01, "chine": _deck_y - _hull_depth * 0.60, "keel": _deck_y - _hull_depth * 1.08, "top_scale": 0.92, "chine_scale": 1.0},
				{"z": half_length * 0.58, "half": half_width * 0.86, "top": _deck_y + 0.07, "chine": _deck_y - _hull_depth * 0.53, "keel": _deck_y - _hull_depth * 0.98, "top_scale": 0.89, "chine_scale": 0.98},
				{"z": half_length * 0.86, "half": half_width * 0.66, "top": _deck_y + 0.17, "chine": _deck_y - _hull_depth * 0.43, "keel": _deck_y - _hull_depth * 0.83, "top_scale": 0.86, "chine_scale": 0.92},
				{"z": half_length * 1.02, "half": half_width * 0.48, "top": _deck_y + 0.25, "chine": _deck_y - _hull_depth * 0.35, "keel": _deck_y - _hull_depth * 0.70, "top_scale": 0.82, "chine_scale": 0.88},
			]
		"Ship of the Line":
			return [
				{"z": -half_length * 1.10, "half": half_width * 0.06, "top": _deck_y + 0.38, "chine": _deck_y - _hull_depth * 0.22, "keel": _deck_y - _hull_depth * 0.70, "top_scale": 0.70, "chine_scale": 0.78},
				{"z": -half_length * 0.94, "half": half_width * 0.34, "top": _deck_y + 0.27, "chine": _deck_y - _hull_depth * 0.39, "keel": _deck_y - _hull_depth * 0.91, "top_scale": 0.76, "chine_scale": 0.91},
				{"z": -half_length * 0.76, "half": half_width * 0.67, "top": _deck_y + 0.16, "chine": _deck_y - _hull_depth * 0.52, "keel": _deck_y - _hull_depth * 1.04, "top_scale": 0.80, "chine_scale": 0.98},
				{"z": -half_length * 0.48, "half": half_width * 0.91, "top": _deck_y + 0.06, "chine": _deck_y - _hull_depth * 0.59, "keel": _deck_y - _hull_depth * 1.10, "top_scale": 0.83, "chine_scale": 1.0},
				{"z": -half_length * 0.12, "half": half_width, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.62, "keel": _deck_y - _hull_depth * 1.12, "top_scale": 0.84, "chine_scale": 1.0},
				{"z": half_length * 0.25, "half": half_width, "top": _deck_y + 0.02, "chine": _deck_y - _hull_depth * 0.61, "keel": _deck_y - _hull_depth * 1.10, "top_scale": 0.83, "chine_scale": 1.0},
				{"z": half_length * 0.56, "half": half_width * 0.94, "top": _deck_y + 0.13, "chine": _deck_y - _hull_depth * 0.55, "keel": _deck_y - _hull_depth * 1.02, "top_scale": 0.81, "chine_scale": 0.98},
				{"z": half_length * 0.80, "half": half_width * 0.82, "top": _deck_y + 0.31, "chine": _deck_y - _hull_depth * 0.46, "keel": _deck_y - _hull_depth * 0.91, "top_scale": 0.78, "chine_scale": 0.93},
				{"z": half_length * 1.01, "half": half_width * 0.66, "top": _deck_y + 0.53, "chine": _deck_y - _hull_depth * 0.36, "keel": _deck_y - _hull_depth * 0.76, "top_scale": 0.75, "chine_scale": 0.87},
			]
		"Man o' War":
			return [
				{"z": -half_length * 1.14, "half": half_width * 0.04, "top": _deck_y + 0.30, "chine": _deck_y - _hull_depth * 0.18, "keel": _deck_y - _hull_depth * 0.58, "top_scale": 0.74, "chine_scale": 0.78},
				{"z": -half_length * 0.98, "half": half_width * 0.25, "top": _deck_y + 0.23, "chine": _deck_y - _hull_depth * 0.34, "keel": _deck_y - _hull_depth * 0.76, "top_scale": 0.79, "chine_scale": 0.91},
				{"z": -half_length * 0.82, "half": half_width * 0.57, "top": _deck_y + 0.14, "chine": _deck_y - _hull_depth * 0.46, "keel": _deck_y - _hull_depth * 0.88, "top_scale": 0.83, "chine_scale": 0.98},
				{"z": -half_length * 0.60, "half": half_width * 0.84, "top": _deck_y + 0.06, "chine": _deck_y - _hull_depth * 0.52, "keel": _deck_y - _hull_depth * 0.94, "top_scale": 0.86, "chine_scale": 1.0},
				{"z": -half_length * 0.31, "half": half_width * 0.98, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.55, "keel": _deck_y - _hull_depth * 0.97, "top_scale": 0.87, "chine_scale": 1.0},
				{"z": half_length * 0.03, "half": half_width, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.56, "keel": _deck_y - _hull_depth * 0.98, "top_scale": 0.87, "chine_scale": 1.0},
				{"z": half_length * 0.34, "half": half_width * 0.98, "top": _deck_y + 0.04, "chine": _deck_y - _hull_depth * 0.54, "keel": _deck_y - _hull_depth * 0.95, "top_scale": 0.86, "chine_scale": 1.0},
				{"z": half_length * 0.62, "half": half_width * 0.91, "top": _deck_y + 0.12, "chine": _deck_y - _hull_depth * 0.49, "keel": _deck_y - _hull_depth * 0.88, "top_scale": 0.84, "chine_scale": 0.98},
				{"z": half_length * 0.84, "half": half_width * 0.76, "top": _deck_y + 0.25, "chine": _deck_y - _hull_depth * 0.41, "keel": _deck_y - _hull_depth * 0.77, "top_scale": 0.81, "chine_scale": 0.93},
				{"z": half_length * 1.02, "half": half_width * 0.58, "top": _deck_y + 0.42, "chine": _deck_y - _hull_depth * 0.32, "keel": _deck_y - _hull_depth * 0.65, "top_scale": 0.78, "chine_scale": 0.87},
			]
		_:
			# Brig: fuller than the sloop, but still noticeably leaner than a frigate.
			return [
				{"z": -half_length * 1.11, "half": half_width * 0.05, "top": _deck_y + 0.22, "chine": _deck_y - _hull_depth * 0.24, "keel": _deck_y - _hull_depth * 0.72, "top_scale": 0.76, "chine_scale": 0.80},
				{"z": -half_length * 0.94, "half": half_width * 0.35, "top": _deck_y + 0.15, "chine": _deck_y - _hull_depth * 0.42, "keel": _deck_y - _hull_depth * 0.93, "top_scale": 0.82, "chine_scale": 0.94},
				{"z": -half_length * 0.70, "half": half_width * 0.75, "top": _deck_y + 0.07, "chine": _deck_y - _hull_depth * 0.54, "keel": _deck_y - _hull_depth * 1.05, "top_scale": 0.87, "chine_scale": 0.99},
				{"z": -half_length * 0.36, "half": half_width * 0.96, "top": _deck_y, "chine": _deck_y - _hull_depth * 0.60, "keel": _deck_y - _hull_depth * 1.10, "top_scale": 0.90, "chine_scale": 1.0},
				{"z": half_length * 0.08, "half": half_width, "top": _deck_y + 0.01, "chine": _deck_y - _hull_depth * 0.61, "keel": _deck_y - _hull_depth * 1.10, "top_scale": 0.90, "chine_scale": 1.0},
				{"z": half_length * 0.48, "half": half_width * 0.93, "top": _deck_y + 0.08, "chine": _deck_y - _hull_depth * 0.55, "keel": _deck_y - _hull_depth * 1.02, "top_scale": 0.87, "chine_scale": 0.98},
				{"z": half_length * 0.78, "half": half_width * 0.78, "top": _deck_y + 0.20, "chine": _deck_y - _hull_depth * 0.46, "keel": _deck_y - _hull_depth * 0.90, "top_scale": 0.83, "chine_scale": 0.93},
				{"z": half_length * 1.01, "half": half_width * 0.59, "top": _deck_y + 0.34, "chine": _deck_y - _hull_depth * 0.36, "keel": _deck_y - _hull_depth * 0.74, "top_scale": 0.79, "chine_scale": 0.87},
			]


func _create_weather_deck_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := _get_hull_profile_rings()
	var first_z := float(rings[0].z)
	var last_z := float(rings[rings.size() - 1].z)
	for index in range(rings.size() - 1):
		var first: Dictionary = rings[index]
		var second: Dictionary = rings[index + 1]
		var inset := 0.94 if hull_class in ["Sloop", "Brig", "Frigate"] else 0.965
		var first_half := float(first.half) * float(first.get("top_scale", 1.0)) * inset
		var second_half := float(second.half) * float(second.get("top_scale", 1.0)) * inset
		var a := Vector3(-first_half, float(first.top) + 0.035, float(first.z))
		var b := Vector3(first_half, float(first.top) + 0.035, float(first.z))
		var c := Vector3(second_half, float(second.top) + 0.035, float(second.z))
		var d := Vector3(-second_half, float(second.top) + 0.035, float(second.z))
		var v0 := inverse_lerp(first_z, last_z, float(first.z))
		var v1 := inverse_lerp(first_z, last_z, float(second.z))
		_add_tri_uv(st, a, Vector2(0.0, v0), c, Vector2(1.0, v1), b, Vector2(1.0, v0))
		_add_tri_uv(st, a, Vector2(0.0, v0), d, Vector2(0.0, v1), c, Vector2(1.0, v1))
	st.generate_normals()
	return st.commit()


func _cap_hull_ring(st: SurfaceTool, points: Array[Vector3], start: int, reverse: bool) -> void:
	var center := Vector3.ZERO
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for i in range(5):
		var point := points[start + i]
		center += point
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	center /= 5.0
	var center_uv := Vector2(
		inverse_lerp(min_x, max_x, center.x),
		inverse_lerp(min_y, max_y, center.y)
	)

	for i in range(5):
		var a := points[start + i]
		var b := points[start + ((i + 1) % 5)]
		var uv_a := Vector2(inverse_lerp(min_x, max_x, a.x), inverse_lerp(min_y, max_y, a.y))
		var uv_b := Vector2(inverse_lerp(min_x, max_x, b.x), inverse_lerp(min_y, max_y, b.y))
		if reverse:
			_add_tri_uv(st, center, center_uv, b, uv_b, a, uv_a)
		else:
			_add_tri_uv(st, center, center_uv, a, uv_a, b, uv_b)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(b)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(c)


func _add_tri_uv(st: SurfaceTool, a: Vector3, uv_a: Vector2, b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_uv(uv_c)
	st.add_vertex(c)


func _add_tapered_box(parent: Node3D, node_name: String, start_width: float, end_width: float, height: float, start_z: float, end_z: float, center_y: float, mat: Material, center_x: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := center_y - height * 0.5
	var y1 := center_y + height * 0.5
	var vertices := [
		Vector3(center_x - start_width * 0.5, y0, start_z), Vector3(center_x + start_width * 0.5, y0, start_z),
		Vector3(center_x - end_width * 0.5, y0, end_z), Vector3(center_x + end_width * 0.5, y0, end_z),
		Vector3(center_x - start_width * 0.5, y1, start_z), Vector3(center_x + start_width * 0.5, y1, start_z),
		Vector3(center_x - end_width * 0.5, y1, end_z), Vector3(center_x + end_width * 0.5, y1, end_z),
	]
	for face in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_add_tri_uv(st, vertices[face[0]], Vector2(0.0, 0.0), vertices[face[1]], Vector2(1.0, 0.0), vertices[face[2]], Vector2(1.0, 1.0))
		_add_tri_uv(st, vertices[face[0]], Vector2(0.0, 0.0), vertices[face[2]], Vector2(1.0, 1.0), vertices[face[3]], Vector2(0.0, 1.0))
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_vertical_trapezoid(parent: Node3D, node_name: String, bottom_width: float, top_width: float, height: float, thickness: float, center: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := center.y - height * 0.5
	var y1 := center.y + height * 0.5
	var z0 := center.z - thickness * 0.5
	var z1 := center.z + thickness * 0.5
	var vertices := [
		Vector3(center.x - bottom_width * 0.5, y0, z0), Vector3(center.x + bottom_width * 0.5, y0, z0),
		Vector3(center.x - top_width * 0.5, y1, z0), Vector3(center.x + top_width * 0.5, y1, z0),
		Vector3(center.x - bottom_width * 0.5, y0, z1), Vector3(center.x + bottom_width * 0.5, y0, z1),
		Vector3(center.x - top_width * 0.5, y1, z1), Vector3(center.x + top_width * 0.5, y1, z1),
	]
	for face in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 4, 6, 2], [1, 3, 7, 5], [2, 6, 7, 3], [0, 1, 5, 4]]:
		_add_tri_uv(st, vertices[face[0]], Vector2(0.0, 0.0), vertices[face[1]], Vector2(0.0, 1.0), vertices[face[2]], Vector2(1.0, 1.0))
		_add_tri_uv(st, vertices[face[0]], Vector2(0.0, 0.0), vertices[face[2]], Vector2(1.0, 1.0), vertices[face[3]], Vector2(1.0, 0.0))
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_spar_between(node_name: String, start: Vector3, finish: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var direction := finish - start
	var spar := _add_cylinder(_visual_root, node_name, radius, direction.length(), start.lerp(finish, 0.5), mat, Vector3.ZERO)
	if direction.length_squared() > 0.001:
		spar.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return spar


func _add_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cannon_ready_marker(node_name: String, pos: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.075
	mesh.height = 0.13
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _cannon_ready_material
	mesh_instance.visible = false
	_visual_root.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _make_textured_material(
	color: Color,
	roughness: float,
	albedo: Texture2D,
	normal: Texture2D,
	roughness_map: Texture2D,
	ao_map: Texture2D,
	uv_scale: Vector2,
	normal_strength: float
) -> StandardMaterial3D:
	var material := _make_material(color, roughness)
	material.albedo_texture = albedo
	material.roughness_texture = roughness_map
	material.normal_enabled = normal != null
	material.normal_texture = normal
	material.normal_scale = normal_strength
	material.ao_enabled = ao_map != null
	material.ao_texture = ao_map
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _make_emissive_material(color: Color, emission: Color, roughness: float) -> StandardMaterial3D:
	var material := _make_material(color, roughness)
	material.emission_enabled = true
	material.emission = emission
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
