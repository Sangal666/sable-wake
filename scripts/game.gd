extends Node3D

const PlayerShip := preload("res://scripts/player_ship.gd")
const EnemyShip := preload("res://scripts/enemy_ship.gd")
const SmoothShipCamera := preload("res://scripts/smooth_ship_camera.gd")
const Hud := preload("res://scripts/hud.gd")
const AimGuide := preload("res://scripts/aim_guide.gd")
const BroadsideDangerGuide := preload("res://scripts/broadside_danger_guide.gd")
const CampaignMapUi := preload("res://scripts/campaign_map_ui.gd")
const MainMenu := preload("res://scripts/main_menu.gd")
const CombatFx := preload("res://scripts/combat_fx.gd")
const CombatAudio := preload("res://scripts/combat_audio.gd")
const MortarTargetingUi := preload("res://scripts/mortar_targeting_ui.gd")
const RogueWave := preload("res://scripts/rogue_wave.gd")
const PirateKitAssets := preload("res://scripts/pirate_kit_assets.gd")
const NatureAssets := preload("res://scripts/nature_assets.gd")
const BattleEnvironmentProfiles := preload("res://scripts/battle_environment_profiles.gd")
const BattleScenarios := preload("res://scripts/battle_scenarios.gd")
const CoastalFort := preload("res://scripts/coastal_fort.gd")
const FortAssaultBoat := preload("res://scripts/fort_assault_boat.gd")
const SeaControlPoint := preload("res://scripts/sea_control_point.gd")
const CombatSandbox := preload("res://scripts/combat_sandbox.gd")
const ShoreFoamShader := preload("res://shaders/shore_foam.gdshader")
const FFTWaveFluid := preload("res://scripts/fft_wave_fluid_area_3d.gd")
const StormRain := preload("res://scripts/storm_rain.gd")

var player_ship: Node3D
var camera: Camera3D
var hud: CanvasLayer
var campaign_map: CanvasLayer
var main_menu: CanvasLayer
var combat_sandbox: CanvasLayer
var combat_audio: Node
var mortar_targeting_ui: CanvasLayer
var aim_guide: Node3D
var danger_guide: Node3D
var enemies: Array[Node] = []
var allies: Array[Node] = []
var island_markers: Array[Dictionary] = []
var wind_direction := Vector3(0.85, 0.0, -0.35).normalized()
var wind_strength := 1.0
var mission_complete := false
var player_sunk := false
var campaign_started := false
var campaign_map_open := false
var boarding_range := 18.0
var boarding_target: Node
var boarding_progress := 0.0
var boarding_duration := 5.6
var boarding_resolution_target: Node
var boarding_attempt_cooldown := 0.0
var boarding_sequence_active := false
var boarding_sequence_phase := -1
var boarding_alignment_side := 1.0
var boarding_enemy_start_transform := Transform3D.IDENTITY
var boarding_clash_stage := 0
var fort_capture_target: Node3D
var fort_capture_active := false
var ai_boarding_operations: Array[Dictionary] = []
var ai_boarding_scan_timer := 0.0
var active_sortie_region: Dictionary = {}
var active_encounter_party: Dictionary = {}
var active_sortie_captures := 0
var active_sortie_resolved := false
var combat_debug_visible := false
var main_menu_open := false
var battle_mode := "menu"
var custom_battle_config: Dictionary = {}
var custom_scenario_id := "fleet_trial"
var custom_scenario_definition: Dictionary = {}
var custom_scenario_failed := false
var custom_scenario_expected_convoy := 0
var custom_scenario_elapsed := 0.0
var custom_scenario_spawned_waves: Dictionary = {}
var custom_scenario_wave_total := 0
var custom_scenario_control_points_expected := 0
var custom_scenario_max_active_ships := 14
var custom_scenario_initial_allies := 1
var custom_scenario_initial_enemies := 0
var aim_focus := 0.0
var _ocean_material: ShaderMaterial
var _shore_foam_material: ShaderMaterial
var _wave_fluid: Area3D
var _world_environment: WorldEnvironment
var _sun_light: DirectionalLight3D
var _storm_rain: GPUParticles3D
var _ocean_time := 0.0
var _ocean_sea_state := 1.16
var _ocean_wave_speed := 0.66
var _ocean_wave_chop := 0.90
var active_rogue_wave: Node3D
var _rogue_wave_cooldown := 22.0
var _storm_breakers_enabled := false
var _storm_breaker_interval := Vector2(24.0, 36.0)
var _storm_breaker_scale := 1.0
var _storm_breaker_palette: Dictionary = {}
var _rogue_wave_impacted: Dictionary = {}
var _rogue_wave_warning_timer := 0.0
var _rogue_wave_near_warned := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_configure_window()
	_ensure_input_actions()
	_create_environment()
	_create_combat_audio()
	_create_ocean()
	_apply_battle_environment(BattleEnvironmentProfiles.default_config())
	_create_islands()
	_spawn_player()
	_create_camera()
	_create_aim_guide()
	_create_danger_guide()
	_create_hud()
	_create_mortar_targeting_ui()
	_create_campaign_map()
	_create_main_menu()
	_show_main_menu()


func _create_combat_audio() -> void:
	combat_audio = CombatAudio.new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)


func _process(_delta: float) -> void:
	if not main_menu_open and not campaign_map_open and Input.is_action_just_pressed("pause_menu"):
		if _is_mortar_targeting_open():
			_close_mortar_targeting()
			return
		_set_pause_menu(not get_tree().paused)
		return
	if get_tree().paused:
		return
	if main_menu_open:
		return
	if campaign_map_open:
		return
	_ocean_time += _delta
	if _wave_fluid:
		_wave_fluid.set("simulation_time", _ocean_time)
	if _ocean_material:
		_ocean_material.set_shader_parameter("simulation_time", _ocean_time)
	if _shore_foam_material:
		_shore_foam_material.set_shader_parameter("simulation_time", _ocean_time)
	for ship_node in get_tree().get_nodes_in_group("ships"):
		if ship_node.has_method("set_ocean_simulation_time"):
			ship_node.set_ocean_simulation_time(_ocean_time)
	_update_rogue_wave(_delta)
	if _is_mortar_targeting_open():
		mortar_targeting_ui.refresh(player_ship, enemies)
		if Input.is_action_just_pressed("fire_mortar"):
			_close_mortar_targeting()
			return
	elif Input.is_action_just_pressed("fire_mortar"):
		_open_mortar_targeting()
		return

	if campaign_started and Input.is_action_just_pressed("campaign_map") and not Input.is_action_pressed("aim_hold"):
		_open_campaign_map(true)
		return

	if Input.is_action_just_pressed("toggle_fullscreen"):
		_toggle_fullscreen()

	if Input.is_action_just_pressed("toggle_debug") and hud:
		hud.toggle_debug()
		combat_debug_visible = not combat_debug_visible
		if not combat_debug_visible and danger_guide and danger_guide.has_method("hide_threats"):
			danger_guide.hide_threats()

	if not _is_mortar_targeting_open():
		_update_camera_aim(_delta)
	_update_boarding(_delta)
	_update_ai_boarding(_delta)
	_update_danger_guide()

	if Input.is_action_just_pressed("restart") and (player_sunk or mission_complete):
		if battle_mode == "custom":
			_prepare_custom_battle(custom_battle_config)
		elif mission_complete and campaign_started:
			_open_campaign_map(true)
		else:
			get_tree().reload_current_scene()
		return

	enemies = enemies.filter(func(ship: Node) -> bool: return is_instance_valid(ship) and not ship.get("is_sunk"))
	allies = allies.filter(func(ship: Node) -> bool: return is_instance_valid(ship) and not ship.get("is_sunk"))
	_update_custom_scenario_state(_delta)

	if hud and player_ship:
		hud.set_stats(player_ship.get_telemetry(), enemies.size(), wind_direction, wind_strength)
		hud.set_world_state(player_ship, enemies, island_markers)
		if hud.has_method("set_combat_objective"):
			hud.set_combat_objective(_build_combat_objective())

	if not mission_complete and not player_sunk and _is_current_battle_complete():
		_complete_sortie_success()


