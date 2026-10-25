extends "res://scripts/player_ship.gd"

signal broadside_warning(enemy: Node, side: int)
signal retreated(ship: Node)

enum CombatState { PURSUE, ORBIT, BROADSIDE, EVADE, CRIPPLED, DISABLED, BOARDING }

@export var desired_range := 34.0
@export var fire_range := 48.0
@export var broadside_windup_duration := 0.62
@export var ai_role := "raider"
@export var battlefield_origin := Vector3.ZERO
@export var escape_radius := 235.0

var target_ship: Node3D
var formation_anchor_ship: Node3D
var formation_station := Vector3.ZERO
var side_preference := 1
var combat_state := CombatState.PURSUE
var _state_timer := 0.0
var _maneuver_timer := 0.0
var _broadside_windup := 0.0
var _target_scan_timer := 0.0
var _has_retreated := false
var _morale_retreating := false
var _morale_check_timer := 0.0
var _ranging_quality := 0.0
var _ranging_target_id := 0
var _ranging_target_velocity := Vector3.ZERO
var _ranging_target_forward := Vector3.FORWARD
var fleet_slot_index := 0
var _target_commitment_timer := 0.0
var _fleet_awareness_timer := 0.0
var _fleet_avoidance := Vector3.ZERO
var _traffic_brake := 0.0
var _island_avoidance := Vector3.ZERO
var _island_brake := 0.0
var boarding_order_target: Node3D
var boarding_order_side := 1.0
var boarding_order_active := false
var strategic_order_kind := ""
var strategic_order_target: Node3D
var strategic_order_station := Vector3.ZERO
var strategic_order_time := 0.0


func _ready() -> void:
	accepts_player_input = false
	incapacitation_health_ratio = 0.18
	_apply_role_identity()
	super._ready()
	incapacitation_health_ratio = 0.18
	add_to_group("allies" if team_id == 0 else "enemies")
	sail_setting = 0.75


func configure_ai(next_team: int, role: String, anchor: Node3D = null, station := Vector3.ZERO) -> void:
	team_id = next_team
	ai_role = _normalize_role(role)
	formation_anchor_ship = anchor
	formation_station = station
	_apply_role_parameters()
	_reset_ranging_solution()
	_fleet_awareness_timer = randf_range(0.02, 0.18)


func configure_fleet_slot(index: int) -> void:
	fleet_slot_index = maxi(index, 0)
	if fleet_slot_index % 2 == 1:
		side_preference = -1


func convert_to_ally(captain_ship: Node3D) -> void:
	convert_to_team(0, captain_ship)


func convert_to_team(next_team: int, captain_ship: Node3D = null) -> void:
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("allies"):
		remove_from_group("allies")
	add_to_group("allies" if next_team == 0 else "enemies")
	team_id = next_team
	ai_role = "escort" if next_team == 0 else "raider"
	formation_anchor_ship = captain_ship
	target_ship = null
	clear_boarding_order()
	is_sunk = false
	is_incapacitated = false
	incapacitated_time_remaining = 0.0
	is_surrendered = false
	was_captured = true
	freeze = false
	sleeping = false
	accepts_player_input = false
	health = maxf(health, max_health * 0.34)
	sail_integrity = maxf(sail_integrity, max_sail_integrity * 0.42)
	rudder_integrity = maxf(rudder_integrity, max_rudder_integrity * 0.48)
	port_cannon_integrity = maxf(port_cannon_integrity, max_cannon_integrity * 0.38)
	starboard_cannon_integrity = maxf(starboard_cannon_integrity, max_cannon_integrity * 0.38)
	flooding = 0.0
	fire_intensity = 0.0
	crew_shock = 0.35
	sail_setting = 0.55
	_port_reload = 1.8
	_starboard_reload = 1.8
	collision_layer = 1
	collision_mask = 1
	set_meta("campaign_crew", maxi(int(get_meta("campaign_crew", 24)) / 3, 8))
	_apply_role_parameters()
	set_captured_flag(next_team)
	_update_damage_smoke()
	_update_regional_damage_visuals()
	_update_cannon_ready_visuals()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_update_strategic_order(delta)
	_target_scan_timer = maxf(_target_scan_timer - delta, 0.0)
	_target_commitment_timer = maxf(_target_commitment_timer - delta, 0.0)
	_update_fleet_awareness(delta)
	if boarding_order_active and is_instance_valid(boarding_order_target):
		target_ship = boarding_order_target
	elif not _has_target() or _target_is_prize_protected() or (_target_scan_timer <= 0.0 and _target_commitment_timer <= 0.0):
		_target_scan_timer = 0.45
		_acquire_target()
	_update_morale_response(delta)
	_update_combat_state(delta)
	_broadside_windup = maxf(_broadside_windup - delta, 0.0)
	_update_retreat_state()
	_update_mortar_attack()
	if not _has_retreated:
		super._physics_process(delta)


