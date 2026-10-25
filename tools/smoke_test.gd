extends SceneTree

const CombatFx := preload("res://scripts/combat_fx.gd")
const Cannonball := preload("res://scripts/cannonball.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("Could not load main scene.")
		quit(1)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)

	for i in range(12):
		await process_frame
	if bool(scene.get("main_menu_open")):
		scene.call("_on_main_campaign_requested")
		await process_frame

	var player := scene.get_node_or_null("PlayerShip")
	if player == null:
		push_error("PlayerShip was not created.")
		quit(1)
		return

	if scene.get_node_or_null("ShipCamera") == null:
		push_error("ShipCamera was not created.")
		quit(1)
		return
	var nature_instance_count := 0
	var combat_islands := scene.find_children("Island_*", "StaticBody3D", true, false)
	for island in combat_islands:
		for child in island.get_children():
			if child.name.begins_with("Nature_"):
				nature_instance_count += 1
	if combat_islands.size() != 3 or nature_instance_count < 70:
		push_error("Combat island nature population is incomplete: %d islands, %d assets" % [combat_islands.size(), nature_instance_count])
		quit(1)
		return

	var campaign_map := scene.get_node_or_null("CampaignMap")
	if campaign_map == null or not campaign_map.has_method("get_selected_region") or not campaign_map.has_method("get_player_position"):
		push_error("Campaign map was not created.")
		quit(1)
		return
	if campaign_map.find_child("WorldMapCanvas", true, false) == null:
		push_error("Campaign map does not expose the Warband-style world canvas.")
		quit(1)
		return
	var selected_region: Dictionary = campaign_map.get_selected_region()
	var sortie_region: Dictionary = selected_region
	var campaign_party_count_before := -1
	var campaign_cargo_before := {}
	var campaign_reputation_before := {}
	var campaign_renown_before := -1
	var encounter_party_for_assert: Dictionary = {}
	if not selected_region.has("name") or not selected_region.has("position"):
		push_error("Campaign map selected location data is invalid.")
		quit(1)
		return
	if campaign_map.has_method("get_party_count") and int(campaign_map.get_party_count()) < 16:
		push_error("Campaign map does not have moving NPC parties.")
		quit(1)
		return
	if not campaign_map.has_method("get_harbor_ship_count") or int(campaign_map.get_harbor_ship_count()) < 1:
		push_error("Campaign map does not show a starting harbor ship.")
		quit(1)
		return
	if not campaign_map.has_method("can_enter_selected_region") or not campaign_map.can_enter_selected_region():
		push_error("Campaign map does not expose a nearby enterable starting harbor.")
		quit(1)
		return
	if not get_nodes_in_group("enemies").is_empty():
		push_error("Campaign map started with combat enemies already spawned.")
		quit(1)
		return
	if not paused or not campaign_map.visible:
		push_error("Game did not start on the campaign map.")
		quit(1)
		return
	if campaign_map.has_method("get_party_snapshot"):
		var parties_before: Array = campaign_map.get_party_snapshot()
		for i in range(8):
			await process_frame
		var parties_after: Array = campaign_map.get_party_snapshot()
		if parties_before.is_empty() or parties_after.is_empty():
			push_error("Campaign map NPC party snapshot is empty.")
			quit(1)
			return
		var before_party_pos: Vector2 = parties_before[0].get("position", Vector2.ZERO)
		var after_party_pos: Vector2 = parties_after[0].get("position", Vector2.ZERO)
		if before_party_pos.distance_to(after_party_pos) < 0.0001:
			push_error("Campaign map NPC parties did not move.")
			quit(1)
			return
		var first_party: Dictionary = parties_after[0]
		if not first_party.has("faction") or not first_party.has("role") or not first_party.has("intent"):
			push_error("Campaign map NPC parties do not expose faction, role and intent data.")
			quit(1)
			return
		if String(first_party.get("intent", "")).is_empty():
			push_error("Campaign map NPC party intent is empty.")
			quit(1)
			return
	var start_map_position: Vector2 = campaign_map.get_player_position()
	campaign_map.call("_set_player_target_from_point", Vector2(840.0, 360.0))
	for i in range(12):
		await process_frame
	if start_map_position.distance_to(campaign_map.get_player_position()) < 0.001:
		push_error("Campaign map player party did not move freely.")
		quit(1)
		return
	campaign_map.call("_show_bottom_panel", "Reports")
	if campaign_map.has_method("has_open_panel") and not campaign_map.has_open_panel():
		push_error("Campaign map bottom bar panels do not open.")
		quit(1)
		return
	campaign_map.call("_show_bottom_panel", "Notes")
	if campaign_map.has_method("get_open_panel_section") and String(campaign_map.get_open_panel_section()) != "Notes":
		push_error("Campaign map Notes panel did not open from the bottom bar.")
		quit(1)
		return
	if campaign_map.has_method("press_bottom_button"):
		campaign_map.press_bottom_button("Party")
		if String(campaign_map.get_open_panel_section()) != "Party":
			push_error("Campaign map bottom buttons do not switch to Party.")
			quit(1)
			return
	if campaign_map.has_method("perform_port_service") and campaign_map.has_method("get_ship_condition") and campaign_map.has_method("get_cargo_snapshot"):
		campaign_map.set("_ship_condition", {"hull": 55, "repair_supplies": 1, "morale": 42})
		var service_cargo_before: Dictionary = campaign_map.get_cargo_snapshot()
		if not campaign_map.perform_port_service("repair"):
			push_error("Campaign port repair service did not run at the starting harbor.")
			quit(1)
			return
		var repaired_condition: Dictionary = campaign_map.get_ship_condition()
		if int(repaired_condition.get("hull", 0)) < 100:
			push_error("Campaign port repair did not restore hull condition.")
			quit(1)
			return
		var service_cargo_after_repair: Dictionary = campaign_map.get_cargo_snapshot()
		if int(service_cargo_after_repair.get("timber", 0)) >= int(service_cargo_before.get("timber", 0)):
			push_error("Campaign port repair did not consume timber.")
			quit(1)
			return
		if not campaign_map.perform_port_service("resupply"):
			push_error("Campaign port resupply service did not run.")
			quit(1)
			return
		var resupplied_condition: Dictionary = campaign_map.get_ship_condition()
		if int(resupplied_condition.get("repair_supplies", 0)) < 3:
			push_error("Campaign port resupply did not refill repair kits.")
			quit(1)
			return
		if not campaign_map.perform_port_service("rest"):
			push_error("Campaign rest service did not run.")
			quit(1)
			return
		var rested_condition: Dictionary = campaign_map.get_ship_condition()
		if int(rested_condition.get("morale", 0)) <= int(resupplied_condition.get("morale", 0)):
			push_error("Campaign rest did not improve morale.")
			quit(1)
			return
	if campaign_map.has_method("get_nearby_encounter") and campaign_map.has_method("can_enter_selected_party"):
		var party_snapshot: Array = campaign_map.get_party_snapshot()
		campaign_party_count_before = party_snapshot.size()
		if campaign_map.has_method("get_cargo_snapshot"):
			campaign_cargo_before = campaign_map.get_cargo_snapshot()
		if campaign_map.has_method("get_reputation_snapshot"):
			campaign_reputation_before = campaign_map.get_reputation_snapshot()
		if campaign_map.has_method("get_renown"):
			campaign_renown_before = int(campaign_map.get_renown())
		var encounter_party: Dictionary = party_snapshot[0]
		encounter_party_for_assert = encounter_party.duplicate(true)
		campaign_map.set("_player_position", encounter_party.get("position", campaign_map.get_player_position()))
		campaign_map.set("_selected_party_index", 0)
		campaign_map.call("_update_nearby_encounter")
		if not campaign_map.can_enter_selected_party():
			push_error("Campaign map close NPC fleet did not become enterable.")
			quit(1)
			return
		if campaign_map.get_nearby_encounter().is_empty():
			push_error("Campaign map did not expose nearby encounter data.")
			quit(1)
			return
		if campaign_map.has_method("get_encounter_count") and int(campaign_map.get_encounter_count()) < 1:
			push_error("Campaign map did not log the nearby encounter.")
			quit(1)
			return
		if campaign_map.has_method("_build_party_encounter_region"):
			sortie_region = campaign_map.call("_build_party_encounter_region", encounter_party)
			if not sortie_region.has("encounter_party"):
				push_error("Campaign map did not build an encounter sortie region.")
				quit(1)
				return
	if player.has_method("disable_ship"):
		player.disable_ship(false)
		player.global_position.y = -4.0
	if campaign_map.has_method("get_ship_condition"):
		campaign_map.set("_ship_condition", {"hull": 82, "repair_supplies": 2, "morale": 60})
	campaign_map.deploy_requested.emit(sortie_region)
	await process_frame
	if paused or campaign_map.visible:
		push_error("Campaign map did not deploy into sailing mode.")
		quit(1)
		return
	if bool(player.get("is_sunk")) or float(player.get("health")) <= 0.0:
		push_error("Player ship started the sortie sunk or destroyed.")
		quit(1)
		return
	if absf(float(player.get("health")) - float(player.get("max_health")) * 0.82) > 0.75:
		push_error("Campaign ship condition was not applied to player sortie health.")
		quit(1)
		return
	if int(player.get("repair_supplies")) != 2:
		push_error("Campaign repair kit count was not applied to player sortie.")
		quit(1)
		return
	if absf(player.global_position.y) > 0.08:
		push_error("Player ship kept its sunk world height after campaign deploy.")
		quit(1)
		return
	if int(player.get("collision_layer")) == 0 or int(player.get("collision_mask")) == 0:
		push_error("Player ship started the sortie with disabled collision.")
		quit(1)
		return
	if get_nodes_in_group("enemies").is_empty():
		push_error("Campaign deploy did not spawn combat NPC ships.")
		quit(1)
		return
	if sortie_region.has("encounter_party"):
		var spawned_enemies := get_nodes_in_group("enemies")
		var first_enemy := spawned_enemies[0] as Node
		if first_enemy == null or not first_enemy.has_meta("campaign_role"):
			push_error("Campaign encounter did not stamp spawned enemies with campaign role metadata.")
			quit(1)
			return
		if String(first_enemy.get_meta("campaign_role")) != String(sortie_region.get("encounter_party", {}).get("role", "")):
			push_error("Campaign encounter spawned enemies with the wrong role metadata.")
			quit(1)
			return
		if spawned_enemies.size() < 3:
			push_error("Treasure fleet encounter did not spawn an escort group.")
			quit(1)
			return
		if campaign_map.has_method("resolve_encounter_result") and campaign_map.has_method("get_defeated_party_count") and campaign_map.has_method("get_cargo_snapshot") and campaign_map.has_method("get_reputation_snapshot") and campaign_map.has_method("get_renown"):
			scene.set("active_sortie_captures", 1)
			scene.call("_resolve_active_campaign_encounter")
			if int(campaign_map.get_defeated_party_count()) < 1:
				push_error("Campaign encounter result did not record a defeated/captured party.")
				quit(1)
				return
			var campaign_party_count_after := int(campaign_map.get_party_count()) if campaign_map.has_method("get_party_count") else campaign_party_count_before
			if campaign_party_count_before >= 0 and campaign_party_count_after >= campaign_party_count_before:
				push_error("Campaign encounter result did not remove the defeated party from the map.")
				quit(1)
				return
			var campaign_cargo_after: Dictionary = campaign_map.get_cargo_snapshot()
			if int(campaign_cargo_after.get("timber", 0)) <= int(campaign_cargo_before.get("timber", 0)):
				push_error("Campaign encounter result did not add loot to cargo.")
				quit(1)
				return
			var campaign_reputation_after: Dictionary = campaign_map.get_reputation_snapshot()
			if int(campaign_reputation_after.get("Crown Dominion", 0)) >= int(campaign_reputation_before.get("Crown Dominion", 0)):
				push_error("Campaign encounter result did not reduce hostile faction reputation.")
				quit(1)
				return
			if int(campaign_reputation_after.get("Free Captains", 0)) <= int(campaign_reputation_before.get("Free Captains", 0)):
				push_error("Campaign encounter result did not improve rival-friendly reputation.")
				quit(1)
				return
			if int(campaign_map.get_renown()) <= campaign_renown_before:
				push_error("Campaign encounter result did not increase captain renown.")
				quit(1)
				return
			if campaign_map.has_method("get_party_relation_state"):
				var relation_probe: Dictionary = {
					"faction": String(encounter_party_for_assert.get("faction", "Crown Dominion")),
					"stance": "shadow",
				}
				var relation_state: Dictionary = campaign_map.get_party_relation_state(relation_probe)
				if String(relation_state.get("effective_stance", "")) != "chase":
					push_error("Hostile reputation did not make patrol-style fleets aggressive.")
					quit(1)
					return
				if float(relation_state.get("detection_distance", 0.0)) <= 0.115:
					push_error("Hostile reputation did not expand fleet detection distance.")
					quit(1)
					return

	var aim_guide := scene.get_node_or_null("AimGuide")
	if aim_guide == null or not aim_guide.has_method("show_solution"):
		push_error("AimGuide was not created.")
		quit(1)
		return
	var danger_guide := scene.get_node_or_null("BroadsideDangerGuide")
	if danger_guide == null or not danger_guide.has_method("show_threats"):
		push_error("Broadside danger guide was not created.")
		quit(1)
		return

	var camera := scene.get_node_or_null("ShipCamera")
	if not camera.has_method("set_aiming") or not camera.has_method("get_aim_direction") or not camera.has_method("get_aim_point") or not camera.has_method("get_aim_side") or not camera.has_method("apply_mouse_delta"):
		push_error("ShipCamera was not created with aim controls.")
		quit(1)
		return
	if not camera.has_method("get_feedback_state"):
		push_error("ShipCamera does not expose combat feedback state.")
		quit(1)
		return
	if not player.has_method("get_broadside_side_for_camera_aim"):
		push_error("PlayerShip does not expose camera aim broadside resolution.")
		quit(1)
		return

	camera.set_aiming(true)
	var aim_direction: Vector3 = camera.get_aim_direction()
	if aim_direction.length_squared() < 0.01:
		push_error("ShipCamera aim direction is invalid.")
		quit(1)
		return
	camera.apply_mouse_delta(Vector2(160.0, 0.0))
	await process_frame
	var rotated_aim_direction: Vector3 = camera.get_aim_direction()
	if aim_direction.dot(rotated_aim_direction) > 0.995:
		push_error("ShipCamera aim direction did not rotate after mouse delta.")
		quit(1)
		return
	var aim_point: Vector3 = camera.get_aim_point()
	if aim_point.distance_to(camera.global_position) < 8.0:
		push_error("ShipCamera aim point is invalid.")
		quit(1)
		return
	var mid_range: float = player.global_position.distance_to(aim_point)
	camera.apply_mouse_delta(Vector2(0.0, -520.0))
	await process_frame
	var long_aim_point: Vector3 = camera.get_aim_point()
	var long_range: float = player.global_position.distance_to(long_aim_point)
	camera.apply_mouse_delta(Vector2(0.0, 520.0))
	await process_frame
	var short_aim_point: Vector3 = camera.get_aim_point()
	var short_range: float = player.global_position.distance_to(short_aim_point)
	if long_range <= mid_range + 8.0 or short_range >= long_range - 30.0:
		push_error("ShipCamera vertical aim does not control broadside range.")
		quit(1)
		return
	camera.apply_mouse_delta(Vector2(0.0, -520.0))
	await process_frame
	aim_point = camera.get_aim_point()
	var far_aim_point: Vector3 = camera.get_aim_point(155.0)
	if player.global_position.distance_to(far_aim_point) < 140.0:
		push_error("ShipCamera aim range was not extended for long cannon shots.")
		quit(1)
		return
	var e_bound_to_fire_camera := false
	for event in InputMap.action_get_events("fire_camera"):
		if event is InputEventKey and event.physical_keycode == KEY_E:
			e_bound_to_fire_camera = true
	if not e_bound_to_fire_camera:
		push_error("E key is not bound to aimed broadside fire.")
		quit(1)
		return
	var aim_side := int(camera.get_aim_side())
	if aim_side == 0:
		push_error("ShipCamera aim side is invalid.")
		quit(1)
		return
	var side_score := rotated_aim_direction.dot(player.global_transform.basis.x.normalized())
	var expected_side := 1 if side_score > 0.0 else -1
	if aim_side != expected_side:
		push_error("ShipCamera aim side is reversed.")
		quit(1)
		return
	var wrong_forced_side := -expected_side
	if not player.fire_camera_broadside(rotated_aim_direction, wrong_forced_side, aim_point):
		push_error("PlayerShip did not fire aimed broadside.")
		quit(1)
		return
	if float(player.get_telemetry().get("broadside_recoil", 0.0)) <= 0.0:
		push_error("Broadside fire did not trigger ship recoil feedback.")
		quit(1)
		return
	await create_timer(0.35).timeout
	var cannonballs := get_nodes_in_group("cannonballs")
	if cannonballs.is_empty():
		push_error("Staggered broadside did not create cannonballs.")
		quit(1)
		return
	var broadside_smoke := scene.find_child("BroadsideSmokeBank", true, false)
	if broadside_smoke == null or broadside_smoke.find_child("PowderSmokeBank", true, false) == null or broadside_smoke.find_child("BroadsideFlashLine", true, false) == null:
		push_error("Broadside volley did not create the powder smoke bank VFX.")
		quit(1)
		return
	var first_ball := cannonballs[0]
	var ball_velocity: Vector3 = first_ball.get("velocity")
	var horizontal_velocity := Vector3(ball_velocity.x, 0.0, ball_velocity.z)
	var horizontal_aim := Vector3(rotated_aim_direction.x, 0.0, rotated_aim_direction.z)
	if horizontal_velocity.length_squared() < 0.01 or horizontal_aim.length_squared() < 0.01:
		push_error("Aimed cannonball velocity is invalid.")
		quit(1)
		return
	if horizontal_velocity.normalized().dot(horizontal_aim.normalized()) < 0.68:
		push_error("Aimed cannonball does not travel toward the camera aim direction.")
		quit(1)
		return
	var fired_side_score := horizontal_velocity.normalized().dot(player.global_transform.basis.x.normalized())
	if signf(fired_side_score) != float(expected_side):
		push_error("Aimed cannonball fired from the wrong broadside direction.")
		quit(1)
		return
	var local_ball_position: Vector3 = player.to_local(first_ball.global_position)
	if signf(local_ball_position.x) != float(expected_side):
		push_error("Aimed cannonball spawned from the wrong broadside muzzle.")
		quit(1)
		return

	for old_ball in get_nodes_in_group("cannonballs"):
		if is_instance_valid(old_ball):
			old_ball.queue_free()
	await process_frame
	for aim_case in [
		{"label": "starboard", "side": 1, "direction": player.global_transform.basis.x.normalized()},
		{"label": "port", "side": -1, "direction": -player.global_transform.basis.x.normalized()},
	]:
		player.reset_for_sortie()
		for old_ball in get_nodes_in_group("cannonballs"):
			if is_instance_valid(old_ball):
				old_ball.queue_free()
		await process_frame

		var explicit_side := int(aim_case.get("side", 0))
		var explicit_direction: Vector3 = aim_case.get("direction", Vector3.ZERO)
		var explicit_point: Vector3 = player.global_position + explicit_direction * 72.0 + Vector3.UP * 0.75
		if int(player.get_broadside_side_for_camera_aim(-explicit_direction, explicit_point)) != explicit_side:
			push_error("Camera aim point did not resolve %s broadside." % String(aim_case.get("label", "unknown")))
			quit(1)
			return
		if not player.fire_camera_broadside(-explicit_direction, -explicit_side, explicit_point):
			push_error("PlayerShip did not fire explicit %s aimed broadside." % String(aim_case.get("label", "unknown")))
			quit(1)
			return
		await create_timer(0.35).timeout
		var explicit_balls := get_nodes_in_group("cannonballs")
		if explicit_balls.is_empty():
			push_error("Explicit %s broadside did not spawn cannonballs." % String(aim_case.get("label", "unknown")))
			quit(1)
			return
		var explicit_ball := explicit_balls[0]
		var explicit_velocity: Vector3 = explicit_ball.get("velocity")
		var explicit_horizontal_velocity := Vector3(explicit_velocity.x, 0.0, explicit_velocity.z)
		var explicit_horizontal_aim := Vector3(explicit_direction.x, 0.0, explicit_direction.z)
		if explicit_horizontal_velocity.normalized().dot(explicit_horizontal_aim.normalized()) < 0.72:
			push_error("Explicit %s broadside did not travel toward its aim point." % String(aim_case.get("label", "unknown")))
			quit(1)
			return
		var explicit_local_position: Vector3 = player.to_local(explicit_ball.global_position)
		if signf(explicit_local_position.x) != float(explicit_side):
			push_error("Explicit %s broadside spawned from the opposite muzzle." % String(aim_case.get("label", "unknown")))
			quit(1)
			return
	for old_ball in get_nodes_in_group("cannonballs"):
		if is_instance_valid(old_ball):
			old_ball.queue_free()
	await process_frame
	player.reset_for_sortie()
	player.set_shot_mode("grape")
	if String(player.get("current_shot_mode")) != "round":
		push_error("Removed special ammunition can still override round shot.")
		quit(1)
		return
	for old_ball in get_nodes_in_group("cannonballs"):
		if is_instance_valid(old_ball):
			old_ball.queue_free()
	await process_frame
	if not player.has_method("apply_ram_impact"):
		push_error("PlayerShip does not expose ramming impact combat.")
		quit(1)
		return
	var ram_targets := get_nodes_in_group("enemies")
	if ram_targets.is_empty():
		push_error("No enemy target available for ramming impact test.")
		quit(1)
		return
	var ram_target := ram_targets[0]
	var target_health_before_ram := float(ram_target.get("health"))
	var player_health_before_ram := float(player.get("health"))
	var ram_report: Dictionary = player.apply_ram_impact(ram_target, 13.5)
	if not bool(ram_report.get("applied", false)):
		push_error("Ramming impact did not apply.")
		quit(1)
		return
	if float(ram_target.get("health")) >= target_health_before_ram or float(player.get("health")) >= player_health_before_ram:
		push_error("Ramming impact did not damage both ships.")
		quit(1)
		return
	player.reset_for_sortie()
	aim_guide.show_solution(player, aim_side, aim_point, true)
	if not aim_guide.visible:
		push_error("AimGuide did not show the combat trajectory.")
		quit(1)
		return
	if aim_guide.find_child("VolleyTrajectoryLines", true, false) == null or aim_guide.find_child("AimImpactMarker", true, false) == null:
		push_error("AimGuide did not create volley trajectory and impact marker visuals.")
		quit(1)
		return
	aim_guide.hide_solution()

	var before_sail := float(player.get_telemetry().get("sail_integrity", 100.0))
	var feedback_before_hit: Dictionary = camera.get_feedback_state()
	player.take_hit(10.0, null, player.to_global(Vector3(0.0, 2.2, 0.0)), Vector3.BACK)
	var feedback_after_hit: Dictionary = camera.get_feedback_state()
	if int(feedback_after_hit.get("hit_impulses", 0)) <= int(feedback_before_hit.get("hit_impulses", 0)):
		push_error("Player hull hit did not trigger camera impact feedback.")
		quit(1)
		return
	var after_sail := float(player.get_telemetry().get("sail_integrity", 100.0))
	if after_sail >= before_sail:
		push_error("Regional sail damage did not reduce sail integrity.")
		quit(1)
		return

	var before_starboard_cannons := float(player.get_telemetry().get("starboard_cannon_integrity", 100.0))
	player.take_hit(10.0, null, player.to_global(Vector3(1.55, 0.55, 0.0)), Vector3.LEFT)
	var after_starboard_cannons := float(player.get_telemetry().get("starboard_cannon_integrity", 100.0))
	if after_starboard_cannons >= before_starboard_cannons:
		push_error("Regional cannon damage did not reduce starboard cannon integrity.")
		quit(1)
		return

	if not player.has_method("set_shot_mode") or not player.has_method("get_current_shot_profile"):
		push_error("Player ship does not expose tactical shot modes.")
		quit(1)
		return
	player.reset_for_sortie()
	player.set_shot_mode("chain")
	var chain_report: Dictionary = player.take_projectile_hit(32.0, null, player.to_global(Vector3(0.0, 2.2, 0.0)), Vector3.BACK, "chain", player.get_current_shot_profile())
	if String(chain_report.get("shot_mode", "")) != "chain" or float(chain_report.get("sail_damage", 0.0)) <= float(chain_report.get("health_damage", 0.0)):
		push_error("Chain shot did not prioritize sail damage.")
		quit(1)
		return
	await process_frame
	var chain_visuals: Dictionary = player.get_visual_damage_state()
	if int(chain_visuals.get("sail_tears", 0)) <= 0:
		push_error("Chain shot sail damage did not reveal sail tear overlays.")
		quit(1)
		return
	if float(chain_visuals.get("sail_slump", 0.0)) <= 0.02:
		push_error("Chain shot sail damage did not slump/tilt sail geometry.")
		quit(1)
		return
	if float(player.get_telemetry().get("sail_hit_flutter", 0.0)) <= 0.0:
		push_error("Chain shot sail damage did not trigger sail flutter feedback.")
		quit(1)
		return
	if scene.find_child("SailRip", true, false) == null:
		push_error("Chain shot sail damage did not spawn sail rip VFX.")
		quit(1)
		return
	var chain_ball := Cannonball.new()
	chain_ball.configure_shot("chain", player.get_current_shot_profile())
	scene.add_child(chain_ball)
	await process_frame
	if chain_ball.find_child("ChainShotWeight", true, false) == null or chain_ball.find_child("ChainShotLink", true, false) == null or chain_ball.find_child("ChainShotTrail", true, false) == null:
		push_error("Chain shot projectile did not create distinctive chain visual/trail.")
		quit(1)
		return
	chain_ball.queue_free()
	await process_frame
	await process_frame
	await process_frame
	player.reset_for_sortie()
	player.set_shot_mode("grape")
	var grape_report: Dictionary = player.take_projectile_hit(10.0, null, player.to_global(Vector3(1.55, 0.55, 0.0)), Vector3.LEFT, "grape", player.get_current_shot_profile())
	if String(grape_report.get("shot_mode", "")) != "grape" or float(grape_report.get("starboard_cannon_damage", 0.0)) <= float(grape_report.get("health_damage", 0.0)):
		push_error("Grape shot did not prioritize cannon deck damage.")
		quit(1)
		return
	if float(grape_report.get("crew_shock_gain", 0.0)) <= 0.0 or float(player.get_telemetry().get("crew_shock", 0.0)) <= 0.0:
		push_error("Grape shot did not disrupt the gun crew.")
		quit(1)
		return
	var grape_visuals: Dictionary = player.get_visual_damage_state()
	if int(grape_visuals.get("damaged_starboard_cannons", 0)) <= 0:
		push_error("Grape shot cannon damage did not mark starboard cannon visuals.")
		quit(1)
		return
	if int(grape_visuals.get("port_ready_markers", 0)) <= 0 or int(grape_visuals.get("starboard_ready_markers", 0)) <= 0:
		push_error("Cannon readiness markers were not created for both broadsides.")
		quit(1)
		return
	if float(grape_visuals.get("starboard_cannon_tilt", 0.0)) <= 0.02:
		push_error("Grape shot cannon damage did not tilt/drop starboard cannon geometry.")
		quit(1)
		return
	if scene.find_child("CannonDeckHit", true, false) == null:
		push_error("Grape shot cannon damage did not spawn cannon deck VFX.")
		quit(1)
		return
	player.reset_for_sortie()
	player.set_shot_mode("round")
	if not player.has_method("set_bracing"):
		push_error("Player ship does not expose brace controls.")
		quit(1)
		return
	player.reset_for_sortie()
	player.set_bracing(false)
	var unbraced_report: Dictionary = player.take_projectile_hit(20.0, null, player.to_global(Vector3(0.0, 0.7, 0.0)), Vector3.BACK, "round", {})
	if float(player.get_telemetry().get("impact_recoil", 0.0)) <= 0.0:
		push_error("Projectile hit did not trigger impact recoil feedback.")
		quit(1)
		return
	if float(unbraced_report.get("impact_push", 0.0)) <= 0.0 or float(player.get_telemetry().get("impact_push", 0.0)) <= 0.0:
		push_error("Projectile hit did not add physical impact push.")
		quit(1)
		return
	var unbraced_damage := float(unbraced_report.get("health_damage", 0.0)) + float(unbraced_report.get("sail_damage", 0.0)) + float(unbraced_report.get("rudder_damage", 0.0)) + float(unbraced_report.get("port_cannon_damage", 0.0)) + float(unbraced_report.get("starboard_cannon_damage", 0.0))
	player.reset_for_sortie()
	player.set_bracing(true)
	var braced_report: Dictionary = player.take_projectile_hit(20.0, null, player.to_global(Vector3(0.0, 0.7, 0.0)), Vector3.BACK, "round", {})
	var braced_damage := float(braced_report.get("health_damage", 0.0)) + float(braced_report.get("sail_damage", 0.0)) + float(braced_report.get("rudder_damage", 0.0)) + float(braced_report.get("port_cannon_damage", 0.0)) + float(braced_report.get("starboard_cannon_damage", 0.0))
	if not bool(braced_report.get("braced", false)) or braced_damage >= unbraced_damage:
		push_error("Brace did not reduce incoming damage.")
		quit(1)
		return
	if not bool(braced_report.get("perfect_brace", false)) or not bool(player.get_telemetry().get("perfect_brace", false)):
		push_error("Fresh brace did not trigger the perfect brace timing window.")
		quit(1)
		return
	player.reset_for_sortie()
	player.set_bracing(false)
	var solid_report: Dictionary = player.take_projectile_hit(20.0, null, player.to_global(Vector3(0.0, 0.7, 0.0)), Vector3(0.7, 0.0, 0.7).normalized(), "round", {})
	var solid_damage := float(solid_report.get("health_damage", 0.0)) + float(solid_report.get("sail_damage", 0.0)) + float(solid_report.get("rudder_damage", 0.0)) + float(solid_report.get("port_cannon_damage", 0.0)) + float(solid_report.get("starboard_cannon_damage", 0.0))
	player.reset_for_sortie()
	var raking_report: Dictionary = player.take_projectile_hit(20.0, null, player.to_global(Vector3(0.0, 0.7, 0.0)), Vector3.BACK, "round", {})
	var raking_damage := float(raking_report.get("health_damage", 0.0)) + float(raking_report.get("sail_damage", 0.0)) + float(raking_report.get("rudder_damage", 0.0)) + float(raking_report.get("port_cannon_damage", 0.0)) + float(raking_report.get("starboard_cannon_damage", 0.0))
	player.reset_for_sortie()
	var glancing_report: Dictionary = player.take_projectile_hit(20.0, null, player.to_global(Vector3(0.0, 0.7, 0.0)), Vector3.RIGHT, "round", {})
	var glancing_damage := float(glancing_report.get("health_damage", 0.0)) + float(glancing_report.get("sail_damage", 0.0)) + float(glancing_report.get("rudder_damage", 0.0)) + float(glancing_report.get("port_cannon_damage", 0.0)) + float(glancing_report.get("starboard_cannon_damage", 0.0))
	if String(raking_report.get("hit_angle", "")) != "raking" or raking_damage <= solid_damage:
		push_error("Raking shot did not increase damage.")
		quit(1)
		return
	if String(glancing_report.get("hit_angle", "")) != "glancing" or glancing_damage >= solid_damage:
		push_error("Glancing shot did not reduce damage.")
		quit(1)
		return
	var hull_visuals: Dictionary = player.get_visual_damage_state()
	if int(hull_visuals.get("hull_scorch", 0)) <= 0:
		push_error("Hull damage did not reveal scorch mark overlays.")
		quit(1)
		return
	var flooding_report: Dictionary = player.take_projectile_hit(48.0, null, player.to_global(Vector3(0.85, 0.35, -0.8)), Vector3.LEFT, "round", {})
	if float(flooding_report.get("flooding_gain", 0.0)) <= 0.0:
		push_error("Hull breach hit did not add flooding.")
		quit(1)
		return
	var flooding_visuals: Dictionary = player.get_visual_damage_state()
	if int(flooding_visuals.get("leak_emitters", 0)) <= 0 or float(flooding_visuals.get("flooding_side", 0.0)) == 0.0:
		push_error("Flooding did not activate hull leak visual feedback.")
		quit(1)
		return
	player.reset_for_sortie()
	var powder_profile := {"force_powder_explosion": true}
	var powder_report: Dictionary = player.take_projectile_hit(38.0, null, player.to_global(Vector3(0.0, 0.7, 0.0)), Vector3.BACK, "round", powder_profile)
	if not bool(powder_report.get("powder_explosion", false)) or float(powder_report.get("powder_explosion_damage", 0.0)) <= 0.0:
		push_error("Forced powder explosion did not add explosive hull damage.")
		quit(1)
		return
	var powder_fx := scene.find_child("PowderExplosion", true, false)
	if powder_fx == null or powder_fx.find_child("PowderSparks", true, false) == null or powder_fx.find_child("PowderSmoke", true, false) == null or powder_fx.find_child("PowderDebris", true, false) == null:
		push_error("Powder explosion VFX was not created.")
		quit(1)
		return
	player.reset_for_sortie()
	if not player.has_method("perform_emergency_repair"):
		push_error("Player ship does not expose emergency repair.")
		quit(1)
		return
	var fire_report: Dictionary = player.take_projectile_hit(36.0, null, player.to_global(Vector3(1.55, 0.55, 0.0)), Vector3.LEFT, "round", {})
	if float(fire_report.get("fire_gain", 0.0)) <= 0.0 or float(player.get_telemetry().get("fire", 0.0)) <= 0.0:
		push_error("Cannon deck hit did not start a fire hazard.")
		quit(1)
		return
	var fire_visuals: Dictionary = player.get_visual_damage_state()
	if int(fire_visuals.get("fire_emitters", 0)) < 2:
		push_error("Fire hazard did not activate deck flame and ember feedback.")
		quit(1)
		return
	var fire_before_repair := float(player.get_telemetry().get("fire", 0.0))
	var flooding_before_repair := float(player.get_telemetry().get("flooding", 0.0))
	var shock_before_repair := float(player.get_telemetry().get("crew_shock", 0.0))
	var supplies_before_repair := int(player.get_telemetry().get("repair_supplies", 0))
	if not player.perform_emergency_repair():
		push_error("Emergency repair could not be performed on damaged ship.")
		quit(1)
		return
	var repair_telemetry: Dictionary = player.get_telemetry()
	if int(repair_telemetry.get("repair_supplies", 0)) >= supplies_before_repair:
		push_error("Emergency repair did not consume supplies.")
		quit(1)
		return
	if float(repair_telemetry.get("fire", 0.0)) >= fire_before_repair and float(repair_telemetry.get("flooding", 0.0)) >= flooding_before_repair and float(repair_telemetry.get("crew_shock", 0.0)) >= shock_before_repair:
		push_error("Emergency repair did not reduce hazards.")
		quit(1)
		return
	player.reset_for_sortie()

	var hud := scene.get_node_or_null("HUD")
	if hud == null or not hud.has_method("toggle_debug") or not hud.has_method("show_pause_menu") or not hud.has_method("show_hit_marker") or not hud.has_method("show_damage_warning") or not hud.has_method("show_combat_warning") or not hud.has_method("show_boarding_prompt"):
		push_error("HUD was not created with menu/debug controls.")
		quit(1)
		return

	hud.toggle_debug()
	hud.set_aim_state(true, 1, true)
	hud.show_hit_marker({"zone": "hull", "amount": 12.0, "critical": true})
	hud.show_damage_warning({"zone": "sails", "amount": 8.0, "critical": false})
	hud.show_combat_warning("ENEMY BROADSIDE", "PORT battery turning on us", 0.5)
	hud.show_pause_menu(true)
	hud.show_pause_menu(false)
	hud.apply_settings({"minimap_zoom": 1.2})
	await process_frame
	if hud.find_child("HitMarker", true, false) == null or hud.find_child("CombatWarning", true, false) == null or hud.find_child("DamageFlash", true, false) == null:
		push_error("HUD combat feedback nodes are missing.")
		quit(1)
		return
	if hud.find_child("BoardingPrompt", true, false) == null:
		push_error("HUD boarding prompt node is missing.")
		quit(1)
		return
	if hud.find_child("EnemyMarker0", true, false) == null:
		push_error("HUD enemy world markers were not created.")
		quit(1)
		return

	CombatFx.spawn_hull_hit(scene, player.global_position + Vector3(3.0, 1.0, 0.0), Vector3.LEFT)
	await process_frame
	var hull_hit := scene.find_child("HullHit", true, false)
	if hull_hit == null or hull_hit.find_child("WoodSplinters", true, false) == null or hull_hit.find_child("HullDebris", true, false) == null:
		push_error("Hull hit splinter/debris VFX was not created.")
		quit(1)
		return
	CombatFx.spawn_damage_callout(scene, player.global_position + Vector3(2.0, 1.2, 0.0), {"zone": "cannons", "shot_mode": "grape", "amount": 18.0, "critical": true})
	await process_frame
	var damage_callout := scene.find_child("DamageCallout", true, false)
	if damage_callout == null or damage_callout.find_child("DamageCalloutLabel", true, false) == null or damage_callout.find_child("DamageCalloutPip", true, false) == null:
		push_error("Damage callout VFX was not created.")
		quit(1)
		return
	CombatFx.spawn_grape_impact(scene, player.global_position + Vector3(2.5, 1.0, 0.0), Vector3.LEFT)
	await process_frame
	var grape_impact := scene.find_child("GrapeImpact", true, false)
	if grape_impact == null or grape_impact.find_child("GrapePelletRicochet", true, false) == null or grape_impact.find_child("GrapeImpactDust", true, false) == null:
		push_error("Grape impact VFX was not created.")
		quit(1)
		return

	var telegraph_targets := get_nodes_in_group("enemies")
	if telegraph_targets.is_empty():
		push_error("No enemy target available for broadside telegraph test.")
		quit(1)
		return
	var telegraph_enemy := telegraph_targets[0]
	if not telegraph_enemy.has_method("begin_broadside_windup") or not telegraph_enemy.has_method("get_broadside_windup"):
		push_error("Enemy ship does not expose broadside wind-up telegraph.")
		quit(1)
		return
	telegraph_enemy.begin_broadside_windup(1)
	await process_frame
	if float(telegraph_enemy.get_broadside_windup()) <= 0.0:
		push_error("Enemy broadside wind-up did not start.")
		quit(1)
		return
	var telegraph_fx := scene.find_child("BroadsideTelegraph", true, false)
	if telegraph_fx == null or telegraph_fx.find_child("BroadsideTelegraphSmoke", true, false) == null or telegraph_fx.find_child("GunPortWarning", true, false) == null:
		push_error("Enemy broadside telegraph VFX was not created.")
		quit(1)
		return

	var near_miss := Cannonball.new()
	scene.add_child(near_miss)
	var feedback_before_near_miss: Dictionary = camera.get_feedback_state()
	near_miss.global_position = player.global_position + player.global_transform.basis.x.normalized() * 5.5 + Vector3.DOWN * 0.65
	near_miss.launch_velocity(Vector3.DOWN * 2.0, null, 1.0)
	for i in range(4):
		await physics_frame
	var feedback_after_near_miss: Dictionary = camera.get_feedback_state()
	if int(feedback_after_near_miss.get("near_miss_impulses", 0)) <= int(feedback_before_near_miss.get("near_miss_impulses", 0)):
		push_error("Near-miss splash did not trigger camera feedback.")
		quit(1)
		return
	var near_miss_fx := scene.find_child("NearMissSplash", true, false)
	if near_miss_fx == null or near_miss_fx.find_child("WaterColumn", true, false) == null:
		push_error("Near-miss cannonball did not create the tall splash feedback.")
		quit(1)
		return

	var enemy_count := get_nodes_in_group("enemies").size()
	if enemy_count < 3:
		push_error("Expected at least 3 enemy ships, found %d." % enemy_count)
		quit(1)
		return

	var scene_enemies: Array = scene.get("enemies")
	var enemy: Node = null
	for candidate in scene_enemies:
		if is_instance_valid(candidate) and not bool(candidate.get("is_sunk")):
			enemy = candidate
			break
	if enemy == null:
		push_error("Scene enemy list did not expose a live combat target.")
		quit(1)
		return
	if enemy.has_method("reset_for_sortie"):
		enemy.reset_for_sortie()
		enemy.set("accepts_player_input", false)
		enemy.set("target_ship", player)
	enemy.global_position = player.global_position + player.global_transform.basis.x.normalized() * 28.0
	enemy.global_rotation = player.global_rotation
	danger_guide.show_threats([enemy], player)
	await process_frame
	if not danger_guide.visible:
		push_error("Broadside danger guide did not show enemy threat lane.")
		quit(1)
		return
	if danger_guide.find_child("BroadsideDangerFill", true, false) == null or danger_guide.find_child("BroadsideDangerLines", true, false) == null:
		push_error("Broadside danger guide did not create filled kill-zone visuals.")
		quit(1)
		return
	if not enemy.has_method("choose_tactical_shot_mode"):
		push_error("Enemy ship does not choose tactical shot modes.")
		quit(1)
		return
	var close_mode := String(enemy.choose_tactical_shot_mode(10.0))
	var chain_mode := String(enemy.choose_tactical_shot_mode(30.0))
	var far_mode := String(enemy.choose_tactical_shot_mode(80.0))
	if close_mode != "grape" or chain_mode != "chain" or far_mode != "round":
		push_error("Enemy tactical shot mode selection is invalid.")
		quit(1)
		return
	hud.set_world_state(player, [enemy], [])
	await process_frame
	var enemy_marker := hud.find_child("EnemyMarker0", true, false)
	if enemy_marker == null:
		push_error("HUD enemy marker disappeared after world-state update.")
		quit(1)
		return
	enemy.global_position = player.global_position + Vector3(6.0, 0.0, 0.0)
	enemy.set_shot_mode("round")
	enemy.take_projectile_hit(120.0, player, enemy.to_global(Vector3(0.0, 0.8, 0.0)), Vector3.BACK, "round", enemy.get_current_shot_profile())
	await process_frame
	if bool(enemy.get("is_sunk")) or not bool(enemy.get("is_incapacitated")):
		push_error("Low-health enemy sank instead of becoming disabled for boarding. sunk=%s incapacitated=%s health=%.2f ratio=%.2f" % [str(enemy.get("is_sunk")), str(enemy.get("is_incapacitated")), float(enemy.get("health")), float(enemy.get("incapacitation_health_ratio"))])
		quit(1)
		return
	if enemy.has_method("get_ai_state_name"):
		enemy.call("_update_combat_state", 0.1)
		if String(enemy.get_ai_state_name()) != "disabled":
			push_error("Incapacitated enemy did not enter disabled AI state.")
			quit(1)
			return
	if not bool(scene.call("_is_boardable", enemy)):
		push_error("Damaged close enemy did not become boardable.")
		quit(1)
		return
	scene.set("mission_complete", false)
	scene.set("player_sunk", false)
	scene.call("_update_boarding")
	await process_frame
	var boarding_prompt := hud.find_child("BoardingPrompt", true, false)
	if boarding_prompt == null or not boarding_prompt.visible:
		push_error("Boarding prompt did not appear for a boardable enemy.")
		quit(1)
		return
	scene.call("_complete_boarding", enemy)
	await process_frame
	if not bool(enemy.get("is_sunk")) or not bool(enemy.get("was_captured")):
		push_error("Boarding did not capture/disable the enemy ship.")
		quit(1)
		return
	var capture_fx := scene.find_child("BoardingCapture", true, false)
	if capture_fx == null or capture_fx.find_child("BoardingCaptureLabel", true, false) == null or capture_fx.find_child("BoardingCaptureSparks", true, false) == null:
		push_error("Boarding capture VFX was not created.")
		quit(1)
		return

	enemy = null
	for candidate in get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and not bool(candidate.get("is_sunk")):
			enemy = candidate
			break
	if enemy == null:
		push_error("No remaining enemy found for AI state smoke test.")
		quit(1)
		return
	if not enemy.has_method("get_ai_state_name"):
		push_error("Enemy ship does not expose AI state.")
		quit(1)
		return
	enemy.set_shot_mode("chain")
	enemy.take_projectile_hit(90.0, null, enemy.to_global(Vector3(0.0, 2.3, 0.0)), Vector3.BACK, "chain", enemy.get_current_shot_profile())
	await physics_frame
	await physics_frame
	if enemy.get_ai_state_name() != "crippled":
		push_error("Enemy AI did not enter crippled state after sail damage.")
		quit(1)
		return

	print("SMOKE_OK ships=%d" % get_nodes_in_group("ships").size())
	quit(0)