func _configure_window() -> void:
	if DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_min_size(Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _ensure_input_actions() -> void:
	_bind_key("sail_up", KEY_W)
	_bind_key("sail_up", KEY_UP)
	_bind_key("sail_down", KEY_S)
	_bind_key("sail_down", KEY_DOWN)
	_bind_key("rudder_left", KEY_A)
	_bind_key("rudder_left", KEY_LEFT)
	_bind_key("rudder_right", KEY_D)
	_bind_key("rudder_right", KEY_RIGHT)
	_bind_key("fire_port", KEY_Q)
	_bind_key("fire_starboard", KEY_E)
	_bind_key("shot_round", KEY_1)
	_bind_key("shot_chain", KEY_2)
	_bind_key("shot_grape", KEY_3)
	_bind_key("brace", KEY_SPACE)
	_bind_key("board", KEY_B)
	_bind_key("fire_mortar", KEY_M)
	_bind_key("emergency_repair", KEY_R)
	_bind_key("toggle_debug", KEY_F3)
	_bind_key("toggle_fullscreen", KEY_F11)
	_bind_key("pause_menu", KEY_ESCAPE)
	_bind_key("restart", KEY_ENTER)
	_bind_mouse("aim_hold", MOUSE_BUTTON_RIGHT)
	_bind_mouse("fire_camera", MOUSE_BUTTON_LEFT)
	_bind_key("fire_camera", KEY_E)
	_bind_key("campaign_map", KEY_TAB)
	_bind_key("campaign_up", KEY_W)
	_bind_key("campaign_up", KEY_UP)
	_bind_key("campaign_down", KEY_S)
	_bind_key("campaign_down", KEY_DOWN)
	_bind_key("campaign_left", KEY_A)
	_bind_key("campaign_left", KEY_LEFT)
	_bind_key("campaign_right", KEY_D)
	_bind_key("campaign_right", KEY_RIGHT)
	_bind_key("map_confirm", KEY_ENTER)
	_bind_key("map_confirm", KEY_SPACE)
	_bind_key("map_previous", KEY_Q)
	_bind_key("map_next", KEY_E)


func _bind_key(action_name: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == physical_key:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, key_event)


func _bind_mouse(action_name: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button:
			return

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button
	InputMap.action_add_event(action_name, mouse_event)


func _update_camera_aim(delta: float) -> void:
	if not camera or not player_ship:
		return

	var gameplay_active := not get_tree().paused and not player_sunk and not mission_complete and not boarding_sequence_active and not fort_capture_active and not is_instance_valid(boarding_resolution_target)
	camera.set_aiming(gameplay_active and Input.is_action_pressed("aim_hold"))
	aim_focus = move_toward(aim_focus, 1.0 if camera.is_aiming() else 0.0, delta * (0.92 if camera.is_aiming() else 2.8))
	if player_ship.has_method("set_aim_focus"):
		player_ship.set_aim_focus(aim_focus)
	var aim_side := 0
	var ready := false
	if camera.is_aiming():
		var aim_direction: Vector3 = camera.get_aim_direction()
		var aim_point: Vector3 = camera.get_aim_point()
		aim_side = camera.get_aim_side()
		if player_ship.has_method("get_broadside_side_for_camera_aim"):
			var resolved_side: int = player_ship.get_broadside_side_for_camera_aim(aim_direction, aim_point)
			if resolved_side != 0:
				aim_side = resolved_side
		ready = player_ship.can_fire_side(aim_side)
		if aim_guide and aim_guide.has_method("show_solution"):
			aim_guide.show_solution(player_ship, aim_side, aim_point, ready)
		if Input.is_action_just_pressed("fire_camera"):
			player_ship.fire_camera_broadside(aim_direction, aim_side, aim_point)
	elif aim_guide and aim_guide.has_method("hide_solution"):
		aim_guide.hide_solution()

	if hud:
		hud.set_aim_state(camera.is_aiming(), aim_side, ready, aim_focus, bool(player_ship.get_telemetry().get("has_mortar", false)), float(player_ship.get_telemetry().get("mortar_reload", 0.0)))


func _update_danger_guide() -> void:
	if danger_guide == null:
		return
	if not combat_debug_visible:
		if danger_guide.has_method("hide_threats"):
			danger_guide.hide_threats()
		return
	if get_tree().paused or player_sunk or mission_complete or campaign_map_open:
		if danger_guide.has_method("hide_threats"):
			danger_guide.hide_threats()
		return
	if danger_guide.has_method("show_threats"):
		danger_guide.show_threats(enemies, player_ship)


func _update_boarding(delta: float) -> void:
	boarding_attempt_cooldown = maxf(boarding_attempt_cooldown - delta, 0.0)
	if fort_capture_active:
		_update_fort_capture_hud()
		return
	if player_ship == null or player_sunk or mission_complete:
		_reset_boarding_state()
		return
	if is_instance_valid(boarding_resolution_target):
		_show_boarding_resolution()
		if Input.is_action_just_pressed("shot_round"):
			_finish_boarding_outcome("capture")
		elif Input.is_action_just_pressed("shot_chain"):
			_finish_boarding_outcome("loot")
		elif Input.is_action_just_pressed("shot_grape"):
			_finish_boarding_outcome("scuttle")
		return
	if boarding_sequence_active:
		_update_automatic_boarding(delta)
		return

	var previous_target := boarding_target
	boarding_target = _find_boarding_candidate()
	if boarding_target != previous_target:
		if is_instance_valid(previous_target) and previous_target.has_method("clear_boarding_visual"):
			previous_target.clear_boarding_visual()
		boarding_progress = 0.0
	if hud and hud.has_method("show_boarding_prompt"):
		if boarding_target:
			var distance: float = player_ship.global_position.distance_to(boarding_target.global_position)
			var readiness := _get_boarding_readiness(boarding_target)
			var ready := bool(readiness.get("ready", false)) and boarding_attempt_cooldown <= 0.0
			var status := String(readiness.get("status", "Hold position"))
			if boarding_attempt_cooldown > 0.0:
				status = "Repel counterattack - regrouping %.1fs" % boarding_attempt_cooldown
			elif ready:
				status = "Press B to board"
			hud.show_boarding_prompt(true, String(boarding_target.get("display_name")), distance, 0.0, status)
			if ready and Input.is_action_just_pressed("board"):
				_start_boarding_sequence(boarding_target)
		else:
			boarding_progress = 0.0
			if player_ship.has_method("clear_boarding_visual"):
				player_ship.clear_boarding_visual()
			hud.show_boarding_prompt(false)


func _start_boarding_sequence(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	_cancel_ai_boarding_for_target(enemy)
	_mark_boarding_protection(enemy, 0, player_ship)
	player_ship.set_meta("boarding_visual_attacker", true)
	enemy.set_meta("boarding_visual_attacker", false)
	boarding_sequence_active = true
	boarding_sequence_phase = -1
	boarding_progress = 0.0
	boarding_clash_stage = 0
	boarding_target = enemy
	if enemy is Node3D:
		boarding_enemy_start_transform = enemy.global_transform
		var enemy_local := player_ship.to_local(enemy.global_position)
		boarding_alignment_side = signf(enemy_local.x) if absf(enemy_local.x) > 0.25 else 1.0
	if enemy.has_method("incapacitate_for_boarding"):
		enemy.incapacitate_for_boarding()
	player_ship.set("accepts_player_input", false)
	if player_ship.has_method("set_sail_step"):
		player_ship.set_sail_step(0, true)
	else:
		player_ship.set("sail_setting", 0.0)
	if player_ship.has_method("stop_water_motion"):
		player_ship.stop_water_motion()
	if enemy.has_method("stop_water_motion"):
		enemy.stop_water_motion()
	if camera:
		camera.set_aiming(false)
		camera.set_input_enabled(false)
		if camera.has_method("add_boarding_impulse"):
			camera.add_boarding_impulse(0.65)
		if camera.has_method("set_boarding_focus"):
			camera.set_boarding_focus(enemy)
		if camera.has_method("set_boarding_stage"):
			camera.set_boarding_stage(0)


func _update_automatic_boarding(delta: float) -> void:
	if not is_instance_valid(boarding_target):
		_reset_boarding_state()
		return
	if player_ship.has_method("set_sail_step"):
		player_ship.set_sail_step(0, true)
	else:
		player_ship.set("sail_setting", 0.0)
	if player_ship.has_method("stop_water_motion"):
		player_ship.stop_water_motion()
	if boarding_target.has_method("stop_water_motion"):
		boarding_target.stop_water_motion()
	var strength_ratio := _get_boarding_strength_ratio(boarding_target)
	var assault_rate := clampf(lerpf(0.70, 1.34, clampf(inverse_lerp(0.45, 1.65, strength_ratio), 0.0, 1.0)), 0.70, 1.34)
	boarding_progress = minf(boarding_progress + delta / boarding_duration * assault_rate, 1.0)
	_update_boarding_alignment(boarding_progress)
	if player_ship.has_method("set_boarding_visual"):
		player_ship.set_boarding_visual(true, boarding_target.global_position, boarding_progress)
	if boarding_target.has_method("set_boarding_visual"):
		boarding_target.set_boarding_visual(true, player_ship.global_position, boarding_progress)
	var phase := 0 if boarding_progress < 0.22 else (1 if boarding_progress < 0.78 else 2)
	if phase != boarding_sequence_phase:
		boarding_sequence_phase = phase
		_apply_boarding_clash_stage(phase, strength_ratio)
		if camera and camera.has_method("set_boarding_stage"):
			camera.set_boarding_stage(phase)
		if camera and camera.has_method("add_boarding_impulse"):
			camera.add_boarding_impulse(0.42 if phase == 1 else 0.28)
	var title := "GRAPPLING"
	var status := "Pulling the ships together"
	if phase == 1:
		title = "BOARDERS AWAY"
		status = "Your crew is taking the enemy deck" if strength_ratio >= 0.85 else "Enemy numbers are slowing the assault"
	elif phase == 2:
		title = "DECK ALMOST SECURED"
		status = "Enemy resistance is collapsing" if strength_ratio >= 0.72 else "Your crew is forcing a costly final push"
	if hud:
		hud.show_boarding_prompt(true, String(boarding_target.get("display_name")), player_ship.global_position.distance_to(boarding_target.global_position), boarding_progress, status, title)
	if boarding_progress >= 1.0:
		_resolve_boarding_assault(boarding_target)


func _get_boarding_strength_ratio(enemy: Node) -> float:
	if not is_instance_valid(enemy) or not is_instance_valid(player_ship):
		return 1.0
	var player_crew := maxi(int(player_ship.get_meta("campaign_sailors", 42)), 1)
	var enemy_crew := maxi(int(enemy.get_meta("campaign_crew", 36)), 1)
	var player_morale := clampf(float(player_ship.get("combat_morale")) / 100.0, 0.45, 1.0)
	var enemy_health_ratio := clampf(float(enemy.get("health")) / maxf(float(enemy.get("max_health")), 1.0), 0.05, 1.0)
	var disabled_penalty := lerpf(0.42, 0.78, enemy_health_ratio)
	return float(player_crew) * player_morale / maxf(float(enemy_crew) * disabled_penalty, 1.0)


func _apply_boarding_clash_stage(phase: int, strength_ratio: float) -> void:
	if phase <= boarding_clash_stage or not is_instance_valid(boarding_target):
		return
	boarding_clash_stage = phase
	var player_roster := maxi(int(player_ship.get_meta("campaign_sailors", 42)), 1)
	var enemy_roster := maxi(int(boarding_target.get_meta("campaign_crew", 36)), 1)
	var player_preview := 1 if strength_ratio >= 1.0 else 2
	var enemy_preview := 2 if strength_ratio >= 1.0 else 1
	if phase == 2:
		player_preview += 1
		enemy_preview += 2
	if player_ship.has_method("show_boarding_clash_losses"):
		player_ship.show_boarding_clash_losses(player_preview, player_roster)
	if boarding_target.has_method("show_boarding_clash_losses"):
		boarding_target.show_boarding_clash_losses(enemy_preview, enemy_roster)


func _update_boarding_alignment(progress: float) -> void:
	if not is_instance_valid(boarding_target) or not (boarding_target is Node3D):
		return
	var player_width := float(player_ship.get("_hull_width"))
	var enemy_width := float(boarding_target.get("_hull_width"))
	var spacing := player_width * 0.46 + enemy_width * 0.46 + 0.95
	var player_basis := player_ship.global_transform.basis.orthonormalized()
	var desired_position := player_ship.global_position + player_basis.x.normalized() * boarding_alignment_side * spacing
	desired_position += -player_basis.z.normalized() * 0.25
	var desired_transform := Transform3D(player_basis, desired_position)
	var align_t := smoothstep(0.0, 1.0, clampf(progress / 0.24, 0.0, 1.0))
	boarding_target.global_transform = boarding_enemy_start_transform.interpolate_with(desired_transform, align_t)


func _find_boarding_candidate() -> Node:
	var best: Node = null
	var best_distance := boarding_range
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("is_sunk")):
			continue
		var distance: float = player_ship.global_position.distance_to(enemy.global_position)
		if distance > best_distance:
			continue
		best = enemy
		best_distance = distance
	return best


func _is_boardable(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or bool(enemy.get("is_sunk")):
		return false
	return bool(enemy.get("is_incapacitated"))


func _get_boarding_readiness(enemy: Node) -> Dictionary:
	if not _is_boardable(enemy):
		return {"ready": false, "status": "Disable the enemy ship before boarding"}
	var enemy_node := enemy as Node3D
	if enemy_node == null:
		return {"ready": false, "status": "Target cannot be boarded"}
	if absf(float(player_ship.get("speed"))) > 6.5:
		return {"ready": false, "status": "Slow down to come alongside"}
	return {"ready": true, "status": "Press B to board"}


func _resolve_boarding_assault(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		_reset_boarding_state()
		return
	var enemy_crew := maxi(int(enemy.get_meta("campaign_crew", 36)), 1)
	var player_crew := maxi(int(player_ship.get_meta("campaign_sailors", 42)), 1)
	var enemy_hull_ratio := float(enemy.get("health")) / maxf(float(enemy.get("max_health")), 1.0)
	var resistance := float(enemy_crew) / float(maxi(player_crew, 1))
	var casualties := clampi(
		int(round(resistance * lerpf(2.4, 5.2, enemy_hull_ratio))),
		1,
		mini(maxi(player_crew - 1, 1), maxi(int(ceil(float(player_crew) * 0.24)), 4))
	)
	player_ship.set_meta("campaign_sailors", maxi(player_crew - casualties, 1))
	if player_ship.has_method("apply_boarding_casualties"):
		player_ship.apply_boarding_casualties(casualties, player_crew)
	if enemy.has_method("apply_boarding_casualties"):
		enemy.apply_boarding_casualties(maxi(int(enemy_crew * 0.45), 1), enemy_crew)
	boarding_sequence_active = false
	boarding_clash_stage = 0
	boarding_resolution_target = enemy
	boarding_target = null
	boarding_progress = 1.0
	if enemy.has_method("strike_flag"):
		enemy.strike_flag()
	if enemy is Node3D:
		CombatFx.spawn_boarding_capture(get_tree().current_scene if get_tree().current_scene else self, enemy.global_position)


func _show_boarding_resolution() -> void:
	if hud and hud.has_method("show_boarding_prompt"):
		hud.show_boarding_prompt(true, String(boarding_resolution_target.get("display_name")), 0.0, 1.0, "[1] Capture prize   [2] Take cargo   [3] Scuttle", "DECK SECURED")


func _finish_boarding_outcome(outcome: String) -> void:
	var enemy := boarding_resolution_target
	if not is_instance_valid(enemy):
		_reset_boarding_state()
		return
	var title := "Prize captured"
	var detail := "The captured ship will count toward the campaign result."
	if enemy.has_method("clear_boarding_visual"):
		enemy.clear_boarding_visual()
	if player_ship.has_method("clear_boarding_visual"):
		player_ship.clear_boarding_visual()
	_clear_boarding_protection(enemy)
	player_ship.remove_meta("boarding_visual_attacker")
	enemy.remove_meta("boarding_visual_attacker")
	match outcome:
		"loot":
			title = "Cargo transferred"
			detail = "Recovered one repair kit and abandoned the disabled hull."
			player_ship.set("repair_supplies", mini(int(player_ship.get("repair_supplies")) + 1, int(player_ship.get("max_repair_supplies"))))
			if enemy.has_method("strike_flag"):
				enemy.strike_flag()
			enemy.disable_ship(true)
		"scuttle":
			title = "Enemy ship scuttled"
			detail = "The prize was denied to every faction."
			enemy.disable_ship(false)
		_:
			if enemy.has_method("set_captured_flag"):
				enemy.set_captured_flag(0)
			if enemy.has_method("convert_to_ally"):
				enemy.convert_to_ally(player_ship)
				enemies.erase(enemy)
				if not allies.has(enemy):
					allies.append(enemy)
			else:
				enemy.disable_ship(true)
			active_sortie_captures += 1
			if campaign_map and campaign_map.has_method("add_boarding_crew_reward"):
				campaign_map.add_boarding_crew_reward()
	boarding_resolution_target = null
	boarding_target = null
	boarding_progress = 0.0
	boarding_sequence_active = false
	boarding_sequence_phase = -1
	boarding_clash_stage = 0
	boarding_alignment_side = 1.0
	boarding_enemy_start_transform = Transform3D.IDENTITY
	_restore_player_after_boarding()
	if hud:
		hud.show_boarding_prompt(false)
		hud.show_banner(title, detail, 3.0)


func _reset_boarding_state() -> void:
	if is_instance_valid(boarding_target):
		_clear_boarding_protection(boarding_target)
	if is_instance_valid(boarding_resolution_target):
		_clear_boarding_protection(boarding_resolution_target)
	if is_instance_valid(player_ship):
		player_ship.remove_meta("boarding_visual_attacker")
	if is_instance_valid(boarding_target) and boarding_target.has_method("clear_boarding_visual"):
		boarding_target.clear_boarding_visual()
	if is_instance_valid(boarding_resolution_target) and boarding_resolution_target.has_method("clear_boarding_visual"):
		boarding_resolution_target.clear_boarding_visual()
	if is_instance_valid(player_ship) and player_ship.has_method("clear_boarding_visual"):
		player_ship.clear_boarding_visual()
	boarding_target = null
	boarding_resolution_target = null
	boarding_progress = 0.0
	boarding_attempt_cooldown = 0.0
	boarding_sequence_active = false
	boarding_sequence_phase = -1
	_restore_player_after_boarding()
	if hud and hud.has_method("show_boarding_prompt"):
		hud.show_boarding_prompt(false)


func _update_ai_boarding(delta: float) -> void:
	ai_boarding_scan_timer = maxf(ai_boarding_scan_timer - delta, 0.0)
	for operation_index in range(ai_boarding_operations.size() - 1, -1, -1):
		var operation := ai_boarding_operations[operation_index]
		var attacker := operation.get("attacker") as Node3D
		var target := operation.get("target") as Node3D
		if not is_instance_valid(attacker) or not is_instance_valid(target) or bool(attacker.get("is_sunk")) or bool(target.get("is_sunk")):
			_release_ai_boarding_operation(operation)
			ai_boarding_operations.remove_at(operation_index)
			continue
		if not bool(target.get("is_incapacitated")) and String(operation.get("phase", "approach")) == "approach":
			_release_ai_boarding_operation(operation)
			ai_boarding_operations.remove_at(operation_index)
			continue
		_update_ai_boarding_operation(operation, delta)

	if ai_boarding_scan_timer <= 0.0:
		ai_boarding_scan_timer = 0.55
		_assign_ai_boarding_orders()


func _assign_ai_boarding_orders() -> void:
	var attackers: Array[Node] = []
	attackers.append_array(allies)
	attackers.append_array(enemies)
	for attacker_node in attackers:
		if not is_instance_valid(attacker_node) or not (attacker_node is Node3D):
			continue
		if not attacker_node.has_method("set_boarding_order"):
			continue
		if bool(attacker_node.get("is_sunk")) or bool(attacker_node.get("is_incapacitated")) or bool(attacker_node.get("boarding_order_active")):
			continue
		if String(attacker_node.get("ai_role")) == "courier":
			continue
		var attacker := attacker_node as Node3D
		var target := _find_ai_boarding_target(attacker)
		if target == null:
			continue
		var side := signf(attacker.to_local(target.global_position).x)
		if absf(side) < 0.01:
			side = 1.0
		_mark_boarding_protection(target, int(attacker.get("team_id")), attacker)
		if attacker.has_method("set_boarding_order"):
			attacker.set_boarding_order(target, -side)
		ai_boarding_operations.append({
			"attacker": attacker,
			"target": target,
			"phase": "approach",
			"progress": 0.0,
			"side": -side,
			"start_transform": target.global_transform,
			"clash_stage": 0,
		})


func _find_ai_boarding_target(attacker: Node3D) -> Node3D:
	var attacker_team := int(attacker.get("team_id"))
	var candidates: Array[Node] = enemies if attacker_team == 0 else allies
	var best: Node3D
	var best_distance := 82.0
	for candidate_node in candidates:
		if not is_instance_valid(candidate_node) or not (candidate_node is Node3D):
			continue
		if bool(candidate_node.get("is_sunk")) or not bool(candidate_node.get("is_incapacitated")):
			continue
		if candidate_node == boarding_target or candidate_node == boarding_resolution_target or bool(candidate_node.get_meta("boarding_protected", false)):
			continue
		var candidate := candidate_node as Node3D
		if attacker_team == 0 and is_instance_valid(player_ship) and player_ship.global_position.distance_to(candidate.global_position) < 32.0:
			continue
		var distance := attacker.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _update_ai_boarding_operation(operation: Dictionary, delta: float) -> void:
	var attacker := operation.get("attacker") as Node3D
	var target := operation.get("target") as Node3D
	var phase := String(operation.get("phase", "approach"))
	if phase == "approach":
		if attacker.has_method("set_boarding_order"):
			attacker.set_boarding_order(target, float(operation.get("side", 1.0)))
		if attacker.global_position.distance_to(target.global_position) <= 21.5:
			operation["phase"] = "grapple"
			operation["start_transform"] = target.global_transform
			attacker.set_meta("boarding_visual_attacker", true)
			target.set_meta("boarding_visual_attacker", false)
			if target.has_method("incapacitate_for_boarding"):
				target.incapacitate_for_boarding()
		return

	if attacker.has_method("stop_water_motion"):
		attacker.stop_water_motion()
	if target.has_method("stop_water_motion"):
		target.stop_water_motion()
	var attacker_crew := maxi(int(attacker.get_meta("campaign_crew", 32)), 1)
	var target_crew := maxi(int(target.get_meta("campaign_crew", 32)), 1)
	var strength_ratio := float(attacker_crew) / maxf(float(target_crew) * 0.62, 1.0)
	var assault_rate := clampf(lerpf(0.78, 1.24, clampf(inverse_lerp(0.55, 1.55, strength_ratio), 0.0, 1.0)), 0.78, 1.24)
	var progress := minf(float(operation.get("progress", 0.0)) + delta / 6.4 * assault_rate, 1.0)
	operation["progress"] = progress
	_align_ai_boarding_ships(operation, progress)
	if attacker.has_method("set_boarding_visual"):
		attacker.set_boarding_visual(true, target.global_position, progress)
	if target.has_method("set_boarding_visual"):
		target.set_boarding_visual(true, attacker.global_position, progress)
	var clash_stage := int(operation.get("clash_stage", 0))
	var next_stage := 1 if progress >= 0.35 else 0
	if progress >= 0.76:
		next_stage = 2
	if next_stage > clash_stage:
		operation["clash_stage"] = next_stage
		if attacker.has_method("show_boarding_clash_losses"):
			attacker.show_boarding_clash_losses(1 if strength_ratio >= 0.9 else 2, attacker_crew)
		if target.has_method("show_boarding_clash_losses"):
			target.show_boarding_clash_losses(2 if strength_ratio >= 0.9 else 1, target_crew)
	if progress >= 1.0:
		_resolve_ai_boarding(operation)
		var operation_index := ai_boarding_operations.find(operation)
		if operation_index >= 0:
			ai_boarding_operations.remove_at(operation_index)


func _align_ai_boarding_ships(operation: Dictionary, progress: float) -> void:
	var attacker := operation.get("attacker") as Node3D
	var target := operation.get("target") as Node3D
	var attacker_basis := attacker.global_transform.basis.orthonormalized()
	var spacing := float(attacker.get("_hull_width")) * 0.46 + float(target.get("_hull_width")) * 0.46 + 0.95
	var desired_position := attacker.global_position + attacker_basis.x.normalized() * float(operation.get("side", 1.0)) * spacing
	desired_position += -attacker_basis.z.normalized() * 0.25
	var desired_transform := Transform3D(attacker_basis, desired_position)
	var align_t := smoothstep(0.0, 1.0, clampf(progress / 0.26, 0.0, 1.0))
	var start_transform: Transform3D = operation.get("start_transform", target.global_transform)
	target.global_transform = start_transform.interpolate_with(desired_transform, align_t)


func _resolve_ai_boarding(operation: Dictionary) -> void:
	var attacker := operation.get("attacker") as Node3D
	var target := operation.get("target") as Node3D
	var capturing_team := int(attacker.get("team_id"))
	var attacker_crew := maxi(int(attacker.get_meta("campaign_crew", 32)), 1)
	var target_crew := maxi(int(target.get_meta("campaign_crew", 32)), 1)
	var attacker_losses := clampi(int(ceil(float(target_crew) / maxf(float(attacker_crew), 1.0) * 3.0)), 1, maxi(attacker_crew / 4, 1))
	attacker.set_meta("campaign_crew", maxi(attacker_crew - attacker_losses, 1))
	if attacker.has_method("apply_boarding_casualties"):
		attacker.apply_boarding_casualties(attacker_losses, attacker_crew)
	if target.has_method("apply_boarding_casualties"):
		target.apply_boarding_casualties(maxi(int(target_crew * 0.48), 1), target_crew)
	if target.has_method("strike_flag"):
		target.strike_flag()
	CombatFx.spawn_boarding_capture(get_tree().current_scene if get_tree().current_scene else self, target.global_position)
	if target.has_method("convert_to_team"):
		target.convert_to_team(capturing_team, attacker)
		if capturing_team == 0:
			enemies.erase(target)
			if not allies.has(target):
				allies.append(target)
			active_sortie_captures += 1
		else:
			allies.erase(target)
			if not enemies.has(target):
				enemies.append(target)
	else:
		target.disable_ship(true)
	_release_ai_boarding_operation(operation)


func _mark_boarding_protection(target: Node, protecting_team: int, reserver: Node) -> void:
	if not is_instance_valid(target):
		return
	target.set_meta("boarding_protected", true)
	target.set_meta("boarding_protecting_team", protecting_team)
	target.set_meta("boarding_reserved_by", reserver.get_instance_id() if is_instance_valid(reserver) else 0)


func _clear_boarding_protection(target: Node) -> void:
	if not is_instance_valid(target):
		return
	target.remove_meta("boarding_protected")
	target.remove_meta("boarding_protecting_team")
	target.remove_meta("boarding_reserved_by")
	target.remove_meta("boarding_visual_attacker")


func _release_ai_boarding_operation(operation: Dictionary) -> void:
	var attacker := operation.get("attacker") as Node
	var target := operation.get("target") as Node
	if is_instance_valid(attacker):
		if attacker.has_method("clear_boarding_order"):
			attacker.clear_boarding_order()
		if attacker.has_method("clear_boarding_visual"):
			attacker.clear_boarding_visual()
		attacker.remove_meta("boarding_visual_attacker")
	if is_instance_valid(target):
		if target.has_method("clear_boarding_visual"):
			target.clear_boarding_visual()
		_clear_boarding_protection(target)


func _cancel_ai_boarding_for_target(target: Node) -> void:
	for operation_index in range(ai_boarding_operations.size() - 1, -1, -1):
		var operation := ai_boarding_operations[operation_index]
		if operation.get("target") != target:
			continue
		_release_ai_boarding_operation(operation)
		ai_boarding_operations.remove_at(operation_index)


func _restore_player_after_boarding() -> void:
	if is_instance_valid(player_ship) and not player_sunk:
		player_ship.set("accepts_player_input", true)
	if camera:
		if camera.has_method("clear_boarding_focus"):
			camera.clear_boarding_focus()
		camera.set_input_enabled(not campaign_map_open and not get_tree().paused)


func _build_combat_objective() -> Dictionary:
	if player_sunk:
		return {
			"title": "Ship Lost",
			"status": "The command ship is sinking.",
			"action": "Press Enter to replay." if battle_mode == "custom" else "Press Enter to restart.",
			"detail": "The custom fleet setup will be preserved." if battle_mode == "custom" else "Campaign progress is paused until you restart this sortie.",
			"tone": "danger",
		}
	if mission_complete:
		if custom_scenario_failed:
			return {
				"title": "Mission Failed",
				"status": "The scenario objective was lost.",
				"action": "Press Enter to replay this battle.",
				"detail": String(custom_scenario_definition.get("objective_detail", "Regroup and try a different approach.")),
				"tone": "danger",
			}
		var result_text := "Captured prizes: %d" % active_sortie_captures if active_sortie_captures > 0 else "Enemy force defeated."
		return {
			"title": "Waters Secured",
			"status": result_text,
			"action": "Press Enter to replay this battle." if battle_mode == "custom" else "Press Enter to return to the campaign map.",
			"detail": "%d allied ships survived the test." % allies.size() if battle_mode == "custom" else "Cargo, crew, reputation and contracts will be resolved on the campaign layer.",
			"tone": "complete",
		}
	if player_ship == null:
		return {
			"title": "Tactical Orders",
			"status": "No command ship found.",
			"action": "Regroup.",
			"detail": "",
			"tone": "neutral",
		}

	var player_health := float(player_ship.get("health"))
	var player_max_health := maxf(float(player_ship.get("max_health")), 1.0)
	var player_health_ratio := player_health / player_max_health
	var best_enemy := _get_priority_enemy()
	if player_health_ratio <= 0.30 and enemies.size() > 0:
		return {
			"title": "Critical Hull",
			"status": "Hull %d%%  |  %d targets" % [int(player_health_ratio * 100.0), enemies.size()],
			"action": "[Space] BRACE   [R] REPAIR",
			"detail": "Surviving the sortie matters more than a clean kill; campaign repairs cost supplies and time.",
			"tone": "danger",
		}
	if best_enemy == null:
		if battle_mode == "custom" and String(custom_scenario_definition.get("objective", "")) == "capture_zones":
			return {
				"title": String(custom_scenario_definition.get("objective_title", "Secure the Waters")),
				"status": "Positions held %d/%d" % [_controlled_zone_count(0), custom_scenario_control_points_expected],
				"action": "Sail into marked waters and hold the position.",
				"detail": _custom_scenario_progress_detail(),
				"tone": "attack",
			}
		return {
			"title": "No Hostiles",
			"status": "The battle space is clear.",
			"action": "Press Enter to replay." if battle_mode == "custom" else "Press Enter to return to campaign travel.",
			"detail": "%d allied ships remain." % allies.size() if battle_mode == "custom" else "The route will update after the after-action report.",
			"tone": "complete",
		}

	var enemy_health_ratio := float(best_enemy.get("health")) / maxf(float(best_enemy.get("max_health")), 1.0)
	var enemy_sail_ratio := float(best_enemy.get("sail_integrity")) / maxf(float(best_enemy.get("max_sail_integrity")), 1.0)
	var distance := player_ship.global_position.distance_to(best_enemy.global_position) if best_enemy is Node3D else 0.0
	var target_name := String(best_enemy.get("display_name"))
	var state := String(best_enemy.get_ai_state_name()) if best_enemy.has_method("get_ai_state_name") else "maneuvering"
	var target_status := "%s  %.0fm  |  Hull %d%%  Sails %d%%" % [
		target_name,
		distance,
		int(enemy_health_ratio * 100.0),
		int(enemy_sail_ratio * 100.0),
	]

	if _is_boardable(best_enemy):
		var prompt := "Slow down and press B." if distance <= boarding_range else "Close to %.0fm for boarding." % boarding_range
		var boarding_window := float(best_enemy.call("get_boarding_window_remaining")) if best_enemy.has_method("get_boarding_window_remaining") else 0.0
		return {
			"title": "Prize Ready",
			"status": "%s  |  Foundering %.0fs" % [target_status, boarding_window],
			"action": prompt,
			"detail": "A captured ship gives supplies and feeds the campaign result as a prize, not just a kill.",
			"tone": "capture",
		}

	var action := ""
	if state == "broadside" and distance < 115.0:
		action = "[Space] BRACE"
	var scenario_objective := String(custom_scenario_definition.get("objective", ""))
	if battle_mode == "custom" and action.is_empty():
		if scenario_objective == "capture_zones":
			action = "POSITIONS %d/%d" % [_controlled_zone_count(0), custom_scenario_control_points_expected]
		elif scenario_objective == "destroy_fort":
			action = "FORTS REMAINING %d" % _living_scenario_forts()
		elif scenario_objective == "protect_convoy":
			action = "COURIERS %d/%d  |  RESERVES %d/%d" % [_surviving_scenario_convoy(), custom_scenario_expected_convoy, custom_scenario_spawned_waves.size(), custom_scenario_wave_total]
		elif custom_scenario_id != "fleet_trial":
			action = "HOSTILES %d  |  RESERVES %d/%d" % [enemies.size(), custom_scenario_spawned_waves.size(), custom_scenario_wave_total]
	var objective_title := String(custom_scenario_definition.get("objective_title", "Engage Target")) if battle_mode == "custom" and custom_scenario_id != "fleet_trial" else "Engage Target"
	var objective_detail := "Targets remaining: %d. Captured prizes this sortie: %d." % [enemies.size(), active_sortie_captures]
	if battle_mode == "custom" and custom_scenario_id != "fleet_trial":
		objective_detail = _custom_scenario_progress_detail()
	return {
		"title": objective_title,
		"status": target_status,
		"action": action,
		"detail": objective_detail,
		"tone": "attack",
	}


func _get_priority_enemy() -> Node:
	if battle_mode == "custom" and String(custom_scenario_definition.get("objective", "")) == "destroy_fort":
		for fort in get_tree().get_nodes_in_group("scenario_fort"):
			if is_instance_valid(fort) and not bool(fort.get("is_captured")):
				return fort

	var best: Node = null
	var best_score := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("is_sunk")):
			continue
		var distance := player_ship.global_position.distance_to(enemy.global_position) if player_ship and enemy is Node3D else 9999.0
		var health_ratio := float(enemy.get("health")) / maxf(float(enemy.get("max_health")), 1.0)
		var cripple_bonus := -80.0 if _is_boardable(enemy) else 0.0
		var score := distance + health_ratio * 45.0 + cripple_bonus
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _set_pause_menu(paused: bool) -> void:
	if campaign_map_open:
		return

	get_tree().paused = paused
	if camera:
		camera.set_input_enabled(not paused)
		camera.set_aiming(false)
	if player_ship:
		player_ship.set("accepts_player_input", not paused)

	if hud:
		hud.show_pause_menu(paused)
		hud.set_aim_state(false, 0, false)
	if aim_guide and aim_guide.has_method("hide_solution"):
		aim_guide.hide_solution()

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _apply_settings(settings: Dictionary) -> void:
	if camera and camera.has_method("apply_settings"):
		camera.apply_settings(settings)
	if hud and hud.has_method("apply_settings"):
		hud.apply_settings(settings)
	if DisplayServer.get_name() != "headless" and settings.has("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.get("fullscreen", true)) else DisplayServer.WINDOW_MODE_WINDOWED)


func _quit_game() -> void:
	get_tree().quit()


func _create_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "BattleEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.025, 0.115, 0.225)
	sky_material.sky_horizon_color = Color(0.48, 0.70, 0.76)
	sky_material.ground_bottom_color = Color(0.012, 0.028, 0.036)
	sky_material.ground_horizon_color = Color(0.075, 0.205, 0.225)
	sky_material.sky_curve = 0.12
	sky_material.sky_energy_multiplier = 1.08
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.07
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.61
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.31, 0.53, 0.59)
	env.fog_density = 0.00145
	env.fog_aerial_perspective = 0.56
	env.fog_sky_affect = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.ssao_enabled = true
	env.ssao_radius = 2.25
	env.ssao_intensity = 1.18
	env.ssao_power = 1.06
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.11
	env.glow_bloom = 0.035
	world_env.environment = env
	add_child(world_env)
	_world_environment = world_env

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.52
	sun.light_color = Color(1.0, 0.90, 0.72)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.35
	sun.directional_shadow_max_distance = 360.0
	sun.directional_shadow_fade_start = 0.82
	sun.rotation_degrees = Vector3(-43.0, -31.0, 0.0)
	add_child(sun)
	_sun_light = sun


func _create_ocean() -> void:
	_ocean_material = null
	_wave_fluid = FFTWaveFluid.new()
	_wave_fluid.name = "CombatWaveFluid"
	_wave_fluid.set("sea_level", -0.18)
	_wave_fluid.set("sea_state", _ocean_sea_state)
	_wave_fluid.set("wave_speed", _ocean_wave_speed)
	_wave_fluid.set("wave_chop", _ocean_wave_chop)
	_wave_fluid.set("wind_direction", Vector2(wind_direction.x, wind_direction.z))
	var fluid_collision := CollisionShape3D.new()
	var fluid_shape := BoxShape3D.new()
	fluid_shape.size = Vector3(1100.0, 40.0, 1100.0)
	fluid_collision.shape = fluid_shape
	fluid_collision.position.y = -20.18
	_wave_fluid.add_child(fluid_collision)
	add_child(_wave_fluid)

	_shore_foam_material = ShaderMaterial.new()
	_shore_foam_material.shader = ShoreFoamShader
	_shore_foam_material.set_shader_parameter("simulation_time", _ocean_time)
	_shore_foam_material.set_shader_parameter("wind_direction", Vector2(wind_direction.x, wind_direction.z))
	_shore_foam_material.set_shader_parameter("sea_state", _ocean_sea_state)


func _apply_battle_environment(config: Dictionary) -> void:
	var profile := BattleEnvironmentProfiles.build_profile(config)
	wind_direction = profile.wind_direction
	wind_strength = float(profile.wind_strength)
	_ocean_sea_state = float(profile.sea_state)
	_ocean_wave_speed = float(profile.wave_speed)
	_ocean_wave_chop = float(profile.wave_chop)
	_storm_breakers_enabled = bool(profile.storm_breakers_enabled)
	_storm_breaker_interval = Vector2(float(profile.storm_breaker_interval_min), float(profile.storm_breaker_interval_max))
	_storm_breaker_scale = float(profile.storm_breaker_scale)
	_storm_breaker_palette = {
		"deep_color": profile.deep_color,
		"face_color": profile.face_color,
		"foam_color": profile.foam_color,
	}
	if _storm_breakers_enabled:
		_rogue_wave_cooldown = randf_range(_storm_breaker_interval.x * 0.45, _storm_breaker_interval.x * 0.72)
	else:
		_clear_rogue_wave()
	_set_storm_rain(String(profile.weather) == "Storm")

	if is_instance_valid(_world_environment) and _world_environment.environment:
		var env := _world_environment.environment
		var sky_material := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
		if sky_material:
			sky_material.sky_top_color = profile.sky_top
			sky_material.sky_horizon_color = profile.sky_horizon
			sky_material.ground_bottom_color = profile.ground_bottom
			sky_material.ground_horizon_color = profile.ground_horizon
			sky_material.sky_energy_multiplier = float(profile.sky_energy)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if bool(profile.use_color_ambient) else Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_color = profile.ambient_color
		env.ambient_light_energy = float(profile.ambient_energy)
		env.fog_light_color = profile.fog_color
		env.fog_density = float(profile.fog_density)
		env.fog_aerial_perspective = float(profile.fog_aerial)
		env.fog_sky_affect = float(profile.fog_sky_affect)
		env.tonemap_exposure = float(profile.exposure)
		env.adjustment_brightness = float(profile.brightness)
		env.adjustment_contrast = float(profile.contrast)
		env.adjustment_saturation = float(profile.saturation)
	if is_instance_valid(_sun_light):
		_sun_light.light_energy = float(profile.sun_energy)
		_sun_light.light_color = profile.sun_color
		_sun_light.rotation_degrees = profile.sun_rotation

	var wind_2d := Vector2(wind_direction.x, wind_direction.z)
	if _ocean_material:
		_ocean_material.set_shader_parameter("wind_direction", wind_2d)
		_ocean_material.set_shader_parameter("sea_state", _ocean_sea_state)
		_ocean_material.set_shader_parameter("wave_speed", profile.wave_speed)
		_ocean_material.set_shader_parameter("wave_chop", profile.wave_chop)
		_ocean_material.set_shader_parameter("foam_strength", profile.foam_strength)
		_ocean_material.set_shader_parameter("abyss_color", profile.abyss_color)
		_ocean_material.set_shader_parameter("deep_color", profile.deep_color)
		_ocean_material.set_shader_parameter("face_color", profile.face_color)
		_ocean_material.set_shader_parameter("foam_color", profile.foam_color)
		_ocean_material.set_shader_parameter("ambient_lift", profile.ocean_emission)
	if _wave_fluid:
		if _wave_fluid.has_method("configure_profile"):
			_wave_fluid.call("configure_profile", profile)
		else:
			_wave_fluid.set("sea_state", _ocean_sea_state)
			_wave_fluid.set("wave_speed", profile.wave_speed)
			_wave_fluid.set("wave_chop", profile.wave_chop)
			_wave_fluid.set("wind_direction", wind_2d)
	if _shore_foam_material:
		_shore_foam_material.set_shader_parameter("wind_direction", wind_2d)
		_shore_foam_material.set_shader_parameter("sea_state", _ocean_sea_state)
		_shore_foam_material.set_shader_parameter("foam_color", profile.foam_color)

	for ship_node in get_tree().get_nodes_in_group("ships"):
		ship_node.set("wind_direction", wind_direction)
		ship_node.set("wind_strength", wind_strength)
		if ship_node.has_method("set_ocean_wave_profile"):
			ship_node.call("set_ocean_wave_profile", profile.sea_state, profile.wave_speed, profile.wave_chop)


func _set_storm_rain(enabled: bool) -> void:
	if not is_instance_valid(_storm_rain):
		_storm_rain = StormRain.new()
		add_child(_storm_rain)
	_storm_rain.emitting = enabled
	_storm_rain.visible = enabled


func _update_rogue_wave(delta: float) -> void:
	if not _storm_breakers_enabled:
		if is_instance_valid(active_rogue_wave):
			_clear_rogue_wave()
		return
	if is_instance_valid(active_rogue_wave):
		if boarding_sequence_active or is_instance_valid(boarding_resolution_target):
			return
		var player_distance := float(active_rogue_wave.call("distance_to_front", player_ship.global_position)) if is_instance_valid(player_ship) else 999.0
		if player_distance < 58.0 and player_distance > 2.0 and not _rogue_wave_near_warned:
			_rogue_wave_near_warned = true
		_resolve_rogue_wave_crossings()
		return

	active_rogue_wave = null
	if main_menu_open or campaign_map_open or mission_complete or player_sunk or battle_mode not in ["custom", "campaign"]:
		return
	if boarding_sequence_active or is_instance_valid(boarding_resolution_target) or enemies.is_empty():
		return
	_rogue_wave_cooldown = maxf(_rogue_wave_cooldown - delta, 0.0)
	if _rogue_wave_cooldown <= 0.0:
		_spawn_rogue_wave()


func _spawn_rogue_wave(source_direction := Vector3.ZERO) -> void:
	if not is_instance_valid(player_ship) or is_instance_valid(active_rogue_wave):
		return
	var from_player := Vector3(source_direction.x, 0.0, source_direction.z).normalized()
	if from_player.length_squared() < 0.01:
		var angle := randf_range(0.0, TAU)
		from_player = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	var origin := player_ship.global_position + from_player * 150.0
	var wave := RogueWave.new()
	wave.name = "StormBreaker"
	wave.configure(origin, -from_player, randf_range(14.0, 15.5) * _storm_breaker_scale, 220.0 * _storm_breaker_scale, _storm_breaker_scale, _storm_breaker_palette)
	add_child(wave)
	wave.connect("expired", Callable(self, "_on_rogue_wave_expired"))
	active_rogue_wave = wave
	_rogue_wave_impacted.clear()
	_rogue_wave_warning_timer = 0.0
	_rogue_wave_near_warned = false
	_rogue_wave_cooldown = randf_range(_storm_breaker_interval.x, _storm_breaker_interval.y)


func _resolve_rogue_wave_crossings() -> void:
	if not is_instance_valid(active_rogue_wave):
		return
	for ship_node in get_tree().get_nodes_in_group("ships"):
		if not (ship_node is Node3D) or bool(ship_node.get("is_sunk")):
			continue
		var ship := ship_node as Node3D
		var ship_id := ship.get_instance_id()
		if _rogue_wave_impacted.has(ship_id):
			continue
		var distance := float(active_rogue_wave.call("distance_to_front", ship.global_position))
		if distance > 2.4:
			continue
		_rogue_wave_impacted[ship_id] = true
		_resolve_rogue_wave_impact(ship)


func _resolve_rogue_wave_impact(ship: Node3D) -> void:
	var travel_direction: Vector3 = active_rogue_wave.get("travel_direction")
	var is_player := ship == player_ship
	var bracing := bool(ship.get("is_bracing")) if is_player else false
	var protected := bracing
	var severity := 0.20 if protected else (minf(0.72 * _storm_breaker_scale, 0.92) if is_player else minf(0.48 * _storm_breaker_scale, 0.70))
	if ship.has_method("apply_rogue_wave_impact"):
		ship.call("apply_rogue_wave_impact", travel_direction, severity, protected)
	CombatFx.spawn_rogue_wave_impact(get_tree().current_scene if get_tree().current_scene else self, ship.global_position, severity)
	if not is_player:
		return
	var local_wave := player_ship.global_transform.basis.inverse() * travel_direction
	var impact_side := signf(local_wave.x) if absf(local_wave.x) > 0.06 else 1.0
	if camera and camera.has_method("add_rogue_wave_impulse"):
		camera.add_rogue_wave_impulse(severity, impact_side)
	if combat_audio:
		combat_audio.apply_impact_duck(0.52 if protected else severity)


func _on_rogue_wave_expired(wave: Node3D) -> void:
	if wave == active_rogue_wave:
		active_rogue_wave = null
		_rogue_wave_impacted.clear()


func _clear_rogue_wave() -> void:
	if is_instance_valid(active_rogue_wave):
		active_rogue_wave.queue_free()
	active_rogue_wave = null
	_rogue_wave_impacted.clear()
	_rogue_wave_warning_timer = 0.0
	_rogue_wave_near_warned = false
	_rogue_wave_cooldown = randf_range(_storm_breaker_interval.x, _storm_breaker_interval.y) if _storm_breakers_enabled else 999.0


func _create_islands() -> void:
	island_markers.clear()
	var island_data := [
		{"pos": Vector3(-70.0, 0.0, -95.0), "radius": 24.0},
		{"pos": Vector3(95.0, 0.0, 70.0), "radius": 19.0},
		{"pos": Vector3(-125.0, 0.0, 95.0), "radius": 13.0},
	]

	for data in island_data:
		_create_island(data.pos, data.radius)
		island_markers.append({"position": data.pos, "radius": data.radius})


func _create_island(pos: Vector3, radius: float) -> StaticBody3D:
	var island := StaticBody3D.new()
	island.name = "Island_%d" % island_markers.size()
	island.position = pos
	island.add_to_group("island_obstacle")
	island.set_meta("collision_radius", radius * 0.78)
	add_child(island)

	var sand_mat := _make_material(Color(0.76, 0.66, 0.45), 0.9)
	var green_mat := _make_material(Color(0.10, 0.26, 0.13), 0.8)

	var beach := MeshInstance3D.new()
	var beach_mesh := CylinderMesh.new()
	beach_mesh.top_radius = radius * 0.72
	beach_mesh.bottom_radius = radius
	beach_mesh.height = 2.0
	beach_mesh.radial_segments = 32
	beach.mesh = beach_mesh
	beach.position.y = -0.85
	beach.material_override = sand_mat
	island.add_child(beach)

	var hill := MeshInstance3D.new()
	var hill_mesh := SphereMesh.new()
	hill_mesh.radius = radius * 0.48
	hill_mesh.height = radius * 0.65
	hill_mesh.radial_segments = 24
	hill_mesh.rings = 12
	hill.mesh = hill_mesh
	hill.scale = Vector3(1.15, 0.55, 0.95)
	hill.position = Vector3(0.0, 1.0, 0.0)
	hill.material_override = green_mat
	island.add_child(hill)
	_create_shore_foam(island, radius)

	_populate_island_nature(island, radius)

	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.78
	shape.height = 5.0
	collider.shape = shape
	collider.position.y = 0.4
	island.add_child(collider)

	if radius >= 19.0:
		var dock := PirateKitAssets.instantiate_prop("dock")
		if dock:
			dock.name = "PirateKitDock"
			dock.position = Vector3(radius * 0.72, -0.05, radius * 0.08)
			dock.rotation.y = PI * 0.5
			dock.scale = Vector3.ONE * 1.15
			island.add_child(dock)
	return island


func _create_shore_foam(island: Node3D, radius: float) -> void:
	if _shore_foam_material == null:
		return
	var foam := MeshInstance3D.new()
	foam.name = "ShoreBreak"
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.extra_cull_margin = 3.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 96
	var inner_radius := radius * 0.76
	var outer_radius := radius * 1.06
	for index in range(segments):
		var t0 := float(index) / float(segments)
		var t1 := float(index + 1) / float(segments)
		var angle0 := t0 * TAU
		var angle1 := t1 * TAU
		var inner0 := Vector3(cos(angle0) * inner_radius, -0.14, sin(angle0) * inner_radius)
		var outer0 := Vector3(cos(angle0) * outer_radius, -0.14, sin(angle0) * outer_radius)
		var inner1 := Vector3(cos(angle1) * inner_radius, -0.14, sin(angle1) * inner_radius)
		var outer1 := Vector3(cos(angle1) * outer_radius, -0.14, sin(angle1) * outer_radius)
		_add_shore_foam_vertex(surface, inner0, Vector2(0.0, t0))
		_add_shore_foam_vertex(surface, outer0, Vector2(1.0, t0))
		_add_shore_foam_vertex(surface, outer1, Vector2(1.0, t1))
		_add_shore_foam_vertex(surface, inner0, Vector2(0.0, t0))
		_add_shore_foam_vertex(surface, outer1, Vector2(1.0, t1))
		_add_shore_foam_vertex(surface, inner1, Vector2(0.0, t1))
	foam.mesh = surface.commit()
	foam.material_override = _shore_foam_material
	island.add_child(foam)


func _add_shore_foam_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_uv(uv)
	surface.add_vertex(point)


func _populate_island_nature(island: Node3D, radius: float) -> void:
	var palm_count := clampi(roundi(radius * 0.28), 4, 7)
	var bush_count := clampi(roundi(radius * 0.22), 3, 6)
	var ground_count := clampi(roundi(radius * 0.32), 4, 8)
	var rock_count := clampi(roundi(radius * 0.20), 3, 5)
	var forest_count := clampi(roundi(radius * 0.15), 2, 4)
	var flower_count := clampi(roundi(radius * 0.16), 2, 4)

	for i in range(palm_count):
		_spawn_nature(island, "palm", radius, 0.12, 0.48, 0.82, 1.16, false)
	for i in range(bush_count):
		_spawn_nature(island, "bush", radius, 0.15, 0.58, 0.75, 1.25, true)
	for i in range(ground_count):
		_spawn_nature(island, "ground", radius, 0.18, 0.62, 0.85, 1.45, true)
	for i in range(rock_count):
		_spawn_nature(island, "rock", radius, 0.52, 0.84, 1.15, 2.15, false, 0.12)
	for i in range(forest_count):
		_spawn_nature(island, "forest", radius, 0.12, 0.44, 0.66, 0.96, false)
	for i in range(flower_count):
		_spawn_nature(island, "flowers", radius, 0.18, 0.60, 0.82, 1.28, true)
	if radius >= 18.0:
		_spawn_nature(island, "dead_tree", radius, 0.16, 0.40, 0.72, 1.0, false)


func _spawn_nature(
	parent: Node3D,
	group_name: String,
	radius: float,
	min_radius_ratio: float,
	max_radius_ratio: float,
	min_scale: float,
	max_scale: float,
	disable_shadows: bool,
	fixed_height: float = -1.0
) -> void:
	var asset := NatureAssets.instantiate(group_name)
	if asset == null:
		return
	var angle := randf() * TAU
	var distance := randf_range(radius * min_radius_ratio, radius * max_radius_ratio)
	var local_pos := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	local_pos.y = fixed_height if fixed_height >= 0.0 else _island_surface_height(local_pos, radius)
	asset.name = "Nature_%s_%d" % [group_name.capitalize(), parent.get_child_count()]
	asset.position = local_pos
	asset.rotation.y = randf() * TAU
	var uniform_scale := randf_range(min_scale, max_scale)
	asset.scale = Vector3.ONE * uniform_scale
	parent.add_child(asset)
	for child in asset.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		mesh_instance.visibility_range_end = 280.0
		if disable_shadows:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _island_surface_height(local_pos: Vector3, radius: float) -> float:
	var x_ratio := local_pos.x / maxf(radius * 0.56, 0.01)
	var z_ratio := local_pos.z / maxf(radius * 0.46, 0.01)
	var radial := x_ratio * x_ratio + z_ratio * z_ratio
	if radial >= 1.0:
		return 0.12
	return 0.12 + sqrt(1.0 - radial) * radius * 0.17


func _spawn_player() -> void:
	player_ship = PlayerShip.new()
	player_ship.name = "PlayerShip"
	player_ship.display_name = "Sable Wake"
	player_ship.team_id = 0
	player_ship.wind_direction = wind_direction
	player_ship.wind_strength = wind_strength
	player_ship.set_ocean_wave_profile(_ocean_sea_state, _ocean_wave_speed, _ocean_wave_chop)
	player_ship.position = Vector3(0.0, 0.0, 24.0)
	player_ship.rotation_degrees.y = 180.0
	player_ship.sunk.connect(_on_player_sunk)
	player_ship.broadside_fired.connect(_on_player_broadside_fired)
	player_ship.hit_reported.connect(_on_ship_hit_reported)
	player_ship.near_missed.connect(_on_player_near_missed)
	add_child(player_ship)


func _spawn_enemies(region: Dictionary = {}) -> void:
	var spawn_data := _build_sortie_spawn_data(region)
	var leader: Node3D = null
	for data in spawn_data:
		var ship := _spawn_ai_ship(data, 1, leader)
		if leader == null and ship is Node3D:
			leader = ship
	for enemy in enemies:
		if is_instance_valid(enemy) and String(enemy.get("ai_role")) == "escort":
			enemy.set("formation_anchor_ship", leader)


func _spawn_ai_ship(data: Dictionary, ship_team: int, anchor: Node3D = null) -> Node:
	var ship := EnemyShip.new()
	var fleet_index := allies.size() if ship_team == 0 else enemies.size()
	var resolved_data := data.duplicate(true)
	var hull_type := String(resolved_data.get("hull_class", _hull_for_role(String(resolved_data.get("role", "Raider")))))
	var class_profile := _ship_profile(hull_type)
	for key in ["health", "max_speed", "acceleration", "turn_rate", "damage", "shot_speed", "reload", "cannons"]:
		if not resolved_data.has(key):
			resolved_data[key] = class_profile.get(key)
	ship.name = "AlliedShip" if ship_team == 0 else "RivalShip"
	ship.wind_direction = wind_direction
	ship.wind_strength = wind_strength
	ship.set_ocean_wave_profile(_ocean_sea_state, _ocean_wave_speed, _ocean_wave_chop)
	ship.side_preference = int(resolved_data.get("side", 1))
	ship.position = resolved_data.get("pos", Vector3.ZERO)
	ship.rotation_degrees.y = float(resolved_data.get("rot", 0.0))
	ship.set_hull_class(hull_type)
	ship.configure_ai(ship_team, String(resolved_data.get("role", "Raider")), anchor, resolved_data.get("station", ship.position))
	ship.configure_fleet_slot(fleet_index)
	ship.target_ship = player_ship if ship_team == 1 else null
	ship.display_name = String(resolved_data.get("name", "Allied Ship" if ship_team == 0 else "Rival Ship"))
	_apply_enemy_spawn_profile(ship, resolved_data)
	ship.sunk.connect(_on_ai_ship_sunk)
	ship.retreated.connect(_on_ai_ship_retreated)
	ship.hit_reported.connect(_on_ship_hit_reported)
	ship.broadside_warning.connect(_on_enemy_broadside_warning)
	add_child(ship)
	if ship_team == 0:
		allies.append(ship)
	else:
		enemies.append(ship)
	return ship


func _apply_enemy_spawn_profile(enemy: Node, data: Dictionary) -> void:
	var class_profile := _ship_profile(String(enemy.get("hull_class")))
	var class_health := float(class_profile.get("health", 135.0))
	var requested_health := float(data.get("health", class_health))
	enemy.set("max_health", clampf(requested_health, class_health * 0.78, class_health * 1.22))
	enemy.set("health", float(enemy.get("max_health")))
	var class_speed := float(class_profile.get("max_speed", 12.5))
	enemy.set("max_speed", clampf(float(data.get("max_speed", class_speed)), class_speed * 0.92, class_speed * 1.06))
	enemy.set("acceleration", float(data.get("acceleration", class_profile.get("acceleration", 4.0))))
	enemy.set("deceleration", float(data.get("deceleration", class_profile.get("deceleration", 3.2))))
	enemy.set("turn_rate", float(data.get("turn_rate", class_profile.get("turn_rate", 0.80))))
	enemy.set("rudder_response", float(data.get("rudder_response", class_profile.get("rudder_response", 1.85))))
	enemy.set("rudder_return_speed", float(data.get("rudder_return_speed", class_profile.get("rudder_return_speed", 2.55))))
	enemy.set("sail_change_rate", float(data.get("sail_change_rate", class_profile.get("sail_change_rate", 0.52))))
	enemy.set("cannon_shot_speed", float(data.get("shot_speed", 44.0)))
	var class_damage := float(class_profile.get("damage", 5.5))
	enemy.set("cannon_damage", clampf(float(data.get("damage", class_damage)), class_damage * 0.85, class_damage * 1.18))
	enemy.set("cannon_reload", float(data.get("reload", 3.2)))
	enemy.set("base_cannons_per_side", int(data.get("cannons", 4)))
	enemy.set_meta("campaign_role", String(data.get("role", "")))
	enemy.set_meta("campaign_faction", String(data.get("faction", "")))
	enemy.set_meta("campaign_strength", int(data.get("strength", 0)))
	enemy.set_meta("campaign_crew", int(data.get("crew", maxi(int(float(enemy.get("max_health")) * 0.42), 20))))
	enemy.set_meta("campaign_morale", int(data.get("morale", 50)))
	if bool(data.get("scenario_convoy", false)):
		enemy.set_meta("scenario_convoy", true)
	if enemy.has_signal("health_changed"):
		enemy.health_changed.emit(float(enemy.get("health")), float(enemy.get("max_health")))


func _build_sortie_spawn_data(region: Dictionary = {}) -> Array[Dictionary]:
	if region.has("encounter_party"):
		return _build_encounter_spawn_data(region.get("encounter_party", {}))
	return _build_region_spawn_data(region)


func _build_region_spawn_data(region: Dictionary = {}) -> Array[Dictionary]:
	var faction := String(region.get("faction", "Independent"))
	var region_name := String(region.get("name", "Open Sea"))
	var dangerous := ["Unclaimed", "Crown Dominion", "Trade Route", "Uncharted"].has(faction)
	var spawn_data: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.0, -82.0), "rot": 10.0, "side": 1, "name": "Rival Sloop", "role": "Raider"},
		{"pos": Vector3(65.0, 0.0, -30.0), "rot": -70.0, "side": -1, "name": "Patrol Cutter", "role": "Escort"},
		{"pos": Vector3(-82.0, 0.0, 36.0), "rot": 115.0, "side": 1, "name": "Privateer Brig", "role": "Raider"},
	]
	if dangerous:
		spawn_data.append({"pos": Vector3(92.0, 0.0, 58.0), "rot": -128.0, "side": -1, "name": "%s Hunter" % region_name, "role": "Line Ship"})
	return spawn_data