func _update_mortar_attack() -> void:
	if boarding_order_active or _target_is_prize_protected() or not hull_class in ["Ship of the Line", "Man o' War"] or not _has_target() or is_incapacitated or is_surrendered:
		return
	var distance := global_position.distance_to(target_ship.global_position)
	if distance < 44.0 or distance > 168.0 or not can_fire_mortar():
		return
	var target_velocity: Vector3 = target_ship.get("velocity") if target_ship.get("velocity") is Vector3 else Vector3.ZERO
	set_aim_focus(0.08 if hull_class == "Man o' War" else 0.04)
	var miss_radius := 18.0 if hull_class == "Man o' War" else 25.0
	var miss_angle := randf() * TAU
	var miss_offset := Vector3(cos(miss_angle), 0.0, sin(miss_angle)) * randf_range(miss_radius * 0.45, miss_radius)
	fire_mortar(target_ship.global_position + target_velocity * clampf(distance / 92.0, 0.20, 1.0) + miss_offset)


func _update_sail_controls(delta: float) -> void:
	var desired_sails := _get_ai_target_sail_setting()
	sail_setting = move_toward(sail_setting, desired_sails, sail_change_rate * 0.82 * delta)
	sail_step_index = _get_sail_step_for_value(sail_setting)
	_target_sail_setting = desired_sails


func _get_ai_target_sail_setting() -> float:
	if is_incapacitated or combat_state == CombatState.DISABLED:
		return 0.0
	if boarding_order_active and is_instance_valid(boarding_order_target):
		var distance := global_position.distance_to(boarding_order_target.global_position)
		return 0.62 if distance > 34.0 else (0.30 if distance > 20.0 else 0.0)
	if _has_strategic_order():
		var station_distance := global_position.distance_to(strategic_order_station)
		return 0.88 if station_distance > 38.0 else (0.58 if station_distance > 15.0 else 0.38)
	if ai_role == "courier" or _morale_retreating:
		return maxf((1.0 - _traffic_brake * 0.45) * (1.0 - _island_brake * 0.48), 0.28)
	var desired := 0.58
	match combat_state:
		CombatState.PURSUE:
			desired = 0.88
		CombatState.ORBIT:
			desired = 0.58
		CombatState.BROADSIDE:
			desired = 0.38
		CombatState.EVADE:
			desired = 0.76
		CombatState.CRIPPLED:
			desired = 0.30
	return maxf(desired * (1.0 - _traffic_brake * 0.72) * (1.0 - _island_brake * 0.58), 0.16 if desired > 0.0 else 0.0)


func _get_sail_input() -> float:
	if is_incapacitated:
		return 0.0
	if boarding_order_active and is_instance_valid(boarding_order_target):
		var distance := global_position.distance_to(boarding_order_target.global_position)
		return 0.72 if distance > 34.0 else (0.18 if distance > 20.0 else -0.35)
	if _has_strategic_order():
		var station_distance := global_position.distance_to(strategic_order_station)
		if station_distance > 20.0:
			return 1.0
	if _morale_retreating:
		return 1.0
	if not _has_target():
		return -1.0
	if ai_role == "courier":
		return 1.0

	var distance := global_position.distance_to(target_ship.global_position)
	match combat_state:
		CombatState.PURSUE:
			return 1.0
		CombatState.BROADSIDE:
			return 0.10 if distance < desired_range * 0.85 else 0.30
		CombatState.EVADE:
			return 0.88
		CombatState.CRIPPLED:
			return 0.45 if distance < desired_range * 1.25 else 0.0
		_:
			if distance > desired_range * 1.12:
				return 0.88
			if distance < desired_range * 0.68:
				return -0.25
			return 0.08


