extends SceneTree

const BattleScenarios := preload("res://scripts/battle_scenarios.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame

	var foundering_config := BattleScenarios.get_definition("fleet_trial")
	game.call("_on_custom_battle_requested", foundering_config)
	await process_frame
	var prize: Node = game.enemies[0]
	prize.call("incapacitate_for_boarding")
	prize.set("incapacitated_time_remaining", 1.0)
	game.call("_mark_boarding_protection", prize, 0, game.player_ship)
	prize.call("_update_incapacitated_foundering", 2.0)
	if bool(prize.get("is_sunk")) or float(prize.get("incapacitated_time_remaining")) < 0.99:
		return _fail("Boarding protection did not pause foundering")
	game.call("_clear_boarding_protection", prize)
	prize.call("_update_incapacitated_foundering", 1.1)
	if not bool(prize.get("is_sunk")):
		return _fail("Unclaimed incapacitated ship did not begin sinking")

	var fort_config := BattleScenarios.get_definition("blackglass_bastion")
	game.call("_prepare_custom_battle", fort_config)
	if String(game.get("custom_scenario_id")) != "blackglass_bastion":
		return _fail("Blackglass scenario id was lost during preparation: %s config=%s" % [String(game.get("custom_scenario_id")), String(fort_config.get("id", "missing"))])
	await process_frame
	var forts := get_nodes_in_group("scenario_fort")
	if forts.size() != 3:
		return _fail("Blackglass scenario did not spawn its three-fort defense chain")
	if game.enemies.size() != 7:
		return _fail("Blackglass scenario did not combine its forts and harbor fleet")
	var fort: Node = forts[0]
	game.hud.call("set_world_state", game.player_ship, game.enemies, game.island_markers)
	var compass = game.hud.get("_minimap")
	var fort_contacts := 0
	for contact in compass.get("contacts"):
		if String(contact.get("kind", "")) == "fort":
			fort_contacts += 1
	if fort_contacts != 3:
		return _fail("Combat compass did not receive all three fort markers")
	game.mortar_targeting_ui.call("open", game.player_ship, game.enemies, 400.0)
	var mortar_plot = game.mortar_targeting_ui.get("_plot")
	var mortar_forts := 0
	for target in mortar_plot.get("targets"):
		if is_instance_valid(target) and target.is_in_group("scenario_fort"):
			mortar_forts += 1
	game.mortar_targeting_ui.call("close")
	if mortar_forts != 3:
		return _fail("Mortar plot did not receive all three fort targets")
	var siege_objective: Dictionary = game.call("_build_combat_objective")
	if String(siege_objective.get("title", "")) != "Crush the Fortress Chain":
		return _fail("Blackglass scenario objective was '%s' (scenario=%s mode=%s health=%.0f)" % [
			String(siege_objective.get("title", "")),
			String(game.get("custom_scenario_id")),
			String(game.get("battle_mode")),
			float(game.player_ship.get("health")),
		])
	if game.call("_get_priority_enemy") != fort:
		return _fail("Blackglass scenario did not prioritize the coastal fort")
	fort.set("fire_range", 400.0)
	fort.set("_reload", 0.0)
	fort.call("_physics_process", 0.1)
	if get_nodes_in_group("cannonballs").is_empty():
		return _fail("Coastal fort did not fire its physical shore battery")
	var initial_guns: int = fort.call("_active_battery_count")
	fort.call("take_damage", float(fort.get("_battery_max_health")) + 0.1, game.player_ship)
	if int(fort.call("_active_battery_count")) != initial_guns - 1 or int(fort.get("fort_phase")) != 0:
		return _fail("A destroyed shore gun did not physically reduce the active battery")
	fort.call("take_damage", float(fort.get("_battery_max_health")) * float(initial_guns - 1) + 0.1, game.player_ship)
	if int(fort.get("fort_phase")) != 1:
		return _fail("Silencing every shore gun did not expose the main keep")
	fort.call("take_damage", float(fort.get("_keep_max_health")) + 0.1, game.player_ship)
	var magazine: Node3D = fort.get("_magazine_node")
	if int(fort.get("fort_phase")) != 2 or not is_instance_valid(magazine) or not magazine.visible:
		return _fail("Destroying the keep did not reveal the physical powder magazine")
	fort.call("take_damage", float(fort.get("_magazine_max_health")) + 0.1, game.player_ship)
	if not bool(fort.get("capture_sequence_active")) or bool(fort.get("is_sunk")):
		return _fail("The fort skipped its capture sequence after the magazine fell")
	if get_nodes_in_group("fort_assault").size() != 3:
		return _fail("Fort capture did not launch its three-boat landing party")
	var relief_orders := 0
	for hostile in game.enemies:
		if is_instance_valid(hostile) and not hostile.is_in_group("scenario_fort") and str(hostile.get("strategic_order_kind")) == "relieve_fort":
			relief_orders += 1
	if relief_orders <= 0:
		return _fail("Enemy fleet did not receive orders to relieve the fort")
	var guard_orders := 0
	for ally in game.allies:
		if is_instance_valid(ally) and str(ally.get("strategic_order_kind")) == "guard_fort":
			guard_orders += 1
	if guard_orders <= 0:
		return _fail("Allied fleet did not form a fort assault screen")
	for _frame in range(60):
		fort.call("_physics_process", 0.1)
	if not bool(fort.get("is_captured")) or bool(fort.get("is_sunk")) or int(fort.get("team_id")) != 0 or bool(game.call("_is_current_battle_complete")):
		return _fail("Capturing one fort incorrectly ended the fortress siege")
	if not fort.is_in_group("combat_ships") or int(fort.call("_active_battery_count")) <= 0:
		return _fail("Captured fort did not return as an allied shore battery")
	for remaining_fort in forts:
		if not bool(remaining_fort.get("is_captured")):
			remaining_fort.call("take_damage", float(remaining_fort.get("max_health")) + 1.0, game.player_ship)
			for _frame in range(60):
				remaining_fort.call("_physics_process", 0.1)
	if not bool(game.call("_is_current_battle_complete")):
		return _fail("Destroying the full fortress chain did not satisfy the siege objective")

	game.call("_prepare_custom_battle", fort_config)
	await process_frame
	if get_nodes_in_group("scenario_fort").size() != 3:
		return _fail("Replaying a scenario stacked duplicate fort content")

	var convoy_config := BattleScenarios.get_definition("tempest_convoy")
	game.call("_prepare_custom_battle", convoy_config)
	await process_frame
	var convoy: Array[Node] = []
	for ally in game.allies:
		if bool(ally.get_meta("scenario_convoy", false)):
			convoy.append(ally)
	if convoy.size() != 3:
		return _fail("Tempest scenario did not mark three dispatch vessels")
	for courier in convoy:
		courier.call("disable_ship", false)
	game.call("_update_custom_scenario_state")
	if not bool(game.get("mission_complete")) or not bool(game.get("custom_scenario_failed")):
		return _fail("Losing every courier did not fail the convoy scenario")

	var dominion_config := BattleScenarios.get_definition("redwater_dominion")
	game.call("_prepare_custom_battle", dominion_config)
	await process_frame
	var control_points := get_nodes_in_group("scenario_control_point")
	if control_points.size() != 3:
		return _fail("Redwater did not spawn three strategic sea positions")
	for point in control_points:
		point.set("owner_team", 0)
	if not bool(game.call("_is_current_battle_complete")):
		return _fail("Holding all Redwater positions did not satisfy the objective")

	var iron_config := BattleScenarios.get_definition("iron_line")
	game.call("_prepare_custom_battle", iron_config)
	await process_frame
	var islands := get_nodes_in_group("island_obstacle")
	if islands.is_empty():
		return _fail("Battlefield islands did not register as navigation obstacles")
	var test_island := islands[0] as Node3D
	var island_radius := float(test_island.get_meta("collision_radius", 0.0))
	var hull_clearance := maxf(float(game.player_ship.get("_hull_width")) * 0.46, float(game.player_ship.get("_hull_length")) * 0.15)
	game.player_ship.global_position = test_island.global_position + Vector3(island_radius * 0.5, 0.0, 0.0)
	game.player_ship.linear_velocity = Vector3(-4.0, 0.0, 0.0)
	game.player_ship.call("_resolve_island_grounding")
	var escaped_distance := Vector2(
		game.player_ship.global_position.x - test_island.global_position.x,
		game.player_ship.global_position.z - test_island.global_position.z
	).length()
	if escaped_distance < island_radius + hull_clearance - 0.02 or game.player_ship.linear_velocity.x <= 0.0:
		return _fail("Island grounding recovery did not separate the ship from shore")
	var navigator: Node3D = game.enemies[0]
	navigator.global_transform = Transform3D(Basis.IDENTITY, test_island.global_position + Vector3(0.0, 0.0, island_radius + 24.0))
	navigator.set("velocity", Vector3(0.0, 0.0, -6.0))
	navigator.set("_fleet_awareness_timer", 0.0)
	navigator.call("_update_fleet_awareness", 1.0)
	if (navigator.get("_island_avoidance") as Vector3).length_squared() <= 0.01:
		return _fail("AI did not anticipate an island lying across its projected route")
	var initial_enemy_count: int = game.call("_active_enemy_ship_count")
	for index in range(2):
		game.enemies[index].call("disable_ship", false)
	game.call("_update_custom_scenario_state", 0.1)
	if int(game.call("_active_enemy_ship_count")) <= initial_enemy_count - 2 or int(game.get("custom_scenario_spawned_waves").size()) != 1:
		return _fail("Iron Line did not commit its reserve when the blockade buckled")

	for scenario in BattleScenarios.all():
		game.call("_prepare_custom_battle", scenario)
		await process_frame
		if String(game.get("custom_scenario_id")) != String(scenario.get("id", "")):
			return _fail("Scenario preset did not retain its id: %s" % String(scenario.get("id", "")))
		if String(game.player_ship.get("hull_class")) != String(scenario.get("player_type", "")):
			return _fail("Scenario preset did not apply its command ship: %s" % String(scenario.get("id", "")))
		if game.enemies.is_empty():
			return _fail("Scenario preset launched without hostiles: %s" % String(scenario.get("id", "")))

	var preset_count := BattleScenarios.all().size()
	game.queue_free()
	await process_frame
	print("BATTLE_SCENARIO_TEST_OK foundering=protected_then_sunk fort=objective+map island=escaped convoy=failure presets=%d" % preset_count)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