func _build_encounter_spawn_data(party: Dictionary) -> Array[Dictionary]:
	var role := String(party.get("role", "Fleet"))
	var stance := String(party.get("stance", "neutral"))
	var intent := String(party.get("intent", ""))
	var strength := int(party.get("strength", 60))
	var party_name := String(party.get("name", "Fleet"))
	var role_key := role.to_lower()
	var count := clampi(1 + int(round(float(strength) / 70.0)), 1, 3)
	var health_scale := clampf(float(strength) / 92.0, 0.62, 1.35)
	var speed_scale := 1.0
	var formation := [
		{"pos": Vector3(0.0, 0.0, -78.0), "rot": 4.0, "side": 1},
		{"pos": Vector3(52.0, 0.0, -46.0), "rot": -42.0, "side": -1},
		{"pos": Vector3(-56.0, 0.0, -38.0), "rot": 42.0, "side": 1},
		{"pos": Vector3(74.0, 0.0, 24.0), "rot": -102.0, "side": -1},
		{"pos": Vector3(-82.0, 0.0, 30.0), "rot": 112.0, "side": 1},
	]

	if intent == "investigating pressure":
		count = clampi(count, 2, 3)
		health_scale = maxf(health_scale, 0.96)
		speed_scale = 1.08
		formation = [
			{"pos": Vector3(0.0, 0.0, -46.0), "rot": 8.0, "side": 1},
			{"pos": Vector3(38.0, 0.0, -18.0), "rot": -62.0, "side": -1},
			{"pos": Vector3(-38.0, 0.0, -18.0), "rot": 62.0, "side": 1},
			{"pos": Vector3(0.0, 0.0, 34.0), "rot": 180.0, "side": -1},
		]
	elif role_key.contains("courier"):
		count = 1
		health_scale = 0.68
		speed_scale = 1.34
		formation = [{"pos": Vector3(0.0, 0.0, -96.0), "rot": 0.0, "side": 1}]
	elif role_key.contains("treasure") or role_key.contains("merchant"):
		count = clampi(count + 1, 2, 3)
		health_scale = maxf(health_scale, 1.02)
		speed_scale = 0.86
	elif role_key.contains("raider") or role_key.contains("bounty") or stance == "chase":
		count = clampi(count, 1, 3)
		health_scale = maxf(health_scale, 0.86)
		speed_scale = 1.12
		formation = [
			{"pos": Vector3(0.0, 0.0, -58.0), "rot": 7.0, "side": 1},
			{"pos": Vector3(45.0, 0.0, -26.0), "rot": -54.0, "side": -1},
			{"pos": Vector3(-45.0, 0.0, -22.0), "rot": 54.0, "side": 1},
			{"pos": Vector3(18.0, 0.0, 28.0), "rot": 172.0, "side": -1},
		]
	elif role_key.contains("patrol") or role_key.contains("escort") or role_key.contains("blockade"):
		count = clampi(count, 2, 3)
		health_scale = maxf(health_scale, 0.96)

	var spawn_data: Array[Dictionary] = []
	for i in range(mini(count, formation.size())):
		var slot: Dictionary = formation[i]
		spawn_data.append({
			"pos": slot.get("pos", Vector3.ZERO),
			"rot": float(slot.get("rot", 0.0)),
			"side": int(slot.get("side", 1)),
			"name": _encounter_enemy_name(party_name, role, i),
			"role": role if i == 0 else "Escort",
			"faction": String(party.get("faction", "")),
			"strength": strength,
			"health": 104.0 * health_scale * (1.10 if i == 0 else 0.92),
			"damage": 6.8 * clampf(health_scale, 0.82, 1.08),
			"max_speed": 12.5 * speed_scale * (1.05 if i == 0 else 1.0),
			"shot_speed": 44.0 * clampf(health_scale, 0.90, 1.18),
		})
	return spawn_data