func _get_rudder_input() -> float:
	if is_incapacitated or (not _has_target() and not _has_strategic_order()):
		return 0.0
	var desired_direction := _get_role_direction()
	if _island_avoidance.length_squared() > 0.01:
		var island_weight := lerpf(1.35, 3.25, _island_brake)
		desired_direction = (desired_direction.normalized() * 1.10 + _island_avoidance.normalized() * island_weight).normalized()
	if _fleet_avoidance.length_squared() > 0.01:
		var avoidance_weight := 1.55 if _traffic_brake > 0.45 else 1.08
		desired_direction = (desired_direction.normalized() * 1.25 + _fleet_avoidance.normalized() * avoidance_weight).normalized()
	if desired_direction.length_squared() < 0.01:
		return 0.0
	var angle := _signed_angle_to_direction(desired_direction.normalized())
	return clampf(angle * 1.8, -1.0, 1.0)


func _get_role_direction() -> Vector3:
	if boarding_order_active and is_instance_valid(boarding_order_target):
		var target_basis := boarding_order_target.global_transform.basis.orthonormalized()
		var spacing := float(get("_hull_width")) * 0.46 + float(boarding_order_target.get("_hull_width")) * 0.46 + 1.15
		var approach_point := boarding_order_target.global_position + target_basis.x.normalized() * boarding_order_side * spacing
		approach_point += target_basis.z.normalized() * 2.5
		var approach := approach_point - global_position
		approach.y = 0.0
		return approach.normalized() if approach.length_squared() > 0.01 else -global_transform.basis.z
	if _has_strategic_order():
		var to_station := strategic_order_station - global_position
		to_station.y = 0.0
		var arrival_radius := 11.0 if strategic_order_kind == "guard_fort" else 14.0
		if to_station.length() > arrival_radius:
			return to_station.normalized()
	if not _has_target():
		return -global_transform.basis.z
	var to_target := target_ship.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return -global_transform.basis.z
	var distance := to_target.length()
	to_target = to_target.normalized()
	var tangent := to_target.rotated(Vector3.UP, float(side_preference) * PI * 0.5)
	var coordinated_range := _get_coordinated_desired_range()
	var range_bias := clampf((distance - coordinated_range) / maxf(coordinated_range, 1.0), -0.9, 0.9)
	if _morale_retreating:
		var retreat_direction := global_position - battlefield_origin
		retreat_direction.y = 0.0
		if retreat_direction.length_squared() < 0.01:
			retreat_direction = -to_target
		return retreat_direction.normalized()

	if ai_role == "courier":
		var outward := global_position - battlefield_origin
		outward.y = 0.0
		if outward.length_squared() < 0.01:
			outward = -to_target
		return (outward.normalized() * 0.75 - to_target * 0.65).normalized()

	if ai_role == "raider":
		var stern := target_ship.global_position + target_ship.global_transform.basis.z.normalized() * 12.0
		stern += target_ship.global_transform.basis.x.normalized() * float(side_preference) * 11.0
		var to_stern := stern - global_position
		to_stern.y = 0.0
		if to_stern.length() > 10.0:
			return to_stern.normalized()

	if ai_role == "escort" and is_instance_valid(formation_anchor_ship) and formation_anchor_ship != self:
		var anchor_to_enemy := target_ship.global_position - formation_anchor_ship.global_position
		anchor_to_enemy.y = 0.0
		if anchor_to_enemy.length_squared() > 0.01:
			var screen_point := formation_anchor_ship.global_position + anchor_to_enemy.normalized() * 14.0
			var to_screen := screen_point - global_position
			to_screen.y = 0.0
			if to_screen.length() > 12.0:
				return to_screen.normalized()

	if ai_role == "blockade":
		var to_station := formation_station - global_position
		to_station.y = 0.0
		if to_station.length() > 18.0:
			return to_station.normalized()
		return (tangent + to_target * range_bias * 0.35).normalized()

	match combat_state:
		CombatState.PURSUE:
			return (to_target + tangent * 0.25).normalized()
		CombatState.BROADSIDE:
			return tangent
		CombatState.EVADE:
			return (-to_target + tangent * 0.55).normalized()
		CombatState.CRIPPLED:
			return (-to_target + tangent * 0.25).normalized()
	return (tangent + to_target * range_bias * (0.55 if ai_role == "line_ship" else 0.9)).normalized()


func _get_fire_request() -> int:
	if boarding_order_active or _target_is_prize_protected() or is_incapacitated or not _has_target():
		return 0
	var to_target := target_ship.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > fire_range or distance < 4.0:
		return 0
	if ai_role != "courier" and combat_state != CombatState.BROADSIDE and combat_state != CombatState.ORBIT:
		return 0
	if combat_state == CombatState.BROADSIDE and _broadside_windup > 0.0:
		return 0

	to_target = to_target.normalized()
	var starboard_score := to_target.dot(global_transform.basis.x.normalized())
	if starboard_score > 0.72 and can_fire_side(1):
		choose_tactical_shot_mode(distance)
		return 1
	if starboard_score < -0.72 and can_fire_side(-1):
		choose_tactical_shot_mode(distance)
		return -1
	return 0


func choose_tactical_shot_mode(distance: float) -> String:
	set_shot_mode(SHOT_ROUND)
	return SHOT_ROUND


func _target_sail_ratio() -> float:
	if not _has_target():
		return 1.0
	var max_sail := maxf(float(target_ship.get("max_sail_integrity")), 1.0)
	return clampf(float(target_ship.get("sail_integrity")) / max_sail, 0.0, 1.0)


func _get_fire_aim_point(side: int) -> Vector3:
	if side == 0 or not _has_target():
		return Vector3.ZERO
	_update_ranging_solution()
	var lead_time := clampf(global_position.distance_to(target_ship.global_position) / cannon_shot_speed, 0.15, 1.25)
	var target_velocity := Vector3.ZERO
	if target_ship.get("velocity") is Vector3:
		target_velocity = target_ship.get("velocity")
	var aim_point := target_ship.global_position + target_velocity * lead_time * 0.35 + Vector3.UP * 0.75
	var distance := global_position.distance_to(target_ship.global_position)
	var distance_ratio := clampf(distance / maxf(fire_range, 1.0), 0.0, 1.0)
	var fresh_solution_error := lerpf(5.8, 9.8, distance_ratio)
	var learned_solution_error := lerpf(2.8, 5.2, distance_ratio)
	var miss_radius := lerpf(fresh_solution_error, learned_solution_error, _ranging_quality)
	match hull_class:
		"Ship of the Line":
			miss_radius *= 0.98
		"Man o' War":
			miss_radius *= 1.10
		"Sloop":
			miss_radius *= 1.08
	if current_shot_mode == SHOT_CHAIN:
		miss_radius *= 1.12
	var miss_angle := randf() * TAU
	aim_point += Vector3(cos(miss_angle), randf_range(-0.18, 0.42), sin(miss_angle)) * randf_range(miss_radius * 0.42, miss_radius)
	return aim_point


func _try_fire(side: int, aim_direction := Vector3.ZERO, aim_point := Vector3.ZERO, use_aim_point := false) -> bool:
	set_aim_focus(lerpf(0.06, 0.58, clampf(_ranging_quality / 0.68, 0.0, 1.0)))
	var fired := super._try_fire(side, aim_direction, aim_point, use_aim_point)
	if fired:
		var gain := 0.10 if hull_class in ["Ship of the Line", "Man o' War"] else 0.13
		_ranging_quality = clampf(_ranging_quality + gain, 0.0, 0.68)
	return fired


func _update_ranging_solution() -> void:
	if not _has_target():
		_reset_ranging_solution()
		return
	var target_id := target_ship.get_instance_id()
	var target_velocity: Vector3 = target_ship.get("velocity") if target_ship.get("velocity") is Vector3 else Vector3.ZERO
	var target_forward := -target_ship.global_transform.basis.z.normalized()
	if _ranging_target_id != target_id:
		_ranging_target_id = target_id
		_ranging_quality = 0.0
	else:
		var speed_change := absf(target_velocity.length() - _ranging_target_velocity.length())
		var course_change := acos(clampf(target_forward.dot(_ranging_target_forward), -1.0, 1.0))
		if speed_change > 1.4 or course_change > 0.14:
			_ranging_quality *= 0.30
		elif speed_change > 0.65 or course_change > 0.065:
			_ranging_quality *= 0.68
	_ranging_target_velocity = target_velocity
	_ranging_target_forward = target_forward