func _encounter_enemy_name(party_name: String, role: String, index: int) -> String:
	if index == 0:
		return party_name
	var suffixes := ["Escort", "Wing", "Rear Guard", "Cutter", "Brig"]
	return "%s %s" % [role, suffixes[(index - 1) % suffixes.size()]]


func _create_camera() -> void:
	camera = SmoothShipCamera.new()
	camera.name = "ShipCamera"
	camera.target = player_ship
	add_child(camera)
	camera.current = true


func _create_aim_guide() -> void:
	aim_guide = AimGuide.new()
	aim_guide.name = "AimGuide"
	add_child(aim_guide)


func _create_danger_guide() -> void:
	danger_guide = BroadsideDangerGuide.new()
	danger_guide.name = "BroadsideDangerGuide"
	add_child(danger_guide)


func _create_hud() -> void:
	hud = Hud.new()
	hud.name = "HUD"
	hud.resume_requested.connect(_on_resume_requested)
	hud.return_to_campaign_requested.connect(_on_return_to_campaign_requested)
	hud.settings_changed.connect(_apply_settings)
	hud.quit_requested.connect(_quit_game)
	add_child(hud)


func _create_mortar_targeting_ui() -> void:
	mortar_targeting_ui = MortarTargetingUi.new()
	mortar_targeting_ui.name = "MortarTargetingUi"
	mortar_targeting_ui.target_selected.connect(_on_mortar_target_selected)
	mortar_targeting_ui.closed.connect(_on_mortar_targeting_closed)
	add_child(mortar_targeting_ui)