func _reset_ranging_solution() -> void:
	_ranging_quality = 0.0
	_ranging_target_id = 0
	_ranging_target_velocity = Vector3.ZERO
	_ranging_target_forward = Vector3.FORWARD


func _acquire_target() -> void:
	if boarding_order_active and is_instance_valid(boarding_order_target):
		target_ship = boarding_order_target
		return
	var previous_target := target_ship
	var best: Node3D = null
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("combat_ships"):
		if candidate == self or not (candidate is Node3D):
			continue
		var candidate_ship := candidate as Node3D
		if int(candidate.get("team_id")) == team_id or bool(candidate.get("is_sunk")) or bool(candidate.get("is_incapacitated")) or bool(candidate.get_meta("boarding_protected", false)):
			continue
		var score := _get_target_assignment_score(candidate_ship)
		if ai_role == "escort" and is_instance_valid(formation_anchor_ship):
			var threat_distance := formation_anchor_ship.global_position.distance_squared_to(candidate_ship.global_position)
			score = score * 0.38 + threat_distance * 0.62
		if candidate_ship == previous_target:
			score *= 0.82
		if score < best_score:
			best_score = score
			best = candidate_ship
	target_ship = best
	if target_ship != previous_target:
		_reset_ranging_solution()
	_target_commitment_timer = randf_range(3.8, 5.8) if target_ship else 0.8


func _get_target_assignment_score(candidate: Node3D) -> float:
	var score := global_position.distance_squared_to(candidate.global_position)
	var claims := _count_friendly_target_claims(candidate)
	var target_capacity := _get_target_attacker_capacity(candidate)
	var claim_pressure := 1.0 + float(claims) * 0.72
	if claims >= target_capacity:
		claim_pressure += float(claims - target_capacity + 1) * 1.25
	score *= claim_pressure

	if ai_role == "raider":
		var stern := candidate.global_position + candidate.global_transform.basis.z.normalized() * 11.0
		score = score * 0.38 + global_position.distance_squared_to(stern) * 0.62
		if claims == 0:
			score *= 0.72
	elif ai_role in ["line_ship", "man_o_war"]:
		var target_weight := clampf(float(candidate.get("max_health")) / 480.0, 0.2, 1.0)
		score *= lerpf(1.20, 0.76, target_weight)
	elif ai_role == "blockade":
		score *= 1.0 + absf(candidate.global_position.distance_to(battlefield_origin) - desired_range) / 180.0
	return score


func _count_friendly_target_claims(candidate: Node3D) -> int:
	var claims := 0
	for ship_node in get_tree().get_nodes_in_group("combat_ships"):
		if ship_node == self or not (ship_node is Node3D) or int(ship_node.get("team_id")) != team_id:
			continue
		if bool(ship_node.get("is_sunk")) or bool(ship_node.get("is_incapacitated")):
			continue
		if ship_node.has_method("clear_boarding_order") and bool(ship_node.get("boarding_order_active")):
			continue
		if ship_node.get("target_ship") == candidate:
			claims += 1
	return claims


func _get_target_attacker_capacity(candidate: Node3D) -> int:
	match String(candidate.get("hull_class")):
		"Man o' War", "Ship of the Line":
			return 3
		"Frigate":
			return 2
	return 1


func _get_coordinated_desired_range() -> float:
	var lane := float((fleet_slot_index % 3) - 1)
	var lane_spacing := 4.0
	if hull_class in ["Ship of the Line", "Man o' War"]:
		lane_spacing = 6.0
	elif hull_class == "Sloop":
		lane_spacing = 3.0
	return maxf(desired_range + lane * lane_spacing, 18.0)