func _is_mortar_targeting_open() -> bool:
	return mortar_targeting_ui != null and mortar_targeting_ui.has_method("is_open") and mortar_targeting_ui.is_open()


func _open_mortar_targeting() -> void:
	if player_ship == null or player_sunk or mission_complete:
		return
	var telemetry: Dictionary = player_ship.get_telemetry()
	if not bool(telemetry.get("has_mortar", false)):
		if hud:
			hud.show_banner("No mortar battery", "Ship of the Line and Man o' War carry mortar batteries.", 1.8)
		return
	if camera:
		camera.set_aiming(false)
		camera.set_input_enabled(false)
	if player_ship.has_method("set_aim_focus"):
		player_ship.set_aim_focus(1.0)
	player_ship.set("accepts_player_input", true)
	player_ship.set("navigation_input_only", true)
	if aim_guide and aim_guide.has_method("hide_solution"):
		aim_guide.hide_solution()
	if hud:
		hud.set_aim_state(false, 0, false)
	mortar_targeting_ui.open(player_ship, enemies, 168.0)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_mortar_targeting() -> void:
	if _is_mortar_targeting_open():
		mortar_targeting_ui.close()


func _on_mortar_targeting_closed() -> void:
	if camera and not get_tree().paused and not campaign_map_open and not main_menu_open:
		camera.set_input_enabled(true)
	if player_ship:
		player_ship.set("navigation_input_only", false)
	if player_ship and not get_tree().paused and not campaign_map_open and not main_menu_open:
		player_ship.set("accepts_player_input", true)
	if DisplayServer.get_name() != "headless" and not get_tree().paused and not campaign_map_open and not main_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_mortar_target_selected(world_position: Vector3) -> void:
	if player_ship == null or not player_ship.has_method("fire_mortar"):
		return
	if player_ship.fire_mortar(world_position):
		_close_mortar_targeting()
	elif hud:
		var reload := float(player_ship.get_telemetry().get("mortar_reload", 0.0))
		hud.show_banner("Mortars reloading", "Battery ready in %.1f seconds." % reload, 1.5)


func _create_campaign_map() -> void:
	campaign_map = CampaignMapUi.new()
	campaign_map.name = "CampaignMap"
	campaign_map.deploy_requested.connect(_on_campaign_deploy_requested)
	campaign_map.close_requested.connect(_on_campaign_map_close_requested)
	add_child(campaign_map)


func _create_main_menu() -> void:
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	main_menu.campaign_requested.connect(_on_main_campaign_requested)
	main_menu.custom_battle_requested.connect(_on_custom_battle_requested)
	main_menu.handling_lab_requested.connect(_on_handling_lab_requested)
	main_menu.combat_sandbox_requested.connect(_on_combat_sandbox_requested)
	main_menu.quit_requested.connect(_quit_game)
	add_child(main_menu)


func _show_main_menu() -> void:
	_close_mortar_targeting()
	if is_instance_valid(combat_sandbox):
		combat_sandbox.close()
	battle_mode = "menu"
	main_menu_open = true
	campaign_map_open = false
	get_tree().paused = true
	_clear_sortie_entities()
	if campaign_map and campaign_map.has_method("hide_map"):
		campaign_map.hide_map()
	if hud:
		hud.visible = false
		hud.show_pause_menu(false)
	if player_ship:
		player_ship.set("accepts_player_input", false)
	if camera:
		camera.set_input_enabled(false)
		camera.set_aiming(false)
	if main_menu and main_menu.has_method("show_menu"):
		main_menu.show_menu()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_main_menu() -> void:
	main_menu_open = false
	if main_menu and main_menu.has_method("hide_menu"):
		main_menu.hide_menu()


func _on_main_campaign_requested() -> void:
	_hide_main_menu()
	battle_mode = "campaign"
	campaign_started = false
	_apply_battle_environment(BattleEnvironmentProfiles.default_config())
	_apply_player_ship_profile("Brig")
	if hud and hud.has_method("set_return_destination"):
		hud.set_return_destination("Return to Campaign")
	_open_campaign_map(false)


func _on_custom_battle_requested(config: Dictionary) -> void:
	_hide_main_menu()
	battle_mode = "custom"
	campaign_started = false
	custom_battle_config = config.duplicate(true)
	if hud and hud.has_method("set_return_destination"):
		hud.set_return_destination("Return to Main Menu")
	_prepare_custom_battle(custom_battle_config)


func _on_handling_lab_requested(config: Dictionary) -> void:
	BattleEnvironmentProfiles.set_pending_lab_config(config)
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://scenes/ship_handling_lab.tscn")


func _on_combat_sandbox_requested() -> void:
	var config := {
		"scenario_id": "combat_sandbox",
		"title": "Combat Sandbox",
		"brief": "Trigger every combat state instantly.",
		"objective": "sandbox",
		"objective_title": "Combat Sandbox",
		"objective_detail": "Use the laboratory panel to control the battle.",
		"player_type": "Man o' War",
		"allies": {"Frigate": 1},
		"enemies": {"Raider": 1, "Frigate": 1, "Ship of the Line": 1},
		"weather": "Clear",
		"time_of_day": "Day",
		"sea_condition": "Rolling",
		"player_spawn": Vector3(0.0, 0.0, 48.0),
		"player_rotation": 0.0,
		"max_active_ships": 8,
		"forts": [{"name": "Sandbox Fort", "position": Vector3(92.0, 0.0, -62.0), "island_radius": 21.0, "style": "battery", "health": 360.0, "guns": 3, "range": 220.0, "reload": 6.0}],
		"scenario_islands": [{"position": Vector3(-105.0, 0.0, -72.0), "radius": 13.0}],
	}
	_on_custom_battle_requested(config)
	if not is_instance_valid(combat_sandbox):
		combat_sandbox = CombatSandbox.new()
		combat_sandbox.name = "CombatSandbox"
		add_child(combat_sandbox)
	combat_sandbox.call_deferred("open", self)


func get_combat_sandbox_targets() -> Array:
	var targets: Array = []
	for target in enemies:
		if is_instance_valid(target):
			targets.append(target)
	return targets