func _update_fleet_awareness(delta: float) -> void:
	_fleet_awareness_timer -= delta
	if _fleet_awareness_timer > 0.0:
		return
	_fleet_awareness_timer = 0.16 + float(fleet_slot_index % 3) * 0.025
	var avoidance := Vector3.ZERO
	var traffic_brake := 0.0
	var forward := -global_transform.basis.z.normalized()
	forward.y = 0.0
	forward = forward.normalized()
	var self_velocity: Vector3 = velocity
	for ship_node in get_tree().get_nodes_in_group("combat_ships"):
		if ship_node == self or not (ship_node is Node3D) or bool(ship_node.get("is_sunk")):
			continue
		var other := ship_node as Node3D
		if boarding_order_active and other == boarding_order_target:
			continue
		var offset := global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.05:
			offset = global_transform.basis.x.normalized() * (1.0 if get_instance_id() > other.get_instance_id() else -1.0)
			distance = 0.05
		var friendly := int(other.get("team_id")) == team_id
		var combined_length := (float(get("_hull_length")) + float(other.get("_hull_length"))) * 0.48
		var safety_radius := combined_length + (4.6 if friendly else 2.2)
		var other_velocity: Vector3 = other.get("velocity") if other.get("velocity") is Vector3 else Vector3.ZERO
		var predicted_offset := offset + (self_velocity - other_velocity) * 1.25
		var predicted_distance := predicted_offset.length()
		if distance < safety_radius * 1.65 or predicted_distance < safety_radius:
			var separation := clampf(1.0 - minf(distance, predicted_distance) / maxf(safety_radius * 1.65, 0.1), 0.0, 1.0)
			var away := offset.normalized()
			if predicted_distance < distance and predicted_distance > 0.05:
				away = (away + predicted_offset.normalized() * 1.35).normalized()
			avoidance += away * separation * (1.55 if friendly else 0.82)
			var to_other := -offset.normalized()
			if friendly and forward.dot(to_other) > 0.48 and distance < safety_radius * 1.45:
				traffic_brake = maxf(traffic_brake, separation)

		if bool(other.get_meta("boarding_protected", false)) and int(other.get_meta("boarding_reserved_by", 0)) != get_instance_id():
			var exclusion_radius := maxf(25.0, float(other.get("_hull_length")) + 13.0)
			if distance < exclusion_radius:
				avoidance += offset.normalized() * clampf(1.0 - distance / exclusion_radius, 0.0, 1.0) * 2.35
				traffic_brake = maxf(traffic_brake, clampf(1.0 - distance / exclusion_radius, 0.0, 1.0) * 0.72)
	_fleet_avoidance = _fleet_avoidance.lerp(avoidance, 0.72)
	if _fleet_avoidance.length_squared() > 1.0:
		_fleet_avoidance = _fleet_avoidance.normalized()
	_traffic_brake = lerpf(_traffic_brake, clampf(traffic_brake, 0.0, 1.0), 0.74)
	_update_island_awareness(forward, self_velocity)


func _update_island_awareness(forward: Vector3, self_velocity: Vector3) -> void:
	var speed_ratio := clampf(Vector2(self_velocity.x, self_velocity.z).length() / maxf(max_speed, 0.1), 0.0, 1.0)
	var hull_length := float(get("_hull_length"))
	var hull_width := float(get("_hull_width"))
	var lookahead := 22.0 + hull_length * 0.72 + speed_ratio * 32.0
	var predicted_bow := global_position + forward * (hull_length * 0.40 + lookahead * 0.42)
	var strongest := 0.0
	var avoidance := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("island_obstacle"):
		if not (node is Node3D):
			continue
		var island := node as Node3D
		var to_island := island.global_position - global_position
		to_island.y = 0.0
		var forward_distance := to_island.dot(forward)
		if forward_distance < -hull_length * 0.25 or forward_distance > lookahead:
			continue
		var lateral := to_island - forward * forward_distance
		var island_radius := float(island.get_meta("collision_radius", 12.0))
		var safe_radius := island_radius + hull_width * 0.65 + 5.0
		var predicted_offset := predicted_bow - island.global_position
		predicted_offset.y = 0.0
		var corridor_distance := minf(lateral.length(), predicted_offset.length())
		if corridor_distance >= safe_radius:
			continue
		var danger := clampf(1.0 - corridor_distance / maxf(safe_radius, 0.1), 0.0, 1.0)
		danger *= clampf(1.15 - forward_distance / maxf(lookahead, 0.1) * 0.62, 0.45, 1.15)
		var pass_side := signf(forward.cross(to_island).y)
		if absf(pass_side) < 0.1:
			pass_side = float(side_preference)
		else:
			pass_side = -pass_side
		var tangent := forward.rotated(Vector3.UP, pass_side * PI * 0.5)
		var away := global_position - island.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = tangent
		avoidance += (tangent * 1.35 + away.normalized() * 0.85).normalized() * danger
		strongest = maxf(strongest, danger)
	_island_avoidance = _island_avoidance.lerp(avoidance.normalized() if avoidance.length_squared() > 0.01 else Vector3.ZERO, 0.68)
	_island_brake = lerpf(_island_brake, strongest, 0.72)