func set_combat_sandbox_panel_open(panel_open: bool) -> void:
	if battle_mode != "custom" or custom_scenario_id != "combat_sandbox":
		return
	if camera:
		camera.set_input_enabled(not panel_open)
		camera.set_aiming(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel_open else Input.MOUSE_MODE_CAPTURED


func apply_combat_sandbox_environment(weather: String, time_of_day: String, sea_condition: String) -> void:
	if custom_scenario_id != "combat_sandbox":
		return
	custom_battle_config["weather"] = weather
	custom_battle_config["time_of_day"] = time_of_day
	custom_battle_config["sea_condition"] = sea_condition
	_apply_battle_environment({
		"weather": weather,
		"time_of_day": time_of_day,
		"sea_condition": sea_condition,
	})


func combat_sandbox_action(action: String, target: Node = null, value: Variant = null) -> String:
	if custom_scenario_id != "combat_sandbox" or not is_instance_valid(player_ship):
		return "Enter Combat Sandbox first."
	match action:
		"set_ai":
			_set_combat_sandbox_ai(bool(value))
			return "Live AI enabled." if bool(value) else "AI frozen."
		"target_light_hit":
			return _sandbox_damage_target(target, 0.08, 1.2, "Light hull impact applied.")
		"target_heavy_hit":
			return _sandbox_damage_target(target, 0.26, 1.5, "Heavy broadside impact applied.")
		"target_rig_hit":
			return _sandbox_damage_target(target, 0.10, 7.5, "High rigging impact applied.")
		"target_gun_hit":
			return _sandbox_damage_target(target, 0.15, 1.0, "Gun deck impact applied.", true)
		"target_boarding_ready":
			return _sandbox_prepare_boarding(target, false)
		"start_boarding":
			return _sandbox_prepare_boarding(target, true)
		"target_foundering":
			if not _sandbox_is_ship(target):
				return "Select a ship target."
			target.incapacitate_for_boarding()
			return "Target disabled; foundering timer started."
		"target_sink":
			if not _sandbox_is_ship(target):
				return "Select a ship target."
			target.disable_ship(false)
			return "Class-specific sinking sequence started."
		"player_broadside":
			return _sandbox_player_broadside(target)
		"incoming_salvo":
			return _sandbox_incoming_salvo(target)
		"mortar_strike":
			if not is_instance_valid(target):
				return "Select a target."
			player_ship.set("_mortar_reload", 0.0)
			return "Mortar battery fired." if player_ship.fire_mortar(target.global_position) else "This command ship has no mortar battery."
		"reload_all":
			player_ship.set("_port_reload", 0.0)
			player_ship.set("_starboard_reload", 0.0)
			player_ship.set("_mortar_reload", 0.0)
			return "All player batteries are ready."
		"damage_player":
			var source: Node = target if is_instance_valid(target) else null
			var incoming: Vector3 = (player_ship.global_position - target.global_position).normalized() if is_instance_valid(target) else Vector3.FORWARD
			player_ship.take_projectile_hit(player_ship.max_health * 0.22, source, player_ship.global_position + Vector3.UP * 1.4, incoming)
			return "Player damage and crew reaction triggered."
		"repair_player":
			player_ship.repair(player_ship.max_health * 0.38)
			return "Emergency hull repair applied."
		"restore_player":
			player_ship.reset_for_sortie()
			return "Player ship fully restored."
		"rogue_wave":
			_clear_rogue_wave()
			_spawn_rogue_wave(Vector3(1.0, 0.0, 0.25).normalized())
			return "Rogue wave approaching the test ship."
		"expose_fort":
			var fort := _sandbox_fort(target)
			if fort == null:
				return "Select the fort target."
			fort.take_damage(fort.max_health * 0.80, player_ship)
			return "Fort batteries and keep destroyed; magazine exposed."
		"capture_fort":
			var fort := _sandbox_fort(target)
			if fort == null:
				return "Select the fort target."
			fort.take_damage(fort.max_health * 2.0, player_ship)
			return "Fort assault and capture sequence started."
		"reset_lab":
			_prepare_custom_battle(custom_battle_config)
			call_deferred("_set_combat_sandbox_ai", false)
			return "Entire laboratory reset."
		"clear_projectiles":
			for projectile in get_tree().get_nodes_in_group("cannonballs"):
				if is_instance_valid(projectile):
					projectile.queue_free()
			return "Active projectiles cleared."
	return "Unknown sandbox action."


func _set_combat_sandbox_ai(enabled: bool) -> void:
	for ship in allies + enemies:
		if not is_instance_valid(ship):
			continue
		if ship.is_in_group("scenario_fort"):
			ship.process_mode = Node.PROCESS_MODE_INHERIT
			ship.set("_reload", 0.0 if enabled else 999.0)
		else:
			ship.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


func _sandbox_damage_target(target: Node, ratio: float, local_height: float, message: String, gun_deck := false) -> String:
	if not is_instance_valid(target) or not target.has_method("take_projectile_hit"):
		return "Select a valid target."
	var side := -1.0 if gun_deck else 1.0
	var width := float(target.get("_hull_width")) if target.get("_hull_width") != null else 8.0
	var hit_position: Vector3 = target.global_position + target.global_transform.basis.x.normalized() * width * 0.42 * side + Vector3.UP * local_height
	var incoming: Vector3 = (hit_position - player_ship.global_position).normalized()
	target.take_projectile_hit(float(target.get("max_health")) * ratio, player_ship, hit_position, incoming)
	return message


func _sandbox_is_ship(target: Node) -> bool:
	return is_instance_valid(target) and not target.is_in_group("scenario_fort") and target.has_method("incapacitate_for_boarding")


func _sandbox_prepare_boarding(target: Node, start_immediately: bool) -> String:
	if not _sandbox_is_ship(target):
		return "Select a ship target."
	if bool(target.get("is_sunk")):
		return "Reset the laboratory; that target has sunk."
	if not bool(target.get("is_incapacitated")):
		target.incapacitate_for_boarding()
	var player_basis := player_ship.global_transform.basis.orthonormalized()
	var spacing := float(player_ship.get("_hull_width")) * 0.46 + float(target.get("_hull_width")) * 0.46 + 0.95
	target.global_transform = Transform3D(player_basis, player_ship.global_position + player_basis.x.normalized() * spacing)
	player_ship.set("speed", 0.0)
	player_ship.set("velocity", Vector3.ZERO)
	if target.has_method("stop_water_motion"):
		target.stop_water_motion()
	if start_immediately:
		_start_boarding_sequence(target)
		return "Three-stage boarding sequence started."
	return "Target placed alongside and prepared for boarding."


func _sandbox_player_broadside(target: Node) -> String:
	if not is_instance_valid(target) or bool(target.get("is_sunk")):
		return "Select a live target."
	if target is Node3D and not target.is_in_group("scenario_fort"):
		var firing_basis := player_ship.global_transform.basis.orthonormalized()
		target.global_transform = Transform3D(firing_basis, player_ship.global_position + firing_basis.x.normalized() * 68.0)
		if target.has_method("stop_water_motion"):
			target.stop_water_motion()
	var local_target: Vector3 = player_ship.to_local(target.global_position)
	var side := 1 if local_target.x >= 0.0 else -1
	player_ship.set("_port_reload", 0.0)
	player_ship.set("_starboard_reload", 0.0)
	player_ship.set_aim_focus(1.0)
	var direction: Vector3 = (target.global_position - player_ship.global_position).normalized()
	return "Focused broadside fired." if player_ship.fire_camera_broadside(direction, side, target.global_position) else "No active guns on that broadside."


func _sandbox_incoming_salvo(target: Node) -> String:
	if not _sandbox_is_ship(target) or bool(target.get("is_sunk")):
		return "Select a live enemy ship."
	var firing_basis := player_ship.global_transform.basis.orthonormalized()
	target.global_transform = Transform3D(firing_basis, player_ship.global_position + firing_basis.x.normalized() * 62.0)
	if target.has_method("stop_water_motion"):
		target.stop_water_motion()
	var local_player: Vector3 = target.to_local(player_ship.global_position)
	var side := 1 if local_player.x >= 0.0 else -1
	target.set("_port_reload", 0.0)
	target.set("_starboard_reload", 0.0)
	target.set_aim_focus(0.55)
	var direction: Vector3 = (player_ship.global_position - target.global_position).normalized()
	return "Enemy test broadside fired." if target.call("_try_fire", side, direction, player_ship.global_position, true) else "Target has no active guns on that side."


func _sandbox_fort(target: Node) -> Node:
	if is_instance_valid(target) and target.is_in_group("scenario_fort") and not bool(target.get("is_captured")):
		return target
	for fort in get_tree().get_nodes_in_group("scenario_fort"):
		if is_instance_valid(fort) and not bool(fort.get("is_captured")):
			return fort
	return null


func _prepare_custom_battle(config: Dictionary) -> void:
	_close_mortar_targeting()
	_apply_battle_environment(config)
	custom_scenario_id = String(config.get("scenario_id", config.get("id", "fleet_trial")))
	custom_scenario_definition = BattleScenarios.get_definition(custom_scenario_id)
	for key in config.keys():
		custom_scenario_definition[key] = config[key]
	custom_scenario_failed = false
	custom_scenario_expected_convoy = int((config.get("allies", {}) as Dictionary).get("Courier", 0)) if String(config.get("objective", "")) == "protect_convoy" else 0
	custom_scenario_elapsed = 0.0
	custom_scenario_spawned_waves.clear()
	custom_scenario_wave_total = (custom_scenario_definition.get("reinforcements", []) as Array).size()
	custom_scenario_control_points_expected = (custom_scenario_definition.get("control_points", []) as Array).size()
	custom_scenario_max_active_ships = maxi(int(custom_scenario_definition.get("max_active_ships", 14)), 6)
	player_sunk = false
	mission_complete = false
	active_sortie_region = {"name": String(config.get("title", "Custom Battle")), "mood": String(config.get("brief", "Fleet trial"))}
	active_encounter_party = {}
	active_sortie_captures = 0
	active_sortie_resolved = false
	_clear_sortie_entities()
	_apply_player_ship_profile(String(config.get("player_type", "Brig")))
	if player_ship:
		if player_ship.has_method("reset_for_sortie"):
			player_ship.reset_for_sortie()
		var player_basis := Basis().rotated(Vector3.UP, deg_to_rad(float(config.get("player_rotation", 0.0))))
		player_ship.global_transform = Transform3D(player_basis, config.get("player_spawn", Vector3(0.0, 0.0, 54.0)))
		player_ship.set("velocity", Vector3.ZERO)
		player_ship.set("speed", 0.0)
		player_ship.set("accepts_player_input", true)
		if player_ship.has_method("reset_physics_interpolation"):
			player_ship.reset_physics_interpolation()

	var ally_data := _build_custom_fleet_data(config.get("allies", {}), 0)
	for data in ally_data:
		var ally_anchor: Node3D = player_ship
		_spawn_ai_ship(data, 0, ally_anchor)

	var enemy_data := _build_custom_fleet_data(config.get("enemies", {}), 1)
	var enemy_leader: Node3D = null
	for data in enemy_data:
		var ship := _spawn_ai_ship(data, 1, enemy_leader)
		if ship is Node3D and (enemy_leader == null or float(ship.get("max_health")) > float(enemy_leader.get("max_health"))):
			enemy_leader = ship
	for enemy in enemies:
		if is_instance_valid(enemy) and String(enemy.get("ai_role")) == "escort":
			enemy.set("formation_anchor_ship", enemy_leader)
	_spawn_custom_scenario_content(config)
	custom_scenario_initial_allies = _active_allied_ship_count()
	custom_scenario_initial_enemies = _active_enemy_ship_count()

	get_tree().paused = false
	campaign_map_open = false
	if camera and player_ship:
		camera.target = player_ship
		camera.global_position = player_ship.global_position + Vector3(0.0, 9.0, 18.0)
		camera.set_input_enabled(true)
	if hud:
		hud.visible = true
		hud.show_pause_menu(false)
		hud.set_aim_state(false, 0, false)
	if aim_guide and aim_guide.has_method("hide_solution"):
		aim_guide.hide_solution()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_player_ship_profile(type_name: String) -> void:
	if player_ship == null:
		return
	var profile := _ship_profile(type_name)
	player_ship.display_name = "Sable Wake %s" % type_name
	player_ship.max_health = float(profile.health)
	player_ship.max_speed = float(profile.max_speed)
	player_ship.acceleration = float(profile.acceleration)
	player_ship.deceleration = float(profile.deceleration)
	player_ship.turn_rate = float(profile.turn_rate)
	player_ship.rudder_response = float(profile.rudder_response)
	player_ship.rudder_return_speed = float(profile.rudder_return_speed)
	player_ship.sail_change_rate = float(profile.sail_change_rate)
	player_ship.cannon_reload = float(profile.reload)
	player_ship.cannon_damage = float(profile.damage)
	player_ship.cannon_shot_speed = float(profile.shot_speed)
	player_ship.base_cannons_per_side = int(profile.cannons)
	player_ship.health = player_ship.max_health
	if battle_mode == "custom":
		player_ship.set_meta("campaign_sailors", int(profile.crew))
		player_ship.set_meta("campaign_morale", int(profile.morale))
	if player_ship.has_method("set_hull_class"):
		player_ship.set_hull_class(type_name)


func _build_custom_fleet_data(counts: Dictionary, ship_team: int) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	var index := 0
	for type_name in counts.keys():
		var count := clampi(int(counts.get(type_name, 0)), 0, 6)
		for local_index in range(count):
			var role := _custom_role_for_type(String(type_name))
			var hull_type := _hull_for_role(String(type_name))
			var profile := _ship_profile(hull_type)
			var slot := _custom_scenario_fleet_slot(custom_scenario_id, ship_team, index)
			var position: Vector3 = slot.get("position", Vector3.ZERO)
			data.append({
				"name": "%s %d" % [type_name, local_index + 1],
				"role": role,
				"hull_class": hull_type,
				"pos": position,
				"station": position,
				"rot": float(slot.get("rotation", 0.0 if ship_team == 0 else 180.0)),
				"side": 1 if index % 2 == 0 else -1,
				"health": profile.health,
				"max_speed": profile.max_speed,
				"damage": profile.damage,
				"shot_speed": profile.shot_speed,
				"reload": profile.reload,
				"cannons": profile.cannons,
				"crew": profile.crew,
				"morale": profile.morale,
				"scenario_convoy": ship_team == 0 and role == "courier",
			})
			index += 1
	return data


func _custom_scenario_fleet_slot(scenario_id: String, ship_team: int, index: int) -> Dictionary:
	var positions: Array = []
	var rotations: Array = []
	match scenario_id:
		"iron_line":
			positions = [Vector3(-66.0, 0.0, 112.0), Vector3(-22.0, 0.0, 128.0), Vector3(22.0, 0.0, 128.0), Vector3(66.0, 0.0, 112.0)] if ship_team == 0 else [Vector3(-88.0, 0.0, -54.0), Vector3(-44.0, 0.0, -64.0), Vector3(0.0, 0.0, -70.0), Vector3(44.0, 0.0, -64.0), Vector3(88.0, 0.0, -54.0)]
			rotations = [-8.0, -3.0, 3.0, 8.0] if ship_team == 0 else [170.0, 175.0, 180.0, 185.0, 190.0]
		"tempest_convoy":
			positions = [Vector3(-18.0, 0.0, 70.0), Vector3(18.0, 0.0, 82.0), Vector3(-16.0, 0.0, 100.0), Vector3(20.0, 0.0, 114.0), Vector3(0.0, 0.0, 132.0)] if ship_team == 0 else [Vector3(-105.0, 0.0, 28.0), Vector3(105.0, 0.0, 20.0), Vector3(-82.0, 0.0, -42.0), Vector3(82.0, 0.0, -50.0), Vector3(0.0, 0.0, -92.0)]
			rotations = [-3.0, 2.0, -2.0, 3.0, 0.0] if ship_team == 0 else [-70.0, 70.0, -42.0, 42.0, 180.0]
		"blackglass_bastion":
			positions = [Vector3(-72.0, 0.0, 122.0), Vector3(-24.0, 0.0, 138.0), Vector3(24.0, 0.0, 138.0), Vector3(72.0, 0.0, 122.0)] if ship_team == 0 else [Vector3(-82.0, 0.0, -76.0), Vector3(-34.0, 0.0, -92.0), Vector3(34.0, 0.0, -92.0), Vector3(82.0, 0.0, -76.0)]
			rotations = [-12.0, -4.0, 4.0, 12.0] if ship_team == 0 else [156.0, 170.0, 190.0, 204.0]
		"moonlit_hunt":
			positions = [Vector3(-48.0, 0.0, 78.0), Vector3(24.0, 0.0, 92.0), Vector3(58.0, 0.0, 60.0)] if ship_team == 0 else [Vector3(-102.0, 0.0, -4.0), Vector3(94.0, 0.0, -28.0), Vector3(-58.0, 0.0, -76.0), Vector3(42.0, 0.0, -98.0), Vector3(4.0, 0.0, -132.0)]
			rotations = [-14.0, 6.0, 18.0] if ship_team == 0 else [-76.0, 68.0, -38.0, 42.0, 178.0]
		"redwater_dominion":
			positions = [Vector3(-72.0, 0.0, 118.0), Vector3(-28.0, 0.0, 132.0), Vector3(28.0, 0.0, 132.0), Vector3(72.0, 0.0, 118.0)] if ship_team == 0 else [Vector3(-96.0, 0.0, -55.0), Vector3(-48.0, 0.0, -76.0), Vector3(0.0, 0.0, -88.0), Vector3(48.0, 0.0, -76.0), Vector3(96.0, 0.0, -55.0)]
			rotations = [-8.0, -4.0, 4.0, 8.0] if ship_team == 0 else [166.0, 172.0, 180.0, 188.0, 194.0]
		"storm_crown_armada":
			positions = [Vector3(-96.0, 0.0, 128.0), Vector3(-50.0, 0.0, 144.0), Vector3(0.0, 0.0, 154.0), Vector3(50.0, 0.0, 144.0), Vector3(96.0, 0.0, 128.0)] if ship_team == 0 else [Vector3(-120.0, 0.0, -102.0), Vector3(-72.0, 0.0, -118.0), Vector3(-24.0, 0.0, -128.0), Vector3(24.0, 0.0, -128.0), Vector3(72.0, 0.0, -118.0), Vector3(120.0, 0.0, -102.0)]
			rotations = [-10.0, -5.0, 0.0, 5.0, 10.0] if ship_team == 0 else [168.0, 173.0, 177.0, 183.0, 187.0, 192.0]
	if positions.is_empty():
		var row := int(index / 3)
		var column := index % 3
		var x := (float(column) - 1.0) * 35.0 + (12.0 if row % 2 == 1 else 0.0)
		var z := 106.0 + float(row) * 32.0 if ship_team == 0 else -72.0 - float(row) * 34.0
		return {"position": Vector3(x, 0.0, z), "rotation": 0.0 if ship_team == 0 else 180.0}
	return {
		"position": positions[index % positions.size()] + Vector3(0.0, 0.0, float(index / positions.size()) * (22.0 if ship_team == 0 else -22.0)),
		"rotation": rotations[index % rotations.size()],
	}


func _spawn_custom_scenario_content(config: Dictionary) -> void:
	for island_data in config.get("scenario_islands", []):
		var position: Vector3 = island_data.get("position", Vector3.ZERO)
		var radius := float(island_data.get("radius", 12.0))
		var island := _create_island(position, radius)
		island.add_to_group("scenario_content")
		island_markers.append({"position": position, "radius": radius, "scenario": true})

	var fort_definitions: Array = (config.get("forts", []) as Array).duplicate(true)
	if fort_definitions.is_empty() and bool(config.get("fort", false)):
		fort_definitions.append({
			"name": "Blackglass Bastion",
			"position": config.get("fort_position", Vector3(0.0, 0.0, -128.0)),
			"island_radius": 29.0,
			"style": "citadel",
		})
	for fort_data in fort_definitions:
		_spawn_scenario_fort(fort_data)

	for point_data in config.get("control_points", []):
		var point := SeaControlPoint.new()
		point.configure(point_data)
		point.position = point_data.get("position", Vector3.ZERO)
		point.ownership_changed.connect(_on_scenario_control_changed)
		add_child(point)
		island_markers.append({
			"position": point.position,
			"radius": float(point_data.get("radius", 30.0)),
			"scenario": true,
			"objective": true,
		})


func _spawn_scenario_fort(data: Dictionary) -> void:
	var fort_position: Vector3 = data.get("position", Vector3(0.0, 0.0, -128.0))
	var island_radius := float(data.get("island_radius", 24.0))
	var island := _create_island(fort_position, island_radius)
	island.add_to_group("scenario_content")
	island_markers.append({"position": fort_position, "radius": island_radius, "scenario": true})
	var fort := CoastalFort.new()
	fort.configure_fort(data)
	fort.position = Vector3(0.0, float(data.get("height", 2.0)), 0.0)
	fort.rotation_degrees.y = float(data.get("rotation", 0.0))
	fort.sunk.connect(_on_ai_ship_sunk)
	if fort.has_signal("phase_changed"):
		fort.phase_changed.connect(_on_scenario_fort_phase_changed)
	if fort.has_signal("capture_started"):
		fort.capture_started.connect(_on_fort_capture_started)
	if fort.has_signal("capture_stage_changed"):
		fort.capture_stage_changed.connect(_on_fort_capture_stage_changed)
	if fort.has_signal("capture_completed"):
		fort.capture_completed.connect(_on_fort_capture_completed)
	island.add_child(fort)
	enemies.append(fort)


func _update_custom_scenario_state(delta := 0.0) -> void:
	if battle_mode != "custom" or mission_complete or player_sunk:
		return
	custom_scenario_elapsed += delta
	_update_scenario_reinforcements()
	if String(custom_scenario_definition.get("objective", "destroy_fleet")) == "protect_convoy" and custom_scenario_expected_convoy > 0:
		var surviving_convoy := 0
		for ally in allies:
			if is_instance_valid(ally) and not bool(ally.get("is_sunk")) and bool(ally.get_meta("scenario_convoy", false)):
				surviving_convoy += 1
		if surviving_convoy <= 0:
			custom_scenario_failed = true
			mission_complete = true
			if hud:
				hud.show_banner("Convoy Lost", "Press Enter to replay the scenario.", 999.0)


func _update_scenario_reinforcements() -> void:
	var waves: Array = custom_scenario_definition.get("reinforcements", [])
	for index in range(waves.size()):
		if custom_scenario_spawned_waves.has(index):
			continue
		var wave: Dictionary = waves[index]
		if not _scenario_wave_ready(wave):
			continue
		var requested := 0
		for count in (wave.get("ships", {}) as Dictionary).values():
			requested += int(count)
		if _active_moving_ship_count() + requested > custom_scenario_max_active_ships:
			continue
		custom_scenario_spawned_waves[index] = true
		_spawn_scenario_reinforcement(wave, index)


func _scenario_wave_ready(wave: Dictionary) -> bool:
	if wave.has("after_wave") and not custom_scenario_spawned_waves.has(int(wave.get("after_wave", -1))):
		return false
	if int(wave.get("team", 1)) == 1 and _active_enemy_ship_count() <= 0:
		return true
	var trigger := String(wave.get("trigger", "time"))
	if trigger == "forts_remaining":
		return _living_scenario_forts() <= int(wave.get("value", 0))
	if trigger == "allied_zones":
		return _controlled_zone_count(0) >= int(wave.get("value", 1))
	if trigger == "enemy_zones":
		return _controlled_zone_count(1) >= int(wave.get("value", 1))
	if trigger == "enemies_remaining":
		return _active_enemy_ship_count() <= int(wave.get("value", 0))
	if trigger == "allied_losses":
		return custom_scenario_initial_allies - _active_allied_ship_count() >= int(wave.get("value", 1))
	if trigger == "convoy_losses":
		return custom_scenario_expected_convoy - _surviving_scenario_convoy() >= int(wave.get("value", 1))
	if trigger == "fort_phase":
		return _highest_scenario_fort_phase() >= int(wave.get("value", 1))
	return custom_scenario_elapsed >= float(wave.get("time", 20.0))


func _spawn_scenario_reinforcement(wave: Dictionary, wave_index: int) -> void:
	var ship_team := int(wave.get("team", 1))
	var origin: Vector3 = wave.get("position", Vector3(0.0, 0.0, 150.0 if ship_team == 0 else -150.0))
	var rotation := float(wave.get("rotation", 0.0 if ship_team == 0 else 180.0))
	var slot_index := 0
	var leader: Node3D = player_ship if ship_team == 0 else null
	for type_name in (wave.get("ships", {}) as Dictionary).keys():
		var count := clampi(int((wave.get("ships", {}) as Dictionary).get(type_name, 0)), 0, 5)
		for local_index in range(count):
			var hull_type := _hull_for_role(String(type_name))
			var profile := _ship_profile(hull_type)
			var row := int(slot_index / 3)
			var column := slot_index % 3
			var offset := Vector3((float(column) - 1.0) * 30.0, 0.0, float(row) * (24.0 if ship_team == 0 else -24.0))
			var ship := _spawn_ai_ship({
				"name": "%s %d" % [String(wave.get("wing", "Reserve Wing")), local_index + 1],
				"role": _custom_role_for_type(String(type_name)),
				"hull_class": hull_type,
				"pos": origin + offset,
				"station": origin + offset,
				"rot": rotation,
				"health": profile.health,
				"max_speed": profile.max_speed,
				"damage": profile.damage,
				"shot_speed": profile.shot_speed,
				"reload": profile.reload,
				"cannons": profile.cannons,
				"crew": profile.crew,
				"morale": profile.morale,
			}, ship_team, leader)
			if ship_team == 1 and leader == null and ship is Node3D:
				leader = ship
			slot_index += 1
	if hud:
		hud.show_banner(String(wave.get("title", "Reinforcements")), String(wave.get("subtitle", "A reserve squadron has entered the battle.")), 3.5)


func _active_moving_ship_count() -> int:
	return maxi(_active_allied_ship_count() - 1, 0) + _active_enemy_ship_count()


func _active_enemy_ship_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_in_group("scenario_fort") and not bool(enemy.get("is_sunk")) and not bool(enemy.get("is_incapacitated")):
			count += 1
	return count


func _active_allied_ship_count() -> int:
	var count := 1 if is_instance_valid(player_ship) and not bool(player_ship.get("is_sunk")) and not bool(player_ship.get("is_incapacitated")) else 0
	for ally in allies:
		if is_instance_valid(ally) and not bool(ally.get("is_sunk")) and not bool(ally.get("is_incapacitated")):
			count += 1
	return count


func _highest_scenario_fort_phase() -> int:
	var highest := 0
	for fort in get_tree().get_nodes_in_group("scenario_fort"):
		if is_instance_valid(fort):
			highest = maxi(highest, int(fort.get("fort_phase")))
	return highest


func _on_scenario_fort_phase_changed(fort: Node, phase: int) -> void:
	if battle_mode != "custom" or not is_instance_valid(fort):
		return
	if hud and phase == 1:
		hud.show_banner("Outer Batteries Silenced", "%s's main keep is exposed." % String(fort.get("display_name")), 2.6)
	elif hud and phase == 2:
		hud.show_banner("Powder Magazine Exposed", "Strike the magazine to capture %s." % String(fort.get("display_name")), 3.0)
	_update_scenario_reinforcements()


func _on_fort_capture_started(fort: Node) -> void:
	if not (fort is Node3D) or fort_capture_active:
		return
	fort_capture_target = fort as Node3D
	fort_capture_active = true
	_spawn_fort_assault_boats(fort_capture_target)
	_issue_fort_capture_orders(fort_capture_target)
	if hud and hud.has_method("hide_banner"):
		hud.hide_banner()
	_reset_boarding_state()
	if is_instance_valid(player_ship):
		player_ship.set("accepts_player_input", false)
		if player_ship.has_method("set_sail_step"):
			player_ship.set_sail_step(0, true)
		if player_ship.has_method("stop_water_motion"):
			player_ship.stop_water_motion()
	if camera:
		camera.set_aiming(false)
		camera.set_input_enabled(false)
		if camera.has_method("set_fort_capture_focus"):
			camera.set_fort_capture_focus(fort_capture_target)
		if camera.has_method("add_boarding_impulse"):
			camera.add_boarding_impulse(0.72)
	_update_fort_capture_hud()


func _on_fort_capture_stage_changed(fort: Node, stage: int) -> void:
	if not fort_capture_active or fort != fort_capture_target:
		return
	if camera and camera.has_method("set_fort_capture_stage"):
		camera.set_fort_capture_stage(stage)
	if camera and camera.has_method("add_boarding_impulse"):
		camera.add_boarding_impulse(0.34 if stage == 1 else 0.22)
	_update_fort_capture_hud()


func _update_fort_capture_hud() -> void:
	if not fort_capture_active or not is_instance_valid(fort_capture_target) or not hud or not hud.has_method("show_boarding_prompt"):
		return
	var progress := float(fort_capture_target.get("capture_progress"))
	var stage := int(fort_capture_target.get("capture_stage"))
	var title := "BREACH OPEN"
	var status := "Marines are entering the outer works"
	if stage == 1:
		title = "FORT ASSAULT"
		status = "Your crew is securing the inner courtyard"
	elif stage >= 2:
		title = "COLORS RISING"
		status = "Enemy colors are down; the fort is ours"
	hud.show_boarding_prompt(true, String(fort_capture_target.get("display_name")), player_ship.global_position.distance_to(fort_capture_target.global_position), progress, status, title)


func _on_fort_capture_completed(fort: Node) -> void:
	if fort != fort_capture_target:
		return
	var captured_name := String(fort.get("display_name"))
	enemies.erase(fort)
	_update_scenario_reinforcements()
	_issue_captured_fort_response(fort as Node3D)
	_reset_fort_capture_state()
	if hud:
		hud.show_banner("Fort Captured", "%s now flies allied colors." % captured_name, 3.0)


func _spawn_fort_assault_boats(fort: Node3D) -> void:
	if not is_instance_valid(player_ship) or not is_instance_valid(fort):
		return
	for lane in range(3):
		var boat := FortAssaultBoat.new()
		boat.name = "FortAssaultBoat%d" % lane
		boat.add_to_group("scenario_content")
		boat.add_to_group("fort_assault")
		add_child(boat)
		boat.begin(player_ship, fort, lane)


func _issue_fort_capture_orders(fort: Node3D) -> void:
	if not is_instance_valid(fort):
		return
	var hostile_ships := _active_fleet_nodes(enemies, fort)
	var allied_ships := _active_fleet_nodes(allies)
	var threat_center := fort.global_position + Vector3.BACK * 80.0
	if not hostile_ships.is_empty():
		threat_center = Vector3.ZERO
		for hostile in hostile_ships:
			threat_center += hostile.global_position
		threat_center /= float(hostile_ships.size())
	var threat_direction := threat_center - fort.global_position
	threat_direction.y = 0.0
	if threat_direction.length_squared() < 0.01:
		threat_direction = Vector3.BACK
	threat_direction = threat_direction.normalized()
	var screen_tangent := Vector3(-threat_direction.z, 0.0, threat_direction.x)
	for index in range(allied_ships.size()):
		var ally := allied_ships[index]
		if not ally.has_method("set_strategic_order"):
			continue
		var offset := (float(index) - float(allied_ships.size() - 1) * 0.5) * 12.0
		var station := fort.global_position + threat_direction * 44.0 + screen_tangent * offset
		ally.set_strategic_order("guard_fort", fort, station, _nearest_fleet_node(ally, hostile_ships), 14.0)
	for index in range(hostile_ships.size()):
		var hostile := hostile_ships[index]
		if not hostile.has_method("set_strategic_order"):
			continue
		var outward := hostile.global_position - fort.global_position
		outward.y = 0.0
		if outward.length_squared() < 0.01:
			outward = threat_direction
		outward = outward.normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var station := fort.global_position + outward * 46.0 + tangent * (float(index % 3) - 1.0) * 8.0
		hostile.set_strategic_order("relieve_fort", fort, station, player_ship, 16.0)


func _issue_captured_fort_response(fort: Node3D) -> void:
	if not is_instance_valid(fort):
		return
	var hostile_ships := _active_fleet_nodes(enemies)
	for index in range(hostile_ships.size()):
		var hostile := hostile_ships[index]
		if not hostile.has_method("set_strategic_order"):
			continue
		var outward := hostile.global_position - fort.global_position
		outward.y = 0.0
		if outward.length_squared() < 0.01:
			outward = Vector3.BACK
		outward = outward.normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var station := fort.global_position + outward * 48.0 + tangent * (float(index % 3) - 1.0) * 9.0
		hostile.set_strategic_order("assault_fort", fort, station, fort, 15.0)


func _active_fleet_nodes(source: Array, excluded: Node = null) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for entry in source:
		if entry == excluded or not (entry is Node3D) or not is_instance_valid(entry):
			continue
		if entry.is_in_group("scenario_fort") or bool(entry.get("is_sunk")) or bool(entry.get("is_incapacitated")):
			continue
		result.append(entry as Node3D)
	return result


func _nearest_fleet_node(source: Node3D, candidates: Array[Node3D]) -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var distance := source.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _reset_fort_capture_state() -> void:
	fort_capture_active = false
	fort_capture_target = null
	if camera and camera.has_method("clear_fort_capture_focus"):
		camera.clear_fort_capture_focus()
	if is_instance_valid(player_ship) and not player_sunk:
		player_ship.set("accepts_player_input", true)
	if camera:
		camera.set_input_enabled(not campaign_map_open and not get_tree().paused)
	if hud and hud.has_method("show_boarding_prompt"):
		hud.show_boarding_prompt(false)


func _enemy_reserves_committed() -> bool:
	var waves: Array = custom_scenario_definition.get("reinforcements", [])
	for index in range(waves.size()):
		if int((waves[index] as Dictionary).get("team", 1)) == 1 and not custom_scenario_spawned_waves.has(index):
			return false
	return true


func _living_scenario_forts() -> int:
	var count := 0
	for fort in get_tree().get_nodes_in_group("scenario_fort"):
		if is_instance_valid(fort) and not bool(fort.get("is_captured")):
			count += 1
	return count


func _controlled_zone_count(team: int) -> int:
	var count := 0
	for point in get_tree().get_nodes_in_group("scenario_control_point"):
		if is_instance_valid(point) and int(point.get("owner_team")) == team:
			count += 1
	return count


func _surviving_scenario_convoy() -> int:
	var count := 0
	for ally in allies:
		if is_instance_valid(ally) and not bool(ally.get("is_sunk")) and bool(ally.get_meta("scenario_convoy", false)):
			count += 1
	return count


func _on_scenario_control_changed(point: Node, new_owner: int) -> void:
	if hud:
		var title := "Waters Secured" if new_owner == 0 else "Position Lost"
		var subtitle := "%s now flies %s colors." % [String(point.get("display_name")), "allied" if new_owner == 0 else "enemy"]
		hud.show_banner(title, subtitle, 2.8)


func _is_current_battle_complete() -> bool:
	if battle_mode != "custom":
		return enemies.is_empty()
	var objective := String(custom_scenario_definition.get("objective", "destroy_fleet"))
	if objective == "sandbox":
		return false
	if objective == "destroy_fort":
		for fort in get_tree().get_nodes_in_group("scenario_fort"):
			if is_instance_valid(fort) and not bool(fort.get("is_captured")):
				return false
		return true
	if objective == "capture_zones":
		var points := get_tree().get_nodes_in_group("scenario_control_point")
		if points.is_empty():
			return false
		for point in points:
			if not is_instance_valid(point) or int(point.get("owner_team")) != 0:
				return false
		return true
	return enemies.is_empty() and _enemy_reserves_committed()


func _custom_scenario_progress_detail() -> String:
	var objective := String(custom_scenario_definition.get("objective", "destroy_fleet"))
	if objective == "protect_convoy":
		var survivors := 0
		for ally in allies:
			if is_instance_valid(ally) and bool(ally.get_meta("scenario_convoy", false)) and not bool(ally.get("is_sunk")):
				survivors += 1
		return "Couriers afloat: %d/%d. Hostiles remaining: %d." % [survivors, custom_scenario_expected_convoy, enemies.size()]
	if objective == "destroy_fort":
		var living_forts := _living_scenario_forts()
		return "Forts remaining: %d. Enemy ships: %d. Reserves committed: %d/%d." % [living_forts, maxi(enemies.size() - living_forts, 0), custom_scenario_spawned_waves.size(), custom_scenario_wave_total]
	if objective == "capture_zones":
		return "Positions held: %d/%d. Allied ships: %d. Enemy ships: %d. Reserves: %d/%d." % [_controlled_zone_count(0), custom_scenario_control_points_expected, allies.size() + 1, enemies.size(), custom_scenario_spawned_waves.size(), custom_scenario_wave_total]
	return "%s Reserves: %d/%d." % [String(custom_scenario_definition.get("objective_detail", "Hostiles remaining: %d." % enemies.size())), custom_scenario_spawned_waves.size(), custom_scenario_wave_total]


func _custom_role_for_type(type_name: String) -> String:
	return type_name.to_lower().replace(" ", "_")


func _hull_for_role(type_name: String) -> String:
	var key := type_name.to_lower().replace("_", " ").replace("-", " ").replace("'", " ")
	key = " ".join(key.split(" ", false))
	if key.contains("man o war") or key.contains("man-of-war") or key.contains("manowar"):
		return "Man o' War"
	if key.contains("ship of the line") or key.contains("line ship") or key.contains("heavy"):
		return "Ship of the Line"
	if key.contains("frigate"):
		return "Frigate"
	if key.contains("courier") or key.contains("raider") or key.contains("sloop"):
		return "Sloop"
	return "Brig"


func _ship_profile(type_name: String) -> Dictionary:
	match type_name:
		"Sloop":
			return {"health": 95.0, "max_speed": 10.4, "acceleration": 4.5, "deceleration": 4.1, "turn_rate": 1.20, "rudder_response": 2.35, "rudder_return_speed": 3.0, "sail_change_rate": 0.66, "reload": 2.75, "damage": 5.8, "shot_speed": 45.0, "cannons": 4, "crew": 28, "morale": 62}
		"Frigate":
			return {"health": 190.0, "max_speed": 9.5, "acceleration": 3.55, "deceleration": 3.2, "turn_rate": 0.94, "rudder_response": 2.0, "rudder_return_speed": 2.6, "sail_change_rate": 0.54, "reload": 3.25, "damage": 5.8, "shot_speed": 46.0, "cannons": 4, "crew": 82, "morale": 66}
		"Ship of the Line":
			return {"health": 330.0, "max_speed": 8.3, "acceleration": 2.55, "deceleration": 2.45, "turn_rate": 0.80, "rudder_response": 1.72, "rudder_return_speed": 2.2, "sail_change_rate": 0.44, "reload": 3.75, "damage": 6.0, "shot_speed": 47.0, "cannons": 4, "crew": 156, "morale": 76}
		"Man o' War":
			return {"health": 480.0, "max_speed": 7.5, "acceleration": 2.15, "deceleration": 2.1, "turn_rate": 0.72, "rudder_response": 1.55, "rudder_return_speed": 2.0, "sail_change_rate": 0.38, "reload": 4.15, "damage": 6.2, "shot_speed": 48.0, "cannons": 4, "crew": 230, "morale": 84}
	return {"health": 135.0, "max_speed": 9.9, "acceleration": 4.1, "deceleration": 3.7, "turn_rate": 1.05, "rudder_response": 2.15, "rudder_return_speed": 2.8, "sail_change_rate": 0.60, "reload": 3.0, "damage": 6.0, "shot_speed": 44.0, "cannons": 5, "crew": 52, "morale": 60}


func _open_campaign_map(can_close: bool) -> void:
	_close_mortar_targeting()
	campaign_map_open = true
	get_tree().paused = true
	if camera:
		camera.set_input_enabled(false)
		camera.set_aiming(false)
	if hud:
		hud.visible = false
		hud.set_aim_state(false, 0, false)
	if player_ship:
		player_ship.set("accepts_player_input", false)
	if aim_guide and aim_guide.has_method("hide_solution"):
		aim_guide.hide_solution()
	if campaign_map and campaign_map.has_method("show_map"):
		campaign_map.show_map(can_close)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_campaign_map() -> void:
	campaign_map_open = false
	get_tree().paused = false
	if campaign_map and campaign_map.has_method("hide_map"):
		campaign_map.hide_map()
	if camera:
		camera.set_input_enabled(true)
	if player_ship:
		player_ship.set("accepts_player_input", true)
	if hud:
		hud.visible = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_campaign_deploy_requested(region: Dictionary) -> void:
	campaign_started = true
	battle_mode = "campaign"
	_prepare_sortie_from_campaign(region)
	_close_campaign_map()


func _prepare_sortie_from_campaign(region: Dictionary) -> void:
	player_sunk = false
	mission_complete = false
	active_sortie_region = region.duplicate(true)
	active_encounter_party = region.get("encounter_party", {}).duplicate(true) if region.has("encounter_party") else {}
	active_sortie_captures = 0
	active_sortie_resolved = false
	_clear_sortie_entities()
	if player_ship:
		if player_ship.has_method("reset_for_sortie"):
			player_ship.reset_for_sortie()
		_apply_campaign_ship_condition()
		player_ship.global_transform = _get_sortie_spawn_transform(region)
		player_ship.global_position.y = 0.0
		player_ship.set("velocity", Vector3.ZERO)
		player_ship.set("speed", 0.0)
		player_ship.set("accepts_player_input", true)
		if player_ship.has_method("reset_physics_interpolation"):
			player_ship.reset_physics_interpolation()
	_spawn_enemies(region)
	if camera and player_ship:
		camera.global_position = player_ship.global_position + Vector3(0.0, 9.0, 18.0)
	if hud:
		hud.show_pause_menu(false)
		hud.set_aim_state(false, 0, false)
	if aim_guide and aim_guide.has_method("hide_solution"):
		aim_guide.hide_solution()


func _complete_sortie_success() -> void:
	mission_complete = true
	if battle_mode == "campaign":
		_record_campaign_ship_condition()
		_resolve_active_campaign_encounter()
	if hud:
		if battle_mode == "custom":
			hud.show_banner("Battle Won", "Press Enter to replay this custom battle.", 999.0)
		elif active_encounter_party.is_empty():
			hud.show_banner("Sea lane secured", "Press Enter to return to the campaign map.", 999.0)
		else:
			hud.show_banner("Fleet defeated", "%s removed from the campaign map. Press Enter." % String(active_encounter_party.get("name", "Enemy fleet")), 999.0)


func _resolve_active_campaign_encounter() -> void:
	if active_sortie_resolved or active_encounter_party.is_empty():
		return
	active_sortie_resolved = true
	var outcome := "captured" if active_sortie_captures > 0 else "defeated"
	var result := {
		"party": active_encounter_party.duplicate(true),
		"outcome": outcome,
	}
	if campaign_map and campaign_map.has_method("resolve_encounter_result"):
		campaign_map.resolve_encounter_result(result)


func _apply_campaign_ship_condition() -> void:
	if player_ship == null or campaign_map == null or not campaign_map.has_method("get_ship_condition"):
		return
	var condition: Dictionary = campaign_map.get_ship_condition()
	var hull_ratio := clampf(float(condition.get("hull", 100)) / 100.0, 0.65, 1.0)
	player_ship.set("health", float(player_ship.get("max_health")) * hull_ratio)
	player_ship.set("repair_supplies", clampi(int(condition.get("repair_supplies", player_ship.get("max_repair_supplies"))), 0, int(player_ship.get("max_repair_supplies"))))
	player_ship.set_meta("campaign_sailors", int(condition.get("sailors", 42)))
	player_ship.set_meta("campaign_gunners", int(condition.get("gunners", 18)))
	player_ship.set_meta("campaign_carpenters", int(condition.get("carpenters", 6)))
	player_ship.set_meta("campaign_morale", int(condition.get("morale", 58)))
	if player_ship.has_signal("health_changed"):
		player_ship.health_changed.emit(float(player_ship.get("health")), float(player_ship.get("max_health")))


func _record_campaign_ship_condition() -> void:
	if player_ship == null or campaign_map == null or not campaign_map.has_method("record_ship_condition"):
		return
	if player_ship.has_method("get_telemetry"):
		campaign_map.record_ship_condition(player_ship.get_telemetry())


func _get_sortie_spawn_transform(region: Dictionary) -> Transform3D:
	var region_position: Vector2 = region.get("position", Vector2(0.53, 0.70))
	var heading := deg_to_rad(180.0 + (region_position.x - 0.5) * 42.0)
	return Transform3D(Basis().rotated(Vector3.UP, heading), Vector3(0.0, 0.0, 24.0))


func _clear_sortie_entities() -> void:
	_reset_boarding_state()
	_reset_fort_capture_state()
	for operation in ai_boarding_operations:
		_release_ai_boarding_operation(operation)
	ai_boarding_operations.clear()
	ai_boarding_scan_timer = 0.0
	_clear_rogue_wave()
	var nodes_to_clear: Array[Node] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not nodes_to_clear.has(enemy):
			nodes_to_clear.append(enemy)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not nodes_to_clear.has(enemy):
			nodes_to_clear.append(enemy)
	for ally in allies:
		if is_instance_valid(ally) and not nodes_to_clear.has(ally):
			nodes_to_clear.append(ally)
	for ally in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(ally) and not nodes_to_clear.has(ally):
			nodes_to_clear.append(ally)
	for enemy in nodes_to_clear:
		if is_instance_valid(enemy):
			if enemy.is_in_group("enemies"):
				enemy.remove_from_group("enemies")
			if enemy.is_in_group("allies"):
				enemy.remove_from_group("allies")
			enemy.queue_free()
	enemies.clear()
	allies.clear()
	for cannonball in get_tree().get_nodes_in_group("cannonballs"):
		if is_instance_valid(cannonball):
			cannonball.queue_free()
	for content in get_tree().get_nodes_in_group("scenario_content"):
		if is_instance_valid(content):
			content.queue_free()
	island_markers = island_markers.filter(func(marker: Dictionary) -> bool: return not bool(marker.get("scenario", false)))


func _on_campaign_map_close_requested() -> void:
	if campaign_started:
		_close_campaign_map()


func _on_resume_requested() -> void:
	_set_pause_menu(false)


func _on_return_to_campaign_requested() -> void:
	_set_pause_menu(false)
	if battle_mode == "custom":
		_show_main_menu()
	elif campaign_started:
		_record_campaign_ship_condition()
		_open_campaign_map(true)


func _on_player_sunk(_ship: Node) -> void:
	player_sunk = true
	if hud:
		hud.show_banner("Your ship is sinking", "Press Enter to replay." if battle_mode == "custom" else "Press Enter to restart.", 999.0)


func _on_ai_ship_sunk(ship: Node) -> void:
	enemies.erase(ship)
	allies.erase(ship)


func _on_ai_ship_retreated(ship: Node) -> void:
	enemies.erase(ship)
	allies.erase(ship)
	if is_instance_valid(ship):
		ship.queue_free()


func _on_player_broadside_fired(side: int) -> void:
	if camera and camera.has_method("add_combat_impulse"):
		camera.add_combat_impulse(side)


func _on_ship_hit_reported(ship: Node, report: Dictionary) -> void:
	var impact_total := float(report.get("health_damage", 0.0)) + float(report.get("sail_damage", 0.0)) + float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	var source_ship: Node = report.get("source", null)
	if impact_total >= 8.0 and combat_audio and (ship == player_ship or source_ship == player_ship):
		combat_audio.apply_impact_duck(clampf(impact_total / 32.0, 0.2, 1.0))
	var is_player_hit: bool = ship == player_ship
	if is_player_hit:
		if camera and camera.has_method("add_hit_impulse"):
			camera.add_hit_impulse(report)


func _on_player_near_missed(_ship: Node, position: Vector3, _source: Node) -> void:
	if player_sunk or mission_complete:
		return
	if camera and camera.has_method("add_near_miss_impulse"):
		camera.add_near_miss_impulse(position)


func _on_enemy_broadside_warning(enemy: Node, side: int) -> void:
	if not is_instance_valid(enemy) or player_sunk or mission_complete:
		return
	if int(enemy.get("team_id")) == 0:
		return

	if enemy is Node3D:
		CombatFx.spawn_broadside_telegraph(get_tree().current_scene if get_tree().current_scene else self, enemy, side)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