func _has_target() -> bool:
	return is_instance_valid(target_ship) and not bool(target_ship.get("is_sunk")) and int(target_ship.get("team_id")) != team_id


func set_boarding_order(next_target: Node3D, approach_side := 1.0) -> void:
	boarding_order_target = next_target
	boarding_order_side = signf(approach_side) if absf(approach_side) > 0.01 else 1.0
	boarding_order_active = is_instance_valid(next_target)
	if boarding_order_active:
		target_ship = next_target
		_morale_retreating = false
		_set_combat_state(CombatState.BOARDING, 0.2)


func clear_boarding_order() -> void:
	boarding_order_active = false
	boarding_order_target = null
	if combat_state == CombatState.BOARDING:
		combat_state = CombatState.PURSUE
	_state_timer = 0.0


func set_strategic_order(kind: String, order_target: Node3D, station: Vector3, focus_target: Node3D = null, duration := 12.0) -> void:
	strategic_order_kind = kind
	strategic_order_target = order_target
	strategic_order_station = station
	strategic_order_time = maxf(duration, 0.1)
	if is_instance_valid(focus_target) and int(focus_target.get("team_id")) != team_id:
		target_ship = focus_target
	_target_scan_timer = 0.0
	_target_commitment_timer = strategic_order_time
	_morale_retreating = false
	if combat_state != CombatState.BOARDING:
		_set_combat_state(CombatState.PURSUE, 0.2)


func clear_strategic_order() -> void:
	strategic_order_kind = ""
	strategic_order_target = null
	strategic_order_time = 0.0
	_target_commitment_timer = 0.0


func _update_strategic_order(delta: float) -> void:
	if strategic_order_kind.is_empty():
		return
	strategic_order_time = maxf(strategic_order_time - delta, 0.0)
	if strategic_order_time <= 0.0 or not is_instance_valid(strategic_order_target):
		clear_strategic_order()


func _has_strategic_order() -> bool:
	return not strategic_order_kind.is_empty() and strategic_order_time > 0.0 and is_instance_valid(strategic_order_target)


func _target_is_prize_protected() -> bool:
	if not _has_target():
		return false
	return bool(target_ship.get("is_incapacitated")) or bool(target_ship.get_meta("boarding_protected", false))


func get_ai_state_name() -> String:
	if is_surrendered:
		return "surrendered"
	if _has_retreated:
		return "retreated"
	if _morale_retreating:
		return "fleeing"
	match combat_state:
		CombatState.PURSUE:
			return "pursue"
		CombatState.ORBIT:
			return "orbit"
		CombatState.BROADSIDE:
			return "broadside"
		CombatState.EVADE:
			return "evade"
		CombatState.CRIPPLED:
			return "crippled"
		CombatState.DISABLED:
			return "disabled"
		CombatState.BOARDING:
			return "boarding"
	return "unknown"


func get_ai_role_name() -> String:
	return ai_role


func get_broadside_windup() -> float:
	return _broadside_windup


func begin_broadside_windup(side: int) -> void:
	if side == 0:
		return
	_broadside_windup = broadside_windup_duration
	broadside_warning.emit(self, side)


func _update_combat_state(delta: float) -> void:
	if is_incapacitated:
		combat_state = CombatState.DISABLED
		return
	if boarding_order_active and is_instance_valid(boarding_order_target):
		combat_state = CombatState.BOARDING
		return
	if _morale_retreating:
		_set_combat_state(CombatState.EVADE, 1.2)
		return
	if not _has_target() or is_sunk:
		combat_state = CombatState.CRIPPLED
		return

	_state_timer = maxf(_state_timer - delta, 0.0)
	_maneuver_timer = maxf(_maneuver_timer - delta, 0.0)
	if _maneuver_timer <= 0.0:
		_maneuver_timer = randf_range(3.0, 6.5)
		if ai_role != "blockade" and randf() < 0.42:
			side_preference *= -1

	var to_target := target_ship.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.01:
		return
	var health_ratio := health / max_health
	var sail_ratio := sail_integrity / max_sail_integrity
	var cannon_ratio := maxf(port_cannon_integrity, starboard_cannon_integrity) / max_cannon_integrity
	var broadside_alignment := absf(to_target.normalized().dot(global_transform.basis.x.normalized()))
	var has_loaded_guns := can_fire_side(1) or can_fire_side(-1)

	if health_ratio < 0.26 or sail_ratio < 0.22:
		_set_combat_state(CombatState.CRIPPLED, 1.8)
	elif ai_role == "courier":
		_set_combat_state(CombatState.EVADE, 0.8)
	elif distance < desired_range * 0.52:
		_set_combat_state(CombatState.EVADE, 1.4)
	elif distance > fire_range * 0.95:
		_set_combat_state(CombatState.PURSUE, 1.0)
	elif broadside_alignment > 0.72 and has_loaded_guns and cannon_ratio > 0.18:
		_set_combat_state(CombatState.BROADSIDE, 0.8)
	else:
		_set_combat_state(CombatState.ORBIT, 1.1)


func _set_combat_state(next_state: int, minimum_time: float) -> void:
	var previous_state := combat_state
	if combat_state == next_state and _state_timer > 0.0:
		return
	if _state_timer > 0.0 and next_state != CombatState.CRIPPLED:
		return
	combat_state = next_state
	_state_timer = minimum_time
	if next_state == CombatState.BROADSIDE and previous_state != CombatState.BROADSIDE and _has_target():
		var to_target := target_ship.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			var side := 1 if to_target.normalized().dot(global_transform.basis.x.normalized()) > 0.0 else -1
			begin_broadside_windup(side)


func _update_retreat_state() -> void:
	if ai_role != "courier" or _has_retreated or is_sunk or is_incapacitated:
		return
	var offset := global_position - battlefield_origin
	offset.y = 0.0
	if offset.length() >= escape_radius:
		_has_retreated = true
		retreated.emit(self)


func _update_morale_response(_delta: float) -> void:
	_morale_retreating = false


func surrender_to(_source: Node = null) -> bool:
	return false


func _apply_role_identity() -> void:
	ai_role = _normalize_role(ai_role)
	if team_id == 0:
		hull_color = Color(0.10, 0.22, 0.30)
		trim_color = Color(0.28, 0.62, 0.78)
		sail_color = Color(0.78, 0.86, 0.84)
	else:
		hull_color = Color(0.16, 0.075, 0.045)
		trim_color = Color(0.56, 0.22, 0.13)
		sail_color = Color(0.72, 0.68, 0.58)
	_apply_role_parameters()


func _apply_role_parameters() -> void:
	match _normalize_role(ai_role):
		"courier":
			desired_range = 55.0
			fire_range = 44.0
		"raider":
			desired_range = 31.0
			fire_range = 50.0
		"escort":
			desired_range = 34.0
			fire_range = 51.0
		"blockade":
			desired_range = 42.0
			fire_range = 58.0
		"line_ship":
			desired_range = 44.0
			fire_range = 58.0
		"man_o_war":
			desired_range = 52.0
			fire_range = 66.0


func _normalize_role(role: String) -> String:
	var key := role.to_lower().replace(" ", "_")
	if key.contains("courier") or key.contains("merchant") or key.contains("treasure"):
		return "courier"
	if key.contains("escort") or key.contains("patrol"):
		return "escort"
	if key.contains("blockade"):
		return "blockade"
	if key.contains("man_o") or key.contains("man-of-war") or key.contains("manowar"):
		return "man_o_war"
	if key.contains("line") or key.contains("heavy") or key.contains("frigate"):
		return "line_ship"
	return "raider"
